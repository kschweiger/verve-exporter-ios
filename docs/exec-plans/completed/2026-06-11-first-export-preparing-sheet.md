# First Export Preparing Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show immediate, explicit progress after tapping export so the first cold export does not feel stalled before the native share sheet appears.

**Architecture:** Keep `HealthManager.generateGeoJSON(for:)` as the only export generation path and leave HealthKit/export schema behavior unchanged. Refactor `WorkoutRow` presentation state in `ContentView.swift` so tapping export opens a preparing sheet immediately, then swaps that sheet to the existing UIKit-backed native share controller once the generated file URL is ready.

**Tech Stack:** Swift, SwiftUI, UIKit interop via `UIViewControllerRepresentable`, HealthKit, Xcode generic iOS build validation.

---

## Goal

After app startup, the first selected workout can take a few seconds before the native share sheet appears because export generation waits for HealthKit route and heart-rate queries. The user should see immediate feedback after tapping export, while preserving the direct share-sheet flow once the file is ready.

The finished behavior should be:

1. The user taps the blue export icon in a workout row.
2. The row spinner appears immediately.
3. A compact preparing sheet appears immediately with clear export progress text.
4. The app continues generating the GeoJSON through the existing `HealthManager.generateGeoJSON(for:)` call.
5. When the URL is ready, the same sheet automatically changes to the native share sheet without requiring another user tap.
6. If generation fails, the preparing sheet closes and the existing `Export Failed` alert appears.
7. If the user dismisses the preparing sheet before generation finishes, the eventual result is ignored so a delayed share sheet does not appear unexpectedly.

## Context

- The previous refactor removed the intermediate `ShareLink` overlay and now presents `ActivityView(activityItems: [file.url])` directly from `.sheet(item: $exportFile)`.
- `exportFile` is only set after `HealthManager.generateGeoJSON(for:)` finishes.
- `generateGeoJSON(for:)` starts both expensive HealthKit reads before encoding:

```swift
async let locationsTask = try? fetchRouteLocations(for: workout)
async let heartRatesTask = try? fetchHeartRates(for: workout)
let (gpsDataOrNil, hrDataOrNil) = await (locationsTask, heartRatesTask)
```

- The observed issue is only the first export after startup. Later exports are already fast enough, so speculative background export generation is not necessary.

## Constraints

- Do not modify `VerveExporter/HealthManager.swift`.
- Do not modify `VerveExporter/GeoJSON.swift`.
- Do not change HealthKit permissions, HealthKit query scope, temporary file names, or Verve GeoJSON output.
- Do not pre-generate exports on app startup or after workout list load. That would read route and heart-rate data before explicit user intent.
- Do not create, print, commit, or upload real workout exports.
- Keep the orange debug preview button and `DebugView` behavior unchanged.
- Keep the existing `ActivityView` wrapper as the native share-sheet presentation path.
- Keep the implementation local to `VerveExporter/ContentView.swift` unless the compiler requires a tiny helper split.

## Files Likely To Change

- Modify `VerveExporter/ContentView.swift`
  - Replace `@State private var exportFile: ExportFile?` with export sheet state.
  - Add a local `ExportSheetState: Identifiable` enum near `ExportFile`.
  - Add a `PreparingExportView` helper near `ActivityView`.
  - Update the export button action to show preparing state before starting generation.
  - Update the export sheet modifier to switch between preparing and sharing states.
  - Keep `ActivityView`, `ExportFile`, debug sheet, and export failure alert.
- Modify `docs/exec-plans/README.md`
  - Add this plan under Current Active Plans.
  - Move it to Completed Plans after implementation and validation.

## Implementation Tasks

### Task 1: Add Export Sheet State Types

**Files:**
- Modify: `VerveExporter/ContentView.swift`

- [ ] **Step 1: Add `ExportSheetState` above `ExportFile`**

Add this enum after `ActivityView` and before `ExportFile`:

```swift
enum ExportSheetState: Identifiable {
    case preparing(UUID)
    case sharing(ExportFile)

    var id: String {
        switch self {
        case .preparing(let id):
            return "preparing-\(id.uuidString)"
        case .sharing(let file):
            return "sharing-\(file.id)"
        }
    }
}
```

The UUID gives each export attempt a stable identity while it is preparing. The different `sharing-` identity forces SwiftUI to rebuild the sheet content when the generated file is ready.

- [ ] **Step 2: Add `PreparingExportView`**

Add this helper near `ActivityView`:

```swift
struct PreparingExportView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Preparing Export")
                .font(.headline)

            Text("Reading workout data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
```

Keep the text short. The user needs to know the tap registered and export is in progress, not learn implementation details.

### Task 2: Replace `exportFile` Presentation State

**Files:**
- Modify: `VerveExporter/ContentView.swift`

- [ ] **Step 1: Replace row state**

In `WorkoutRow`, replace:

```swift
@State private var exportFile: ExportFile?
```

with:

```swift
@State private var exportSheetState: ExportSheetState?
@State private var activeExportID: UUID?
```

Keep the existing `isExporting`, `showError`, and `showDebug` state.

- [ ] **Step 2: Update the export button action**

Replace the current `Task` body:

```swift
Task {
    isExporting = true
    do {
        let url = try await healthManager.generateGeoJSON(for: workout)
        self.exportFile = ExportFile(url: url)
    } catch {
        print("Export error: \(error.localizedDescription)")
        showError = true
    }
    isExporting = false
}
```

with:

```swift
Task {
    let exportID = UUID()
    activeExportID = exportID
    isExporting = true
    exportSheetState = .preparing(exportID)

    #if DEBUG
    let exportStart = Date()
    print("Export started for workout \(workout.uuid)")
    #endif

    do {
        let url = try await healthManager.generateGeoJSON(for: workout)

        #if DEBUG
        let elapsed = Date().timeIntervalSince(exportStart)
        print("Export generated for workout \(workout.uuid) in \(String(format: "%.2f", elapsed))s")
        #endif

        guard activeExportID == exportID else {
            return
        }

        exportSheetState = .sharing(ExportFile(url: url))
    } catch {
        print("Export error: \(error.localizedDescription)")

        guard activeExportID == exportID else {
            return
        }

        exportSheetState = nil
        showError = true
    }

    if activeExportID == exportID {
        isExporting = false
        activeExportID = nil
    }
}
```

This preserves the existing export path while making the pending state visible immediately. The `activeExportID` checks prevent a dismissed export attempt from presenting a share sheet later.

- [ ] **Step 3: Fix cancellation cleanup**

The `return` paths above can leave `isExporting` true if the user dismissed the sheet before completion. To avoid that, prefer this final implementation shape instead of early returns:

```swift
Task {
    let exportID = UUID()
    activeExportID = exportID
    isExporting = true
    exportSheetState = .preparing(exportID)

    #if DEBUG
    let exportStart = Date()
    print("Export started for workout \(workout.uuid)")
    #endif

    do {
        let url = try await healthManager.generateGeoJSON(for: workout)

        #if DEBUG
        let elapsed = Date().timeIntervalSince(exportStart)
        print("Export generated for workout \(workout.uuid) in \(String(format: "%.2f", elapsed))s")
        #endif

        if activeExportID == exportID {
            exportSheetState = .sharing(ExportFile(url: url))
        }
    } catch {
        print("Export error: \(error.localizedDescription)")

        if activeExportID == exportID {
            exportSheetState = nil
            showError = true
        }
    }

    if activeExportID == exportID {
        isExporting = false
        activeExportID = nil
    }
}
```

Use this second version in the code.

### Task 3: Update Sheet Presentation

**Files:**
- Modify: `VerveExporter/ContentView.swift`

- [ ] **Step 1: Replace the export sheet modifier**

Replace:

```swift
.sheet(item: $exportFile) { file in
    ActivityView(activityItems: [file.url])
}
```

with:

```swift
.sheet(item: $exportSheetState, onDismiss: {
    activeExportID = nil
    isExporting = false
}) { state in
    switch state {
    case .preparing:
        PreparingExportView()
    case .sharing(let file):
        ActivityView(activityItems: [file.url])
    }
}
```

This keeps one export-related sheet. The separate debug sheet stays unchanged.

- [ ] **Step 2: Confirm debug sheet remains separate**

Do not change this existing modifier:

```swift
.sheet(isPresented: $showDebug) {
    DebugView(workout: workout, healthManager: healthManager)
}
```

- [ ] **Step 3: Confirm failure alert remains unchanged**

Keep:

```swift
.alert("Export Failed", isPresented: $showError) {
    Button("OK", role: .cancel) { }
} message: {
    Text("Could not find data for this workout.")
}
```

### Task 4: Run Targeted Source Checks

**Files:**
- Inspect: `VerveExporter/ContentView.swift`

- [ ] **Step 1: Confirm old direct file state is gone**

Run:

```bash
rg -n "exportFile" VerveExporter/ContentView.swift
```

Expected: no output.

- [ ] **Step 2: Confirm new sheet state exists**

Run:

```bash
rg -n "ExportSheetState|PreparingExportView|activeExportID|exportSheetState" VerveExporter/ContentView.swift
```

Expected: output for the new enum, preparing view, row state, export button action, and sheet modifier.

- [ ] **Step 3: Confirm share overlay remains absent**

Run:

```bash
rg -n "ShareView|ShareLink|Save GeoJSON|presentationDetents" VerveExporter/ContentView.swift
```

Expected: no output.

- [ ] **Step 4: Confirm export generation code is untouched**

Run:

```bash
git diff -- VerveExporter/HealthManager.swift VerveExporter/GeoJSON.swift
```

Expected: no output.

### Task 5: Validate The Change

**Files:**
- Validate: repository root

- [ ] **Step 1: Run docs validation**

Run:

```bash
make validate-docs
```

Expected: required files exist, harness metadata parses, and the unresolved-template scan passes.

- [ ] **Step 2: Run whitespace validation**

Run:

```bash
git diff --check
```

Expected: no whitespace errors.

- [ ] **Step 3: Run the generic iOS build**

Run:

```bash
make validate-build
```

Expected: build succeeds.

If this fails only with the known Swift macro/plugin sandbox restriction described in `docs/TESTING.md`, run:

```bash
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='-disable-sandbox' build
```

Expected: build succeeds with the sandbox workaround.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git diff -- VerveExporter/ContentView.swift docs/exec-plans/README.md docs/exec-plans/active/2026-06-11-first-export-preparing-sheet.md
```

Expected:

- `ContentView.swift` contains the export state refactor, preparing view, and existing `ActivityView`.
- `HealthManager.swift` and `GeoJSON.swift` are unchanged.
- `docs/exec-plans/README.md` lists this active plan while implementation is in progress.

## Manual Real-Device Smoke Test

Run this on an iPhone with HealthKit access and at least one workout:

1. Force quit the app.
2. Launch the app.
3. Wait for the workout list to load.
4. Tap a row's blue export icon.
5. Confirm a row-level spinner appears immediately.
6. Confirm a preparing sheet appears immediately.
7. Confirm the preparing sheet automatically becomes the native iOS share sheet.
8. Cancel the share sheet.
9. Tap export on a different workout.
10. Confirm the share sheet appears quickly, with the preparing sheet appearing only briefly if generation is already warm.
11. Force quit and relaunch again.
12. Tap export on a workout, then dismiss the preparing sheet before generation finishes.
13. Confirm no delayed share sheet appears after dismissal.
14. Tap the orange debug icon on a row.
15. Confirm the JSON preview sheet still opens.

Do not share, paste, commit, or upload the generated workout file unless the specific file has been marked safe by the user.

## Progress Log

- 2026-06-11: Created active execution plan for first-export preparing sheet UX.
- 2026-06-11: Replaced row export state with a preparing/share sheet state machine in `ContentView.swift`.
- 2026-06-11: Added `PreparingExportView`, `ExportSheetState`, and stale-export guards so dismissing the preparing sheet suppresses delayed share presentation.
- 2026-06-11: Validation results: `make validate-docs` passed, `git diff --check` passed, `make validate-build` hit the documented Swift macro sandbox failure, and the fallback build with `OTHER_SWIFT_FLAGS='-disable-sandbox'` succeeded.

## Decisions

- Keep direct share behavior from the previous refactor: no extra `ShareLink` button.
- Use a visible preparing sheet instead of startup pre-generation to avoid reading HealthKit route and heart-rate data before explicit export intent.
- Add debug-only timing logs around row-triggered export generation to aid real-device diagnosis without changing production behavior.
- Ignore stale export results when the preparing sheet is dismissed before generation finishes.

## Questions Resolved

- The first export delay is acceptable if the app immediately shows explicit preparation progress.
- Later exports being fast means background export generation is not required for this change.
- The current export generation path should remain unchanged.

## Completion Criteria

- First export after startup shows immediate preparing feedback.
- The native share sheet appears automatically when the file URL is ready.
- No intermediate `ShareLink` or second-tap overlay returns.
- Dismissing the preparing sheet prevents a delayed share sheet from appearing.
- Export failures still show the existing `Export Failed` alert.
- Debug JSON preview still works.
- `HealthManager.swift` and `GeoJSON.swift` are unchanged.
- Validation commands have been run and results are recorded in the implementation handoff or final response.
- After implementation and validation, move this file to `docs/exec-plans/completed/` and update `docs/exec-plans/README.md`.

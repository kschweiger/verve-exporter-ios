# Direct Export Share Sheet Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the export button in each workout list row generate the GeoJSON file and present the native iOS share sheet directly, without the intermediate SwiftUI `ShareLink` overlay.

**Architecture:** Keep `HealthManager.generateGeoJSON(for:)` as the only export-file generation path. Change only the SwiftUI presentation layer in `ContentView.swift` by replacing the current `ShareView`/`ShareLink` wrapper with a `UIViewControllerRepresentable` that hosts `UIActivityViewController` for the generated file URL.

**Tech Stack:** Swift, SwiftUI, UIKit interop via `UIViewControllerRepresentable`, HealthKit, Xcode generic iOS build validation.

---

## Goal

When a user taps a workout row's export icon, the app should:

1. Show the row-level export progress indicator while `HealthManager.generateGeoJSON(for:)` runs.
2. Present the native iOS share sheet as soon as the temporary GeoJSON file URL is ready.
3. Avoid showing a custom half-height sheet containing a second `Save GeoJSON` button.
4. Preserve existing error handling, debug preview behavior, export file naming, and GeoJSON content.

## Context

- Current code in `VerveExporter/ContentView.swift` stores the generated URL in `@State private var exportFile: ExportFile?`.
- The row then presents `.sheet(item: $exportFile) { ShareView(url: file.url) }`.
- `ShareView` contains a `ShareLink`, so the user sees an extra overlay and must tap again before the system share sheet appears.
- `HealthManager.generateGeoJSON(for:)` already writes a temporary `.json` file and returns the URL. That flow should not change.

## Constraints

- Do not modify `VerveExporter/HealthManager.swift`.
- Do not modify `VerveExporter/GeoJSON.swift`.
- Do not change HealthKit permissions, queries, or export schema.
- Do not create, print, commit, or upload real workout exports.
- Keep `DebugView` and the orange debug button behavior unchanged.
- Keep row-level error presentation for export failures.
- Keep the implementation local to `ContentView.swift` unless the compiler requires a tiny UIKit helper split.

## Files Likely To Change

- Modify `VerveExporter/ContentView.swift`
  - Add `import UIKit`.
  - Replace `ShareView` with `ActivityView`.
  - Keep or rename `ExportFile`; if renamed, update all references consistently.
  - Change the `.sheet(item:)` content to present `ActivityView(activityItems: [file.url])`.
- Modify `docs/exec-plans/README.md`
  - Add this plan under Current Active Plans.
  - Move it to Completed Plans when implementation is complete.

## Implementation Tasks

### Task 1: Replace The Intermediate ShareLink Overlay

**Files:**
- Modify: `VerveExporter/ContentView.swift`

- [ ] **Step 1: Add UIKit import**

At the top of `VerveExporter/ContentView.swift`, keep the existing imports and add UIKit:

```swift
import SwiftUI
import HealthKit
import UIKit
```

- [ ] **Step 2: Replace the export sheet body**

Find the existing share sheet modifier:

```swift
.sheet(item: $exportFile) { file in
    ShareView(url: file.url)
}
```

Replace it with:

```swift
.sheet(item: $exportFile) { file in
    ActivityView(activityItems: [file.url])
}
```

This keeps the same state-driven presentation timing while changing the sheet content to the native activity controller.

- [ ] **Step 3: Remove the old ShareView**

Delete this helper view entirely:

```swift
struct ShareView: View {
    let url: URL

    var body: some View {
        ShareLink(item: url) {
            Label("Save GeoJSON", systemImage: "doc.text")
                .font(.headline)
                .padding()
        }
        .presentationDetents([.medium])
    }
}
```

- [ ] **Step 4: Add ActivityView**

Add this helper where `ShareView` used to be, above `ExportFile`:

```swift
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}
```

Keep the empty update method because `UIViewControllerRepresentable` requires it and there is no dynamic update state after presentation.

- [ ] **Step 5: Keep ExportFile unless renaming improves clarity**

The existing type is acceptable:

```swift
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}
```

If renaming to `ShareFile`, update all three references in `WorkoutRow`:

```swift
@State private var exportFile: ShareFile?
self.exportFile = ShareFile(url: url)
struct ShareFile: Identifiable { ... }
```

Do not rename unless the final diff is clearer; a small localized diff is preferred.

### Task 2: Confirm Existing Export And Error State Still Flow Correctly

**Files:**
- Inspect: `VerveExporter/ContentView.swift`

- [ ] **Step 1: Confirm loading state order**

Verify the export button action still follows this order:

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

This preserves current behavior: progress appears while generating, successful generation triggers the share presentation, and failed generation opens the existing alert.

- [ ] **Step 2: Confirm no duplicate sheet conflicts were introduced**

After the edit, `WorkoutRow` should still have exactly two sheet modifiers:

```swift
.sheet(item: $exportFile) { file in
    ActivityView(activityItems: [file.url])
}

.sheet(isPresented: $showDebug) {
    DebugView(workout: workout, healthManager: healthManager)
}
```

Do not merge these sheets in this refactor. They are driven by separate buttons and separate state.

- [ ] **Step 3: Confirm the old overlay is gone**

Run:

```bash
rg -n "ShareView|ShareLink|Save GeoJSON|presentationDetents" VerveExporter/ContentView.swift
```

Expected: no output.

Run:

```bash
rg -n "ActivityView|UIActivityViewController|exportFile" VerveExporter/ContentView.swift
```

Expected: output showing `ActivityView`, `UIActivityViewController`, and the existing `exportFile` state references.

### Task 3: Validate The Refactor

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

If the build fails only with the known Swift macro/plugin sandbox restriction described in `docs/TESTING.md`, run:

```bash
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='-disable-sandbox' build
```

Expected: build succeeds with the sandbox workaround.

- [ ] **Step 4: Inspect final diff**

Run:

```bash
git diff -- VerveExporter/ContentView.swift docs/exec-plans/README.md docs/exec-plans/active/2026-06-10-direct-export-share-sheet.md
```

Expected:

- `ContentView.swift` only changes the share presentation helper and import.
- `HealthManager.swift` and `GeoJSON.swift` are unchanged.
- `docs/exec-plans/README.md` lists this active plan.

## Manual Real-Device Smoke Test

Run this on an iPhone with HealthKit access and at least one workout:

1. Launch the app.
2. Confirm the workout list loads.
3. Tap a row's blue export icon.
4. Confirm a row-level spinner appears during export generation.
5. Confirm the native iOS share sheet appears directly after generation.
6. Confirm there is no intermediate sheet with a `Save GeoJSON` button.
7. Cancel the share sheet.
8. Confirm the workout list remains visible and usable.
9. Tap the orange debug icon on the same row.
10. Confirm the JSON preview sheet still opens.

Do not share, paste, commit, or upload the generated workout file unless the specific file has been marked safe by the user.

## Progress Log

- 2026-06-10: Created active execution plan for direct export share sheet refactor.
- 2026-06-11: Replaced the intermediate `ShareLink` sheet content with a UIKit `UIActivityViewController` wrapper in `ContentView.swift`.
- 2026-06-11: Verified the old overlay path is gone with targeted `rg` checks and preserved the existing row-level export/error state flow.
- 2026-06-11: Validation results: `make validate-docs` passed, `git diff --check` passed after removing one trailing-space issue, `make validate-build` hit the documented sandbox macro/plugin failure, and the fallback build with `OTHER_SWIFT_FLAGS='-disable-sandbox'` succeeded.

## Decisions

- Use UIKit `UIActivityViewController` because SwiftUI `ShareLink` embedded in a sheet creates the extra overlay the refactor is removing.
- Keep `HealthManager.generateGeoJSON(for:)` unchanged because the issue is presentation-only.
- Keep the existing debug preview sheet unchanged because it serves a separate diagnostic workflow.
- Use the existing `ExportFile` state wrapper by default to minimize diff size.

## Questions Resolved

- The export button should directly present the native share sheet after file generation.
- The refactor should not change GeoJSON output or HealthKit behavior.
- A detailed plan file is required even though the code change itself is small.

## Completion Criteria

- Tapping the export icon opens the native iOS share sheet directly after generation.
- The custom `ShareView`/`ShareLink` overlay no longer exists.
- Export failure still shows the `Export Failed` alert.
- Debug JSON preview still opens from the orange debug button.
- `HealthManager.swift` and `GeoJSON.swift` are unchanged.
- Validation commands have been run and results are recorded in the implementation handoff or final response.
- After implementation and validation, move this file to `docs/exec-plans/completed/` and update `docs/exec-plans/README.md`.

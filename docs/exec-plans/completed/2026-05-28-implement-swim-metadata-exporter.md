# Swim Metadata Exporter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` or `superpowers:subagent-driven-development` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Export source-neutral swimming lap, set, stroke, pool length, and SWOLF metadata from HealthKit into Verve GeoJSON.

**Architecture:** Add a typed optional `properties.metadata.swimming` model to the Swift GeoJSON encoder, then build that model from `HKWorkout` events and statistics only for swimming workouts. Keep HealthKit names inside extraction code and emit only the source-neutral field names documented in the Verve file extension design.

**Tech Stack:** SwiftUI app, HealthKit, `Codable`, Verve GeoJSON `FeatureCollection`.

---

## Goal

Implement the exporter side of the swim metadata Verve file extension described in `docs/design-docs/2026-05-28-swim-metadata-verve-file-extension.md`.

The exported Verve GeoJSON should include:

```json
{
  "properties": {
    "metadata": {
      "swimming": {
        "schemaVersion": 1,
        "poolLengthMeters": 50,
        "totalStrokeCount": 337,
        "averageSwolf": 97.1,
        "lapCount": 10,
        "setCount": 8,
        "strokeStyles": ["breaststroke", "freestyle"],
        "laps": [],
        "sets": []
      }
    }
  }
}
```

Backend ingestion, database storage, and import validation are out of scope for this plan.

## Context

- A real-device debug JSON probe confirmed HealthKit provides pool swim `lap` events, `segment` events, `HKSwimmingStrokeStyle`, `HKSWOLFScore`, workout lap length, and aggregate swimming stroke count for Apple-generated Workouts app swims.
- The current Swift exporter can preview a swim diagnostic JSON sheet, but the normal Verve GeoJSON export does not yet include `properties.metadata`.
- Verve should define a source-neutral transfer schema. Export JSON must not contain HealthKit field names such as `HKSWOLFScore`.
- Swimming location type belongs in Verve `activityType` and `activitySubType`, not in `metadata.swimming`.
- There is no automated XCTest target in the repository today. Validation is compiler/docs checks plus manual real-device HealthKit verification.

## Constraints

- Do not change backend code in this session.
- Do not commit, paste, or store real workout export files.
- Do not put swimming location type into `metadata.swimming`.
- Keep non-swim exports valid and avoid adding empty `metadata` objects to non-swim workouts.
- Omit unknown optional fields instead of inventing values.
- Keep the existing diagnostic JSON sheet available as the fallback verification path while implementing the real export.
- Treat real-device feedback as a blocking implementation checkpoint. After the first exporter wiring, stop and wait for the user's phone-tested JSON before continuing.
- Do not fix unrelated GeoJSON gaps, including the existing `movingDistanceSeconds` vs `movingDurationSeconds` compatibility note, unless the user explicitly expands scope.

## Files likely to change

- Modify `VerveExporter/GeoJSON.swift`
  - Add Codable models for root metadata, swimming metadata, swim laps, and swim sets.
  - Add optional `metadata` to `VerveProperties`.
- Modify `VerveExporter/HealthManager.swift`
  - Build `SwimmingMetadata` from HealthKit swim workouts.
  - Attach the metadata to exported Verve GeoJSON.
  - Improve swimming subtype mapping using HealthKit swimming location type for pool vs open-water swims.
  - Reuse or consolidate debug helper logic where possible.
- Modify `docs/product-specs/verve-geojson-format.md`
  - Promote the proposed `metadata.swimming` shape into the product format documentation after implementation.
- Modify `docs/references/healthkit.md`
  - Record the implemented HealthKit mapping and remaining real-device validation limits.
- Modify this execution plan
  - Check off completed steps and move the file to `docs/exec-plans/completed/` when the implementation is finished.

## Validation commands

Run these before claiming implementation complete:

```bash
make validate-docs
```

```bash
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='-disable-sandbox' build
```

Also run:

```bash
git diff --check
git status --short
```

Manual real-device validation is required after the compiler check:

- Export the same Apple Workouts pool swim used for the diagnostic probe.
- Confirm exported Verve GeoJSON has `properties.metadata.swimming`.
- Confirm the sample workout exports `lapCount: 10`, `setCount: 8`, `poolLengthMeters: 50`, and `totalStrokeCount: 337`.
- Confirm lap objects include `strokeStyle` and `swolf`.
- Confirm set objects include `lapStartIndex`, `lapEndIndex`, `lapCount`, `distanceMeters`, `strokeStyle`, and `averageSwolf` where derivable.
- Confirm `metadata.swimming` has no swimming location field.
- Confirm the workout activity is still classified through `activityType` and `activitySubType`.
- Export a non-swim workout and confirm no `metadata.swimming` object is emitted.

## Mandatory user-device checkpoints

The implementing agent must stop at these checkpoints and wait for the user to test on a real phone. Do not continue past a checkpoint using assumptions if the phone output differs from the plan.

### Checkpoint A: First swim metadata export

Stop after Tasks 1-5 and a successful local build. Ask the user to run the app on their phone against the same Apple Workouts pool swim and provide a sanitized snippet with:

```json
{
  "properties": {
    "activityType": "...",
    "activitySubType": "...",
    "metadata": {
      "swimming": {
        "schemaVersion": 1,
        "poolLengthMeters": 50,
        "totalStrokeCount": 337,
        "averageSwolf": 97.1,
        "lapCount": 10,
        "setCount": 8,
        "strokeStyles": ["breaststroke", "freestyle"],
        "laps": [
          {
            "index": 1,
            "durationSeconds": 54.34,
            "distanceMeters": 50,
            "strokeStyle": "breaststroke",
            "strokeCount": 26,
            "swolf": 80.34
          }
        ],
        "sets": [
          {
            "index": 1,
            "lapStartIndex": 1,
            "lapEndIndex": 2,
            "lapCount": 2,
            "distanceMeters": 100,
            "strokeStyle": "breaststroke",
            "strokeCount": 56,
            "averageSwolf": 82.69
          }
        ]
      }
    }
  }
}
```

The user does not need to provide route coordinates, heart-rate samples, private notes, or a full workout file. The useful minimum is `properties.activityType`, `properties.activitySubType`, the full `properties.metadata.swimming` object, the first two lap objects, and all set summary objects.

After the user responds:

- If lap or set counts differ from the diagnostic probe, update this plan before changing code further.
- If `strokeCount` inference is wrong or suspicious, remove inferred per-lap and per-set stroke counts from the implementation and keep only `totalStrokeCount`.
- If segment-to-set overlap does not match Apple Workouts app sets, revise Task 3 before continuing.
- If pool/open-water subtype mapping disagrees with the phone output, revise Task 7 before continuing.
- Record the observed phone result in this plan's progress log without pasting private full workout files.

### Checkpoint B: Final real-device export review

Stop again after subtype mapping and docs updates. Ask the user to run one final swim export and one non-swim export on device.

Continue to completion only after the user confirms:

- The swim export contains `properties.metadata.swimming`.
- The swim metadata has no location-type field.
- The swim activity classification is acceptable.
- The non-swim export does not contain `metadata.swimming`.

If the user cannot run the final device check in the same session, leave this plan in `active/` and record the manual validation as blocked.

## Implementation tasks

### Task 1: Add source-neutral Swift GeoJSON metadata models

**Files:**

- Modify `VerveExporter/GeoJSON.swift`

- [x] Add an optional `metadata: VerveMetadata?` property to `VerveProperties`.
- [x] Add `metadata` to `VerveProperties.CodingKeys`.
- [x] Add these `Codable` structs near the existing GeoJSON model structs:

```swift
struct VerveMetadata: Codable {
    let swimming: SwimmingMetadata?
}

struct SwimmingMetadata: Codable {
    let schemaVersion: Int
    let poolLengthMeters: Double?
    let totalStrokeCount: Int?
    let averageSwolf: Double?
    let lapCount: Int?
    let setCount: Int?
    let strokeStyles: [String]?
    let laps: [SwimLapMetadata]?
    let sets: [SwimSetMetadata]?
}

struct SwimLapMetadata: Codable {
    let index: Int
    let startTime: String?
    let endTime: String?
    let durationSeconds: Double?
    let distanceMeters: Double?
    let strokeStyle: String?
    let strokeCount: Int?
    let swolf: Double?
    let restAfterSeconds: Double?
}

struct SwimSetMetadata: Codable {
    let index: Int
    let startTime: String?
    let endTime: String?
    let durationSeconds: Double?
    let lapStartIndex: Int?
    let lapEndIndex: Int?
    let lapCount: Int?
    let distanceMeters: Double?
    let strokeStyle: String?
    let strokeCount: Int?
    let averageSwolf: Double?
    let restAfterSeconds: Double?
}
```

- [x] Keep all swim fields optional except `schemaVersion` and object `index` fields.
- [x] Use the existing encoder behavior so nil fields are omitted when possible by Swift optional encoding.

### Task 2: Build lap metadata from HealthKit lap events

**Files:**

- Modify `VerveExporter/HealthManager.swift`

- [x] Add a private helper `buildSwimmingMetadata(for workout: HKWorkout, isoFormatter: ISO8601DateFormatter) -> SwimmingMetadata?`.
- [x] Return `nil` when `workout.workoutActivityType != .swimming`.
- [x] Read pool length from `workoutActivities.first?.workoutConfiguration.lapLength` first, then fall back to `HKMetadataKeyLapLength`.
- [x] Read total stroke count from `.swimmingStrokeCount` workout statistics.
- [x] Sort `workout.workoutEvents` with `type == .lap` by start date.
- [x] Convert each lap event into `SwimLapMetadata`:
  - `index`: 1-based sorted lap index.
  - `startTime` and `endTime`: ISO-8601 event boundaries.
  - `durationSeconds`: `event.endDate.timeIntervalSince(event.dateInterval.start)`.
  - `distanceMeters`: pool length when known.
  - `strokeStyle`: normalized source-neutral value from `HKMetadataKeySwimmingStrokeStyle`.
  - `swolf`: numeric value from `HKMetadataKeySWOLFScore`.
  - `strokeCount`: `round(swolf - durationSeconds)` only when both values exist and the result is non-negative.
  - `restAfterSeconds`: next lap start minus this lap end when positive.
- [x] Reuse the existing diagnostic helpers for SWOLF and stroke style conversion when they already express the desired behavior.
- [x] Emit `unknown` only when HealthKit has a style key that cannot be mapped; omit `strokeStyle` when there is no style signal.

### Task 3: Build set metadata from HealthKit segment events

**Files:**

- Modify `VerveExporter/HealthManager.swift`

- [x] Sort `workout.workoutEvents` with `type == .segment` by start date.
- [x] For each segment, find laps whose time interval overlaps the segment interval.
- [x] Convert each segment into `SwimSetMetadata`:
  - `index`: 1-based sorted set index.
  - `startTime`, `endTime`, `durationSeconds`: segment boundaries.
  - `lapStartIndex`: first overlapping lap index when laps overlap.
  - `lapEndIndex`: last overlapping lap index when laps overlap.
  - `lapCount`: count of overlapping laps.
  - `distanceMeters`: sum of overlapping lap distances.
  - `strokeStyle`: the one known style when all overlapping laps agree, `mixed` when known styles differ, omitted when no style is known.
  - `strokeCount`: sum of overlapping lap stroke counts when every included lap has a count.
  - `averageSwolf`: segment `HKSWOLFScore` when present, otherwise average of overlapping lap SWOLF values.
  - `restAfterSeconds`: next segment start minus this segment end when positive.
- [x] Keep set inference deterministic by deriving every set from the already sorted lap objects and their indexes.

### Task 4: Build workout-level swimming summary fields

**Files:**

- Modify `VerveExporter/HealthManager.swift`

- [x] Set `schemaVersion` to `1`.
- [x] Set `lapCount` to the number of exported lap objects when laps are present.
- [x] Set `setCount` to the number of exported set objects when sets are present.
- [x] Set `averageSwolf` to the arithmetic average of lap `swolf` values when at least one lap SWOLF exists.
- [x] Set `strokeStyles` from lap and set styles, excluding `unknown` unless all available styles are `unknown`.
- [x] Return `nil` from `buildSwimmingMetadata` only when the workout is not swimming. For swim workouts with partial data, return a sparse `SwimmingMetadata(schemaVersion: 1, ...)`.

### Task 5: Attach swim metadata to normal Verve exports

**Files:**

- Modify `VerveExporter/HealthManager.swift`

- [x] In `generateGeoJSON(for:)`, build `let swimmingMetadata = buildSwimmingMetadata(for: workout, isoFormatter: formatter)` after formatter setup.
- [x] Pass `metadata: VerveMetadata(swimming: swimmingMetadata)` into `VerveProperties` only when `swimmingMetadata` is non-nil.
- [x] Confirm non-swim exports still encode no `metadata` property.
- [x] Keep `generateDebugJSON(for:)` returning the diagnostic swim JSON for `.swimming`; the debug sheet remains the fallback investigation tool.

### Task 6: Mandatory stop for first phone-tested export

**Files:**

- Modify `docs/exec-plans/active/2026-05-28-implement-swim-metadata-exporter.md`

- [x] Run the generic iOS build command from this plan.
- [x] Stop implementation and ask the user to run the exporter on their phone using the known pool swim.
- [x] Ask for the sanitized Checkpoint A snippet described above.
- [x] Compare the user's phone output against the planned schema and derivation rules.
- [x] Update this plan immediately if real HealthKit output contradicts any planned mapping.
- [x] Do not proceed to Task 7 until Checkpoint A is resolved or explicitly marked blocked.

### Task 7: Correct swimming activity subtype mapping in the exporter

**Files:**

- Modify `VerveExporter/HealthManager.swift`

- [x] Update `mapToVerveActivity(workout:)` for `.swimming` to use HealthKit swimming location type:
  - Pool + `HKMetadataKeyIndoorWorkout == true`: `("Swimming", "Indoor")`.
  - Pool + `HKMetadataKeyIndoorWorkout == false` or missing: `("Swimming", "Outdoor Pool")`.
  - Open water: `("Swimming", "Open Water")`.
  - Unknown location: preserve the current indoor metadata fallback behavior.
- [x] Do not add location type to `metadata.swimming`.
- [x] Add a short code comment only if the HealthKit fallback logic is not obvious from the helper names.

### Task 8: Update format and HealthKit docs

**Files:**

- Modify `docs/product-specs/verve-geojson-format.md`
- Modify `docs/references/healthkit.md`
- Optionally modify `docs/DECISIONS.md` if implementation reveals a durable decision not already captured by the design doc.

- [x] Add a `metadata.swimming` subsection to the Verve GeoJSON product spec with field definitions matching the design doc.
- [x] Update "Current iOS Export Behavior" to say swim metadata export is implemented.
- [x] Remove or revise the "No metadata export is implemented" known-gap line so it remains accurate.
- [x] Add HealthKit mapping notes for lap events, segment events, SWOLF, stroke style, lap length, and aggregate swim stroke count.
- [x] Record that real-device validation is still required for Apple HealthKit swim behavior.

### Task 9: Final phone-tested export review

**Files:**

- Modify `docs/exec-plans/active/2026-05-28-implement-swim-metadata-exporter.md`

- [x] Stop implementation and ask the user to run the final device checks from Checkpoint B.
- [x] Record the user's final device-test result in the progress log.
- [x] If the final device result shows schema or mapping drift, update the plan and return to the relevant implementation task.
- [x] If the user cannot run the final device check, keep the plan active and record manual validation as blocked.

### Task 10: Validate and record completion

**Files:**

- Modify `docs/exec-plans/active/2026-05-28-implement-swim-metadata-exporter.md`
- Move to `docs/exec-plans/completed/2026-05-28-implement-swim-metadata-exporter.md` after implementation is validated.
- Modify `docs/exec-plans/README.md` to move the plan entry from active to completed.

- [x] Run `make validate-docs`.
- [x] Run the generic iOS build command from this plan.
- [x] Run `git diff --check`.
- [x] Run `git status --short` and review changed files.
- [x] Confirm Checkpoint A and Checkpoint B are resolved or explicitly recorded as blocked.
- [x] Move this plan to `docs/exec-plans/completed/` only after code/docs checks pass and manual checks are either complete or explicitly documented as remaining.

## Progress log

- 2026-05-28: Created exporter implementation plan from the swim metadata design document and the real-device diagnostic JSON result.
- 2026-05-28: Added mandatory phone-tested iteration checkpoints so the implementation stops after initial export wiring and again before completion.
- 2026-05-29: Implemented Tasks 1-5 through first swim metadata export wiring. Awaiting compiler validation and Checkpoint A phone-tested JSON before continuing.
- 2026-05-29: Generic iOS build with `OTHER_SWIFT_FLAGS='-disable-sandbox'` succeeded. Stopping at Checkpoint A for phone-tested swim export JSON.
- 2026-05-29: Checkpoint A phone export matched swim metadata expectations: 10 laps, 8 sets, 50 m pool length, 337 total strokes, lap/set SWOLF, stroke styles, inferred lap/set stroke counts, and no location field in `metadata.swimming`. The pool swim still exported as `activitySubType: "Open Water"`, so Task 7 updated subtype mapping to use HealthKit swimming location type.
- 2026-05-29: Updated product and HealthKit docs, then build/docs/whitespace checks passed. Stopping at Checkpoint B for final phone-tested swim and non-swim exports.
- 2026-05-29: Checkpoint B swim export passed: the tested pool swim now exports `activitySubType: "Outdoor Pool"`, still includes `metadata.swimming`, and does not include a location field inside swim metadata. Non-swim phone export check is still pending.
- 2026-05-29: Checkpoint B non-swim export passed with a climbing workout. The export has no root `metadata` object, so `metadata.swimming` is absent for non-swim workouts.
- 2026-05-29: Final validation passed: `make validate-docs`, generic iOS build with `OTHER_SWIFT_FLAGS='-disable-sandbox'`, `git diff --check`, and `git status --short`.

## Decisions

- Use `properties.metadata.swimming` as the only Verve GeoJSON extension point for this work.
- Export source-neutral field names only.
- Keep swimming location type out of `metadata.swimming`; use it only for `activitySubType`.
- Keep backend work out of this implementation plan.
- Keep the existing debug JSON sheet as a diagnostic fallback until real Verve exports are manually verified on device.
- Stop after the first metadata export wiring and align the plan with the user's phone-tested JSON before continuing.

## Questions to resolve

- No blocking questions before implementation.
- After implementation, verify on a real device whether HealthKit segment boundaries always align with Apple Workouts app sets closely enough for the overlap-based set derivation.

## Completion criteria

- Swim workouts export `properties.metadata.swimming` with schema version, pool length, aggregate stroke count, laps, sets, stroke styles, and SWOLF values when HealthKit provides them.
- Non-swim exports are unchanged except for any harmless Codable initializer changes required by the new optional metadata property.
- Swim subtype mapping distinguishes pool swims from open-water swims without putting location type into swim metadata.
- Product and HealthKit docs describe the implemented exporter behavior.
- `make validate-docs`, the generic iOS build command, and `git diff --check` have been run and results are recorded.
- Checkpoint A and Checkpoint B real-device testing status is documented before the plan is moved to completed.

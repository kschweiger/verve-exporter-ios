# Testing And Validation

## Known Safe Commands

```bash
make validate-docs
make xcode-list
make validate-build
make validate
xcodebuild -list -project VerveExporter.xcodeproj
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO build
git status --short
rg <pattern>
```

`make validate-docs` checks required harness files, parses harness metadata, and scans for unresolved template markers. It is the fastest validation target and does not invoke Xcode.

`make validate` runs `make validate-docs` and `make validate-build`.

`xcodebuild -list` completed during bootstrap and found the `VerveExporter` scheme, but the sandbox reported CoreSimulatorService and cache permission warnings. Treat those warnings as environment-specific unless reproduced outside the sandbox.

The signing-disabled generic iOS build command is useful for local compiler validation when provisioning is unavailable. During bootstrap it progressed to Swift compilation but failed inside this sandbox because `swift-plugin-server` could not load SwiftUI/Observation macros and emitted `sandbox-exec: Operation not permitted`. Re-run outside the restricted sandbox before treating that as a source failure.

If the standard sandboxed build fails only because Swift macro/plugin subprocesses cannot run, this local compiler workaround can typecheck the app without changing project settings:

```bash
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='-disable-sandbox' build
```

Use the workaround only as a validation command, not as a committed build setting.

## Test Commands

No XCTest target exists in the repository at bootstrap. Add a test target before relying on automated unit tests.

Recommended first tests:

- Pure Swift encoding tests for `GeoJSON.swift`, especially field names and omission/null behavior.
- Pure mapping tests for HealthKit workout type to Verve `activityType` and `activitySubType` values.
- Export-shape tests using sanitized fixtures, not personal workout files.

## Lint, Format, Typecheck, And Build Commands

Build:

```bash
make validate-build
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO build
```

No SwiftLint, formatter, typecheck-only command, or CI configuration exists at bootstrap.

## Smoke Tests

Manual real-device smoke test:

1. Install/run the app on an iPhone with Health data and HealthKit permission available.
2. Grant read access for workouts, workout routes, and heart rate.
3. Confirm the workout list loads.
4. Open the debug JSON preview for an outdoor workout with GPS and confirm `features[0].geometry.type == "LineString"`.
5. Export/share the JSON and validate it against `docs/product-specs/verve-geojson-format.md`.
6. Test an indoor/no-route workout and confirm the app either exports a no-geometry feature intentionally or reports a clear error.

## Expensive Or Unsafe Checks

- Do not run tests that export, upload, or commit real personal workouts without explicit approval.
- Do not reset simulator/device Health data without explicit approval.
- Do not change signing/provisioning settings as part of validation unless the task is specifically about signing.

## Validation Before Completion

Before claiming work is complete, run the safest relevant commands above. If a command cannot be run, explain why and record the gap in `docs/QUALITY_SCORE.md` or `docs/exec-plans/tech-debt-tracker.md`.

## Unknowns To Confirm

- A stable local or CI destination for repeatable builds and tests.
- Whether the project should add a unit test target now or wait until the export model is refactored.
- How to create representative sanitized workout fixtures without exposing personal HealthKit data.

# Testing And Validation

## Known Safe Commands

```bash
make validate-docs
make validate-lint
make xcode-list
make validate-build
make validate
xcodebuild -list -project VerveExporter.xcodeproj
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO build
git status --short
rg <pattern>
```

`make validate-docs` checks required harness files, parses harness metadata, and scans for unresolved template markers. It is the fastest validation target and does not invoke Xcode.

`make validate-lint` runs `uvx pre-commit run -a`, including SwiftFormat,
SwiftLint, and plutil checks. The local `swiftformat` and `swiftlint`
executables must be available on `PATH`.

`make validate` runs documentation, lint, and generic iOS build validation.

`xcodebuild -list` completed during bootstrap and found the `VerveExporter` scheme, but the sandbox reported CoreSimulatorService and cache permission warnings. Treat those warnings as environment-specific unless reproduced outside the sandbox.

The signing-disabled generic iOS build command is useful for local compiler validation when provisioning is unavailable. During bootstrap it progressed to Swift compilation but failed inside this sandbox because `swift-plugin-server` could not load SwiftUI/Observation macros and emitted `sandbox-exec: Operation not permitted`. Re-run outside the restricted sandbox before treating that as a source failure.

If the standard sandboxed build fails only because Swift macro/plugin subprocesses cannot run, this local compiler workaround can typecheck the app without changing project settings:

```bash
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS='-disable-sandbox' build
```

Use the workaround only as a validation command, not as a committed build setting.

## Test Commands

`VerveExporterTests` exercises the export builder and swim diagnostic JSON with invented workouts, routes, heart-rate samples, and swimming events. It does not save samples to HealthKit or read personal Health data. Run it on an available iOS simulator:

```bash
xcrun simctl list devices available
make test TEST_DESTINATION='platform=iOS Simulator,id=<simulator-UUID>'
make test-coverage TEST_DESTINATION='platform=iOS Simulator,id=<simulator-UUID>'
```

Xcode's Product > Test also runs the suite on the selected simulator or device. Prefer a simulator so test runs remain separate from a personal Health store. The test target is hosted by the iOS app; it cannot run as a macOS unit test. `make validate` remains simulator-independent and runs docs, lint, and generic iOS build checks.

`make test-coverage` enables Xcode coverage, saves a uniquely named `.xcresult`
bundle under `/private/tmp`, and prints the app and test target coverage summary.
The app target percentage measures app code; the test target percentage measures
the test code itself. Set `COVERAGE_RESULT_BUNDLE=/path/to/result.xcresult` to
choose a specific output path; that path must not already exist.

Automated export coverage:

- Route coordinates, timestamp and heart-rate alignment, and required duration.
- Nearest heart-rate matching at the strict 30-second boundary and stats from matched values.
- No-route heart-rate output and rejection of workouts with no route or heart-rate samples.
- Synthetic swimming lap/set metadata, ordering, rest intervals, mixed styles, and incomplete inputs.
- Swim diagnostic event grouping and metadata representation.
- Indoor/outdoor activity mapping and workout time-zone selection with fallback, recorded IANA timezone encoding, and omission of missing or fixed-offset timezone metadata.
- At least two spatial positions; ordinary HealthKit-style altitude-only CLLocation inputs converted by `h = H + N`; valid negative/zero derived heights; invalid/nonfinite altitude, accuracy, coordinates, or conversion values; route errors even with heart-rate samples; and no second conversion of verified heights.
- Offline PGM parsing/interpolation, both poles and periodic longitude, exact binary-raster boundaries, twelve independent public NGA synthesis vectors, immutable bundled-grid checksum and actual app packaging, missing/corrupt model errors, and no geoid lookup for non-spatial exports.
- Active energy remains numerically unchanged in kcal.
- Fractional swimming distances/durations, internal pauses, zero subsequent gaps, meaningful zero scalars, unavailable-only metadata, detail arrays without counts, deterministic equal-start ordering, inclusive lap references, boundary-touching and noncontiguous overlap selections.
- Conservative lap-derived set SWOLF averages, missing pool length, unexplained fractional inference, and out-of-range individual/set stroke-count arithmetic without crashing.

`HKWorkout` rejects an invalid `HKMetadataKeyTimeZone` value at construction, so synthetic tests cover a missing time zone fallback. Invalid persisted metadata still uses the same fallback branch in the exporter.

The test input uses in-memory HealthKit objects. Real HealthKit authorization, saved-route queries, and device-specific workout data still need the manual smoke test below.

## Lint, Format, Typecheck, And Build Commands

Lint and format:

```bash
uvx pre-commit run -a
```

The repository hooks run SwiftFormat in lint mode and SwiftLint with strict
warnings, along with YAML, whitespace, conflict-marker, symlink, and Apple
property-file checks. SwiftFormat uses `.swiftformat`; the local `swiftformat`
and `swiftlint` executables must be available on `PATH` because these hooks use
the pre-commit `unsupported` environment. Run them directly with
`uvx pre-commit run -a` or through `make validate-lint`.

In a read-only agent sandbox, `make validate-lint` can fail before hooks run
because `uvx` cannot access its cache. Re-run outside that sandbox when allowed.

Pre-commit's `-a` option checks tracked files only. Until new Swift files are tracked, also check them explicitly:

```bash
swiftformat VerveExporter VerveExporterTests --lint --cache ignore
swiftlint lint --quiet --strict VerveExporter VerveExporterTests
```

The iOS test target uses invented in-memory inputs and requires no HealthKit data. The hosted app can log missing-entitlement/authorization messages in signing-disabled simulator runs; those do not indicate test data was saved. Existing test-only deprecated HKWorkout construction is retained to avoid writing samples through HKWorkoutBuilder.

GeoidGridTests additionally uses twelve public NGA-generated reference points, unrelated to personal workouts. Their expected EGM2008 heights come from independent harmonic synthesis, not the implementation under test; the comparison tolerance is 0.5 m, covering the selected grid's reported interpolation error. Provenance and checksums are in `../VerveExporter/Resources/Geoid/README.md`. General route tests inject known geoid corrections and construct ordinary CLLocation instances; the test that exercises production loading uses the actual app-bundled model. Do not reintroduce an overridden ellipsoidalAltitude fixture as evidence of HealthKit persistence.

Build:

```bash
make validate-build
xcodebuild -project VerveExporter.xcodeproj -scheme VerveExporter -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath /private/tmp/VerveExporter-DerivedData CODE_SIGNING_ALLOWED=NO build
```

`make validate` runs documentation, pre-commit lint, and generic iOS build validation. It does
not run XCTest. No typecheck-only command or CI configuration
exists at bootstrap.

## Smoke Tests

Manual real-device smoke test:

1. Install/run the app on an iPhone with Health data and HealthKit permission available.
2. Grant read access for workouts, workout routes, and heart rate.
3. Confirm the workout list loads.
4. Open the debug JSON preview for an outdoor workout with GPS and confirm `features[0].geometry.type == "LineString"`.
5. Export/share the JSON and validate it against `docs/product-specs/verve-geojson-format.md`.
6. Test an indoor/no-route workout and confirm the app either exports a no-geometry feature intentionally or reports a clear error.
7. With safe synthetic inputs or an approved local workout, confirm one-point/invalid-elevation routes show the specific failure reason, dismiss the preparing sheet, and do not open the share sheet. Start another export to confirm previous error text is cleared.
8. Re-export a locally approved outdoor workout and confirm elevation retains variation after geoid correction. Expect ellipsoidal heights to differ from the earlier sea-level export. Check the first cold export and offline operation on device; do not upload or commit the resulting personal file.

Activity browser smoke check on a device with several workout types and months:

1. Confirm the newest workout appears once in `Latest activity` with the same compact export icon as history rows; the first screen shows at most ten workouts.
2. Select a Verve activity type whose newest workout is older than the newest ten overall. Confirm the newest matching workout appears first and all visible rows match the selected type.
3. Confirm month headings match the local calendar, then use `Show more` to reveal up to ten additional matching workouts.
4. Clear the active filter with the one-tap clear button. Confirm `All activities` and the newest ten workouts return.
5. Select a type with no workouts, if available, and confirm the empty state offers `Clear filter`.
6. Pull to refresh and confirm the current filter remains selected and the list resets to ten workouts.

## Expensive Or Unsafe Checks

- Do not run tests that export, upload, or commit real personal workouts without explicit approval.
- Do not reset simulator/device Health data without explicit approval.
- Do not change signing/provisioning settings as part of validation unless the task is specifically about signing.

## Validation Before Completion

Before claiming work is complete, run the safest relevant commands above. If a command cannot be run, explain why and record the gap in `docs/QUALITY_SCORE.md` or `docs/exec-plans/tech-debt-tracker.md`.

## Unknowns To Confirm

- A CI runner with an available iOS simulator destination.
- A separate opt-in simulator integration test that writes synthetic workouts and routes to a dedicated simulator HealthKit store.

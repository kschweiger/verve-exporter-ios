# Export Test Execution Plan

## Goal

Make Verve GeoJSON export behavior repeatably testable with invented workout data, without writing to HealthKit.

## Work

1. Add an XCTest target and synthetic export scenarios for route, heart rate, swimming, time zones, and empty input.
2. Extract export construction from `HealthManager` so tests can supply workout, route, and heart rate values in memory.
3. Correct the moving-duration key and reject exports with no features.
4. Document fixtures, test commands, and the remaining real-device HealthKit boundary.

## Validation

- `make validate-docs`
- `make validate-build`
- Simulator XCTest suite when a simulator is available.
- `git diff --check`

## Safety

Use only invented dates, locations, and measurements. Do not write, export, or delete personal HealthKit data.

## Result

- Added an app-hosted XCTest target with seven synthetic export tests.
- Extracted in-memory export construction from HealthKit queries and file writing.
- Fixed the moving-duration key and rejected workouts with no exportable samples.
- `make validate-docs`, `make validate-build`, and `git diff --check` passed.
- The iPhone 17 Pro iOS 26.3 simulator result bundle reported 7 passed, 0 failed on 2026-09-27.
- The test fixture uses a deprecated in-memory `HKWorkout` initializer; Xcode warns about it, but the suite passes. Saved HealthKit integration remains future work.

Follow-up: `2026-09-27-omit-moving-duration.md` removes the field added in this plan after confirming it overrode the Python importer's track-derived moving time.

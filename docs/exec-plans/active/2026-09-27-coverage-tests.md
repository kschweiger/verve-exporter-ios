# Coverage Test Expansion

## Goal

Increase useful app coverage with synthetic tests for swim diagnostics, swimming edge cases, route heart-rate boundaries, activity mapping, and time-zone fallback.

## Context

The baseline `make test-coverage` run passed 7 tests and reported 40.31% (678/1682) app coverage. Swim diagnostics, UI views, and HealthKit queries account for most uncovered lines. This plan focuses on deterministic export and diagnostic logic; saved HealthKit and UI integration remain separate work.

## Constraints

- Use invented in-memory HealthKit objects only. Do not save or export personal workouts.
- Preserve the documented Verve GeoJSON and swimming metadata contracts.
- Add tests without changing app behavior or Xcode project settings.

## Files Likely To Change

- `VerveExporterTests/ExportTests.swift`
- `VerveExporterTests/SwimDiagnosticTests.swift`
- Documentation indexes and test guidance if the test inventory changes.

## Validation Commands

- `make test-coverage TEST_DESTINATION='platform=iOS Simulator,id=34DD5E26-AB65-4A76-AE2E-3E742644ADB5'`
- `make validate-docs`
- `make validate-lint`
- `git status --short`

## Progress Log

- Baseline coverage: 7 tests passed; app 40.31% (678/1682).

## Decisions

- Prioritize synthetic export and diagnostic behavior; UI and saved HealthKit tests need dedicated seams and are outside this change.

## Questions To Resolve

- None.

## Completion Criteria

- The new tests assert the planned behavior, pass on an iOS simulator, and increase app coverage from baseline.
- The execution plan moves to `completed/` with validation results recorded.

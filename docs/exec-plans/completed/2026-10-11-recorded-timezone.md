# Recorded activity timezone

## Goal
Export optional root `properties.timezone` from valid IANA workout metadata.

## Context
The backend accepts an optional IANA timezone. Existing export timestamps already use workout timezone metadata with a device timezone fallback.

## Constraints
Use only recorded metadata for the root timezone. Omit missing, invalid, or non-IANA names; never label the device fallback as the recorded timezone. Preserve timestamp and filename behavior. Use synthetic in-memory inputs only.

## Files likely to change
GeoJSON.swift, HealthManager.swift, ExportTests.swift, format and HealthKit references, decision log, testing docs, and corresponding documentation indexes.

## Validation commands
Synthetic XCTest suite on an available simulator; make validate-docs; make validate-lint; make validate-build.

## Progress log
- Design approved in conversation. Repository context and backend schema reviewed.
- Added assertions for recorded timezone, UTC, missing metadata, and fixed-offset names before implementation.
- Simulator run failed only the new Berlin and UTC timezone assertions, as expected.
- Added optional export model property and workout metadata validation; updated contract and API references.

## Decisions
Validate metadata against Foundation known timezone identifiers, with explicit UTC support, before emitting the original identifier.

## Questions to resolve
None.

## Completion criteria
Valid recorded IANA timezone is encoded; absent or unsupported values are omitted; existing timestamp fallback remains intact; validation results documented.

## Validation results

- Full synthetic XCTest suite: 16 tests passed on iOS 26.3 iPhone 17 Pro. The pre-implementation run failed the new Berlin and UTC assertions as expected.
- `make validate-build`: passed with signing disabled.
- `make validate-docs`: passed.
- `make validate-lint`: SwiftLint and property-file checks passed; SwiftFormat failed only existing single-line property bodies in WorkoutBrowserModel.swift lines 16 and 17. Changed Swift files passed formatting. Recorded as TD-006.
- `git diff --check`: passed.
- Signed device HealthKit integration was not exercised; simulator host logs a missing entitlement warning, while all in-memory tests pass.

## Outcome
Implemented recorded IANA timezone encoding, omission of absent or non-IANA metadata, and synthetic coverage. Timestamp and filename fallback behavior remains unchanged.

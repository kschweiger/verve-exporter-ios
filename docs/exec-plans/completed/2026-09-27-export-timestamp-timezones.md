# Export Timestamp Timezones

## Goal

Export workout timestamps with the local UTC offset for the workout's HealthKit time zone, falling back to the device's current time zone.

## Context

The iOS exporter currently uses an `ISO8601DateFormatter` without a time zone, so it writes UTC timestamps. The Verve schema accepts ISO-8601 timestamps with offsets. The agreed design changes timestamp representation without changing the instant or adding a schema field.

## Constraints

- Prefer a valid `HKMetadataKeyTimeZone` identifier from the workout; otherwise use `TimeZone.current`.
- Use one selected time zone across root, route, heart-rate, swim lap, swim set, and filename dates. Let the offset vary by timestamp date under daylight saving rules.
- Do not export or commit real workout data during validation.

## Files Likely To Change

- `VerveExporter/HealthManager.swift`
- `docs/product-specs/verve-geojson-format.md`, `docs/references/healthkit.md`, `docs/DECISIONS.md`, and their indexes.

## Validation Commands

- `make validate-docs`
- `make validate-build`
- `git diff --check`

## Progress Log

- 2026-09-27: Plan created before implementation.
- 2026-09-27: Export uses the workout time zone or current device time zone for all GeoJSON timestamps and the filename date; format, HealthKit, decision, and index docs updated.
- 2026-09-27: `make validate-docs`, `make validate-build`, `make validate`, and `git diff --check` passed. The iOS build was run outside the read-only sandbox because Xcode needed to write DerivedData.
- 2026-09-27: A Foundation-only formatter check confirmed winter `+01:00`, summer `+02:00`, offsets on both sides of a daylight saving transition, unchanged parsed instants, and invalid-zone fallback eligibility. Real-device HealthKit export inspection was not run because no sanitized workout was provided.

## Decisions

- Emit local ISO-8601 offsets; do not add a separate time zone field.
- Use the current device time zone when HealthKit time zone metadata is absent or invalid.

## Questions To Resolve

- None.

## Completion Criteria

- All exported timestamp paths use the selected time zone and preserve their original instants.
- Export filenames use the same time zone as the exported timestamps.
- Format and HealthKit docs, decision log, and indexes reflect the behavior.
- Repository validation commands have been run and results recorded.
- Move this plan to `completed/` and update the execution-plan index.

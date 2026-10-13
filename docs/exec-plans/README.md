# Execution Plans

Execution plans are durable work plans for larger or riskier changes.

Small changes may use a lightweight plan in the agent session. Larger changes, multi-step work, architecture changes, HealthKit changes, or export format changes should create a plan under `active/` before implementation and move it to `completed/` when done.

## Plan Structure

Use this structure:

```text
Goal
Context
Constraints
Files likely to change
Validation commands
Progress log
Decisions
Questions to resolve
Completion criteria
```

## Current Active Plans

- `active/2026-09-27-coverage-tests.md`: Add synthetic tests for export edge cases and swim diagnostics, then compare coverage with the baseline.

## Completed Plans

- `completed/2026-10-13-healthkit-elevation-conversion.md`: Corrected persisted HealthKit height provenance with offline EGM2008 conversion, checksum-pinned public data, ordinary-location regressions, and 57 passing tests.

- `completed/2026-10-13-exporter-release-conformance.md`: Aligned routes, swimming derivations, specific export errors, fixtures, and docs with Verve GeoJSON 1.0; 37 synthetic tests and docs/lint/build checks passed.

- `completed/2026-10-11-recorded-timezone.md`: Exported recorded IANA workout timezone; documented synthetic tests and the existing formatting gap.

- `completed/2026-09-28-activity-browser.md`: Added recent workout browsing, Verve type filtering, month grouping, and incremental reveal.
- `completed/2026-09-27-pre-commit-lint-cleanup.md`: Aligned SwiftFormat and SwiftLint settings and refactored existing Swift code to satisfy the new hooks without changing app behavior.
- `completed/2026-09-27-omit-moving-duration.md`: Omitted both moving-time keys from new iOS exports and recorded the missing source as technical debt.
- `completed/2026-09-27-export-tests.md`: Added synthetic export XCTest coverage and rejected empty exports; the moving-duration key change was subsequently superseded.
- `completed/2026-09-27-export-timestamp-timezones.md`: Exported workout timestamps with local offsets from the workout time zone or current device time zone.
- `completed/2026-05-28-implement-swim-metadata-exporter.md`: Implemented source-neutral swimming lap, set, stroke, pool length, and SWOLF metadata export in the iOS exporter.
- `completed/2026-06-01-swim-metadata-envelope.md`: Updated swim metadata export to use the canonical metadata envelope.
- `completed/2026-06-10-direct-export-share-sheet.md`: Replaced the intermediate export `ShareLink` overlay with a native share sheet presented directly after GeoJSON generation.
- `completed/2026-06-11-first-export-preparing-sheet.md`: Added an immediate preparing sheet for the first cold export before automatically transitioning to the native share sheet.

## Directories

- `active/`: Plans currently being executed.
- `completed/`: Finished plans retained for future agents.
- `tech-debt-tracker.md`: Known debt and quality gaps; TD-006 browser property formatting is now resolved.

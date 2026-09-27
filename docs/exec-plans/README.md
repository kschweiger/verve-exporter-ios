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

- None.

## Completed Plans

- `completed/2026-09-27-export-timestamp-timezones.md`: Exported workout timestamps with local offsets from the workout time zone or current device time zone.
- `completed/2026-05-28-implement-swim-metadata-exporter.md`: Implemented source-neutral swimming lap, set, stroke, pool length, and SWOLF metadata export in the iOS exporter.
- `completed/2026-06-01-swim-metadata-envelope.md`: Updated swim metadata export to use the canonical metadata envelope.
- `completed/2026-06-10-direct-export-share-sheet.md`: Replaced the intermediate export `ShareLink` overlay with a native share sheet presented directly after GeoJSON generation.
- `completed/2026-06-11-first-export-preparing-sheet.md`: Added an immediate preparing sheet for the first cold export before automatically transitioning to the native share sheet.

## Directories

- `active/`: Plans currently being executed.
- `completed/`: Finished plans retained for future agents.
- `tech-debt-tracker.md`: Known debt, quality gaps, and follow-up work.

# Swim Debug Probe

## Goal

Add a minimal on-device diagnostic view for HealthKit swimming lap, segment, and activity data inside the existing debug JSON sheet.

## Context

The Verve exporter currently exports selected workouts as Verve GeoJSON. Swimming export should not be extended until we verify what Apple HealthKit actually exposes for the user's recorded swim workouts. Research points to `HKWorkout.workoutEvents`, lap and segment event metadata, workout-level swim metadata, `HKWorkout.workoutActivities`, and interval statistics for swimming distance and stroke count.

Backend swim metadata already has a compact shape in `/Users/korbinian/Code/verve/backend/verve_backend/core/meta_data.py`: `SwimmingMetaData` contains `segments`, each segment has `count`, `lap_lengths`, `style`, and `duration`. This probe should gather enough HealthKit data to decide whether that model can be populated cleanly later.

## Constraints

- Do not change the Verve GeoJSON export schema in this slice.
- Do not add backend upload or network behavior.
- Do not commit real HealthKit exports or personal workout data.
- Keep the probe small enough to remove or replace after schema design.
- Automated XCTest coverage is not practical yet because the repository has no test target and the useful behavior depends on real HealthKit data.

## Files likely to change

- `VerveExporter/DebugView.swift`: choose swim diagnostics for swimming workouts in the debug JSON sheet.
- `VerveExporter/HealthManager.swift`: add a read authorization for swimming stroke count and expose a diagnostic JSON generator for selected swim workouts.
- `docs/references/healthkit.md`: document any implementation details or follow-up findings.
- `docs/exec-plans/active/2026-05-28-swim-debug-probe.md`: track progress.

## Validation commands

- `make validate-docs`
- `make validate-build`
- Manual real-device test: open a swimming workout's debug sheet and inspect whether lap, segment, stroke-style, activity, pool-length, distance, and stroke-count values appear.

## Progress log

- 2026-05-28: HealthKit swim API research recorded in `docs/references/healthkit.md`.
- 2026-05-28: User chose the existing debug JSON sheet as the first verification path.
- 2026-05-28: Added a swim-only diagnostic JSON branch to the existing debug sheet.
- 2026-05-28: Generic iOS build succeeds with `OTHER_SWIFT_FLAGS='-disable-sandbox'`; the default sandboxed build still hits the known Swift macro/plugin sandbox issue.
- 2026-05-28: `make validate-docs` and `git diff --check` pass.
- 2026-05-28: Manual real-device swim inspection confirmed HealthKit lap events, segment events, lap stroke-style metadata, lap/segment SWOLF metadata, pool length, swim location type, swimming distance, and swimming stroke count.

## Decisions

- Use the existing Debug JSON sheet first.
- Fall back to a separate shareable diagnostic JSON file only if the sheet is insufficient for device inspection.
- Prefer a raw-but-readable diagnostic payload over a polished Verve swim schema for this slice.

## Questions to resolve

- Open-water swim behavior still needs a separate device check.
- Segment stroke style should be inferred from overlapping laps unless future samples prove segment-level stroke metadata exists.
- Verve schema design needs to decide whether to preserve raw laps, segment summaries, or both.

## Completion criteria

- Existing debug sheet shows Verve GeoJSON for non-swim workouts.
- Existing debug sheet shows swim diagnostic JSON for swim workouts.
- Diagnostic JSON includes enough structure to verify lap and segment availability on an iPhone.
- Safe validation commands have been run or their failure mode is documented.
- The real-device pool-swim result has been summarized in `docs/references/healthkit.md`.

# Technical Debt Tracker

Track known debt and follow-up work here when it is too durable to leave only in chat.

| ID | Area | Problem | Impact | Suggested fix | Owner or agent | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TD-001 | Bootstrap | Confirm repository-specific unknowns recorded during bootstrap. | Future agents may lack complete local guidance until unknowns are resolved. | Review `ARCHITECTURE.md`, `docs/TESTING.md`, `docs/SECURITY.md`, and `docs/QUALITY_SCORE.md` after first real development task. | Future agent | Open |
| TD-002 | Export format | Swift encodes `movingDistanceSeconds`, but Verve backend expects `movingDurationSeconds`. | Imports may miss moving duration from iOS exports. | Rename the Swift property/coding key and add an encoding test. | Future agent | Open |
| TD-003 | Testing | No XCTest target or sanitized fixtures exist. | Export compatibility depends on manual testing with personal workouts. | Add a unit test target and fixture policy, then test `GeoJSON.swift` independently of HealthKit. | Future agent | Open |
| TD-004 | HealthKit | Cadence, power, speed, elevation gain/loss, and multiple-route handling are not documented or implemented. | Export may omit useful metrics or mishandle edge cases. | Research each metric in HealthKit docs and update `docs/references/healthkit.md` before implementation. | Future agent | Open |

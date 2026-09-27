# Technical Debt Tracker

Track known debt and follow-up work here when it is too durable to leave only in chat.

| ID | Area | Problem | Impact | Suggested fix | Owner or agent | Status |
| --- | --- | --- | --- | --- | --- | --- |
| TD-001 | Bootstrap | Confirm repository-specific unknowns recorded during bootstrap. | Future agents may lack complete local guidance until unknowns are resolved. | Review `ARCHITECTURE.md`, `docs/TESTING.md`, `docs/SECURITY.md`, and `docs/QUALITY_SCORE.md` after first real development task. | Future agent | Open |
| TD-002 | Export format | Swift encoded `movingDistanceSeconds`, which the Verve backend ignored. | The old field did not supply moving duration. | Removed both moving-time fields from new iOS exports; see TD-005 for a supported value. | Completed | Closed |
| TD-003 | Testing | No XCTest target or sanitized fixtures existed. | Export compatibility depended on manual testing with personal workouts. | Added an iOS test target with invented in-memory workout inputs. Saved HealthKit integration testing remains separate. | Completed | Closed |
| TD-004 | HealthKit | Cadence, power, speed, elevation gain/loss, and multiple-route handling are not documented or implemented. | Export may omit useful metrics or mishandle edge cases. | Research each metric in HealthKit docs and update `docs/references/healthkit.md` before implementation. | Future agent | Open |
| TD-005 | Export format | The iOS exporter has no verified moving-duration source. | Supplying total workout duration as moving time overrides the Python importer's track-derived value; omitting it leaves stationary moving time unset. | Investigate HealthKit pause and activity timing semantics, choose a defined moving-duration source, then add export and backend compatibility tests before emitting `movingDurationSeconds`. | Future agent | Open |

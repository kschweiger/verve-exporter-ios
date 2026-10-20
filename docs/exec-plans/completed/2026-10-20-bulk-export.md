# Bulk Export Execution Plan

## Goal

Implement the approved [bulk export behavior](../../product-specs/bulk-export.md).

## Context and constraints

Reuse HealthManager and ActivityView. No export schema, permissions, dependencies, signing, or project setting changes. Use invented inputs only. Preserve unrelated untracked user files.

## Files likely to change

ContentView and dedicated batch model/views; HealthManager and a focused file writer; synthetic XCTest files; architecture, product, testing, security and documentation indexes.

## Tasks

- [x] Record product behavior and execution plan.
- [x] Add failing synthetic tests for selection, batch outcomes, cancellation and file isolation.
- [x] Implement sequential model and collision-safe atomic file writing.
- [x] Integrate selection, progress, failure results and multi-file sharing.
- [x] Run tests, docs/lint/build checks and review changes.
- [x] Record validation gaps, move plan to completed and update indexes.

## Validation commands

make validate; make test TEST_DESTINATION='platform=iOS Simulator,id=<available-UUID>'; explicit SwiftFormat and SwiftLint checks for new files.

## Progress log

- 2026-10-20: Approved chat plan; implementation started with read-only project inspection.

## Decisions

Selection stays in current filter; share separate JSON files; retain successful files after per-workout failures. Cancellation stops between workouts and suppresses late presentation. No unresolved product questions.

## Completion criteria

Approved behavior is implemented, synthetic tests and safest relevant validation run, and limitations documented. Real-device UI/HealthKit checks remain manual unless a configured approved device is available.

- 2026-10-20: Initial XCTest build failed on missing batch types. Implemented the model, writer, and UI; explicit SwiftLint and SwiftFormat checks passed. First runtime run exposed an iOS 26.3 actor-deinit crash in synchronous XCTest invocation; converted that test to async and reran, with concurrent retry and file-write failure coverage added.

- 2026-10-20: All 64 synthetic tests passed on iOS 26.3 after ensuring the actor test actually suspends (SwiftFormat removes unused async declarations). `make validate` and explicit all-source lint/format checks passed. Independent review found no processing defects; aligned file cleanup with SwiftUI onDismiss, keeping browser controls disabled through dismissal to prevent a retry race. Device sharing/accessibility checks remain manual and are recorded in QUALITY_SCORE.

- 2026-10-20: Final `make validate` passed after correcting SwiftLint's multiple-closure style. Explicit all-source lint/format checks passed. Final sequential XCTest rerun passed all 64 tests with zero failures; a preceding launch-only simulator Busy failure resolved without device reset. `git diff --check` passed. Completed the plan; no real workout files were read or exported.

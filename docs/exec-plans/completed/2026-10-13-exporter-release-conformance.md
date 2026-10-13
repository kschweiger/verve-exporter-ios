# Verve GeoJSON 1.0 exporter implementation plan

## Goal

Implement `docs/exporter-release-changes.md` against the unified core and swimming 1.0 contracts. Execute inline using the executing-plans and test-driven-development skills.

## Context

Follow-up correction: real-device feedback exposed zero ellipsoidalAltitude on stored HealthKit routes. The earlier overridden location fixture did not validate that storage boundary. The direct-property and nonnegative-accuracy decisions in this historical plan are superseded by `2026-10-13-healthkit-elevation-conversion.md`; the earlier passing test results remain historical evidence, not proof of persisted elevation provenance.

The unified source specifications are in `/Users/korbinian/Code/verve/geojson-flavor/src/content/docs/specification/`. At the start of this work, the exporter used sea-level altitude, accepted one-position routes, rounded inferred swimming stroke counts, and accepted unqualified segment SWOLF as an average.

## Constraints

- Keep `verveVersion: "1.0"` and swimming envelope version `"1.0"`.
- Keep energy in kcal, route order, explicit null geometry, required `coordTimes`, aligned sensor placeholders, offset-qualified timestamps, and recorded timezone/fallback distinction.
- Do not add summary-only export, speed/cadence export, permissions, dependencies, uploads, signing changes, or backend changes.
- Only invented in-memory HealthKit/location fixtures; never save samples to HealthKit or use personal exports.
- Leave the unrelated untracked screenshot untouched.

## Files likely to change

Export construction, export error handling, synthetic XCTest fixtures, core/swimming specs, HealthKit references, testing notes, decision log, and corresponding documentation indexes. The Xcode project uses synchronized source groups and needs no rewrite for new test files.

## Tasks

- [x] 1. Align core/swimming documentation with unified specs and correct examples; register this plan and the handoff.
- [x] 2. Add failing route/energy regression tests, then make `WorkoutFeatureBuilder.build` throwing and propagate errors through `HealthManager.buildGeoJSON`. Reject nonempty routes with fewer than two points. Require finite ellipsoidal height and finite nonnegative vertical accuracy. Export the height directly, including zero/negative values. Add routeTooShort and invalidElevation(pointIndex:) errors.
- [x] 3. Show the localized export error in the existing workout-row alert, clearing old error state when a new export starts. Keep file writes after successful construction.
- [x] 4. Add failing swimming regressions, then preserve fractional distances, zeros, elapsed duration, and meaningful-data checks. Keep stable chronological array indices and valid inclusive ranges; omit references for unavailable/noncontiguous selected laps. Export known zero gaps, omit overlapping/final gaps. Infer standard length-based lap strokes only with positive known pool length and finite nonnegative integer-valued subtraction within 0.000001 numerical tolerance, checking Int representability. Derive set SWOLF from available included lap scores; omit it without scores. Preserve complete-sum checks.
- [x] 5. Run docs, lint, generic build, and full synthetic simulator tests. Review the diff, update durable decisions/testing notes and indexes, and move this plan to completed when available automated checks pass.

## Validation commands

```bash
make validate-docs
make validate-lint
make validate-build
xcrun simctl list devices available
make test TEST_DESTINATION='platform=iOS Simulator,id=DF525E3A-90A3-4136-AB2C-7B1634F41B81'
```

Use local-only `.agent-local/exporter-release/` for validation logs. Document missing device checks and unavailable commands. Do not erase simulator or DerivedData state.

## Review focus and tests

- One-position route even with heart-rate data: reject before encoding/file writing.
- Sea-level and ellipsoidal heights differ: output only ellipsoidal height, no double conversion; test zero/negative/invalid heights and accuracy.
- Set overlap produces noncontiguous lap indices: omit invalid references; test boundary-touching intervals and absent lap details.
- SWOLF arithmetic is fractional or overflows Int: preserve score but omit invented count; test finite, fractional, negative and representability cases.
- Internal pauses, zero adjacent gap, fractional interval precision: retain elapsed durations and valid offset timestamps; omit overlapping/final rest.

## Decisions

- User selected derivation from available lap SWOLF values instead of using unqualified segment scores.
- Ruling: use the existing `refactor/finalize-schema` feature branch and this repo-local plan as the durable progress ledger; local logs live in `.agent-local/` per repository guidance. The initial handoff left changes uncommitted; the user subsequently requested a commit on this branch.
- Ruling: split additional conformance tests into focused extension files and share existing synthetic helpers, avoiding oversized test files or Xcode project changes.

## Progress log

- 2026-10-13: Planning baseline `make validate-docs` passed despite sandbox cache warnings. No production code changed yet. Available iOS 26.3 simulator chosen for synthetic tests.

## Completion criteria

All handoff checks covered by code, corrected docs, or explicit retained capability limits; full automated checks pass; plan and indexes updated. Real-device authorization/query behavior and UI sharing/error smoke checks must be reported separately if unavailable.

- Route RED: full suite ran 21 tests with 10 expected assertion failures: sea-level height output, missing one-point rejection, and missing elevation validation. The 250 kcal preservation fixture passed. Added throwing validation and specific UI error propagation; GREEN validation pending.
- File modifications after the user's 2026-10-13 correction use `apply_patch`.
- Route GREEN: full synthetic simulator suite passed, 21 tests and zero failures (`route-green.log`). The app compiled with specific alert-error propagation; real-device alert/share smoke checks remain unperformed.
- Swimming RED: 35 tests ran with nine expected assertions and no unexpected failures after correcting a fixture that HealthKit rejected. Missing zero gaps, unstable equal-start ordering, noncontiguous ranges, unqualified segment averages, unknown-pool stroke inference, and fractional rounding are reproduced in `swimming-red.log`.
- Durable finding: HealthKit rejects synthetic pool workouts lacking a valid pool length; missing-length fixtures must leave the location type unspecified rather than claim a pool swim.
- Isolated overflow RED: an invented SWOLF value above Int.max crashed the old unchecked Int conversion (`swimming-overflow-red.log`). The builder now checks finite arithmetic, integer precision, and Int representability before conversion. Swimming GREEN validation pending.
- Swimming GREEN: the full suite passed 36 tests with zero failures (`swimming-green.log`), including the overflow regression. Documentation validation passed. Initial lint identified known TD-006 plus ContentView exceeding the 400-line limit; wrapped the browser property and removed stale comments without changing behavior. Untracked test lint is checked explicitly.
- Independent final review found an Important aggregate overflow: two individually representable lap stroke counts can overflow a set total. Added a two-lap/one-set regression before fixing the sum.
- Final review: optional zero-vertical-accuracy and identical-start/end ordering assertions deferred; current behavior was confirmed by inspection. Negative inferred subtraction is already asserted by testSwimmingSetOmitsInferredDistanceAndStrokeCountWhenLapInputsAreMissing.
- Final ruling: retain explicitly excluded multiple-route/summary-only capabilities and historical raw-source numeric conversion paths. Saved HealthKit semantics and actual UI presentation require separate device smoke checks; they cannot be established by these synthetic tests. These boundaries remain documented limitations rather than conformance claims.
- Final review fix RED: isolated set-total regression crashed the exporter (`set-overflow-red.log`, TEST FAILED). Replaced unchecked addition with addingReportingOverflow, omitting an unrepresentable set stroke total. Full GREEN suite pending. Five complete synthetic doc examples parsed and passed structure, offset, array alignment, and lap-reference checks.
- Final GREEN: 37 tests passed with zero failures on iOS 26.3 (`tests-final.log`, TEST SUCCEEDED). Both individual and aggregate overflow regressions now pass. Generic signing-disabled iOS build passed (`build.log`, BUILD SUCCEEDED). Repository pre-commit checks passed (`lint-final.log`); explicit SwiftFormat and SwiftLint checks passed for all 14 Swift files, including untracked tests. Diff whitespace check passed.
- Completion: implementation and available automated validation are complete. The user authorized a follow-up commit on the existing branch. No push, package/project rewrite, saved HealthKit input, or personal workout export was performed. Device authorization/query behavior and actual alert/share-sheet presentation remain unverified manual checks. Optional extra zero-accuracy and identical-boundary regression assertions remain deferred as recorded above.

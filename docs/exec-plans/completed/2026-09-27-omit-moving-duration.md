# Omit iOS Moving Duration

## Goal

Stop emitting a moving-duration value that is currently copied from total workout duration.

## Context

The Python importer recognizes `movingDurationSeconds` and uses it instead of deriving moving time from a track. The earlier `movingDistanceSeconds` key was ignored. Neither iOS value currently has a trustworthy moving-time source.

## Work

1. Assert that synthetic route and heart-rate exports omit both moving-time keys while retaining `durationSeconds`.
2. Remove moving duration from the Swift export model and construction.
3. Update the format and testing docs, decision log, technical debt tracker, and indexes.

## Validation

- Run the relevant XCTest case, then the full simulator suite.
- Run `make validate-docs`, `make validate-build`, and `git diff --check`.

## Completion

Move this plan to `completed/` after validation. Existing files and the Python importer are unchanged.

## Result

- New iOS exports omit both moving-time keys and retain `durationSeconds`.
- The focused test failed before the change because `movingDurationSeconds` contained `120`.
- `make test` passed 7 tests with 0 failures on the iPhone 17 Pro iOS simulator.
- `make validate-docs`, `make validate-build`, and `git diff --check` passed.
- TD-005 tracks research into a trustworthy moving-duration source.

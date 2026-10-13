# HealthKit elevation conversion implementation plan

## Goal

Replace unavailable HealthKit ellipsoidal altitude with an offline EGM2008-based conversion of the stored sea-level altitude, preserving the Verve 1.0 ellipsoidal height contract.

## Context

The earlier release tests overrode CLLocation.ellipsoidalAltitude and missed the actual storage boundary. Comparing two user-provided exports showed identical horizontal/sample data but an entirely zero height series on this branch. An ordinary altitude-only CLLocation also returned ellipsoidalAltitude zero with positive vertical accuracy. Apple documents altitude among persisted HealthKit route fields, not ellipsoidalAltitude.

## Constraints and decisions

- User selected proper conversion and GeographicLib EGM2008 5-minute data (approximately 19 MB uncompressed), with bilinear interpolation.
- Use h = H + N at each position; source H is Apple's approximate sea-level height, and N is the EGM2008 geoid height relative to WGS 84. Apple usually uses EGM2008 but does not establish every stored/imported input's model; this remains an estimate, not recovered original GNSS height.
- Bundle public grid data with source, checksum, redistribution notes, and attribution. No runtime networking, package dependency, signing changes, or real workout fixtures.
- Keep user-provided workout files and screenshot untracked and unchanged. Use apply_patch for text edits; the upstream binary PGM must be acquired/copied byte-identically rather than encoded as a text patch.
- Keep no-route heart-rate exports independent of geoid loading and preserve sensor/timestamp alignment, energy, timezone, swimming, and route minimum length.

## Tasks

- [x] 1. Register the plan and public-resource tracking exception; acquire and verify the canonical PGM resource with checksum/attribution.
- [x] 2. Add plain CLLocation regression tests, then implement an injectable geoid provider, offline grid loading/parsing/interpolation, and explicit ellipsoidal height arrays in the feature builder. Require finite inputs, valid coordinates, positive finite accuracy, and finite results; show a specific grid-resource failure.
- [x] 3. Validate binary PGM parsing, independent public model reference vectors, checksum and actual bundle inclusion, periodic longitude/poles, missing/corrupt grids, malformed inputs, and no double conversion. Run the complete synthetic suite.
- [x] 4. Correct architecture, handoff, format notes, HealthKit guidance, testing notes, decisions, historical validation claims, and indexes. Run docs/lint/generic iOS build and independent review; move the plan to completed when available checks pass.

## Interfaces

- GeoidGrid.init(data:) throws and undulationMeters(latitude:longitude:) throws -> Double, independent of HealthKit.
- HealthManager.buildGeoJSON adds an optional geoidUndulation provider closure for deterministic synthetic tests; production lazily uses the cached bundled grid.
- WorkoutFeatureBuilder.build requires aligned ellipsoidalElevations: [Double], consuming verified converted heights directly.

## Validation

Use make validate-docs, make validate-lint, explicit all-source SwiftFormat/SwiftLint for untracked Swift files, make validate-build, and make test on the existing iOS 26.3 simulator. Store logs in .agent-local/exporter-release/. Compare miniature-grid results with hand-derived literals and real-grid output with public NGA-derived vectors within 0.5 m. Check the packaged resource and SHA-256. Do not write tests to a HealthKit store.

## Progress

- Approved plan ready; initial tree is clean except the user's two workout exports and screenshot. Earlier release commit is f620577.
- RED: full suite ran 38 tests with two expected assertions in testPlainHealthKitStyleLocationsRetainAltitudeVariation: both exported heights were zero. No unexpected failures.
- Downloaded canonical public model, confirmed 4320 x 2161 dimensions and SHA-256 96d55e88db186ddae892b00c5f8cc42a37cdac8ddb69b6de00af8c75dffb34a3. Resource provenance documented before binary acquisition into the app.
- New interfaces were compiled RED: GeoidGrid and GeoidUndulationProvider were absent as expected. Implemented the offline parser/interpolator, checksum-validated lazy resource cache, mean-sea-level conversion, and explicit feature-height arrays; GREEN validation pending.
- GREEN: 56 tests passed with zero failures in geoid-green.log, including production conversion with ordinary locations and twelve public NGA synthesis vectors. The actual simulator app contains the checksum-validated grid at bundle root. Addressed formatter/lint findings using apply_patch; final validation pending.
- Independent review found an Important source-validity gap: numeric coordinate bounds did not check CLLocation.horizontalAccuracy, whose negative value marks coordinates invalid. Added an ordinary-location regression before changing the guard.
- Local aggregate-only check using the app's GeoidGrid implementation and the user's comparison export produced finite, varying converted heights rather than zeros. No workout data was written, uploaded, or added to fixtures; original files remain unchanged.
- Ruling: current Apple altitude documentation strengthens the planned provenance: EGM2008 is used in most cases and DMA 10x10 rarely. Document that finding while retaining uncertainty for persisted/imported sources. Restricted PGM syntax and caching failed loads are intentional for an immutable, checksum-pinned bundled resource. Native HealthKit/UI and first-export device latency remain manual validation boundaries.
- Review fix RED: invalid horizontal accuracy (-1, NaN, infinity) caused provider lookups and no rejection, producing nine expected failures in geoid-horizontal-red.log. Added finite, nonnegative horizontal-accuracy validation before model loading/lookup. Full GREEN suite pending.
- Final GREEN: 57 tests passed with zero failures (geoid-tests-final.log), including the horizontal-validity regression. Generic iOS build passed (geoid-build.log); repository pre-commit checks passed (geoid-lint-final.log); explicit SwiftFormat and SwiftLint passed for all source files, including untracked additions; diff whitespace checks passed.
- Public resource is explicitly marked binary in .gitattributes and documented with its checksum and independent reference-vector provenance. No package dependency or Xcode/signing rewrite was needed; both bundled-model tests and native generic build include the app resource.
- Completion: code and available automated checks are complete, on the existing feature branch with changes left uncommitted. Real-device re-export, HealthKit query round trips, native UI behavior, and cold-start responsiveness remain manual checks. Personal JSON exports and screenshot remain untracked and unchanged. No runtime network service or personal data upload was added.

## Completion criteria

Plain altitude-only locations retain elevation variation after local geoid correction, including valid zero/negative derived heights. Errors never fabricate heights or silently use sea-level values. Automated validation passes; saved-route/device/UI checks not performed by the agent are recorded explicitly.

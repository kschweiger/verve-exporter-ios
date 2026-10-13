# Decisions

This is the compact decision log. Keep entries short. If a decision needs longer rationale, create or update a design document in `docs/design-docs/` and link it from the entry.

## Entries

### 2026-10-13: Convert persisted HealthKit sea-level heights with an offline geoid

Decision: Use GeographicLib's immutable EGM2008 5-minute PGM grid (approximately 19 MB), bilinear interpolation, and `h = H + N(latitude, longitude)`. Validate its SHA-256 once through a lazy cached loader, require positive finite source accuracy and finite/valid inputs, and fail explicitly for damaged/missing data. Pass converted height arrays to the feature builder so they cannot be converted twice.

Context: The user reported flattened elevations after the earlier change. HealthKit does not promise to store ellipsoidalAltitude; an ordinary CLLocation also returned zero for it despite valid sea-level height and positive accuracy. The earlier overridden test fixture hid this boundary. The user selected proper local conversion and the EGM2008 grid instead of changing the schema or rejecting all such routes.

Consequences: No runtime network service or package dependency is needed; only native Foundation/CryptoKit are used. Apple documents EGM2008 in most cases, but rare alternate geoids and imported provenance still make this an explicitly documented estimate. Valid zero/negative derived heights remain valid. The 0.478 m interpolation error is relative to the model, not total source uncertainty. No-route heart-rate exports do not initialize the model. Resource provenance lives in `../VerveExporter/Resources/Geoid/README.md`.

Implementation record: `exec-plans/completed/2026-10-13-healthkit-elevation-conversion.md`.

### 2026-10-13: Align exporter output with unified Verve GeoJSON 1.0

Decision at the initial release checkpoint: export route elevation directly from `CLLocation.ellipsoidalAltitude`, require at least two positions, and fail clearly for invalid inputs. The direct-property and nonnegative-accuracy choices are superseded by the offline conversion decision above. Specific alerts, kcal energy, explicit null geometry, sample alignment, and timezone semantics remain unchanged.

Context: Sea-level altitude and one-position LineStrings do not satisfy the unified contract. Summary-only files are valid in the format, but this exporter still requires route or heart-rate samples. Statistics remain optional in the format even though this exporter supplies them.

Consequences: A spatial workout with invalid elevation or only one point is rejected even if heart-rate samples are present. No points or elevation values are fabricated or silently substituted. Speed/cadence support remains separate work.

### 2026-10-13: Derive swimming averages conservatively and retain source precision

Decision: Derive set SWOLF averages from available included lap scores, omitting the average when no lap scores exist. Infer lap strokes only for standard length-based HealthKit SWOLF with known positive pool length and finite nonnegative integer-valued subtraction within 0.000001 numerical tolerance, checking Int representability. Preserve zero gaps, fractional distances, elapsed source-event durations, and meaningful reported zero values.

Context: The user selected lap-derived averages; SDK wording does not guarantee that every segment score is an average. Rounding an unexplained fractional subtraction invents a stroke count. The old unchecked Int conversion also crashed for out-of-range synthetic inputs.

Consequences: Missing lap scores are not zero. Complete derived sums require every component. Inclusive references are emitted only for contiguous selected lap indices; sets without usable ranges may still include their counts and other summaries. Equal-start events sort by end time and then original source position.

Implementation record: `exec-plans/completed/2026-10-13-exporter-release-conformance.md`.

### 2026-09-29: Use the Verve palette in the activity browser

Decision: Set the app accent color to Verve orange (`#F57A07`) for tinted controls and export icons. Use dark green (`#778332`) for workout activity icons, light green (`#EFF3DB`) for the activity screen background, white for workout rows, and brown (`#6D5239`) for section headings. Remove the large navigation title and present the activity browser in light appearance.

Context: The web palette defines this orange, and the activity browser previously used hard-coded blue for its primary icons.

Consequences: Palette colors live in the asset catalog. Green activity icons remain distinct from orange export actions and are clearer against white rows than neon green. Brown headings remain legible against the light green screen.

### 2026-09-28: Browse by Verve activity type and reveal ten workouts at a time

Decision: Use the top-level `VerveActivityMapper` type for a single activity filter, show the newest matching workout first, and reveal older matches ten at a time under month headings. Keep an explicit one-tap clear action for the selected filter.

Context: Routine use centers on exporting the latest workout, while a new user needs a manageable way to find and export older workouts individually.

Consequences: Workout queries must find matching activities beyond the newest ten overall. The UI must handle an empty category and reset to All activities when the filter is cleared.

### 2026-09-27: Omit moving duration from iOS GeoJSON

Decision: Emit neither `movingDurationSeconds` nor the unsupported `movingDistanceSeconds` until the iOS app has a trustworthy moving-duration value.

Context: The old field was ignored by the Python importer. Renaming it made the importer use `HKWorkout.duration` as moving duration instead of deriving moving time from a route.

Consequences: New iOS exports leave moving duration for the importer to derive from a moving track. For a stationary workout, the importer leaves it unset. Researching an iOS moving-duration source is tracked as technical debt.

### 2026-09-27: Test exports with in-memory synthetic HealthKit objects

Decision: Add an iOS XCTest target that supplies invented workout, route, and heart-rate objects directly to the export builder. Keep saved HealthKit integration checks separate and opt-in on a dedicated simulator.

Context: Export mapping and GeoJSON compatibility carry most of this app's logic; preloaded simulator clinical records do not provide workout routes.

Consequences: The automated suite checks export behavior without personal Health data. Real authorization and route-query behavior still require a separate integration or device check.

### 2026-05-28: Initialize repository agent harness

Decision: Initialize this repository with HarnessHub v0.1 from local source `/Users/korbinian/harnesshub`.

Context: The repository needs local agent-readable guidance, documentation structure, safety rules, Verve format knowledge, and HealthKit reference notes.

Design reference: `docs/design-docs/README.md`

Consequences: Future agents should use `AGENTS.md`, `ARCHITECTURE.md`, and `docs/` as the system of record.

Follow-up checks: Confirm automated test strategy, real-device smoke-test flow, and fixture policy.

### 2026-05-28: Treat Verve GeoJSON as a shared interface

Decision: Document the current Verve GeoJSON contract in `docs/product-specs/verve-geojson-format.md` and require agents to consult it before changing export fields.

Context: The iOS app exports data consumed by the Verve frontend/backend, whose current local references are `/Users/korbinian/Code/verve/frontend/src/views/HelpView.vue` and `/Users/korbinian/Code/verve/backend/verve_backend/schema/verve_file.py`.

Consequences: Field names, units, nullability, and activity mappings are compatibility-sensitive.

Follow-up checks: Add automated tests that encode sample Verve JSON and validate key names.

### 2026-09-27: Format export timestamps in the workout time zone

Decision: Use a valid workout `HKMetadataKeyTimeZone` identifier for all exported timestamps and the filename date; fall back to the device's current time zone when unavailable. Emit ISO-8601 offsets. The original choice to omit a separate time zone field is superseded by the 2026-10-11 decision below.

Context: UTC timestamps preserve instants but do not show the workout's local clock time in the exported file. The existing Verve schema accepts timestamps with offsets.

Consequences: The offset is calculated for each timestamp date, including daylight saving transitions. Re-exporting a workout without valid time zone metadata on a device in another time zone can change its displayed local time and filename, while preserving the same instant.

### 2026-09-27: Align SwiftFormat with SwiftLint

Decision: Format Swift 5.0 source at 120 columns, omit trailing commas, and keep multiline statement braces on the declaration line to match SwiftLint's strict rules. Split swimming metadata, diagnostics, activity mapping, and feature assembly into focused source files to satisfy the hooks without suppressing rules.

Context: The new pre-commit hooks initially disagreed on trailing commas and reported existing source-size, function-size, and complexity violations.

Consequences: Run `uvx pre-commit run -a` for lint and format checks. The generic build remains a separate `make validate-build` check.

### 2026-05-28: Add Makefile validation entry points

Decision: Add `Makefile` targets for harness validation, Xcode scheme inspection, signing-disabled generic iOS builds, and the full validation path.

Context: Future agents need stable commands that match the repository docs instead of reconstructing long `xcodebuild` invocations.

Consequences: Prefer `make validate-docs`, `make validate-build`, and `make validate` in agent workflows. Keep `docs/TESTING.md` synchronized when targets change.

### 2026-10-11: Export recorded IANA timezone separately

Decision: Emit optional root `timezone` from workout `HKMetadataKeyTimeZone` only when it is a recognized IANA name, including `UTC`. Preserve its spelling and omit missing, invalid, or fixed-offset names.

Reason: The backend now accepts an IANA timezone so activities retain their timezone rules rather than just a timestamp offset.

Consequences: Existing timestamp and filename fallback stays in place, but the device fallback never claims to be the recorded timezone. HealthKit describes object creation timezone, which may differ for imported workouts.

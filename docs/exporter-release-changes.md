# iOS exporter changes for the first Verve GeoJSON release

Date: 2026-10-13. Target file format: `verveVersion: "1.0"`.

This document preserves the implementation handoff and acceptance requirements.
The iOS changes were implemented on 2026-10-13; the execution record and validation
evidence are in [the completed plan](exec-plans/completed/2026-10-13-exporter-release-conformance.md).
Real-device HealthKit and native alert/share-sheet smoke checks remain separate.
The format elevation requirement is **meters above or below the
WGS 84 ellipsoid**. The core specification defines this reference, speed summaries in
m/s, optional statistics, and the running/cycling cadence conventions.
The requirements below describe the target Verve 1.0 exporter contract.

## Required changes

- **Ellipsoidal elevation:** export a verified ellipsoidal value as the third
  coordinate, retaining `[longitude, latitude, elevation]` and meter units.
  The initial direct `CLLocation.ellipsoidalAltitude` instruction is superseded
  for HealthKit routes: that field is not promised among persisted route fields.
  Convert HealthKit's approximate sea-level `altitude` locally with the bundled
  EGM2008 geoid, `h = H + N`. Record the model and source-height uncertainty.
  `WorkoutFeatureBuilder.swift` consumes explicit converted heights without
  converting them again. Do not silently fall back to sea-level height or apply
  a correction to an already verified ellipsoidal value. Invalid/unavailable
  inputs or model data must fail clearly rather than fabricate zero/null heights.
- **Reject short spatial routes:** validate the route before constructing its
  LineString. A one-position route must fail with a clear export error propagated
  through `HealthManager.swift`. Do not duplicate the point or write a one-position
  LineString. A workout with no route may continue through the existing non-spatial
  export path.
- **Metric conventions:** document m/s for every supplied speed summary and
  preserve `totalEnergyKcal` in kcal, including the existing HealthKit kilocalorie
  query. The exporter does not currently emit speed or cadence; this handoff does
  not require adding them. If those metrics are supplied later, normalize source
  speed units to m/s and running cadence to total steps from both feet per minute;
  cycling cadence counts crank revolutions per minute. Do not blindly double
  running values. For other sports, document the counted motion for cadence
  values in counts per minute.
- **Correct documentation and fixtures:** update
  `docs/product-specs/verve-geojson-format.md` and relevant `ExportTests.swift`
  fixtures/assertions. State the two-position minimum, ellipsoidal meter units,
  required geometry member, and explicitly required `coordTimes`. Replace or label
  any one-position illustration so it is not presented as valid GeoJSON.

## Swimming metadata requirements

Apply the Swimming metadata 1.0 contract to `HealthManager+Swimming.swift` and its
fixtures. Number-valued distances and presence-based scalar checks already match
its fractional-distance and zero-value rules; retain those behaviors.

- Counts may be supplied without details; detail arrays may be supplied without
  counts. When this exporter supplies both, counts must match their array lengths.
  Preserve zero values and omit an envelope only when recognized data is unavailable.
- Retain elapsed source-event durations. A set includes pauses within its interval;
  `restAfterSeconds` is only the subsequent gap. Account for timestamp precision
  when checking boundaries and durations; a known zero gap is allowed.
- Ensure array-position indices and set overlap selection produce valid inclusive
  lap ranges and counts. Omit references when lap details are unavailable.
- Infer strokes from SWOLF only for a known standard length-based score. Preserve
  precision; do not manufacture a count from an unexplained fractional result.
  A supplied set SWOLF must represent an average; otherwise derive an average of
  available lap scores or omit it. Compare recommendation-level arithmetic using
  the source's reported precision.
- Update swimming documentation/examples with complete core properties, an
  explicit geometry member, and consistent counts, timing, distances, and SWOLF.

Swimming acceptance checks: preserve fractional distances and reported zero
counts; omit empty/unavailable-only metadata; verify any supplied counts and set
references, offset-qualified times, elapsed duration with internal rest, and
standard SWOLF inference. Supporting every valid summary-only input remains a
separate exporter capability; it does not restrict the format.

## Already compliant; retain and verify

- `GeoJSON.swift` deliberately encodes `geometry: null` for non-spatial features.
  Keep that custom encoding; omission is not equivalent to explicit null.
- `LineProperties` already includes an explicit `coordTimes` array. Preserve
  coordinate/timestamp alignment and null placeholders in sensor arrays.
- Exported timestamps already carry UTC offsets. Preserve that behavior and the
  distinction between a recorded timezone and a timestamp-formatting fallback.

## Clarifications

A summary-only activity with `geometry: null` and `coordTimes: []` is valid Verve
1.0. The current `noSamples` rejection is an exporter capability limitation;
adding summary-only export support is a separate feature, not required by this
handoff. Documentation and error descriptions must not call that shape invalid.

`stats` remains optional in the format even though this exporter emits it.
Consistency among supplied min/avg/max values remains a format recommendation;
a backend may enforce stricter checks without requiring omitted summaries.
The exporter's available sensors and metadata do not determine what other
exporters may produce.

Energy remains in kcal under the existing field name. Distances/elevations use
meters, durations seconds, power watts, temperature degrees Celsius, and heart
rate bpm. No energy conversion or field rename is required.

## Acceptance checks

- A two-position route exports successfully; a one-position route produces the
  clear export error and no invalid file, including when heart-rate data exists.
- No-route heart-rate exports retain explicit null geometry and aligned arrays.
- Use ordinary altitude-only CLLocation fixtures with positive accuracy and
  injected known geoid values; assert `h = H + N` with the correct sign and
  preserved height variation. Separately test the actual bundled grid against
  independent public NGA synthesis vectors and its pinned checksum.
- Cover valid negative ellipsoidal heights, unavailable/invalid elevation, and
  absence of double conversion. Verify every feature contains `coordTimes`.
- Retain a known kcal fixture and verify its field and numerical value remain
  unchanged. For any subsequently supported speed/cadence export, verify the
  36 km/h -> 10 m/s conversion and stride/step normalization without double conversion.

References: [Apple ellipsoidal altitude](https://developer.apple.com/documentation/corelocation/cllocation/ellipsoidalaltitude)
and [GeoJSON section 4](https://www.rfc-editor.org/rfc/rfc7946#section-4).
The companion backend handoff is maintained in the unified format repository at
`/Users/korbinian/Code/verve/geojson-flavor/docs/backend-release-changes.md`.

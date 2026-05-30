# Verve GeoJSON Format

## Sources

This document captures the current local Verve format references used during harness bootstrap:

- Frontend FAQ: `/Users/korbinian/Code/verve/frontend/src/views/HelpView.vue`
- Backend schema: `/Users/korbinian/Code/verve/backend/verve_backend/schema/verve_file.py`
- Backend exporter/importer behavior: `/Users/korbinian/Code/verve/backend/verve_backend/schema/exporter.py` and `/Users/korbinian/Code/verve/backend/verve_backend/schema/importer.py`

Update this document whenever those references change.

## Root Object

The preferred Verve file is a GeoJSON `FeatureCollection`:

```json
{
  "type": "FeatureCollection",
  "properties": {},
  "features": []
}
```

Backend validation requires at least one feature.

The backend sniffs Verve format by checking:

```text
properties.verveVersion == "1.0"
```

## Root Properties

Use camelCase aliases in exported JSON.

| Field | Required | Type | Unit / meaning |
| --- | --- | --- | --- |
| `verveVersion` | yes | string literal | Must be `"1.0"`. |
| `generator` | yes | string | Exporter name. Current iOS value is `VerveExporteriOS`. |
| `name` | yes | string | Activity display name. |
| `description` | no | string or null | Optional activity description. |
| `activityType` | yes | string | Verve activity type, such as `Cycling` or `Foot Sports`. |
| `activitySubType` | no | string or null | Verve subtype, such as `Run`, `Indoor`, or `Treadmill`. |
| `startTime` | yes | ISO-8601 string | Activity start time. |
| `durationSeconds` | yes | number | Total workout duration in seconds. |
| `movingDurationSeconds` | no | number or null | Moving duration in seconds. |
| `totalDistanceMeters` | no | number or null | Total distance in meters. |
| `totalEnergyKcal` | no | number or null | Active energy in kcal. |
| `elevationGain` | no | number or null | Elevation gain in meters. |
| `elevationLoss` | no | number or null | Elevation loss in meters. |
| `stats` | yes | object | Aggregate metric summaries. |
| `equipment` | no | array or null | Snapshot of associated equipment. |
| `metadata` | no | object | Source-neutral activity metadata. Current documented child object: `metadata.swimming`. |

Important compatibility note: the backend schema field is `moving_duration` serialized as `movingDurationSeconds`. The current Swift model has `movingDistanceSeconds`, which does not match the backend alias and should be fixed before treating moving duration as supported.

## Metric Summary

Each metric summary is an object with optional numeric values:

```json
{
  "avg": 145.0,
  "max": 170.0,
  "min": 110.0
}
```

Supported stats keys:

- `speed`
- `heartRate`
- `power`
- `cadence`

## Swimming Metadata

Swimming workouts may include source-neutral metadata under `properties.metadata.swimming`.

Example:

```json
{
  "schemaVersion": 1,
  "poolLengthMeters": 50,
  "totalStrokeCount": 337,
  "averageSwolf": 97.1,
  "lapCount": 10,
  "setCount": 8,
  "strokeStyles": ["breaststroke", "freestyle"],
  "laps": [],
  "sets": []
}
```

`metadata.swimming` fields:

| Field | Type | Required | Unit / meaning |
| --- | --- | --- | --- |
| `schemaVersion` | integer | yes | Swimming metadata schema version. Current value is `1`. |
| `poolLengthMeters` | number | no | Pool length in meters. Omit for open-water swims or when unknown. |
| `totalStrokeCount` | integer | no | Total counted swim strokes for the whole workout. |
| `averageSwolf` | number | no | Average swim efficiency score across exported laps. |
| `lapCount` | integer | no | Number of exported lap objects. |
| `setCount` | integer | no | Number of exported set objects. |
| `strokeStyles` | array of strings | no | Distinct stroke styles present in laps or sets. |
| `laps` | array | no | Atomic lap records, usually one pool length each. |
| `sets` | array | no | Higher-level groupings of one or more laps. |

SWOLF means swim golf:

```text
SWOLF = length duration in seconds + stroke count for that length
```

Lower values are better for a fixed pool length. A 50 m length completed in `54` seconds with `26` strokes has a SWOLF score of `80`.

Stroke style values use lowercase strings:

- `freestyle`
- `backstroke`
- `breaststroke`
- `butterfly`
- `kickboard`
- `mixed`
- `unknown`

Swim lap fields:

| Field | Type | Required | Unit / meaning |
| --- | --- | --- | --- |
| `index` | integer | yes | Zero-based lap array index within the workout. |
| `startTime` | string | no | ISO-8601 lap start time. |
| `endTime` | string | no | ISO-8601 lap end time. |
| `durationSeconds` | number | no | Lap duration in seconds. |
| `distanceMeters` | number | no | Lap distance in meters. |
| `strokeStyle` | string | no | Stroke style enum value. |
| `strokeCount` | integer | no | Stroke count for this lap. |
| `swolf` | number | no | SWOLF score for this lap. |
| `restAfterSeconds` | number | no | Time from this lap end to the next lap start. |

Swim set fields:

| Field | Type | Required | Unit / meaning |
| --- | --- | --- | --- |
| `index` | integer | yes | Zero-based set array index within the workout. |
| `startTime` | string | no | ISO-8601 set start time. |
| `endTime` | string | no | ISO-8601 set end time. |
| `durationSeconds` | number | no | Set duration in seconds. |
| `lapStartIndex` | integer | no | Zero-based index of the first included lap. |
| `lapEndIndex` | integer | no | Zero-based index of the last included lap. |
| `lapCount` | integer | no | Number of laps in the set. |
| `distanceMeters` | number | no | Set distance in meters. |
| `strokeStyle` | string | no | Single style if included laps agree, otherwise `mixed`. |
| `strokeCount` | integer | no | Total stroke count for the set. |
| `averageSwolf` | number | no | Average SWOLF for the set. |
| `restAfterSeconds` | number | no | Time from this set end to the next set start. |

Swimming location is not stored in `metadata.swimming`. Use root `activityType` and `activitySubType` for classification such as `Swimming` + `Indoor`, `Outdoor Pool`, or `Open Water`.

## Features

Each feature represents one track segment or one non-spatial time series:

```json
{
  "type": "Feature",
  "geometry": {
    "type": "LineString",
    "coordinates": [[11.582, 48.135, 520.0]]
  },
  "properties": {
    "coordTimes": ["2026-02-28T09:00:00Z"]
  }
}
```

The backend schema allows `geometry` to be `null`. That supports workouts with time-series samples but no route.

## Coordinates

Coordinates are arrays of three numbers:

```text
[longitude, latitude, elevation]
```

The order is longitude, latitude, elevation. Elevation is stored in meters.

## Feature Properties

| Field | Required | Type | Meaning |
| --- | --- | --- | --- |
| `coordTimes` | yes | array of ISO-8601 strings | One timestamp per point/sample. |
| `heartRates` | no | array of integer or null | Beats per minute, aligned by index with `coordTimes`. |
| `cadences` | no | array of integer or null | Cadence, aligned by index. |
| `powers` | no | array of number or null | Power in watts, aligned by index. |
| `temperatures` | no | array of number or null | Temperature, aligned by index. |

Validation rule: when an optional per-point array is present, its length must equal `coordTimes.count`. If `geometry` is present, `geometry.coordinates.count` must also equal `coordTimes.count`.

## Supported Variants

The frontend FAQ documents these supported variants:

- A single GeoJSON `Feature` with `LineString` geometry and per-point arrays in `properties`.
- A `FeatureCollection` with multiple `LineString` segment features.
- A `FeatureCollection` of point features.
- The Verve `FeatureCollection` format with root `properties.verveVersion == "1.0"`.

For this iOS app, prefer the Verve `FeatureCollection` with one feature per HealthKit route segment or time-series-only workout. Do not switch to point-feature output without updating backend compatibility tests and this document.

## Current iOS Export Behavior

Current implementation:

- Requests HealthKit read access to workouts, workout routes, and heart rate.
- Exports GPS workouts as one `LineString` feature.
- Exports `[longitude, latitude, altitude]` from `CLLocation`.
- Exports `coordTimes` from route timestamps.
- Finds nearest heart-rate sample within 30 seconds of each route point.
- Exports no-geometry heart-rate time series for workouts without route data.
- Calculates root heart-rate stats from exported/available heart-rate values.
- Reads active energy and distance from workout statistics when present.
- Exports source-neutral swimming metadata for HealthKit swim workouts when lap, segment, stroke, pool length, and SWOLF data are available.

Known gaps:

- `movingDistanceSeconds` is encoded instead of the backend-compatible `movingDurationSeconds`.
- No cadence, power, temperature, speed, elevation gain/loss, or equipment export is implemented.
- Multiple HealthKit route samples or route discontinuities are not yet documented as multiple Verve features.
- No automated schema/fixture tests exist.

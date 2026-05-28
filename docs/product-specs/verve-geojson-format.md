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
| `metadata` | no | object | Arbitrary JSON metadata. The current Swift model does not encode this field. |

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

Known gaps:

- `movingDistanceSeconds` is encoded instead of the backend-compatible `movingDurationSeconds`.
- No cadence, power, temperature, speed, elevation gain/loss, equipment, or metadata export is implemented.
- Multiple HealthKit route samples or route discontinuities are not yet documented as multiple Verve features.
- No automated schema/fixture tests exist.

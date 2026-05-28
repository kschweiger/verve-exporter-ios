# Swim Metadata Verve File Extension

## Status

Proposed for the Verve file transfer contract. Backend implementation is intentionally out of scope for this repository session.

## Purpose

Extend the Verve GeoJSON file format with a source-neutral swimming metadata object that can carry pool lengths, laps, sets, strokes, and SWOLF values. The extension should be easy for multiple exporters to produce and easy for Verve to import without coupling the schema to Apple HealthKit.

## Non-Goals

- Do not encode exporter-specific or HealthKit-specific field names in the transfer schema.
- Do not store swimming location type inside swim metadata. Verve activity type/subtype already owns classification such as `Swimming` + `Indoor`, `Outdoor Pool`, or `Open Water`.
- Do not require every exporter to provide every swim field. Partial swim metadata should remain valid.
- Do not change GeoJSON feature geometry or per-point track arrays for this extension.

## Placement In Verve GeoJSON

Swimming metadata belongs under root properties metadata:

```json
{
  "type": "FeatureCollection",
  "properties": {
    "verveVersion": "1.0",
    "activityType": "Swimming",
    "activitySubType": "Outdoor Pool",
    "metadata": {
      "swimming": {
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
    }
  },
  "features": []
}
```

## Design Principles

- The schema describes swimming concepts, not source APIs.
- Laps are the atomic pool-length records.
- Sets are higher-level groupings of laps that are useful for display and analysis.
- Exporters may provide only `laps`, only `sets`, or both.
- Numeric values use SI units: meters, seconds, and counts.
- Timestamps use the same ISO-8601 representation as existing Verve fields.
- Unknown or unavailable values should be omitted instead of guessed.

## SWOLF

SWOLF means "swim golf". It is a swimming efficiency score:

```text
SWOLF = length duration in seconds + stroke count for that length
```

Lower values are better for a fixed pool length because the swimmer covered the same distance with less time, fewer strokes, or both. Example: a 50 m length completed in `54` seconds with `26` strokes has a SWOLF score of `80`.

For sets, `averageSwolf` should represent the average of the included lap SWOLF values when available. If a source provides a set-level SWOLF directly, the exporter may use it when it is semantically an average over the set.

## Field Definitions

### `metadata.swimming`

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `schemaVersion` | integer | yes | Version of the swim metadata object. Start with `1`. |
| `poolLengthMeters` | number | no | Pool length in meters. Omit for open-water swims or when unknown. |
| `totalStrokeCount` | integer | no | Total counted swim strokes for the whole workout. |
| `averageSwolf` | number | no | Average swim efficiency score across the workout. |
| `lapCount` | integer | no | Number of lap objects included or reported by the source. |
| `setCount` | integer | no | Number of set objects included or reported by the source. |
| `strokeStyles` | array of strings | no | Distinct stroke styles present in laps or sets. |
| `laps` | array of swim lap objects | no | Atomic lap records, usually one pool length each. |
| `sets` | array of swim set objects | no | Higher-level groupings of one or more laps. |

### Stroke Style Values

Use lowercase strings:

- `freestyle`
- `backstroke`
- `breaststroke`
- `butterfly`
- `kickboard`
- `mixed`
- `unknown`

`mixed` means a set contains more than one known style, or the source classified the interval as mixed. `unknown` means the style is unavailable or not confidently classified.

### Swim Lap Object

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `index` | integer | yes | 1-based lap number within the workout. |
| `startTime` | string | no | ISO-8601 lap start time. |
| `endTime` | string | no | ISO-8601 lap end time. |
| `durationSeconds` | number | no | Lap duration in seconds. |
| `distanceMeters` | number | no | Lap distance in meters. For pool swims this is normally `poolLengthMeters`. |
| `strokeStyle` | string | no | Stroke style enum value. |
| `strokeCount` | integer | no | Stroke count for this lap. |
| `swolf` | number | no | SWOLF score for this lap. |
| `restAfterSeconds` | number | no | Time from this lap end to the next lap start. Omit for the final lap or when unknown. |

Example:

```json
{
  "index": 1,
  "startTime": "2026-05-27T14:58:06Z",
  "endTime": "2026-05-27T14:59:01Z",
  "durationSeconds": 54.34,
  "distanceMeters": 50,
  "strokeStyle": "breaststroke",
  "strokeCount": 26,
  "swolf": 80.34,
  "restAfterSeconds": 6.0
}
```

### Swim Set Object

| Field | Type | Required | Description |
| --- | --- | --- | --- |
| `index` | integer | yes | 1-based set number within the workout. |
| `startTime` | string | no | ISO-8601 set start time. |
| `endTime` | string | no | ISO-8601 set end time. |
| `durationSeconds` | number | no | Set duration in seconds. |
| `lapStartIndex` | integer | no | First included lap index. |
| `lapEndIndex` | integer | no | Last included lap index. |
| `lapCount` | integer | no | Number of laps in the set. |
| `distanceMeters` | number | no | Set distance in meters. |
| `strokeStyle` | string | no | Single style if all included laps agree; `mixed` if styles differ. |
| `strokeCount` | integer | no | Total stroke count for the set. |
| `averageSwolf` | number | no | Average SWOLF for the set. |
| `restAfterSeconds` | number | no | Time from this set end to the next set start. Omit for the final set or when unknown. |

Example:

```json
{
  "index": 1,
  "startTime": "2026-05-27T14:57:39Z",
  "endTime": "2026-05-27T15:00:02Z",
  "durationSeconds": 143.0,
  "lapStartIndex": 1,
  "lapEndIndex": 2,
  "lapCount": 2,
  "distanceMeters": 100,
  "strokeStyle": "breaststroke",
  "strokeCount": 56,
  "averageSwolf": 82.69,
  "restAfterSeconds": 62.0
}
```

## Derivation Rules For Exporters

- `lapCount` should equal `laps.length` when laps are exported.
- `setCount` should equal `sets.length` when sets are exported.
- `strokeStyles` should be derived from available lap and set styles, excluding `unknown` unless all styles are unknown.
- `strokeCount` for a lap may be inferred from `swolf - durationSeconds` only when the source definition is known to use standard SWOLF for that pool length.
- `strokeCount` for a set may be summed from included laps when direct set stroke count is unavailable.
- `distanceMeters` for a pool lap may be set from `poolLengthMeters`.
- `distanceMeters` for a set may be computed as the sum of included lap distances.
- `restAfterSeconds` should be computed from adjacent interval boundaries, not inferred from pauses unless interval boundaries are unavailable.
- If a source provides only set-level data, omit `lapStartIndex` and `lapEndIndex`.

## Apple HealthKit Mapping Notes

The iOS exporter should map Apple HealthKit data into the source-neutral fields:

- `HKMetadataKeyLapLength` or `HKWorkoutActivity.workoutConfiguration.lapLength` -> `poolLengthMeters`
- `HKQuantityTypeIdentifierSwimmingStrokeCount` workout statistic -> `totalStrokeCount`
- `HKWorkoutEventType.lap` -> `laps`
- `HKWorkoutEventType.segment` -> `sets`
- `HKMetadataKeySwimmingStrokeStyle` on lap events -> lap `strokeStyle`
- `HKMetadataKeySWOLFScore` on lap events -> lap `swolf`
- `HKMetadataKeySWOLFScore` on segment events -> set `averageSwolf`

HealthKit swimming location type should affect Verve `activitySubType`, not `metadata.swimming`.

## Open Questions

- Whether open-water swims should use `laps` for source-provided intervals, a separate future interval shape, or only track geometry plus aggregate swim metadata.
- Whether Verve should preserve per-lap/set heart-rate summaries later. This design intentionally leaves heart rate in existing stats and feature-level arrays for now.
- Whether the backend should validate this object strictly or accept it as JSON with lightweight shape checks.

## Acceptance Criteria

- The Verve file documentation defines `metadata.swimming` as source-neutral swim metadata.
- The iOS exporter can populate the documented fields from HealthKit pool swim diagnostics.
- The backend can import the object into the existing activity JSON metadata column without needing a source-specific schema.
- Existing non-swim Verve GeoJSON files remain valid.

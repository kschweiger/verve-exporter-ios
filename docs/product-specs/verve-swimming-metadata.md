# Verve Swimming Metadata Contract

## Source

Aligned with the unified Verve contract in `/Users/korbinian/Code/verve/geojson-flavor/src/content/docs/specification/swimming-1.0.md` on 2026-10-13. Format requirements below are distinct from this iOS exporter's supported capabilities.

Swimming metadata describes pool information, lengths, sets, stroke styles, and
SWOLF in a Verve activity. It is an optional extension to the core format. A file
using this extension MUST satisfy both the core requirements and this contract.
Uppercase requirement words use the meanings defined in the core specification.

## Placement and envelope

The envelope is stored in the root activity properties as `properties.metadata`.

| Field | Required | Type | Value or meaning |
| --- | --- | --- | --- |
| `target` | Yes | String literal | Exactly `"SwimmingMetaData"`. |
| `version` | Yes | String literal | Exactly `"1.0"`, the swimming extension version. |
| `data` | Yes | Object | Swimming data containing at least one meaningful field. |

These three members MUST be present and MUST NOT be null. Consumers MUST select
an extension contract using both `target` and `version`; they MUST NOT interpret
an unsupported version as version 1.0. Additional members MAY be present, without
changing the meaning of the defined fields.

The root `activityType` identifies `Swimming`. Location classification belongs to
root `activitySubType`, for example `Indoor`, `Outdoor Pool`, or `Open Water`;
it is not a field in `metadata.data`. The metadata is independent of whether the
activity has route geometry, a non-spatial time series, or summary information only.

## Swimming data

All fields below are optional. They MAY be omitted or null. Missing or null means
unavailable; zero is a reported numerical value. Arrays MUST NOT contain null
items. Numeric values MUST be finite JSON numbers, and counts and indices MUST
be integers. Counts and indices MUST be nonnegative. Lengths, distances, elapsed
durations, rest durations, and SWOLF values SHOULD be nonnegative; a supplied pool
length SHOULD be positive.

| Field | Type, when non-null | Units or meaning |
| --- | --- | --- |
| `poolLengthMeters` | Number | Pool length in meters; fractional values are allowed. Omit when unknown or for open-water swims. |
| `totalStrokeCount` | Integer | Total counted swim strokes for the workout. |
| `averageSwolf` | Number | Source-reported workout average or average of available exported lap SWOLF values. |
| `lapCount` | Integer | Number of supplied lap objects, or a reported count when lap details are unavailable. |
| `setCount` | Integer | Number of supplied set objects, or a reported count when set details are unavailable. |
| `strokeStyles` | Array of strings | Distinct stroke styles represented in the workout. |
| `laps` | Array of lap objects | Atomic swimming intervals, normally one pool length each. |
| `sets` | Array of set objects | Higher-level swimming intervals that can group multiple laps. |

A swimming envelope MUST contain at least one non-null scalar field from this
table or at least one non-empty `strokeStyles`, `laps`, or `sets` array. A known
zero count qualifies. An empty object, null fields alone, empty arrays alone, or
additional unrecognized fields alone do not qualify. Exporters MUST omit the
swimming envelope when meaningful swimming data is unavailable.

## Unit conventions

| Quantity | Unit | Convention |
| --- | --- | --- |
| Pool length and lap/set distance | m | Number of meters, preserving fractional values. |
| Lap/set duration | s | Elapsed interval time, including pauses within the interval. |
| Rest after an interval | s | Gap from the interval end to the next interval start. |
| Stroke, lap, and set counts | count | Nonnegative integers. |
| Lap and set indices | index | Zero-based positions in the corresponding exported array. |
| SWOLF | score | Length duration in seconds plus the stroke count for that length. |

Integer meter values such as 25 and 50 are valid numbers. A converted yard-based
length can be represented exactly to its stated precision, such as 22.86 meters.
Core activity units still apply: route elevation uses ellipsoidal meters, speed
summaries use m/s, and active energy uses kcal.

## Lap objects

A lap is an atomic exported swimming interval. In a pool, it normally represents
one length; the format does not use the informal down-and-back meaning of lap.
Every lap MUST include its zero-based array-position `index`. Other fields are
optional and MAY be null.

| Field | Type, when non-null | Units or meaning |
| --- | --- | --- |
| `index` | Integer, required | Position in the exported `laps` array, starting at zero. |
| `startTime` | Timestamp string | Start instant. |
| `endTime` | Timestamp string | End instant. |
| `durationSeconds` | Number | Elapsed lap interval in seconds. |
| `distanceMeters` | Number | Lap distance in meters; fractional values are allowed. |
| `strokeStyle` | String | A supported stroke-style value. |
| `strokeCount` | Integer | Counted strokes for this lap. |
| `swolf` | Number | SWOLF score for this lap. |
| `restAfterSeconds` | Number | Gap after the lap before the next lap starts, in seconds. |

## Set objects

Every set MUST include its zero-based array-position `index`. Other fields are
optional and MAY be null. A source can supply set-level data without lap details.

| Field | Type, when non-null | Units or meaning |
| --- | --- | --- |
| `index` | Integer, required | Position in the exported `sets` array, starting at zero. |
| `startTime` | Timestamp string | Start instant. |
| `endTime` | Timestamp string | End instant. |
| `durationSeconds` | Number | Elapsed set interval in seconds, including pauses between its laps. |
| `lapStartIndex` | Integer | First included index in the exported `laps` array. |
| `lapEndIndex` | Integer | Last included index in the exported `laps` array, inclusive. |
| `lapCount` | Integer | Number of laps in this set. |
| `distanceMeters` | Number | Set distance in meters; fractional values are allowed. |
| `strokeStyle` | String | Shared known style, or `mixed` when known styles differ. |
| `strokeCount` | Integer | Total counted strokes for the set. |
| `averageSwolf` | Number | Average SWOLF over the set, not set duration plus total strokes. |
| `restAfterSeconds` | Number | Gap after the set before the next set starts, in seconds. |

## Counts, indices, and lap references

`lapCount` and `setCount` MAY be supplied without their detail arrays. Detail
arrays MAY also be supplied without counts. When a non-null array and its count
are both supplied, the count MUST equal the array length, including for an empty
array. A null or omitted array means details are unavailable, rather than a
reported empty set of details.

Each supplied lap or set `index` MUST equal its position in the corresponding
array. Indices are local to the exported arrays, not source database identifiers.

Set lap references MUST refer to supplied lap objects. When lap details are
unavailable, exporters MUST omit `lapStartIndex` and `lapEndIndex`. The two range
boundaries SHOULD be provided together. When both are supplied, the start MUST
NOT exceed the end. A supplied set `lapCount` MUST equal the size of that inclusive
range. A set without lap references can still carry source-reported summary data.

Workout-level summaries can cover information not included in exported detail
records. The format does not require `totalStrokeCount` or a source-reported
workout average to be recomputed from a partial set of exported laps.

## Timing and rest

Every non-null `startTime` and `endTime` MUST follow the core timestamp rules,
including an explicit UTC offset. If both boundaries are supplied, `endTime`
MUST NOT precede `startTime`. Compare instants using their offsets.

`durationSeconds` represents elapsed time across that interval. It includes pauses
inside a lap or set. A set covering two laps with a rest between them therefore
has a longer elapsed duration than the sum of those two lap durations. Its
`restAfterSeconds` describes the gap after the set, not its internal pauses.

Supplied durations SHOULD agree with the interval boundaries to the precision
reported by the source. Timestamp formatting can discard fractional seconds;
validators SHOULD account for that precision instead of requiring exact numeric
equality with a more precise duration. Exporters SHOULD order laps and sets
chronologically and derive rest from adjacent interval boundaries. Omit rest for
the final interval or when the next boundary is unknown; a known zero gap MAY be
reported as zero. Do not infer a positive rest from overlapping boundaries.

## Stroke styles

The supported values are `freestyle`, `backstroke`, `breaststroke`, `butterfly`,
`kickboard`, `mixed`, and `unknown`. Values MUST use these lowercase spellings.
`unknown` means unavailable or not confidently classified; `mixed` means multiple
known styles, or an interval directly classified as mixed by the source.

`strokeStyles` SHOULD contain distinct styles derived from available laps, sets,
or source classification. Exclude `unknown` when known styles are available;
use `unknown` when all available styles are unknown. A derived set style SHOULD
be the shared known style of its laps or `mixed` when their known styles differ.
Do not infer an additional style from absent information.

## SWOLF and derivation

For one pool length, SWOLF is length duration in seconds plus the stroke count
for that length. For example, 50 seconds and 20 strokes give a score of 70.
Compare scores using the same pool length; a set average is not computed by
adding the entire set duration to its total stroke count.

When lap duration, stroke count, and SWOLF are supplied together, they SHOULD
agree with that formula to the precision of the source values. A source can
provide a SWOLF score without the component fields. Exporters MAY infer a stroke
count from SWOLF minus duration only when the source is known to use this standard
length-based definition. Preserve the source precision; do not manufacture an
integer count from an unexplained fractional or negative result.

A derived set or workout `averageSwolf` SHOULD be the arithmetic mean of available
included lap SWOLF values. A directly supplied source average MAY be used when it
represents an average over the stated set or workout. Missing scores are not zero.

Exporters MAY use pool length as a pool lap's distance, sum known included lap
distances or stroke counts for a set, and derive counts from supplied arrays.
Do not claim a complete sum when an included component is unavailable. These are
source-neutral derivations; no particular source API or synchronization algorithm
is required.

## Complete synthetic examples

Both examples are complete standalone Verve GeoJSON files, with explicit null
geometry. Their metadata is unrelated to real workouts. Downloadable example
files and JSON Schemas are still in preparation.

### Pool workout with lap and set details

The first length takes 50 seconds, followed by 10 seconds of rest and a second
55-second length. The set's elapsed duration is 115 seconds; its two SWOLF scores
are 70 and 77, averaging 73.5. Final lap/set rest values are omitted.

```json
{
  "type": "FeatureCollection",
  "properties": {
    "verveVersion": "1.0",
    "generator": "ExampleExporter",
    "name": "Synthetic two-length pool workout",
    "activityType": "Swimming",
    "activitySubType": "Indoor",
    "startTime": "2026-10-13T08:00:00Z",
    "durationSeconds": 115,
    "totalDistanceMeters": 50,
    "totalEnergyKcal": 12,
    "metadata": {
      "target": "SwimmingMetaData",
      "version": "1.0",
      "data": {
        "poolLengthMeters": 25,
        "totalStrokeCount": 42,
        "averageSwolf": 73.5,
        "lapCount": 2,
        "setCount": 1,
        "strokeStyles": [
          "freestyle"
        ],
        "laps": [
          {
            "index": 0,
            "startTime": "2026-10-13T08:00:00Z",
            "endTime": "2026-10-13T08:00:50Z",
            "durationSeconds": 50,
            "distanceMeters": 25,
            "strokeStyle": "freestyle",
            "strokeCount": 20,
            "swolf": 70,
            "restAfterSeconds": 10
          },
          {
            "index": 1,
            "startTime": "2026-10-13T08:01:00Z",
            "endTime": "2026-10-13T08:01:55Z",
            "durationSeconds": 55,
            "distanceMeters": 25,
            "strokeStyle": "freestyle",
            "strokeCount": 22,
            "swolf": 77
          }
        ],
        "sets": [
          {
            "index": 0,
            "startTime": "2026-10-13T08:00:00Z",
            "endTime": "2026-10-13T08:01:55Z",
            "durationSeconds": 115,
            "lapStartIndex": 0,
            "lapEndIndex": 1,
            "lapCount": 2,
            "distanceMeters": 50,
            "strokeStyle": "freestyle",
            "strokeCount": 42,
            "averageSwolf": 73.5
          }
        ]
      }
    }
  },
  "features": [
    {
      "type": "Feature",
      "geometry": null,
      "properties": {
        "coordTimes": [
          "2026-10-13T08:00:00Z",
          "2026-10-13T08:00:50Z",
          "2026-10-13T08:01:00Z",
          "2026-10-13T08:01:55Z"
        ],
        "heartRates": [
          120,
          null,
          130,
          135
        ]
      }
    }
  ]
}
```

### Summary-only workout with fractional pool length

This workout reports eight lengths and two sets without detail arrays. Its pool
length is 22.86 meters and its reported stroke count is zero. No route or sensor
samples are required to represent the activity.

```json
{
  "type": "FeatureCollection",
  "properties": {
    "verveVersion": "1.0",
    "generator": "ExampleExporter",
    "name": "Synthetic summary-only kickboard workout",
    "activityType": "Swimming",
    "activitySubType": "Indoor",
    "startTime": "2026-10-13T09:00:00Z",
    "durationSeconds": 600,
    "totalDistanceMeters": 182.88,
    "metadata": {
      "target": "SwimmingMetaData",
      "version": "1.0",
      "data": {
        "poolLengthMeters": 22.86,
        "totalStrokeCount": 0,
        "lapCount": 8,
        "setCount": 2,
        "strokeStyles": [
          "kickboard"
        ]
      }
    }
  },
  "features": [
    {
      "type": "Feature",
      "geometry": null,
      "properties": {
        "coordTimes": []
      }
    }
  ]
}
```

## Conformance and validation limits

Extension conformance requires the envelope, field types, supported styles,
meaningful-data rule, count/array agreement, and valid indices and references.
Duration, SWOLF, and derived-summary consistency are recommendations; applications
may enforce stricter consistency checks. Core conformance remains required too.

Portable JSON Schema can check structural types and supported literals, but it
cannot fully check count/array equality, set references, timestamp ordering, or
cross-field arithmetic. Those checks require semantic validation. Timestamp
format assertion and offset checks must be enabled when using a validator.

Validation scenarios include a reported zero count, fractional distances,
summary counts without arrays, details without counts, null optional fields,
empty or unavailable-only envelopes, mismatched counts, invalid indices or set
ranges, unsupported stroke styles, and offsetless timestamps. Additional arbitrary
core metadata does not establish swimming extension conformance by itself.

## iOS exporter derivation policy

- Exported lap/set counts match their supplied detail arrays; support for every summary-only source input is a separate capability.
- Preserve source-event elapsed durations, including internal pauses; adjacent gaps are computed separately. Offset-qualified timestamps currently have whole-second formatting, so duration comparisons allow the discarded fractional precision.
- HealthKit lap SWOLF uses the standard length-based definition. Only infer stroke counts with known positive pool length and an integer-valued, finite, nonnegative subtraction; a 0.000001 tolerance covers numerical representation, not unexplained source rounding.
- Derive set average SWOLF from available included lap scores. Do not treat an unqualified HealthKit segment score as a guaranteed average.
- Keep complete-sum checks for derived distance and stroke totals; omit an unrepresentable integer total rather than overflow. Omit lap-range references without lap details or when the selected overlapping indices are noncontiguous.
- Existing whole-workout stroke totals are retained independently of incomplete exported lap details.

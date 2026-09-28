# HealthKit Reference Notes

## Purpose

This document is the knowledge base for HealthKit work in Verve Exporter. Update it whenever an agent learns something durable about HealthKit permissions, queries, metrics, route handling, real-device testing, or privacy constraints.

Primary Apple documentation entry point:

- HealthKit: https://developer.apple.com/documentation/healthkit

## Current App Usage

Current code in `VerveExporter/HealthManager.swift` uses:

- `HKHealthStore` as the HealthKit entry point.
- `HKHealthStore.isHealthDataAvailable()` before requesting data.
- `requestAuthorization(toShare:read:)` with read types for workouts, workout routes, heart rate, swimming distance, and swimming stroke count.
- `HKSampleQueryDescriptor` to fetch a bounded prefix of `HKWorkout` samples sorted by end date descending. The activity browser grows the prefix when a selected Verve type is rare, so matching happens before the ten-workout display limit.
- `HKSampleQueryDescriptor` to fetch `HKWorkoutRoute` samples for a selected workout.
- `HKWorkoutRouteQuery` to stream batches of `CLLocation` values from a route.
- `HKSampleQueryDescriptor` to fetch `HKQuantitySample` heart-rate samples between workout start and end.
- `HKWorkout.statistics(for:)` for active energy and available distance totals.
- `HKMetadataKeyIndoorWorkout` to distinguish indoor and outdoor activity mappings.
- `HKMetadataKeyTimeZone` to format exported timestamps in the workout's recorded time zone when the identifier is valid.
- The debug JSON sheet shows a swimming diagnostic payload for selected swim workouts, including workout events, activity-level configuration, and swim statistics. This diagnostic payload is not part of the Verve export schema.
- Normal Verve GeoJSON export maps swimming laps, sets, stroke style, pool length, stroke count, and SWOLF values into the source-neutral `properties.metadata` envelope with `target: "SwimmingMetaData"`.

## Apple Documentation Links To Start From

- HealthKit overview: https://developer.apple.com/documentation/healthkit
- Setting up HealthKit: https://developer.apple.com/documentation/healthkit/setting-up-healthkit
- Authorizing access to health data: https://developer.apple.com/documentation/healthkit/authorizing-access-to-health-data
- Protecting user privacy: https://developer.apple.com/documentation/healthkit/protecting-user-privacy
- `HKHealthStore`: https://developer.apple.com/documentation/healthkit/hkhealthstore
- `HKWorkout`: https://developer.apple.com/documentation/healthkit/hkworkout
- `HKWorkoutActivityType`: https://developer.apple.com/documentation/healthkit/hkworkoutactivitytype
- `HKWorkoutRoute`: https://developer.apple.com/documentation/healthkit/hkworkoutroute
- `HKWorkoutRouteQuery`: https://developer.apple.com/documentation/healthkit/hkworkoutroutequery
- `HKSampleQueryDescriptor`: https://developer.apple.com/documentation/healthkit/hksamplequerydescriptor
- `HKSamplePredicate`: https://developer.apple.com/documentation/healthkit/hksamplepredicate
- `HKQuantitySample`: https://developer.apple.com/documentation/healthkit/hkquantitysample
- `HKQuantityTypeIdentifier.heartRate`: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/heartrate
- `HKMetadataKeyIndoorWorkout`: https://developer.apple.com/documentation/healthkit/hkmetadatakeyindoorworkout
- `HKMetadataKeyTimeZone`: https://developer.apple.com/documentation/healthkit/hkmetadatakeytimezone

If any link moves, search within Apple Developer Documentation and update the link here rather than leaving stale URLs.

## Privacy And Entitlements

HealthKit requires:

- HealthKit entitlement in `VerveExporter/VerveExporter.entitlements`.
- A health share usage description in the generated Info.plist build settings.
- Runtime user authorization for each requested read type.

Never assume authorization succeeds. HealthKit may return no samples because the user denied access, the device has no relevant data, route data was not recorded, or the workout type has no GPS route.

## Query Shape

Workout list:

```swift
let endDateSort = SortDescriptor(\HKWorkout.endDate, order: .reverse)
let startDateSort = SortDescriptor(\HKWorkout.startDate, order: .reverse)
let query = HKSampleQueryDescriptor(
    predicates: [.workout(nil)],
    sortDescriptors: [endDateSort, startDateSort],
    limit: 11
)
let workouts = try await query.result(for: healthStore)
```

The browser requests one extra matching workout to decide whether `Show more` is available. Verve type filtering uses `VerveActivityMapper` on workout metadata; route and heart-rate queries still run only for an individual export or debug preview.

Route lookup for one workout:

```swift
let workoutPredicate = HKQuery.predicateForObjects(from: workout)
let query = HKSampleQueryDescriptor(
    predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: workoutPredicate)],
    sortDescriptors: [],
    limit: 1
)
```

Route streaming:

```swift
HKWorkoutRouteQuery(route: route) { query, locations, done, error in
    // locations arrive in batches; done marks completion
}
```

Heart-rate lookup:

```swift
let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
```

## Export Mapping Notes

Verve expects coordinates as `[longitude, latitude, elevation]`. `CLLocationCoordinate2D` exposes latitude and longitude separately, so preserve the Verve order explicitly.

Heart rate values are exported in beats per minute:

```swift
sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
```

Current nearest-neighbor matching accepts a heart-rate sample when it is within 30 seconds of a route timestamp. If this threshold changes, document the reason and test effect on sparse data.

`HKMetadataKeyTimeZone` is a string compatible with `NSTimeZone` names. Export uses a valid workout-level identifier for every timestamp and the filename date. When it is missing or invalid, export uses `TimeZone.current` captured at export time. ISO-8601 formatting calculates the offset for each timestamp's date, so daylight saving changes within a workout retain the correct offsets without changing the underlying instants.

## Swimming Data Research

Research date: 2026-05-28.

Official Apple entry points:

- `HKQuantityTypeIdentifierSwimmingStrokeCount`: https://developer.apple.com/documentation/healthkit/hkquantitytypeidentifier/swimmingstrokecount
- `HKMetadataKeySwimmingStrokeStyle`: https://developer.apple.com/documentation/healthkit/hkmetadatakeyswimmingstrokestyle
- `HKWorkoutEventTypeLap`: https://developer.apple.com/documentation/healthkit/hkworkouteventtype/hkworkouteventtypelap
- `HKWorkoutEventTypeSegment`: https://developer.apple.com/documentation/healthkit/hkworkouteventtype/hkworkouteventtypesegment
- `HKWorkoutActivity`: https://developer.apple.com/documentation/healthkit/hkworkoutactivity
- Dividing a HealthKit workout into activities: https://developer.apple.com/documentation/healthkit/workouts_and_activity_rings/dividing_a_healthkit_workout_into_activities
- Accessing condensed workout samples: https://developer.apple.com/documentation/healthkit/workouts_and_activity_rings/accessing_condensed_workout_samples
- `HKWorkoutConfiguration`: https://developer.apple.com/documentation/healthkit/hkworkoutconfiguration

Likely HealthKit surfaces for pool swim details:

- `HKWorkout.workoutEvents` contains ordered `HKWorkoutEvent` values. Lap and segment events can have nonzero `dateInterval` durations.
- Lap events can carry `HKMetadataKeySwimmingStrokeStyle`, whose value is an `NSNumber` wrapping `HKSwimmingStrokeStyle`.
- `HKSwimmingStrokeStyle` values are `unknown`, `mixed`, `freestyle`, `backstroke`, `breaststroke`, `butterfly`, and `kickboard`.
- `HKWorkoutEventTypeSegment` is intended for periods of interest during a workout. Apple's docs explicitly mention swimming segments as a way to group consecutive laps with the same stroke style. This is the first place to inspect for Apple Fitness "sets" or auto-set-like intervals, but real-device verification is required because the public docs do not promise that Fitness auto sets are persisted exactly this way.
- `HKWorkout.metadata?[HKMetadataKeyLapLength]` can hold an `HKQuantity` length for the pool length.
- `HKWorkout.metadata?[HKMetadataKeySwimmingLocationType]` can hold an `NSNumber` wrapping `HKWorkoutSwimmingLocationType` (`unknown`, `pool`, or `openWater`).
- `HKWorkout.metadata?[HKMetadataKeySWOLFScore]` can hold an `NSNumber` SWOLF score for the whole workout. SDK comments also refer to SWOLF for lap and segment events, so inspect event metadata on device.
- `HKWorkout.workoutActivities` is available on iOS 16+. Activities partition longer workouts and can expose per-activity `workoutConfiguration`, `workoutEvents`, and `allStatistics`. Every workout has at least one activity, even if HealthKit creates it implicitly.
- `HKWorkoutActivity.workoutConfiguration.lapLength` and `.swimmingLocationType` may duplicate or clarify workout-level swim metadata.
- `HKQuantityTypeIdentifierSwimmingStrokeCount` is a cumulative count quantity. Add the corresponding read type before querying stroke-count samples directly.
- `HKQuantityTypeIdentifierDistanceSwimming` is the cumulative swimming distance type. Existing export code reads this from `HKWorkout.statistics(for:)`; detailed lap/set distance may need interval statistics or associated samples.

Verified pool-swim findings from a real device on 2026-05-28:

- A pool swim recorded by Apple Watch exposed both `HKWorkoutEventType.lap` and `HKWorkoutEventType.segment` events.
- The sample workout had one lap event per pool length. A 50 m pool-length workout with 500 m total swimming distance produced 10 lap events.
- Lap events included `HKMetadataKeySwimmingStrokeStyle` and `HKMetadataKeySWOLFScore`.
- Segment events included `HKMetadataKeySWOLFScore` but did not include `HKMetadataKeySwimmingStrokeStyle` in the observed workout.
- Segment intervals appeared to group one or more consecutive lap events. Segment SWOLF matched the average of the overlapping lap SWOLF values in observed multi-lap segments.
- The single `HKWorkoutActivity` for the swim exposed `workoutConfiguration.lapLength`, `workoutConfiguration.swimmingLocationType`, `distanceSwimming`, `swimmingStrokeCount`, active energy, basal energy, and heart-rate statistics.
- Workout metadata included `HKMetadataKeyLapLength`, `HKMetadataKeySwimmingLocationType`, time zone, average METs, and `HKMetadataKeyIndoorWorkout`.
- `HKMetadataKeyIndoorWorkout` was not sufficient for swimming subtype mapping in the observed pool swim. Use `HKMetadataKeySwimmingLocationType` or `HKWorkoutActivity.workoutConfiguration.swimmingLocationType` to distinguish pool from open water.
- No lane-number-like field was observed. HealthKit exposes pool length and lap events, not a lane identifier.

Verified exporter checkpoint from a real device on 2026-05-29:

- The first normal Verve GeoJSON swim export included swim metadata. The current export shape uses the canonical `properties.metadata` envelope with `target: "SwimmingMetaData"`, `version: "1.0"`, and swim fields under `data`.
- The observed export contained 10 lap objects, 8 set objects, `poolLengthMeters: 50`, and `totalStrokeCount: 337`, matching the diagnostic probe for the same workout.
- Lap objects contained source-neutral `strokeStyle`, `strokeCount`, and `swolf` fields derived from HealthKit lap event metadata.
- Set objects contained overlapping lap indexes, lap counts, distances, inferred stroke style, inferred stroke count, and average SWOLF.
- No swimming location field was emitted inside swim metadata `data`.
- The first checkpoint still exported the pool swim as `activitySubType: "Open Water"` because subtype mapping still used `HKMetadataKeyIndoorWorkout`; subsequent implementation should use swimming location type for pool vs open water.

Recommended retrieval order for a selected swimming workout:

1. Read workout-level swim metadata: lap length, swimming location type, SWOLF, distance swimming, and swimming stroke count statistics.
2. Inspect `workout.workoutEvents?.filter { $0.type == .lap }` for lap intervals and stroke-style metadata.
3. Inspect `workout.workoutEvents?.filter { $0.type == .segment }` for set-like intervals, segment metadata, and overlapping lap membership.
4. Inspect `workout.workoutActivities` for activity-level configuration, statistics, and events, especially on workouts recorded with newer watchOS versions.
5. Use `HKStatisticsQuery`/statistics descriptors for `distanceSwimming` and `swimmingStrokeCount` over lap or segment intervals when exact per-interval quantities are needed. Apple may condense older first-party workout samples, so statistics APIs are safer for totals than assuming one simple `HKQuantitySample` per interval.
6. Use `HKQuantitySeriesSampleQuery` only if the app needs the detailed backing values from condensed samples.

Implemented export mapping:

- `HKWorkoutActivity.workoutConfiguration.lapLength` or `HKMetadataKeyLapLength` -> `metadata.data.poolLengthMeters`
- `HKQuantityTypeIdentifierSwimmingStrokeCount` workout statistic -> `metadata.data.totalStrokeCount`
- `HKWorkoutEventType.lap` -> `metadata.data.laps`
- `HKWorkoutEventType.segment` -> `metadata.data.sets`
- `HKMetadataKeySwimmingStrokeStyle` on lap events -> lap `strokeStyle`
- `HKMetadataKeySWOLFScore` on lap events -> lap `swolf`
- `HKMetadataKeySWOLFScore` on segment events -> set `averageSwolf`
- Lap `strokeCount` -> inferred from `swolf - durationSeconds` when non-negative
- Set `strokeStyle`, `strokeCount`, and `distanceMeters` -> inferred from overlapping laps
- `HKWorkoutActivity.workoutConfiguration.swimmingLocationType` or `HKMetadataKeySwimmingLocationType` -> Verve `activitySubType`, not swim metadata `data`

Real-device questions to continue testing:

- Does Fitness "Auto Sets" always map to `HKWorkoutEventTypeSegment`, or can it vary by watchOS version and workout shape?
- Do segment events ever carry `HKMetadataKeySwimmingStrokeStyle`, or should segment style always be inferred from overlapping laps?
- Is stroke style present on every lap across several workouts, or only when Apple can classify it confidently?
- What does an open-water swim contain: route only, distance/strokes, lap events, segment events, or no stroke-style metadata?
- Can interval statistics recover per-lap and per-segment stroke counts from HealthKit, or should stroke counts be inferred from SWOLF and duration when HealthKit does not expose interval statistics directly?

## Manual Testing Reality

The automated export suite uses synthetic HealthKit objects in memory and does not require HealthKit authorization or saved workouts. Apple documents simulator sample accounts for clinical records; it does not provide a comparable preloaded workout/route fixture set. `HKWorkoutBuilder`, `HKQuantitySample`, and `HKWorkoutRouteBuilder` can create synthetic saved workouts for a later opt-in simulator integration check, with write authorization. Keep that check on a dedicated simulator.

Sources: https://developer.apple.com/documentation/healthkit/accessing-sample-data-in-the-simulator ; https://developer.apple.com/documentation/healthkit/hkworkoutbuilder ; https://developer.apple.com/documentation/healthkit/hkworkoutroutebuilder

HealthKit route export is hard to test without real device data. Current practical smoke testing uses the user's own workouts. That is acceptable for local/manual validation but not for committed fixtures.

Before adding fixtures:

- Prefer synthetic or heavily sanitized JSON that preserves shape but not real routes.
- Remove or alter exact locations, timestamps, names, and metadata.
- Document fixture provenance and safety in `docs/SECURITY.md`.

## Research Backlog

Use this section as the starting place for future HealthKit investigations.

- Multiple routes per workout: determine whether `limit: 1` loses route samples and how to map multiple routes to multiple Verve `features`.
- Route segmentation: determine whether route pauses/gaps should become separate Verve line features.
- Cadence: identify the correct HealthKit quantity identifiers for running and cycling cadence and expected units.
- Cycling power: identify the quantity type and authorization requirements for power samples.
- Speed: decide whether to export sampled speed, derive it from route points, or rely on backend-derived stats.
- Elevation gain/loss: decide whether to compute from route altitude, use workout statistics if available, or let backend derive it.
- Moving duration: determine whether HealthKit provides a trustworthy moving-time measure distinct from total `HKWorkout.duration`, including pauses and stationary workouts, before adding `movingDurationSeconds` to iOS exports.
- Swimming: use verified pool-lap and segment findings above to design the Verve export shape; still test open-water workouts.
- Indoor workouts: decide expected behavior for no-geometry features with heart rate only.
- Permission UX: distinguish no authorization, no data, and unsupported data in user-facing errors.

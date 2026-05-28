# HealthKit Reference Notes

## Purpose

This document is the knowledge base for HealthKit work in Verve Exporter. Update it whenever an agent learns something durable about HealthKit permissions, queries, metrics, route handling, real-device testing, or privacy constraints.

Primary Apple documentation entry point:

- HealthKit: https://developer.apple.com/documentation/healthkit

## Current App Usage

Current code in `VerveExporter/HealthManager.swift` uses:

- `HKHealthStore` as the HealthKit entry point.
- `HKHealthStore.isHealthDataAvailable()` before requesting data.
- `requestAuthorization(toShare:read:)` with read types for workouts, workout routes, and heart rate.
- `HKSampleQueryDescriptor` to fetch `HKWorkout` samples sorted by end date descending.
- `HKSampleQueryDescriptor` to fetch `HKWorkoutRoute` samples for a selected workout.
- `HKWorkoutRouteQuery` to stream batches of `CLLocation` values from a route.
- `HKSampleQueryDescriptor` to fetch `HKQuantitySample` heart-rate samples between workout start and end.
- `HKWorkout.statistics(for:)` for active energy and available distance totals.
- `HKMetadataKeyIndoorWorkout` to distinguish indoor and outdoor activity mappings.

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
let sortDescriptor = SortDescriptor(\HKWorkout.endDate, order: .reverse)
let query = HKSampleQueryDescriptor(
    predicates: [.workout(nil)],
    sortDescriptors: [sortDescriptor],
    limit: nil
)
let workouts = try await query.result(for: healthStore)
```

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

## Manual Testing Reality

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
- Swimming: confirm route/distance behavior for pool and open-water workouts.
- Indoor workouts: decide expected behavior for no-geometry features with heart rate only.
- Permission UX: distinguish no authorization, no data, and unsupported data in user-facing errors.

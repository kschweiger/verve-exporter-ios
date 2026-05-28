//
//  HealthManager.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import Foundation
import HealthKit
import CoreLocation

// Helper to hold your backend schema
struct VerveActivityCategory {
    let type: String
    let subType: String?
}

private struct SwimDiagnosticReport: Encodable {
    let generatedAt: String
    let note: String
    let workout: SwimWorkoutDiagnostic
    let totals: [SwimStatisticDiagnostic]
    let eventCounts: [String: Int]
    let laps: [SwimEventDiagnostic]
    let segments: [SwimEventDiagnostic]
    let otherEvents: [SwimEventDiagnostic]
    let activities: [SwimActivityDiagnostic]
}

private struct SwimWorkoutDiagnostic: Encodable {
    let uuid: String
    let startTime: String
    let endTime: String
    let durationSeconds: Double
    let lapLengthMeters: Double?
    let swimmingLocationType: String?
    let swolfScore: Double?
    let metadata: [String: String]
}

private struct SwimEventDiagnostic: Encodable {
    let type: String
    let startTime: String
    let endTime: String
    let durationSeconds: Double
    let strokeStyle: String?
    let lapLengthMeters: Double?
    let swolfScore: Double?
    let metadata: [String: String]
}

private struct SwimActivityDiagnostic: Encodable {
    let uuid: String
    let startTime: String
    let endTime: String?
    let durationSeconds: Double
    let activityType: String
    let lapLengthMeters: Double?
    let swimmingLocationType: String
    let locationTypeRawValue: Int
    let eventCounts: [String: Int]
    let availableStatisticIdentifiers: [String]
    let statistics: [SwimStatisticDiagnostic]
    let metadata: [String: String]
}

private struct SwimStatisticDiagnostic: Encodable {
    let identifier: String
    let unit: String
    let sum: Double?
    let average: Double?
    let minimum: Double?
    let maximum: Double?
}

@Observable
class HealthManager {
    let healthStore = HKHealthStore()

    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        var readTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]
        let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
            .heartRate,
            .distanceSwimming,
            .swimmingStrokeCount
        ]
        for identifier in quantityIdentifiers {
            if let type = HKObjectType.quantityType(forIdentifier: identifier) {
                readTypes.insert(type)
            }
        }
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    func fetchWorkouts() async throws -> [HKWorkout] {
        let sortDescriptor = SortDescriptor(\HKWorkout.endDate, order: .reverse)
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(nil)],
            sortDescriptors: [sortDescriptor],
            limit: nil
        )
        return try await query.result(for: healthStore)
    }

    func generateDebugJSON(for workout: HKWorkout) async throws -> String {
        if workout.workoutActivityType == .swimming {
            return try generateSwimDiagnosticJSON(for: workout)
        }

        let url = try await generateGeoJSON(for: workout)
        let data = try Data(contentsOf: url)
        return String(data: data, encoding: .utf8) ?? "Encoding Error"
    }

    func generateGeoJSON(for workout: HKWorkout) async throws -> URL {
        // Fetch Data Streams
        async let locationsTask = try? fetchRouteLocations(for: workout)
        async let heartRatesTask = try? fetchHeartRates(for: workout)

        let (gpsDataOrNil, hrDataOrNil) = await (locationsTask, heartRatesTask)

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        // Prepare Data
        var features: [LineFeature] = []
        var allHRValues: [Double] = []

        // Process Logic
        if let gpsData = gpsDataOrNil, !gpsData.isEmpty {
            // --- SCENARIO A: GPS Exists (Outdoor Run/Bike/Hike) ---
            var coords: [Coordinates] = []
            var times: [String] = []
            var hrs: [Int?] = []

            let hrSamples = hrDataOrNil ?? []

            for location in gpsData {
                // Geometry
                coords.append([
                    location.coordinate.longitude,
                    location.coordinate.latitude,
                    location.altitude
                ])

                // Time
                times.append(isoFormatter.string(from: location.timestamp))

                // Nearest Neighbor HR
                let closestHR = hrSamples.min(by: {
                    abs($0.startDate.timeIntervalSince(location.timestamp)) < abs($1.startDate.timeIntervalSince(location.timestamp))
                })

                var hrVal: Int? = nil
                if let hr = closestHR, abs(hr.startDate.timeIntervalSince(location.timestamp)) < 30 {
                    let val = hr.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    hrVal = Int(round(val))
                    allHRValues.append(val)
                }
                hrs.append(hrVal)
            }

            let geometry = LineStringGeometry(coordinates: coords)
            let properties = LineProperties(
                coordTimes: times,
                heartRates: hrs,
                cadences: nil, powers: nil, temperatures: nil
            )

            features.append(LineFeature(geometry: geometry, properties: properties))

        } else if let hrSamples = hrDataOrNil, !hrSamples.isEmpty {
            // --- SCENARIO B: No GPS, but HR Exists (Treadmill, Strength, Yoga) ---
            var times: [String] = []
            var hrs: [Int?] = []

            for sample in hrSamples {
                // Time
                times.append(isoFormatter.string(from: sample.startDate))

                // Value
                let val = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let intVal = Int(round(val))

                hrs.append(intVal)
                allHRValues.append(val) // Add to stats
            }

            let properties = LineProperties(
                coordTimes: times,
                heartRates: hrs,
                cadences: nil, powers: nil, temperatures: nil
            )

            // Note: geometry is nil here
            features.append(LineFeature(geometry: nil, properties: properties))
        }

        // Calculate Global Properties

        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let totalCalories = workout.statistics(for: energyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())

        var totalDistance: Double? = nil
        let distanceTypes: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning, .distanceCycling, .distanceSwimming
        ]
        for identifier in distanceTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier),
               let quantity = workout.statistics(for: type)?.sumQuantity() {
                totalDistance = quantity.doubleValue(for: .meter())
                break
            }
        }

        let hrStats = calculateStats(from: allHRValues)

        let activityStats = ActivityStats(
            speed: nil,
            heartRate: hrStats,
            power: nil,
            cadence: nil
        )

        // --- Map Activity Types ---
        let mapping = mapToVerveActivity(workout: workout)
        let displayName = workout.workoutActivityType.name

        let verveProps = VerveProperties(
            name: displayName,
            description: nil,
            activityType: mapping.type,
            activitySubType: mapping.subType,
            startTime: isoFormatter.string(from: workout.startDate),
            durationSeconds: workout.duration,
            movingDistanceSeconds: workout.duration,
            totalDistanceMeters: totalDistance,
            totalEnergyKcal: totalCalories,
            elevationGain: nil,
            elevationLoss: nil,
            stats: activityStats,
            equipment: nil
        )

        let root = VerveFeature(features: features, properties: verveProps)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(root)

        // --- Filename Generation ---
        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = fileDateFormatter.string(from: workout.startDate)

        // Concatenate Type and SubType (if present)
        var fileNameType = mapping.type
        if let sub = mapping.subType {
            fileNameType += " \(sub)"
        }

        // Replace spaces with underscores
        let safeType = fileNameType.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(dateString)_\(safeType).json"

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)

        return tempURL
    }

    private func generateSwimDiagnosticJSON(for workout: HKWorkout) throws -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]

        let events = workout.workoutEvents ?? []
        let laps = events
            .filter { $0.type == .lap }
            .map { swimEventDiagnostic(from: $0, isoFormatter: isoFormatter) }
        let segments = events
            .filter { $0.type == .segment }
            .map { swimEventDiagnostic(from: $0, isoFormatter: isoFormatter) }
        let otherEvents = events
            .filter { $0.type != .lap && $0.type != .segment }
            .map { swimEventDiagnostic(from: $0, isoFormatter: isoFormatter) }

        let report = SwimDiagnosticReport(
            generatedAt: isoFormatter.string(from: Date()),
            note: "Diagnostic only. This is not Verve export schema.",
            workout: SwimWorkoutDiagnostic(
                uuid: workout.uuid.uuidString,
                startTime: isoFormatter.string(from: workout.startDate),
                endTime: isoFormatter.string(from: workout.endDate),
                durationSeconds: workout.duration,
                lapLengthMeters: lapLengthMeters(from: workout.metadata),
                swimmingLocationType: swimmingLocationTypeName(from: workout.metadata),
                swolfScore: swolfScore(from: workout.metadata),
                metadata: metadataDiagnostic(from: workout.metadata, isoFormatter: isoFormatter)
            ),
            totals: swimStatistics(for: workout),
            eventCounts: eventCounts(for: events),
            laps: laps,
            segments: segments,
            otherEvents: otherEvents,
            activities: workout.workoutActivities.map {
                swimActivityDiagnostic(from: $0, isoFormatter: isoFormatter)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        return String(data: data, encoding: .utf8) ?? "Encoding Error"
    }


    private func mapToVerveActivity(workout: HKWorkout) -> VerveActivityCategory {
        // Detect Indoor status via Metadata
        let isIndoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false

        switch workout.workoutActivityType {

            // --- CYCLING ---
        case .cycling:
            if isIndoor {
                return VerveActivityCategory(type: "Cycling", subType: "Indoor")
            } else {
                return VerveActivityCategory(type: "Cycling", subType: nil)
            }

            // --- FOOT SPORTS ---
        case .walking:
            if isIndoor {
                return VerveActivityCategory(type: "Foot Sports", subType: "Treadmill")
            } else {
                return VerveActivityCategory(type: "Foot Sports", subType: "Walk")
            }

        case .running:
            if isIndoor {
                return VerveActivityCategory(type: "Foot Sports", subType: "Treadmill")
            } else {
                return VerveActivityCategory(type: "Foot Sports", subType: "Run")
            }

        case .hiking:
            return VerveActivityCategory(type: "Foot Sports", subType: "Hike")

            // --- WINTER SPORTS ---
        case .crossCountrySkiing:
            return VerveActivityCategory(type: "Winter Sports", subType: "Cross-country Skiing")
        case .downhillSkiing, .snowSports:
            return VerveActivityCategory(type: "Winter Sports", subType: "Downhill Skiing")
        case .snowboarding:
            return VerveActivityCategory(type: "Winter Sports", subType: "Downhill Skiing")

            // --- SWIMMING ---
        case .swimming:
            return VerveActivityCategory(type: "Swimming", subType: isIndoor ? "Indoor" : "Open Water")

            // --- STRENGTH TRAINING ---
        case .traditionalStrengthTraining:
            return VerveActivityCategory(type: "Strength Training", subType: "Weight Training")
        case .functionalStrengthTraining:
            return VerveActivityCategory(type: "Strength Training", subType: "Circuit Training")
        case .crossTraining:
            return VerveActivityCategory(type: "Strength Training", subType: "CrossFit")

            // --- INDOOR CARDIO ---
        case .elliptical:
            return VerveActivityCategory(type: "Indoor Cardio", subType: "Elliptical")
        case .stairClimbing:
            return VerveActivityCategory(type: "Indoor Cardio", subType: "Stair Stepper")
        case .rowing:
            return VerveActivityCategory(type: "Indoor Cardio", subType: "Indoor Rowing")

            // --- FITNESS & FLEXIBILITY ---
        case .yoga:
            return VerveActivityCategory(type: "Fitness & Flexibility", subType: "Yoga")
        case .pilates:
            return VerveActivityCategory(type: "Fitness & Flexibility", subType: "Pilates")
        case .highIntensityIntervalTraining:
            return VerveActivityCategory(type: "Fitness & Flexibility", subType: "HIIT")
            // --- CLIMBING ---
        case .climbing:
            return VerveActivityCategory(type: "Climbing", subType: nil)
            // --- OTHER ---
        case .skatingSports:
            return VerveActivityCategory(type: "Other", subType: "Skateboarding")

            // --- DEFAULTS ---
        default:
            return VerveActivityCategory(type: "Other", subType: "Other")
        }
    }

    private func calculateStats(from values: [Double]) -> MetricSummary? {
        guard !values.isEmpty else {
            return nil
        }

        let min = values.min()
        let max = values.max()
        let sum = values.reduce(0, +)
        let avg = sum / Double(values.count)

        return MetricSummary(avg: avg, max: max, min: min)
    }

    private func swimEventDiagnostic(from event: HKWorkoutEvent, isoFormatter: ISO8601DateFormatter) -> SwimEventDiagnostic {
        SwimEventDiagnostic(
            type: workoutEventTypeName(event.type),
            startTime: isoFormatter.string(from: event.dateInterval.start),
            endTime: isoFormatter.string(from: event.dateInterval.end),
            durationSeconds: event.dateInterval.duration,
            strokeStyle: swimmingStrokeStyleName(from: event.metadata),
            lapLengthMeters: lapLengthMeters(from: event.metadata),
            swolfScore: swolfScore(from: event.metadata),
            metadata: metadataDiagnostic(from: event.metadata, isoFormatter: isoFormatter)
        )
    }

    private func swimActivityDiagnostic(from activity: HKWorkoutActivity, isoFormatter: ISO8601DateFormatter) -> SwimActivityDiagnostic {
        let configuration = activity.workoutConfiguration
        return SwimActivityDiagnostic(
            uuid: activity.uuid.uuidString,
            startTime: isoFormatter.string(from: activity.startDate),
            endTime: activity.endDate.map { isoFormatter.string(from: $0) },
            durationSeconds: activity.duration,
            activityType: workoutActivityTypeName(configuration.activityType),
            lapLengthMeters: configuration.lapLength?.doubleValue(for: .meter()),
            swimmingLocationType: swimmingLocationTypeName(configuration.swimmingLocationType),
            locationTypeRawValue: configuration.locationType.rawValue,
            eventCounts: eventCounts(for: activity.workoutEvents),
            availableStatisticIdentifiers: activity.allStatistics.keys.map(\.identifier).sorted(),
            statistics: swimStatistics(for: activity),
            metadata: metadataDiagnostic(from: activity.metadata, isoFormatter: isoFormatter)
        )
    }

    private func swimStatistics(for workout: HKWorkout) -> [SwimStatisticDiagnostic] {
        guard let distanceSwimming = HKQuantityType.quantityType(forIdentifier: .distanceSwimming),
              let swimmingStrokeCount = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return []
        }

        return [
            statisticDiagnostic(
                identifier: "distanceSwimming",
                statistics: workout.statistics(for: distanceSwimming),
                unit: .meter(),
                unitName: "m"
            ),
            statisticDiagnostic(
                identifier: "swimmingStrokeCount",
                statistics: workout.statistics(for: swimmingStrokeCount),
                unit: .count(),
                unitName: "count"
            ),
            statisticDiagnostic(
                identifier: "activeEnergyBurned",
                statistics: workout.statistics(for: activeEnergy),
                unit: .kilocalorie(),
                unitName: "kcal"
            )
        ].compactMap { $0 }
    }

    private func swimStatistics(for activity: HKWorkoutActivity) -> [SwimStatisticDiagnostic] {
        guard let distanceSwimming = HKQuantityType.quantityType(forIdentifier: .distanceSwimming),
              let swimmingStrokeCount = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount),
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return []
        }

        return [
            statisticDiagnostic(
                identifier: "distanceSwimming",
                statistics: activity.statistics(for: distanceSwimming),
                unit: .meter(),
                unitName: "m"
            ),
            statisticDiagnostic(
                identifier: "swimmingStrokeCount",
                statistics: activity.statistics(for: swimmingStrokeCount),
                unit: .count(),
                unitName: "count"
            ),
            statisticDiagnostic(
                identifier: "activeEnergyBurned",
                statistics: activity.statistics(for: activeEnergy),
                unit: .kilocalorie(),
                unitName: "kcal"
            )
        ].compactMap { $0 }
    }

    private func statisticDiagnostic(
        identifier: String,
        statistics: HKStatistics?,
        unit: HKUnit,
        unitName: String
    ) -> SwimStatisticDiagnostic? {
        guard let statistics else {
            return nil
        }

        return SwimStatisticDiagnostic(
            identifier: identifier,
            unit: unitName,
            sum: statistics.sumQuantity()?.doubleValue(for: unit),
            average: statistics.averageQuantity()?.doubleValue(for: unit),
            minimum: statistics.minimumQuantity()?.doubleValue(for: unit),
            maximum: statistics.maximumQuantity()?.doubleValue(for: unit)
        )
    }

    private func eventCounts(for events: [HKWorkoutEvent]) -> [String: Int] {
        events.reduce(into: [:]) { counts, event in
            counts[workoutEventTypeName(event.type), default: 0] += 1
        }
    }

    private func metadataDiagnostic(
        from metadata: [String: Any]?,
        isoFormatter: ISO8601DateFormatter
    ) -> [String: String] {
        guard let metadata else {
            return [:]
        }

        return metadata.reduce(into: [:]) { result, entry in
            result[entry.key] = metadataValueDescription(entry.value, isoFormatter: isoFormatter)
        }
    }

    private func metadataValueDescription(_ value: Any, isoFormatter: ISO8601DateFormatter) -> String {
        if let quantity = value as? HKQuantity {
            return String(describing: quantity)
        }
        if let date = value as? Date {
            return isoFormatter.string(from: date)
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let string = value as? String {
            return string
        }
        return String(describing: value)
    }

    private func lapLengthMeters(from metadata: [String: Any]?) -> Double? {
        guard let quantity = metadata?[HKMetadataKeyLapLength] as? HKQuantity else {
            return nil
        }
        return quantity.doubleValue(for: .meter())
    }

    private func swolfScore(from metadata: [String: Any]?) -> Double? {
        (metadata?[HKMetadataKeySWOLFScore] as? NSNumber)?.doubleValue
    }

    private func swimmingStrokeStyleName(from metadata: [String: Any]?) -> String? {
        guard let rawValue = (metadata?[HKMetadataKeySwimmingStrokeStyle] as? NSNumber)?.intValue,
              let style = HKSwimmingStrokeStyle(rawValue: rawValue) else {
            return nil
        }

        switch style {
        case .unknown:
            return "unknown"
        case .mixed:
            return "mixed"
        case .freestyle:
            return "freestyle"
        case .backstroke:
            return "backstroke"
        case .breaststroke:
            return "breaststroke"
        case .butterfly:
            return "butterfly"
        case .kickboard:
            return "kickboard"
        @unknown default:
            return "unknown(\(rawValue))"
        }
    }

    private func swimmingLocationTypeName(from metadata: [String: Any]?) -> String? {
        guard let rawValue = (metadata?[HKMetadataKeySwimmingLocationType] as? NSNumber)?.intValue,
              let locationType = HKWorkoutSwimmingLocationType(rawValue: rawValue) else {
            return nil
        }
        return swimmingLocationTypeName(locationType)
    }

    private func swimmingLocationTypeName(_ locationType: HKWorkoutSwimmingLocationType) -> String {
        switch locationType {
        case .unknown:
            return "unknown"
        case .pool:
            return "pool"
        case .openWater:
            return "openWater"
        @unknown default:
            return "unknown(\(locationType.rawValue))"
        }
    }

    private func workoutEventTypeName(_ type: HKWorkoutEventType) -> String {
        switch type {
        case .pause:
            return "pause"
        case .resume:
            return "resume"
        case .lap:
            return "lap"
        case .marker:
            return "marker"
        case .motionPaused:
            return "motionPaused"
        case .motionResumed:
            return "motionResumed"
        case .segment:
            return "segment"
        case .pauseOrResumeRequest:
            return "pauseOrResumeRequest"
        @unknown default:
            return "unknown(\(type.rawValue))"
        }
    }

    private func workoutActivityTypeName(_ type: HKWorkoutActivityType) -> String {
        switch type {
        case .swimming:
            return "swimming"
        case .transition:
            return "transition"
        case .swimBikeRun:
            return "swimBikeRun"
        default:
            return "other(\(type.rawValue))"
        }
    }

    private func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: workoutPredicate)],
            sortDescriptors: [],
            limit: 1
        )

        guard let route = try await routeQuery.result(for: healthStore).first as? HKWorkoutRoute else {
            return []
        }

        var allLocations: [CLLocation] = []
        for try await batch in streamRouteLocations(route: route) {
            allLocations.append(contentsOf: batch)
        }
        return allLocations
    }

    private func streamRouteLocations(route: HKWorkoutRoute) -> AsyncThrowingStream<[CLLocation], Error> {
        return AsyncThrowingStream { continuation in
            let query = HKWorkoutRouteQuery(route: route) { query, locationsOrNil, done, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                if let locations = locationsOrNil {
                    continuation.yield(locations)
                }
                if done {
                    continuation.finish()
                }
            }
            self.healthStore.execute(query)
        }
    }

    private func fetchHeartRates(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKSamplePredicate.quantitySample(
            type: hrType,
            predicate: HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        )
        let query = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await query.result(for: healthStore)
    }
}

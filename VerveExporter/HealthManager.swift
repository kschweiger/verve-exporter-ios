//
//  HealthManager.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import CoreLocation
import Foundation
import HealthKit

struct GeoJSONExport {
    let data: Data
    let fileName: String
}

enum GeoJSONExportError: LocalizedError {
    case noSamples

    var errorDescription: String? {
        switch self {
        case .noSamples:
            return "This workout has no route or heart-rate samples to export."
        }
    }
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

    func fetchWorkouts(limit: Int) async throws -> [HKWorkout] {
        let endDateSort = SortDescriptor(\HKWorkout.endDate, order: .reverse)
        let startDateSort = SortDescriptor(\HKWorkout.startDate, order: .reverse)
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(nil)],
            sortDescriptors: [endDateSort, startDateSort],
            limit: limit
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
        async let locationsTask = try? fetchRouteLocations(for: workout)
        async let heartRatesTask = try? fetchHeartRates(for: workout)
        let (gpsDataOrNil, hrDataOrNil) = await(locationsTask, heartRatesTask)

        let export = try buildGeoJSON(
            for: workout,
            locations: gpsDataOrNil ?? [],
            heartRates: hrDataOrNil ?? [],
            fallbackTimeZone: .current
        )
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(export.fileName)
        try export.data.write(to: tempURL)
        return tempURL
    }

    func buildGeoJSON(
        for workout: HKWorkout,
        locations: [CLLocation],
        heartRates: [HKQuantitySample],
        fallbackTimeZone: TimeZone
    ) throws -> GeoJSONExport {
        guard !locations.isEmpty || !heartRates.isEmpty else {
            throw GeoJSONExportError.noSamples
        }

        let exportTimeZone = exportTimeZone(for: workout, fallback: fallbackTimeZone)
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        isoFormatter.timeZone = exportTimeZone
        let swimmingMetadata = buildSwimmingMetadata(for: workout, isoFormatter: isoFormatter)

        let exportFeature = WorkoutFeatureBuilder.build(
            locations: locations,
            heartRates: heartRates,
            isoFormatter: isoFormatter
        )
        let swimmingLocationType = workout.workoutActivityType == .swimming
            ? swimmingLocationType(for: workout)
            : nil
        let mapping = VerveActivityMapper.category(
            for: workout,
            swimmingLocationType: swimmingLocationType
        )
        let verveProperties = buildVerveProperties(
            for: workout,
            mapping: mapping,
            isoFormatter: isoFormatter,
            swimmingMetadata: swimmingMetadata,
            heartRateValues: exportFeature.heartRateValues
        )

        let root = VerveFeature(features: [exportFeature.feature], properties: verveProperties)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        let data = try encoder.encode(root)

        let fileName = exportFileName(for: workout, mapping: mapping, timeZone: exportTimeZone)
        return GeoJSONExport(data: data, fileName: fileName)
    }

    private func exportTimeZone(for workout: HKWorkout, fallback: TimeZone) -> TimeZone {
        guard let identifier = workout.metadata?[HKMetadataKeyTimeZone] as? String,
              let timeZone = TimeZone(identifier: identifier)
        else {
            return fallback
        }
        return timeZone
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

    private func buildVerveProperties(
        for workout: HKWorkout,
        mapping: VerveActivityCategory,
        isoFormatter: ISO8601DateFormatter,
        swimmingMetadata: SwimmingMetadata?,
        heartRateValues: [Double]
    ) -> VerveProperties {
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let totalCalories = workout.statistics(for: energyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())

        let distanceTypes: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning, .distanceCycling, .distanceSwimming
        ]
        var totalDistance: Double?
        for identifier in distanceTypes {
            guard let type = HKQuantityType.quantityType(forIdentifier: identifier) else { continue }
            guard let quantity = workout.statistics(for: type)?.sumQuantity() else { continue }
            totalDistance = quantity.doubleValue(for: .meter())
            break
        }

        let activityStats = ActivityStats(
            speed: nil,
            heartRate: calculateStats(from: heartRateValues),
            power: nil,
            cadence: nil
        )
        return VerveProperties(
            name: workout.workoutActivityType.name,
            description: nil,
            activityType: mapping.type,
            activitySubType: mapping.subType,
            startTime: isoFormatter.string(from: workout.startDate),
            durationSeconds: workout.duration,
            totalDistanceMeters: totalDistance,
            totalEnergyKcal: totalCalories,
            elevationGain: nil,
            elevationLoss: nil,
            stats: activityStats,
            equipment: nil,
            metadata: swimmingMetadata.map {
                VerveMetadata(target: "SwimmingMetaData", version: "1.0", data: $0)
            }
        )
    }

    private func exportFileName(
        for workout: HKWorkout,
        mapping: VerveActivityCategory,
        timeZone: TimeZone
    ) -> String {
        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        fileDateFormatter.timeZone = timeZone
        let dateString = fileDateFormatter.string(from: workout.startDate)
        let activityName = [mapping.type, mapping.subType].compactMap { $0 }.joined(separator: " ")
        let safeType = activityName.replacingOccurrences(of: " ", with: "_")
        return "\(dateString)_\(safeType).json"
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
            let query = HKWorkoutRouteQuery(route: route) { _, locationsOrNil, done, error in
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

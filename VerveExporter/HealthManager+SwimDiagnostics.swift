import Foundation
import HealthKit

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

extension HealthManager {
    func generateSwimDiagnosticJSON(for workout: HKWorkout) throws -> String {
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

    private func swimEventDiagnostic(from event: HKWorkoutEvent,
                                     isoFormatter: ISO8601DateFormatter) -> SwimEventDiagnostic {
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

    private func swimActivityDiagnostic(from activity: HKWorkoutActivity,
                                        isoFormatter: ISO8601DateFormatter) -> SwimActivityDiagnostic {
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
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else {
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
              let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)
        else {
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

    func lapLengthMeters(from metadata: [String: Any]?) -> Double? {
        guard let quantity = metadata?[HKMetadataKeyLapLength] as? HKQuantity else {
            return nil
        }
        return quantity.doubleValue(for: .meter())
    }

    func swolfScore(from metadata: [String: Any]?) -> Double? {
        (metadata?[HKMetadataKeySWOLFScore] as? NSNumber)?.doubleValue
    }

    func swimmingStrokeStyleName(from metadata: [String: Any]?) -> String? {
        guard let rawValue = (metadata?[HKMetadataKeySwimmingStrokeStyle] as? NSNumber)?.intValue,
              let style = HKSwimmingStrokeStyle(rawValue: rawValue)
        else {
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

    func swimmingLocationTypeName(from metadata: [String: Any]?) -> String? {
        guard let locationType = swimmingLocationType(from: metadata) else {
            return nil
        }
        return swimmingLocationTypeName(locationType)
    }

    func swimmingLocationType(from metadata: [String: Any]?) -> HKWorkoutSwimmingLocationType? {
        guard let rawValue = (metadata?[HKMetadataKeySwimmingLocationType] as? NSNumber)?.intValue else {
            return nil
        }
        return HKWorkoutSwimmingLocationType(rawValue: rawValue)
    }

    func swimmingLocationTypeName(_ locationType: HKWorkoutSwimmingLocationType) -> String {
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
}

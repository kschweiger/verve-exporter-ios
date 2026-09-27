import Foundation
import HealthKit

extension HealthManager {
    private struct IndexedSwimLap {
        let event: HKWorkoutEvent
        let metadata: SwimLapMetadata
    }

    func buildSwimmingMetadata(
        for workout: HKWorkout,
        isoFormatter: ISO8601DateFormatter
    ) -> SwimmingMetadata? {
        guard workout.workoutActivityType == .swimming else {
            return nil
        }

        let poolLength = poolLengthMeters(for: workout)
        let totalStrokeCount = totalSwimStrokeCount(for: workout)
        let events = workout.workoutEvents ?? []
        let lapEvents = sortedEvents(events, ofType: .lap)
        let segmentEvents = sortedEvents(events, ofType: .segment)

        let indexedLaps = buildSwimLaps(
            from: lapEvents,
            poolLengthMeters: poolLength,
            isoFormatter: isoFormatter
        )
        let laps = indexedLaps.map(\.metadata)
        let sets = buildSwimSets(
            from: segmentEvents,
            indexedLaps: indexedLaps,
            isoFormatter: isoFormatter
        )

        let averageSwolf = average(laps.compactMap(\.swolf))
        let strokeStyles = strokeStyles(from: laps, sets: sets)

        let metadata = SwimmingMetadata(
            poolLengthMeters: poolLength,
            totalStrokeCount: totalStrokeCount,
            averageSwolf: averageSwolf,
            lapCount: laps.isEmpty ? nil : laps.count,
            setCount: sets.isEmpty ? nil : sets.count,
            strokeStyles: strokeStyles,
            laps: laps.isEmpty ? nil : laps,
            sets: sets.isEmpty ? nil : sets
        )
        return metadata.hasMeaningfulData ? metadata : nil
    }

    private func buildSwimLaps(
        from events: [HKWorkoutEvent],
        poolLengthMeters: Double?,
        isoFormatter: ISO8601DateFormatter
    ) -> [IndexedSwimLap] {
        events.enumerated().map { offset, event in
            let swolf = swolfScore(from: event.metadata)
            let strokeCount = inferredStrokeCount(
                swolf: swolf,
                durationSeconds: event.dateInterval.duration
            )
            let nextEvent = events.indices.contains(offset + 1) ? events[offset + 1] : nil
            let restAfterSeconds = nextEvent.flatMap {
                positiveDuration(from: event.dateInterval.end, to: $0.dateInterval.start)
            }

            let metadata = SwimLapMetadata(
                index: offset,
                startTime: isoFormatter.string(from: event.dateInterval.start),
                endTime: isoFormatter.string(from: event.dateInterval.end),
                durationSeconds: event.dateInterval.duration,
                distanceMeters: poolLengthMeters,
                strokeStyle: swimmingStrokeStyleName(from: event.metadata),
                strokeCount: strokeCount,
                swolf: swolf,
                restAfterSeconds: restAfterSeconds
            )
            return IndexedSwimLap(event: event, metadata: metadata)
        }
    }

    private func buildSwimSets(
        from events: [HKWorkoutEvent],
        indexedLaps: [IndexedSwimLap],
        isoFormatter: ISO8601DateFormatter
    ) -> [SwimSetMetadata] {
        events.enumerated().map { offset, event in
            let overlappingLaps = indexedLaps.filter {
                intervalsOverlap($0.event.dateInterval, event.dateInterval)
            }
            let lapMetadata = overlappingLaps.map(\.metadata)
            let nextEvent = events.indices.contains(offset + 1) ? events[offset + 1] : nil
            let restAfterSeconds = nextEvent.flatMap {
                positiveDuration(from: event.dateInterval.end, to: $0.dateInterval.start)
            }

            return SwimSetMetadata(
                index: offset,
                startTime: isoFormatter.string(from: event.dateInterval.start),
                endTime: isoFormatter.string(from: event.dateInterval.end),
                durationSeconds: event.dateInterval.duration,
                lapStartIndex: lapMetadata.first?.index,
                lapEndIndex: lapMetadata.last?.index,
                lapCount: lapMetadata.isEmpty ? nil : lapMetadata.count,
                distanceMeters: sumIfComplete(lapMetadata.map(\.distanceMeters)),
                strokeStyle: setStrokeStyle(from: lapMetadata),
                strokeCount: sumIfComplete(lapMetadata.map(\.strokeCount)),
                averageSwolf: swolfScore(from: event.metadata) ?? average(lapMetadata.compactMap(\.swolf)),
                restAfterSeconds: restAfterSeconds
            )
        }
    }

    private func poolLengthMeters(for workout: HKWorkout) -> Double? {
        let activityLapLength = workout.workoutActivities
            .compactMap { activity in
                activity.workoutConfiguration.lapLength?.doubleValue(for: .meter())
            }
            .first

        return activityLapLength ?? lapLengthMeters(from: workout.metadata)
    }

    private func totalSwimStrokeCount(for workout: HKWorkout) -> Int? {
        guard let type = HKQuantityType.quantityType(forIdentifier: .swimmingStrokeCount),
              let quantity = workout.statistics(for: type)?.sumQuantity()
        else {
            return nil
        }
        return Int(round(quantity.doubleValue(for: .count())))
    }

    func swimmingLocationType(for workout: HKWorkout) -> HKWorkoutSwimmingLocationType? {
        let activityLocationType = workout.workoutActivities
            .map { $0.workoutConfiguration.swimmingLocationType }
            .first { $0 != .unknown }

        return activityLocationType ?? swimmingLocationType(from: workout.metadata)
    }

    private func sortedEvents(_ events: [HKWorkoutEvent], ofType type: HKWorkoutEventType) -> [HKWorkoutEvent] {
        events
            .filter { $0.type == type }
            .sorted { $0.dateInterval.start < $1.dateInterval.start }
    }

    private func inferredStrokeCount(swolf: Double?, durationSeconds: Double?) -> Int? {
        guard let swolf, let durationSeconds else {
            return nil
        }
        let strokeCount = swolf - durationSeconds
        guard strokeCount >= 0 else {
            return nil
        }
        return Int(round(strokeCount))
    }

    private func positiveDuration(from start: Date, to end: Date) -> Double? {
        let duration = end.timeIntervalSince(start)
        return duration > 0 ? duration : nil
    }

    private func intervalsOverlap(_ first: DateInterval, _ second: DateInterval) -> Bool {
        first.start < second.end && second.start < first.end
    }

    private func sumIfComplete(_ values: [Double?]) -> Double? {
        guard !values.isEmpty, values.allSatisfy({ $0 != nil }) else {
            return nil
        }
        return values.compactMap { $0 }.reduce(0, +)
    }

    private func sumIfComplete(_ values: [Int?]) -> Int? {
        guard !values.isEmpty, values.allSatisfy({ $0 != nil }) else {
            return nil
        }
        return values.compactMap { $0 }.reduce(0, +)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else {
            return nil
        }
        return values.reduce(0, +) / Double(values.count)
    }

    private func setStrokeStyle(from laps: [SwimLapMetadata]) -> String? {
        let styles = laps.compactMap(\.strokeStyle)
        guard !styles.isEmpty else {
            return nil
        }

        let knownStyles = styles.filter { $0 != "unknown" }
        let stylesToCompare = knownStyles.isEmpty ? styles : knownStyles
        let uniqueStyles = Set(stylesToCompare)

        if uniqueStyles.count == 1 {
            return uniqueStyles.first
        }
        return "mixed"
    }

    private func strokeStyles(from laps: [SwimLapMetadata], sets: [SwimSetMetadata]) -> [String]? {
        let allStyles = laps.compactMap(\.strokeStyle) + sets.compactMap(\.strokeStyle)
        guard !allStyles.isEmpty else {
            return nil
        }

        let knownStyles = allStyles.filter { $0 != "unknown" }
        let stylesToExport = knownStyles.isEmpty ? allStyles : knownStyles
        let uniqueStyles = Array(Set(stylesToExport)).sorted()

        return uniqueStyles.isEmpty ? nil : uniqueStyles
    }
}

import CoreLocation
import Foundation
import HealthKit

enum WorkoutFeatureBuilder {
    static func build(
        locations: [CLLocation],
        heartRates: [HKQuantitySample],
        isoFormatter: ISO8601DateFormatter
    ) -> (feature: LineFeature, heartRateValues: [Double]) {
        guard locations.isEmpty else {
            return routeFeature(
                locations: locations,
                heartRates: heartRates,
                isoFormatter: isoFormatter
            )
        }

        return heartRateFeature(heartRates: heartRates, isoFormatter: isoFormatter)
    }

    private static func routeFeature(
        locations: [CLLocation],
        heartRates: [HKQuantitySample],
        isoFormatter: ISO8601DateFormatter
    ) -> (feature: LineFeature, heartRateValues: [Double]) {
        var coordinates: [Coordinates] = []
        var coordinateTimes: [String] = []
        var heartRateValues: [Int?] = []
        var matchedHeartRateValues: [Double] = []

        for location in locations {
            coordinates.append([
                location.coordinate.longitude,
                location.coordinate.latitude,
                location.altitude
            ])
            coordinateTimes.append(isoFormatter.string(from: location.timestamp))

            let closestHeartRate = heartRates.min { first, second in
                abs(first.startDate.timeIntervalSince(location.timestamp))
                    < abs(second.startDate.timeIntervalSince(location.timestamp))
            }
            guard let closestHeartRate, isWithinMatchingWindow(closestHeartRate, of: location) else {
                heartRateValues.append(nil)
                continue
            }

            let value = closestHeartRate.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            heartRateValues.append(Int(round(value)))
            matchedHeartRateValues.append(value)
        }

        let geometry = LineStringGeometry(coordinates: coordinates)
        let properties = LineProperties(
            coordTimes: coordinateTimes,
            heartRates: heartRateValues,
            cadences: nil,
            powers: nil,
            temperatures: nil
        )
        return (LineFeature(geometry: geometry, properties: properties), matchedHeartRateValues)
    }

    private static func heartRateFeature(
        heartRates: [HKQuantitySample],
        isoFormatter: ISO8601DateFormatter
    ) -> (feature: LineFeature, heartRateValues: [Double]) {
        var coordinateTimes: [String] = []
        var heartRateValues: [Int?] = []
        var values: [Double] = []

        for sample in heartRates {
            coordinateTimes.append(isoFormatter.string(from: sample.startDate))
            let value = sample.quantity.doubleValue(
                for: HKUnit.count().unitDivided(by: .minute())
            )
            heartRateValues.append(Int(round(value)))
            values.append(value)
        }

        let properties = LineProperties(
            coordTimes: coordinateTimes,
            heartRates: heartRateValues,
            cadences: nil,
            powers: nil,
            temperatures: nil
        )
        return (LineFeature(geometry: nil, properties: properties), values)
    }

    private static func isWithinMatchingWindow(
        _ heartRate: HKQuantitySample,
        of location: CLLocation
    ) -> Bool {
        abs(heartRate.startDate.timeIntervalSince(location.timestamp)) < 30
    }
}

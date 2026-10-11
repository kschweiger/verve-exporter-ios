import CoreLocation
import HealthKit
@testable import VerveExporter
import XCTest

final class ExportTests: XCTestCase {
    private static let manager = HealthManager()
    private let start = Date(timeIntervalSince1970: 1_752_000_000)

    func testRouteExportAlignsCoordinatesTimesAndNearbyHeartRates() throws {
        let workout = workout(type: .running)
        let route = [location(0, latitude: 48.1, longitude: 11.5), location(60, latitude: 48.2, longitude: 11.6)]
        let samples = try [heartRate(5, bpm: 140), heartRate(100, bpm: 170)]

        let export = try buildExport(for: workout, locations: route, heartRates: samples)
        let json = try jsonObject(export.data)
        let feature = try XCTUnwrap((json["features"] as? [[String: Any]])?.first)
        let properties = try XCTUnwrap(feature["properties"] as? [String: Any])
        let geometry = try XCTUnwrap(feature["geometry"] as? [String: Any])
        let coordinates = try XCTUnwrap(geometry["coordinates"] as? [[Double]])
        XCTAssertEqual(coordinates, [[11.5, 48.1, 500], [11.6, 48.2, 500]])
        XCTAssertEqual((properties["coordTimes"] as? [String])?.count, 2)
        let exportedRates = try XCTUnwrap(properties["heartRates"] as? [Any])
        XCTAssertEqual(exportedRates.first as? Int, 140)
        XCTAssertTrue(exportedRates.last is NSNull)
        let root = try XCTUnwrap(json["properties"] as? [String: Any])
        XCTAssertEqual(root["durationSeconds"] as? Double, 120)
    }

    func testHeartRateOnlyExportHasNullGeometry() throws {
        let export = try buildExport(
            for: workout(type: .yoga),
            heartRates: [heartRate(10, bpm: 101)]
        )
        let feature = try XCTUnwrap(try (jsonObject(export.data)["features"] as? [[String: Any]])?.first)
        XCTAssertTrue(feature["geometry"] is NSNull)
        XCTAssertEqual((feature["properties"] as? [String: Any])?["heartRates"] as? [Int], [101])
    }

    func testEmptyWorkoutFailsInsteadOfWritingInvalidFeatureCollection() throws {
        XCTAssertThrowsError(try buildExport(for: workout(type: .yoga)))
    }

    func testSwimmingExportContainsSyntheticLapAndSetMetadata() throws {
        let lap = HKWorkoutEvent(type: .lap, dateInterval: DateInterval(start: start, duration: 50), metadata: [
            HKMetadataKeySwimmingStrokeStyle: HKSwimmingStrokeStyle.freestyle.rawValue,
            HKMetadataKeySWOLFScore: 76
        ])
        let segment = HKWorkoutEvent(
            type: .segment,
            dateInterval: DateInterval(start: start, duration: 50),
            metadata: nil
        )
        let swim = workout(type: .swimming, events: [lap, segment], metadata: [
            HKMetadataKeyLapLength: HKQuantity(unit: .meter(), doubleValue: 50),
            HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.pool.rawValue
        ])

        let export = try buildExport(
            for: swim,
            heartRates: [heartRate(5, bpm: 120)]
        )
        let properties = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        XCTAssertEqual(properties["activitySubType"] as? String, "Outdoor Pool")
        let envelope = try XCTUnwrap(properties["metadata"] as? [String: Any])
        XCTAssertEqual(envelope["target"] as? String, "SwimmingMetaData")
        let data = try XCTUnwrap(envelope["data"] as? [String: Any])
        XCTAssertEqual(data["poolLengthMeters"] as? Double, 50)
        let exportedLap = try XCTUnwrap((data["laps"] as? [[String: Any]])?.first)
        XCTAssertEqual(exportedLap["strokeStyle"] as? String, "freestyle")
        XCTAssertEqual(exportedLap["strokeCount"] as? Int, 26)
        XCTAssertEqual((data["sets"] as? [[String: Any]])?.count, 1)
    }

    func testSwimmingWithoutDetailsOmitsMetadataEnvelope() throws {
        let export = try buildExport(
            for: workout(type: .swimming),
            heartRates: [heartRate(5, bpm: 120)]
        )
        let properties = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        XCTAssertNil(properties["metadata"])
    }

    func testWorkoutTimeZoneControlsTimestampsAndFilename() throws {
        let winter = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z"))
        let berlin = workout(type: .running, start: winter, metadata: [HKMetadataKeyTimeZone: "Europe/Berlin"])
        let export = try buildExport(
            for: berlin,
            heartRates: [heartRate(0, bpm: 100, start: winter)]
        )
        let properties = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        XCTAssertEqual(properties["timezone"] as? String, "Europe/Berlin")
        XCTAssertEqual(properties["startTime"] as? String, "2026-01-15T13:00:00+01:00")
        XCTAssertTrue(export.fileName.hasPrefix("2026-01-15_13-00"))

        let summer = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-07-15T12:00:00Z"))
        let summerWorkout = workout(type: .running, start: summer, metadata: [HKMetadataKeyTimeZone: "Europe/Berlin"])
        let summerExport = try buildExport(
            for: summerWorkout,
            heartRates: [heartRate(0, bpm: 100, start: summer)]
        )
        let summerProperties = try XCTUnwrap(try jsonObject(summerExport.data)["properties"] as? [String: Any])
        XCTAssertEqual(summerProperties["timezone"] as? String, "Europe/Berlin")
        XCTAssertEqual(summerProperties["startTime"] as? String, "2026-07-15T14:00:00+02:00")
        XCTAssertTrue(summerExport.fileName.hasPrefix("2026-07-15_14-00"))
    }

    func testRecordedUTCTimeZoneIsExported() throws {
        let export = try buildExport(
            for: workout(type: .running, metadata: [HKMetadataKeyTimeZone: "UTC"]),
            heartRates: [heartRate(0, bpm: 100)],
            fallbackTimeZone: XCTUnwrap(TimeZone(identifier: "Europe/Berlin"))
        )
        let properties = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        XCTAssertEqual(properties["timezone"] as? String, "UTC")
        XCTAssertTrue((properties["startTime"] as? String)?.hasSuffix("Z") == true)
    }

    func testRecordedFixedOffsetOmitsIANATimeZone() throws {
        let export = try buildExport(
            for: workout(type: .running, metadata: [HKMetadataKeyTimeZone: "GMT+0200"]),
            heartRates: [heartRate(0, bpm: 100)]
        )
        let properties = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        XCTAssertNil(properties["timezone"])
        XCTAssertTrue((properties["startTime"] as? String)?.hasSuffix("+02:00") == true)
    }

    func testMissingWorkoutTimeZoneUsesProvidedFallback() throws {
        let export = try buildExport(
            for: workout(type: .running),
            heartRates: [heartRate(0, bpm: 100)],
            fallbackTimeZone: XCTUnwrap(TimeZone(secondsFromGMT: 7200))
        )
        let properties = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        XCTAssertNil(properties["timezone"])
        XCTAssertTrue((properties["startTime"] as? String)?.hasSuffix("+02:00") == true)
        let expectedDate = DateFormatter()
        expectedDate.dateFormat = "yyyy-MM-dd_HH-mm"
        expectedDate.timeZone = TimeZone(secondsFromGMT: 7200)
        XCTAssertTrue(export.fileName.hasPrefix(expectedDate.string(from: start)))
    }

    func testNearestHeartRateRequiresLessThanThirtySecondsAndStatsUseMatchedValues() throws {
        let route = [
            location(30, latitude: 48.1, longitude: 11.5),
            location(90, latitude: 48.2, longitude: 11.6),
            location(150, latitude: 48.3, longitude: 11.7)
        ]
        let samples = try [
            heartRate(179, bpm: 170),
            heartRate(1, bpm: 120),
            heartRate(60, bpm: 180),
            heartRate(35, bpm: 140)
        ]
        let export = try buildExport(for: workout(type: .running, duration: 180), locations: route, heartRates: samples)
        let json = try jsonObject(export.data)
        let feature = try XCTUnwrap((json["features"] as? [[String: Any]])?.first)
        let featureProperties = try XCTUnwrap(feature["properties"] as? [String: Any])
        let rates = try XCTUnwrap(featureProperties["heartRates"] as? [Any])
        XCTAssertEqual(rates.count, 3)
        XCTAssertEqual(rates[0] as? Int, 140)
        XCTAssertTrue(rates[1] is NSNull)
        XCTAssertEqual(rates[2] as? Int, 170)
        XCTAssertEqual((featureProperties["coordTimes"] as? [String])?.count, 3)

        let root = try XCTUnwrap(json["properties"] as? [String: Any])
        let stats = try XCTUnwrap(root["stats"] as? [String: Any])
        let heartRate = try XCTUnwrap(stats["heartRate"] as? [String: Any])
        XCTAssertEqual(heartRate["min"] as? Double, 140)
        XCTAssertEqual(heartRate["avg"] as? Double, 155)
        XCTAssertEqual(heartRate["max"] as? Double, 170)
    }

    func testRouteWithoutHeartRatesOmitsHeartRateStats() throws {
        let export = try buildExport(
            for: workout(type: .running),
            locations: [location(0, latitude: 48.1, longitude: 11.5)]
        )
        let json = try jsonObject(export.data)
        let root = try XCTUnwrap(json["properties"] as? [String: Any])
        let stats = try XCTUnwrap(root["stats"] as? [String: Any])
        XCTAssertNil(stats["heartRate"])
    }

    func testActivityMappingCoversIndoorSwimmingAndFallbackVariants() {
        let indoor = [HKMetadataKeyIndoorWorkout: true]
        XCTAssertEqual(VerveActivityMapper.category(for: workout(type: .walking, metadata: indoor),
                                                    swimmingLocationType: nil).subType, "Treadmill")
        XCTAssertEqual(VerveActivityMapper.category(for: workout(type: .running, metadata: indoor),
                                                    swimmingLocationType: nil).subType, "Treadmill")
        XCTAssertEqual(VerveActivityMapper.category(for: workout(type: .cycling, metadata: indoor),
                                                    swimmingLocationType: nil).subType, "Indoor")
        XCTAssertNil(VerveActivityMapper.category(for: workout(type: .cycling), swimmingLocationType: nil).subType)
        XCTAssertEqual(VerveActivityMapper.category(for: workout(type: .swimming, metadata: indoor),
                                                    swimmingLocationType: .pool).subType, "Indoor")
        XCTAssertEqual(VerveActivityMapper.category(for: workout(type: .swimming),
                                                    swimmingLocationType: .pool).subType, "Outdoor Pool")
        XCTAssertEqual(VerveActivityMapper.category(for: workout(type: .swimming),
                                                    swimmingLocationType: .openWater).subType, "Open Water")
        XCTAssertEqual(VerveActivityMapper.category(for: workout(type: .swimming, metadata: indoor),
                                                    swimmingLocationType: .unknown).subType, "Indoor")
        let fallback = VerveActivityMapper.category(for: workout(type: .dance), swimmingLocationType: nil)
        XCTAssertEqual(fallback.type, "Other")
        XCTAssertEqual(fallback.subType, "Other")
    }
}

extension ExportTests {
    func testOutOfOrderSwimmingEventsProduceSortedLapsMixedSetAndRestIntervals() throws {
        let firstLap = swimEvent(.lap, offset: 0, duration: 20, metadata: [
            HKMetadataKeySwimmingStrokeStyle: HKSwimmingStrokeStyle.freestyle.rawValue,
            HKMetadataKeySWOLFScore: 45
        ])
        let secondLap = swimEvent(.lap, offset: 30, duration: 20, metadata: [
            HKMetadataKeySwimmingStrokeStyle: HKSwimmingStrokeStyle.backstroke.rawValue,
            HKMetadataKeySWOLFScore: 55
        ])
        let firstSet = swimEvent(.segment, offset: 0, duration: 50)
        let secondSet = swimEvent(.segment, offset: 60, duration: 20)
        let finalLap = swimEvent(.lap, offset: 60, duration: 20)
        let swim = workout(type: .swimming, events: [secondSet, finalLap, secondLap, firstSet, firstLap], metadata: [
            HKMetadataKeyLapLength: HKQuantity(unit: .meter(), doubleValue: 50),
            HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.pool.rawValue
        ])

        let export = try buildExport(for: swim, heartRates: [heartRate(0, bpm: 100)])
        let root = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        let envelope = try XCTUnwrap(root["metadata"] as? [String: Any])
        let data = try XCTUnwrap(envelope["data"] as? [String: Any])
        let laps = try XCTUnwrap(data["laps"] as? [[String: Any]])
        let sets = try XCTUnwrap(data["sets"] as? [[String: Any]])

        XCTAssertEqual(laps.map { $0["index"] as? Int }, [0, 1, 2])
        XCTAssertEqual(laps[0]["strokeStyle"] as? String, "freestyle")
        XCTAssertEqual(laps[0]["restAfterSeconds"] as? Double, 10)
        XCTAssertEqual(laps[1]["restAfterSeconds"] as? Double, 10)
        XCTAssertNil(laps[2]["restAfterSeconds"])
        XCTAssertEqual(sets[0]["lapStartIndex"] as? Int, 0)
        XCTAssertEqual(sets[0]["lapEndIndex"] as? Int, 1)
        XCTAssertEqual(sets[0]["lapCount"] as? Int, 2)
        XCTAssertEqual(sets[0]["distanceMeters"] as? Double, 100)
        XCTAssertEqual(sets[0]["strokeStyle"] as? String, "mixed")
        XCTAssertEqual(sets[0]["strokeCount"] as? Int, 60)
        XCTAssertEqual(sets[0]["averageSwolf"] as? Double, 50)
        XCTAssertEqual(sets[0]["restAfterSeconds"] as? Double, 10)
        XCTAssertNil(sets[1]["strokeCount"])
        XCTAssertNil(sets[1]["averageSwolf"])
        XCTAssertEqual(data["strokeStyles"] as? [String], ["backstroke", "freestyle", "mixed"])
    }

    func testSwimmingSetOmitsInferredDistanceAndStrokeCountWhenLapInputsAreMissing() throws {
        let lap = swimEvent(.lap, offset: 0, duration: 20, metadata: [HKMetadataKeySWOLFScore: 15])
        let segment = swimEvent(.segment, offset: 0, duration: 20)
        let swim = workout(type: .swimming, events: [lap, segment])
        let export = try buildExport(for: swim, heartRates: [heartRate(0, bpm: 100)])
        let root = try XCTUnwrap(try jsonObject(export.data)["properties"] as? [String: Any])
        let envelope = try XCTUnwrap(root["metadata"] as? [String: Any])
        let data = try XCTUnwrap(envelope["data"] as? [String: Any])
        let laps = try XCTUnwrap(data["laps"] as? [[String: Any]])
        let sets = try XCTUnwrap(data["sets"] as? [[String: Any]])

        XCTAssertNil(laps[0]["distanceMeters"])
        XCTAssertNil(laps[0]["strokeCount"])
        XCTAssertNil(sets[0]["distanceMeters"])
        XCTAssertNil(sets[0]["strokeCount"])
        XCTAssertEqual(sets[0]["averageSwolf"] as? Double, 15)
    }
}

extension ExportTests {
    private func buildExport(
        for workout: HKWorkout,
        locations: [CLLocation] = [],
        heartRates: [HKQuantitySample] = [],
        fallbackTimeZone: TimeZone? = nil
    ) throws -> GeoJSONExport {
        let timeZone = try XCTUnwrap(fallbackTimeZone ?? TimeZone(secondsFromGMT: 0))
        return try Self.manager.buildGeoJSON(
            for: workout,
            locations: locations,
            heartRates: heartRates,
            fallbackTimeZone: timeZone
        )
    }

    private func workout(
        type: HKWorkoutActivityType,
        start workoutStart: Date? = nil,
        duration: TimeInterval = 120,
        events: [HKWorkoutEvent]? = nil,
        metadata: [String: Any]? = nil
    ) -> HKWorkout {
        let workoutStart = workoutStart ?? start
        return HKWorkout(
            activityType: type,
            start: workoutStart,
            end: workoutStart.addingTimeInterval(duration),
            workoutEvents: events,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: metadata
        )
    }

    private func location(_ offset: TimeInterval, latitude: Double, longitude: Double) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            altitude: 500,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: start.addingTimeInterval(offset)
        )
    }

    private func swimEvent(
        _ type: HKWorkoutEventType,
        offset: TimeInterval,
        duration: TimeInterval,
        metadata: [String: Any]? = nil
    ) -> HKWorkoutEvent {
        HKWorkoutEvent(
            type: type,
            dateInterval: DateInterval(start: start.addingTimeInterval(offset), duration: duration),
            metadata: metadata
        )
    }

    private func heartRate(
        _ offset: TimeInterval,
        bpm: Double,
        start sampleStart: Date? = nil
    ) throws -> HKQuantitySample {
        let type = try XCTUnwrap(HKQuantityType.quantityType(forIdentifier: .heartRate))
        let timestamp = (sampleStart ?? start).addingTimeInterval(offset)
        return HKQuantitySample(
            type: type,
            quantity: HKQuantity(
                unit: HKUnit.count().unitDivided(by: .minute()),
                doubleValue: bpm
            ),
            start: timestamp,
            end: timestamp
        )
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

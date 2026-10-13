import Foundation
import HealthKit
@testable import VerveExporter
import XCTest

@available(iOS, deprecated: 17.0, message: "Uses unsaved HKWorkout fixtures for isolated export tests")
extension ExportTests {
    func testFractionalSwimmingDistancesAndElapsedSetDurationArePreserved() throws {
        let laps = [
            swimEvent(.lap, offset: 0.125, duration: 50.34, metadata: [HKMetadataKeySWOLFScore: 76.34]),
            swimEvent(.lap, offset: 60.465, duration: 55.16, metadata: [HKMetadataKeySWOLFScore: 77.16])
        ]
        let segment = swimEvent(.segment, offset: 0.125, duration: 115.5)
        let data = try swimMetadata(events: laps + [segment], poolLength: 22.86)
        let exportedLaps = try XCTUnwrap(data["laps"] as? [[String: Any]])
        let set = try XCTUnwrap((data["sets"] as? [[String: Any]])?.first)
        XCTAssertEqual(data["poolLengthMeters"] as? Double, 22.86)
        XCTAssertEqual(exportedLaps[0]["distanceMeters"] as? Double, 22.86)
        XCTAssertEqual(exportedLaps[0]["strokeCount"] as? Int, 26)
        XCTAssertEqual(exportedLaps[1]["strokeCount"] as? Int, 22)
        XCTAssertEqual(try XCTUnwrap(exportedLaps[0]["restAfterSeconds"] as? Double), 10, accuracy: 0.000001)
        XCTAssertEqual(set["distanceMeters"] as? Double, 45.72)
        XCTAssertEqual(set["strokeCount"] as? Int, 48)
        XCTAssertEqual(set["averageSwolf"] as? Double, 76.75)
        XCTAssertEqual(set["durationSeconds"] as? Double, 115.5)
        XCTAssertEqual(data["lapCount"] as? Int, 2)
        XCTAssertEqual(data["setCount"] as? Int, 1)
        for interval in exportedLaps + [set] {
            let formatter = ISO8601DateFormatter()
            let begin = try XCTUnwrap(formatter.date(from: XCTUnwrap(interval["startTime"] as? String)))
            let end = try XCTUnwrap(formatter.date(from: XCTUnwrap(interval["endTime"] as? String)))
            let duration = try XCTUnwrap(interval["durationSeconds"] as? Double)
            XCTAssertEqual(end.timeIntervalSince(begin), duration, accuracy: 1)
            XCTAssertTrue((interval["startTime"] as? String)?.hasSuffix("Z") == true)
            XCTAssertTrue((interval["endTime"] as? String)?.hasSuffix("Z") == true)
        }
    }

    func testKnownZeroRestGapIsExportedForLapsAndSets() throws {
        let events = [
            swimEvent(.lap, offset: 0, duration: 20),
            swimEvent(.lap, offset: 20, duration: 20),
            swimEvent(.segment, offset: 0, duration: 20),
            swimEvent(.segment, offset: 20, duration: 20)
        ]
        let data = try swimMetadata(events: events)
        for key in ["laps", "sets"] {
            let intervals = try XCTUnwrap(data[key] as? [[String: Any]])
            XCTAssertEqual(intervals[0]["restAfterSeconds"] as? Double, 0)
            XCTAssertNil(intervals[1]["restAfterSeconds"])
        }
    }

    func testOverlappingIntervalsDoNotInventPositiveRest() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 30),
            swimEvent(.lap, offset: 20, duration: 30),
            swimEvent(.segment, offset: 0, duration: 30),
            swimEvent(.segment, offset: 20, duration: 30)
        ])
        for key in ["laps", "sets"] {
            let intervals = try XCTUnwrap(data[key] as? [[String: Any]])
            XCTAssertNil(intervals[0]["restAfterSeconds"])
            XCTAssertNil(intervals[1]["restAfterSeconds"])
        }
    }

    func testUnexplainedFractionalSwolfDoesNotManufactureStrokeCount() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 50, metadata: [HKMetadataKeySWOLFScore: 76.2])
        ])
        let lap = try XCTUnwrap((data["laps"] as? [[String: Any]])?.first)
        XCTAssertEqual(lap["swolf"] as? Double, 76.2)
        XCTAssertNil(lap["strokeCount"])
    }

    func testSwolfWithoutKnownPoolLengthDoesNotInferStrokes() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 50, metadata: [HKMetadataKeySWOLFScore: 76])
        ], poolLength: nil)
        let lap = try XCTUnwrap((data["laps"] as? [[String: Any]])?.first)
        XCTAssertEqual(lap["swolf"] as? Double, 76)
        XCTAssertNil(lap["strokeCount"])
        XCTAssertNil(lap["distanceMeters"])
    }

    func testZeroInferredStrokeCountIsPreserved() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 50, metadata: [HKMetadataKeySWOLFScore: 50])
        ])
        let lap = try XCTUnwrap((data["laps"] as? [[String: Any]])?.first)
        XCTAssertEqual(lap["strokeCount"] as? Int, 0)
    }

    func testZUnrepresentableSwolfStrokeCountIsOmittedInsteadOfCrashing() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 50, metadata: [HKMetadataKeySWOLFScore: Double(Int.max) * 2])
        ])
        let lap = try XCTUnwrap((data["laps"] as? [[String: Any]])?.first)
        XCTAssertNil(lap["strokeCount"])
        XCTAssertNotNil(lap["swolf"])
    }

    func testSetStrokeCountOverflowOmitsAggregateInsteadOfCrashing() throws {
        let score = Double(Int.max) / 2
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 50, metadata: [HKMetadataKeySWOLFScore: score]),
            swimEvent(.lap, offset: 60, duration: 50, metadata: [HKMetadataKeySWOLFScore: score]),
            swimEvent(.segment, offset: 0, duration: 110)
        ])
        let laps = try XCTUnwrap(data["laps"] as? [[String: Any]])
        XCTAssertNotNil(laps[0]["strokeCount"])
        XCTAssertNotNil(laps[1]["strokeCount"])
        let set = try XCTUnwrap((data["sets"] as? [[String: Any]])?.first)
        XCTAssertNil(set["strokeCount"])
        XCTAssertEqual(set["lapCount"] as? Int, 2)
    }

    func testSetAverageUsesAvailableLapScoresInsteadOfSegmentScore() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 20, metadata: [HKMetadataKeySWOLFScore: 40]),
            swimEvent(.lap, offset: 25, duration: 20),
            swimEvent(.lap, offset: 50, duration: 20, metadata: [HKMetadataKeySWOLFScore: 60]),
            swimEvent(.segment, offset: 0, duration: 70, metadata: [HKMetadataKeySWOLFScore: 999])
        ])
        let set = try XCTUnwrap((data["sets"] as? [[String: Any]])?.first)
        XCTAssertEqual(set["averageSwolf"] as? Double, 50)
        XCTAssertEqual(set["lapStartIndex"] as? Int, 0)
        XCTAssertEqual(set["lapEndIndex"] as? Int, 2)
        XCTAssertEqual(set["lapCount"] as? Int, 3)
        XCTAssertNil(set["strokeCount"])
    }

    func testSetWithoutLapDetailsOmitsReferencesAndUnqualifiedSwolf() throws {
        let data = try swimMetadata(events: [
            swimEvent(.segment, offset: 0, duration: 70, metadata: [HKMetadataKeySWOLFScore: 999])
        ])
        let set = try XCTUnwrap((data["sets"] as? [[String: Any]])?.first)
        XCTAssertNil(data["laps"])
        XCTAssertNil(data["lapCount"])
        XCTAssertNil(set["lapStartIndex"])
        XCTAssertNil(set["lapEndIndex"])
        XCTAssertNil(set["lapCount"])
        XCTAssertNil(set["averageSwolf"])
        XCTAssertEqual(set["durationSeconds"] as? Double, 70)
    }

    func testNoncontiguousOverlapSelectionOmitsInvalidLapRange() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 100),
            swimEvent(.lap, offset: 10, duration: 10),
            swimEvent(.lap, offset: 30, duration: 10),
            swimEvent(.segment, offset: 30, duration: 10)
        ])
        let set = try XCTUnwrap((data["sets"] as? [[String: Any]])?.first)
        XCTAssertEqual(set["lapCount"] as? Int, 2)
        XCTAssertNil(set["lapStartIndex"])
        XCTAssertNil(set["lapEndIndex"])
    }

    func testBoundaryTouchingLapIsExcludedFromNextSet() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 20),
            swimEvent(.lap, offset: 20, duration: 20),
            swimEvent(.segment, offset: 20, duration: 20)
        ])
        let set = try XCTUnwrap((data["sets"] as? [[String: Any]])?.first)
        XCTAssertEqual(set["lapStartIndex"] as? Int, 1)
        XCTAssertEqual(set["lapEndIndex"] as? Int, 1)
        XCTAssertEqual(set["lapCount"] as? Int, 1)
    }

    func testEqualStartEventsHaveDeterministicEndTimeOrdering() throws {
        let data = try swimMetadata(events: [
            swimEvent(.lap, offset: 0, duration: 30),
            swimEvent(.lap, offset: 0, duration: 20)
        ])
        let laps = try XCTUnwrap(data["laps"] as? [[String: Any]])
        XCTAssertEqual(laps.map { $0["index"] as? Int }, [0, 1])
        XCTAssertEqual(laps.map { $0["durationSeconds"] as? Double }, [20, 30])
    }

    private func swimMetadata(events: [HKWorkoutEvent], poolLength: Double? = 50) throws -> [String: Any] {
        var metadata: [String: Any] = [:]
        if let poolLength {
            metadata[HKMetadataKeyLapLength] = HKQuantity(unit: .meter(), doubleValue: poolLength)
            metadata[HKMetadataKeySwimmingLocationType] = HKWorkoutSwimmingLocationType.pool.rawValue
        }
        let export = try buildExport(for: workout(type: .swimming, events: events, metadata: metadata),
                                     heartRates: [heartRate(0, bpm: 120)])
        let root = try XCTUnwrap(jsonObject(export.data)["properties"] as? [String: Any])
        let envelope = try XCTUnwrap(root["metadata"] as? [String: Any])
        return try XCTUnwrap(envelope["data"] as? [String: Any])
    }
}

@available(iOS, deprecated: 17.0, message: "Uses unsaved HKWorkout fixtures for isolated export tests")
extension ExportTests {
    func testReportedZeroSwimmingScalarsRemainMeaningfulWithoutDetails() throws {
        let metadata = SwimmingMetadata(poolLengthMeters: nil, totalStrokeCount: 0, averageSwolf: 0,
                                        lapCount: 0, setCount: 0, strokeStyles: nil, laps: nil, sets: nil)
        XCTAssertTrue(metadata.hasMeaningfulData)
        let envelope = VerveMetadata(target: "SwimmingMetaData", version: "1.0", data: metadata)
        let data = try XCTUnwrap(jsonObject(JSONEncoder().encode(envelope))["data"] as? [String: Any])
        for key in ["totalStrokeCount", "averageSwolf", "lapCount", "setCount"] {
            XCTAssertEqual(data[key] as? Double, 0)
        }
        XCTAssertNil(data["laps"])
        XCTAssertNil(data["sets"])
    }

    func testSwimmingDetailsCanBeEncodedWithoutSummaryCounts() throws {
        let lap = SwimLapMetadata(index: 0, startTime: nil, endTime: nil, durationSeconds: nil,
                                  distanceMeters: 22.86, strokeStyle: nil, strokeCount: nil,
                                  swolf: nil, restAfterSeconds: nil)
        let metadata = SwimmingMetadata(poolLengthMeters: nil, totalStrokeCount: nil, averageSwolf: nil,
                                        lapCount: nil, setCount: nil, strokeStyles: nil, laps: [lap], sets: nil)
        XCTAssertTrue(metadata.hasMeaningfulData)
        let data = try jsonObject(JSONEncoder().encode(metadata))
        XCTAssertNil(data["lapCount"])
        XCTAssertEqual((data["laps"] as? [[String: Any]])?.count, 1)
    }

    func testUnavailableOnlySwimmingFieldsAreNotMeaningful() {
        let metadata = SwimmingMetadata(poolLengthMeters: nil, totalStrokeCount: nil, averageSwolf: nil,
                                        lapCount: nil, setCount: nil, strokeStyles: [], laps: [], sets: [])
        XCTAssertFalse(metadata.hasMeaningfulData)
    }
}

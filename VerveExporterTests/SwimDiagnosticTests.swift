import Foundation
import HealthKit
@testable import VerveExporter
import XCTest

final class SwimDiagnosticTests: XCTestCase {
    private let manager = HealthManager()
    private let start = Date(timeIntervalSince1970: 1_752_000_000)

    func testDiagnosticGroupsSyntheticEventsAndDescribesMetadata() throws {
        let lap = event(.lap, offset: 0, duration: 40, metadata: [
            HKMetadataKeySwimmingStrokeStyle: HKSwimmingStrokeStyle.freestyle.rawValue,
            HKMetadataKeySWOLFScore: 64,
            HKMetadataKeyLapLength: HKQuantity(unit: .meter(), doubleValue: 25)
        ])
        let segment = event(.segment, offset: 0, duration: 40)
        let pause = event(.pause, offset: 40, duration: 0)
        let swim = workout(events: [pause, lap, segment], metadata: [
            HKMetadataKeyLapLength: HKQuantity(unit: .meter(), doubleValue: 25),
            HKMetadataKeySwimmingLocationType: HKWorkoutSwimmingLocationType.pool.rawValue,
            HKMetadataKeySWOLFScore: 64,
            "SyntheticDate": start,
            "SyntheticLabel": "fixture"
        ])

        let json = try jsonObject(manager.generateSwimDiagnosticJSON(for: swim))
        let workout = try XCTUnwrap(json["workout"] as? [String: Any])
        let metadata = try XCTUnwrap(workout["metadata"] as? [String: String])
        let counts = try XCTUnwrap(json["eventCounts"] as? [String: Int])
        let laps = try XCTUnwrap(json["laps"] as? [[String: Any]])
        let segments = try XCTUnwrap(json["segments"] as? [[String: Any]])
        let otherEvents = try XCTUnwrap(json["otherEvents"] as? [[String: Any]])

        XCTAssertEqual(workout["lapLengthMeters"] as? Double, 25)
        XCTAssertEqual(workout["swimmingLocationType"] as? String, "pool")
        XCTAssertEqual(workout["swolfScore"] as? Double, 64)
        XCTAssertEqual(metadata["SyntheticLabel"], "fixture")
        XCTAssertEqual(metadata["SyntheticDate"], "2025-07-08T18:40:00Z")
        XCTAssertEqual(counts, ["lap": 1, "segment": 1, "pause": 1])
        XCTAssertEqual(laps[0]["strokeStyle"] as? String, "freestyle")
        XCTAssertEqual(laps[0]["lapLengthMeters"] as? Double, 25)
        XCTAssertEqual(segments[0]["type"] as? String, "segment")
        XCTAssertEqual(otherEvents[0]["type"] as? String, "pause")
        XCTAssertNotNil(json["activities"] as? [[String: Any]])
        XCTAssertNotNil(json["totals"] as? [[String: Any]])
        let generatedAt = try XCTUnwrap(json["generatedAt"] as? String)
        XCTAssertNotNil(ISO8601DateFormatter().date(from: generatedAt))
    }

    func testDiagnosticWithNoEventsOrMetadataEmitsEmptyCollections() throws {
        let json = try jsonObject(manager.generateSwimDiagnosticJSON(for: workout()))
        let workout = try XCTUnwrap(json["workout"] as? [String: Any])

        XCTAssertEqual((json["laps"] as? [Any])?.count, 0)
        XCTAssertEqual((json["segments"] as? [Any])?.count, 0)
        XCTAssertEqual((json["otherEvents"] as? [Any])?.count, 0)
        XCTAssertEqual((json["eventCounts"] as? [String: Int])?.count, 0)
        XCTAssertEqual((workout["metadata"] as? [String: String])?.count, 0)
        XCTAssertNil(workout["lapLengthMeters"])
        XCTAssertNil(workout["swimmingLocationType"])
    }

    private func workout(
        events: [HKWorkoutEvent]? = nil,
        metadata: [String: Any]? = nil
    ) -> HKWorkout {
        HKWorkout(
            activityType: .swimming,
            start: start,
            end: start.addingTimeInterval(120),
            workoutEvents: events,
            totalEnergyBurned: nil,
            totalDistance: nil,
            metadata: metadata
        )
    }

    private func event(
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

    private func jsonObject(_ json: String) throws -> [String: Any] {
        let data = try XCTUnwrap(json.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}

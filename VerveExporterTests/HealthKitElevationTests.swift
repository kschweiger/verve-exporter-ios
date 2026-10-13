import CoreLocation
import HealthKit
@testable import VerveExporter
import XCTest

@available(iOS, deprecated: 17.0, message: "Uses unsaved HKWorkout fixtures for isolated export tests")
extension ExportTests {
    func testPlainHealthKitStyleLocationsRetainAltitudeVariation() throws {
        let route = [275.0, 285.0].enumerated().map { index, altitude in
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 45, longitude: 9),
                altitude: altitude,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: start.addingTimeInterval(Double(index) * 60)
            )
        }
        let export = try buildExport(for: workout(type: .walking), locations: route, geoidUndulation: nil)
        let feature = try XCTUnwrap((jsonObject(export.data)["features"] as? [[String: Any]])?.first)
        let geometry = try XCTUnwrap(feature["geometry"] as? [String: Any])
        let coordinates = try XCTUnwrap(geometry["coordinates"] as? [[Double]])
        XCTAssertEqual(coordinates[1][2] - coordinates[0][2], 10, accuracy: 0.000001)
        XCTAssertNotEqual(coordinates[0][2], 0)
    }

    func testStoredMeanSeaLevelHeightsUsePositionSpecificGeoidCorrection() throws {
        let route = [location(0, latitude: 45, longitude: 9, altitude: 275),
                     location(60, latitude: 45, longitude: 10, altitude: 285)]
        let export = try buildExport(for: workout(type: .walking), locations: route,
                                     geoidUndulation: { _, longitude in longitude == 9 ? 42 : 43 })
        XCTAssertEqual(try exportedCoordinates(export), [[9, 45, 317], [10, 45, 328]])
    }

    func testNegativeGeoidCorrectionUsesTheSameAdditionConvention() throws {
        let route = [location(0, latitude: -20, longitude: -70, altitude: 275),
                     location(60, latitude: -20, longitude: -70, altitude: 285)]
        let export = try buildExport(for: workout(type: .walking), locations: route,
                                     geoidUndulation: { _, _ in -42 })
        XCTAssertEqual(try exportedCoordinates(export), [[-70, -20, 233], [-70, -20, 243]])
    }

    func testHeartRateOnlyExportDoesNotConsultUnavailableGeoid() throws {
        let export = try buildExport(for: workout(type: .yoga), heartRates: [heartRate(0, bpm: 120)],
                                     geoidUndulation: { _, _ in throw GeoidGridError.invalidData })
        let feature = try XCTUnwrap((jsonObject(export.data)["features"] as? [[String: Any]])?.first)
        XCTAssertTrue(feature["geometry"] is NSNull)
    }

    func testUnavailableGeoidReportsSpecificExportFailure() throws {
        let route = [location(0, latitude: 45, longitude: 9), location(60, latitude: 45, longitude: 9)]
        XCTAssertThrowsError(try buildExport(for: workout(type: .walking), locations: route,
                                             geoidUndulation: { _, _ in throw GeoidGridError.invalidData })) {
            guard case GeoJSONExportError.geoidModelUnavailable = $0 else {
                return XCTFail("Expected an unavailable elevation-model error")
            }
            XCTAssertTrue($0.localizedDescription.contains("elevation model"))
        }
    }

    func testShortRouteFailsBeforeConsultingGeoid() throws {
        let route = [location(0, latitude: 45, longitude: 9)]
        XCTAssertThrowsError(try buildExport(for: workout(type: .walking), locations: route,
                                             geoidUndulation: { _, _ in
                                                 XCTFail("Short routes must be rejected before lookup")
                                                 return 40
                                             })) {
            guard case GeoJSONExportError.routeTooShort = $0 else {
                return XCTFail("Expected a short-route error")
            }
        }
    }

    func testNonfiniteGeoidOrConvertedHeightIsRejected() throws {
        let cases: [(Double, Double)] = [(500, .nan), (500, .infinity),
                                         (.greatestFiniteMagnitude, .greatestFiniteMagnitude)]
        for (altitude, undulation) in cases {
            let route = [location(0, latitude: 45, longitude: 9, altitude: altitude),
                         location(60, latitude: 45, longitude: 9)]
            XCTAssertThrowsError(try buildExport(for: workout(type: .walking), locations: route,
                                                 geoidUndulation: { _, _ in undulation })) {
                guard case GeoJSONExportError.invalidElevation(pointIndex: 0) = $0 else {
                    return XCTFail("Expected invalid converted elevation at the first position")
                }
            }
        }
    }

    func testInvalidRouteCoordinatesCannotBeConverted() throws {
        let coordinates: [(Double, Double)] = [(.nan, 9), (45, .infinity), (91, 9), (45, 181)]
        for (latitude, longitude) in coordinates {
            let route = [location(0, latitude: latitude, longitude: longitude),
                         location(60, latitude: 45, longitude: 9)]
            XCTAssertThrowsError(try buildExport(for: workout(type: .walking), locations: route))
        }
    }

    func testInvalidHorizontalAccuracyIsRejectedBeforeGeoidLookup() throws {
        for accuracy in [-1.0, .nan, .infinity] {
            let invalid = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 45, longitude: 9),
                                     altitude: 275, horizontalAccuracy: accuracy, verticalAccuracy: 5,
                                     timestamp: start)
            let route = [invalid, location(60, latitude: 45, longitude: 9)]
            XCTAssertThrowsError(try buildExport(for: workout(type: .walking), locations: route,
                                                 geoidUndulation: { _, _ in
                                                     XCTFail("Invalid horizontal positions must not be looked up")
                                                     return 40
                                                 })) {
                guard case GeoJSONExportError.invalidElevation(pointIndex: 0) = $0 else {
                    return XCTFail("Expected an invalid source-position error")
                }
            }
        }
    }

    func testVerifiedEllipsoidalHeightsAreNotConvertedAgain() throws {
        let route = [location(0, latitude: 45, longitude: 9, altitude: 275),
                     location(60, latitude: 45, longitude: 10, altitude: 285)]
        let result = try WorkoutFeatureBuilder.build(locations: route, ellipsoidalElevations: [317, 328],
                                                     heartRates: [], isoFormatter: ISO8601DateFormatter())
        XCTAssertEqual(result.feature.geometry?.coordinates, [[9, 45, 317], [10, 45, 328]])
    }

    func testFeatureBuilderRejectsMissingOrNonfiniteVerifiedHeights() throws {
        let route = [location(0, latitude: 45, longitude: 9), location(60, latitude: 45, longitude: 10)]
        for heights in [[], [317], [317, 328, 339], [317, .nan]] {
            XCTAssertThrowsError(try WorkoutFeatureBuilder.build(locations: route, ellipsoidalElevations: heights,
                                                                 heartRates: [], isoFormatter: ISO8601DateFormatter()))
        }
    }

    private func exportedCoordinates(_ export: GeoJSONExport) throws -> [[Double]] {
        let feature = try XCTUnwrap((jsonObject(export.data)["features"] as? [[String: Any]])?.first)
        let geometry = try XCTUnwrap(feature["geometry"] as? [String: Any])
        return try XCTUnwrap(geometry["coordinates"] as? [[Double]])
    }
}

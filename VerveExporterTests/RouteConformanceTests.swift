import CoreLocation
import HealthKit
@testable import VerveExporter
import XCTest

extension ExportTests {
    func testOnePositionRouteFailsEvenWithHeartRateSamples() throws {
        let route = [location(0, latitude: 48.1, longitude: 11.5)]
        for samples in try [[], [heartRate(0, bpm: 120)]] {
            XCTAssertThrowsError(try buildExport(for: workout(type: .running), locations: route, heartRates: samples)) {
                XCTAssertTrue($0.localizedDescription.contains("two"))
            }
        }
    }

    func testConvertedZeroAndNegativeEllipsoidalHeightsArePreserved() throws {
        let route = [
            location(0, latitude: 48.1, longitude: 11.5, altitude: -65),
            location(60, latitude: 48.2, longitude: 11.6, altitude: -40)
        ]
        let export = try buildExport(for: workout(type: .running), locations: route)
        let feature = try XCTUnwrap((jsonObject(export.data)["features"] as? [[String: Any]])?.first)
        let geometry = try XCTUnwrap(feature["geometry"] as? [String: Any])
        XCTAssertEqual(geometry["coordinates"] as? [[Double]], [[11.5, 48.1, -25], [11.6, 48.2, 0]])
    }

    func testInvalidElevationReportsClearErrorEvenWithHeartRateSamples() throws {
        let invalidInputs: [(Double, Double)] = [
            (540, -1), (540, 0), (540, .nan), (540, .infinity), (.nan, 5), (.infinity, 5), (-.infinity, 5)
        ]
        for (height, accuracy) in invalidInputs {
            let route = [
                location(0, latitude: 48.1, longitude: 11.5),
                location(60, latitude: 48.2, longitude: 11.6,
                         altitude: height, verticalAccuracy: accuracy)
            ]
            XCTAssertThrowsError(try buildExport(for: workout(type: .running), locations: route,
                                                 heartRates: [heartRate(0, bpm: 120)])) {
                XCTAssertTrue($0.localizedDescription.lowercased().contains("elevation"))
            }
        }
    }

    func testExportKeepsActiveEnergyInKilocalories() throws {
        let export = try buildExport(for: workout(type: .running, energyKcal: 250),
                                     heartRates: [heartRate(0, bpm: 120)])
        let properties = try XCTUnwrap(jsonObject(export.data)["properties"] as? [String: Any])
        XCTAssertEqual(properties["totalEnergyKcal"] as? Double, 250)
    }

    func testEveryFeatureHasExplicitGeometryAndAlignedRequiredTimes() throws {
        let route = [location(0, latitude: 48.1, longitude: 11.5), location(60, latitude: 48.2, longitude: 11.6)]
        let exports = try [
            buildExport(for: workout(type: .running), locations: route),
            buildExport(for: workout(type: .yoga), heartRates: [heartRate(0, bpm: 120)])
        ]
        for export in exports {
            let features = try XCTUnwrap(jsonObject(export.data)["features"] as? [[String: Any]])
            for feature in features {
                XCTAssertNotNil(feature["geometry"])
                let properties = try XCTUnwrap(feature["properties"] as? [String: Any])
                let times = try XCTUnwrap(properties["coordTimes"] as? [String])
                let rates = try XCTUnwrap(properties["heartRates"] as? [Any])
                XCTAssertEqual(times.count, rates.count)
                if let geometry = feature["geometry"] as? [String: Any] {
                    XCTAssertEqual((geometry["coordinates"] as? [[Double]])?.count, times.count)
                } else {
                    XCTAssertTrue(feature["geometry"] is NSNull)
                }
            }
        }
    }
}

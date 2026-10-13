import Foundation
@testable import VerveExporter
import XCTest

final class GeoidGridTests: XCTestCase {
    func testMiniatureGridNodesScaleAndBilinearInterior() throws {
        let grid = try GeoidGrid(data: miniatureData())
        XCTAssertEqual(try grid.undulationMeters(latitude: 0, longitude: 90), -107.4, accuracy: 0.000001)
        XCTAssertEqual(try grid.undulationMeters(latitude: 45, longitude: 45), -106.275, accuracy: 0.000001)
        XCTAssertEqual(try grid.undulationMeters(latitude: -45, longitude: 45), -104.775, accuracy: 0.000001)
    }

    func testLongitudeWrappingAndBothPoles() throws {
        let grid = try GeoidGrid(data: miniatureData())
        for longitude in [-45.0, 315, 675] {
            XCTAssertEqual(try grid.undulationMeters(latitude: 0, longitude: longitude), -107.25, accuracy: 0.000001)
        }
        for longitude in [-180.0, 180, 0, 360] {
            XCTAssertEqual(try grid.undulationMeters(latitude: 0, longitude: longitude == 0 ? 360 : longitude),
                           longitude == 0 || longitude == 360 ? -107.7 : -107.1, accuracy: 0.000001)
            XCTAssertEqual(try grid.undulationMeters(latitude: 90, longitude: longitude), -105, accuracy: 0.000001)
            XCTAssertEqual(try grid.undulationMeters(latitude: -90, longitude: longitude), -102, accuracy: 0.000001)
        }
    }

    func testFirstBinaryWhitespaceByteIsNotDiscarded() throws {
        let grid = try GeoidGrid(data: miniatureData(samples: Array(repeating: 0x0A0D, count: 12)))
        XCTAssertEqual(try grid.undulationMeters(latitude: 0, longitude: 0), -100.281, accuracy: 0.000001)
    }

    func testInvalidCoordinatesAreRejected() throws {
        let grid = try GeoidGrid(data: miniatureData())
        for (latitude, longitude) in [(91.0, 0.0), (-91, 0), (.nan, 0), (0, .infinity), (0, .nan)] {
            XCTAssertThrowsError(try grid.undulationMeters(latitude: latitude, longitude: longitude))
        }
    }

    func testMalformedAndTruncatedGridsAreRejected() {
        let valid = miniatureData()
        let badHeaders = [
            "P2\n# Offset -108\n# Scale 0.003\n4 3\n65535\n",
            "P5\n# Offset -108\n4 3\n65535\n",
            "P5\n# Offset nan\n# Scale 0.003\n4 3\n65535\n",
            "P5\n# Offset -108\n# Scale -1\n4 3\n65535\n",
            "P5\n# Offset -108\n# Scale 0.003\n-4 3\n65535\n",
            "P5\n# Offset -108\n# Scale 0.003\n9223372036854775806 4611686018427387904\n65535\n",
            "P5\n# Offset -108\n# Scale 0.003\n4 3\n255\n"
        ]
        for header in badHeaders {
            XCTAssertThrowsError(try GeoidGrid(data: miniatureData(header: header)))
        }
        XCTAssertThrowsError(try GeoidGrid(data: Data()))
        XCTAssertThrowsError(try GeoidGrid(data: Data(valid.dropLast())))
        XCTAssertThrowsError(try GeoidGrid(data: valid + Data([0])))
    }

    func testBundledGridHasExpectedDimensionsAndPinnedChecksum() throws {
        let grid = try BundledGeoidGrid.load()
        XCTAssertEqual(grid.columns, 4320)
        XCTAssertEqual(grid.rows, 2161)
    }

    func testDamagedBundledGridFailsChecksumValidation() throws {
        let url = try BundledGeoidGrid.resourceURL(in: .main)
        var data = try Data(contentsOf: url)
        data[data.endIndex - 1] ^= 1
        XCTAssertThrowsError(try BundledGeoidGrid.validatedGrid(data: data))
    }

    func testMissingResourceInTestBundleFailsClearly() {
        XCTAssertThrowsError(try BundledGeoidGrid.load(bundle: Bundle(for: Self.self)))
    }

    func testBundledGridAgainstIndependentNGASynthesisVectors() throws {
        // First twelve vectors from GeographicLib's public GeoidHeights.dat.gz.
        // Values are NGA harmonic-synthesis EGM2008 heights, not this grid's output.
        let vectors: [GeoidReference] = [
            .init(latitude: -76.981466, longitude: 34.17016, expected: 12.63629),
            .init(latitude: 79.695484, longitude: 88.805571, expected: 0.749472),
            .init(latitude: -15.244804, longitude: 168.747961, expected: 65.108852),
            .init(latitude: -19.379357, longitude: 15.85511, expected: 24.888926),
            .init(latitude: 43.377784, longitude: 229.448418, expected: -29.55705),
            .init(latitude: -16.074554, longitude: 21.79547, expected: 9.741516),
            .init(latitude: -11.256389, longitude: 286.249745, expected: 30.058864),
            .init(latitude: 69.016564, longitude: 344.078885, expected: 60.69041),
            .init(latitude: 2.221008, longitude: 139.73935, expected: 69.133157),
            .init(latitude: -9.096878, longitude: 119.141551, expected: 36.520307),
            .init(latitude: -28.523717, longitude: 337.8075, expected: 6.80124),
            .init(latitude: 12.27231, longitude: 223.575832, expected: -20.651171)
        ]
        let grid = try BundledGeoidGrid.load()
        for reference in vectors {
            let height = try grid.undulationMeters(latitude: reference.latitude, longitude: reference.longitude)
            XCTAssertEqual(height, reference.expected, accuracy: 0.5)
        }
    }

    private struct GeoidReference {
        let latitude: Double
        let longitude: Double
        let expected: Double
    }

    private func miniatureData(header: String? = nil, samples: [UInt16]? = nil) -> Data {
        let header = header ?? "P5\n# Offset -108\n# Scale 0.003\n4 3\n65535\n"
        let samples = samples ?? [1000, 1000, 1000, 1000, 100, 200, 300, 400, 2000, 2000, 2000, 2000]
        var data = Data(header.utf8)
        for sample in samples {
            data.append(UInt8(sample >> 8))
            data.append(UInt8(sample & 0xFF))
        }
        return data
    }
}

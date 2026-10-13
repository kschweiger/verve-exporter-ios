import Foundation

enum GeoidGridError: Error {
    case invalidData
    case invalidCoordinate
    case missingResource
}

/// GeographicLib global P5 grid: north-to-south rows, periodic eastward columns.
struct GeoidGrid {
    let columns: Int
    let rows: Int
    private let data: Data
    private let rasterStart: Int
    private let offset: Double
    private let scale: Double

    init(data: Data) throws {
        var reader = GeoidPGMReader(data: data)
        guard try reader.nextContentLine() == "P5" else {
            throw GeoidGridError.invalidData
        }
        let dimensions = try reader.nextContentLine().split(whereSeparator: \.isWhitespace)
        guard dimensions.count == 2,
              let columns = Int(dimensions[0]), let rows = Int(dimensions[1]),
              columns >= 4, columns.isMultiple(of: 2), rows == columns / 2 + 1,
              try reader.nextContentLine() == "65535",
              let offsetText = reader.metadata["Offset"], let offset = Double(offsetText), offset.isFinite,
              let scaleText = reader.metadata["Scale"], let scale = Double(scaleText), scale.isFinite, scale > 0,
              reader.metadata["Origin"].map({ $0 == "90N 0E" }) ?? true,
              reader.metadata["Vertical_Datum"].map({ $0 == "WGS84" }) ?? true
        else {
            throw GeoidGridError.invalidData
        }
        let (samples, sampleOverflow) = columns.multipliedReportingOverflow(by: rows)
        let (bytes, byteOverflow) = samples.multipliedReportingOverflow(by: 2)
        guard !sampleOverflow, !byteOverflow, bytes == data.endIndex - reader.position else {
            throw GeoidGridError.invalidData
        }
        self.columns = columns
        self.rows = rows
        self.data = data
        rasterStart = reader.position
        self.offset = offset
        self.scale = scale
    }

    func undulationMeters(latitude: Double, longitude: Double) throws -> Double {
        guard latitude.isFinite, longitude.isFinite, (-90 ... 90).contains(latitude) else {
            throw GeoidGridError.invalidCoordinate
        }
        let remainder = longitude.truncatingRemainder(dividingBy: 360)
        let normalizedLongitude = remainder < 0 ? remainder + 360 : remainder
        let columnPosition = normalizedLongitude * Double(columns) / 360
        let rowPosition = (90 - latitude) * Double(rows - 1) / 180
        let west = Int(floor(columnPosition)) % columns
        let east = (west + 1) % columns
        let north = min(Int(floor(rowPosition)), rows - 2)
        let south = north + 1
        let eastWeight = columnPosition - floor(columnPosition)
        let southWeight = rowPosition - Double(north)
        let top = sample(row: north, column: west) * (1 - eastWeight)
            + sample(row: north, column: east) * eastWeight
        let bottom = sample(row: south, column: west) * (1 - eastWeight)
            + sample(row: south, column: east) * eastWeight
        let height = offset + scale * (top * (1 - southWeight) + bottom * southWeight)
        guard height.isFinite else {
            throw GeoidGridError.invalidData
        }
        return height
    }

    private func sample(row: Int, column: Int) -> Double {
        let index = rasterStart + 2 * (row * columns + column)
        return Double(UInt16(data[index]) << 8 | UInt16(data[index + 1]))
    }
}

/// Reads whole ASCII header lines only; never skips whitespace in the raster.
private struct GeoidPGMReader {
    private let data: Data
    private(set) var position: Int
    private(set) var metadata: [String: String] = [:]

    init(data: Data) {
        self.data = data
        position = data.startIndex
    }

    mutating func nextContentLine() throws -> String {
        let headerEnd = data.startIndex + min(data.count, 16384)
        while position < headerEnd {
            guard let end = data[position ..< headerEnd].firstIndex(of: 10),
                  let text = String(data: data[position ..< end], encoding: .ascii)
            else {
                throw GeoidGridError.invalidData
            }
            position = end + 1
            let line = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty {
                continue
            }
            guard line.hasPrefix("#") else {
                return line
            }
            let fields = line.dropFirst().split(maxSplits: 1, whereSeparator: \.isWhitespace)
            if fields.count == 2 {
                let key = String(fields[0])
                if ["Offset", "Scale", "Origin", "Vertical_Datum"].contains(key) {
                    guard metadata[key] == nil else {
                        throw GeoidGridError.invalidData
                    }
                    metadata[key] = fields[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        throw GeoidGridError.invalidData
    }
}

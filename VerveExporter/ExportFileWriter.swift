import Foundation

enum ExportFileWriter {
    static func write(_ export: GeoJSONExport, to directory: URL) throws -> URL {
        let original = directory.appendingPathComponent(export.fileName)
        var destination = original
        var suffix = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            let name = original.deletingPathExtension().lastPathComponent
            destination = directory.appendingPathComponent("\(name)-\(suffix).\(original.pathExtension)")
            suffix += 1
        }
        try export.data.write(to: destination, options: .atomic)
        return destination
    }
}

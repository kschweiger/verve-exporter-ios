import CryptoKit
import Foundation

enum BundledGeoidGrid {
    static let cached: Result<GeoidGrid, Error> = Result { try load() }
    private static let checksum = "96d55e88db186ddae892b00c5f8cc42a37cdac8ddb69b6de00af8c75dffb34a3"

    static func resourceURL(in bundle: Bundle) throws -> URL {
        guard let url = bundle.url(forResource: "egm2008-5", withExtension: "pgm")
            ?? bundle.url(forResource: "egm2008-5", withExtension: "pgm", subdirectory: "Resources/Geoid")
        else {
            throw GeoidGridError.missingResource
        }
        return url
    }

    static func load(bundle: Bundle = .main) throws -> GeoidGrid {
        let url = try resourceURL(in: bundle)
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try validatedGrid(data: data)
    }

    static func validatedGrid(data: Data) throws -> GeoidGrid {
        guard data.count == 18_671_444 else {
            throw GeoidGridError.invalidData
        }
        let actualChecksum = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        guard actualChecksum == checksum else {
            throw GeoidGridError.invalidData
        }
        return try GeoidGrid(data: data)
    }
}

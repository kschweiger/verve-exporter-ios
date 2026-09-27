//
//  GeoJSON.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 28.12.25.
//

import Foundation

typealias Coordinates = [Double]

struct MetricSummary: Encodable {
    let avg: Double?
    let max: Double?
    let min: Double?
}

struct ActivityStats: Encodable {
    let speed: MetricSummary?
    let heartRate: MetricSummary?
    let power: MetricSummary?
    let cadence: MetricSummary?
    
    enum CodingKeys: String, CodingKey {
        case speed
        case heartRate
        case power
        case cadence
    }
}

struct EquipmentExport: Encodable {
    let name: String
    let type: String
    let brand: String?
    let model: String?
}

struct VerveMetadata: Encodable {
    let target: String
    let version: String
    let data: SwimmingMetadata
}

struct SwimmingMetadata: Encodable {
    let poolLengthMeters: Double?
    let totalStrokeCount: Int?
    let averageSwolf: Double?
    let lapCount: Int?
    let setCount: Int?
    let strokeStyles: [String]?
    let laps: [SwimLapMetadata]?
    let sets: [SwimSetMetadata]?

    var hasMeaningfulData: Bool {
        poolLengthMeters != nil ||
        totalStrokeCount != nil ||
        averageSwolf != nil ||
        lapCount != nil ||
        setCount != nil ||
        strokeStyles?.isEmpty == false ||
        laps?.isEmpty == false ||
        sets?.isEmpty == false
    }
}

struct SwimLapMetadata: Encodable {
    let index: Int
    let startTime: String?
    let endTime: String?
    let durationSeconds: Double?
    let distanceMeters: Double?
    let strokeStyle: String?
    let strokeCount: Int?
    let swolf: Double?
    let restAfterSeconds: Double?
}

struct SwimSetMetadata: Encodable {
    let index: Int
    let startTime: String?
    let endTime: String?
    let durationSeconds: Double?
    let lapStartIndex: Int?
    let lapEndIndex: Int?
    let lapCount: Int?
    let distanceMeters: Double?
    let strokeStyle: String?
    let strokeCount: Int?
    let averageSwolf: Double?
    let restAfterSeconds: Double?
}

struct LineStringGeometry: Encodable {
    let type = "LineString"
    let coordinates: [Coordinates]
}

struct LineProperties: Encodable {
    let coordTimes: [String]
    let heartRates: [Int?]?
    let cadences: [Int?]?
    let powers: [Double?]?
    let temperatures: [Double?]?
    
    enum CodingKeys: String, CodingKey {
        case coordTimes
        case heartRates
        case cadences
        case powers
        case temperatures
    }
}

struct LineFeature: Encodable {
    let type = "Feature"
    let geometry: LineStringGeometry?
    let properties: LineProperties
    
    enum CodingKeys: String, CodingKey {
        case type
        case geometry
        case properties
    }
    
    // Manual implementation to force "geometry": null
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        // 1. Encode Type
        try container.encode(type, forKey: .type)
        
        // 2. Encode Properties
        try container.encode(properties, forKey: .properties)
        
        // 3. Encode Geometry (Explicit Null handling)
        if let geometry = geometry {
            try container.encode(geometry, forKey: .geometry)
        } else {
            // This writes "geometry": null into the JSON
            try container.encodeNil(forKey: .geometry)
        }
    }
}


struct VerveProperties: Encodable {
    // -- Identification --
    let verveVersion: String = "1.0"
    let generator: String = "VerveExporteriOS"
    
    // -- Core Data --
    let name: String
    let description: String?
    let activityType: String
    let activitySubType: String?
    
    let startTime: String
    
    // -- Dimensions --
    let durationSeconds: Double
    let totalDistanceMeters: Double?
    let totalEnergyKcal: Double?
    
    let elevationGain: Double?
    let elevationLoss: Double?
    
    // -- Extensible Aggregates --
    let stats: ActivityStats
    
    // -- Context --
    let equipment: [EquipmentExport]?
    let metadata: VerveMetadata?
    
    enum CodingKeys: String, CodingKey {
        case verveVersion
        case generator
        case name, description
        case activityType, activitySubType
        case startTime
        case durationSeconds
        case totalDistanceMeters
        case totalEnergyKcal
        case elevationGain, elevationLoss
        case stats, equipment
        case metadata
    }
}


struct VerveFeature: Encodable {
    let type = "FeatureCollection"
    let features: [LineFeature]
    let properties: VerveProperties
}

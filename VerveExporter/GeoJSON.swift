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
    let movingDistanceSeconds: Double?
    let totalDistanceMeters: Double?
    let totalEnergyKcal: Double?
    
    let elevationGain: Double?
    let elevationLoss: Double?
    
    // -- Extensible Aggregates --
    let stats: ActivityStats
    
    // -- Context --
    let equipment: [EquipmentExport]?
    
    enum CodingKeys: String, CodingKey {
        case verveVersion
        case generator
        case name, description
        case activityType, activitySubType
        case startTime
        case durationSeconds
        case movingDistanceSeconds
        case totalDistanceMeters
        case totalEnergyKcal
        case elevationGain, elevationLoss
        case stats, equipment
    }
}


struct VerveFeature: Encodable {
    let type = "FeatureCollection"
    let features: [LineFeature]
    let properties: VerveProperties
}

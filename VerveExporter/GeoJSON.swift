//
//  GeoJSON.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 28.12.25.
//

import Foundation

struct RootFeature: Encodable {
    let type = "Feature"
    let geometry: LineStringGeometry? // Nullable for non-GPS workouts
    let properties: ActivityProperties
}

struct LineStringGeometry: Encodable {
    let type = "LineString"
    let coordinates: [[Double]]
}

struct ActivityProperties: Encodable {
    // --- Metadata ---
    let name: String
    let activityType: String
    let startTime: Date
    let durationSeconds: Double
    let totalDistanceMeters: Double?
    let totalEnergyKcal: Double?
    
    // --- Time Series Data ---
    // We rename "coordTimes" to "timestamps" to be generic,
    // but you can map it back to "coordTimes" using CodingKeys if your backend requires it.
    let timestamps: [String]?
    let heartRates: [Int?]?
    
    enum CodingKeys: String, CodingKey {
        case name, activityType, startTime, durationSeconds
        case totalDistanceMeters, totalEnergyKcal
        case timestamps = "coordTimes" // Maps Swift 'timestamps' -> JSON 'coordTimes'
        case heartRates
    }
}

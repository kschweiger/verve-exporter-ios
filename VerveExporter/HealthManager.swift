//
//  HealthManager.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import Foundation
import HealthKit
import CoreLocation

@Observable
class HealthManager {
    let healthStore = HKHealthStore()
    
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization() async throws {
        let readTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
    
    func fetchWorkouts() async throws -> [HKWorkout] {
        let sortDescriptor = SortDescriptor(\HKWorkout.endDate, order: .reverse)
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(nil)],
            sortDescriptors: [sortDescriptor],
            limit: nil
        )
        return try await query.result(for: healthStore)
    }
    
    func generateGeoJSON(for workout: HKWorkout) async throws -> URL {
        // Fetch Data Streams
        async let locationsTask = try? fetchRouteLocations(for: workout)
        async let heartRatesTask = try? fetchHeartRates(for: workout)
        
        let (gpsDataOrNil, hrDataOrNil) = await (locationsTask, heartRatesTask)
        
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        
        // Prepare Data
        var features: [LineFeature] = []
        var allHRValues: [Double] = []
        
        // Process Logic
        if let gpsData = gpsDataOrNil, !gpsData.isEmpty {
            // --- SCENARIO A: GPS Exists (Outdoor Run/Bike/Hike) ---
            var coords: [Coordinates] = []
            var times: [String] = []
            var hrs: [Int?] = []
            
            let hrSamples = hrDataOrNil ?? []
            
            for location in gpsData {
                // Geometry
                coords.append([
                    location.coordinate.longitude,
                    location.coordinate.latitude,
                    location.altitude
                ])
                
                // Time
                times.append(isoFormatter.string(from: location.timestamp))
                
                // Nearest Neighbor HR
                let closestHR = hrSamples.min(by: {
                    abs($0.startDate.timeIntervalSince(location.timestamp)) < abs($1.startDate.timeIntervalSince(location.timestamp))
                })
                
                var hrVal: Int? = nil
                if let hr = closestHR, abs(hr.startDate.timeIntervalSince(location.timestamp)) < 30 {
                    let val = hr.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    hrVal = Int(round(val))
                    allHRValues.append(val)
                }
                hrs.append(hrVal)
            }
            
            let geometry = LineStringGeometry(coordinates: coords)
            let properties = LineProperties(
                coordTimes: times,
                heartRates: hrs,
                cadences: nil, powers: nil, temperatures: nil
            )
            
            features.append(LineFeature(geometry: geometry, properties: properties))
            
        } else if let hrSamples = hrDataOrNil, !hrSamples.isEmpty {
            // --- SCENARIO B: No GPS, but HR Exists (Treadmill, Strength, Yoga) ---
            var times: [String] = []
            var hrs: [Int?] = []
            
            for sample in hrSamples {
                // Time
                times.append(isoFormatter.string(from: sample.startDate))
                
                // Value
                let val = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                let intVal = Int(round(val))
                
                hrs.append(intVal)
                allHRValues.append(val) // Add to stats
            }
            
            let properties = LineProperties(
                coordTimes: times,
                heartRates: hrs,
                cadences: nil, powers: nil, temperatures: nil
            )
            
            // Note: geometry is nil here
            features.append(LineFeature(geometry: nil, properties: properties))
        }
        
        // Calculate Global Properties
        
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let totalCalories = workout.statistics(for: energyType)?
            .sumQuantity()?
            .doubleValue(for: .kilocalorie())
        
        var totalDistance: Double? = nil
        let distanceTypes: [HKQuantityTypeIdentifier] = [
            .distanceWalkingRunning, .distanceCycling, .distanceSwimming
        ]
        for identifier in distanceTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier),
               let quantity = workout.statistics(for: type)?.sumQuantity() {
                totalDistance = quantity.doubleValue(for: .meter())
                break
            }
        }
        
        let hrStats = calculateStats(from: allHRValues)
        
        let activityStats = ActivityStats(
            speed: nil,
            heartRate: hrStats,
            power: nil,
            cadence: nil
        )
        
        let verveProps = VerveProperties(
            name: workout.workoutActivityType.name,
            description: nil,
            activityType: workout.workoutActivityType.name,
            activitySubType: nil,
            startTime: isoFormatter.string(from: workout.startDate),
            durationSeconds: workout.duration,
            movingDistanceSeconds: workout.duration,
            totalDistanceMeters: totalDistance,
            totalEnergyKcal: totalCalories,
            elevationGain: nil,
            elevationLoss: nil,
            stats: activityStats,
            equipment: nil
        )
        
        let root = VerveFeature(features: features, properties: verveProps)
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let data = try encoder.encode(root)
        
        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = fileDateFormatter.string(from: workout.startDate)
        let cleanType = workout.workoutActivityType.name.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(dateString)_\(cleanType).json"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    private func calculateStats(from values: [Double]) -> MetricSummary? {
        guard !values.isEmpty else {
            return nil
        }
        
        let min = values.min()
        let max = values.max()
        let sum = values.reduce(0, +)
        let avg = sum / Double(values.count)
        
        return MetricSummary(avg: avg, max: max, min: min)
    }
    
    private func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let routeQuery = HKSampleQueryDescriptor(
            predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: workoutPredicate)],
            sortDescriptors: [],
            limit: 1
        )
        
        guard let route = try await routeQuery.result(for: healthStore).first as? HKWorkoutRoute else {
            return []
        }
        
        var allLocations: [CLLocation] = []
        for try await batch in streamRouteLocations(route: route) {
            allLocations.append(contentsOf: batch)
        }
        return allLocations
    }
    
    private func streamRouteLocations(route: HKWorkoutRoute) -> AsyncThrowingStream<[CLLocation], Error> {
        return AsyncThrowingStream { continuation in
            let query = HKWorkoutRouteQuery(route: route) { query, locationsOrNil, done, error in
                if let error = error {
                    continuation.finish(throwing: error)
                    return
                }
                if let locations = locationsOrNil {
                    continuation.yield(locations)
                }
                if done {
                    continuation.finish()
                }
            }
            self.healthStore.execute(query)
        }
    }
    
    private func fetchHeartRates(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKSamplePredicate.quantitySample(
            type: hrType,
            predicate: HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        )
        let query = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return try await query.result(for: healthStore)
    }
}

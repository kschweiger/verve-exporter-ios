//
//  HealthManager.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import Foundation
import HealthKit
import CoreLocation

// Helper to hold your backend schema
struct VerveActivityCategory {
    let type: String
    let subType: String?
}

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
        
        // --- Map Activity Types ---
        let mapping = mapToVerveActivity(workout: workout)
        let displayName = workout.workoutActivityType.name
        
        let verveProps = VerveProperties(
            name: displayName,
            description: nil,
            activityType: mapping.type,
            activitySubType: mapping.subType,
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
        
        // --- Filename Generation ---
        let fileDateFormatter = DateFormatter()
        fileDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let dateString = fileDateFormatter.string(from: workout.startDate)
        
        // Concatenate Type and SubType (if present)
        var fileNameType = mapping.type
        if let sub = mapping.subType {
            fileNameType += " \(sub)"
        }
        
        // Replace spaces with underscores
        let safeType = fileNameType.replacingOccurrences(of: " ", with: "_")
        let fileName = "\(dateString)_\(safeType).json"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: tempURL)
        
        return tempURL
    }
    
    
    private func mapToVerveActivity(workout: HKWorkout) -> VerveActivityCategory {
        // Detect Indoor status via Metadata
        let isIndoor = (workout.metadata?[HKMetadataKeyIndoorWorkout] as? Bool) ?? false
        
        switch workout.workoutActivityType {
            
            // --- CYCLING ---
        case .cycling:
            if isIndoor {
                return VerveActivityCategory(type: "Cycling", subType: "Indoor")
            } else {
                return VerveActivityCategory(type: "Cycling", subType: nil)
            }
            
            // --- FOOT SPORTS ---
        case .walking:
            if isIndoor {
                return VerveActivityCategory(type: "Foot Sports", subType: "Treadmill")
            } else {
                return VerveActivityCategory(type: "Foot Sports", subType: "Walk")
            }
            
        case .running:
            if isIndoor {
                return VerveActivityCategory(type: "Foot Sports", subType: "Treadmill")
            } else {
                return VerveActivityCategory(type: "Foot Sports", subType: "Run")
            }
            
        case .hiking:
            return VerveActivityCategory(type: "Foot Sports", subType: "Hike")
            
            // --- WINTER SPORTS ---
        case .crossCountrySkiing:
            return VerveActivityCategory(type: "Winter Sports", subType: "Cross-country Skiing")
        case .downhillSkiing, .snowSports:
            return VerveActivityCategory(type: "Winter Sports", subType: "Downhill Skiing")
        case .snowboarding:
            return VerveActivityCategory(type: "Winter Sports", subType: "Downhill Skiing")
            
            // --- SWIMMING ---
        case .swimming:
            return VerveActivityCategory(type: "Swimming", subType: isIndoor ? "Indoor" : "Open Water")
            
            // --- STRENGTH TRAINING ---
        case .traditionalStrengthTraining:
            return VerveActivityCategory(type: "Strength Training", subType: "Weight Training")
        case .functionalStrengthTraining:
            return VerveActivityCategory(type: "Strength Training", subType: "Circuit Training")
        case .crossTraining:
            return VerveActivityCategory(type: "Strength Training", subType: "CrossFit")
            
            // --- INDOOR CARDIO ---
        case .elliptical:
            return VerveActivityCategory(type: "Indoor Cardio", subType: "Elliptical")
        case .stairClimbing:
            return VerveActivityCategory(type: "Indoor Cardio", subType: "Stair Stepper")
        case .rowing:
            return VerveActivityCategory(type: "Indoor Cardio", subType: "Indoor Rowing")
            
            // --- FITNESS & FLEXIBILITY ---
        case .yoga:
            return VerveActivityCategory(type: "Fitness & Flexibility", subType: "Yoga")
        case .pilates:
            return VerveActivityCategory(type: "Fitness & Flexibility", subType: "Pilates")
        case .highIntensityIntervalTraining:
            return VerveActivityCategory(type: "Fitness & Flexibility", subType: "HIIT")
            // --- CLIMBING ---
        case .climbing:
            return VerveActivityCategory(type: "Climbing", subType: nil)
            // --- OTHER ---
        case .skatingSports:
            return VerveActivityCategory(type: "Other", subType: "Skateboarding")
            
            // --- DEFAULTS ---
        default:
            return VerveActivityCategory(type: "Other", subType: "Other")
        }
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

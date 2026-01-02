//
//  HealthManager.swift.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import Foundation
import HealthKit
import CoreLocation
// @Observable is the new state management macro (Swift 5.9+).
// Any view watching this object will auto-update when properties change.
@Observable
class HealthManager {
    // The connection to the database
    let healthStore = HKHealthStore()
    
    // Check if HealthKit is actually available on this device (e.g. not an iPad)
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }
    
    // AUTHORIZATION
    // Python analogy: This is like doing an OAuth handshake.
    func requestAuthorization() async throws {
        // We define the types we want to read.
        // We want Workouts, Routes, and Heart Rate.
        // Even though we aren't loading HR yet, we ask for permission now so we don't bug the user twice.
        let readTypes: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        // This prompts the system dialog. It suspends execution until the user clicks "Allow" or "Don't Allow".
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }
    
    // FETCH WORKOUTS
    // Python analogy: SELECT * FROM Workouts ORDER BY endDate DESC
    func fetchWorkouts() async throws -> [HKWorkout] {
        // Predicate is Apple's version of a SQL "WHERE" clause.
        // Here, nil means "Select All".
        let predicate: NSPredicate? = nil
        
        // We want to sort by date, newest first.
        let sortDescriptor = SortDescriptor(\HKWorkout.endDate, order: .reverse)
        
        // The Query Descriptor. This is the definition of the fetch request.
        let query = HKSampleQueryDescriptor(
            predicates: [.workout(predicate)],
            sortDescriptors: [sortDescriptor],
            limit: nil // No limit, give me everything
        )
        
        // Execute the query.
        // The result is an array of HKSample, which we cast to [HKWorkout].
        let workouts = try await query.result(for: healthStore)
        return workouts
    }
}

extension HealthManager {
    
    // Main Entry Point
    func generateGeoJSON(for workout: HKWorkout) async throws -> URL {
            // 1. Fetch Data Streams (Async)
            // We use try? to handle cases where data is missing without crashing
            async let locationsTask = try? fetchRouteLocations(for: workout)
            async let heartRatesTask = try? fetchHeartRates(for: workout)
            
            let (gpsDataOrNil, hrDataOrNil) = await (locationsTask, heartRatesTask)
            
            // Formatter for ISO8601
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime]
            
            // 2. Prepare Containers
            var geometry: LineStringGeometry? = nil
            var finalTimestamps: [String]? = nil
            var finalHeartRates: [Int?]? = nil
            
            // Unpack HR data safely (empty list if nil)
            let hrSamples = hrDataOrNil ?? []
            
            // A. Energy
            let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
            let totalCalories = workout.statistics(for: energyType)?
                .sumQuantity()?
                .doubleValue(for: .kilocalorie())
            
            // B. Distance
            // Distance is tricky because the TYPE depends on the activity (Run vs Swim vs Bike).
            // We try the most common ones.
            var totalDistance: Double? = nil
            
            let distanceTypes: [HKQuantityTypeIdentifier] = [
                .distanceWalkingRunning,
                .distanceCycling,
                .distanceSwimming,
                .distanceWheelchair
            ]
            
            for identifier in distanceTypes {
                if let type = HKQuantityType.quantityType(forIdentifier: identifier),
                   let quantity = workout.statistics(for: type)?.sumQuantity() {
                    totalDistance = quantity.doubleValue(for: .meter())
                    break // Found the matching distance type
                }
            }
        
            // 3. Logic Branching
            
            if let gpsData = gpsDataOrNil, !gpsData.isEmpty {
                // --- SCENARIO A: We have GPS (Master = Location) ---
                // We resample Heart Rate to align with GPS points
                
                var coords: [[Double]] = []
                var times: [String] = []
                var hrs: [Int?] = []
                
                for location in gpsData {
                    // Geometry
                    coords.append([
                        location.coordinate.longitude,
                        location.coordinate.latitude,
                        location.altitude
                    ])
                    
                    // Time
                    times.append(isoFormatter.string(from: location.timestamp))
                    
                    // Nearest Neighbor HR Match
                    let closestHR = hrSamples.min(by: {
                        abs($0.startDate.timeIntervalSince(location.timestamp)) < abs($1.startDate.timeIntervalSince(location.timestamp))
                    })
                    
                    var hrValue: Int? = nil
                    // Only link if within 30 seconds
                    if let hr = closestHR, abs(hr.startDate.timeIntervalSince(location.timestamp)) < 30 {
                        let val = hr.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                        hrValue = Int(round(val))
                    }
                    hrs.append(hrValue)
                }
                
                geometry = LineStringGeometry(coordinates: coords)
                finalTimestamps = times
                finalHeartRates = hrs
                
            } else if !hrSamples.isEmpty {
                // --- SCENARIO B: No GPS, but we have Heart Rate (Master = HR Sample) ---
                // We dump the raw HR time series
                
                var times: [String] = []
                var hrs: [Int?] = []
                
                for sample in hrSamples {
                    // Time
                    times.append(isoFormatter.string(from: sample.startDate))
                    
                    // Value
                    let val = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                    hrs.append(Int(round(val)))
                }
                
                // Geometry remains nil
                finalTimestamps = times
                finalHeartRates = hrs
            }
            
            // 4. Construct Properties
            let properties = ActivityProperties(
                    name: workout.workoutActivityType.name,
                    activityType: workout.workoutActivityType.name,
                    startTime: workout.startDate,
                    durationSeconds: workout.duration,
                    
                    // Pass the calculated variables from Step 2
                    totalDistanceMeters: totalDistance,
                    totalEnergyKcal: totalCalories,
                    
                    timestamps: finalTimestamps,
                    heartRates: finalHeartRates
                )
            
            // 5. Create Feature & Save
            let rootFeature = RootFeature(
                geometry: geometry,
                properties: properties
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            
            let data = try encoder.encode(rootFeature)
            
            // 1. Create a custom formatter for the filename
            // Format: "2026-05-12_08-30" (Year-Month-Day_Hour-Minute)
            let fileDateFormatter = DateFormatter()
            fileDateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
            
            let dateString = fileDateFormatter.string(from: workout.startDate)
            
            // 2. Clean up the type name (e.g. "Strength Training" -> "Strength_Training")
            let cleanType = workout.workoutActivityType.name
                .replacingOccurrences(of: " ", with: "_")
            
            // 3. Assemble: "2026-05-12_08-30_Strength_Training.json"
            let fileName = "\(dateString)_\(cleanType).json"
            
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            
            return tempURL
        }
    
    // MARK: - Helper: Fetch Route (The Manual Async Way)
    private func fetchRouteLocations(for workout: HKWorkout) async throws -> [CLLocation] {
            // 1. Get the Route Object (Metadata)
            let workoutPredicate = HKQuery.predicateForObjects(from: workout)
            let routeQuery = HKSampleQueryDescriptor(
                predicates: [.sample(type: HKSeriesType.workoutRoute(), predicate: workoutPredicate)],
                sortDescriptors: [],
                limit: 1
            )
            
            guard let route = try await routeQuery.result(for: healthStore).first as? HKWorkoutRoute else {
                // No GPS data found for this workout
                return []
            }
            
            // 2. Stream the data using our custom adapter
            // This gathers all "batches" of GPS points into one big array
            var allLocations: [CLLocation] = []
            
            for try await batch in streamRouteLocations(route: route) {
                allLocations.append(contentsOf: batch)
            }
            
            return allLocations
        }
        
        // MARK: - The Async Adapter
        // This converts the Apple Callback API -> Swift Async Stream
        private func streamRouteLocations(route: HKWorkoutRoute) -> AsyncThrowingStream<[CLLocation], Error> {
            return AsyncThrowingStream { continuation in
                // 1. Create the classic query
                let query = HKWorkoutRouteQuery(route: route) { query, locationsOrNil, done, error in
                    
                    // Handle Errors
                    if let error = error {
                        continuation.finish(throwing: error)
                        return
                    }
                    
                    // Yield Data (Batches of locations)
                    if let locations = locationsOrNil {
                        continuation.yield(locations)
                    }
                    
                    // Handle Completion
                    if done {
                        continuation.finish()
                    }
                }
                
                // 2. Execute it
                self.healthStore.execute(query)
            }
        }
    
    // MARK: - Helper: Fetch Heart Rates
    private func fetchHeartRates(for workout: HKWorkout) async throws -> [HKQuantitySample] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        
        // Predicate: HR samples strictly between start and end of workout
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

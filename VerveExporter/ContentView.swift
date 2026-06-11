//
//  ContentView.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import SwiftUI
import HealthKit
import UIKit

struct ContentView: View {
    @State private var healthManager = HealthManager()
    
    // Local state to hold the data for the UI
    @State private var workouts: [HKWorkout] = []
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            List(workouts, id: \.uuid) { workout in
                // This block runs for every item in the list
                WorkoutRow(workout: workout, healthManager: healthManager)
            }
            .navigationTitle("Activities")
            .task {
                // This acts like "useEffect" or "onMount" in JS frameworks.
                // It runs strictly once when the view appears.
                await loadData()
            }
            .refreshable {
                // Adds "Pull to Refresh" functionality automatically
                await loadData()
            }
            // Simple error handling alert
            .alert("Error", isPresented: Binding(
                get: { errorMessage != nil },
                set: { _ in errorMessage = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
            }
        }
    }
    
    // Helper function to orchestrate the async calls
    private func loadData() async {
        print("--- STARTING LOAD DATA ---")
        do {
            // 1. Check if HealthKit is available
            guard HKHealthStore.isHealthDataAvailable() else {
                print("HealthKit is NOT available on this device.")
                return
            }
            
            // 2. Request Authorization
            print("Requesting authorization...")
            try await healthManager.requestAuthorization()
            print("Authorization request finished.")
            
            // 3. Fetch data
            print("Fetching workouts...")
            let fetchedWorkouts = try await healthManager.fetchWorkouts()
            print("Found \(fetchedWorkouts.count) workouts.")
            
            // 4. Update UI
            self.workouts = fetchedWorkouts
            
        } catch {
            print("CRITICAL ERROR: \(error.localizedDescription)")
            self.errorMessage = error.localizedDescription
        }
    }
}

struct WorkoutRow: View {
    // Inputs
    let workout: HKWorkout
    var healthManager: HealthManager
    
    // Internal State
    @State private var isExporting = false
    @State private var exportFile: ExportFile?
    @State private var showError = false
    
    // New State for Debugging
    @State private var showDebug = false
    
    var body: some View {
        HStack {
            // 1. Icon
            Image(systemName: iconName(for: workout.workoutActivityType))
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            // 2. Text Info
            VStack(alignment: .leading) {
                Text(workout.workoutActivityType.name)
                    .font(.headline)
                
                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 3. Duration
            Text(formatDuration(workout.duration))
                .font(.subheadline)
                .monospacedDigit()
            
            // --- BUTTONS ---
            HStack(spacing: 15) { // Group buttons together
                
                // A. Debug Button (New)
                Button {
                    showDebug = true
                } label: {
                    Image(systemName: "doc.text.magnifyingglass")
                        .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
                
                // B. Export Button
                if isExporting {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            isExporting = true
                            do {
                                let url = try await healthManager.generateGeoJSON(for: workout)
                                self.exportFile = ExportFile(url: url)
                            } catch {
                                print("Export error: \(error.localizedDescription)")
                                showError = true
                            }
                            isExporting = false
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 10)
            
        } // End Main HStack
        
        // --- Modifiers ---
        
        // 1. The Share Sheet
        .sheet(item: $exportFile) { file in
            ActivityView(activityItems: [file.url])
        }
        
        // 2. The Debug Sheet (New)
        .sheet(isPresented: $showDebug) {
            DebugView(workout: workout, healthManager: healthManager)
        }
        
        // 3. Error Alert
        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Could not find data for this workout.")
        }
    }
    
    // ... (Keep your iconName and formatDuration helpers exactly as they were) ...
    func iconName(for type: HKWorkoutActivityType) -> String {
        switch type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .hiking: return "figure.hiking"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .elliptical: return "figure.elliptical"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
        case .yoga: return "figure.yoga"
        case .crossTraining: return "figure.cross.training"
        case .dance: return "figure.dance"
        case .rowing: return "figure.rower"
        case .coreTraining: return "figure.core.training"
        case .cooldown: return "figure.cooldown"
        case .climbing: return "figure.climbing"
        default: return "figure.mixed.cardio"
        }
    }
    
    func formatDuration(_ duration: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: duration) ?? ""
    }
}

// MARK: - Helper Views & Extensions

// 1. Share Sheet Wrapper
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {
    }
}


struct ExportFile: Identifiable {
    let url: URL
    // We use the URL string itself as the unique ID
    var id: String { url.absoluteString }
}

// Extension to map Enum types to readable Strings
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Run"
        case .walking: return "Walk"
        case .hiking: return "Hike"
        case .cycling: return "Bike"
        case .swimming: return "Swim"
            
            // The ones you were missing:
        case .elliptical: return "Elliptical" // Often used for Crosstrainer
        case .traditionalStrengthTraining: return "Strength Training"
        case .functionalStrengthTraining: return "Functional Strength"
        case .crossTraining: return "Cross Training"
            
            // Common Gym/Studio types
        case .yoga: return "Yoga"
        case .pilates: return "Pilates"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climber"
        case .coreTraining: return "Core"
        case .cooldown: return "Cooldown"
        case .highIntensityIntervalTraining: return "HIIT"
        case .climbing: return "Climbing"
            
            // Fallback for the other ~70 types
        default:
            // This is a nifty trick: standardizes "HKWorkoutActivityTypeCaseName" -> "Case Name"
            // Use debugDescription or manual mapping if you want perfection,
            // but for a dev tool, specific cases + a generic string is best.
            return "Workout"
        }
    }
}


#Preview {
    ContentView()
}

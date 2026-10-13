//
//  ContentView.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import HealthKit
import SwiftUI
import UIKit

struct ContentView: View {
    @State private var browser = WorkoutBrowserModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                List {
                    if let latest = browser.workouts.first {
                        Section {
                            WorkoutRow(
                                workout: latest,
                                healthManager: browser.healthManager
                            )
                        } header: {
                            Text("Latest activity")
                                .foregroundStyle(Color("VerveBrown"))
                        }

                        ForEach(monthSections) { month in
                            Section {
                                ForEach(month.workouts, id: \.uuid) { workout in
                                    WorkoutRow(workout: workout, healthManager: browser.healthManager)
                                }
                            } header: {
                                Text(month.date.formatted(.dateTime.month(.wide).year()))
                                    .foregroundStyle(Color("VerveBrown"))
                            }
                        }
                    } else if browser.isLoading {
                        ProgressView("Loading activities…")
                    } else if browser.loadFailed {
                        ContentUnavailableView(
                            "Couldn’t load activities",
                            systemImage: "exclamationmark.arrow.circlepath",
                            description: Text("Try again to read your workouts.")
                        )
                        Button("Try Again") {
                            Task { await browser.reload() }
                        }
                    } else if browser.selectedFilter == .all {
                        ContentUnavailableView(
                            "No activities",
                            systemImage: "figure.run",
                            description: Text("Workouts from Apple Health will appear here.")
                        )
                    } else {
                        ContentUnavailableView(
                            "No \(browser.selectedFilter.rawValue) activities",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Try another activity type or clear the filter.")
                        )
                        Button("Clear filter") {
                            browser.selectFilter(.all)
                        }
                    }

                    if browser.hasMore {
                        Button {
                            Task { await browser.showMore() }
                        } label: {
                            if browser.isLoadingMore {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Show more")
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .disabled(browser.isLoadingMore)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color("VerveLight"))
                .refreshable {
                    await browser.reload()
                }
            }
            .background(Color("VerveLight"))
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await browser.loadInitially()
            }
            .alert("Error", isPresented: Binding(
                get: { browser.errorMessage != nil },
                set: { _ in browser.errorMessage = nil }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(browser.errorMessage ?? "Unknown error")
            }
        }
        .preferredColorScheme(.light)
    }

    private var filterBar: some View {
        HStack {
            Menu {
                filterMenuItem(.all)
                Divider()
                ForEach(ActivityFilter.allCases.filter { $0 != .all }) { filter in
                    filterMenuItem(filter)
                }
            } label: {
                Label(browser.selectedFilter.rawValue, systemImage: "line.3.horizontal.decrease")
            }

            Spacer()

            if browser.selectedFilter != .all {
                Button {
                    browser.selectFilter(.all)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear activity filter")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func filterMenuItem(_ filter: ActivityFilter) -> some View {
        Button {
            browser.selectFilter(filter)
        } label: {
            if browser.selectedFilter == filter {
                Label(filter.rawValue, systemImage: "checkmark")
            } else {
                Text(filter.rawValue)
            }
        }
    }

    private var monthSections: [WorkoutMonthSection] {
        let grouped = Dictionary(grouping: browser.workouts.dropFirst()) { workout in
            let calendar = Calendar.current
            return calendar.dateInterval(of: .month, for: workout.startDate)?.start
                ?? calendar.startOfDay(for: workout.startDate)
        }
        return grouped.keys.sorted(by: >).map { date in
            WorkoutMonthSection(date: date, workouts: grouped[date] ?? [])
        }
    }
}

private struct WorkoutMonthSection: Identifiable {
    let date: Date
    let workouts: [HKWorkout]

    var id: Date {
        date
    }
}

struct WorkoutRow: View {
    private let isDebugPreviewEnabled = false

    let workout: HKWorkout
    var healthManager: HealthManager

    @State private var isExporting = false
    @State private var exportSheetState: ExportSheetState?
    @State private var activeExportID: UUID?
    @State private var showError = false
    @State private var exportErrorMessage: String?

    @State private var showDebug = false

    var body: some View {
        HStack {
            Image(systemName: WorkoutActivityIconMapper.systemName(for: workout.workoutActivityType))
                .font(.title2)
                .foregroundStyle(Color("VerveDark"))
                .frame(width: 40)

            VStack(alignment: .leading) {
                Text(workout.workoutActivityType.name)
                    .font(.headline)

                Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(Color("VerveBrown").opacity(0.8))
            }

            Spacer()

            Text(formatDuration(workout.duration))
                .font(.subheadline)
                .monospacedDigit()

            HStack(spacing: 15) {
                if isDebugPreviewEnabled {
                    Button {
                        showDebug = true
                    } label: {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }

                if isExporting {
                    ProgressView()
                } else {
                    Button {
                        Task {
                            let exportID = UUID()
                            activeExportID = exportID
                            isExporting = true
                            exportErrorMessage = nil
                            exportSheetState = .preparing(exportID)

                            #if DEBUG
                                let exportStart = Date()
                                print("Export started for workout \(workout.uuid)")
                            #endif

                            do {
                                let url = try await healthManager.generateGeoJSON(for: workout)

                                #if DEBUG
                                    let elapsed = Date().timeIntervalSince(exportStart)
                                    print(
                                        "Export generated for workout \(workout.uuid) "
                                            + "in \(String(format: "%.2f", elapsed))s"
                                    )
                                #endif

                                if activeExportID == exportID {
                                    exportSheetState = .sharing(ExportFile(url: url))
                                }
                            } catch {
                                print("Export error: \(error.localizedDescription)")

                                if activeExportID == exportID {
                                    exportSheetState = nil
                                    exportErrorMessage = error.localizedDescription
                                    showError = true
                                }
                            }

                            if activeExportID == exportID {
                                isExporting = false
                                activeExportID = nil
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.tint)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.leading, 10)
        }
        .foregroundStyle(Color("VerveBrown"))
        .listRowBackground(Color.white)
        .sheet(
            item: $exportSheetState,
            onDismiss: {
                activeExportID = nil
                isExporting = false
            },
            content: { state in
                switch state {
                case .preparing:
                    PreparingExportView()
                case let .sharing(file):
                    ActivityView(activityItems: [file.url])
                }
            }
        )

        .sheet(isPresented: $showDebug) {
            DebugView(workout: workout, healthManager: healthManager)
        }

        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportErrorMessage ?? "Could not export this workout.")
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

/// 1. Share Sheet Wrapper
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    var applicationActivities: [UIActivity]?

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
    }

    func updateUIViewController(
        _: UIActivityViewController,
        context _: Context
    ) {}
}

struct PreparingExportView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)

            Text("Preparing Export")
                .font(.headline)

            Text("Reading workout data...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

enum ExportSheetState: Identifiable {
    case preparing(UUID)
    case sharing(ExportFile)

    var id: String {
        switch self {
        case let .preparing(id):
            return "preparing-\(id.uuidString)"
        case let .sharing(file):
            return "sharing-\(file.id)"
        }
    }
}

struct ExportFile: Identifiable {
    let url: URL
    /// We use the URL string itself as the unique ID
    var id: String {
        url.absoluteString
    }
}

/// Extension to map Enum types to readable Strings
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Run"
        case .walking: return "Walk"
        case .hiking: return "Hike"
        case .cycling: return "Bike"
        case .swimming: return "Swim"
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
            return "Workout"
        }
    }
}

#Preview {
    ContentView()
}

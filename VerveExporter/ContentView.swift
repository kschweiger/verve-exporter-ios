//
//  ContentView.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 27.12.25.
//

import HealthKit
import SwiftUI

struct ContentView: View {
    @State private var browser = WorkoutBrowserModel()
    @State private var bulk = BulkExportModel()
    @State private var isBulkSheetPresented = false
    @State private var bulkPresentationActive = false
    @State private var activeIndividualExports: Set<UUID> = []

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterBar

                List {
                    if let latest = browser.workouts.first {
                        Section {
                            workoutRow(latest)
                        } header: {
                            Text("Latest activity")
                                .foregroundStyle(Color("VerveBrown"))
                        }

                        ForEach(monthSections) { month in
                            Section {
                                ForEach(month.workouts, id: \.uuid) { workout in
                                    workoutRow(workout)
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
                .modifier(BrowserRefreshModifier(isEnabled: !bulk.isSelecting, browser: browser))

                if bulk.isSelecting {
                    selectionBar
                }
            }
            .disabled(bulkPresentationActive)
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
        .sheet(isPresented: $isBulkSheetPresented, onDismiss: {
            bulk.dismiss()
            bulkPresentationActive = false
        }, content: {
            BulkExportSheet(model: bulk) { isBulkSheetPresented = false }
        })
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

            .disabled(bulk.isSelecting)

            Spacer()

            if !bulk.isSelecting, browser.selectedFilter != .all {
                Button {
                    browser.selectFilter(.all)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Clear activity filter")
            }

            Button(bulk.isSelecting ? "Cancel" : "Select") {
                if bulk.isSelecting {
                    bulk.endSelection()
                } else {
                    bulk.beginSelection()
                }
            }
            .disabled(browser.isLoading || browser.isLoadingMore || !activeIndividualExports.isEmpty
                || (!bulk.isSelecting && browser.workouts.isEmpty))
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func workoutRow(_ workout: HKWorkout) -> some View {
        if bulk.isSelecting {
            Button {
                bulk.toggle(workout)
            } label: {
                HStack {
                    Image(systemName: bulk.selectedIDs.contains(workout.uuid)
                        ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(.tint)
                    WorkoutRow(workout: workout, healthManager: browser.healthManager, showsExportActions: false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowBackground(Color.white)
            .accessibilityValue(bulk.selectedIDs.contains(workout.uuid) ? "Selected" : "Not selected")
            .accessibilityAddTraits(bulk.selectedIDs.contains(workout.uuid) ? .isSelected : [])
        } else {
            WorkoutRow(workout: workout, healthManager: browser.healthManager) { active in
                if active {
                    activeIndividualExports.insert(workout.uuid)
                } else {
                    activeIndividualExports.remove(workout.uuid)
                }
            }
        }
    }

    private var selectionBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button("Select loaded") { bulk.selectLoaded(browser.workouts) }
                Spacer()
                Button("Deselect all") { bulk.clearSelection() }
                    .disabled(bulk.selectedIDs.isEmpty)
            }
            Button("Export (\(bulk.selectedIDs.count))") {
                let snapshot = bulk.selectedWorkouts(in: browser.workouts)
                bulkPresentationActive = true
                isBulkSheetPresented = true
                Task { await bulk.prepare(snapshot) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(bulk.selectedIDs.isEmpty || browser.isLoadingMore)
        }
        .padding()
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

#Preview {
    ContentView()
}

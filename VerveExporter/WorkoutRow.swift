import HealthKit
import SwiftUI
import UIKit

struct WorkoutRow: View {
    private let isDebugPreviewEnabled = false

    let workout: HKWorkout
    var healthManager: HealthManager
    var showsExportActions = true
    var onExportPresentationChanged: (Bool) -> Void = { _ in }

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

            if showsExportActions {
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
                                onExportPresentationChanged(true)
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
                                        onExportPresentationChanged(false)
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
        }
        .foregroundStyle(Color("VerveBrown"))
        .listRowBackground(Color.white)
        .sheet(
            item: $exportSheetState,
            onDismiss: {
                activeExportID = nil
                isExporting = false
                onExportPresentationChanged(false)
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

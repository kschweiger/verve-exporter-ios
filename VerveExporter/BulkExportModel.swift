import Foundation
import HealthKit

struct BulkExportFailure: Identifiable {
    let id: UUID
    let date: Date
    let activity: String
    let message: String
}

@MainActor
@Observable
final class BulkExportModel {
    enum Phase { case idle, preparing, results, sharing }

    private(set) var selectedIDs: Set<UUID> = []
    private(set) var phase: Phase = .idle
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    private(set) var files: [URL] = []
    private(set) var failures: [BulkExportFailure] = []
    private(set) var directory: URL?
    private(set) var setupError: String?

    private var attemptID: UUID?
    private let export: (HKWorkout, URL) async throws -> URL

    init(export: @escaping (HKWorkout, URL) async throws -> URL = { workout, directory in
        try await HealthManager().generateGeoJSON(for: workout, destinationDirectory: directory)
    }) {
        self.export = export
    }

    func toggle(_ workout: HKWorkout) {
        if !selectedIDs.insert(workout.uuid).inserted {
            selectedIDs.remove(workout.uuid)
        }
    }

    func selectLoaded(_ workouts: [HKWorkout]) {
        selectedIDs.formUnion(workouts.map(\.uuid))
    }

    func clearSelection() {
        selectedIDs.removeAll()
    }

    func selectedWorkouts(in workouts: [HKWorkout]) -> [HKWorkout] {
        var seen = Set<UUID>()
        return workouts.filter { selectedIDs.contains($0.uuid) && seen.insert($0.uuid).inserted }
    }

    func prepare(_ workouts: [HKWorkout]) async {
        guard phase == .idle else { return }
        var seen = Set<UUID>()
        let snapshot = workouts.filter { seen.insert($0.uuid).inserted }
        guard !snapshot.isEmpty else { return }
        let id = UUID()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("VerveBulk-\(id.uuidString)", isDirectory: true)
        attemptID = id
        directory = folder
        files = []
        failures = []
        setupError = nil
        completedCount = 0
        totalCount = snapshot.count
        phase = .preparing
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
        } catch {
            setupError = error.localizedDescription
            phase = .results
            return
        }
        await Task.yield()
        for workout in snapshot {
            guard attemptID == id, !Task.isCancelled else {
                finishCancelledAttempt(id, folder: folder)
                return
            }
            do {
                let url = try await export(workout, folder)
                guard attemptID == id, !Task.isCancelled else {
                    finishCancelledAttempt(id, folder: folder)
                    return
                }
                files.append(url)
            } catch {
                guard attemptID == id, !Task.isCancelled else {
                    finishCancelledAttempt(id, folder: folder)
                    return
                }
                failures.append(BulkExportFailure(
                    id: workout.uuid, date: workout.startDate,
                    activity: workout.workoutActivityType.name, message: error.localizedDescription
                ))
            }
            completedCount += 1
        }
        phase = failures.isEmpty ? .sharing : .results
    }

    func shareSuccessfulFiles() {
        guard phase == .results, !files.isEmpty else { return }
        phase = .sharing
    }

    func dismiss() {
        let wasPreparing = phase == .preparing
        let folder = directory
        attemptID = nil
        directory = nil
        phase = .idle
        files = []
        failures = []
        setupError = nil
        // An in-flight writer still owns its directory until prepare returns.
        if !wasPreparing, let folder {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private func finishCancelledAttempt(_ id: UUID, folder: URL) {
        try? FileManager.default.removeItem(at: folder)
        if attemptID == id {
            dismiss()
        }
    }
}

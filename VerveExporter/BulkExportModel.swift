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

    private(set) var isSelecting = false
    private(set) var selectedIDs: Set<UUID> = []
    private(set) var phase: Phase = .idle
    private(set) var completedCount = 0
    private(set) var totalCount = 0
    private(set) var files: [URL] = []
    private(set) var failures: [BulkExportFailure] = []
    private(set) var directory: URL?
    private(set) var setupError: String?
    private(set) var didShareSuccessfully = false

    private var attemptID: UUID?
    private var pendingShareID: UUID?
    private let export: (HKWorkout, URL) async throws -> URL

    init(export: @escaping (HKWorkout, URL) async throws -> URL = { workout, directory in
        try await HealthManager().generateGeoJSON(for: workout, destinationDirectory: directory)
    }) {
        self.export = export
    }

    func beginSelection() {
        clearSelection()
        isSelecting = true
    }

    func endSelection() {
        clearSelection()
        isSelecting = false
    }

    func toggle(_ workout: HKWorkout) {
        invalidateShareCompletion()
        if !selectedIDs.insert(workout.uuid).inserted {
            selectedIDs.remove(workout.uuid)
        }
    }

    func selectLoaded(_ workouts: [HKWorkout]) {
        invalidateShareCompletion()
        selectedIDs.formUnion(workouts.map(\.uuid))
    }

    func clearSelection() {
        invalidateShareCompletion()
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
        do {
            try beginAttempt(id: id, folder: folder, count: snapshot.count)
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
        if phase == .sharing {
            pendingShareID = id
        }
    }

    func shareSuccessfulFiles() {
        guard phase == .results, !files.isEmpty else { return }
        phase = .sharing
        pendingShareID = attemptID
    }

    func shareCompletionHandler(onCompletion: @escaping () -> Void = {}) -> (Bool) -> Void {
        let id = pendingShareID
        return { [weak self] success in
            guard let self, let id, self.pendingShareID == id else { return }
            self.pendingShareID = nil
            if success {
                self.didShareSuccessfully = true
                self.selectedIDs.removeAll()
                self.isSelecting = false
            }
            onCompletion()
        }
    }

    private func invalidateShareCompletion() {
        pendingShareID = nil
        didShareSuccessfully = false
    }

    func dismiss() {
        let wasPreparing = phase == .preparing
        let folder = directory
        attemptID = nil
        // Sharing may complete after dismissal. Keep its token until a callback or a new user action.
        directory = nil
        phase = .idle
        files = []
        failures = []
        setupError = nil
        didShareSuccessfully = false
        // An in-flight writer still owns its directory until prepare returns.
        if !wasPreparing, let folder {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    private func beginAttempt(id: UUID, folder: URL, count: Int) throws {
        attemptID = id
        pendingShareID = nil
        directory = folder
        files = []
        failures = []
        setupError = nil
        didShareSuccessfully = false
        completedCount = 0
        totalCount = count
        phase = .preparing
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: false)
    }

    private func finishCancelledAttempt(_ id: UUID, folder: URL) {
        try? FileManager.default.removeItem(at: folder)
        if attemptID == id {
            dismiss()
        }
    }
}

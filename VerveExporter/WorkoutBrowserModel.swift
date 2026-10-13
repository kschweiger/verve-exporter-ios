import Foundation
import HealthKit

enum ActivityFilter: String, CaseIterable, Identifiable {
    case all = "All activities"
    case cycling = "Cycling"
    case footSports = "Foot Sports"
    case swimming = "Swimming"
    case winterSports = "Winter Sports"
    case strengthTraining = "Strength Training"
    case indoorCardio = "Indoor Cardio"
    case fitnessAndFlexibility = "Fitness & Flexibility"
    case climbing = "Climbing"
    case other = "Other"

    var id: String {
        rawValue
    }

    func includes(_ workout: HKWorkout) -> Bool {
        self == .all || VerveActivityMapper.category(for: workout, swimmingLocationType: nil).type == rawValue
    }
}

@MainActor
@Observable
final class WorkoutBrowserModel {
    let healthManager = HealthManager()

    private(set) var workouts: [HKWorkout] = []
    private(set) var selectedFilter: ActivityFilter = .all
    private(set) var hasMore = false
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var loadFailed = false
    var errorMessage: String?

    private var hasLoaded = false
    private var hasRequestedAuthorization = false
    private var authorizationTask: Task<Void, Error>?
    private var requestID = UUID()

    func loadInitially() async {
        guard !hasLoaded else { return }
        hasLoaded = true
        await reload()
    }

    func reload() async {
        let id = UUID()
        requestID = id
        isLoading = true
        isLoadingMore = false
        errorMessage = nil
        await load(count: 10, requestID: id)
    }

    func selectFilter(_ filter: ActivityFilter) {
        guard selectedFilter != filter else { return }
        selectedFilter = filter
        workouts = []
        hasMore = false
        loadFailed = false
        errorMessage = nil
        let id = UUID()
        requestID = id
        isLoading = true
        isLoadingMore = false
        Task { await load(count: 10, requestID: id) }
    }

    func showMore() async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        let id = UUID()
        requestID = id
        isLoadingMore = true
        errorMessage = nil
        await load(count: workouts.count + 10, requestID: id)
    }

    private func load(count: Int, requestID id: UUID) async {
        do {
            guard HKHealthStore.isHealthDataAvailable() else {
                throw WorkoutBrowserError.healthDataUnavailable
            }
            try await authorizeIfNeeded()
            let result = try await matchingWorkouts(count: count, filter: selectedFilter, requestID: id)
            guard requestID == id else { return }
            workouts = result.workouts
            hasMore = result.hasMore
            loadFailed = false
        } catch {
            guard requestID == id else { return }
            loadFailed = workouts.isEmpty
            errorMessage = error.localizedDescription
        }
        guard requestID == id else { return }
        isLoading = false
        isLoadingMore = false
    }

    private func authorizeIfNeeded() async throws {
        guard !hasRequestedAuthorization else { return }
        if let authorizationTask {
            try await authorizationTask.value
            return
        }

        let task = Task { try await healthManager.requestAuthorization() }
        authorizationTask = task
        do {
            try await task.value
            hasRequestedAuthorization = true
            authorizationTask = nil
        } catch {
            authorizationTask = nil
            throw error
        }
    }

    private func matchingWorkouts(
        count: Int,
        filter: ActivityFilter,
        requestID id: UUID
    ) async throws -> (workouts: [HKWorkout], hasMore: Bool) {
        let desiredCount = count + 1
        var queryLimit = filter == .all ? desiredCount : max(40, desiredCount)

        while true {
            try Task.checkCancellation()
            guard requestID == id else { throw CancellationError() }
            let fetched = try await healthManager.fetchWorkouts(limit: queryLimit)
            guard requestID == id else { throw CancellationError() }
            var seen = Set<UUID>()
            let matches = fetched.filter { seen.insert($0.uuid).inserted && filter.includes($0) }
            if matches.count >= desiredCount || fetched.count < queryLimit {
                return (Array(matches.prefix(count)), matches.count > count)
            }
            queryLimit *= 2
        }
    }
}

private enum WorkoutBrowserError: LocalizedError {
    case healthDataUnavailable

    var errorDescription: String? {
        "Health data is unavailable on this device."
    }
}

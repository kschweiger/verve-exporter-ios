import HealthKit
@testable import VerveExporter
import XCTest

@MainActor
@available(iOS, deprecated: 17.0, message: "Uses unsaved HKWorkout fixtures for isolated export tests")
final class BulkExportTests: XCTestCase {
    func testSelectionDeduplicatesAndPreservesLoadedChoices() async {
        await Task.yield()
        let model = BulkExportModel()
        let first = workout()
        let second = workout()
        model.selectLoaded([first, first])
        XCTAssertEqual(model.selectedIDs, [first.uuid])
        model.toggle(second)
        XCTAssertEqual(model.selectedWorkouts(in: [second, first, first]).map(\.uuid), [second.uuid, first.uuid])
        model.toggle(first)
        XCTAssertEqual(model.selectedIDs, [second.uuid])
        model.clearSelection()
        XCTAssertTrue(model.selectedIDs.isEmpty)
    }

    func testBatchKeepsSuccessfulFilesAndFailureReasonsInOrder() async throws {
        let first = workout()
        let failed = workout()
        let last = workout()
        var order: [UUID] = []
        let model = BulkExportModel { workout, directory in
            order.append(workout.uuid)
            if workout.uuid == failed.uuid {
                throw GeoJSONExportError.noSamples
            }
            return try ExportFileWriter.write(
                GeoJSONExport(data: Data("{}".utf8), fileName: "same.json"),
                to: directory
            )
        }
        await model.prepare([first, failed, last, first])
        XCTAssertEqual(order, [first.uuid, failed.uuid, last.uuid])
        XCTAssertEqual(model.completedCount, 3)
        XCTAssertEqual(model.totalCount, 3)
        XCTAssertEqual(model.files.map(\.lastPathComponent), ["same.json", "same-2.json"])
        XCTAssertEqual(model.failures.map(\.id), [failed.uuid])
        XCTAssertEqual(model.failures.first?.message, GeoJSONExportError.noSamples.localizedDescription)
        XCTAssertEqual(model.phase, .results)
        let directory = try XCTUnwrap(model.directory)
        model.dismiss()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testAllSuccessSharesAndAllFailureShowsResults() async {
        let model = BulkExportModel { _, directory in
            try ExportFileWriter.write(GeoJSONExport(data: Data("{}".utf8), fileName: "one.json"), to: directory)
        }
        await model.prepare([workout()])
        XCTAssertEqual(model.phase, .sharing)
        XCTAssertEqual(model.files.count, 1)
        model.dismiss()
        let failing = BulkExportModel { _, _ in throw GeoJSONExportError.noSamples }
        await failing.prepare([workout()])
        XCTAssertEqual(failing.phase, .results)
        XCTAssertTrue(failing.files.isEmpty)
        XCTAssertEqual(failing.failures.count, 1)
        failing.dismiss()
    }

    func testCancelledInFlightResultIsDiscardedWithoutStartingNextWorkout() async throws {
        var continuation: CheckedContinuation<Void, Never>?
        var started = 0
        var attemptDirectory: URL?
        let model = BulkExportModel { _, directory in
            started += 1
            attemptDirectory = directory
            await withCheckedContinuation { continuation = $0 }
            return try ExportFileWriter.write(
                GeoJSONExport(data: Data("{}".utf8), fileName: "late.json"),
                to: directory
            )
        }
        let task = Task { await model.prepare([workout(), workout()]) }
        while continuation == nil {
            await Task.yield()
        }
        model.dismiss()
        XCTAssertEqual(model.phase, .idle)
        XCTAssertTrue(try FileManager.default.fileExists(atPath: XCTUnwrap(attemptDirectory).path))
        continuation?.resume()
        await task.value
        XCTAssertEqual(started, 1)
        XCTAssertTrue(model.files.isEmpty)
        XCTAssertEqual(model.phase, .idle)
        XCTAssertFalse(try FileManager.default.fileExists(atPath: XCTUnwrap(attemptDirectory).path))
    }

    func testRetrySurvivesLateCleanupFromCancelledAttempt() async throws {
        var continuation: CheckedContinuation<Void, Never>?
        var calls = 0
        var oldDirectory: URL?
        let model = BulkExportModel { _, directory in
            calls += 1
            if calls == 1 {
                oldDirectory = directory
                await withCheckedContinuation { continuation = $0 }
            }
            return try ExportFileWriter.write(GeoJSONExport(data: Data("{}".utf8), fileName: "one.json"), to: directory)
        }
        let oldTask = Task { await model.prepare([workout(), workout()]) }
        while continuation == nil {
            await Task.yield()
        }
        model.dismiss()
        await model.prepare([workout()])
        let newDirectory = try XCTUnwrap(model.directory)
        let sharedFile = try XCTUnwrap(model.files.first)
        continuation?.resume()
        await oldTask.value
        XCTAssertEqual(calls, 2)
        XCTAssertEqual(model.phase, .sharing)
        XCTAssertEqual(model.directory, newDirectory)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sharedFile.path))
        XCTAssertFalse(try FileManager.default.fileExists(atPath: XCTUnwrap(oldDirectory).path))
        model.dismiss()
        XCTAssertFalse(FileManager.default.fileExists(atPath: newDirectory.path))
    }

    func testEmptyBatchDoesNothingAndFileWriteFailureBecomesAnOutcome() async {
        let model = BulkExportModel { _, directory in
            try ExportFileWriter.write(GeoJSONExport(data: Data("{}".utf8), fileName: "one.json"),
                                       to: directory.appendingPathComponent("missing"))
        }
        await model.prepare([])
        XCTAssertEqual(model.phase, .idle)
        XCTAssertNil(model.directory)
        await model.prepare([workout()])
        XCTAssertEqual(model.phase, .results)
        XCTAssertEqual(model.failures.count, 1)
        XCTAssertTrue(model.files.isEmpty)
        model.shareSuccessfulFiles()
        XCTAssertEqual(model.phase, .results)
        model.dismiss()
    }

    func testWriterPreservesContentsAndDoesNotOverwriteCollisions() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let export = GeoJSONExport(data: Data("{\"invented\":true}".utf8), fileName: "workout.json")
        let first = try ExportFileWriter.write(export, to: directory)
        let second = try ExportFileWriter.write(export, to: directory)
        XCTAssertEqual(first.lastPathComponent, "workout.json")
        XCTAssertEqual(second.lastPathComponent, "workout-2.json")
        XCTAssertEqual(try Data(contentsOf: first), export.data)
        XCTAssertEqual(try Data(contentsOf: second), export.data)
        XCTAssertThrowsError(try ExportFileWriter.write(export, to: directory.appendingPathComponent("missing")))
    }

    private func workout() -> HKWorkout {
        HKWorkout(activityType: .running, start: Date(timeIntervalSince1970: 1_752_000_000),
                  end: Date(timeIntervalSince1970: 1_752_000_120))
    }
}

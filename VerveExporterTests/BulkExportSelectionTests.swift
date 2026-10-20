import HealthKit
@testable import VerveExporter
import XCTest

extension BulkExportTests {
    func testSuccessfulShareClearsSelectionAndKeepsFilesUntilDismissal() async throws {
        let model = successfulExportModel()
        let selected = selectionWorkout()
        model.selectLoaded([selected])
        await model.prepare([selected])
        let directory = try XCTUnwrap(model.directory)
        model.shareCompletionHandler()(true)
        XCTAssertTrue(model.didShareSuccessfully)
        XCTAssertTrue(model.selectedIDs.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        model.dismiss()
        XCTAssertFalse(model.didShareSuccessfully)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    func testCancelledOrFailedSharePreservesSelection() async {
        let model = successfulExportModel()
        let selected = selectionWorkout()
        model.selectLoaded([selected])
        await model.prepare([selected])
        model.shareCompletionHandler()(false)
        XCTAssertFalse(model.didShareSuccessfully)
        XCTAssertEqual(model.selectedIDs, [selected.uuid])
        model.dismiss()
        XCTAssertEqual(model.selectedIDs, [selected.uuid])
    }

    func testSuccessfulPartialShareClearsFailedSelectionsToo() async {
        let failed = selectionWorkout()
        let selected = selectionWorkout()
        let model = BulkExportModel { workout, directory in
            if workout.uuid == failed.uuid {
                throw GeoJSONExportError.noSamples
            }
            return try ExportFileWriter.write(GeoJSONExport(data: Data("{}".utf8), fileName: "one.json"), to: directory)
        }
        model.selectLoaded([selected, failed])
        await model.prepare([selected, failed])
        XCTAssertEqual(model.phase, .results)
        XCTAssertEqual(model.selectedIDs.count, 2)
        model.shareSuccessfulFiles()
        model.shareCompletionHandler()(true)
        XCTAssertTrue(model.didShareSuccessfully)
        XCTAssertTrue(model.selectedIDs.isEmpty)
        model.dismiss()
    }

    func testPreviousShareCallbackCannotClearRetrySelection() async {
        let model = successfulExportModel()
        let selected = selectionWorkout()
        model.beginSelection()
        model.selectLoaded([selected])
        await model.prepare([selected])
        var previousCloseCount = 0
        let previousCompletion = model.shareCompletionHandler { previousCloseCount += 1 }
        model.dismiss()
        // Retry the same selection without consuming the old callback or changing selection.
        await model.prepare([selected])
        previousCompletion(true)
        XCTAssertFalse(model.didShareSuccessfully)
        XCTAssertTrue(model.isSelecting)
        XCTAssertEqual(model.selectedIDs, [selected.uuid])
        XCTAssertEqual(model.phase, .sharing)
        XCTAssertEqual(previousCloseCount, 0)
        model.dismiss()
    }

    func testExportFailureCannotBeRecordedAsSuccessfulSharing() async {
        let model = BulkExportModel { _, _ in throw GeoJSONExportError.noSamples }
        let selected = selectionWorkout()
        model.selectLoaded([selected])
        await model.prepare([selected])
        model.shareCompletionHandler()(true)
        XCTAssertFalse(model.didShareSuccessfully)
        XCTAssertEqual(model.selectedIDs, [selected.uuid])
        model.dismiss()
    }

    func testShareSuccessAfterSheetDismissalStillClearsOriginalSelection() async {
        let model = successfulExportModel()
        let selected = selectionWorkout()
        model.beginSelection()
        model.selectLoaded([selected])
        await model.prepare([selected])
        let completion = model.shareCompletionHandler()
        model.dismiss()
        completion(true)
        XCTAssertTrue(model.selectedIDs.isEmpty)
        XCTAssertFalse(model.isSelecting)
        XCTAssertTrue(model.didShareSuccessfully)
    }

    func testCompletedShareExitsSelectionBeforeSheetDismissal() async throws {
        let model = successfulExportModel()
        let selected = selectionWorkout()
        model.beginSelection()
        model.selectLoaded([selected])
        await model.prepare([selected])
        let directory = try XCTUnwrap(model.directory)
        var closeCount = 0
        let completion = model.shareCompletionHandler { closeCount += 1 }
        completion(true)
        XCTAssertFalse(model.isSelecting)
        XCTAssertTrue(model.selectedIDs.isEmpty)
        XCTAssertEqual(closeCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.path))
        model.dismiss()
        completion(true)
        XCTAssertEqual(closeCount, 1)
    }

    func testLateCompletionCannotClearSelectionChangedAfterDismissal() async {
        let model = successfulExportModel()
        let first = selectionWorkout()
        let second = selectionWorkout()
        model.beginSelection()
        model.selectLoaded([first])
        await model.prepare([first])
        var closeCount = 0
        let completion = model.shareCompletionHandler { closeCount += 1 }
        model.dismiss()
        model.toggle(second)
        completion(true)
        XCTAssertTrue(model.isSelecting)
        XCTAssertEqual(model.selectedIDs, [first.uuid, second.uuid])
        XCTAssertEqual(closeCount, 0)
        model.endSelection()
        XCTAssertFalse(model.isSelecting)
    }

    func testCancelledShareClosesSheetAndPreservesSelectionMode() async {
        let model = successfulExportModel()
        let selected = selectionWorkout()
        model.beginSelection()
        model.selectLoaded([selected])
        await model.prepare([selected])
        var closeCount = 0
        let completion = model.shareCompletionHandler { closeCount += 1 }
        completion(false)
        XCTAssertTrue(model.isSelecting)
        XCTAssertEqual(model.selectedIDs, [selected.uuid])
        XCTAssertEqual(closeCount, 1)
        completion(true)
        XCTAssertTrue(model.isSelecting)
        XCTAssertEqual(closeCount, 1)
        model.dismiss()
    }

    private func successfulExportModel() -> BulkExportModel {
        BulkExportModel { _, directory in
            try ExportFileWriter.write(GeoJSONExport(data: Data("{}".utf8), fileName: "one.json"), to: directory)
        }
    }

    private func selectionWorkout() -> HKWorkout {
        HKWorkout(activityType: .running, start: Date(timeIntervalSince1970: 1_752_000_000),
                  end: Date(timeIntervalSince1970: 1_752_000_120))
    }
}

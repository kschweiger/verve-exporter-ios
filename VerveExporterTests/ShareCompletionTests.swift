import UIKit
@testable import VerveExporter
import XCTest

@MainActor
final class ShareCompletionTests: XCTestCase {
    func testNativeCompletionRequiresCompletedActivityWithoutError() async throws {
        await Task.yield()
        var outcomes: [Bool] = []
        let view = ActivityView(activityItems: ["invented test content"], onCompletion: { outcomes.append($0) })
        let controller = view.makeActivityController()
        let completion = try XCTUnwrap(controller.completionWithItemsHandler)
        let error = NSError(domain: "InventedShareError", code: 1)
        completion(nil, true, nil, nil)
        completion(nil, false, nil, nil)
        completion(nil, true, nil, error)
        completion(nil, false, nil, error)
        XCTAssertEqual(outcomes, [true, false, false, false])
    }
}

import SwiftUI

struct BulkExportSheet: View {
    let model: BulkExportModel
    var onClose: () -> Void

    var body: some View {
        switch model.phase {
        case .idle:
            EmptyView()
        case .preparing:
            VStack(spacing: 16) {
                ProgressView(value: Double(model.completedCount), total: Double(model.totalCount))
                Text("Preparing workout \(min(model.completedCount + 1, model.totalCount)) of \(model.totalCount)")
                    .font(.headline)
                Button("Cancel", role: .cancel) {
                    model.dismiss()
                    onClose()
                }
            }
            .padding()
            .interactiveDismissDisabled()
        case .sharing:
            ActivityView(activityItems: model.files, onCompletion: model.shareCompletionHandler(onCompletion: onClose))
        case .results:
            NavigationStack {
                List {
                    Section {
                        Text("\(model.files.count) prepared, \(model.failures.count) failed")
                        if let error = model.setupError {
                            Text(error)
                        }
                    }
                    ForEach(model.failures) { failure in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(failure.activity).font(.headline)
                            Text(failure.date.formatted(date: .abbreviated, time: .shortened))
                            Text(failure.message).foregroundStyle(.secondary)
                        }
                    }
                    if !model.files.isEmpty {
                        Button("Share \(model.files.count) files") { model.shareSuccessfulFiles() }
                    }
                }
                .navigationTitle("Export Results")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done", action: onClose)
                    }
                }
            }
        }
    }
}

struct BrowserRefreshModifier: ViewModifier {
    let isEnabled: Bool
    let browser: WorkoutBrowserModel

    func body(content: Content) -> some View {
        if isEnabled {
            content.refreshable { await browser.reload() }
        } else {
            content
        }
    }
}

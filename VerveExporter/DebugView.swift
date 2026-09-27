//
//  DebugView.swift
//  VerveExporter
//
//  Created by Korbinian Schweiger on 28.12.25.
//

import HealthKit
import SwiftUI

struct DebugView: View {
    let workout: HKWorkout
    let healthManager: HealthManager

    @State private var jsonContent: String = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Generating JSON...")
                } else if let error = errorMessage {
                    ContentUnavailableView {
                        Label("Generation Failed", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    }
                } else {
                    ScrollView {
                        Text(jsonContent)
                            .font(.system(.caption, design: .monospaced)) // Monospace for code
                            .padding()
                            .textSelection(.enabled) // Allows you to long-press and copy text
                    }
                }
            }
            .navigationTitle("JSON Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    // Quick Copy Button
                    Button {
                        UIPasteboard.general.string = jsonContent
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .disabled(isLoading || errorMessage != nil)
                }
            }
        }
        .task {
            await generateAndLoad()
        }
    }

    private func generateAndLoad() async {
        do {
            jsonContent = try await healthManager.generateDebugJSON(for: workout)
            isLoading = false

        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}

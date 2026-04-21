//
//  LibraryView.swift
//  surgeapp
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var store: StudyStore
    @State private var flyStatusText = "Not checked yet"
    @State private var flyIsChecking = false

    var body: some View {
        List {
            Section("Fly.io backend") {
                LabeledContent("Base URL") {
                    Text(FlyService.baseURL.host() ?? FlyService.baseURL.absoluteString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Status") {
                    HStack(spacing: 8) {
                        if flyIsChecking {
                            ProgressView()
                                .scaleEffect(0.85)
                        }
                        Text(flyStatusText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                Button {
                    Task { await checkFlyHealth() }
                } label: {
                    Label("Check connection", systemImage: "arrow.clockwise")
                }
                .disabled(flyIsChecking)
            }

            Section("Overview") {
                Label("\(store.notes.count) Notes", systemImage: "note.text")
                Label("\(store.decks.count) Decks", systemImage: "rectangle.stack")
            }

            Section("Next Steps") {
                Text("Connect cloud sync")
                Text("Import PDFs and lecture slides")
                Text("Add AI chat + citation support")
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.white)
        .task {
            await checkFlyHealth()
        }
    }

    private func checkFlyHealth() async {
        flyIsChecking = true
        flyStatusText = "Connecting…"
        defer { flyIsChecking = false }

        do {
            let health = try await FlyService.fetchHealth()
            flyStatusText = "\(health.status) · \(health.service)"
        } catch {
            flyStatusText = error.localizedDescription
        }
    }
}

#Preview {
    LibraryView()
        .environmentObject(StudyStore())
}

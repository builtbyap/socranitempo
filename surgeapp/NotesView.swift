//
//  NotesView.swift
//  surgeapp
//

import SwiftUI
import UniformTypeIdentifiers

struct NotesView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var voiceRecorder = VoiceRecorder(destination: .notes)
    @State private var showAddSheet = false
    @State private var presentedLinkMode: LinkInputMode?
    @State private var showDocumentPicker = false
    @State private var showDocumentConfirmSheet = false
    @State private var pendingDocumentURL: URL?
    @State private var isUploadingDocument = false
    @State private var selectedNote: StudyNote?
    @State private var showTranscriptionError = false

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                ForEach(Array(store.notes.enumerated()), id: \.element.id) { index, note in
                    sessionRow(note: note, index: index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedNote = note
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.white)
                        .listRowSeparator(.visible, edges: .bottom)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.removeNote(id: note.id)
                            } label: {
                                Image(systemName: "trash.fill")
                            }
                            .accessibilityLabel("Delete")
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.top, 8)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear.frame(height: 96)
            }

            if voiceRecorder.isRecording {
                RecordingPanelView(recorder: voiceRecorder) {
                    voiceRecorder.toggleRecording(store: store)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                Button {
                    showAddSheet = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.gray.opacity(0.14))
                            .frame(width: 66, height: 66)
                            .shadow(color: .black.opacity(0.12), radius: 10, y: 4)

                        Image(systemName: "plus")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel("Add recording or content")
                .padding(.bottom, 28)
                .transition(.opacity)
            }
        }
        .background(Color.white)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: voiceRecorder.isRecording)
        .onAppear {
            store.generationOutput = .notes
        }
        .onDisappear {
            voiceRecorder.stopIfRecording(store: store)
        }
        .sheet(isPresented: $showAddSheet) {
            AssistantAddOptionsSheet(
                onRecordAudio: {
                    showAddSheet = false
                    voiceRecorder.toggleRecording(store: store)
                },
                onWebsite: {
                    showAddSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        presentedLinkMode = .website
                    }
                },
                onYouTube: {
                    showAddSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        presentedLinkMode = .youtube
                    }
                },
                onUploadDocument: {
                    showAddSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        showDocumentPicker = true
                    }
                }
            )
            .environmentObject(store)
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .sheet(item: $presentedLinkMode) { mode in
            WebsiteLinkInputSheet(mode: mode)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .sheet(item: $selectedNote) { note in
            GeneratedNoteDetailSheet(note: note)
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            guard let selectedURL = try? result.get().first else { return }
            pendingDocumentURL = selectedURL
            showDocumentConfirmSheet = true
        }
        .sheet(isPresented: $showDocumentConfirmSheet, onDismiss: {
            pendingDocumentURL = nil
            isUploadingDocument = false
        }) {
            DocumentUploadConfirmSheet(
                fileURL: pendingDocumentURL,
                onCancel: {
                    showDocumentConfirmSheet = false
                },
                isSubmitting: isUploadingDocument,
                onConfirm: { fileURL in
                    guard !isUploadingDocument else { return }
                    isUploadingDocument = true
                    await store.addRecordingFromDocumentAndGenerateNotes(fileURL: fileURL)
                    isUploadingDocument = false
                    if store.transcriptionError == nil {
                        showDocumentConfirmSheet = false
                    }
                }
            )
            .environmentObject(store)
            .presentationDetents([.height(320)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
        .alert("Microphone access needed", isPresented: Binding(
            get: { voiceRecorder.permissionDenied },
            set: { if !$0 { voiceRecorder.dismissPermissionAlert() } }
        )) {
            Button("OK", role: .cancel) {
                voiceRecorder.dismissPermissionAlert()
            }
        } message: {
            Text("Enable microphone access in Settings to record meeting and lecture audio.")
        }
        .onChange(of: store.transcriptionError) { _, newValue in
            showTranscriptionError = (newValue != nil)
        }
        .alert("Please try again", isPresented: $showTranscriptionError) {
            Button("OK", role: .cancel) {
                store.transcriptionError = nil
            }
        } message: {
            Text(store.transcriptionError ?? StudyStore.generationFailureTryAgainMessage)
        }
    }

    private func sessionRow(note: StudyNote, index: Int) -> some View {
        let sourceIcon = sourceIcon(for: note)

        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: sourceIcon.name)
                        .font(.system(size: 20))
                        .foregroundStyle(sourceIcon.color)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title.isEmpty ? "Untitled session" : note.title)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(1)

                Text(formattedDate(note.updatedAt))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
            }

            Spacer()
        }
        .padding(.vertical, 15)
    }

    private func sourceIcon(for note: StudyNote) -> (name: String, color: Color) {
        let lowerTags = Set(note.tags.map { $0.lowercased() })
        let title = note.title.lowercased()
        let body = note.body.lowercased()

        if note.audioFilename != nil || lowerTags.contains("transcript") || lowerTags.contains("voice") {
            return ("waveform", .gray)
        }

        if lowerTags.contains("document")
            || title.contains(".pdf")
            || body.contains(".pdf")
            || body.contains("uploaded document") {
            return ("doc.text.fill", Color.red.opacity(0.85))
        }

        if lowerTags.contains("youtube")
            || title.contains("youtube")
            || body.contains("youtube.com")
            || body.contains("youtu.be") {
            return ("play.rectangle.fill", Color.red.opacity(0.85))
        }

        if lowerTags.contains("website") || lowerTags.contains("web") {
            return ("globe", Color.blue.opacity(0.85))
        }

        return ("waveform", .gray)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

}

// Keeps previews and empty states close to the intended look.
private extension StudyStore {
    static var notesMockForDesign: [StudyNote] {
        [
            StudyNote(title: "Cluely Demo with CEO Roy Lee", body: "", tags: [], updatedAt: .now),
            StudyNote(title: "Untitled session", body: "", tags: [], updatedAt: .now.addingTimeInterval(-172_800)),
            StudyNote(title: "Untitled session", body: "", tags: [], updatedAt: .now.addingTimeInterval(-8_640_000)),
            StudyNote(title: "Untitled session", body: "", tags: [], updatedAt: .now.addingTimeInterval(-12_960_000))
        ]
    }
}

#Preview("Cluely style") {
    NotesView()
        .environmentObject(StudyStore(notes: StudyStore.notesMockForDesign, decks: StudyStore.sampleDecks))
}

#Preview("Default") {
    NotesView()
        .environmentObject(StudyStore())
}

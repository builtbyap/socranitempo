//
//  AssistantView.swift
//  surgeapp
//

import SwiftUI
import SuperwallKit
import UniformTypeIdentifiers
import UIKit
import AVFoundation
import Photos

struct AssistantView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var auth: AuthSessionManager
    @StateObject private var voiceRecorder = VoiceRecorder(destination: .assistant)
    @State private var showAddSheet = false
    @State private var showLinkSheet = false
    @State private var showDocumentPicker = false
    @State private var showDocumentConfirmSheet = false
    @State private var pendingDocumentURL: URL?
    @State private var isUploadingDocument = false
    @State private var showTranscriptionError = false
    @State private var selectedGeneratedNote: StudyNote?
    @State private var isSwitchBarVisible = false
    @State private var recordDragX: CGFloat = 0
    @State private var linkMode: LinkInputMode = .website
    @State private var showCameraCapture = false
    @State private var showCameraUnavailableAlert = false
    @State private var showCameraPermissionDenied = false
    @State private var isSolvingHomework = false

    var body: some View {
        ZStack(alignment: .bottom) {
            List {
                ForEach(Array(store.recordings.enumerated()), id: \.element.id) { index, recording in
                    recordingRow(recording: recording, index: index)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            openGeneratedNote(for: recording)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        .listRowBackground(Color.white)
                        .listRowSeparator(.visible, edges: .bottom)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.removeRecording(id: recording.id)
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
                recordingControls
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
                    linkMode = .website
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showLinkSheet = true
                    }
                },
                onYouTube: {
                    showAddSheet = false
                    linkMode = .youtube
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        showLinkSheet = true
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
        .sheet(isPresented: $showLinkSheet) {
            WebsiteLinkInputSheet(mode: linkMode)
                .environmentObject(store)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(24)
        }
        .sheet(isPresented: $showCameraCapture) {
            CameraCaptureSheet(isPresented: $showCameraCapture) { image in
                Task {
                    await solveHomeworkFromImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .sheet(item: $selectedGeneratedNote) { note in
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
            Button("Open Settings") {
                voiceRecorder.dismissPermissionAlert()
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                voiceRecorder.dismissPermissionAlert()
            }
        } message: {
            Text("Enable microphone access in Settings to record meeting and lecture audio.")
        }
        .onChange(of: store.transcriptionError) { _, newValue in
            showTranscriptionError = (newValue != nil)
        }
        .alert("Could not generate notes", isPresented: $showTranscriptionError) {
            Button("OK", role: .cancel) {
                store.transcriptionError = nil
            }
        } message: {
            Text(store.transcriptionError ?? "Please try again.")
        }
        .alert("Camera unavailable", isPresented: $showCameraUnavailableAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This device does not have an available camera.")
        }
        .alert("Camera access needed", isPresented: $showCameraPermissionDenied) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enable camera access in Settings to capture homework problems.")
        }
        .overlay {
            if isSolvingHomework {
                ZStack {
                    Color.black.opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(.white)
                        Text("Solving homework...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
    }

    // MARK: - Recording button + camera swipe

    private var recordingControls: some View {
        let slideProgress = max(0, min(recordDragX / 54, 1))
        let recordScale = 1 - (0.28 * slideProgress)
        let cameraSize: CGFloat = 58 + (6 * slideProgress)

        return ZStack(alignment: .leading) {
            // Camera pill (appears behind recording button on hold)
            Capsule(style: .continuous)
                .fill(Color.white)
                .frame(width: 96, height: 72)
                .overlay {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: cameraSize, height: cameraSize)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(.gray)
                        )
                }
                .offset(x: 130)
                .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                .opacity(isSwitchBarVisible ? 1 : 0)
                .scaleEffect(isSwitchBarVisible ? 1 : 0.92, anchor: .leading)

            // Recording button
            ZStack {
                Circle()
                    .fill(Color.red)
                    .frame(width: 66, height: 66)

                if voiceRecorder.isRecording {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 22, height: 22)
                } else {
                    Image(systemName: "waveform")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .scaleEffect(recordScale)
            .offset(x: 77)
            .gesture(holdAndSlideGesture)
            .accessibilityLabel(voiceRecorder.isRecording ? "Stop recording" : "Record audio")
        }
        .frame(width: 236, height: 72, alignment: .leading)
        .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isSwitchBarVisible)
        .animation(.interactiveSpring(response: 0.18, dampingFraction: 0.9), value: recordDragX)
    }

    private var holdAndSlideGesture: some Gesture {
        // Simple tap (short press) → toggle recording
        // Long press + drag right → reveal camera, slide to activate
        LongPressGesture(minimumDuration: 0.2)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { value in
                switch value {
                case .first(true):
                    // Long press recognized — show the switch bar
                    if !voiceRecorder.isRecording {
                        isSwitchBarVisible = true
                    }
                case .second(true, let drag):
                    // Dragging after long press
                    if let drag {
                        recordDragX = min(max(drag.translation.width, 0), 54)
                    }
                default:
                    break
                }
            }
            .onEnded { value in
                if case .second(true, let drag) = value {
                    let shouldOpenCamera = (drag?.translation.width ?? 0) > 32
                    recordDragX = 0
                    isSwitchBarVisible = false
                    if shouldOpenCamera {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            requestCameraAccess()
                        }
                    }
                } else {
                    // Long press completed but no drag → reset
                    recordDragX = 0
                    isSwitchBarVisible = false
                }
            }
            .simultaneously(with:
                TapGesture()
                    .onEnded {
                        if !isSwitchBarVisible {
                            voiceRecorder.toggleRecording(store: store)
                        }
                    }
            )
    }

    private func requestCameraAccess() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showCameraUnavailableAlert = true
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            showCameraCapture = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCameraCapture = true
                    } else {
                        showCameraPermissionDenied = true
                    }
                }
            }
        case .denied, .restricted:
            showCameraPermissionDenied = true
        @unknown default:
            showCameraUnavailableAlert = true
        }
    }

    private func recordingRow(recording: RecordingItem, index: Int) -> some View {
        let duration = durationLabel(for: recording, index: index)

        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.14))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "waveform")
                        .font(.system(size: 20))
                        .foregroundStyle(.gray)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.title)
                    .font(.system(size: 18, weight: .bold))
                    .lineLimit(2)

                Text("\(recording.kind.label) · \(formattedDate(recording.updatedAt))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray)
            }

            Spacer()

            if let sourceURL = recording.sourceURL {
                let isFile = sourceURL.lowercased().hasPrefix("file://")
                Text(isFile ? "File" : "Link")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.blue.opacity(0.85))
            } else {
                Text(duration)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.gray.opacity(0.8))
            }

            if recording.generatedNoteID != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .padding(.vertical, 15)
    }

    private func openGeneratedNote(for recording: RecordingItem) {
        guard let noteID = recording.generatedNoteID,
              let note = store.notes.first(where: { $0.id == noteID })
        else { return }
        selectedGeneratedNote = note
    }

    private func durationLabel(for recording: RecordingItem, index: Int) -> String {
        if recording.audioFilename != nil {
            if let part = recording.title.split(separator: "·").last {
                return String(part).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return mockDuration(for: index)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: date)
    }

    private func mockDuration(for index: Int) -> String {
        let durations = ["45:12", "12:03", "58:40", "06:22", "33:01"]
        return durations[index % durations.count]
    }

    private func solveHomeworkFromImage(_ image: UIImage) async {
        guard FreeTierUsageTracker.shared.canAnalyzeHomeworkImage(
            subscriptionStatus: auth.subscriptionStatusFromDB,
            subscriptionType: auth.subscriptionTypeFromDB
        ) else {
            registerSuperwallPlacement(SuperwallPlacements.freeTierLimit)
            return
        }

        isSolvingHomework = true

        let imageURL: URL? = await Task.detached(priority: .userInitiated) { () -> URL? in
            guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("homework_\(UUID().uuidString).jpg")
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }.value

        guard let imageURL else {
            isSolvingHomework = false
            store.transcriptionError = "Could not prepare image for upload."
            showTranscriptionError = true
            return
        }

        defer {
            isSolvingHomework = false
            try? FileManager.default.removeItem(at: imageURL)
        }

        do {
            let result = try await FlyService.solveHomeworkFromImage(fileURL: imageURL)
            let cleanedTitle = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let solutionTitle = (cleanedTitle?.isEmpty == false) ? cleanedTitle! : "Homework solution"
            let solutionNote = StudyNote(
                title: solutionTitle,
                body: result.notes ?? "",
                tags: ["homework", "solver"]
            )
            FreeTierUsageTracker.shared.recordSuccessfulHomeworkImageAnalysis(
                subscriptionStatus: auth.subscriptionStatusFromDB,
                subscriptionType: auth.subscriptionTypeFromDB
            )
            selectedGeneratedNote = solutionNote
        } catch {
            store.transcriptionError = error.localizedDescription
            showTranscriptionError = true
        }
    }
}

private struct CameraCaptureSheet: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onImagePicked: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        picker.cameraOverlayView = context.coordinator.makeCameraOverlay()
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isPresented: $isPresented, onImagePicked: onImagePicked)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let isPresented: Binding<Bool>
        private let onImagePicked: (UIImage) -> Void
        private weak var picker: UIImagePickerController?

        init(isPresented: Binding<Bool>, onImagePicked: @escaping (UIImage) -> Void) {
            self.isPresented = isPresented
            self.onImagePicked = onImagePicked
        }

        func makeCameraOverlay() -> UIView {
            let overlay = UIView(frame: UIScreen.main.bounds)
            overlay.backgroundColor = .clear
            overlay.isUserInteractionEnabled = true

            let photosButton = UIButton(type: .system)
            photosButton.translatesAutoresizingMaskIntoConstraints = false
            photosButton.backgroundColor = UIColor(white: 0.1, alpha: 0.45)
            photosButton.tintColor = .white
            photosButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
            photosButton.layer.cornerRadius = 32
            photosButton.clipsToBounds = true
            photosButton.addTarget(self, action: #selector(openPhotoLibrary), for: .touchUpInside)

            overlay.addSubview(photosButton)
            NSLayoutConstraint.activate([
                photosButton.widthAnchor.constraint(equalToConstant: 64),
                photosButton.heightAnchor.constraint(equalToConstant: 64),
                photosButton.leadingAnchor.constraint(equalTo: overlay.leadingAnchor, constant: 26),
                photosButton.bottomAnchor.constraint(equalTo: overlay.bottomAnchor, constant: -156)
            ])
            return overlay
        }

        @objc private func openPhotoLibrary() {
            guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary),
                  let picker
            else { return }

            let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
            switch status {
            case .authorized, .limited:
                picker.sourceType = .photoLibrary
                picker.cameraOverlayView = nil
            case .notDetermined:
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] newStatus in
                    DispatchQueue.main.async {
                        if newStatus == .authorized || newStatus == .limited {
                            picker.sourceType = .photoLibrary
                            picker.cameraOverlayView = nil
                        } else {
                            self?.showPhotoAccessDeniedAlert(on: picker)
                        }
                    }
                }
            case .denied, .restricted:
                showPhotoAccessDeniedAlert(on: picker)
            @unknown default:
                break
            }
        }

        private func showPhotoAccessDeniedAlert(on viewController: UIViewController) {
            let alert = UIAlertController(
                title: "Photo access needed",
                message: "Enable photo library access in Settings to select images for homework solving.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            viewController.present(alert, animated: true)
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            self.picker = picker
            let image = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            DispatchQueue.main.async {
                if let image {
                    self.onImagePicked(image)
                }
                self.isPresented.wrappedValue = false
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            self.picker = picker
            DispatchQueue.main.async {
                self.isPresented.wrappedValue = false
            }
        }

        func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController, animated: Bool) {
            if let picker = navigationController as? UIImagePickerController {
                self.picker = picker
                if picker.sourceType == .camera {
                    picker.cameraOverlayView = makeCameraOverlay()
                }
            }
        }
    }
}

// MARK: - Turbo AI–style note detail sheet

struct GeneratedNoteDetailSheet: View {
    let note: StudyNote

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TurboMarkdownView(markdown: note.body)
                }
                .padding(20)
            }
            .background(Color.white)
            .navigationTitle(note.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct TurboMarkdownView: View {
    let markdown: String

    var body: some View {
        let blocks = Self.parse(markdown)
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .h2(let text):
            styledHeading(text, font: .title2)
                .padding(.top, 20)
                .padding(.bottom, 8)

        case .h3(let text):
            styledHeading(text, font: .headline)
                .padding(.top, 16)
                .padding(.bottom, 6)

        case .h4(let text):
            styledHeading(text, font: .subheadline)
                .foregroundStyle(Color(red: 0.45, green: 0.32, blue: 0.88))
                .padding(.top, 12)
                .padding(.bottom, 4)

        case .bullet(let text):
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                richText(text)
                    .font(.body)
            }
            .padding(.vertical, 3)
            .padding(.leading, 4)

        case .numbered(let num, let text):
            HStack(alignment: .top, spacing: 8) {
                Text("\(num).")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(red: 0.45, green: 0.32, blue: 0.88))
                    .frame(width: 22, alignment: .trailing)
                richText(text)
                    .font(.body)
            }
            .padding(.vertical, 3)

        case .blockquote(let text):
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.45, green: 0.32, blue: 0.88).opacity(0.6))
                    .frame(width: 3)
                richText(text)
                    .font(.body)
                    .padding(.leading, 12)
                    .padding(.vertical, 8)
            }
            .padding(.vertical, 4)

        case .divider:
            Divider()
                .padding(.vertical, 12)

        case .table(let headers, let rows):
            TableBlockView(headers: headers, rows: rows, richText: richText)
                .padding(.vertical, 8)

        case .paragraph(let text):
            richText(text)
                .font(.body)
                .padding(.vertical, 4)
        }
    }

    private func styledHeading(_ raw: String, font: Font) -> some View {
        Text(Self.convertFractions(Self.convertSuperSubscripts(raw)))
            .font(font.weight(.bold))
            .foregroundStyle(.primary)
    }

    private func richText(_ raw: String) -> Text {
        let colorLabels: [(String, Color)] = [
            ("Tip:", Color(red: 0.45, green: 0.32, blue: 0.88)),
            ("Key Insight:", Color(red: 0.45, green: 0.32, blue: 0.88)),
            ("Key insight:", Color(red: 0.45, green: 0.32, blue: 0.88)),
            ("Warning:", .orange),
            ("Note:", Color(red: 0.45, green: 0.32, blue: 0.88)),
            ("Definition:", Color(red: 0.45, green: 0.32, blue: 0.88)),
            ("Important:", .red)
        ]
        let matchedLabel = colorLabels.first { raw.hasPrefix($0.0) }
        if let (label, color) = matchedLabel {
            let rest = String(raw.dropFirst(label.count)).trimmingCharacters(in: .whitespaces)
            return (
                Text(label)
                    .fontWeight(.bold)
                    .foregroundColor(color)
                + Text(" ")
                + inlineFormatted(rest)
            )
        } else {
            return inlineFormatted(raw)
        }
    }

    private func inlineFormatted(_ raw: String) -> Text {
        let preprocessed = Self.convertFractions(Self.convertSuperSubscripts(raw))
        var result = Text("")
        var remaining = preprocessed[preprocessed.startIndex...]

        while !remaining.isEmpty {
            if let boldRange = remaining.range(of: #"\*\*(.+?)\*\*"#, options: .regularExpression) {
                let before = remaining[remaining.startIndex..<boldRange.lowerBound]
                if !before.isEmpty { result = result + Text(String(before)) }
                let inner = String(remaining[boldRange]).dropFirst(2).dropLast(2)
                result = result + Text(String(inner)).bold()
                remaining = remaining[boldRange.upperBound...]
            } else if let italicRange = remaining.range(of: #"\*(.+?)\*"#, options: .regularExpression) {
                let before = remaining[remaining.startIndex..<italicRange.lowerBound]
                if !before.isEmpty { result = result + Text(String(before)) }
                let inner = String(remaining[italicRange]).dropFirst(1).dropLast(1)
                result = result + Text(String(inner)).italic()
                remaining = remaining[italicRange.upperBound...]
            } else {
                result = result + Text(String(remaining))
                break
            }
        }
        return result
    }

    private static let superscriptMap: [Character: String] = [
        "0": "\u{2070}", "1": "\u{00B9}", "2": "\u{00B2}", "3": "\u{00B3}",
        "4": "\u{2074}", "5": "\u{2075}", "6": "\u{2076}", "7": "\u{2077}",
        "8": "\u{2078}", "9": "\u{2079}", "+": "\u{207A}", "-": "\u{207B}",
        "=": "\u{207C}", "(": "\u{207D}", ")": "\u{207E}", "n": "\u{207F}",
        "i": "\u{2071}", "a": "\u{1D43}", "b": "\u{1D47}", "c": "\u{1D9C}",
        "d": "\u{1D48}", "e": "\u{1D49}", "f": "\u{1DA0}", "g": "\u{1D4D}",
        "h": "\u{02B0}", "j": "\u{02B2}", "k": "\u{1D4F}", "l": "\u{02E1}",
        "m": "\u{1D50}", "o": "\u{1D52}", "p": "\u{1D56}", "r": "\u{02B3}",
        "s": "\u{02E2}", "t": "\u{1D57}", "u": "\u{1D58}", "v": "\u{1D5B}",
        "w": "\u{02B7}", "x": "\u{02E3}", "y": "\u{02B8}", "z": "\u{1DBB}",
        "N": "\u{1D3A}", "T": "\u{1D40}"
    ]

    private static let subscriptMap: [Character: String] = [
        "0": "\u{2080}", "1": "\u{2081}", "2": "\u{2082}", "3": "\u{2083}",
        "4": "\u{2084}", "5": "\u{2085}", "6": "\u{2086}", "7": "\u{2087}",
        "8": "\u{2088}", "9": "\u{2089}", "+": "\u{208A}", "-": "\u{208B}",
        "=": "\u{208C}", "(": "\u{208D}", ")": "\u{208E}",
        "a": "\u{2090}", "e": "\u{2091}", "h": "\u{2095}", "i": "\u{1D62}",
        "j": "\u{2C7C}", "k": "\u{2096}", "l": "\u{2097}", "m": "\u{2098}",
        "n": "\u{2099}", "o": "\u{2092}", "p": "\u{209A}", "r": "\u{1D63}",
        "s": "\u{209B}", "t": "\u{209C}", "u": "\u{1D64}", "v": "\u{1D65}",
        "x": "\u{2093}"
    ]

    /// Converts `digit(s)/digit(s)` into Unicode stacked fractions: superscript numerator + fraction slash (⁄) + subscript denominator.
    static func convertFractions(_ text: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"(\d+)\s*/\s*(\d+)"#) else { return text }
        let ns = text as NSString
        var out = ""
        var cursor = 0
        for match in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            out += ns.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let num = ns.substring(with: match.range(at: 1))
            let den = ns.substring(with: match.range(at: 2))
            let sup = num.map { superscriptMap[$0] ?? String($0) }.joined()
            let sub = den.map { subscriptMap[$0] ?? String($0) }.joined()
            out += sup + "\u{2044}" + sub
            cursor = match.range.location + match.range.length
        }
        out += ns.substring(from: cursor)
        return out
    }

    /// Converts `^{...}`, `^(...)`, `^x`, `_{...}`, `_(...)`, `_x` into Unicode super/subscripts.
    static func convertSuperSubscripts(_ text: String) -> String {
        var out = ""
        var i = text.startIndex
        while i < text.endIndex {
            let ch = text[i]
            if (ch == "^" || ch == "_") {
                let map = ch == "^" ? superscriptMap : subscriptMap
                let next = text.index(after: i)
                if next < text.endIndex {
                    // Grouped with braces: ^{a+b} or _{n-1}
                    if text[next] == "{" {
                        if let close = text[next...].firstIndex(of: "}"), close > text.index(after: next) {
                            let inner = text[text.index(after: next)..<close]
                            out += inner.map { map[$0] ?? String($0) }.joined()
                            i = text.index(after: close)
                            continue
                        }
                    }
                    // Grouped with parentheses: ^(a+b) or _(n-1)
                    if text[next] == "(" {
                        if let close = text[next...].firstIndex(of: ")"), close > text.index(after: next) {
                            let inner = text[text.index(after: next)..<close]
                            out += inner.map { map[$0] ?? String($0) }.joined()
                            i = text.index(after: close)
                            continue
                        }
                    }
                    // Run of mappable characters: ^abc or _12 (greedy)
                    var run = ""
                    var j = next
                    while j < text.endIndex, map[text[j]] != nil {
                        run += map[text[j]]!
                        j = text.index(after: j)
                    }
                    if !run.isEmpty {
                        out += run
                        i = j
                        continue
                    }
                }
                out.append(ch)
                i = text.index(after: i)
            } else {
                out.append(ch)
                i = text.index(after: i)
            }
        }
        return out
    }

    // MARK: - Markdown line parser

    enum MarkdownBlock {
        case h2(String)
        case h3(String)
        case h4(String)
        case bullet(String)
        case numbered(Int, String)
        case blockquote(String)
        case divider
        case table(headers: [String], rows: [[String]])
        case paragraph(String)
    }

    private static func isTableRow(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("|") && t.hasSuffix("|") && t.count > 2
    }

    private static func isSeparatorRow(_ line: String) -> Bool {
        let t = line.trimmingCharacters(in: .whitespaces)
        guard t.hasPrefix("|") && t.hasSuffix("|") else { return false }
        let inner = t.dropFirst().dropLast()
        return inner.allSatisfy { $0 == "-" || $0 == "|" || $0 == ":" || $0 == " " }
    }

    private static func parseCells(_ line: String) -> [String] {
        var t = line.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t = String(t.dropFirst()) }
        if t.hasSuffix("|") { t = String(t.dropLast()) }
        return t.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
    }

    static func parse(_ raw: String) -> [MarkdownBlock] {
        let lines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        var blocks: [MarkdownBlock] = []
        var pendingBlockquote: [String] = []
        var idx = 0

        func flushBlockquote() {
            if !pendingBlockquote.isEmpty {
                blocks.append(.blockquote(pendingBlockquote.joined(separator: " ")))
                pendingBlockquote.removeAll()
            }
        }

        while idx < lines.count {
            let trimmed = lines[idx].trimmingCharacters(in: .whitespaces)

            // Table detection: header row followed by separator row
            if isTableRow(trimmed),
               idx + 1 < lines.count,
               isSeparatorRow(lines[idx + 1]) {
                flushBlockquote()
                let headers = parseCells(trimmed)
                idx += 2 // skip header + separator
                var rows: [[String]] = []
                while idx < lines.count, isTableRow(lines[idx]) {
                    let cells = parseCells(lines[idx])
                    rows.append(cells)
                    idx += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }

            if trimmed.hasPrefix("#### ") {
                flushBlockquote()
                blocks.append(.h4(String(trimmed.dropFirst(5))))
            } else if trimmed.hasPrefix("### ") {
                flushBlockquote()
                blocks.append(.h3(String(trimmed.dropFirst(4))))
            } else if trimmed.hasPrefix("## ") {
                flushBlockquote()
                blocks.append(.h2(String(trimmed.dropFirst(3))))
            } else if trimmed.hasPrefix("# ") {
                flushBlockquote()
                blocks.append(.h2(String(trimmed.dropFirst(2))))
            } else if trimmed.hasPrefix("> ") {
                pendingBlockquote.append(String(trimmed.dropFirst(2)))
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                flushBlockquote()
                let content = String(trimmed.dropFirst(2))
                blocks.append(.bullet(content))
            } else if let match = trimmed.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
                flushBlockquote()
                let numStr = trimmed[trimmed.startIndex..<match.upperBound]
                    .trimmingCharacters(in: .whitespaces)
                    .replacingOccurrences(of: ".", with: "")
                    .trimmingCharacters(in: .whitespaces)
                let num = Int(numStr) ?? 0
                let content = String(trimmed[match.upperBound...])
                blocks.append(.numbered(num, content))
            } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushBlockquote()
                blocks.append(.divider)
            } else if trimmed.isEmpty {
                flushBlockquote()
            } else {
                flushBlockquote()
                blocks.append(.paragraph(trimmed))
            }
            idx += 1
        }
        flushBlockquote()
        return blocks
    }
}

// MARK: - Table rendering

private struct TableBlockView: View {
    let headers: [String]
    let rows: [[String]]
    let richText: (String) -> Text

    private let accentColor = Color(red: 0.30, green: 0.55, blue: 0.52)

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                ForEach(Array(headers.enumerated()), id: \.offset) { colIdx, header in
                    richText(header)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(accentColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    if colIdx < headers.count - 1 {
                        Divider()
                    }
                }
            }
            .background(Color(.systemGray6))

            Divider()

            // Data rows
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIdx, row in
                HStack(spacing: 0) {
                    ForEach(Array(row.prefix(headers.count).enumerated()), id: \.offset) { colIdx, cell in
                        richText(cell)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                        if colIdx < headers.count - 1 {
                            Divider()
                        }
                    }
                }
                .background(rowIdx % 2 == 0 ? Color.clear : Color(.systemGray6).opacity(0.5))

                if rowIdx < rows.count - 1 {
                    Divider()
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// MARK: - Document upload confirmation

struct DocumentUploadConfirmSheet: View {
    @EnvironmentObject private var store: StudyStore
    let fileURL: URL?
    let onCancel: () -> Void
    let isSubmitting: Bool
    let onConfirm: (URL) async -> Void

    private var generateButtonTitle: String {
        switch store.generationOutput {
        case .notes: return "Generate Notes"
        case .flashcards: return "Generate Flashcards"
        case .quiz: return "Generate Quiz"
        }
    }

    var body: some View {
        VStack(spacing: 18) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.45, green: 0.32, blue: 0.88))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                )

            Text(fileURL?.lastPathComponent ?? "Selected file")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Button {
                guard let fileURL else { return }
                Task { @MainActor in
                    await onConfirm(fileURL)
                }
            } label: {
                Group {
                    if isSubmitting {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.white)
                            Text("Generating...")
                        }
                    } else {
                        Text(generateButtonTitle)
                    }
                }
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    Color(red: 0.08, green: 0.26, blue: 0.52),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .allowsHitTesting(fileURL != nil && !isSubmitting)

            Button("Cancel", role: .cancel, action: onCancel)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .disabled(isSubmitting)
        }
        .padding(.horizontal, 24)
        .padding(.top, 18)
        .padding(.bottom, 24)
    }
}

// MARK: - YouTube-style link icon (add sheet + URL sheet)

private struct YouTubeStyleLinkIcon: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * size / 44, style: .continuous)
                .fill(Color(red: 0.9, green: 0.15, blue: 0.12))
                .frame(width: size, height: size)
            Image(systemName: "play.fill")
                .font(.system(size: 16 * size / 44, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: 1 * size / 44)
        }
    }
}

// MARK: - Add options bottom sheet

struct AssistantAddOptionsSheet: View {
    @EnvironmentObject private var store: StudyStore
    @State private var isRecentFlashcardsExpanded = false
    @State private var isRecentQuizzesExpanded = false

    let onRecordAudio: () -> Void
    let onWebsite: () -> Void
    let onYouTube: () -> Void
    let onUploadDocument: () -> Void
    /// Study tab (flashcards flow): open a deck the user already generated.
    let onSelectRecentDeck: ((StudyDeck) -> Void)?
    /// Study tab (quiz flow): open a quiz the user already generated.
    let onSelectRecentQuiz: ((StudyQuiz) -> Void)?

    init(
        onRecordAudio: @escaping () -> Void,
        onWebsite: @escaping () -> Void,
        onYouTube: @escaping () -> Void,
        onUploadDocument: @escaping () -> Void,
        onSelectRecentDeck: ((StudyDeck) -> Void)? = nil,
        onSelectRecentQuiz: ((StudyQuiz) -> Void)? = nil
    ) {
        self.onRecordAudio = onRecordAudio
        self.onWebsite = onWebsite
        self.onYouTube = onYouTube
        self.onUploadDocument = onUploadDocument
        self.onSelectRecentDeck = onSelectRecentDeck
        self.onSelectRecentQuiz = onSelectRecentQuiz
    }

    private let cardShadow = Color.black.opacity(0.08)
    /// Add-sheet rows: larger tap targets and room for multiline titles (Study flashcards / quiz).
    private let addSheetIconSize: CGFloat = 48
    private let addSheetRowSpacing: CGFloat = 14
    private let addSheetRowPadding = EdgeInsets(top: 16, leading: 18, bottom: 16, trailing: 16)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: addSheetRowSpacing) {
            if store.generationOutput == .flashcards {
                recentFlashcardsSection
            }

            if store.generationOutput == .quiz {
                recentQuizzesSection
            }

            optionButton(
                title: "Record audio",
                subtitle: nil,
                action: onRecordAudio
            ) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.45, green: 0.32, blue: 0.88))
                        .frame(width: addSheetIconSize, height: addSheetIconSize)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }

            optionButton(
                title: "Import from website",
                subtitle: nil,
                action: onWebsite
            ) {
                WebsiteGlobeIcon(size: addSheetIconSize)
            }

            optionButton(
                title: "Add a YouTube link",
                subtitle: nil,
                action: onYouTube
            ) {
                YouTubeStyleLinkIcon(size: addSheetIconSize)
            }

            optionButton(
                title: "Upload document",
                subtitle: "Any PDF, DOCX, PPT, TXT, etc!",
                action: onUploadDocument
            ) {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color(red: 0.45, green: 0.32, blue: 0.88))
                        .frame(width: addSheetIconSize, height: addSheetIconSize)
                    Text("DOC")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundStyle(.white)
                        .padding(.bottom, 5)
                }
            }
            }
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, 14)
        .padding(.top, 10)
        .padding(.bottom, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.96, green: 0.96, blue: 0.97))
        .onAppear {
            isRecentFlashcardsExpanded = false
            isRecentQuizzesExpanded = false
        }
    }

    private var recentQuizzesSection: some View {
        VStack(alignment: .leading, spacing: addSheetRowSpacing) {
            if store.quizzes.isEmpty {
                recentQuizzesEmptyRow
            } else if store.quizzes.count == 1, let only = store.quizzes.first {
                optionButton(
                    title: "Recent Quizzes",
                    subtitle: "\(only.questions.count) questions · \(only.topic)",
                    action: { onSelectRecentQuiz?(only) }
                ) {
                    recentQuizzesIcon
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRecentQuizzesExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        recentQuizzesIcon
                            .frame(width: addSheetIconSize, height: addSheetIconSize)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recent Quizzes")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(store.quizzes.count) quizzes · Choose one to take")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.gray.opacity(0.45))
                            .rotationEffect(.degrees(isRecentQuizzesExpanded ? 180 : 0))
                            .padding(.top, 4)
                    }
                    .padding(addSheetRowPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: cardShadow, radius: 10, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)

                if isRecentQuizzesExpanded {
                    ForEach(store.quizzes) { quiz in
                        Button {
                            onSelectRecentQuiz?(quiz)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(quiz.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(quiz.questions.count) questions · \(quiz.topic)")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 6)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.gray.opacity(0.45))
                                    .padding(.top, 2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(white: 0.97))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentQuizzesEmptyRow: some View {
        HStack(alignment: .top, spacing: 14) {
            recentQuizzesIcon
                .frame(width: addSheetIconSize, height: addSheetIconSize)

            VStack(alignment: .leading, spacing: 6) {
                Text("Recent Quizzes")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.55))
                    .multilineTextAlignment(.leading)
                Text("No quizzes yet — generate below")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(addSheetRowPadding)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: cardShadow, radius: 10, x: 0, y: 4)
        )
    }

    private var recentQuizzesIcon: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.18, green: 0.7, blue: 0.55).opacity(0.18))
                .frame(width: addSheetIconSize, height: addSheetIconSize)
            Image(systemName: "checklist")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.18, green: 0.7, blue: 0.55))
        }
    }

    private var recentFlashcardsSection: some View {
        VStack(alignment: .leading, spacing: addSheetRowSpacing) {
            if store.decks.isEmpty {
                recentFlashcardsEmptyRow
            } else if store.decks.count == 1, let only = store.decks.first {
                optionButton(
                    title: "Recent Flashcards",
                    subtitle: "\(only.cards.count) cards · \(only.topic)",
                    action: { onSelectRecentDeck?(only) }
                ) {
                    recentFlashcardsIcon
                }
            } else {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isRecentFlashcardsExpanded.toggle()
                    }
                } label: {
                    HStack(alignment: .top, spacing: 14) {
                        recentFlashcardsIcon
                            .frame(width: addSheetIconSize, height: addSheetIconSize)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recent Flashcards")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(store.decks.count) decks · Choose one to study")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Color.gray.opacity(0.45))
                            .rotationEffect(.degrees(isRecentFlashcardsExpanded ? 180 : 0))
                            .padding(.top, 4)
                    }
                    .padding(addSheetRowPadding)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: cardShadow, radius: 10, x: 0, y: 4)
                    )
                }
                .buttonStyle(.plain)

                if isRecentFlashcardsExpanded {
                    ForEach(store.decks) { deck in
                        Button {
                            onSelectRecentDeck?(deck)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(deck.title)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Text("\(deck.cards.count) cards · \(deck.topic)")
                                        .font(.system(size: 13, weight: .regular))
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 6)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.gray.opacity(0.45))
                                    .padding(.top, 2)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(white: 0.97))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var recentFlashcardsEmptyRow: some View {
        HStack(alignment: .top, spacing: 14) {
            recentFlashcardsIcon
                .frame(width: addSheetIconSize, height: addSheetIconSize)

            VStack(alignment: .leading, spacing: 6) {
                Text("Recent Flashcards")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.primary.opacity(0.55))
                    .multilineTextAlignment(.leading)
                Text("No decks yet — generate below")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)
        }
        .padding(addSheetRowPadding)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .shadow(color: cardShadow, radius: 10, x: 0, y: 4)
        )
    }

    private var recentFlashcardsIcon: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.55, green: 0.35, blue: 0.85).opacity(0.18))
                .frame(width: addSheetIconSize, height: addSheetIconSize)
            Image(systemName: "rectangle.on.rectangle.angled")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(red: 0.55, green: 0.35, blue: 0.85))
        }
    }

    private func optionButton(
        title: String,
        subtitle: String?,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> some View
    ) -> some View {
        Button(action: action) {
            HStack(alignment: subtitle == nil ? .center : .top, spacing: 14) {
                icon()
                    .frame(width: addSheetIconSize, height: addSheetIconSize)

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.gray.opacity(0.45))
            }
            .padding(addSheetRowPadding)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: cardShadow, radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Website / YouTube URL (Turbo-style bar)

enum LinkInputMode {
    case website
    case youtube

    var title: String {
        switch self {
        case .website: return "Paste a website link"
        case .youtube: return "Paste a YouTube link"
        }
    }

    var placeholder: String {
        switch self {
        case .website: return "https://example.com/article"
        case .youtube: return "https://youtube.com/watch?v=…"
        }
    }
}

struct WebsiteLinkInputSheet: View {
    var mode: LinkInputMode = .website
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var urlText = ""
    @State private var isSubmitting = false
    @FocusState private var urlFieldFocused: Bool

    private var canSubmit: Bool {
        StudyStore.isValidWebURL(urlText)
    }

    private var generateButtonTitle: String {
        switch store.generationOutput {
        case .notes: return "Generate Notes"
        case .flashcards: return "Generate Flashcards"
        case .quiz: return "Generate Quiz"
        }
    }

    var body: some View {
        NavigationStack {
            VStack {
                Spacer(minLength: 0)

                VStack(spacing: 28) {
                    Group {
                        switch mode {
                        case .youtube:
                            YouTubeStyleLinkIcon(size: 56)
                        case .website:
                            WebsiteGlobeIcon(size: 56)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Text(mode.title)
                        .font(.title3.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    TextField("", text: $urlText, prompt: Text(mode.placeholder).foregroundStyle(Color.primary.opacity(0.88)))
                        .font(.body)
                        .foregroundStyle(Color(UIColor.label))
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($urlFieldFocused)
                        .submitLabel(.go)
                        .onSubmit(submitIfValid)
                        .disabled(isSubmitting)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(Color.gray.opacity(0.12))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Color.gray.opacity(0.18), lineWidth: 1)
                    )

                    Button(action: submitIfValid) {
                        Group {
                            if isSubmitting {
                                HStack(spacing: 10) {
                                    ProgressView()
                                        .tint(.white)
                                    Text("Generating...")
                                }
                            } else {
                                Text(generateButtonTitle)
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            Color(red: 0.08, green: 0.26, blue: 0.52),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                    .allowsHitTesting(canSubmit && !isSubmitting)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 28)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .onAppear {
                urlFieldFocused = true
            }
        }
    }

    private func submitIfValid() {
        guard canSubmit, !isSubmitting else { return }
        isSubmitting = true
        let submittedURL = urlText
        Task { @MainActor in
            await store.addRecordingFromLinkAndGenerateNotes(urlString: submittedURL)
            isSubmitting = false
            if store.transcriptionError == nil {
                dismiss()
            }
        }
    }
}

private struct WebsiteGlobeIcon: View {
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10 * size / 44, style: .continuous)
                .fill(Color(red: 0.20, green: 0.50, blue: 0.85))
                .frame(width: size, height: size)
            Image(systemName: "globe")
                .font(.system(size: 20 * size / 44, weight: .bold))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    AssistantView()
        .environmentObject(StudyStore())
        .environmentObject(AuthSessionManager())
}

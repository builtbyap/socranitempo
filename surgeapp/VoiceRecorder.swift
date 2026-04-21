//
//  VoiceRecorder.swift
//  surgeapp
//

import AVFoundation
import Combine
import Foundation

enum VoiceRecorderDestination {
    /// Saves into Notes as a voice note.
    case notes
    /// Saves into Assistant recordings list (meetings, lectures, etc.).
    case assistant
}

@MainActor
final class VoiceRecorder: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var permissionDenied = false
    @Published private(set) var currentLevel: Float = 0
    @Published private(set) var elapsedSeconds: TimeInterval = 0
    @Published private(set) var levelHistory: [Float] = []

    private let destination: VoiceRecorderDestination
    private var recorder: AVAudioRecorder?
    private var recordingURL: URL?
    private var meterTimer: Timer?
    private let maxHistoryCount = 50

    init(destination: VoiceRecorderDestination = .notes) {
        self.destination = destination
        super.init()
    }

    func toggleRecording(store: StudyStore) {
        if isRecording {
            stopRecording(store: store)
        } else {
            Task { await startRecording(store: store) }
        }
    }

    func stopIfRecording(store: StudyStore) {
        if isRecording {
            stopRecording(store: store)
        }
    }

    func dismissPermissionAlert() {
        permissionDenied = false
    }

    private func startRecording(store: StudyStore) async {
        permissionDenied = false

        let session = AVAudioSession.sharedInstance()

        switch session.recordPermission {
        case .denied:
            permissionDenied = true
            return
        case .undetermined:
            let granted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                session.requestRecordPermission { continuation.resume(returning: $0) }
            }
            if !granted {
                permissionDenied = true
                return
            }
        case .granted:
            break
        @unknown default:
            permissionDenied = true
            return
        }

        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            permissionDenied = true
            return
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let prefix = destination == .assistant ? "assistant" : "voice"
        let url = docs.appendingPathComponent("\(prefix)_\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let r = try AVAudioRecorder(url: url, settings: settings)
            r.delegate = self
            r.isMeteringEnabled = true
            guard r.prepareToRecord() else {
                permissionDenied = true
                return
            }
            guard r.record() else {
                permissionDenied = true
                return
            }
            recorder = r
            isRecording = true
            startMetering()
        } catch {
            permissionDenied = true
        }
    }

    private func startMetering() {
        levelHistory = []
        elapsedSeconds = 0
        currentLevel = 0
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateMeters()
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        currentLevel = 0
        elapsedSeconds = 0
    }

    private func updateMeters() {
        guard let recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let db = recorder.averagePower(forChannel: 0)
        let normalized = max(0, min(1, (db + 50) / 50))
        currentLevel = normalized
        elapsedSeconds = recorder.currentTime

        levelHistory.append(normalized)
        if levelHistory.count > maxHistoryCount {
            levelHistory.removeFirst(levelHistory.count - maxHistoryCount)
        }
    }

    private func stopRecording(store: StudyStore) {
        guard let recorder else { return }
        let duration = recorder.currentTime
        let url = recordingURL
        recorder.stop()
        self.recorder = nil
        isRecording = false
        stopMetering()

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)

        guard let url, duration > 0.5 else {
            if let url { try? FileManager.default.removeItem(at: url) }
            recordingURL = nil
            return
        }

        let filename = url.lastPathComponent
        switch destination {
        case .notes:
            Task { @MainActor in
                _ = await store.addVoiceNoteAndGenerateNotes(duration: duration, audioFilename: filename)
            }
        case .assistant:
            Task { @MainActor in
                await store.addMicrophoneRecordingAndGenerateNotes(duration: duration, audioFilename: filename)
            }
        }
        recordingURL = nil
    }
}

extension VoiceRecorder: AVAudioRecorderDelegate {
    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            let url = self.recordingURL
            self.recorder?.stop()
            self.recorder = nil
            self.isRecording = false
            self.stopMetering()
            if let url {
                try? FileManager.default.removeItem(at: url)
            }
            self.recordingURL = nil
        }
    }
}

// MARK: - Recording Panel UI

import SwiftUI

struct RecordingPanelView: View {
    @ObservedObject var recorder: VoiceRecorder
    var onStop: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Capsule()
                .fill(Color.gray.opacity(0.35))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            LiveWaveformView(levels: recorder.levelHistory, currentLevel: recorder.currentLevel)
                .frame(height: 80)
                .padding(.horizontal, 24)

            Button(action: onStop) {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 72, height: 72)

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.white)
                        .frame(width: 26, height: 26)
                }
            }
            .accessibilityLabel("Stop recording")
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, y: -4)
        )
    }

}

struct LiveWaveformView: View {
    var levels: [Float]
    var currentLevel: Float

    private let barCount = 50
    private let barSpacing: CGFloat = 2.5

    var body: some View {
        GeometryReader { geo in
            let totalSpacing = barSpacing * CGFloat(barCount - 1)
            let barWidth = max(2, (geo.size.width - totalSpacing) / CGFloat(barCount))

            HStack(spacing: barSpacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    let level = barLevel(at: i)
                    let height = max(4, CGFloat(level) * geo.size.height)

                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(Color.red.opacity(0.7 + Double(level) * 0.3))
                        .frame(width: barWidth, height: height)
                        .animation(.easeOut(duration: 0.08), value: level)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func barLevel(at index: Int) -> Float {
        guard !levels.isEmpty else {
            return 0.05
        }
        if index < levels.count {
            let mapIndex = levels.count - barCount + index
            if mapIndex >= 0 && mapIndex < levels.count {
                return max(0.05, levels[mapIndex])
            }
        }
        return 0.05
    }
}

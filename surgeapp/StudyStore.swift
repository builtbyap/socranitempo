//
//  StudyStore.swift
//  surgeapp
//

import Combine
import Foundation
import OSLog
import Supabase
import SuperwallKit

/// Controls whether Fly APIs produce markdown notes, a flashcard deck, or a multiple-choice quiz (Study tab).
enum StudyGenerationOutput: String, Sendable {
    case notes
    case flashcards
    case quiz
}

@MainActor
final class StudyStore: ObservableObject {
    private static let log = Logger(subsystem: "com.socrani.surgeapp", category: "StudySync")

    /// When set, study data is loaded from and pushed to Supabase for `cloudUserId`.
    private var cloudClient: SupabaseClient?
    private var cloudUserId: UUID?

    /// Free-tier quotas read subscription fields from this session (weak to avoid retain cycles).
    weak var freeTierAuth: AuthSessionManager?

    @Published var notes: [StudyNote]
    @Published var decks: [StudyDeck]
    @Published var quizzes: [StudyQuiz]
    @Published var recordings: [RecordingItem]
    /// Set by Notes/Assistant (`.notes`) or Study tab before opening add flows (`.flashcards` / `.quiz`).
    @Published var generationOutput: StudyGenerationOutput = .notes
    @Published var transcriptionInProgress = false
    @Published var transcriptionError: String?
    /// While a flashcard deck or quiz session is open (Study tab), `ContentView` hides the main tab title bar.
    @Published var hidesStudyTabTitleBarForSession = false
    /// Set when a new deck is generated so `StudyView` can push `DeckSessionView` without using Recent Flashcards.
    @Published var deckPendingAutoPresent: StudyDeck?
    /// Set when a new quiz is generated so `StudyView` can push `QuizSessionView` without using Recent Quizzes.
    @Published var quizPendingAutoPresent: StudyQuiz?

    init(
        notes: [StudyNote] = [],
        decks: [StudyDeck] = [],
        quizzes: [StudyQuiz] = [],
        recordings: [RecordingItem] = []
    ) {
        self.notes = notes
        self.decks = decks
        self.quizzes = quizzes
        self.recordings = recordings
    }

    /// Set before `loadFromCloud()`; pass `nil` on sign-out.
    func configureCloudSync(client: SupabaseClient?, userId: UUID?) {
        cloudClient = client
        cloudUserId = userId
        FreeTierUsageTracker.shared.configure(userId: userId)
    }

    /// After sign-in, moves server study rows to this session if another auth account exists with the same
    /// email (e.g. prior Google + new Apple). Safe to call every launch; it no-ops when there is no duplicate.
    func mergeCloudDataFromOtherAccountsWithSameEmail() async {
        guard let client = cloudClient, cloudUserId != nil else { return }
        do {
            try await StudySyncService(client: client).mergeStudyDataFromOtherAccountsWithSameEmail()
        } catch {
            Self.log.error("merge by same email failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Replaces local study data with the user’s server rows. Call when the session becomes available.
    func loadFromCloud() async {
        guard let client = cloudClient, let userId = cloudUserId else { return }
        do {
            let data = try await StudySyncService(client: client).fetchAll(userId: userId)
            notes = data.notes
            decks = data.decks
            quizzes = data.quizzes
            recordings = data.recordings
        } catch {
            Self.log.error("loadFromCloud failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Clear sync context and in-memory data after sign-out.
    func clearCloudDataAndResetLocal() {
        configureCloudSync(client: nil, userId: nil)
        notes = []
        decks = []
        quizzes = []
        recordings = []
        freeTierAuth = nil
    }

    private var freeTierSubscription: (status: String?, type: String?) {
        (
            freeTierAuth?.subscriptionStatusFromDB?.trimmingCharacters(in: .whitespacesAndNewlines),
            freeTierAuth?.subscriptionTypeFromDB?.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    @discardableResult
    private func gateFreeTierOrPresentPaywall(
        mode: StudyGenerationOutput,
        origin: FreeTierGenerationOrigin
    ) -> Bool {
        guard FreeTierUsageTracker.shared.canStartGeneration(
            mode: mode,
            origin: origin,
            subscriptionStatus: freeTierSubscription.status,
            subscriptionType: freeTierSubscription.type
        ) else {
            registerSuperwallPlacement(SuperwallPlacements.freeTierLimit)
            return false
        }
        return true
    }

    private func recordSuccessfulFreeTierIfApplicable(mode: StudyGenerationOutput, origin: FreeTierGenerationOrigin) {
        FreeTierUsageTracker.shared.recordSuccessfulGeneration(
            mode: mode,
            origin: origin,
            subscriptionStatus: freeTierSubscription.status,
            subscriptionType: freeTierSubscription.type
        )
    }

    /// Offline / no-Supabase mode: seed demo content once if everything is empty.
    func loadDemoDataIfEmpty() {
        guard notes.isEmpty, decks.isEmpty, quizzes.isEmpty, recordings.isEmpty else { return }
        notes = Self.sampleNotes
        decks = Self.sampleDecks
        recordings = Self.sampleRecordings
    }

    @discardableResult
    func addNote(title: String, body: String, tags: [String]) -> UUID {
        let cleanedTags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let newNote = StudyNote(title: title, body: body, tags: cleanedTags)
        notes.insert(newNote, at: 0)
        scheduleCloud { s, u in try await s.upsertNote(userId: u, newNote) }
        return newNote.id
    }

    func addVoiceNote(duration: TimeInterval, audioFilename: String) {
        let total = max(0, Int(duration.rounded()))
        let mins = total / 60
        let secs = total % 60
        let lengthLabel = String(format: "%d:%02d", mins, secs)
        let note = StudyNote(
            title: "Voice note",
            body: "Recorded audio · \(lengthLabel)",
            tags: ["voice"],
            audioFilename: audioFilename
        )
        notes.insert(note, at: 0)
        scheduleCloud { s, u in try await s.upsertNote(userId: u, note) }
    }

    /// Saves Notes-tab mic capture and generates transcript notes (or flashcards/quiz when `generationOutput` is set) via Fly proxy.
    @discardableResult
    func addVoiceNoteAndGenerateNotes(duration: TimeInterval, audioFilename: String) async -> UUID {
        let total = max(0, Int(duration.rounded()))
        let mins = total / 60
        let secs = total % 60
        let lengthLabel = String(format: "%d:%02d", mins, secs)
        let fallbackTitle = "Voice note · \(lengthLabel)"
        let mode = generationOutput

        guard gateFreeTierOrPresentPaywall(mode: mode, origin: .notesTabVoice) else {
            return UUID()
        }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = docs.appendingPathComponent(audioFilename)

        transcriptionInProgress = true
        transcriptionError = nil
        defer { transcriptionInProgress = false }

        do {
            let result = try await FlyService.transcribeAudioToNotes(fileURL: audioURL, outputMode: mode)
            switch mode {
            case .notes:
                let body = (result.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !body.isEmpty else {
                    throw NSError(domain: "StudyStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Empty response"])
                }
                let cleanedTitle = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let noteTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : fallbackTitle)
                let id = addNote(title: noteTitle, body: body, tags: ["ai", "transcript", "voice"])
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .notesTabVoice)
                return id
            case .flashcards:
                guard let pairs = result.cards, !pairs.isEmpty else {
                    transcriptionError = "Could not generate flashcards from this audio."
                    return UUID()
                }
                let t = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let deckTitle = (t?.isEmpty == false ? t! : "Flashcards")
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                let id = insertFlashcardDeck(title: deckTitle, topic: topic, pairs: pairs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .notesTabVoice)
                return id
            case .quiz:
                guard let qs = result.questions, !qs.isEmpty else {
                    transcriptionError = "Could not generate a quiz from this audio."
                    return UUID()
                }
                let t = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let quizTitle = (t?.isEmpty == false ? t! : "Quiz")
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                let id = insertQuiz(title: quizTitle, topic: topic, questions: qs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .notesTabVoice)
                return id
            }
        } catch {
            transcriptionError = error.localizedDescription
            if mode == .notes {
                return addNote(
                    title: fallbackTitle,
                    body: "Recorded audio · \(lengthLabel)\n\nTranscription failed. Please try again.",
                    tags: ["voice"]
                )
            }
            return UUID()
        }
    }

    func addRecording(title: String, kind: RecordingKind) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let displayTitle = trimmed.isEmpty ? "Untitled recording" : trimmed
        let item = RecordingItem(title: displayTitle, kind: kind)
        recordings.insert(item, at: 0)
        scheduleCloud { s, u in try await s.upsertRecording(userId: u, item) }
    }

    func removeNote(id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        let note = notes[idx]
        Self.removeAudioFileIfPresent(filename: note.audioFilename)
        notes.remove(at: idx)
        scheduleCloud { s, _ in try await s.deleteNote(id: id) }
    }

    func removeRecording(id: UUID) {
        guard let idx = recordings.firstIndex(where: { $0.id == id }) else { return }
        let item = recordings[idx]
        Self.removeAudioFileIfPresent(filename: item.audioFilename)
        recordings.remove(at: idx)
        scheduleCloud { s, _ in try await s.deleteRecording(id: id) }
    }

    private static func removeAudioFileIfPresent(filename: String?) {
        guard let name = filename, !name.isEmpty else { return }
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
    }

    private static func nonEmptyTopicOrGeneral(_ raw: String?) -> String {
        let t = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "General" : t
    }

    /// Adds a recording row from a pasted website or YouTube URL.
    @discardableResult
    func addRecordingFromLink(urlString: String) -> UUID? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = Self.normalizeURLString(trimmed)
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return nil }

        let hostRaw = url.host ?? ""
        let displayTitle: String = {
            let h = hostRaw
            if h.lowercased().hasPrefix("www.") {
                return String(h.dropFirst(4))
            }
            return h.isEmpty ? "Link" : h
        }()
        let hostLower = hostRaw.lowercased()
        let isYouTube =
            hostLower.contains("youtube.com")
            || hostLower.contains("youtu.be")
            || hostLower.contains("youtube-nocookie.com")
        let kind: RecordingKind = isYouTube ? .lecture : .other
        let item = RecordingItem(
            title: displayTitle,
            kind: kind,
            updatedAt: Date(),
            audioFilename: nil,
            sourceURL: normalized
        )
        recordings.insert(item, at: 0)
        scheduleCloud { s, u in try await s.upsertRecording(userId: u, item) }
        return item.id
    }

    /// Adds URL row and generates notes (or flashcards/quiz) from a website/YouTube link through Fly proxy.
    func addRecordingFromLinkAndGenerateNotes(urlString: String) async {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let normalized = Self.normalizeURLString(trimmed)
        guard Self.isValidWebURL(normalized) else { return }

        let mode = generationOutput
        guard gateFreeTierOrPresentPaywall(mode: mode, origin: .linkOrDocument) else { return }

        guard let recordingID = addRecordingFromLink(urlString: normalized) else { return }

        transcriptionInProgress = true
        transcriptionError = nil
        defer { transcriptionInProgress = false }

        do {
            let result = try await FlyService.generateNotesFromURL(urlString: normalized, outputMode: mode)
            let cleanedTitle = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let isYouTube = normalized.lowercased().contains("youtube.com")
                || normalized.lowercased().contains("youtu.be")
                || normalized.lowercased().contains("youtube-nocookie.com")
            let tags = isYouTube ? ["ai", "web", "youtube"] : ["ai", "web", "website"]

            switch mode {
            case .notes:
                let body = (result.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !body.isEmpty else {
                    transcriptionError = "No content could be generated from this link."
                    return
                }
                let noteTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : "Web notes")
                let noteID = addNote(title: noteTitle, body: body, tags: tags)
                linkGeneratedNote(noteID: noteID, toRecordingID: recordingID)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .linkOrDocument)
            case .flashcards:
                guard let pairs = result.cards, !pairs.isEmpty else {
                    transcriptionError = "Could not generate flashcards from this link."
                    return
                }
                let deckTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : "Flashcards")
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                _ = insertFlashcardDeck(title: deckTitle, topic: topic, pairs: pairs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .linkOrDocument)
            case .quiz:
                guard let qs = result.questions, !qs.isEmpty else {
                    transcriptionError = "Could not generate a quiz from this link."
                    return
                }
                let quizTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : "Quiz")
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                _ = insertQuiz(title: quizTitle, topic: topic, questions: qs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .linkOrDocument)
            }
        } catch {
            transcriptionError = error.localizedDescription
        }
    }

    /// Adds a recording row from a picked document file.
    @discardableResult
    func addRecordingFromDocument(fileURL: URL) -> UUID {
        let savedURL = Self.copyPickedFileToDocuments(fileURL) ?? fileURL
        return insertDocumentRecordingRow(savedURL: savedURL)
    }

    /// Imports document, adds a recording row, and generates notes (or flashcards/quiz) through Fly proxy.
    func addRecordingFromDocumentAndGenerateNotes(fileURL: URL) async {
        let savedURL = Self.copyPickedFileToDocuments(fileURL) ?? fileURL

        let mode = generationOutput
        guard gateFreeTierOrPresentPaywall(mode: mode, origin: .linkOrDocument) else { return }

        let recordingID = insertDocumentRecordingRow(savedURL: savedURL)

        transcriptionInProgress = true
        transcriptionError = nil
        defer { transcriptionInProgress = false }

        do {
            let result = try await FlyService.generateNotesFromDocument(fileURL: savedURL, outputMode: mode)
            let cleanedTitle = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackTitle = savedURL.deletingPathExtension().lastPathComponent

            switch mode {
            case .notes:
                let body = (result.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !body.isEmpty else {
                    transcriptionError = "No content could be extracted from this document."
                    return
                }
                let noteTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : fallbackTitle)
                let noteID = addNote(title: noteTitle, body: body, tags: ["ai", "document"])
                linkGeneratedNote(noteID: noteID, toRecordingID: recordingID)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .linkOrDocument)
            case .flashcards:
                guard let pairs = result.cards, !pairs.isEmpty else {
                    transcriptionError = "Could not generate flashcards from this document."
                    return
                }
                let deckTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : fallbackTitle)
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                _ = insertFlashcardDeck(title: deckTitle, topic: topic, pairs: pairs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .linkOrDocument)
            case .quiz:
                guard let qs = result.questions, !qs.isEmpty else {
                    transcriptionError = "Could not generate a quiz from this document."
                    return
                }
                let quizTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : fallbackTitle)
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                _ = insertQuiz(title: quizTitle, topic: topic, questions: qs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .linkOrDocument)
            }
        } catch {
            transcriptionError = error.localizedDescription
        }
    }

    @discardableResult
    private func insertDocumentRecordingRow(savedURL: URL) -> UUID {
        let title = savedURL.deletingPathExtension().lastPathComponent
        let displayTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Document"
            : title
        let item = RecordingItem(
            title: displayTitle,
            kind: .other,
            updatedAt: Date(),
            audioFilename: nil,
            sourceURL: savedURL.absoluteString
        )
        recordings.insert(item, at: 0)
        scheduleCloud { s, u in try await s.upsertRecording(userId: u, item) }
        return item.id
    }

    private static func copyPickedFileToDocuments(_ sourceURL: URL) -> URL? {
        let shouldStopAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let fm = FileManager.default
        guard let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        var destination = docsDir.appendingPathComponent(sourceURL.lastPathComponent)
        var suffix = 1
        while fm.fileExists(atPath: destination.path) {
            let candidate = ext.isEmpty ? "\(baseName)-\(suffix)" : "\(baseName)-\(suffix).\(ext)"
            destination = docsDir.appendingPathComponent(candidate)
            suffix += 1
        }

        do {
            try fm.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private static func normalizeURLString(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.lowercased().hasPrefix("http://") || t.lowercased().hasPrefix("https://") {
            return t
        }
        return "https://\(t)"
    }

    static func isValidWebURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let normalized = normalizeURLString(trimmed)
        guard let url = URL(string: normalized),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil
        else { return false }
        return true
    }

    /// Saves a mic capture for meetings / lectures (Assistant tab).
    @discardableResult
    func addMicrophoneRecording(duration: TimeInterval, audioFilename: String) -> UUID {
        let total = max(0, Int(duration.rounded()))
        let mins = total / 60
        let secs = total % 60
        let lengthLabel = String(format: "%d:%02d", mins, secs)
        let item = RecordingItem(
            title: "Recording · \(lengthLabel)",
            kind: .meeting,
            updatedAt: Date(),
            audioFilename: audioFilename
        )
        recordings.insert(item, at: 0)
        scheduleCloud { s, u in try await s.upsertRecording(userId: u, item) }
        return item.id
    }

    /// Saves the assistant recording and generates notes (or flashcards/quiz) from the audio via Fly proxy.
    func addMicrophoneRecordingAndGenerateNotes(duration: TimeInterval, audioFilename: String) async {
        let mode = generationOutput
        guard gateFreeTierOrPresentPaywall(mode: mode, origin: .assistantMicrophone) else { return }

        let recordingID = addMicrophoneRecording(duration: duration, audioFilename: audioFilename)

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioURL = docs.appendingPathComponent(audioFilename)

        transcriptionInProgress = true
        transcriptionError = nil
        defer { transcriptionInProgress = false }

        do {
            let result = try await FlyService.transcribeAudioToNotes(fileURL: audioURL, outputMode: mode)
            switch mode {
            case .notes:
                let body = (result.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard !body.isEmpty else {
                    transcriptionError = "No content could be generated from this recording."
                    return
                }
                let cleanedTitle = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let noteTitle = (cleanedTitle?.isEmpty == false ? cleanedTitle! : "Lecture notes")
                let noteID = addNote(title: noteTitle, body: body, tags: ["ai", "transcript"])
                linkGeneratedNote(noteID: noteID, toRecordingID: recordingID)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .assistantMicrophone)
            case .flashcards:
                guard let pairs = result.cards, !pairs.isEmpty else {
                    transcriptionError = "Could not generate flashcards from this recording."
                    return
                }
                let t = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let deckTitle = (t?.isEmpty == false ? t! : "Flashcards")
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                _ = insertFlashcardDeck(title: deckTitle, topic: topic, pairs: pairs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .assistantMicrophone)
            case .quiz:
                guard let qs = result.questions, !qs.isEmpty else {
                    transcriptionError = "Could not generate a quiz from this recording."
                    return
                }
                let t = result.title?.trimmingCharacters(in: .whitespacesAndNewlines)
                let quizTitle = (t?.isEmpty == false ? t! : "Quiz")
                let topic = Self.nonEmptyTopicOrGeneral(result.topic)
                _ = insertQuiz(title: quizTitle, topic: topic, questions: qs)
                recordSuccessfulFreeTierIfApplicable(mode: mode, origin: .assistantMicrophone)
            }
        } catch {
            transcriptionError = error.localizedDescription
        }
    }

    @discardableResult
    private func insertFlashcardDeck(title: String, topic: String, pairs: [FlyFlashcardPairDTO]) -> UUID {
        let cards = pairs.map { Flashcard(front: $0.front, back: $0.back) }
        let deck = StudyDeck(title: title, topic: topic, cards: cards)
        // Reassign so `@Published` reliably emits (in-place `insert` can skip SwiftUI updates).
        decks = [deck] + decks
        deckPendingAutoPresent = deck
        scheduleCloud { s, u in try await s.upsertDeck(userId: u, deck) }
        return deck.id
    }

    @discardableResult
    private func insertQuiz(title: String, topic: String, questions: [FlyQuizQuestionDTO]) -> UUID {
        let qs: [QuizQuestion] = questions.compactMap { dto in
            guard !dto.options.isEmpty else { return nil }
            let idx = min(max(0, dto.correctIndex), dto.options.count - 1)
            return QuizQuestion(question: dto.question, options: dto.options, correctIndex: idx)
        }
        guard !qs.isEmpty else { return UUID() }
        let quiz = StudyQuiz(title: title, topic: topic, questions: qs)
        quizzes = [quiz] + quizzes
        quizPendingAutoPresent = quiz
        scheduleCloud { s, u in try await s.upsertQuiz(userId: u, quiz) }
        return quiz.id
    }

    private func linkGeneratedNote(noteID: UUID, toRecordingID recordingID: UUID) {
        guard let idx = recordings.firstIndex(where: { $0.id == recordingID }) else { return }
        recordings[idx].generatedNoteID = noteID
        let rec = recordings[idx]
        scheduleCloud { s, u in try await s.upsertRecording(userId: u, rec) }
    }

    private func scheduleCloud(_ op: @escaping (StudySyncService, UUID) async throws -> Void) {
        guard let client = cloudClient, let userId = cloudUserId else { return }
        Task {
            do {
                try await op(StudySyncService(client: client), userId)
            } catch {
                Self.log.error("cloud sync: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    static let sampleNotes: [StudyNote] = [
        StudyNote(
            title: "Calculus - Chain Rule",
            body: "If f(x) = g(h(x)), then f'(x) = g'(h(x)) * h'(x).",
            tags: ["math", "exam-1"]
        ),
        StudyNote(
            title: "Biology - Cell Cycle",
            body: "Interphase has G1, S, G2. M phase includes mitosis and cytokinesis.",
            tags: ["biology", "midterm"]
        ),
        StudyNote(
            title: "History Essay Outline",
            body: "Thesis first, then 3 body arguments with evidence and counterargument.",
            tags: ["history", "writing"]
        )
    ]

    static let sampleDecks: [StudyDeck] = [
        StudyDeck(
            title: "Spanish Basics",
            topic: "Language",
            cards: [
                Flashcard(front: "Hola", back: "Hello"),
                Flashcard(front: "Gracias", back: "Thank you"),
                Flashcard(front: "Adios", back: "Goodbye")
            ]
        ),
        StudyDeck(
            title: "Physics Units",
            topic: "Science",
            cards: [
                Flashcard(front: "Force unit", back: "Newton (N)"),
                Flashcard(front: "Energy unit", back: "Joule (J)")
            ]
        )
    ]

    static let sampleRecordings: [RecordingItem] = [
        RecordingItem(title: "CS 101 — Week 4 lecture", kind: .lecture, updatedAt: .now),
        RecordingItem(title: "Product sync", kind: .meeting, updatedAt: .now.addingTimeInterval(-86_400)),
        RecordingItem(title: "Office hours Q&A", kind: .lecture, updatedAt: .now.addingTimeInterval(-3 * 86_400)),
        RecordingItem(title: "Untitled recording", kind: .meeting, updatedAt: .now.addingTimeInterval(-10 * 86_400))
    ]
}

//
//  StudyModels.swift
//  surgeapp
//

import Foundation

struct StudyNote: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var body: String
    var tags: [String]
    var updatedAt: Date
    /// Filename in the app Documents directory when this note has an attached voice recording.
    var audioFilename: String?

    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        tags: [String],
        updatedAt: Date = Date(),
        audioFilename: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.tags = tags
        self.updatedAt = updatedAt
        self.audioFilename = audioFilename
    }
}

struct Flashcard: Identifiable, Hashable, Codable {
    let id: UUID
    var front: String
    var back: String
    var confidence: Int

    init(id: UUID = UUID(), front: String, back: String, confidence: Int = 0) {
        self.id = id
        self.front = front
        self.back = back
        self.confidence = confidence
    }
}

struct StudyDeck: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var topic: String
    var cards: [Flashcard]

    init(id: UUID = UUID(), title: String, topic: String, cards: [Flashcard]) {
        self.id = id
        self.title = title
        self.topic = topic
        self.cards = cards
    }
}

struct QuizQuestion: Identifiable, Hashable, Codable {
    let id: UUID
    var question: String
    var options: [String]
    var correctIndex: Int

    init(id: UUID = UUID(), question: String, options: [String], correctIndex: Int) {
        self.id = id
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
    }
}

struct StudyQuiz: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var topic: String
    var questions: [QuizQuestion]

    init(id: UUID = UUID(), title: String, topic: String, questions: [QuizQuestion]) {
        self.id = id
        self.title = title
        self.topic = topic
        self.questions = questions
    }
}

/// Which surface created this recording metadata row (`study_recordings`). Assistant tab history lists only `.assistant`.
enum RecordingListOrigin: String, Hashable, Codable, Sendable {
    case assistant
    case notesAndStudy = "notes_and_study"
}

enum RecordingKind: String, CaseIterable, Identifiable, Hashable, Codable {
    case lecture
    case meeting
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .lecture: return "Lecture"
        case .meeting: return "Meeting"
        case .other: return "Other"
        }
    }
}

struct RecordingItem: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var kind: RecordingKind
    var updatedAt: Date
    /// Filename in app Documents when this row has an attached recording file.
    var audioFilename: String?
    /// Full URL when this row was added from a website or YouTube link.
    var sourceURL: String?
    /// Linked note ID when notes were generated from this recording item.
    var generatedNoteID: UUID?
    /// Whether this row should appear in the Assistant tab history (not Notes/Study link or document imports).
    var listOrigin: RecordingListOrigin

    init(
        id: UUID = UUID(),
        title: String,
        kind: RecordingKind,
        updatedAt: Date = Date(),
        audioFilename: String? = nil,
        sourceURL: String? = nil,
        generatedNoteID: UUID? = nil,
        listOrigin: RecordingListOrigin = .notesAndStudy
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.updatedAt = updatedAt
        self.audioFilename = audioFilename
        self.sourceURL = sourceURL
        self.generatedNoteID = generatedNoteID
        self.listOrigin = listOrigin
    }
}

//
//  StudySyncService.swift
//  surgeapp
//

import Foundation
import Supabase

/// Persists `StudyStore` data to Supabase (`study_*` tables) for the signed-in user.
struct StudySyncService {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Account merge (same person, different sign-in)

    /// Reassigns all `study_*` rows to the current `auth.uid()` when other `auth.users` rows
    /// share the same email (e.g. Google first, then Apple with the same address).
    /// Requires the RPC from migration `20260427_merge_study_data_same_email_accounts`.
    func mergeStudyDataFromOtherAccountsWithSameEmail() async throws {
        _ = try await client.rpc("merge_study_data_from_duplicate_email_accounts").execute()
    }

    // MARK: - Load

    func fetchAll(userId _: UUID) async throws -> (
        notes: [StudyNote],
        decks: [StudyDeck],
        quizzes: [StudyQuiz],
        recordings: [RecordingItem]
    ) {
        let noteRows: [StudyNoteDB] = try await client
            .from("study_notes")
            .select()
            .execute()
            .value
        let deckRows: [StudyDeckDB] = try await client
            .from("study_decks")
            .select()
            .execute()
            .value
        let quizRows: [StudyQuizDB] = try await client
            .from("study_quizzes")
            .select()
            .execute()
            .value
        let recRows: [StudyRecordingDB] = try await client
            .from("study_recordings")
            .select()
            .execute()
            .value

        let notes = noteRows.map { $0.toModel() }.sorted { $0.updatedAt > $1.updatedAt }
        let decks = deckRows.map { $0.toModel() }
        let quizzes = quizRows.map { $0.toModel() }
        let recordings = recRows.map { $0.toModel() }.sorted { $0.updatedAt > $1.updatedAt }
        return (notes, decks, quizzes, recordings)
    }

    // MARK: - Upsert / delete

    func upsertNote(userId: UUID, _ note: StudyNote) async throws {
        let row = StudyNoteDB(
            id: note.id,
            user_id: userId,
            title: note.title,
            body: note.body,
            tags: note.tags,
            updated_at: note.updatedAt,
            audio_filename: note.audioFilename
        )
        try await client
            .from("study_notes")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func deleteNote(id: UUID) async throws {
        try await client
            .from("study_notes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func upsertDeck(userId: UUID, _ deck: StudyDeck) async throws {
        let row = StudyDeckDB(
            id: deck.id,
            user_id: userId,
            title: deck.title,
            topic: deck.topic,
            cards: deck.cards,
            updated_at: Date()
        )
        try await client
            .from("study_decks")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func deleteDeck(id: UUID) async throws {
        try await client
            .from("study_decks")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func upsertQuiz(userId: UUID, _ quiz: StudyQuiz) async throws {
        let row = StudyQuizDB(
            id: quiz.id,
            user_id: userId,
            title: quiz.title,
            topic: quiz.topic,
            questions: quiz.questions,
            updated_at: Date()
        )
        try await client
            .from("study_quizzes")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func deleteQuiz(id: UUID) async throws {
        try await client
            .from("study_quizzes")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func upsertRecording(userId: UUID, _ item: RecordingItem) async throws {
        let row = StudyRecordingDB(
            id: item.id,
            user_id: userId,
            title: item.title,
            kind: item.kind.rawValue,
            updated_at: item.updatedAt,
            audio_filename: item.audioFilename,
            source_url: item.sourceURL,
            generated_note_id: item.generatedNoteID,
            list_origin: item.listOrigin.rawValue
        )
        try await client
            .from("study_recordings")
            .upsert(row, onConflict: "id")
            .execute()
    }

    func deleteRecording(id: UUID) async throws {
        try await client
            .from("study_recordings")
            .delete()
            .eq("id", value: id)
            .execute()
    }
}

// MARK: - DB rows (snake_case)

private struct StudyNoteDB: Codable {
    let id: UUID
    let user_id: UUID
    var title: String
    var body: String
    var tags: [String]
    var updated_at: Date
    var audio_filename: String?

    func toModel() -> StudyNote {
        StudyNote(
            id: id,
            title: title,
            body: body,
            tags: tags,
            updatedAt: updated_at,
            audioFilename: audio_filename
        )
    }
}

private struct StudyDeckDB: Codable {
    let id: UUID
    let user_id: UUID
    var title: String
    var topic: String
    var cards: [Flashcard]
    var updated_at: Date

    func toModel() -> StudyDeck {
        StudyDeck(id: id, title: title, topic: topic, cards: cards)
    }
}

private struct StudyQuizDB: Codable {
    let id: UUID
    let user_id: UUID
    var title: String
    var topic: String
    var questions: [QuizQuestion]
    var updated_at: Date

    func toModel() -> StudyQuiz {
        StudyQuiz(id: id, title: title, topic: topic, questions: questions)
    }
}

private struct StudyRecordingDB: Codable {
    let id: UUID
    let user_id: UUID
    var title: String
    var kind: String
    var updated_at: Date
    var audio_filename: String?
    var source_url: String?
    var generated_note_id: UUID?
    /// When missing (legacy row), inferred from `audio_filename` (`assistant_` prefix) in `toModel()`.
    var list_origin: String?

    func toModel() -> RecordingItem {
        let k = RecordingKind(rawValue: kind) ?? .other
        let origin = Self.resolveListOrigin(stored: list_origin, audioFilename: audio_filename)
        return RecordingItem(
            id: id,
            title: title,
            kind: k,
            updatedAt: updated_at,
            audioFilename: audio_filename,
            sourceURL: source_url,
            generatedNoteID: generated_note_id,
            listOrigin: origin
        )
    }

    private static func resolveListOrigin(stored: String?, audioFilename: String?) -> RecordingListOrigin {
        if let stored, let o = RecordingListOrigin(rawValue: stored) {
            return o
        }
        if audioFilename?.hasPrefix("assistant_") == true {
            return .assistant
        }
        return .notesAndStudy
    }
}

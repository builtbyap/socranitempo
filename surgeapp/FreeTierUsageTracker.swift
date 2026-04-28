//
//  FreeTierUsageTracker.swift
//  surgeapp
//
//  Local caps when `subscription_type` is **`free`** and **`subscription_status`**
//  indicates “no paid access” — default signup free tier, inactive/canceled after trial, etc.
//  Paid product types (`pro`, `yearly`, monthly, …) never hit limits or quota paywalls.
//

import Combine
import Foundation

/// Sources that drive which quota buckets count toward a Fly generation success.
enum FreeTierGenerationOrigin: Equatable {
    /// Notes-tab mic → `addVoiceNoteAndGenerateNotes` (never counts toward assistant recording cap).
    case notesTabVoice
    /// Website / YouTube link or document import (Notes, Study, or Assistant add sheet).
    case linkOrDocument
    /// Assistant tab meeting/lecture mic → `addMicrophoneRecordingAndGenerateNotes`.
    case assistantMicrophone
}

@MainActor
final class FreeTierUsageTracker: ObservableObject {
    static let shared = FreeTierUsageTracker()

    private let defaults = UserDefaults.standard

    private enum Key {
        static func notes(_ uid: UUID) -> String { "freeQuota.\(uid.uuidString).notesTx" }
        static func flashcards(_ uid: UUID) -> String { "freeQuota.\(uid.uuidString).flashGen" }
        static func quizzes(_ uid: UUID) -> String { "freeQuota.\(uid.uuidString).quizGen" }
        static func assistantRec(_ uid: UUID) -> String { "freeQuota.\(uid.uuidString).assistantRec" }
        static func homeworkImages(_ uid: UUID) -> String { "freeQuota.\(uid.uuidString).homeworkImg" }
    }

    static let maxNoteTranscriptions = 2
    static let maxFlashcardGenerations = 2
    static let maxQuizGenerations = 2
    static let maxAssistantRecordingTranscriptions = 2
    static let maxHomeworkImageAnalyses = 4

    private(set) var userId: UUID?

    private init() {}

    func configure(userId: UUID?) {
        self.userId = userId
        objectWillChange.send()
    }

    /// Quota gates apply whenever the user presents as **subscription_type `free`** and the status
    /// reflects “no unlimited paid entitlement”: default free row, churn, expired trial (`inactive`),
    /// cancellations, unpaid/ billing issues with no paid SKU, etc.
    /// **Paid SKUs are never gated** (`t != "free"`).
    ///
    /// `subscription_status == "trialing"` is excluded — live paid trials normally use non-`free` types
    /// from StoreKit/webhooks; if that ever overlaps `free`, we avoid wrongly throttling checkout trials.
    static func isRestrictedFreeTier(subscriptionStatus: String?, subscriptionType: String?) -> Bool {
        let s = (subscriptionStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let t = (subscriptionType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard t == "free" else {
            return false
        }

        if s == "trialing" {
            return false
        }

        let restrictedStatusesNonEntitledFree: Set<String> = [
            "active",
            "inactive",
            "expired",
            "canceled",
            "cancelled",
            "paused",
            "unpaid",
            "past_due",
            "billing_issue",
            "incomplete",
            "incomplete_expired",
        ]

        guard restrictedStatusesNonEntitledFree.contains(s) else {
            return false
        }

        return true
    }

    private func readCount(for key: (UUID) -> String) -> Int {
        guard let uid = userId else { return 0 }
        return defaults.integer(forKey: key(uid))
    }

    private func writeCount(_ value: Int, for key: (UUID) -> String) {
        guard let uid = userId else { return }
        defaults.set(value, forKey: key(uid))
        objectWillChange.send()
    }

    // MARK: - Gates (call before network / heavy work)

    /// Returns `true` if the user may start this generation (or is not on the limited free tier).
    func canStartGeneration(
        mode: StudyGenerationOutput,
        origin: FreeTierGenerationOrigin,
        subscriptionStatus: String?,
        subscriptionType: String?
    ) -> Bool {
        guard Self.isRestrictedFreeTier(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType),
              userId != nil
        else { return true }

        switch origin {
        case .notesTabVoice:
            if mode == .notes { return readCount(for: Key.notes) < Self.maxNoteTranscriptions }
            if mode == .flashcards { return readCount(for: Key.flashcards) < Self.maxFlashcardGenerations }
            return readCount(for: Key.quizzes) < Self.maxQuizGenerations

        case .linkOrDocument:
            if mode == .notes { return readCount(for: Key.notes) < Self.maxNoteTranscriptions }
            if mode == .flashcards { return readCount(for: Key.flashcards) < Self.maxFlashcardGenerations }
            return readCount(for: Key.quizzes) < Self.maxQuizGenerations

        case .assistantMicrophone:
            guard readCount(for: Key.assistantRec) < Self.maxAssistantRecordingTranscriptions else { return false }
            if mode == .notes { return readCount(for: Key.notes) < Self.maxNoteTranscriptions }
            if mode == .flashcards { return readCount(for: Key.flashcards) < Self.maxFlashcardGenerations }
            return readCount(for: Key.quizzes) < Self.maxQuizGenerations
        }
    }

    func canAnalyzeHomeworkImage(subscriptionStatus: String?, subscriptionType: String?) -> Bool {
        guard Self.isRestrictedFreeTier(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType),
              userId != nil
        else { return true }
        return readCount(for: Key.homeworkImages) < Self.maxHomeworkImageAnalyses
    }

    // MARK: - Record success (call only after a successful AI generation)

    func recordSuccessfulGeneration(
        mode: StudyGenerationOutput,
        origin: FreeTierGenerationOrigin,
        subscriptionStatus: String?,
        subscriptionType: String?
    ) {
        guard Self.isRestrictedFreeTier(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType),
              userId != nil else { return }

        switch origin {
        case .notesTabVoice, .linkOrDocument:
            switch mode {
            case .notes:
                increment(Key.notes)
            case .flashcards:
                increment(Key.flashcards)
            case .quiz:
                increment(Key.quizzes)
            }
        case .assistantMicrophone:
            increment(Key.assistantRec)
            switch mode {
            case .notes:
                increment(Key.notes)
            case .flashcards:
                increment(Key.flashcards)
            case .quiz:
                increment(Key.quizzes)
            }
        }
    }

    func recordSuccessfulHomeworkImageAnalysis(subscriptionStatus: String?, subscriptionType: String?) {
        guard Self.isRestrictedFreeTier(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType),
              userId != nil else { return }
        increment(Key.homeworkImages)
    }

    private func increment(_ keyFn: (UUID) -> String) {
        guard let uid = userId else { return }
        let k = keyFn(uid)
        let next = defaults.integer(forKey: k) + 1
        defaults.set(next, forKey: k)
        objectWillChange.send()
    }
}

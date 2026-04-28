//
//  FreeTierUsageTracker.swift
//  surgeapp
//
//  Unlimited local usage **only** when `public.users` has:
//  - `subscription_type` ∈ { trial, pro, yearly, annual } AND
//  - `subscription_status` ∈ { active, trialing }.
//  All other rows (including **`free`**, empty type, **monthly**/other SKUs) hit caps and quota paywalls.
//
//  Buckets:
//  - Notes / flashcards / quizzes: AI generations (all tabs).
//  - Assistant sessions: Assistant tab only (link, doc, or mic) — see `assistantTabSession`.
//

import Combine
import Foundation

/// What produced a Fly-backed generation for quota accounting.
enum FreeTierGenerationOrigin: Equatable {
    /// Voice on **Notes** or **Study** tabs only (no Assistant “session” bucket).
    case notesOrStudyVoice
    /// Website / YouTube / document from **Notes** or **Study** add sheets (mode buckets only).
    case notesOrStudyLinkOrDocument
    /// **Assistant** tab: website, YouTube, document, **or** meeting mic — uses Assistant session cap **and** mode buckets.
    case assistantTabSession
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

    private static let unlimitedSubscriptionTypes: Set<String> = [
        "trial",
        "pro",
        "yearly",
        "annual",
    ]

    private static let entitledSubscriptionStatuses: Set<String> = [
        "active",
        "trialing",
    ]

    static func hasUnlimitedSubscriptionAccess(subscriptionStatus: String?, subscriptionType: String?) -> Bool {
        let s = (subscriptionStatus ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let t = (subscriptionType ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard Self.entitledSubscriptionStatuses.contains(s) else { return false }
        guard Self.unlimitedSubscriptionTypes.contains(t) else { return false }
        return true
    }

    static func shouldApplyUsageLimits(subscriptionStatus: String?, subscriptionType: String?) -> Bool {
        !Self.hasUnlimitedSubscriptionAccess(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType)
    }

    static func isRestrictedFreeTier(subscriptionStatus: String?, subscriptionType: String?) -> Bool {
        Self.shouldApplyUsageLimits(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType)
    }

    private func readCount(for key: (UUID) -> String) -> Int {
        guard let uid = userId else { return 0 }
        return defaults.integer(forKey: key(uid))
    }

    private func increment(_ keyFn: (UUID) -> String) {
        guard let uid = userId else { return }
        let k = keyFn(uid)
        let next = defaults.integer(forKey: k) + 1
        defaults.set(next, forKey: k)
        objectWillChange.send()
    }

    private func remainingUnderModeCap(_ mode: StudyGenerationOutput) -> Bool {
        switch mode {
        case .notes:
            return readCount(for: Key.notes) < Self.maxNoteTranscriptions
        case .flashcards:
            return readCount(for: Key.flashcards) < Self.maxFlashcardGenerations
        case .quiz:
            return readCount(for: Key.quizzes) < Self.maxQuizGenerations
        }
    }

    /// Returns `true` if the user may start this generation (`false` triggers paywall).
    func canStartGeneration(
        mode: StudyGenerationOutput,
        origin: FreeTierGenerationOrigin,
        subscriptionStatus: String?,
        subscriptionType: String?
    ) -> Bool {
        guard Self.shouldApplyUsageLimits(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType) else {
            return true
        }
        guard userId != nil else {
            return true
        }

        switch origin {
        case .notesOrStudyVoice, .notesOrStudyLinkOrDocument:
            return remainingUnderModeCap(mode)

        case .assistantTabSession:
            guard readCount(for: Key.assistantRec) < Self.maxAssistantRecordingTranscriptions else { return false }
            return remainingUnderModeCap(mode)
        }
    }

    func canAnalyzeHomeworkImage(subscriptionStatus: String?, subscriptionType: String?) -> Bool {
        guard Self.shouldApplyUsageLimits(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType) else {
            return true
        }
        guard userId != nil else {
            return true
        }
        return readCount(for: Key.homeworkImages) < Self.maxHomeworkImageAnalyses
    }

    func recordSuccessfulGeneration(
        mode: StudyGenerationOutput,
        origin: FreeTierGenerationOrigin,
        subscriptionStatus: String?,
        subscriptionType: String?
    ) {
        guard Self.shouldApplyUsageLimits(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType),
              userId != nil else { return }

        switch origin {
        case .notesOrStudyVoice, .notesOrStudyLinkOrDocument:
            incrementModeOnly(mode)

        case .assistantTabSession:
            increment(Key.assistantRec)
            incrementModeOnly(mode)
        }
    }

    private func incrementModeOnly(_ mode: StudyGenerationOutput) {
        switch mode {
        case .notes:
            increment(Key.notes)
        case .flashcards:
            increment(Key.flashcards)
        case .quiz:
            increment(Key.quizzes)
        }
    }

    func recordSuccessfulHomeworkImageAnalysis(subscriptionStatus: String?, subscriptionType: String?) {
        guard Self.shouldApplyUsageLimits(subscriptionStatus: subscriptionStatus, subscriptionType: subscriptionType),
              userId != nil else { return }
        increment(Key.homeworkImages)
    }
}

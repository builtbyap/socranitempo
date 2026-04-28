//
//  StudyView.swift
//  surgeapp
//

import SwiftUI
import UniformTypeIdentifiers

private enum StudyToolKind: String, CaseIterable, Identifiable {
    case flashcards
    case quiz

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flashcards: return "Flashcards"
        case .quiz: return "Quiz"
        }
    }

    var subtitle: String {
        switch self {
        case .flashcards: return "Review made easy"
        case .quiz: return "Instant Q&As"
        }
    }

    var icon: String {
        switch self {
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .quiz: return "checklist"
        }
    }

    var iconColor: Color {
        switch self {
        case .flashcards:
            return Color(red: 0.55, green: 0.35, blue: 0.85)
        case .quiz:
            return Color(red: 0.18, green: 0.7, blue: 0.55)
        }
    }

    var bgColor: Color {
        iconColor.opacity(0.12)
    }
}

struct StudyView: View {
    @EnvironmentObject private var store: StudyStore
    @StateObject private var voiceRecorder = VoiceRecorder(destination: .notes)
    @State private var showAddSheet = false
    @State private var presentedLinkMode: LinkInputMode?
    @State private var showDocumentPicker = false
    @State private var showDocumentConfirmSheet = false
    @State private var pendingDocumentURL: URL?
    @State private var isUploadingDocument = false
    @State private var showTranscriptionError = false
    @State private var deckToOpenFromAddSheet: StudyDeck?
    @State private var quizToOpenFromAddSheet: StudyQuiz?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(spacing: 16) {
                            Button {
                                store.generationOutput = .flashcards
                                showAddSheet = true
                            } label: {
                                studyCardView(.flashcards)
                            }
                            .buttonStyle(.plain)

                            Button {
                                store.generationOutput = .quiz
                                showAddSheet = true
                            } label: {
                                studyCardView(.quiz)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, voiceRecorder.isRecording ? 200 : 24)
                }
                .background(Color(UIColor.systemGroupedBackground))

                if voiceRecorder.isRecording {
                    RecordingPanelView(recorder: voiceRecorder) {
                        voiceRecorder.toggleRecording(store: store)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.82), value: voiceRecorder.isRecording)
            .background(Color(UIColor.systemGroupedBackground))
            .toolbar(.hidden, for: .navigationBar)
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
                    },
                    onSelectRecentDeck: { deck in
                        showAddSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            deckToOpenFromAddSheet = deck
                        }
                    },
                    onSelectRecentQuiz: { quiz in
                        showAddSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            quizToOpenFromAddSheet = quiz
                        }
                    }
                )
                .environmentObject(store)
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
                .presentationCornerRadius(24)
            }
            .sheet(item: $presentedLinkMode) { mode in
                WebsiteLinkInputSheet(mode: mode)
                    .environmentObject(store)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
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
            .navigationDestination(item: $deckToOpenFromAddSheet) { deck in
                DeckSessionView(deck: deck)
            }
            .navigationDestination(item: $quizToOpenFromAddSheet) { quiz in
                QuizSessionView(quiz: quiz)
            }
            .onChange(of: store.deckPendingAutoPresent) { _, deck in
                guard let deck else { return }
                store.deckPendingAutoPresent = nil
                deckToOpenFromAddSheet = deck
            }
            .onChange(of: store.quizPendingAutoPresent) { _, quiz in
                guard let quiz else { return }
                store.quizPendingAutoPresent = nil
                quizToOpenFromAddSheet = quiz
            }
            .onAppear {
                if let deck = store.deckPendingAutoPresent {
                    store.deckPendingAutoPresent = nil
                    deckToOpenFromAddSheet = deck
                } else if let quiz = store.quizPendingAutoPresent {
                    store.quizPendingAutoPresent = nil
                    quizToOpenFromAddSheet = quiz
                }
            }
        }
    }

    private func studyCardView(_ tool: StudyToolKind) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tool.bgColor)
                    .frame(width: 52, height: 52)

                Image(systemName: tool.icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tool.iconColor)
            }
            .padding(.bottom, 4)

            Text(tool.title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(.primary)

            Text(tool.subtitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
    }

}

private struct QuizSessionView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    let quiz: StudyQuiz
    @State private var index = 0
    @State private var selectedOption: Int?
    @State private var hasChecked = false
    @State private var showHint = false

    private static let optionLetters = ["A", "B", "C", "D"]

    private func letter(for i: Int) -> String {
        if i >= 0 && i < Self.optionLetters.count {
            return Self.optionLetters[i]
        }
        return "\(i + 1)"
    }

    private var q: QuizQuestion {
        quiz.questions[index]
    }

    private var hintText: String {
        let correct = q.options[q.correctIndex]
        let t = correct.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.count <= 100 { return t }
        return String(t.prefix(100)) + "…"
    }

    var body: some View {
        Group {
            if quiz.questions.isEmpty {
                ZStack {
                    quizSessionBackgroundGradient
                        .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

                    VStack(spacing: 0) {
                        quizSessionTopBar
                        Spacer()
                        ContentUnavailableView {
                            Label("No questions", systemImage: "checklist")
                        } description: {
                            Text("This quiz has no questions yet.")
                        }
                        Spacer()
                    }
                }
            } else {
                quizContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { store.hidesStudyTabTitleBarForSession = true }
        .onDisappear { store.hidesStudyTabTitleBarForSession = false }
    }

    /// Back + title below the status bar (main tab title bar is hidden for this screen).
    private var quizSessionTopBar: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer(minLength: 8)

            Text(quiz.title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var quizSessionBackgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.91, green: 0.86, blue: 0.98),
                Color(red: 0.98, green: 0.88, blue: 0.94),
                Color(red: 0.94, green: 0.91, blue: 0.99)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var quizContent: some View {
        ZStack {
            quizSessionBackgroundGradient
                .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

            VStack(spacing: 0) {
                quizSessionTopBar

                VStack {
                    Spacer(minLength: 0)
                    VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        Text("\(index + 1) / \(quiz.questions.count)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.gray.opacity(0.75))

                        Spacer(minLength: 0)

                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showHint.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.primary.opacity(0.85))
                                Text("Hint")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)

                    if showHint {
                        Text(hintText)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(Color.gray.opacity(0.9))
                            .multilineTextAlignment(.leading)
                            .padding(.horizontal, 22)
                            .padding(.top, 12)
                    }

                    Text(q.question)
                        .font(.system(size: 19, weight: .regular, design: .serif))
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 22)
                        .padding(.top, showHint ? 16 : 22)
                        .padding(.bottom, 20)

                    VStack(spacing: 12) {
                        ForEach(Array(q.options.enumerated()), id: \.offset) { i, opt in
                            Button {
                                guard !hasChecked else { return }
                                selectedOption = i
                            } label: {
                                HStack(alignment: .top, spacing: 0) {
                                    (
                                        Text("\(letter(for: i)). ")
                                            .font(.system(size: 16, weight: .semibold))
                                        + Text(opt)
                                            .font(.system(size: 16, weight: .regular))
                                    )
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(optionForeground(for: i))
                                    .strikethrough(isIncorrectUserChoice(i), color: Color.primary.opacity(0.45))
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(optionBackground(for: i))
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 22)

                    Button(action: primaryBottomAction) {
                        Text(primaryBottomTitle)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(Color.red)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!hasChecked && selectedOption == nil)
                    .opacity((!hasChecked && selectedOption == nil) ? 0.45 : 1)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 22)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 16)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private var primaryBottomTitle: String {
        if !hasChecked { return "Check" }
        if index < quiz.questions.count - 1 { return "Next" }
        return "Finish"
    }

    private func primaryBottomAction() {
        if !hasChecked {
            hasChecked = true
            return
        }
        if index < quiz.questions.count - 1 {
            index += 1
            selectedOption = nil
            hasChecked = false
            showHint = false
        } else {
            dismiss()
        }
    }

    /// User picked this option after Check, and it is not the correct answer.
    private func isIncorrectUserChoice(_ i: Int) -> Bool {
        hasChecked && i == selectedOption && selectedOption != q.correctIndex
    }

    private func optionBackground(for i: Int) -> Color {
        if hasChecked {
            if i == q.correctIndex {
                return Color.green.opacity(0.16)
            }
            if isIncorrectUserChoice(i) {
                return Color(red: 1, green: 0.28, blue: 0.34).opacity(0.38)
            }
            return Color(white: 0.96)
        }
        if selectedOption == i {
            return Color.blue.opacity(0.16)
        }
        return Color(white: 0.96)
    }

    private func optionForeground(for i: Int) -> Color {
        if hasChecked {
            if i == q.correctIndex {
                return Color(red: 0.1, green: 0.5, blue: 0.25)
            }
            if i == selectedOption {
                return Color(red: 0.65, green: 0.15, blue: 0.18)
            }
            return Color.primary.opacity(0.85)
        }
        if selectedOption == i {
            return Color.blue
        }
        return Color.primary.opacity(0.88)
    }
}

private struct DeckSessionView: View {
    @EnvironmentObject private var store: StudyStore
    @Environment(\.dismiss) private var dismiss

    @State private var cards: [Flashcard]
    @State private var index = 0
    @State private var showBack = false

    private let navigationTitle: String

    init(deck: StudyDeck) {
        _cards = State(initialValue: deck.cards)
        navigationTitle = deck.title
    }

    private var card: Flashcard {
        cards[index]
    }

    var body: some View {
        Group {
            if cards.isEmpty {
                ZStack {
                    Color(red: 0.96, green: 0.97, blue: 0.98)
                        .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

                    VStack(spacing: 0) {
                        deckSessionTopBar
                        Spacer()
                        ContentUnavailableView {
                            Label("No flashcards", systemImage: "rectangle.on.rectangle.angled")
                        } description: {
                            Text("This deck has no cards yet.")
                        }
                        Spacer()
                    }
                }
            } else {
                flashcardStudyContent
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear { store.hidesStudyTabTitleBarForSession = true }
        .onDisappear { store.hidesStudyTabTitleBarForSession = false }
    }

    /// Back + title below the status bar (main tab title bar is hidden for this screen).
    private var deckSessionTopBar: some View {
        HStack(alignment: .center) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer(minLength: 8)

            Text(navigationTitle)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var flashcardStudyContent: some View {
        ZStack {
            Color(red: 0.96, green: 0.97, blue: 0.98)
                .ignoresSafeArea(edges: [.bottom, .leading, .trailing])

            VStack(spacing: 0) {
                deckSessionTopBar

                VStack {
                    Spacer(minLength: 0)
                    VStack(spacing: 0) {
                        // Stacked flashcard
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 6)
                                .frame(height: 360)
                                .scaleEffect(0.94)
                                .offset(y: 14)

                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.white)
                                .shadow(color: .black.opacity(0.07), radius: 14, x: 0, y: 7)
                                .frame(height: 360)
                                .scaleEffect(0.97)
                                .offset(y: 7)

                            VStack(spacing: 0) {
                                HStack(alignment: .center) {
                                    Text("\(index + 1) / \(cards.count)")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Color.gray.opacity(0.75))
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 22)
                                .padding(.top, 22)
                                .padding(.bottom, 8)

                                Spacer(minLength: 8)

                                Text(showBack ? card.back : card.front)
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 28)

                                Spacer(minLength: 8)
                            }
                            .frame(height: 360)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Color.white)
                            )
                            .shadow(color: .black.opacity(0.12), radius: 24, x: 0, y: 10)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                    showBack.toggle()
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        HStack(spacing: 12) {
                            flashcardActionButton(
                                emoji: "😤",
                                circleColor: Color(red: 0.95, green: 0.82, blue: 0.84),
                                title: "To review",
                                titleColor: Color(red: 0.62, green: 0.18, blue: 0.22),
                                action: markToReview
                            )

                            flashcardActionButton(
                                emoji: "😌",
                                circleColor: Color(red: 0.82, green: 0.94, blue: 0.88),
                                title: "Mastered",
                                titleColor: Color(red: 0.15, green: 0.48, blue: 0.32),
                                action: markMastered
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 28)
                        .padding(.bottom, 8)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func flashcardActionButton(
        emoji: String,
        circleColor: Color,
        title: String,
        titleColor: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(circleColor)
                        .frame(width: 40, height: 40)
                    Text(emoji)
                        .font(.system(size: 22))
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(titleColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.06), radius: 10, x: 0, y: 4)
            )
        }
        .buttonStyle(.plain)
    }

    private func markToReview() {
        var c = cards[index]
        c.confidence = max(0, c.confidence - 1)
        cards[index] = c
        advanceCard()
    }

    private func markMastered() {
        var c = cards[index]
        c.confidence = min(5, c.confidence + 1)
        cards[index] = c
        advanceCard()
    }

    private func advanceCard() {
        showBack = false
        if cards.count <= 1 { return }
        if index < cards.count - 1 {
            index += 1
        } else {
            index = 0
        }
    }
}

#Preview {
    StudyView()
        .environmentObject(StudyStore())
}

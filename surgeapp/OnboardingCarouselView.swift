//
//  OnboardingCarouselView.swift
//  surgeapp
//

import SwiftUI
import UserNotifications

private enum OnboardingTheme {
    static let background = Color.white
    /// Grouped-style surface for cards and pills
    static let card = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let progressTrack = Color(red: 0.88, green: 0.88, blue: 0.91)
    static let accent = Color(red: 0.57, green: 0.40, blue: 1.0)
    static let primaryText = Color(red: 0.11, green: 0.11, blue: 0.13)
    static let secondaryText = Color(red: 0.45, green: 0.45, blue: 0.48)
    static let gold = Color(red: 1.0, green: 0.76, blue: 0.03)
    static let success = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let quizIncorrect = Color(red: 0.82, green: 0.22, blue: 0.28)
    static let pillBorder = Color.black.opacity(0.1)
    static let subtleFill = Color.black.opacity(0.06)
}

struct OnboardingCarouselView: View {
    @EnvironmentObject private var store: StudyStore
    @Binding var hasCompletedOnboarding: Bool
    @State private var page = 0
    @State private var flashcardFlipped = false
    @State private var selectedRole: String?
    @State private var selectedReferral: String?
    @State private var showOnboardingAddSheet = false
    @State private var didAutoPresentUploadAddSheet = false
    /// Title of the add action chosen on the upload step (matches `AssistantAddOptionsSheet` row labels).
    @State private var onboardingUploadSelection: String?
    /// Cancellable wait before auto-advancing from the upload step (3s after a choice is shown).
    @State private var uploadAutoAdvanceTask: Task<Void, Never>?
    /// Selected onboarding quiz option (`A`…`D`); `nil` until the user taps.
    @State private var onboardingQuizSelection: String?
    private let totalPages = 8
    private let onboardingQuizCorrectLetter = "B"
    /// Space between the page title block and the options / examples below (replaces flex `Spacer` that pulled them apart).
    private let onboardingHeaderToBodySpacing: CGFloat = 20
    /// Lifts the Upload Anything content slightly vs. vertically centered pages.
    private let onboardingUploadPageVerticalNudge: CGFloat = -32

    /// Tab index for the upload step (same order as `TabView` tags).
    private var uploadPageIndex: Int { 4 }
    private var quizPageIndex: Int { 3 }
    private var rolePageIndex: Int { 0 }
    private var referralPageIndex: Int { 5 }

    /// `Continue` is only shown on steps that require picking an option. Upload uses auto-advance instead.
    private var isContinueUnlocked: Bool {
        switch page {
        case rolePageIndex: return selectedRole != nil
        case quizPageIndex: return onboardingQuizSelection != nil
        case uploadPageIndex: return false
        case referralPageIndex: return selectedReferral != nil
        default: return true
        }
    }

    var body: some View {
        ZStack {
            OnboardingTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                TabView(selection: $page) {
                    rolePage.tag(0)
                    flashcardsPage.tag(1)
                    notesPage.tag(2)
                    quizPage.tag(3)
                    uploadPage.tag(4)
                    referralPage.tag(5)
                    notificationsPage.tag(6)
                    socialProofPage.tag(7)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: page)
                .onChange(of: page) { oldValue, newValue in
                    if oldValue == uploadPageIndex, newValue != uploadPageIndex {
                        uploadAutoAdvanceTask?.cancel()
                        uploadAutoAdvanceTask = nil
                    }
                    if newValue == uploadPageIndex, !didAutoPresentUploadAddSheet {
                        didAutoPresentUploadAddSheet = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                            showOnboardingAddSheet = true
                        }
                    }
                    if newValue == quizPageIndex {
                        onboardingQuizSelection = nil
                    }
                    if newValue == uploadPageIndex {
                        scheduleUploadAutoAdvanceIfNeeded()
                    }
                }
                .onChange(of: onboardingUploadSelection) { _, _ in
                    scheduleUploadAutoAdvanceIfNeeded()
                }

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 28)
                    .padding(.top, 12)
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            store.generationOutput = .notes
        }
        .sheet(isPresented: $showOnboardingAddSheet) {
            AssistantAddOptionsSheet(
                onRecordAudio: {
                    onboardingUploadSelection = "Record audio"
                    showOnboardingAddSheet = false
                },
                onWebsite: {
                    onboardingUploadSelection = "Import from website"
                    showOnboardingAddSheet = false
                },
                onYouTube: {
                    onboardingUploadSelection = "Add a YouTube link"
                    showOnboardingAddSheet = false
                },
                onUploadDocument: {
                    onboardingUploadSelection = "Upload document"
                    showOnboardingAddSheet = false
                }
            )
            .environmentObject(store)
            .presentationDetents([.height(420)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(24)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                if page > 0 { page -= 1 }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .opacity(page > 0 ? 1 : 0.35)
            .disabled(page == 0)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(OnboardingTheme.progressTrack)
                        .frame(height: 6)
                    Capsule()
                        .fill(OnboardingTheme.accent)
                        .frame(width: max(8, geo.size.width * progress), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    private var progress: CGFloat {
        CGFloat(page + 1) / CGFloat(totalPages)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if page == 6 {
            VStack(spacing: 14) {
                Button("Skip for now") {
                    advanceOrFinish()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(OnboardingTheme.secondaryText)

                Button {
                    Task {
                        _ = try? await UNUserNotificationCenter.current()
                            .requestAuthorization(options: [.alert, .sound, .badge])
                        advanceOrFinish()
                    }
                } label: {
                    label("Enable Notifications", fullWidth: true)
                }
                .buttonStyle(.plain)
            }
        } else if isContinueUnlocked {
            Button {
                advanceOrFinish()
            } label: {
                label(primaryButtonTitle, fullWidth: true)
            }
            .buttonStyle(.plain)
        }
    }

    private var primaryButtonTitle: String {
        switch page {
        case 7: return "Join 1 Million Students"
        default: return "Continue"
        }
    }

    private func label(_ text: String, fullWidth: Bool) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: fullWidth ? .infinity : nil)
            .padding(.vertical, 18)
            .background(OnboardingTheme.accent)
            .clipShape(Capsule())
    }

    private func advanceOrFinish() {
        if page < totalPages - 1 {
            page += 1
        } else {
            hasCompletedOnboarding = true
        }
    }

    /// After an upload option is shown, advance after 3s (no Continue on this step).
    private func scheduleUploadAutoAdvanceIfNeeded() {
        uploadAutoAdvanceTask?.cancel()
        uploadAutoAdvanceTask = nil
        guard page == uploadPageIndex, onboardingUploadSelection != nil else { return }
        uploadAutoAdvanceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled, page == uploadPageIndex else { return }
            advanceOrFinish()
        }
    }

    // MARK: - Page 1: Flashcards

    private var flashcardsPage: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: onboardingHeaderToBodySpacing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Master your terms.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                    Text("Memorize key concepts with spaced repetition")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                flashcard
                    .onTapGesture {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            flashcardFlipped.toggle()
                        }
                    }
                    .padding(.horizontal, 4)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var flashcard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(OnboardingTheme.card)
                .shadow(color: .black.opacity(0.12), radius: 16, y: 8)

            VStack(spacing: 12) {
                Text("Tap to flip")
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                Spacer()
                Group {
                    if flashcardFlipped {
                        Text("Process by which plants convert light into chemical energy.")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        Text("Photosynthesis")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(OnboardingTheme.primaryText)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
                Spacer()
            }
        }
        .frame(height: 280)
    }

    // MARK: - Page 2: Notes

    private var notesPage: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: onboardingHeaderToBodySpacing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("We'll create beautiful notes for you.")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(OnboardingTheme.card)
                    .overlay(
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(OnboardingTheme.accent)
                                Text("Biology 101 — Molecular Biology")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(OnboardingTheme.secondaryText)
                            }
                            Text("Prokaryotes vs. Eukaryotes")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(OnboardingTheme.primaryText)
                            Text("Overview")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(OnboardingTheme.accent)
                            Text("Cells are categorized into two main groups with distinct structural differences.")
                                .font(.subheadline)
                                .foregroundStyle(OnboardingTheme.primaryText.opacity(0.88))
                            HStack(spacing: 12) {
                                cellChip(title: "Prokaryotic", subtitle: "Simple")
                                cellChip(title: "Eukaryotic", subtitle: "Complex")
                            }
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(OnboardingTheme.accent)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)
                                Text("Prokaryotic cells: no nucleus, simpler structure.")
                                    .font(.footnote)
                                    .foregroundStyle(OnboardingTheme.secondaryText)
                            }
                        }
                        .padding(20)
                    )
                    .frame(maxHeight: 360)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func cellChip(title: String, subtitle: String) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [OnboardingTheme.accent.opacity(0.35), OnboardingTheme.background],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 56, height: 56)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(OnboardingTheme.primaryText)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(OnboardingTheme.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(OnboardingTheme.subtleFill))
    }

    // MARK: - Page 3: Quiz

    private var quizPage: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: onboardingHeaderToBodySpacing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Crush your exams.")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                    Text("Auto-generated quizzes help you retain what you've learned")
                        .font(.system(size: 16))
                        .foregroundStyle(OnboardingTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 16) {
                    Group {
                        if onboardingQuizSelection == nil {
                            Text("Choose an answer")
                        } else if onboardingQuizSelection == onboardingQuizCorrectLetter {
                            Text("Nice — that's right!")
                        } else {
                            Text("Not quite — try another option")
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.secondaryText)
                    Text("What is the primary function of mitochondria in a cell?")
                        .font(.headline)
                        .foregroundStyle(OnboardingTheme.primaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 10) {
                        onboardingQuizOptionRow(letter: "A", text: "DNA replication")
                        onboardingQuizOptionRow(letter: "B", text: "Energy production (ATP synthesis)")
                        onboardingQuizOptionRow(letter: "C", text: "Protein folding")
                        onboardingQuizOptionRow(letter: "D", text: "Photosynthesis")
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(OnboardingTheme.card)
                )
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func onboardingQuizOptionRow(letter: String, text: String) -> some View {
        let isSelected = onboardingQuizSelection == letter
        let isCorrect = letter == onboardingQuizCorrectLetter
        let borderColor: Color = {
            guard isSelected else { return OnboardingTheme.pillBorder }
            return isCorrect ? OnboardingTheme.success : OnboardingTheme.quizIncorrect
        }()
        let borderWidth: CGFloat = isSelected ? 2 : 1

        return Button {
            onboardingQuizSelection = letter
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Text(letter)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .frame(width: 24, alignment: .leading)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                if isSelected {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(isCorrect ? OnboardingTheme.success : OnboardingTheme.quizIncorrect)
                        .padding(.top, 2)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: borderWidth)
                    .background(RoundedRectangle(cornerRadius: 14).fill(OnboardingTheme.subtleFill))
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 4: Upload

    private var uploadPage: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: onboardingHeaderToBodySpacing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Upload Anything")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                    Text("PDFs • YouTube Videos • Audio")
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showOnboardingAddSheet = true
                } label: {
                    Group {
                        if let selection = onboardingUploadSelection {
                            AddSheetOptionRowLabel(
                                title: selection,
                                subtitle: AddSheetAddOptionKind(title: selection)?.subtitle
                            ) {
                                AddSheetAddOptionIcons.icon(for: selection)
                            }
                        } else {
                            ZStack {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(OnboardingTheme.card)
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .strokeBorder(
                                        OnboardingTheme.accent,
                                        style: StrokeStyle(lineWidth: 2, dash: [8, 6])
                                    )
                                VStack(spacing: 10) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(OnboardingTheme.accent)
                                    Text("Tap to upload")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(OnboardingTheme.primaryText)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 20)
                                    Text("Record, link, or upload")
                                        .font(.caption)
                                        .foregroundStyle(OnboardingTheme.secondaryText)
                                }
                            }
                            .frame(height: 180)
                        }
                    }
                    .contentShape(
                        RoundedRectangle(cornerRadius: onboardingUploadSelection == nil ? 20 : 16, style: .continuous)
                    )
                }
                .buttonStyle(.plain)

                if onboardingUploadSelection == nil {
                    VStack(spacing: 8) {
                        Text("Try it out!")
                            .font(.headline)
                            .foregroundStyle(OnboardingTheme.primaryText)
                        Text("This is the add sheet you’ll use in the Notes tab after signing in.")
                            .font(.subheadline)
                            .foregroundStyle(OnboardingTheme.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .offset(y: onboardingUploadPageVerticalNudge)
        }
    }

    // MARK: - Page 5: Role

    private var rolePage: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: onboardingHeaderToBodySpacing) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("What describes you best?")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                    Text("We use this to personalize your experience :)")
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(roleOptions, id: \.self) { role in
                        selectionPill(role, selected: selectedRole == role) {
                            selectedRole = role
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var roleOptions: [String] {
        [
            "Undergraduate Student", "High School Student", "Middle School Student",
            "Graduate Student", "Professional", "Educator", "Other",
        ]
    }

    // MARK: - Page 6: Referral

    private var referralPage: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: onboardingHeaderToBodySpacing) {
                Text("How did you hear about us?")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 10) {
                    ForEach(referralOptions, id: \.self) { opt in
                        selectionPill(opt, selected: selectedReferral == opt) {
                            selectedReferral = opt
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var referralOptions: [String] {
        ["TikTok", "YouTube", "Instagram", "Twitter/X", "Friend", "Google Search", "App Store", "Other"]
    }

    private func selectionPill(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OnboardingTheme.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(OnboardingTheme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(selected ? OnboardingTheme.accent : OnboardingTheme.pillBorder, lineWidth: selected ? 2 : 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Page 7: Notifications

    private var notificationsPage: some View {
        OnboardingPageContainer {
            VStack(alignment: .leading, spacing: onboardingHeaderToBodySpacing) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Never miss what matters")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                    Text("Get notified about things like…")
                        .font(.subheadline)
                        .foregroundStyle(OnboardingTheme.primaryText.opacity(0.85))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 12) {
                    notificationRow(icon: "bell.fill", title: "Live Lectures", body: "Lecture starting — want a quick summary?")
                    notificationRow(icon: "calendar", title: "Study streaks", body: "You're on a roll — keep today's streak alive.")
                    notificationRow(icon: "bell.fill", title: "Quiz ready", body: "Your spaced-repetition deck is due.")
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private func notificationRow(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(OnboardingTheme.accent.opacity(0.55))
                .frame(width: 48, height: 48)
                .overlay(Image(systemName: icon).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(OnboardingTheme.primaryText)
                Text(body)
                    .font(.caption)
                    .foregroundStyle(OnboardingTheme.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(OnboardingTheme.card))
    }

    // MARK: - Page 8: Social proof

    private var socialProofPage: some View {
        OnboardingPageContainer {
            VStack(alignment: .center, spacing: 12) {
                VStack(spacing: 4) {
                    Text("1 Million")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(OnboardingTheme.accent.opacity(0.85))
                    Text("Students trust Socrani")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: 8) {
                    testimonialCard(
                        initials: "AR",
                        name: "Alex Rodriguez",
                        school: "UC Berkeley",
                        quote: "Practice quizzes help me retain material—finally felt confident for exams."
                    )
                    testimonialCard(
                        initials: "SK",
                        name: "Sarah Kim",
                        school: "New York University",
                        quote: "Clear notes I can study from. No more rewriting slides at 2 a.m.",
                        avatarColor: Color.purple.opacity(0.75)
                    )
                    testimonialCard(
                        initials: "JL",
                        name: "Jordan Lee",
                        school: "UT Austin",
                        quote: "Flashcards from my own files changed how I prep for midterms.",
                        avatarColor: Color.orange.opacity(0.8)
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func testimonialCard(
        initials: String,
        name: String,
        school: String,
        quote: String,
        avatarColor: Color = Color.teal.opacity(0.85)
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 36, height: 36)
                    Text(initials)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(OnboardingTheme.primaryText)
                    Text(school)
                        .font(.caption2)
                        .foregroundStyle(OnboardingTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 4)
                HStack(spacing: 1) {
                    ForEach(0..<5, id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(OnboardingTheme.gold)
                    }
                }
            }
            Text("\"\(quote)\"")
                .font(.caption)
                .foregroundStyle(OnboardingTheme.secondaryText)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(OnboardingTheme.card)
        )
    }
}

// MARK: - Layout wrapper

/// Vertically centers page content in the area between the progress header and the bottom bar. Short pages look
/// centered; tall pages scroll. Uses a single `ScrollView` with `minHeight` (common pattern) — avoid nested
/// `ScrollView`s in `content` so this remains the only vertical scroll.
private struct OnboardingPageContainer<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    content()
                        .padding(.horizontal, 24)
                    Spacer(minLength: 0)
                }
                .frame(minWidth: geo.size.width, minHeight: geo.size.height, alignment: .center)
            }
            .scrollIndicators(.hidden)
        }
    }
}

#Preview {
    OnboardingCarouselView(hasCompletedOnboarding: .constant(false))
        .environmentObject(StudyStore())
}

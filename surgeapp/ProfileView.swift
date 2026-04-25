//
//  ProfileView.swift
//  surgeapp
//

import Supabase
import SuperwallKit
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthSessionManager
    @Environment(\.openURL) private var openURL

    @State private var showDeleteConfirm = false
    @State private var showDeleteAppleStep = false
    @State private var isDeletingAccount = false
    @State private var showDeleteError = false
    @State private var deleteErrorMessage = ""
    @AppStorage("appThemeDisplay") private var themeDisplay = "System"

    private var user: User? { auth.profileUser }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    profileHeaderCard
                    upgradeCTAButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 8)

                sectionGroup(title: "ACCOUNT") {
                    settingsRow(
                        symbol: "character.book.closed",
                        title: "Change Language",
                        value: "English (US)"
                    ) {
                        // Localize later: open system or in-app language picker
                    }
                    sectionDivider
                    settingsRow(
                        symbol: "paintpalette",
                        title: "Theme",
                        value: themeDisplay
                    ) {
                        // Placeholder: cycle or sheet
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                sectionGroup(title: "SUBSCRIPTION") {
                    HStack(alignment: .center, spacing: 12) {
                        settingsIcon("creditcard")
                        Text("Manage Subscription")
                            .font(.body)
                        Spacer(minLength: 0)
                        Text("Free Plan")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 14)
                    .padding(.horizontal, 16)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        registerSuperwallPlacement(SuperwallPlacements.manageSubscriptionTapped)
                    }
                    sectionDivider
                    settingsRow(symbol: "clock.arrow.circlepath", title: "Restore Purchases") {
                        Task { await Superwall.shared.restorePurchases() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                sectionGroup(title: "SUPPORT") {
                    settingsRow(symbol: "headphones", title: "Contact Support") {
                        if let url = URL(string: "mailto:support@socrani.com?subject=Surge%20support") {
                            openURL(url)
                        }
                    }
                    sectionDivider
                    settingsRow(symbol: "globe", title: "Go to Website") {
                        if let url = URL(string: "https://socrani.com") {
                            openURL(url)
                        }
                    }
                    sectionDivider
                    settingsRow(symbol: "star", title: "Rate Us") {
                        if let url = URL(string: "https://apps.apple.com/app/id000000000") {
                            openURL(url)
                        }
                    }
                    sectionDivider
                    settingsRow(symbol: "doc.text", title: "Terms of Service") {
                        if let url = URL(string: "https://socrani.com/terms") {
                            openURL(url)
                        }
                    }
                    sectionDivider
                    settingsRow(symbol: "lock", title: "Privacy Policy") {
                        if let url = URL(string: "https://socrani.com/privacy") {
                            openURL(url)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                if auth.isSupabaseConfigured, auth.isAuthenticated {
                    VStack(spacing: 12) {
                        Button {
                            Task { await auth.signOut() }
                        } label: {
                            Text("Log Out")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(
                                            Color(red: 0.55, green: 0.14, blue: 0.18)
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showDeleteAppleStep = true
                        } label: {
                            Text(isDeletingAccount ? "Deleting account…" : "Delete Account")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(red: 0.9, green: 0.35, blue: 0.38))
                        }
                        .buttonStyle(.plain)
                        .disabled(isDeletingAccount)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 28)
                }
            }
        }
        .background(Color(white: 0.99))
        // Step 1: for Apple users, explain they need to revoke from Apple ID settings so name re-appears next sign-in.
        .alert("Before you delete", isPresented: $showDeleteAppleStep) {
            Button("Cancel", role: .cancel) {}
            if auth.signedInWithApple {
                Button("Got it — continue") { showDeleteConfirm = true }
            } else {
                Button("Delete permanently", role: .destructive) {
                    Task { @MainActor in
                        isDeletingAccount = true
                        defer { isDeletingAccount = false }
                        if let err = await auth.deleteAccount() {
                            deleteErrorMessage = err
                            showDeleteError = true
                        }
                    }
                }
            }
        } message: {
            if auth.signedInWithApple {
                Text("If you sign in again with Apple, your name will only re-appear if you first revoke this app from your Apple ID settings:\n\nSettings → [Your Name] → Sign-In & Security → Apps Using Apple ID → Surge → Stop Using Apple ID\n\nThis lets Apple re-share your name on the next sign-in.")
            } else {
                Text("This permanently removes your account and all synced notes, flashcards, quizzes, and recording metadata. This cannot be undone.")
            }
        }
        // Step 2: final confirmation (Apple users reach here after step 1; others skip straight here).
        .alert("Delete account", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete permanently", role: .destructive) {
                Task { @MainActor in
                    isDeletingAccount = true
                    defer { isDeletingAccount = false }
                    if let err = await auth.deleteAccount() {
                        deleteErrorMessage = err
                        showDeleteError = true
                    }
                }
            }
        } message: {
            Text("This permanently removes your account and all synced notes, flashcards, quizzes, and recording metadata. This cannot be undone.")
        }
        .alert("Couldn’t delete account", isPresented: $showDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage)
        }
    }

    // MARK: - Header card

    private var profileHeaderCard: some View {
        Button {
            // Placeholder: edit profile
        } label: {
            HStack(alignment: .center, spacing: 14) {
                profileAvatar
                VStack(alignment: .leading, spacing: 4) {
                    // Line 1: name (from Apple metadata / identities). Line 2: email — order is fixed.
                    Text(displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(displayEmail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private var profileAvatar: some View {
        let initial = String(displayName.prefix(1).uppercased())
        return ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.92, green: 0.28, blue: 0.65),
                            Color(red: 0.78, green: 0.22, blue: 0.52),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Text(initial.isEmpty ? "?" : initial)
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(width: 56, height: 56)
    }

    private var upgradeCTAButton: some View {
        Button {
            registerSuperwallPlacement(SuperwallPlacements.upgradeTapped)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                Text("Upgrade to Unlimited")
                    .font(.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.55, green: 0.32, blue: 0.92),
                                Color(red: 0.45, green: 0.28, blue: 0.82),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section chrome

    private func sectionGroup(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
                .textCase(.uppercase)
            VStack(spacing: 0) {
                content()
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(0.04), radius: 6, y: 2)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
            )
        }
    }

    private var sectionDivider: some View {
        HStack {
            Spacer()
                .frame(width: 44)
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(height: 0.5)
        }
    }

    private func settingsIcon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(.primary)
            .frame(width: 28, alignment: .center)
    }

    private func settingsRow(
        symbol: String,
        title: String,
        value: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 12) {
                settingsIcon(symbol)
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - User display

    private var displayName: String {
        guard let user else { return "Guest" }
        if let s = user.resolvedDisplayName, !s.isEmpty { return s }
        if let s = auth.cachedSignInWithAppleDisplayName, !s.isEmpty { return s }
        if let s = auth.publicUsersDisplayName, !s.isEmpty { return s }
        if let e = user.resolvedDisplayEmail,
           Self.canUseEmailLocalPartAsDisplayName(e),
           let local = e.split(separator: "@").first, !e.isEmpty {
            return String(local).replacingOccurrences(of: ".", with: " ").capitalized
        }
        return "User"
    }

    private var displayEmail: String {
        if let e = user?.resolvedDisplayEmail, !e.isEmpty { return e }
        return "Not signed in"
    }

    /// Hide My Email’s local part is random; it must not be shown as a “name” above the real address.
    private static func canUseEmailLocalPartAsDisplayName(_ email: String) -> Bool {
        let lower = email.lowercased()
        if lower.hasSuffix("@privaterelay.appleid.com") { return false }
        return true
    }
}

// MARK: - User display (Apple often omits `email` on the JWT; GoTrue + identities can still hold it)

private extension User {
    /// Prefer real name for the **first** profile line (above email). Apple may only expose it in metadata or `identities`.
    var resolvedDisplayName: String? {
        let meta = userMetadata
        if let s = meta["full_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
        if let s = meta["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
        if let s = meta["display_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
        let given = meta["given_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let family = meta["family_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let combined = [given, family].filter { !$0.isEmpty }.joined(separator: " ")
        if !combined.isEmpty { return combined }
        for id in identities ?? [] {
            guard let d = id.identityData else { continue }
            if let s = d["full_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
            if let s = d["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty { return s }
            let ig = d["given_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let ifam = d["family_name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let idCombined = [ig, ifam].filter { !$0.isEmpty }.joined(separator: " ")
            if !idCombined.isEmpty { return idCombined }
        }
        return nil
    }

    /// `email` is sometimes nil on the in-memory `Session.user` for Apple; server user + `identities` may still have the address (second line).
    var resolvedDisplayEmail: String? {
        if let e = email?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty { return e }
        for id in identities ?? [] {
            if let d = id.identityData, let s = d["email"]?.stringValue, !s.isEmpty { return s }
        }
        return nil
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthSessionManager())
}

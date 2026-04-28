//
//  AuthSessionManager.swift
//  surgeapp
//

import AuthenticationServices
import Combine
import Foundation
import OSLog
import Supabase

@MainActor
final class AuthSessionManager: ObservableObject {
    private static let log = Logger(subsystem: "com.socrani.surgeapp", category: "users")

    /// Auth state stream; `user.email` is often **nil** for Apple in the cached JWT even when the account has an email in GoTrue.
    @Published private(set) var session: Session?
    /// Filled from `client.auth.user()`; prefer for profile UI when the session’s user omits `email` or `identities`.
    @Published private(set) var serverSyncedUser: User?
    @Published private(set) var isReady = false
    @Published var lastError: String?

    private(set) var client: SupabaseClient?

    var isAuthenticated: Bool {
        session != nil
    }

    /// When there are no Supabase keys, the app behaves as before (no sign-in). With keys, the user must sign in.
    var canUseApp: Bool {
        guard isReady else { return false }
        if !isSupabaseConfigured { return true }
        return isAuthenticated
    }

    var isSupabaseConfigured: Bool {
        SupabaseConfig.supabaseURL != nil && SupabaseConfig.supabaseAnonKey != nil
    }

    /// Per-user id for store sync; exposed here so views need not import the Auth module.
    var syncUserId: UUID? { session?.user.id }

    /// Best-effort `User` for the profile screen (server fetch when the JWT is thin).
    var profileUser: User? { serverSyncedUser ?? session?.user }

    /// True when the current user's primary (or only) identity is Sign in with Apple.
    var signedInWithApple: Bool {
        let user = serverSyncedUser ?? session?.user
        guard let identities = user?.identities, !identities.isEmpty else {
            // No identity data available; fall back to app metadata provider hint.
            let provider = user?.appMetadata["provider"]?.stringValue ?? ""
            return provider == "apple"
        }
        return identities.contains { $0.provider == "apple" }
    }

    /// Name Apple shared on a previous sign-in (only set when we received `credential.fullName`). Not a relay-email local part.
    var cachedSignInWithAppleDisplayName: String? {
        guard let id = session?.user.id else { return nil }
        return UserDefaults.standard.string(forKey: Self.siwaDisplayNameKey(id))
    }

    /// Name fetched from the `public.users` row (populated by `handle_new_user` trigger). Last-resort fallback for display name.
    @Published private(set) var publicUsersDisplayName: String?

    /// `public.users.subscription_status` (snake case in DB).
    @Published private(set) var subscriptionStatusFromDB: String?
    /// `public.users.subscription_type` (e.g. `free` vs a paid product slug).
    @Published private(set) var subscriptionTypeFromDB: String?
    /// After the first `public.users` fetch for the current session; used to avoid flashing onboarding for entitled users.
    @Published private(set) var isPublicUserProfileLoaded = false

    /// Google sign-in uses Supabase OAuth (PKCE + `ASWebAuthenticationSession`), not `grant_type=id_token`,
    /// so we avoid GoTrue’s Google iOS nonce checks (supabase/auth#1829).
    var canUseGoogleSignIn: Bool {
        isSupabaseConfigured
    }

    init() {
        guard let url = SupabaseConfig.supabaseURL, let key = SupabaseConfig.supabaseAnonKey else {
            isReady = true
            return
        }
        let opts = SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(redirectToURL: SupabaseConfig.oauthRedirectURL)
        )
        client = SupabaseClient(supabaseURL: url, supabaseKey: key, options: opts)
        Task { await listenForAuthChanges() }
    }

    private static let userRefreshAuthEvents: Set<AuthChangeEvent> = [
        .signedIn, .initialSession, .tokenRefreshed, .userUpdated, .mfaChallengeVerified,
    ]

    private func listenForAuthChanges() async {
        guard let client else { return }
        for await (event, session) in client.auth.authStateChanges {
            if event == .signedOut || event == .userDeleted {
                UserDefaults.standard.set(false, forKey: Self.hasCompletedOnboardingKey)
            }
            self.session = session
            if !isReady { isReady = true }
            if session != nil, Self.userRefreshAuthEvents.contains(event) {
                await refreshUserFromServer(client: client)
            } else if session == nil {
                serverSyncedUser = nil
                clearPublicUserProfile()
            }
            if let session, event == .signedIn || event == .initialSession {
                await ensureUserRowInDatabase(client: client, session: session)
            }
        }
    }

    private func refreshUserFromServer(client: SupabaseClient) async {
        do {
            let u = try await client.auth.user()
            serverSyncedUser = u
        } catch {
            Self.log.debug("auth.user() refresh failed: \(error.localizedDescription, privacy: .public)")
        }
        await refreshPublicUserProfile(client: client)
    }

    /// `public.users` row: name + subscription fields for paywall / onboarding routing.
    private func refreshPublicUserProfile(client: SupabaseClient) async {
        defer { isPublicUserProfileLoaded = true }
        guard let uid = session?.user.id else {
            publicUsersDisplayName = nil
            subscriptionStatusFromDB = nil
            subscriptionTypeFromDB = nil
            return
        }
        do {
            let rows: [PublicUserProfileRow] = try await client
                .from("users")
                .select("name, full_name, subscription_status, subscription_type")
                .eq("id", value: uid)
                .limit(1)
                .execute()
                .value
            if let row = rows.first {
                let fn = row.fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let n = row.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                publicUsersDisplayName = !fn.isEmpty ? fn : !n.isEmpty ? n : nil
                subscriptionStatusFromDB = row.subscriptionStatus?.trimmingCharacters(in: .whitespacesAndNewlines)
                subscriptionTypeFromDB = row.subscriptionType?.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                publicUsersDisplayName = nil
                subscriptionStatusFromDB = nil
                subscriptionTypeFromDB = nil
            }
        } catch {
            Self.log.debug("public.users profile fetch failed: \(error.localizedDescription, privacy: .public)")
            publicUsersDisplayName = nil
            subscriptionStatusFromDB = nil
            subscriptionTypeFromDB = nil
        }
    }

    /// Skips the marketing onboarding when the user is signed in and `public.users` shows an **entitled** (non–free) subscription with a live status. Default rows are `active` + `free`; paid users should have `subscription_type` set to a product (e.g. `monthly`) by your billing integration.
    var shouldSkipOnboardingForEntitledUser: Bool {
        guard isSupabaseConfigured, isAuthenticated, isPublicUserProfileLoaded else { return false }
        let status = (subscriptionStatusFromDB ?? "").lowercased()
        let type = (subscriptionTypeFromDB ?? "free").lowercased()
        if status == "canceled" || status == "cancelled" || status == "past_due" || status == "unpaid" {
            return false
        }
        let statusOK = status == "active" || status == "trialing"
        let notOnFreeOnlyTier = !type.isEmpty && type != "free"
        return statusOK && notOnFreeOnlyTier
    }

    private func clearPublicUserProfile() {
        publicUsersDisplayName = nil
        subscriptionStatusFromDB = nil
        subscriptionTypeFromDB = nil
        isPublicUserProfileLoaded = false
    }

    func handleOpenURL(_ url: URL) {
        client?.auth.handle(url)
    }

    /// Google via Supabase-hosted OAuth; completes in the in-app auth session, then `auth.handle` if needed.
    func signInWithGoogle() async {
        lastError = nil
        guard let client else {
            lastError = "Add SupabaseURL and SupabaseAnonKey to Info.plist."
            return
        }
        do {
            _ = try await client.auth.signInWithOAuth(
                provider: .google,
                redirectTo: SupabaseConfig.oauthRedirectURL
            )
        } catch {
            let ns = error as NSError
            // ASWebAuthenticationSessionErrorCodeCanceledLogin == 1
            if ns.domain == ASWebAuthenticationSessionErrorDomain, ns.code == 1 {
                return
            }
            lastError = Self.userFacingSignInError(error)
        }
    }

    /// Apple via **native** Sign in with Apple + Supabase `signInWithIdToken` (no in-app `supabase.co` web OAuth dialog).
    /// In the Supabase Apple provider, add your iOS **bundle id** to **Client IDs** so the id token is accepted.
    func signInWithApple() async {
        lastError = nil
        guard let client else {
            lastError = "Add SupabaseURL and SupabaseAnonKey to Info.plist."
            return
        }
        do {
            let auth = try await AppleSignInCoordinator.perform()
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                lastError = "Apple sign in returned an unexpected credential type."
                return
            }
            guard
                let idToken = credential.identityToken.flatMap({ String(data: $0, encoding: .utf8)
                })
            else {
                lastError = "Could not read the Apple identity token."
                return
            }
            _ = try await client.auth.signInWithIdToken(
                credentials: OpenIDConnectCredentials(
                    provider: .apple,
                    idToken: idToken
                )
            )
            // Apple only sends `fullName` on the first sign-in. Format reliably, send to auth metadata, and cache locally for later sign-ins.
            if let full = credential.fullName, let display = Self.displayNameFromApplePersonNameComponents(full) {
                _ = try? await client.auth.update(
                    user: UserAttributes(
                        data: [
                            "full_name": .string(display),
                            "name": .string(display),
                        ]
                    )
                )
                if let u = try? await client.auth.user() {
                    UserDefaults.standard.set(display, forKey: Self.siwaDisplayNameKey(u.id))
                    objectWillChange.send()
                }
            }
            await refreshUserFromServer(client: client)
        } catch {
            if let aerr = error as? ASAuthorizationError, aerr.code == .canceled {
                return
            }
            lastError = Self.userFacingSignInError(error, isNativeApple: true)
        }
    }

    private static func userFacingSignInError(_ error: Error, isNativeApple: Bool = false) -> String {
        let s = error.localizedDescription
        let lower = s.lowercased()
        if isNativeApple, lower.contains("aud") || lower.contains("audience") || lower.contains("issuer") {
            return """
            In Supabase → Auth → Apple, add your app’s bundle ID (e.g. com.socrani.surgeapp) under **Client IDs** so the native Apple ID token is accepted.
            """
        }
        if lower.contains("custom scheme") || (lower.contains("web") && lower.contains("client type")) {
            return """
            For Google this build still uses Supabase web OAuth. For Google: the Web client must list https://YOUR_PROJECT.supabase.co/auth/v1/callback.
            """
        }
        if lower.contains("audience") || lower.contains("unacceptable") {
            return """
            In Supabase → Auth, check the provider (Google web client, or Apple bundle ID in Client IDs for native). Allow OAuth redirects in URL Configuration for Google.
            """
        }
        if lower.contains("redirect") || lower.contains("redirect_uri") {
            return """
            In Supabase → Auth → URL Configuration, add: com.socrani.surgeapp://** (or exactly com.socrani.surgeapp://auth-callback). site URL can stay https://socrani.com
            """
        }
        if lower.contains("nonce") || lower.contains("invalid nonce") {
            return "If you see a nonce error on Apple, update Supabase — native Sign in with Apple may require matching nonce configuration."
        }
        return s
    }

    func signOut() async {
        lastError = nil
        guard let client else { return }
        do {
            serverSyncedUser = nil
            clearPublicUserProfile()
            try await client.auth.signOut()
            UserDefaults.standard.set(false, forKey: Self.hasCompletedOnboardingKey)
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Permanently deletes the signed-in user’s `public.users` row, app study data (cascades with auth user), and `auth.users`.
    /// See migration `20260428_delete_account_and_data`. Returns `nil` on success, or a short error string.
    @discardableResult
    func deleteAccount() async -> String? {
        lastError = nil
        guard let client else { return "Supabase is not configured." }
        guard let uid = session?.user.id else { return "Not signed in." }
        do {
            UserDefaults.standard.removeObject(forKey: Self.siwaDisplayNameKey(uid))
            _ = try await client.rpc("delete_account_and_data").execute()
            serverSyncedUser = nil
            clearPublicUserProfile()
            UserDefaults.standard.set(false, forKey: Self.hasCompletedOnboardingKey)
            // Auth row is gone; clear local session (may 401 if the session is already invalid).
            try? await client.auth.signOut()
        } catch {
            let msg = (error as NSError).localizedDescription
            lastError = msg
            Self.log.error("deleteAccount: \(msg, privacy: .public)")
            return msg
        }
        return nil
    }

    /// Same key as `@AppStorage("hasCompletedOnboarding")` in `surgeappApp` — sign-out sends users through onboarding again.
    private static let hasCompletedOnboardingKey = "hasCompletedOnboarding"

    private static func siwaDisplayNameKey(_ id: UUID) -> String {
        "com.socrani.surgeapp.siwa_display_name_\(id.uuidString)"
    }

    /// `PersonNameComponents.formatter` / `formatted` can be empty for some component combinations; this matches the system address-book style.
    private static func displayNameFromApplePersonNameComponents(_ name: PersonNameComponents) -> String? {
        let f = PersonNameComponentsFormatter()
        f.style = .default
        var s = f.string(from: name).trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty {
            s = [name.givenName, name.middleName, name.familyName]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
        }
        return s.isEmpty ? nil : s
    }

    /// If there is no row yet, inserts `active` / `free`. Skips when a row already exists for this
    /// auth id, `user_id`, or email (avoids a second row for the same person).
    private func ensureUserRowInDatabase(client: SupabaseClient, session: Session) async {
        let user = session.user
        do {
            if try await hasExistingUserRow(client: client, user: user) { return }

            let meta = user.userMetadata
            let name = meta["name"]?.stringValue ?? meta["full_name"]?.stringValue
            let fullName = meta["full_name"]?.stringValue ?? name
            let avatar = meta["avatar_url"]?.stringValue ?? meta["picture"]?.stringValue
            let emailTrimmed = user.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email: String? = (emailTrimmed?.isEmpty == false) ? emailTrimmed : nil
            let tokenId = email ?? user.id.uuidString
            let row = NewPublicUserRow(
                id: user.id,
                userId: user.id.uuidString,
                email: email,
                name: name,
                fullName: fullName,
                avatarUrl: avatar,
                tokenIdentifier: tokenId,
                subscriptionStatus: "active",
                subscriptionType: "free"
            )
            try await client.from("users").insert(row).execute()
        } catch {
            Self.log.error("public.users row sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func hasExistingUserRow(client: SupabaseClient, user: User) async throws -> Bool {
        if try await hasRow(matching: { $0.eq("id", value: user.id) }, client: client) { return true }
        if try await hasRow(matching: { $0.eq("user_id", value: user.id.uuidString) }, client: client) { return true }
        if let email = user.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty,
           try await hasRow(matching: { $0.eq("email", value: email) }, client: client) {
            return true
        }
        return false
    }

    private func hasRow(
        matching applyFilter: (PostgrestFilterBuilder) -> PostgrestFilterBuilder,
        client: SupabaseClient
    ) async throws -> Bool {
        var builder: PostgrestFilterBuilder = client
            .from("users")
            .select("id")
        builder = applyFilter(builder)
        let rows: [UserIdOnlyRow] = try await builder
            .limit(1)
            .execute()
            .value
        return !rows.isEmpty
    }
}

// MARK: - public.users (Supabase)

private struct UserIdOnlyRow: Decodable {
    let id: UUID
}

private struct PublicUserProfileRow: Decodable {
    let name: String?
    let fullName: String?
    let subscriptionStatus: String?
    let subscriptionType: String?
    enum CodingKeys: String, CodingKey {
        case name
        case fullName = "full_name"
        case subscriptionStatus = "subscription_status"
        case subscriptionType = "subscription_type"
    }
}

private struct NewPublicUserRow: Encodable {
    let id: UUID
    let userId: String
    let email: String?
    let name: String?
    let fullName: String?
    let avatarUrl: String?
    let tokenIdentifier: String
    let subscriptionStatus: String
    let subscriptionType: String
    enum CodingKeys: String, CodingKey {
        case id, email, name, avatarUrl = "avatar_url", fullName = "full_name", userId = "user_id"
        case tokenIdentifier = "token_identifier", subscriptionStatus = "subscription_status", subscriptionType = "subscription_type"
    }
}

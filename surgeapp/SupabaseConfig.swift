//
//  SupabaseConfig.swift
//  surgeapp
//

import Foundation

/// Reads Supabase project credentials from `Info.plist`.
/// Set `SupabaseURL` and `SupabaseAnonKey` in Config/Info.plist (see keys below).
enum SupabaseConfig {
    static var supabaseURL: URL? {
        rawURL(fromPlistKey: "SupabaseURL")
    }

    static var supabaseAnonKey: String? {
        let s = string(fromPlistKey: "SupabaseAnonKey")
        guard let s, !s.isEmpty, !s.contains("YOUR_") else { return nil }
        return s
    }

    /// Optional. Only if you add native Google Sign-In later; the OAuth browser flow does not use this.
    static var googleClientID: String? {
        string(fromPlistKey: "GoogleClientID", rejectPlaceholder: true)
    }

    /// Optional, legacy field for reference; not read by the Supabase OAuth path.
    static var googleServerClientID: String? {
        string(fromPlistKey: "GoogleServerClientID", rejectPlaceholder: true)
    }

    /// Must match a URL type in Info.plist and an allowed redirect URL in the Supabase dashboard
    /// (Authentication → URL Configuration) for OAuth.
    static var oauthRedirectURL: URL {
        URL(string: "com.socrani.surgeapp://auth-callback")!
    }

    private static func rawURL(fromPlistKey key: String) -> URL? {
        guard let s = string(fromPlistKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !s.isEmpty,
              !s.contains("YOUR_")
        else { return nil }
        return URL(string: s)
    }

    private static func string(fromPlistKey key: String, rejectPlaceholder: Bool = false) -> String? {
        guard let s = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !s.isEmpty
        else { return nil }
        if rejectPlaceholder, s.contains("YOUR_") { return nil }
        return s
    }
}

//
//  Config.example.swift
//  surgeapp
//
//  Copy this file to Config.swift and add your actual API keys
//  Config.swift is gitignored and will not be committed to GitHub
//

import Foundation

// Fly.io: set Info.plist key `FlyServiceBaseURL` (default is socrani-api-proxy.fly.dev). See FlyService.swift.
// Supabase: set `SupabaseURL` and `SupabaseAnonKey` in Config/Info.plist (not this file). See SupabaseConfig.swift.

struct Config {
    static let supabaseURL = "YOUR_SUPABASE_URL_HERE"
    static let supabaseKey = "YOUR_SUPABASE_ANON_KEY_HERE"
    static let apifyToken = "YOUR_APIFY_API_TOKEN_HERE"
    static let hunterApiKey = "YOUR_HUNTER_API_KEY_HERE"
    static let serpApiKey = "YOUR_SERPAPI_KEY_HERE"
    static let openAIKey = "YOUR_OPENAI_API_KEY_HERE"
    static let googleClientID = "YOUR_GOOGLE_CLIENT_ID_HERE"
}


//
//  surgeappApp.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SuperwallKit
import SwiftUI

@main
struct surgeappApp: App {
    @StateObject private var store = StudyStore()
    @StateObject private var auth = AuthSessionManager()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let options = SuperwallOptions()
        // Required for real App Store / Sandbox purchases. Default `.automatic` turns on Test mode
        // (simulated “SUPERWALL” sheet) when bundle ID doesn’t match the dashboard or for test users.
        options.testModeBehavior = .never
        Superwall.configure(apiKey: "pk__dM27Q_hpwnEDIlXZ6sYn", options: options)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if !auth.isReady {
                    ProgressView("Loading…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.white)
                        .preferredColorScheme(.light)
                } else if auth.isAuthenticated {
                    ContentView()
                        .environmentObject(store)
                        .environmentObject(auth)
                        .preferredColorScheme(.light)
                } else if !hasCompletedOnboarding {
                    OnboardingCarouselView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .environmentObject(store)
                } else if auth.isSupabaseConfigured {
                    SignInView()
                        .environmentObject(auth)
                        .preferredColorScheme(.light)
                } else {
                    ContentView()
                        .environmentObject(store)
                        .environmentObject(auth)
                        .preferredColorScheme(.light)
                }
            }
            .onOpenURL { url in
                auth.handleOpenURL(url)
            }
            .onChange(of: auth.isAuthenticated) { _, isAuthed in
                if !isAuthed, auth.isSupabaseConfigured {
                    store.clearCloudDataAndResetLocal()
                }
            }
        }
    }
}

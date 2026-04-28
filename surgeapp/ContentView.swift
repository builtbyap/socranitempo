//
//  ContentView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: StudyStore
    @EnvironmentObject private var auth: AuthSessionManager
    @State private var selectedScreen: AppScreen = .notes
    @State private var isAskSearchPresented = false
    @State private var askSearchText = ""
    /// Fires `campaign_trigger` once per `ContentView` lifetime (main app shell after sign-in).
    @State private var didRegisterCampaignTrigger = false

    private var showMainTabTitleBar: Bool {
        !(selectedScreen == .study && store.hidesStudyTabTitleBarForSession)
    }

    private var hideTabBarForImmersiveStudy: Bool {
        selectedScreen == .study && store.hidesStudyTabTitleBarForSession
    }

    var body: some View {
        VStack(spacing: 0) {
            if showMainTabTitleBar {
                TabTitleBar(
                    selectedScreen: $selectedScreen,
                    isAskSearchPresented: $isAskSearchPresented,
                    askSearchText: $askSearchText
                )
                .padding(.horizontal, isAskSearchPresented ? 0 : 16)
                .padding(.top, 8)
                .padding(.bottom, isAskSearchPresented ? 0 : 12)
                .zIndex(1)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                tabbedRoot

                if isAskSearchPresented {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea(edges: [.horizontal, .bottom])
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isAskSearchPresented = false
                                askSearchText = ""
                            }
                        }
                        .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.2), value: isAskSearchPresented)
            .animation(.easeInOut(duration: 0.22), value: showMainTabTitleBar)
        }
        .background(Color.white)
        .preferredColorScheme(.light)
        .onAppear {
            guard !didRegisterCampaignTrigger else { return }
            didRegisterCampaignTrigger = true
            registerSuperwallPlacement(SuperwallPlacements.campaignTrigger)
        }
        .onAppear {
            store.freeTierAuth = auth
        }
        .onChange(of: auth.syncUserId) { _, _ in
            store.freeTierAuth = auth
        }
        .onChange(of: selectedScreen) { _, new in
            if new != .study {
                store.hidesStudyTabTitleBarForSession = false
            }
        }
        .task(id: auth.syncUserId) {
            if !auth.isSupabaseConfigured {
                store.configureCloudSync(client: nil, userId: nil)
                store.loadDemoDataIfEmpty()
                return
            }
            guard let uid = auth.syncUserId, let client = auth.client else {
                store.configureCloudSync(client: nil, userId: nil)
                return
            }
            store.configureCloudSync(client: client, userId: uid)
            await store.mergeCloudDataFromOtherAccountsWithSameEmail()
            await store.loadFromCloud()
        }
    }

    @ViewBuilder
    private var tabbedRoot: some View {
        TabView(selection: $selectedScreen) {
            ForEach(AppScreen.allCases) { screen in
                Group {
                    switch screen {
                    case .notes: NotesView()
                    case .study: StudyView()
                    case .assistant: AssistantView()
                    case .profile: ProfileView()
                    }
                }
                .tag(screen)
                .tabItem {
                    Label(screen.title, systemImage: screen.menuSymbol)
                }
            }
        }
        .tint(Color(red: 0.45, green: 0.32, blue: 0.78))
        .toolbar(hideTabBarForImmersiveStudy ? .hidden : .automatic, for: .tabBar)
    }
}

#Preview {
    ContentView()
        .environmentObject(StudyStore())
        .environmentObject(AuthSessionManager())
}

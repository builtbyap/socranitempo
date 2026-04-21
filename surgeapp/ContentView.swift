//
//  ContentView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = StudyStore()
    @State private var selectedScreen: AppScreen = .notes
    @State private var isAskSearchPresented = false
    @State private var askSearchText = ""

    private var showMainTabTitleBar: Bool {
        !(selectedScreen == .study && store.hidesStudyTabTitleBarForSession)
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
                Group {
                    switch selectedScreen {
                    case .notes:
                        NotesView()
                    case .study:
                        StudyView()
                    case .assistant:
                        AssistantView()
                    case .library:
                        LibraryView()
                    }
                }

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
        .environmentObject(store)
        .onChange(of: selectedScreen) { _, new in
            if new != .study {
                store.hidesStudyTabTitleBarForSession = false
            }
        }
    }
}

#Preview {
    ContentView()
}

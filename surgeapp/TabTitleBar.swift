//
//  TabTitleBar.swift
//  surgeapp
//

import SwiftUI

/// Centered title + FREE badge + search; section switching lives in the ⋯ menu.
struct TabTitleBar: View {
    @Binding var selectedScreen: AppScreen
    @Binding var isAskSearchPresented: Bool
    @Binding var askSearchText: String
    @FocusState private var askFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isAskSearchPresented {
                HStack(alignment: .center, spacing: 10) {
                    Button {
                        askSearchText = ""
                        isAskSearchPresented = false
                        askFieldFocused = false
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")

                    TextField("Ask me anything", text: $askSearchText)
                        .textFieldStyle(.plain)
                        .focused($askFieldFocused)
                        .submitLabel(.search)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.regularMaterial)
                        )
                }
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                HStack {
                    trailingActions
                        .opacity(0)
                        .allowsHitTesting(false)

                    Spacer()

                    titleBadge

                    Spacer()

                    trailingActions
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.bottom, isAskSearchPresented ? 12 : 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if isAskSearchPresented {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: [.top, .horizontal])
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isAskSearchPresented)
    }

    private var titleBadge: some View {
        HStack(spacing: 8) {
            Text(selectedScreen.title)
                .font(.system(size: 28, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)

            Text("FREE")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.15))
                .clipShape(Capsule())
                .offset(y: 2)
        }
    }

    private var trailingActions: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isAskSearchPresented.toggle()
                    if isAskSearchPresented {
                        askFieldFocused = true
                    } else {
                        askSearchText = ""
                        askFieldFocused = false
                    }
                }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            Menu {
                ForEach(AppScreen.allCases) { screen in
                    Button {
                        selectedScreen = screen
                    } label: {
                        Label(screen.title, systemImage: screen.menuSymbol)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
    }
}

#Preview {
    TabTitleBarPreview()
}

private struct TabTitleBarPreview: View {
    @State private var screen = AppScreen.notes
    @State private var showAsk = false
    @State private var askText = ""

    var body: some View {
        TabTitleBar(selectedScreen: $screen, isAskSearchPresented: $showAsk, askSearchText: $askText)
            .padding()
    }
}

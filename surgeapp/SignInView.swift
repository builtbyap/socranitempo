//
//  SignInView.swift
//  surgeapp
//

import SwiftUI

private enum SignInScreenTheme {
    static let background = Color.white
    static let accent = Color(red: 0.54, green: 0.39, blue: 0.82)
    static let secondaryText = Color(red: 0.44, green: 0.44, blue: 0.46)
    static let buttonFill = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let buttonBorder = Color.black.opacity(0.10)
    static let hasCompletedOnboardingKey = "hasCompletedOnboarding"
}

struct SignInView: View {
    @EnvironmentObject private var auth: AuthSessionManager
    @State private var activeProvider: SignInProvider?

    private var isBusy: Bool { activeProvider != nil }

    var body: some View {
        ZStack {
            SignInScreenTheme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                // Title block — left-aligned under the back arrow
                VStack(alignment: .leading, spacing: 6) {
                    Text("Create Your Account")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.black)

                    Text("Last step before you get started!")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(SignInScreenTheme.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Logo centred in the remaining space
                Image("SocraniLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)

                Spacer()

                if !auth.isSupabaseConfigured {
                    Text("Add SupabaseURL and SupabaseAnonKey to Info.plist to enable sign-in.")
                        .font(.subheadline)
                        .foregroundStyle(SignInScreenTheme.secondaryText)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 12)
                }

                if let err = auth.lastError {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(.red.opacity(0.95))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.bottom, 12)
                }

                VStack(spacing: 12) {
                    providerButton(provider: .google, title: "Continue with Google") {
                        GoogleGMark()
                    }
                    providerButton(provider: .apple, title: "Continue with Apple") {
                        Image(systemName: "apple.logo")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 48)
            }
        }
        .preferredColorScheme(.light)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                UserDefaults.standard.set(false, forKey: SignInScreenTheme.hasCompletedOnboardingKey)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Back to onboarding")
            // Onboarding is complete — track + full purple fill
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.black.opacity(0.08))
                    Capsule()
                        .fill(SignInScreenTheme.accent)
                        .frame(width: geo.size.width)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func providerButton<Icon: View>(
        provider: SignInProvider,
        title: String,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        let busyHere = activeProvider == provider
        Button {
            activeProvider = provider
            Task {
                switch provider {
                case .google: await auth.signInWithGoogle()
                case .apple: await auth.signInWithApple()
                }
                activeProvider = nil
            }
        } label: {
            HStack(spacing: 14) {
                if busyHere {
                    ProgressView()
                        .tint(.white)
                        .frame(width: 28, height: 28)
                } else {
                    icon()
                }
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(SignInScreenTheme.buttonFill)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(SignInScreenTheme.buttonBorder, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!auth.isSupabaseConfigured || isBusy)
        .opacity(auth.isSupabaseConfigured ? 1 : 0.5)
    }
}

private enum SignInProvider: Hashable {
    case google, apple
}

// MARK: - Google “G” (simplified mark)

private struct GoogleGMark: View {
    var body: some View {
        Text("G")
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        Color(red: 0.26, green: 0.52, blue: 0.96),
                        Color(red: 0.22, green: 0.59, blue: 0.25),
                        Color(red: 0.98, green: 0.74, blue: 0.02),
                        Color(red: 0.92, green: 0.25, blue: 0.21),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 28, height: 28)
    }
}

// MARK: - Decorative wave

private struct PurpleDotWave: View {
    var accent: Color
    private let dotCount = 26

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<dotCount, id: \.self) { i in
                let t = Double(i) / Double(max(dotCount - 1, 1))
                let amp = sin(t * .pi * 3.5) * 11
                Circle()
                    .fill(accent.opacity(0.32 + Double(i % 4) * 0.1))
                    .frame(width: 5, height: 5)
                    .shadow(color: accent.opacity(0.4), radius: 3, y: 0)
                    .offset(y: CGFloat(amp))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
    }
}

#Preview {
    SignInView()
        .environmentObject(AuthSessionManager())
}

//
//  AppleSignInCoordinator.swift
//  surgeapp
//

import AuthenticationServices
import UIKit

/// Presents the **native** Sign in with Apple dialog (not the in-app web OAuth to supabase.co).
enum AppleSignInCoordinator {
    @MainActor
    static func perform() async throws -> ASAuthorization {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let session = ASAuthorizationControllerSession(controller: controller)
        return try await session.start()
    }

    private final class ASAuthorizationControllerSession: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        private var continuation: CheckedContinuation<ASAuthorization, Error>?
        private let controller: ASAuthorizationController

        init(controller: ASAuthorizationController) {
            self.controller = controller
            super.init()
        }

        func start() async throws -> ASAuthorization {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ASAuthorization, Error>) in
                self.continuation = continuation
                self.controller.delegate = self
                self.controller.presentationContextProvider = self
                self.controller.performRequests()
            }
        }

        // MARK: ASAuthorizationControllerDelegate

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            self.controller.delegate = nil
            self.controller.presentationContextProvider = nil
            continuation?.resume(returning: authorization)
            continuation = nil
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            self.controller.delegate = nil
            self.controller.presentationContextProvider = nil
            continuation?.resume(throwing: error)
            continuation = nil
        }

        // MARK: ASAuthorizationControllerPresentationContextProviding

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            let active = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
            if let s = active {
                if let w = s.keyWindow { return w }
                if let w = s.windows.first(where: \.isKeyWindow) { return w }
                if let w = s.windows.first { return w }
            }
            if let w = scenes.flatMap(\.windows).first { return w }
            assertionFailure("No UIWindow for Sign in with Apple")
            if let s = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                return UIWindow(windowScene: s)
            }
            fatalError("No UIWindowScene for Sign in with Apple")
        }
    }
}

extension UIWindowScene {
    fileprivate var keyWindow: UIWindow? { windows.first { $0.isKeyWindow } }
}

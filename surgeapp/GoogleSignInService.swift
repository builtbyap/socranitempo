//
//  GoogleSignInService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation
import Combine
import GoogleSignIn

class GoogleSignInService: ObservableObject {
    static let shared = GoogleSignInService()
    
    @Published var isSignedIn = false
    @Published var currentUser: GIDGoogleUser?
    
    // You'll need to add your Google Client ID from Google Cloud Console
    // Add it to Config.swift as: static let googleClientID = "YOUR_CLIENT_ID"
    private let clientID = Config.googleClientID
    
    private init() {
        configureGoogleSignIn()
    }
    
    private func configureGoogleSignIn() {
        guard clientID != "YOUR_GOOGLE_CLIENT_ID" else {
            print("⚠️ Google Client ID not configured. Please add it to Config.swift")
            return
        }
        
        // Configure GIDSignIn with client ID
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
    }
    
    func signIn(completion: @escaping (Bool, Error?) -> Void) {
        guard clientID != "YOUR_GOOGLE_CLIENT_ID" else {
            completion(false, NSError(domain: "GoogleSignIn", code: -1, userInfo: [NSLocalizedDescriptionKey: "Google Client ID not configured"]))
            return
        }
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            completion(false, NSError(domain: "GoogleSignIn", code: -2, userInfo: [NSLocalizedDescriptionKey: "Could not find root view controller"]))
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            guard let user = result?.user else {
                completion(false, NSError(domain: "GoogleSignIn", code: -3, userInfo: [NSLocalizedDescriptionKey: "Sign in failed"]))
                return
            }
            
            self?.currentUser = user
            self?.isSignedIn = true
            completion(true, nil)
        }
    }
    
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        currentUser = nil
        isSignedIn = false
    }
    
    func getAccessToken() -> String? {
        return currentUser?.accessToken.tokenString
    }
}


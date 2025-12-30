//
//  surgeappApp.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI
import GoogleSignIn
import UserNotifications

@main
struct surgeappApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Configure Google Sign-In
        let clientID = Config.googleClientID
        if clientID != "YOUR_GOOGLE_CLIENT_ID" {
            let config = GIDConfiguration(clientID: clientID)
            GIDSignIn.sharedInstance.configuration = config
        }
        
        // Request notification permissions
        requestNotificationPermissions()
        
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = self
        
        // Start email monitoring (checks Supabase database for new emails)
        // No Gmail authentication needed - Edge Function handles Gmail API
        GmailMonitoringService.shared.startMonitoring(interval: 300) // Check every 5 minutes
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
    
    // MARK: - Notification Permissions
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else if let error = error {
                print("⚠️ Notification permission error: \(error.localizedDescription)")
            } else {
                print("⚠️ Notification permissions denied")
            }
        }
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // Handle notification tap
        let userInfo = response.notification.request.content.userInfo
        if let emailId = userInfo["emailId"] as? String {
            print("📧 User tapped notification for email: \(emailId)")
            // You can navigate to the email detail view here
            NotificationCenter.default.post(
                name: NSNotification.Name("ShowApplicationEmail"),
                object: nil,
                userInfo: ["emailId": emailId]
            )
        }
        completionHandler()
    }
}

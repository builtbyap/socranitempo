//
//  GmailMonitoringService.swift
//  surgeapp
//
//  Service to monitor Gmail inbox for application confirmation emails
//

import Foundation
import UserNotifications

class GmailMonitoringService {
    static let shared = GmailMonitoringService()
    
    private let gmailAPIBaseURL = "https://gmail.googleapis.com/gmail/v1"
    private let monitoredEmail = "thesocrani@gmail.com"
    private var accessToken: String?
    private var refreshToken: String?
    private var lastCheckedMessageId: String?
    
    private init() {
        loadTokens()
    }
    
    // MARK: - Token Management
    func setAccessToken(_ token: String) {
        accessToken = token
        UserDefaults.standard.set(token, forKey: "gmail_access_token")
    }
    
    func setRefreshToken(_ token: String) {
        refreshToken = token
        UserDefaults.standard.set(token, forKey: "gmail_refresh_token")
    }
    
    private func loadTokens() {
        accessToken = UserDefaults.standard.string(forKey: "gmail_access_token")
        refreshToken = UserDefaults.standard.string(forKey: "gmail_refresh_token")
        lastCheckedMessageId = UserDefaults.standard.string(forKey: "gmail_last_checked_message_id")
    }
    
    // MARK: - Gmail API Authentication
    func authenticateWithGmail() async throws -> String {
        // This should open a web view for OAuth authentication
        // For now, return a placeholder - you'll need to implement OAuth flow
        guard let token = accessToken else {
            throw GmailError.notAuthenticated
        }
        return token
    }
    
    // MARK: - Check for New Emails from Database
    func checkForNewApplicationEmails() async throws -> [ApplicationEmail] {
        // Check Supabase database for new emails (saved by Edge Function)
        let allEmails = try await SupabaseService.shared.fetchApplicationEmails()
        
        // Get list of emails we've already notified about
        let notifiedEmailIds = getNotifiedEmailIds()
        
        // Filter for new emails (ones we haven't notified about yet)
        let newEmails = allEmails.filter { email in
            !notifiedEmailIds.contains(email.id)
        }
        
        print("📧 Found \(newEmails.count) new application emails (out of \(allEmails.count) total)")
        
        return newEmails
    }
    
    // MARK: - Track Notified Emails
    private func getNotifiedEmailIds() -> Set<String> {
        if let data = UserDefaults.standard.data(forKey: "notified_email_ids"),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            return ids
        }
        return []
    }
    
    private func markEmailAsNotified(_ emailId: String) {
        var notifiedIds = getNotifiedEmailIds()
        notifiedIds.insert(emailId)
        
        if let data = try? JSONEncoder().encode(notifiedIds) {
            UserDefaults.standard.set(data, forKey: "notified_email_ids")
        }
    }
    
    // MARK: - Fetch Message Details
    private func fetchMessageDetails(messageId: String, token: String) async throws -> ApplicationEmail {
        let messageURL = "\(gmailAPIBaseURL)/users/me/messages/\(messageId)"
        
        var request = URLRequest(url: URL(string: messageURL)!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw GmailError.apiError("Failed to fetch message details")
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let payload = json["payload"] as? [String: Any],
              let headers = payload["headers"] as? [[String: Any]] else {
            throw GmailError.parsingError
        }
        
        var from = ""
        var subject = ""
        var date = ""
        var body = ""
        
        for header in headers {
            if let name = header["name"] as? String,
               let value = header["value"] as? String {
                switch name.lowercased() {
                case "from":
                    from = value
                case "subject":
                    subject = value
                case "date":
                    date = value
                default:
                    break
                }
            }
        }
        
        // Extract body from payload
        if let bodyParts = payload["body"] as? [String: Any],
           let bodyData = bodyParts["data"] as? String,
           let decodedData = Data(base64Encoded: bodyData),
           let bodyText = String(data: decodedData, encoding: .utf8) {
            body = bodyText
        } else if let parts = payload["parts"] as? [[String: Any]] {
            // Try to get body from parts
            for part in parts {
                if let partBody = part["body"] as? [String: Any],
                   let partData = partBody["data"] as? String,
                   let decodedData = Data(base64Encoded: partData),
                   let partText = String(data: decodedData, encoding: .utf8) {
                    body += partText
                }
            }
        }
        
        return ApplicationEmail(
            id: messageId,
            from: from,
            subject: subject,
            body: body,
            date: date,
            isApplicationConfirmation: isApplicationConfirmationEmail(subject: subject, body: body)
        )
    }
    
    // MARK: - Detect Application Confirmation Emails
    private func isApplicationConfirmationEmail(_ email: ApplicationEmail) -> Bool {
        return isApplicationConfirmationEmail(subject: email.subject, body: email.body)
    }
    
    private func isApplicationConfirmationEmail(subject: String, body: String) -> Bool {
        let subjectLower = subject.lowercased()
        let bodyLower = body.lowercased()
        
        // Keywords that indicate application confirmation
        let confirmationKeywords = [
            "application received",
            "thank you for applying",
            "application submitted",
            "we received your application",
            "application confirmation",
            "your application has been",
            "application status",
            "application update",
            "next steps",
            "interview",
            "screening",
            "application review"
        ]
        
        for keyword in confirmationKeywords {
            if subjectLower.contains(keyword) || bodyLower.contains(keyword) {
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Send Push Notification
    func sendNotificationForEmail(_ email: ApplicationEmail) {
        let content = UNMutableNotificationContent()
        content.title = "New Application Confirmation"
        content.body = "\(email.from): \(email.subject)"
        content.sound = .default
        content.badge = 1
        
        // Add application info to notification
        content.userInfo = [
            "emailId": email.id,
            "from": email.from,
            "subject": email.subject
        ]
        
        let request = UNNotificationRequest(
            identifier: "application_email_\(email.id)",
            content: content,
            trigger: nil // Send immediately
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("⚠️ Failed to send notification: \(error.localizedDescription)")
            } else {
                print("✅ Notification sent for email: \(email.subject)")
            }
        }
    }
    
    // MARK: - Start Monitoring
    func startMonitoring(interval: TimeInterval = 300) { // Check every 5 minutes
        print("📧 Starting email monitoring (checking database every \(interval/60) minutes)")
        
        Task {
            // Check immediately on start
            await checkAndNotify()
            
            // Then check periodically
            while true {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                await checkAndNotify()
            }
        }
    }
    
    // MARK: - Check and Notify
    private func checkAndNotify() async {
        do {
            let newEmails = try await checkForNewApplicationEmails()
            
            for email in newEmails {
                // Send notification
                sendNotificationForEmail(email)
                
                // Mark as notified so we don't notify again
                markEmailAsNotified(email.id)
                
                print("✅ Sent notification for: \(email.subject)")
            }
            
            if newEmails.isEmpty {
                print("📧 No new application emails found")
            }
        } catch {
            print("⚠️ Error checking emails: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Save Email to Database
    private func saveApplicationEmail(_ email: ApplicationEmail) async {
        // Save to Supabase for tracking
        // This allows the app to show email history
        do {
            try await SupabaseService.shared.insertApplicationEmail(email)
        } catch {
            print("⚠️ Failed to save email to database: \(error.localizedDescription)")
        }
    }
}

// MARK: - Application Email Model
struct ApplicationEmail: Identifiable, Codable {
    let id: String
    let from: String
    let subject: String
    let body: String
    let date: String
    let isApplicationConfirmation: Bool
}

// MARK: - Gmail Error
enum GmailError: LocalizedError {
    case notAuthenticated
    case apiError(String)
    case parsingError
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Gmail API is not authenticated. Please sign in with Google."
        case .apiError(let message):
            return "Gmail API error: \(message)"
        case .parsingError:
            return "Failed to parse email data."
        }
    }
}


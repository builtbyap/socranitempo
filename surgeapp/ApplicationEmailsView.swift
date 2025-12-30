//
//  ApplicationEmailsView.swift
//  surgeapp
//
//  View to display application confirmation emails
//

import SwiftUI

struct ApplicationEmailsView: View {
    @State private var emails: [ApplicationEmail] = []
    @State private var loading = false
    @State private var error: String?
    @State private var isAuthenticated = false
    
    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = error {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                        
                        if error.contains("not authenticated") {
                            Button("Connect Gmail") {
                                authenticateGmail()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    Spacer()
                } else if emails.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "envelope")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No application emails yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Application confirmations will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(emails) { email in
                            ApplicationEmailCard(email: email)
                        }
                    }
                }
            }
            .navigationTitle("Application Emails")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await refreshEmails()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                checkAuthentication()
                Task {
                    await fetchEmails()
                }
            }
        }
    }
    
    private func checkAuthentication() {
        // Check if Gmail is authenticated
        let token = UserDefaults.standard.string(forKey: "gmail_access_token")
        isAuthenticated = token != nil
    }
    
    private func authenticateGmail() {
        // This should open Google Sign-In flow
        // For now, show instructions
        Task {
            // TODO: Implement Google Sign-In with Gmail scopes
            error = "Gmail authentication not yet implemented. Please follow the setup guide."
        }
    }
    
    private func fetchEmails() async {
        loading = true
        error = nil
        
        do {
            let fetchedEmails = try await SupabaseService.shared.fetchApplicationEmails()
            await MainActor.run {
                self.emails = fetchedEmails
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.loading = false
            }
        }
    }
    
    private func refreshEmails() async {
        // Trigger edge function to check for new emails
        guard let url = URL(string: "\(Config.supabaseURL)/functions/v1/gmail-monitor") else {
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse,
               (200...299).contains(httpResponse.statusCode) {
                // Refresh the list
                await fetchEmails()
            }
        } catch {
            print("⚠️ Failed to trigger email check: \(error.localizedDescription)")
        }
    }
}

struct ApplicationEmailCard: View {
    let email: ApplicationEmail
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "envelope.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(email.from)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(email.date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if email.isApplicationConfirmation {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            Text(email.subject)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)
            
            if !email.body.isEmpty {
                Text(email.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    ApplicationEmailsView()
}


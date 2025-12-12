//
//  EmailSearchView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct EmailSearchView: View {
    @State private var emailContacts: [EmailContact] = []
    @State private var savedEmailIds: Set<String> = []
    @State private var loading = false
    @State private var error: String?
    @State private var searchQuery = ""
    @State private var selectedTab = 0
    
    var savedEmails: [EmailContact] {
        emailContacts.filter { savedEmailIds.contains($0.id) }
    }
    
    var filteredEmails: [EmailContact] {
        let emails = selectedTab == 0 ? emailContacts : savedEmails
        guard !searchQuery.isEmpty else { return emails }
        let query = searchQuery.lowercased()
        return emails.filter { contact in
            contact.name.lowercased().contains(query) ||
            contact.email.lowercased().contains(query) ||
            contact.company.lowercased().contains(query)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search emails...", text: $searchQuery)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text("All Emails").tag(0)
                    Text("Saved Emails").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content
                if loading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = error {
                    Spacer()
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    }
                    Spacer()
                } else if filteredEmails.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: selectedTab == 0 ? "envelope" : "star.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(selectedTab == 0 ? "No emails found" : "No saved emails")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredEmails) { contact in
                                EmailContactCard(contact: contact, isSaved: savedEmailIds.contains(contact.id)) {
                                    toggleSave(contact: contact)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Action Button
                Button(action: {
                    if let url = URL(string: "https://n8n.socrani.com/form/6272f3aa-a2f6-417a-9977-2b11ec3488a7") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Email Search")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Email Search")
            .onAppear {
                loadSavedEmails()
                Task {
                    await fetchEmails()
                }
            }
        }
    }
    
    private func toggleSave(contact: EmailContact) {
        if savedEmailIds.contains(contact.id) {
            savedEmailIds.remove(contact.id)
        } else {
            savedEmailIds.insert(contact.id)
        }
        saveSavedEmails()
    }
    
    private func loadSavedEmails() {
        if let data = UserDefaults.standard.data(forKey: "savedEmails"),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            savedEmailIds = Set(ids)
        }
    }
    
    private func saveSavedEmails() {
        if let data = try? JSONEncoder().encode(Array(savedEmailIds)) {
            UserDefaults.standard.set(data, forKey: "savedEmails")
        }
    }
    
    private func fetchEmails() async {
        loading = true
        error = nil
        
        do {
            let contacts = try await SupabaseService.shared.fetchEmailContacts()
            await MainActor.run {
                // Remove duplicates by email address
                var uniqueEmails: [EmailContact] = []
                var seenEmails = Set<String>()
                
                for contact in contacts {
                    if !seenEmails.contains(contact.email) {
                        seenEmails.insert(contact.email)
                        uniqueEmails.append(contact)
                    }
                }
                
                self.emailContacts = uniqueEmails
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.loading = false
                
                // Fallback to sample data if Supabase is not configured
                if error.localizedDescription.contains("not configured") {
                    loadSampleData()
                }
            }
        }
    }
    
    private func loadSampleData() {
        // Sample data for testing (fallback when Supabase is not configured)
        emailContacts = [
            EmailContact(
                id: "1",
                name: "Jane Smith",
                email: "jane.smith@example.com",
                company: "Tech Corp",
                lastContact: "2025-12-01"
            )
        ]
    }
}

struct EmailContactCard: View {
    let contact: EmailContact
    let isSaved: Bool
    let onToggleSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contact.name)
                        .font(.headline)
                    Text(contact.email)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "envelope")
                    .foregroundColor(.secondary)
            }
            
            Text("Company: \(contact.company)")
                .font(.caption)
            
            Text("Last contacted: \(formatDate(contact.lastContact))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: "mailto:\(contact.email)") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("Send Email")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "star.fill" : "star")
                        .foregroundColor(isSaved ? .yellow : .gray)
                        .frame(width: 44, height: 44)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            formatter.dateStyle = .medium
            return formatter.string(from: date)
        }
        return dateString
    }
}

#Preview {
    EmailSearchView()
}


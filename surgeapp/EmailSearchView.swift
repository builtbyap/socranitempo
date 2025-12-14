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
    @State private var showSearchForm = false
    
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
                        LazyVStack(spacing: 20) {
                            ForEach(filteredEmails) { contact in
                                EmailContactCard(contact: contact, isSaved: savedEmailIds.contains(contact.id)) {
                                    toggleSave(contact: contact)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
                
                // Action Button
                Button(action: {
                    showSearchForm = true
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
            .sheet(isPresented: $showSearchForm) {
                EmailSearchFormView()
            }
            .onChange(of: showSearchForm) { oldValue, newValue in
                // Refresh email list when form is dismissed
                if !newValue {
                    Task {
                        await fetchEmails()
                    }
                }
            }
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
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            HStack(alignment: .top, spacing: 12) {
                // Email Avatar
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "envelope.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                }
                
                // Name and Email
                VStack(alignment: .leading, spacing: 6) {
                    Text(contact.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(contact.email)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Save Button
                Button(action: onToggleSave) {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .foregroundColor(isSaved ? .blue : .gray)
                        .font(.system(size: 20))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Info Section
            VStack(alignment: .leading, spacing: 10) {
                // Company
                HStack(spacing: 8) {
                    Image(systemName: "building.2.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    Text(contact.company)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                
                // Last Contacted
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Text("Last contacted \(formatDate(contact.lastContact))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Action Button
            Button(action: {
                if let url = URL(string: "mailto:\(contact.email)") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Send Email")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.green)
                .cornerRadius(10)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            
            if daysAgo == 0 {
                return "today"
            } else if daysAgo == 1 {
                return "yesterday"
            } else if daysAgo < 7 {
                return "\(daysAgo) days ago"
            } else {
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}

#Preview {
    EmailSearchView()
}


//
//  LinkedInSearchView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct LinkedInSearchView: View {
    @State private var profiles: [LinkedInProfile] = []
    @State private var savedProfileIds: Set<String> = []
    @State private var loading = false
    @State private var error: String?
    @State private var searchQuery = ""
    @State private var selectedTab = 0
    @State private var showSearchForm = false
    
    var savedProfiles: [LinkedInProfile] {
        profiles.filter { savedProfileIds.contains($0.id) }
    }
    
    var filteredProfiles: [LinkedInProfile] {
        let profs = selectedTab == 0 ? profiles : savedProfiles
        guard !searchQuery.isEmpty else { return profs }
        let query = searchQuery.lowercased()
        return profs.filter { profile in
            profile.name.lowercased().contains(query) ||
            profile.title.lowercased().contains(query) ||
            profile.company.lowercased().contains(query)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search profiles...", text: $searchQuery)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text("All Profiles").tag(0)
                    Text("Saved Profiles").tag(1)
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
                } else if filteredProfiles.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: selectedTab == 0 ? "person.2" : "star.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(selectedTab == 0 ? "No profiles found" : "No saved profiles")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredProfiles) { profile in
                                LinkedInProfileCard(profile: profile, isSaved: savedProfileIds.contains(profile.id)) {
                                    toggleSave(profile: profile)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Action Button
                Button(action: {
                    showSearchForm = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("LinkedIn Search")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("LinkedIn Search")
            .sheet(isPresented: $showSearchForm) {
                LinkedInSearchFormView()
            }
            .onAppear {
                loadSavedProfiles()
                Task {
                    await fetchProfiles()
                }
            }
        }
    }
    
    private func toggleSave(profile: LinkedInProfile) {
        if savedProfileIds.contains(profile.id) {
            savedProfileIds.remove(profile.id)
        } else {
            savedProfileIds.insert(profile.id)
        }
        saveSavedProfiles()
    }
    
    private func loadSavedProfiles() {
        if let data = UserDefaults.standard.data(forKey: "savedLinkedInProfiles"),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            savedProfileIds = Set(ids)
        }
    }
    
    private func saveSavedProfiles() {
        if let data = try? JSONEncoder().encode(Array(savedProfileIds)) {
            UserDefaults.standard.set(data, forKey: "savedLinkedInProfiles")
        }
    }
    
    private func fetchProfiles() async {
        loading = true
        error = nil
        
        do {
            let fetchedProfiles = try await SupabaseService.shared.fetchLinkedInProfiles()
            await MainActor.run {
                // Filter out profiles with missing required fields
                let validProfiles = fetchedProfiles.filter { profile in
                    !profile.id.isEmpty && !profile.name.isEmpty
                }
                
                self.profiles = validProfiles
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
        profiles = [
            LinkedInProfile(
                id: "1",
                name: "John Doe - Senior Software Engineer",
                title: "Senior Software Engineer",
                company: "Tech Corp",
                connections: 500,
                linkedin: "https://linkedin.com/in/johndoe"
            )
        ]
    }
}

struct LinkedInProfileCard: View {
    let profile: LinkedInProfile
    let isSaved: Bool
    let onToggleSave: () -> Void
    
    var displayName: String {
        if profile.name.contains(" - ") {
            return String(profile.name.split(separator: " - ").first ?? "")
        }
        return profile.name
    }
    
    var displayTitle: String {
        if profile.name.contains(" - ") {
            let parts = profile.name.split(separator: " - ")
            if parts.count > 1 {
                return parts.dropFirst().joined(separator: " - ")
            }
        }
        return profile.title
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.headline)
                    Text(displayTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "person.2")
                    .foregroundColor(.secondary)
            }
            
            Text("Company: \(profile.company)")
                .font(.caption)
            
            HStack(spacing: 12) {
                Button(action: {
                    if let url = URL(string: profile.linkedin) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text("View Profile")
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
}

#Preview {
    LinkedInSearchView()
}


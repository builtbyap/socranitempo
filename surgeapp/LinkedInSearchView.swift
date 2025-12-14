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
                        LazyVStack(spacing: 20) {
                            ForEach(filteredProfiles) { profile in
                                LinkedInProfileCard(profile: profile, isSaved: savedProfileIds.contains(profile.id)) {
                                    toggleSave(profile: profile)
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
            .onChange(of: showSearchForm) { oldValue, newValue in
                // Refresh profiles when form is dismissed
                if !newValue {
                    Task {
                        await fetchProfiles()
                    }
                }
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
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            HStack(alignment: .top, spacing: 12) {
                // Profile Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "person.fill")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                // Name and Title
                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(displayTitle)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
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
                    Text(profile.company)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                
                // Connections (if available)
                if let connections = profile.connections {
                    HStack(spacing: 6) {
                        Image(systemName: "person.2.fill")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text("\(connections) connections")
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Action Button
            Button(action: {
                if let url = URL(string: profile.linkedin) {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "link")
                        .font(.system(size: 14, weight: .semibold))
                    Text("View LinkedIn Profile")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 14)
                .background(Color.blue)
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
}

#Preview {
    LinkedInSearchView()
}


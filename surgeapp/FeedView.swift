//
//  FeedView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct FeedView: View {
    @State private var selectedTab = 0 // 0: Jobs, 1: LinkedIn, 2: Emails
    @State private var jobPosts: [JobPost] = []
    @State private var linkedInProfiles: [LinkedInProfile] = []
    @State private var emailContacts: [EmailContact] = []
    @State private var loading = false
    @State private var error: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text("Jobs").tag(0)
                    Text("LinkedIn").tag(1)
                    Text("Emails").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                .onChange(of: selectedTab) { oldValue, newValue in
                    Task {
                        await fetchData()
                    }
                }
                
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
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            if selectedTab == 0 {
                                // Jobs Feed
                                if jobPosts.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "briefcase.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.secondary)
                                        Text("No jobs in feed")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Text("Job posts will appear here")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 100)
                                } else {
                                    ForEach(jobPosts) { post in
                                        JobPostCard(post: post, isSaved: false, onToggleSave: {})
                                    }
                                }
                            } else if selectedTab == 1 {
                                // LinkedIn Feed
                                if linkedInProfiles.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "person.2.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.secondary)
                                        Text("No LinkedIn profiles in feed")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Text("LinkedIn profiles will appear here")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 100)
                                } else {
                                    ForEach(linkedInProfiles) { profile in
                                        LinkedInProfileCard(profile: profile, isSaved: false, onToggleSave: {})
                                    }
                                }
                            } else {
                                // Emails Feed
                                if emailContacts.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "envelope.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.secondary)
                                        Text("No email contacts in feed")
                                            .font(.headline)
                                            .foregroundColor(.secondary)
                                        Text("Email contacts will appear here")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.top, 100)
                                } else {
                                    ForEach(emailContacts) { contact in
                                        EmailContactCard(contact: contact, isSaved: false, onToggleSave: {})
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Feed")
            .onAppear {
                Task {
                    await fetchData()
                }
            }
            .refreshable {
                await fetchData()
            }
        }
    }
    
    private func fetchData() async {
        loading = true
        error = nil
        
        do {
            switch selectedTab {
            case 0:
                // Fetch Jobs
                let posts = try await SupabaseService.shared.fetchJobPosts()
                await MainActor.run {
                    var uniquePosts: [JobPost] = []
                    var seenIds = Set<String>()
                    
                    for post in posts {
                        if !seenIds.contains(post.id) {
                            seenIds.insert(post.id)
                            uniquePosts.append(post)
                        }
                    }
                    
                    self.jobPosts = uniquePosts
                    self.loading = false
                }
            case 1:
                // Fetch LinkedIn Profiles
                let profiles = try await SupabaseService.shared.fetchLinkedInProfiles()
                await MainActor.run {
                    var uniqueProfiles: [LinkedInProfile] = []
                    var seenIds = Set<String>()
                    
                    for profile in profiles {
                        if !seenIds.contains(profile.id) {
                            seenIds.insert(profile.id)
                            uniqueProfiles.append(profile)
                        }
                    }
                    
                    self.linkedInProfiles = uniqueProfiles
                    self.loading = false
                }
            case 2:
                // Fetch Email Contacts
                let contacts = try await SupabaseService.shared.fetchEmailContacts()
                await MainActor.run {
                    var uniqueContacts: [EmailContact] = []
                    var seenIds = Set<String>()
                    
                    for contact in contacts {
                        if !seenIds.contains(contact.id) {
                            seenIds.insert(contact.id)
                            uniqueContacts.append(contact)
                        }
                    }
                    
                    self.emailContacts = uniqueContacts
                    self.loading = false
                }
            default:
                await MainActor.run {
                    self.loading = false
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.loading = false
            }
        }
    }
}

#Preview {
    FeedView()
}


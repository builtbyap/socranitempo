//
//  JobSearchView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct JobSearchView: View {
    @State private var jobPosts: [JobPost] = []
    @State private var savedPostIds: Set<String> = []
    @State private var loading = false
    @State private var error: String?
    @State private var searchQuery = ""
    @State private var selectedTab = 0
    
    var savedPosts: [JobPost] {
        jobPosts.filter { savedPostIds.contains($0.id) }
    }
    
    var filteredPosts: [JobPost] {
        let posts = selectedTab == 0 ? jobPosts : savedPosts
        guard !searchQuery.isEmpty else { return posts }
        let query = searchQuery.lowercased()
        return posts.filter { post in
            post.title.lowercased().contains(query) ||
            post.company.lowercased().contains(query) ||
            post.location.lowercased().contains(query) ||
            (post.description?.lowercased().contains(query) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search jobs...", text: $searchQuery)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top)
                
                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text("All Jobs").tag(0)
                    Text("Saved Jobs").tag(1)
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
                } else if filteredPosts.isEmpty {
                    Spacer()
                    VStack {
                        Image(systemName: selectedTab == 0 ? "briefcase" : "star.fill")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text(selectedTab == 0 ? "No job posts found" : "No saved jobs")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredPosts) { post in
                                JobPostCard(post: post, isSaved: savedPostIds.contains(post.id)) {
                                    toggleSave(post: post)
                                }
                            }
                        }
                        .padding()
                    }
                }
                
                // Action Button
                Button(action: {
                    if let url = URL(string: "https://n8n.socrani.com/form/job-search-form") {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Job Search")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Job Search")
            .onAppear {
                loadSavedPosts()
                Task {
                    await fetchJobPosts()
                }
            }
        }
    }
    
    private func toggleSave(post: JobPost) {
        if savedPostIds.contains(post.id) {
            savedPostIds.remove(post.id)
        } else {
            savedPostIds.insert(post.id)
        }
        saveSavedPosts()
    }
    
    private func loadSavedPosts() {
        if let data = UserDefaults.standard.data(forKey: "savedJobPosts"),
           let ids = try? JSONDecoder().decode([String].self, from: data) {
            savedPostIds = Set(ids)
        }
    }
    
    private func saveSavedPosts() {
        if let data = try? JSONEncoder().encode(Array(savedPostIds)) {
            UserDefaults.standard.set(data, forKey: "savedJobPosts")
        }
    }
    
    private func fetchJobPosts() async {
        loading = true
        error = nil
        
        do {
            let posts = try await SupabaseService.shared.fetchJobPosts()
            await MainActor.run {
                // Remove duplicates by email/ID if needed
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
                
                // Load saved posts after fetching
                if !uniquePosts.isEmpty {
                    let savedItems = uniquePosts.filter { savedPostIds.contains($0.id) }
                    // Update saved posts if needed
                }
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
        jobPosts = [
            JobPost(
                id: "1",
                title: "Software Engineer",
                company: "Tech Corp",
                location: "San Francisco, CA",
                postedDate: "2025-12-01",
                description: "Looking for an experienced software engineer",
                url: "https://example.com/job/1",
                salary: "$120k - $150k",
                jobType: "Full-time"
            )
        ]
    }
}

struct JobPostCard: View {
    let post: JobPost
    let isSaved: Bool
    let onToggleSave: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(post.title)
                        .font(.headline)
                    Text(post.company)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "briefcase")
                    .foregroundColor(.secondary)
            }
            
            Text("Location: \(post.location)")
                .font(.caption)
            
            if let salary = post.salary {
                Text("Salary: \(salary)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let jobType = post.jobType {
                Text("Type: \(jobType)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Text("Posted: \(formatDate(post.postedDate))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                if let url = post.url, !url.isEmpty {
                    Button(action: {
                        if let url = URL(string: url) {
                            UIApplication.shared.open(url)
                        }
                    }) {
                        Text("View Details")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                } else {
                    Text("No Link")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.gray)
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
    JobSearchView()
}


//
//  JobSearchView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct JobSearchView: View {
    @State private var jobPosts: [JobPost] = []
    @State private var swipeablePosts: [JobPost] = [] // Posts available for swiping
    @State private var savedPostIds: Set<String> = []
    @State private var loading = false
    @State private var error: String?
    @State private var searchQuery = ""
    @State private var selectedTab = 0
    @State private var showSearchForm = false
    @State private var showApplicationSuccess = false
    @State private var appliedJobTitle: String = ""
    
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
                    if selectedTab == 0 {
                        // Swipeable card stack for "All Jobs"
                        GeometryReader { geometry in
                            ZStack {
                                ForEach(Array(swipeablePosts.enumerated()), id: \.element.id) { index, post in
                                    if index < 3 { // Show max 3 cards at once
                                        SwipeableJobCardView(
                                            post: post,
                                            onApply: {
                                                applyToJob(post: post)
                                            },
                                            onPass: {
                                                passJob(post: post)
                                            }
                                        )
                                        .zIndex(Double(swipeablePosts.count - index))
                                        .offset(y: CGFloat(index) * 8)
                                        .scaleEffect(1.0 - CGFloat(index) * 0.03)
                                        .opacity(index == 0 ? 1.0 : 0.95)
                                    }
                                }
                                
                                if swipeablePosts.isEmpty {
                                    VStack(spacing: 16) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.green)
                                        Text("You've reviewed all jobs!")
                                            .font(.headline)
                                        Text("Pull down to refresh or search for more jobs")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                    }
                                    .padding()
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                        }
                        .padding()
                    } else {
                        // List view for "Saved Jobs"
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                ForEach(filteredPosts) { post in
                                    JobPostCard(post: post, isSaved: savedPostIds.contains(post.id)) {
                                        toggleSave(post: post)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                    }
                }
                
                // Action Button
                Button(action: {
                    showSearchForm = true
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
            .sheet(isPresented: $showSearchForm) {
                JobSearchFormView()
            }
            .onChange(of: showSearchForm) { oldValue, newValue in
                // Refresh job posts when form is dismissed
                if !newValue {
                    Task {
                        await fetchJobPosts()
                    }
                }
            }
            .alert("Application Submitted!", isPresented: $showApplicationSuccess) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("You've successfully applied to \(appliedJobTitle)")
            }
            .onAppear {
                loadSavedPosts()
                Task {
                    await fetchJobPosts()
                }
            }
            .refreshable {
                await fetchJobPosts()
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
                // Initialize swipeable posts (exclude already applied jobs)
                self.swipeablePosts = uniquePosts
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
    
    private func applyToJob(post: JobPost) {
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                let application = Application(
                    id: UUID().uuidString,
                    jobPostId: post.id,
                    jobTitle: post.title,
                    company: post.company,
                    status: "applied",
                    appliedDate: dateFormatter.string(from: Date()),
                    resumeUrl: nil // TODO: Get from uploaded resume
                )
                
                try await SupabaseService.shared.insertApplication(application)
                
                // Remove from swipeable posts
                await MainActor.run {
                    swipeablePosts.removeAll { $0.id == post.id }
                    appliedJobTitle = post.title
                    showApplicationSuccess = true
                }
            } catch {
                print("Error applying to job: \(error)")
            }
        }
    }
    
    private func passJob(post: JobPost) {
        // Remove from swipeable posts
        swipeablePosts.removeAll { $0.id == post.id }
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
        swipeablePosts = jobPosts
    }
}

struct JobPostCard: View {
    let post: JobPost
    let isSaved: Bool
    let onToggleSave: () -> Void
    var onSimpleApply: (() -> Void)? = nil
    
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header Section
            HStack(alignment: .top, spacing: 12) {
                // Company Icon/Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "building.2")
                        .foregroundColor(.blue)
                        .font(.title3)
                }
                
                // Title and Company
                VStack(alignment: .leading, spacing: 6) {
                    Text(post.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(post.company)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
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
                // Location
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 14))
                    Text(post.location)
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                
                // Salary and Job Type Row
                HStack(spacing: 16) {
                    if let salary = post.salary {
                        HStack(spacing: 6) {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text(salary)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                    
                    if let jobType = post.jobType {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.orange)
                                .font(.system(size: 14))
                            Text(jobType)
                                .font(.system(size: 14))
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Posted Date
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    Text("Posted \(formatDate(post.postedDate))")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            // Expanded Details Section (sorce.jobs style)
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal, 16)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        // Job Description Section
                        if let description = post.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("About this role")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                ScrollView {
                                    Text(description)
                                        .font(.system(size: 15))
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxHeight: 300)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 20)
                        }
                        
                        // Key Information Grid
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Details")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                                .padding(.horizontal, 16)
                            
                            VStack(spacing: 0) {
                                // Salary
                                if let salary = post.salary {
                                    HStack(alignment: .top, spacing: 16) {
                                        Image(systemName: "dollarsign.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 18))
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Salary")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                            Text(salary)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    
                                    Divider()
                                        .padding(.leading, 56)
                                }
                                
                                // Job Type
                                if let jobType = post.jobType {
                                    HStack(alignment: .top, spacing: 16) {
                                        Image(systemName: "clock.fill")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 18))
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Job Type")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                            Text(jobType)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    
                                    Divider()
                                        .padding(.leading, 56)
                                }
                                
                                // Location
                                HStack(alignment: .top, spacing: 16) {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 18))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Location")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                        Text(post.location)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                if post.url != nil {
                                    Divider()
                                        .padding(.leading, 56)
                                }
                                
                                // Posted Date
                                HStack(alignment: .top, spacing: 16) {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.purple)
                                        .font(.system(size: 18))
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Posted")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                        Text(formatDate(post.postedDate))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                
                                // Application URL
            if let url = post.url, !url.isEmpty {
                                    Divider()
                                        .padding(.leading, 56)
                                    
                                    HStack(alignment: .top, spacing: 16) {
                                        Image(systemName: "link")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 18))
                                            .frame(width: 24)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Apply")
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                Button(action: {
                    if let url = URL(string: url) {
                        UIApplication.shared.open(url)
                                                }
                                            }) {
                                                HStack(spacing: 4) {
                                                    Text("View on company website")
                                                        .font(.system(size: 15, weight: .medium))
                                                    Image(systemName: "arrow.up.right.square")
                                                        .font(.system(size: 13))
                                                }
                                                .foregroundColor(.blue)
                                            }
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            .background(Color(.systemBackground))
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                    }
                    .background(Color(.systemGray6))
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity.combined(with: .move(edge: .top))
                ))
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                // Simple Apply Button
                if let onSimpleApply = onSimpleApply {
                    Button(action: onSimpleApply) {
                        HStack {
                            Spacer()
                            Image(systemName: "paperplane.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Simple Apply")
                                .font(.system(size: 16, weight: .semibold))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                }
                
                // View Job Button (Toggle Expansion)
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        isExpanded.toggle()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text(isExpanded ? "Hide Details" : "View Job")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
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
    JobSearchView()
}


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
                    resumeUrl: nil, // TODO: Get from uploaded resume
                    jobUrl: post.url,
                    pendingQuestions: nil
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
                jobType: "Full-time",
                sections: nil
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
    @State private var jobDetails: JobDetails? = nil
    @State private var isLoadingDetails = false
    @State private var detailsError: String? = nil
    
    var body: some View {
        return GeometryReader { geometry in
            ZStack {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        VStack(alignment: .leading, spacing: 0) {
                            // Top anchor for scrolling
                            Color.clear
                                .frame(height: 0)
                                .id("top")
                            
                            // Allow scrolling even when not expanded (for long descriptions)
                            // The card will still maintain minimum height when not expanded
                            
                            // Category Tag (sorce.jobs style)
                            HStack {
                                Text(extractCategory(from: post))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 12)
                            
                            // Job Title with Up Arrow Button (sorce.jobs style)
                            HStack(alignment: .top, spacing: 12) {
                                Text(post.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.primary)
                                    .lineLimit(3)
                                    .fixedSize(horizontal: false, vertical: true)
                                
                                Spacer()
                                
                                // Up Arrow Button (white circle) - Expands card to show all info and enables scrolling
                                Button(action: {
                                    // Toggle expansion to show all job information
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                        isExpanded.toggle()
                                        if isExpanded && jobDetails == nil && !isLoadingDetails {
                                            fetchJobDetails()
                                        }
                                        // Scroll to top when expanding to show all content
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            withAnimation {
                                                proxy.scrollTo("top", anchor: .top)
                                            }
                                        }
                                    }
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.white)
                                            .frame(width: 36, height: 36)
                                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        Image(systemName: isExpanded ? "arrow.down" : "arrow.up")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            
                            // Company Logo and Name (sorce.jobs style)
                            HStack(spacing: 12) {
                                // Company Logo (black circle with white letter)
                                ZStack {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 48, height: 48)
                                    Text(String(post.company.prefix(1)).uppercased())
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(post.company)
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.primary)
                                    
                                    // Location
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                        Text(post.location)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            
                            // Work arrangement Section (sorce.jobs style)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Work arrangement")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 8) {
                                    // Remote badge
                                    if isRemoteJob(post: post) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 11))
                                            Text("Remote")
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .foregroundColor(.teal)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.teal.opacity(0.1))
                                        .cornerRadius(16)
                                    }
                                    
                                    // Job Type badge
                                    if let jobType = post.jobType, !jobType.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "briefcase.fill")
                                                .font(.system(size: 11))
                                            Text(jobType)
                                                .font(.system(size: 13, weight: .medium))
                                        }
                                        .foregroundColor(.purple)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.purple.opacity(0.1))
                                        .cornerRadius(16)
                                    }
                                    
                                    // Salary info bubble
                                    let salaryToUse: String? = {
                                        if let detailsSalary = jobDetails?.salary,
                                           detailsSalary != "Salary not specified" &&
                                           detailsSalary.lowercased() != "salary not specified" &&
                                           !detailsSalary.isEmpty {
                                            return detailsSalary
                                        } else if let postSalary = post.salary,
                                                  postSalary != "Salary not specified" &&
                                                  postSalary.lowercased() != "salary not specified" {
                                            return postSalary
                                        }
                                        return nil
                                    }()
                                    
                                    if let salary = salaryToUse {
                                        let cleanSalary = cleanSalaryText(salary)
                                        if !cleanSalary.isEmpty {
                                            HStack(spacing: 4) {
                                                Image(systemName: "dollarsign.circle.fill")
                                                    .font(.system(size: 11))
                                                Text(cleanSalary)
                                                    .font(.system(size: 13, weight: .medium))
                                            }
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(16)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            
                            // Experience level Section (sorce.jobs style)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Experience level")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "graduationcap.fill")
                                        .font(.system(size: 11))
                                    Text("Entry Level")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.pink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.pink.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            
                            // Education Section (sorce.jobs style)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Education")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 4) {
                                    Image(systemName: "book.fill")
                                        .font(.system(size: 11))
                                    Text("Bachelor's")
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.purple)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(16)
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 16)
                            
                            // Job Description Section (sorce.jobs style - always visible, full text)
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Job description")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                if let description = post.description, !description.isEmpty {
                                    Text(description)
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                        .lineSpacing(4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    // Show placeholder if no description available
                                    Text("No description available")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .italic()
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                            
                            // Qualifications Section (always visible below description)
                            if let details = jobDetails {
                                let qualifications = details.sections.filter { section in
                                    let titleLower = section.title.lowercased()
                                    return titleLower.contains("qualification") ||
                                           titleLower.contains("requirement") ||
                                           titleLower.contains("what we're looking for") ||
                                           titleLower.contains("essential") ||
                                           titleLower.contains("preferred") ||
                                           titleLower.contains("required skills")
                                }
                                
                                if !qualifications.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Qualifications")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.secondary)
                                        
                                        ForEach(qualifications) { qualification in
                                            VStack(alignment: .leading, spacing: 4) {
                                                if qualifications.count > 1 {
                                                    Text(qualification.title)
                                                        .font(.system(size: 13, weight: .semibold))
                                                        .foregroundColor(.primary)
                                                        .padding(.bottom, 4)
                                                }
                                                
                                                Text(qualification.content)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.primary)
                                                    .lineSpacing(4)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            } else if isLoadingDetails {
                                // Show loading indicator for qualifications
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading qualifications...")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                            
                            // Expanded Job Information (when tapped)
                            if isExpanded {
                                if isLoadingDetails {
                                    HStack {
                                        Spacer()
                                        ProgressView()
                                            .padding()
                                        Spacer()
                                    }
                                    .padding(.vertical, 20)
                                } else if let error = detailsError {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Unable to load job details")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.red)
                                        Text(error)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 12)
                                } else if let details = jobDetails, !details.sections.isEmpty {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(details.sections) { section in
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text(section.title)
                                                    .font(.system(size: 16, weight: .semibold))
                                                    .foregroundColor(.primary)
                                                
                                                Text(section.content)
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.secondary)
                                                    .lineSpacing(4)
                                            }
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
                                            
                                            if section.id != details.sections.last?.id {
                                                Divider()
                                                    .padding(.horizontal, 20)
                                            }
                                        }
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                
                            // Extra padding at bottom for fixed buttons
                            Color.clear
                                .frame(height: 100)
                        }
                        // Remove minHeight constraint - let content expand fully
                        // ScrollView will handle scrolling when content exceeds available space
                    }
                    // Always allow scrolling for long content (descriptions, qualifications, etc.)
                    // Content can expand fully and scroll when needed
                }
                
                // Action Buttons (Fixed at bottom - always visible)
                VStack {
                    Spacer()
                    HStack(spacing: 16) {
                        Spacer()
                        
                        // Back/Undo button
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 44, height: 44)
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Reject button
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                Image(systemName: "xmark")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Save/Resume button
                        Button(action: onToggleSave) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                Image(systemName: isSaved ? "bookmark.fill" : "doc.text")
                                    .font(.system(size: 18))
                                    .foregroundColor(isSaved ? .blue : .yellow)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Like/Favorite button
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Share button
                        Button(action: {}) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 18))
                                    .foregroundColor(.primary)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                    .background(
                        // Gradient background for better visibility
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(.systemBackground).opacity(0.0),
                                Color(.systemBackground).opacity(0.95),
                                Color(.systemBackground)
                            ]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }
            .frame(height: geometry.size.height) // Card fills available height
            .background(Color(.systemBackground))
        }
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            // Toggle expansion when card is tapped (like sorce.jobs)
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                isExpanded.toggle()
                if isExpanded && jobDetails == nil && !isLoadingDetails {
                    fetchJobDetails()
                }
            }
        }
        .onAppear {
            // Auto-fetch job details when card appears to get qualifications
            if jobDetails == nil && !isLoadingDetails {
                fetchJobDetails()
            }
        }
    }
    
    // MARK: - Helper Functions
    private func extractCategory(from post: JobPost) -> String {
        // Extract category from job title or description
        let title = post.title.lowercased()
        let description = post.description?.lowercased() ?? ""
        
        if title.contains("intern") || description.contains("intern") {
            return "Internships"
        } else if title.contains("engineer") || description.contains("engineer") {
            return "Engineering"
        } else if title.contains("data") || description.contains("data") {
            return "Data Center Services"
        } else if title.contains("design") || description.contains("design") {
            return "Design"
        } else if title.contains("marketing") || description.contains("marketing") {
            return "Marketing"
        } else if title.contains("product") || description.contains("product") {
            return "Product"
        } else {
            return "General"
        }
    }
    
    private func isRemoteJob(post: JobPost) -> Bool {
        let locationLower = post.location.lowercased()
        let jobTypeLower = post.jobType?.lowercased() ?? ""
        let descriptionLower = post.description?.lowercased() ?? ""
        let titleLower = post.title.lowercased()
        
        let remoteKeywords = ["remote", "anywhere", "work from home", "wfh", "distributed", "virtual", "telecommute", "telecommuting"]
        
        return remoteKeywords.contains { locationLower.contains($0) } ||
               remoteKeywords.contains { jobTypeLower.contains($0) } ||
               remoteKeywords.contains { descriptionLower.contains($0) } ||
               remoteKeywords.contains { titleLower.contains($0) }
    }
    
    private func buildInfoBubbles(for post: JobPost) -> [BubbleInfo] {
        var bubbles: [BubbleInfo] = []
        
        // Location Bubble (always show, but truncate if too long)
        let locationText = truncateText(post.location, maxLength: 25)
        bubbles.append(BubbleInfo(id: "location", icon: "mappin.circle.fill", text: locationText, color: .blue))
        
        // Remote Option Bubble (if detected)
        if isRemoteJob(post: post) {
            bubbles.append(BubbleInfo(id: "remote", icon: "house.fill", text: "Remote", color: .green))
        }
        
        // Salary Bubble (clean and format) - use from job details if available, otherwise from post
        var salaryToUse: String? = nil
        if let detailsSalary = jobDetails?.salary, 
           detailsSalary != "Salary not specified" && 
           detailsSalary.lowercased() != "salary not specified" &&
           !detailsSalary.isEmpty {
            salaryToUse = detailsSalary
        } else if let postSalary = post.salary, 
                  postSalary != "Salary not specified" && 
                  postSalary.lowercased() != "salary not specified" {
            salaryToUse = postSalary
        }
        
        if let salary = salaryToUse {
            let cleanSalary = cleanSalaryText(salary)
            if !cleanSalary.isEmpty {
                bubbles.append(BubbleInfo(id: "salary", icon: "dollarsign.circle.fill", text: cleanSalary, color: .green))
            }
        }
        
        // Job Type Bubble
        if let jobType = post.jobType, !jobType.isEmpty {
            let cleanJobType = truncateText(jobType, maxLength: 20)
            bubbles.append(BubbleInfo(id: "jobType", icon: "briefcase.fill", text: cleanJobType, color: .orange))
        }
        
        // Posted Date Bubble
        bubbles.append(BubbleInfo(id: "date", icon: "clock.fill", text: formatDate(post.postedDate), color: .purple))
        
        return bubbles
    }
    
    private func truncateText(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        return String(text.prefix(maxLength - 3)) + "..."
    }
    
    private func cleanSalaryText(_ salary: String) -> String {
        // Clean up salary text - remove extra whitespace, normalize format
        var cleaned = salary.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common prefixes
        let prefixes = ["Salary:", "Compensation:", "Pay:", "Wage:"]
        for prefix in prefixes {
            if cleaned.lowercased().hasPrefix(prefix.lowercased()) {
                cleaned = String(cleaned.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Convert to "k" notation (thousands) - simplify format
        // Pattern: Extract numbers and convert to k notation
        let numberPattern = #"(\d{1,3}(?:,\d{3})*(?:k|K)?)"#
        if let regex = try? NSRegularExpression(pattern: numberPattern, options: []) {
            let nsString = cleaned as NSString
            let results = regex.matches(in: cleaned, options: [], range: NSRange(location: 0, length: nsString.length))
            
            var convertedSalary = cleaned
            // Replace in reverse order to maintain indices
            for match in results.reversed() {
                let matchString = nsString.substring(with: match.range)
                var value = Int(matchString.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "k", with: "", options: .caseInsensitive)) ?? 0
                
                // If it didn't have "k" and is > 1000, convert to thousands
                if !matchString.lowercased().contains("k") && value > 1000 {
                    value = value / 1000
                }
                
                // Check if hourly or monthly (convert to annual)
                let isHourly = cleaned.lowercased().contains("hour") || cleaned.lowercased().contains("hr") || cleaned.lowercased().contains("hourly")
                let isMonthly = cleaned.lowercased().contains("month") || cleaned.lowercased().contains("mo") || cleaned.lowercased().contains("monthly")
                
                if isHourly {
                    // Rough conversion: $50/hr ≈ $100k/year
                    value = value * 2
                } else if isMonthly {
                    // Convert monthly to annual thousands
                    value = (value * 12) / 1000
                }
                
                // Replace with k notation
                let replacement = "$\(value)k"
                convertedSalary = (convertedSalary as NSString).replacingCharacters(in: match.range, with: replacement)
            }
            cleaned = convertedSalary
        }
        
        // Normalize common abbreviations and clean up
        cleaned = cleaned.replacingOccurrences(of: "per year", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "per month", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "per hour", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "annually", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "monthly", with: "", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "hourly", with: "", options: .caseInsensitive)
        
        // Clean up extra spaces and dashes
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        cleaned = cleaned.replacingOccurrences(of: " - ", with: " - ")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Handle "+" notation (e.g., "$100k+" stays as "$100k+")
        // Handle "up to" notation (e.g., "up to $150k" becomes "$150k")
        if cleaned.lowercased().contains("up to") {
            cleaned = cleaned.replacingOccurrences(of: "up to", with: "", options: .caseInsensitive).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // Truncate if too long
        return truncateText(cleaned, maxLength: 25)
    }
    
    // MARK: - Bubble Info Model
    struct BubbleInfo: Identifiable {
        let id: String
        let icon: String
        let text: String
        let color: Color
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
    
    // MARK: - Fetch Job Details
    private func fetchJobDetails() {
        guard let jobUrl = post.url, !jobUrl.isEmpty else {
            detailsError = "No job URL available"
            isLoadingDetails = false
            return
        }
        
        // Don't fetch again if we already have details or are currently loading
        if jobDetails != nil || isLoadingDetails {
            return
        }
        
        print("🔄 Fetching job details for: \(jobUrl)")
        isLoadingDetails = true
        detailsError = nil
        
        Task {
            do {
                let details = try await JobDetailsService.shared.fetchJobDetails(from: jobUrl)
                print("✅ Successfully fetched \(details.sections.count) sections")
                await MainActor.run {
                    self.jobDetails = details
                    self.isLoadingDetails = false
                }
            } catch {
                print("❌ Failed to fetch job details: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingDetails = false
                    self.detailsError = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Info Bubble Component (sorce.jobs style)
struct InfoBubble: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .overlay(
            Capsule()
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Flow Layout (for wrapping bubbles)
struct InfoBubbleFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    // Move to next line
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    JobSearchView()
}


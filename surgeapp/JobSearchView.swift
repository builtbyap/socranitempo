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
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
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
                    
                    // Up Arrow Button (white circle)
                    Button(action: onToggleSave) {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 36, height: 36)
                                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            Image(systemName: "arrow.up")
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
            
            
                // Action Buttons (sorce.jobs style - 5 circular buttons)
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
                    
                    // Save/Bookmark button
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
                .padding(.top, 20)
                .padding(.bottom, 30)
                }
                .frame(minHeight: geometry.size.height)
            }
        }
        .background(Color(.systemBackground))
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
            // Auto-fetch job details when card appears (like sorce.jobs)
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
        
        // Salary Bubble (clean and format)
        if let salary = post.salary, salary != "Salary not specified" && salary.lowercased() != "salary not specified" {
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
        
        // Normalize common abbreviations
        cleaned = cleaned.replacingOccurrences(of: "per year", with: "/yr", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "per month", with: "/mo", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "per hour", with: "/hr", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "annually", with: "/yr", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "monthly", with: "/mo", options: .caseInsensitive)
        cleaned = cleaned.replacingOccurrences(of: "hourly", with: "/hr", options: .caseInsensitive)
        
        // Truncate if too long
        return truncateText(cleaned, maxLength: 20)
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


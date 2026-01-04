//
//  FeedView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct FeedView: View {
    @State private var jobPosts: [JobPost] = []
    @State private var loading = false
    @State private var error: String?
    @State private var careerInterests: [String] = []
    @State private var showingSimpleApply: JobPost?
    @State private var showingAutoApply: JobPost?
    @State private var applicationData: ApplicationData?
    @State private var filters = JobFilters()
    @State private var showingFilters = false
    @State private var allJobPosts: [JobPost] = [] // Store all jobs before filtering
    @State private var appliedJobIds: Set<String> = [] // Track applied job IDs
    @State private var passedJobIds: Set<String> = [] // Track passed/rejected job IDs
    @State private var currentJobIndex: Int = 0 // Track current job in swipeable view
    @State private var hasLoadedInitialData: Bool = false // Track if initial data has been loaded
    
    // Computed property for filtered jobs (excludes applied and passed jobs)
    private var filteredJobPosts: [JobPost] {
        var jobs = allJobPosts
        
        print("🔍 Filtering jobs:")
        print("   - Total jobs: \(jobs.count)")
        print("   - Applied job IDs: \(appliedJobIds.count)")
        print("   - Passed job IDs: \(passedJobIds.count)")
        print("   - Has active filters: \(filters.hasActiveFilters)")
        
        // Filter out jobs that have been applied to or passed on
        let beforeAppliedFilter = jobs.count
        jobs = jobs.filter { job in
            !appliedJobIds.contains(job.id) && !passedJobIds.contains(job.id)
        }
        print("   - After removing applied/passed: \(jobs.count) (removed \(beforeAppliedFilter - jobs.count))")
        
        // Apply user filters if active
        if filters.hasActiveFilters {
            let beforeFilter = jobs.count
            jobs = filters.apply(to: jobs)
            print("   - After applying filters: \(jobs.count) (removed \(beforeFilter - jobs.count))")
            
            if jobs.isEmpty && beforeFilter > 0 {
                print("⚠️ WARNING: All jobs filtered out! Filters may be too strict.")
                print("   - Active filters: jobTitles=\(filters.jobTitles), jobTypes=\(filters.jobTypes), locations=\(filters.locations), minSalary=\(filters.minSalary?.description ?? "nil"), maxSalary=\(filters.maxSalary?.description ?? "nil")")
            }
        }
        
        return jobs
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                    // Jobs Feed - Swipeable single card view (like sorce.jobs)
                    if filteredJobPosts.isEmpty {
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
                        GeometryReader { geometry in
                            ZStack {
                                // Show up to 3 cards stacked (sorce.jobs style - subtle stacking)
                                ForEach(Array(filteredJobPosts.enumerated()), id: \.element.id) { index, post in
                                    if index >= currentJobIndex && index < currentJobIndex + 3 {
                                        SwipeableJobCardView(
                                            post: post,
                                            onApply: {
                                                handleApply(to: post)
                                            },
                                            onPass: {
                                                handlePass(for: post)
                                            }
                                        )
                                        .zIndex(Double(filteredJobPosts.count - index))
                                        .offset(y: CGFloat(index - currentJobIndex) * 6) // Subtle offset
                                        .scaleEffect(1.0 - CGFloat(index - currentJobIndex) * 0.02) // Subtle scale
                                        .opacity(index == currentJobIndex ? 1.0 : max(0.7, 1.0 - CGFloat(index - currentJobIndex) * 0.15))
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingFilters = true
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: filters.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(.system(size: 20))
                                .foregroundColor(filters.hasActiveFilters ? .blue : .primary)
                            
                            if filters.hasActiveFilters {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 8, height: 8)
                                    .offset(x: 4, y: -4)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                JobFiltersView(filters: $filters)
                    .onDisappear {
                        // When filters are applied, trigger a new search with updated filters
                        Task {
                            await fetchData()
                        }
                    }
            }
            .onAppear {
                loadCareerInterests()
                // Only fetch data on first appearance, not every time tab is switched
                if !hasLoadedInitialData {
                    Task {
                        await loadPassedJobs()
                        await fetchAppliedJobs()
                        await fetchData()
                        hasLoadedInitialData = true
                    }
                } else {
                    // Just refresh applied/passed jobs when returning to tab
                    Task {
                        await loadPassedJobs()
                        await fetchAppliedJobs()
                    }
                }
            }
            .refreshable {
                // Pull to refresh - always fetch new data
                loadCareerInterests()
                await fetchData()
            }
            .fullScreenCover(item: Binding(
                get: { showingSimpleApply },
                set: { showingSimpleApply = $0 }
            )) { job in
                if let appData = applicationData {
                    // Use Human-Assisted Apply for jobs with URLs (visible, slow, user-controlled)
                    if let jobURL = job.url, !jobURL.isEmpty {
                        HumanAssistedApplyView(job: job, applicationData: appData)
                    } else {
                        // No URL, use review screen
                        SimpleApplyReviewView(job: job, applicationData: appData)
                    }
                }
            }
            .fullScreenCover(item: Binding(
                get: { showingAutoApply },
                set: { showingAutoApply = $0 }
            )) { job in
                // Use Playwright-based fully automated application (like sorce.jobs)
                AutoApplyProgressView(job: job)
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ApplicationStatusUpdated"))) { _ in
                // Refresh applied jobs when application status changes
                Task {
                    await fetchAppliedJobs()
                }
            }
        }
    }
    
    // MARK: - Fetch Applied Jobs
    private func fetchAppliedJobs() async {
        do {
            let applications = try await SupabaseService.shared.fetchApplications()
            let appliedIds = Set(applications.map { $0.jobPostId })
            await MainActor.run {
                self.appliedJobIds = appliedIds
                print("📋 Loaded \(appliedIds.count) applied job IDs")
            }
        } catch {
            print("⚠️ Failed to fetch applied jobs: \(error.localizedDescription)")
            // Don't block the UI if this fails
        }
    }
    
    // MARK: - Handle Apply
    private func handleApply(to post: JobPost) {
        // Use Human-Assisted Apply (slow, visible, user-controlled)
        // This follows human behavior patterns and stops at friction
        if let jobURL = post.url, !jobURL.isEmpty {
            // Get application data
            let profileData = SimpleApplyService.shared.getUserProfileData()
            let appData = SimpleApplyService.shared.generateApplicationData(for: post, profileData: profileData)
            applicationData = appData
            
            // Show human-assisted apply view (visible, slow, user-controlled)
            showingSimpleApply = post
        } else {
            // No URL, show review screen instead
            let profileData = SimpleApplyService.shared.getUserProfileData()
            let appData = SimpleApplyService.shared.generateApplicationData(for: post, profileData: profileData)
            applicationData = appData
            showingSimpleApply = post
        }
        
        // Move to next job after applying
        moveToNextJob()
    }
    
    // MARK: - Handle Pass
    private func handlePass(for post: JobPost) {
        // Mark job as passed/rejected (like sorce.jobs)
        markJobAsPassed(post)
        
        // Move to next job
        moveToNextJob()
    }
    
    // MARK: - Move to Next Job
    private func moveToNextJob() {
        withAnimation(.spring()) {
            if currentJobIndex < filteredJobPosts.count - 1 {
                currentJobIndex += 1
            } else {
                // Reached end, could refresh or show message
                print("📋 Reached end of job feed")
            }
        }
    }
    
    // MARK: - Mark Job as Passed
    private func markJobAsPassed(_ job: JobPost) {
        // Add to local set for immediate filtering
        passedJobIds.insert(job.id)
        savePassedJobs()
        
        // Save to Supabase as a "passed" application
        Task {
            do {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                
                let passedApplication = Application(
                    id: UUID().uuidString,
                    jobPostId: job.id,
                    jobTitle: job.title,
                    company: job.company,
                    status: "passed", // Use "passed" status
                    appliedDate: dateFormatter.string(from: Date()),
                    resumeUrl: nil,
                    jobUrl: job.url,
                    pendingQuestions: nil
                )
                
                try await SupabaseService.shared.insertApplication(passedApplication)
                print("✅ Saved passed job to Applications: \(job.title)")
                
                // Notify ApplicationsView to refresh
                NotificationCenter.default.post(
                    name: NSNotification.Name("ApplicationStatusUpdated"),
                    object: nil
                )
            } catch {
                print("⚠️ Failed to save passed job to Supabase: \(error.localizedDescription)")
                // Still keep it in local storage even if Supabase save fails
            }
        }
        
        print("📋 Marked job \(job.id) as passed - will not show again")
    }
    
    // MARK: - Load Passed Jobs
    private func loadPassedJobs() {
        if let data = UserDefaults.standard.data(forKey: "passed_job_ids"),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            passedJobIds = ids
            print("📋 Loaded \(ids.count) passed job IDs")
        }
    }
    
    // MARK: - Save Passed Jobs
    private func savePassedJobs() {
        if let data = try? JSONEncoder().encode(passedJobIds) {
            UserDefaults.standard.set(data, forKey: "passed_job_ids")
        }
    }
    
    private func fetchData() async {
        loading = true
        error = nil
        
        do {
            // Fetch Jobs from multiple sources, filtered by career interests
            var allPosts: [JobPost] = []
            
            // Fetch from Supabase (existing jobs)
            do {
                let supabasePosts = try await SupabaseService.shared.fetchJobPosts()
                // Filter Supabase posts by job titles (career interests) from filters
                let filterKeywords = !filters.jobTitles.isEmpty ? Array(filters.jobTitles) : careerInterests
                let filteredPosts = filterJobsByCareerInterests(supabasePosts, careerInterests: filterKeywords)
                allPosts.append(contentsOf: filteredPosts)
            } catch {
                print("⚠️ Failed to fetch from Supabase: \(error.localizedDescription)")
            }
            
            // Use job titles from filters if available, otherwise use career interests
            var searchKeywords: [String]
            if !filters.jobTitles.isEmpty {
                searchKeywords = Array(filters.jobTitles)
            } else {
                searchKeywords = careerInterests
            }
            
            // If internship filter is selected, add "internship" to search keywords
            if filters.jobTypes.contains(.internship) {
                // Add "internship" to each keyword to search for internship positions
                var internshipKeywords: [String] = []
                for keyword in searchKeywords {
                    internshipKeywords.append("\(keyword) internship")
                    internshipKeywords.append("internship \(keyword)")
                }
                // Also add standalone "internship" if no keywords
                if searchKeywords.isEmpty {
                    internshipKeywords.append("internship")
                }
                searchKeywords = internshipKeywords
                print("🔍 Added internship keywords: \(internshipKeywords)")
            }
            
            // Use locations from filters if available
            let searchLocation: String?
            if !filters.locations.isEmpty {
                searchLocation = Array(filters.locations).first
            } else if !filters.location.isEmpty {
                searchLocation = filters.location
            } else {
                searchLocation = nil
            }
            
            // Fetch from job scraping service (job boards, company pages, ATS)
            do {
                print("🔍 Fetching jobs from backend...")
                print("🔍 Job titles/career interests: \(searchKeywords)")
                print("🔍 Location: \(searchLocation ?? "none")")
                let scrapedPosts = try await JobScrapingService.shared.fetchJobsFromBackend(
                    keywords: searchKeywords.isEmpty ? nil : searchKeywords.joined(separator: " OR "),
                    location: searchLocation,
                    careerInterests: searchKeywords,
                    minSalary: filters.minSalary,
                    maxSalary: filters.maxSalary
                )
                print("✅ Fetched \(scrapedPosts.count) jobs from backend")
                if scrapedPosts.isEmpty {
                    print("⚠️ WARNING: Backend returned 0 jobs!")
                } else {
                    print("📋 Sample job from backend:")
                    if let sample = scrapedPosts.first {
                        print("   - ID: \(sample.id)")
                        print("   - Title: \(sample.title)")
                        print("   - Company: \(sample.company)")
                    }
                }
                allPosts.append(contentsOf: scrapedPosts)
            } catch {
                print("⚠️ Backend API error: \(error.localizedDescription)")
                // If backend API is not available, try direct scraping (limited)
                print("⚠️ Attempting direct scraping as fallback...")
                do {
                    let directPosts = try await JobScrapingService.shared.fetchJobsFromAllSources(
                        keywords: searchKeywords.isEmpty ? nil : searchKeywords.joined(separator: " OR "),
                        location: searchLocation,
                        careerInterests: searchKeywords
                    )
                    print("✅ Fetched \(directPosts.count) jobs from direct scraping")
                    allPosts.append(contentsOf: directPosts)
                } catch {
                    print("⚠️ Direct scraping also failed: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                print("📊 Processing \(allPosts.count) total posts from all sources")
                var uniquePosts: [JobPost] = []
                var seenIds = Set<String>()
                
                for post in allPosts {
                    if !seenIds.contains(post.id) {
                        seenIds.insert(post.id)
                        uniquePosts.append(post)
                    }
                }
                
                print("📊 After deduplication: \(uniquePosts.count) unique posts")
                
                // Sort by posted date (most recent first)
                uniquePosts.sort { post1, post2 in
                    post1.postedDate > post2.postedDate
                }
                
                self.allJobPosts = uniquePosts
                self.jobPosts = uniquePosts // Keep for compatibility
                // Reset to first job when new jobs are loaded
                if self.currentJobIndex >= uniquePosts.count {
                    self.currentJobIndex = 0
                }
                self.loading = false
                
                print("✅ Updated UI with \(uniquePosts.count) jobs")
                print("   - allJobPosts count: \(self.allJobPosts.count)")
                print("   - jobPosts count: \(self.jobPosts.count)")
                print("   - filteredJobPosts count: \(self.filteredJobPosts.count)")
                
                // Debug: Print first job if available
                if let firstJob = uniquePosts.first {
                    print("📋 First job sample:")
                    print("   - ID: \(firstJob.id)")
                    print("   - Title: \(firstJob.title)")
                    print("   - Company: \(firstJob.company)")
                    print("   - Location: \(firstJob.location)")
                    print("   - Posted Date: \(firstJob.postedDate)")
                }
                
                // Queue jobs for auto-apply (like sorce.jobs)
                // This will automatically apply to company career pages
                Task {
                    AutoApplyQueueService.shared.queueJobsForAutoApply(uniquePosts)
                }
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.loading = false
            }
        }
    }
    
    // MARK: - Load Career Interests
    private func loadCareerInterests() {
        if let data = UserDefaults.standard.data(forKey: "savedCareerArchetypes"),
           let savedInterests = try? JSONDecoder().decode([String].self, from: data) {
            careerInterests = savedInterests
        }
    }
    
    // MARK: - Filter Jobs by Career Interests
    private func filterJobsByCareerInterests(_ jobs: [JobPost], careerInterests: [String]) -> [JobPost] {
        guard !careerInterests.isEmpty else {
            return jobs
        }
        
        return jobs.filter { job in
            // Check if job title, description, or company matches any career interest
            let jobText = "\(job.title) \(job.company) \(job.description ?? "")".lowercased()
            
            return careerInterests.contains { interest in
                let interestLower = interest.lowercased()
                // Check for exact match or partial match in job text
                return jobText.contains(interestLower) ||
                       job.title.lowercased().contains(interestLower) ||
                       (job.description?.lowercased().contains(interestLower) ?? false)
            }
        }
    }
}

#Preview {
    FeedView()
}


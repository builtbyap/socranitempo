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
    @State private var careerInterests: [String] = []
    @State private var showingSimpleApply: JobPost?
    @State private var showingAutoApply: JobPost?
    @State private var applicationData: ApplicationData?
    @State private var filters = JobFilters()
    @State private var showingFilters = false
    @State private var allJobPosts: [JobPost] = [] // Store all jobs before filtering
    
    // Computed property for filtered jobs
    private var filteredJobPosts: [JobPost] {
        if filters.hasActiveFilters {
            return filters.apply(to: allJobPosts)
        }
        return allJobPosts
    }
    
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
                                    ForEach(filteredJobPosts) { post in
                                        JobPostCard(
                                            post: post,
                                            isSaved: false,
                                            onToggleSave: {},
                                            onSimpleApply: {
                                                // Get profile data
                                                let profileData = SimpleApplyService.shared.getUserProfileData()
                                                let appData = SimpleApplyService.shared.generateApplicationData(for: post, profileData: profileData)
                                                applicationData = appData
                                                
                                                // Check if job has URL for auto-apply
                                                if let jobURL = post.url, !jobURL.isEmpty {
                                                    // Directly start AI Auto-Apply (like sorce.jobs)
                                                    showingAutoApply = post
                                                } else {
                                                    // No URL, show review screen instead
                                                    showingSimpleApply = post
                                                }
                                            }
                                        )
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
            .toolbar {
                if selectedTab == 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            showingFilters = true
                        }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 20))
                                
                                if filters.hasActiveFilters {
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 8, height: 8)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                JobFiltersView(filters: $filters)
            }
            .onAppear {
                loadCareerInterests()
                Task {
                    await fetchData()
                }
            }
            .refreshable {
                loadCareerInterests()
                await fetchData()
            }
            .sheet(isPresented: Binding(
                get: { showingSimpleApply != nil },
                set: { if !$0 { showingSimpleApply = nil } }
            )) {
                if let job = showingSimpleApply, let appData = applicationData {
                    SimpleApplyReviewView(job: job, applicationData: appData)
                }
            }
            .fullScreenCover(item: Binding(
                get: { showingAutoApply },
                set: { showingAutoApply = $0 }
            )) { job in
                if let appData = applicationData {
                    AutoApplyView(job: job, applicationData: appData)
                }
            }
        }
    }
    
    private func fetchData() async {
        loading = true
        error = nil
        
        do {
            switch selectedTab {
            case 0:
                // Fetch Jobs from multiple sources, filtered by career interests
                var allPosts: [JobPost] = []
                
                // Fetch from Supabase (existing jobs)
                do {
                    let supabasePosts = try await SupabaseService.shared.fetchJobPosts()
                    // Filter Supabase posts by career interests
                    let filteredPosts = filterJobsByCareerInterests(supabasePosts, careerInterests: careerInterests)
                    allPosts.append(contentsOf: filteredPosts)
                } catch {
                    print("⚠️ Failed to fetch from Supabase: \(error.localizedDescription)")
                }
                
                // Fetch from job scraping service (job boards, company pages, ATS)
                do {
                    print("🔍 Fetching jobs from backend...")
                    print("🔍 Career interests: \(careerInterests)")
                    let scrapedPosts = try await JobScrapingService.shared.fetchJobsFromBackend(
                        careerInterests: careerInterests
                    )
                    print("✅ Fetched \(scrapedPosts.count) jobs from backend")
                    allPosts.append(contentsOf: scrapedPosts)
                } catch {
                    print("⚠️ Backend API error: \(error.localizedDescription)")
                    // If backend API is not available, try direct scraping (limited)
                    print("⚠️ Attempting direct scraping as fallback...")
                    do {
                        let directPosts = try await JobScrapingService.shared.fetchJobsFromAllSources(
                            careerInterests: careerInterests
                        )
                        print("✅ Fetched \(directPosts.count) jobs from direct scraping")
                        allPosts.append(contentsOf: directPosts)
                    } catch {
                        print("⚠️ Direct scraping also failed: \(error.localizedDescription)")
                    }
                }
                
                await MainActor.run {
                    var uniquePosts: [JobPost] = []
                    var seenIds = Set<String>()
                    
                    for post in allPosts {
                        if !seenIds.contains(post.id) {
                            seenIds.insert(post.id)
                            uniquePosts.append(post)
                        }
                    }
                    
                    // Sort by posted date (most recent first)
                    uniquePosts.sort { post1, post2 in
                        post1.postedDate > post2.postedDate
                    }
                    
                    self.allJobPosts = uniquePosts
                    self.jobPosts = uniquePosts // Keep for compatibility
                    self.loading = false
                    
                    // Queue jobs for auto-apply (like sorce.jobs)
                    // This will automatically apply to company career pages
                    Task {
                        AutoApplyQueueService.shared.queueJobsForAutoApply(uniquePosts)
                    }
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


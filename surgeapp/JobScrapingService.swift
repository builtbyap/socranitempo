//
//  JobScrapingService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Job Scraping Service
class JobScrapingService {
    static let shared = JobScrapingService()
    
    private init() {}
    
    // MARK: - Fetch Jobs from All Sources
    func fetchJobsFromAllSources(keywords: String? = nil, location: String? = nil, careerInterests: [String] = []) async throws -> [JobPost] {
        var allJobs: [JobPost] = []
        
        // Build search keywords from career interests if provided
        let searchKeywords: String?
        if !careerInterests.isEmpty {
            // Combine career interests into a search query
            searchKeywords = careerInterests.joined(separator: " OR ")
        } else {
            searchKeywords = keywords
        }
        
        // Fetch from multiple sources in parallel
        async let jobBoardJobs = fetchFromJobBoards(keywords: searchKeywords, location: location)
        async let companyPageJobs = fetchFromCompanyCareerPages(keywords: searchKeywords, location: location)
        async let atsJobs = fetchFromATSPages(keywords: searchKeywords, location: location)
        
        // Wait for all to complete
        let results = try await [jobBoardJobs, companyPageJobs, atsJobs]
        
        // Combine and deduplicate
        for jobs in results {
            allJobs.append(contentsOf: jobs)
        }
        
        // Filter jobs by career interests if provided
        let filteredJobs = filterJobsByCareerInterests(allJobs, careerInterests: careerInterests)
        
        return deduplicateJobs(filteredJobs)
    }
    
    // MARK: - Fetch from Public Job Boards
    private func fetchFromJobBoards(keywords: String?, location: String?) async throws -> [JobPost] {
        var jobs: [JobPost] = []
        
        // Fetch from multiple job boards in parallel
        async let indeedJobs = fetchFromIndeed(keywords: keywords, location: location)
        async let monsterJobs = fetchFromMonster(keywords: keywords, location: location)
        async let glassdoorJobs = fetchFromGlassdoor(keywords: keywords, location: location)
        async let zipRecruiterJobs = fetchFromZipRecruiter(keywords: keywords, location: location)
        async let linkedInJobs = fetchFromLinkedIn(keywords: keywords, location: location)
        
        // Wait for all to complete (using try? to handle individual failures gracefully)
        let results = await [
            try? indeedJobs,
            try? monsterJobs,
            try? glassdoorJobs,
            try? zipRecruiterJobs,
            try? linkedInJobs
        ]
        
        for result in results {
            if let jobList = result {
                jobs.append(contentsOf: jobList)
            }
        }
        
        return jobs
    }
    
    // MARK: - Indeed
    private func fetchFromIndeed(keywords: String?, location: String?) async throws -> [JobPost] {
        // Indeed has an unofficial API endpoint or we can use web scraping
        // For now, we'll create a structure that can work with a backend service
        // or attempt direct parsing
        
        var components = URLComponents(string: "https://www.indeed.com/jobs")
        var queryItems: [URLQueryItem] = []
        
        if let keywords = keywords, !keywords.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: keywords))
        }
        if let location = location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "l", value: location))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return []
        }
        
        // Note: Indeed blocks direct scraping, so this would need a backend service
        // or use their API if available. For now, return empty array.
        // In production, you'd call a backend service here.
        return []
    }
    
    // MARK: - Monster
    private func fetchFromMonster(keywords: String?, location: String?) async throws -> [JobPost] {
        var components = URLComponents(string: "https://www.monster.com/jobs/search")
        var queryItems: [URLQueryItem] = []
        
        if let keywords = keywords, !keywords.isEmpty {
            queryItems.append(URLQueryItem(name: "q", value: keywords))
        }
        if let location = location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "where", value: location))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return []
        }
        
        // Similar to Indeed - would need backend service for scraping
        return []
    }
    
    // MARK: - Glassdoor
    private func fetchFromGlassdoor(keywords: String?, location: String?) async throws -> [JobPost] {
        var components = URLComponents(string: "https://www.glassdoor.com/Job/jobs.htm")
        var queryItems: [URLQueryItem] = []
        
        if let keywords = keywords, !keywords.isEmpty {
            queryItems.append(URLQueryItem(name: "sc.keyword", value: keywords))
        }
        if let location = location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "locT", value: "C"))
            queryItems.append(URLQueryItem(name: "locId", value: location))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return []
        }
        
        // Would need backend service for scraping
        return []
    }
    
    // MARK: - ZipRecruiter
    private func fetchFromZipRecruiter(keywords: String?, location: String?) async throws -> [JobPost] {
        var components = URLComponents(string: "https://www.ziprecruiter.com/jobs-search")
        var queryItems: [URLQueryItem] = []
        
        if let keywords = keywords, !keywords.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: keywords))
        }
        if let location = location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "location", value: location))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return []
        }
        
        // Would need backend service for scraping
        return []
    }
    
    // MARK: - LinkedIn
    private func fetchFromLinkedIn(keywords: String?, location: String?) async throws -> [JobPost] {
        // LinkedIn has strict anti-scraping measures
        // Would need to use their official API or a backend service
        // LinkedIn Jobs API requires authentication
        
        var components = URLComponents(string: "https://www.linkedin.com/jobs/search")
        var queryItems: [URLQueryItem] = []
        
        if let keywords = keywords, !keywords.isEmpty {
            queryItems.append(URLQueryItem(name: "keywords", value: keywords))
        }
        if let location = location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "location", value: location))
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            return []
        }
        
        // LinkedIn requires authentication and has rate limits
        // Would need backend service or official API
        return []
    }
    
    // MARK: - Fetch from Company Career Pages
    private func fetchFromCompanyCareerPages(keywords: String?, location: String?) async throws -> [JobPost] {
        // This would typically require:
        // 1. A list of company domains to check
        // 2. Common career page patterns (/careers, /jobs, /careers/jobs, etc.)
        // 3. Parsing logic for each company's specific structure
        
        // For now, return empty array
        // In production, you'd:
        // - Maintain a list of companies to check
        // - Try common career page URLs
        // - Parse each company's job listing page structure
        
        return []
    }
    
    // MARK: - Fetch from ATS-Hosted Job Pages
    private func fetchFromATSPages(keywords: String?, location: String?) async throws -> [JobPost] {
        // Common ATS systems:
        // - Greenhouse (greenhouse.io)
        // - Lever (lever.co)
        // - Workday (workday.com)
        // - SmartRecruiters (smartrecruiters.com)
        // - BambooHR (bamboohr.com)
        // - JazzHR (jazzhr.com)
        // - iCIMS (icims.com)
        
        // Each ATS has different URL patterns and structures
        // Would need specific parsers for each
        
        return []
    }
    
    // MARK: - Parse Job from HTML (Generic)
    private func parseJobFromHTML(html: String, source: String) -> [JobPost] {
        // This would use HTML parsing (e.g., SwiftSoup if available, or regex)
        // to extract job information from HTML content
        
        // For now, return empty array
        // In production, you'd parse:
        // - Job title
        // - Company name
        // - Location
        // - Description
        // - Posted date
        // - Salary (if available)
        // - Job type (if available)
        // - Application URL
        
        return []
    }
    
    // MARK: - Deduplicate Jobs
    private func deduplicateJobs(_ jobs: [JobPost]) -> [JobPost] {
        var seen = Set<String>()
        var uniqueJobs: [JobPost] = []
        
        for job in jobs {
            // Create a unique identifier based on title, company, and location
            let identifier = "\(job.title.lowercased())|\(job.company.lowercased())|\(job.location.lowercased())"
            
            if !seen.contains(identifier) {
                seen.insert(identifier)
                uniqueJobs.append(job)
            }
        }
        
        return uniqueJobs
    }
    
    // MARK: - Backend API Integration
    // This method calls your backend service that handles the actual scraping
    // 
    // IMPORTANT: Direct web scraping from iOS is limited due to:
    // - Anti-scraping measures (CAPTCHAs, rate limiting)
    // - JavaScript-heavy sites requiring browser rendering
    // - Legal/ToS concerns
    // 
    // RECOMMENDED APPROACH: Set up a backend service (Node.js, Python, etc.) that:
    // 1. Scrapes job boards (Indeed, Monster, Glassdoor, ZipRecruiter, LinkedIn)
    // 2. Parses company career pages (/careers, /jobs endpoints)
    // 3. Handles ATS-hosted pages (Greenhouse, Lever, Workday, etc.)
    // 4. Returns structured JSON data
    //
    // To configure: Update Config.jobScrapingBackendURL in Config.swift with your actual backend endpoint
    func fetchJobsFromBackend(keywords: String? = nil, location: String? = nil, careerInterests: [String] = []) async throws -> [JobPost] {
        // Backend URL is configured in Config.swift
        guard let backendURL = URL(string: Config.jobScrapingBackendURL) else {
            throw JobScrapingError.invalidURL
        }
        
        var components = URLComponents(url: backendURL, resolvingAgainstBaseURL: false)
        var queryItems: [URLQueryItem] = []
        
        // Use career interests as keywords if provided, otherwise use provided keywords
        let searchKeywords: String?
        if !careerInterests.isEmpty {
            searchKeywords = careerInterests.joined(separator: " OR ")
        } else {
            searchKeywords = keywords
        }
        
        if let keywords = searchKeywords, !keywords.isEmpty {
            queryItems.append(URLQueryItem(name: "keywords", value: keywords))
        }
        if let location = location, !location.isEmpty {
            queryItems.append(URLQueryItem(name: "location", value: location))
        }
        
        // Also send career interests as a separate parameter for backend filtering
        if !careerInterests.isEmpty {
            if let interestsJSON = try? JSONEncoder().encode(careerInterests),
               let interestsString = String(data: interestsJSON, encoding: .utf8) {
                queryItems.append(URLQueryItem(name: "career_interests", value: interestsString))
            }
        }
        
        components?.queryItems = queryItems
        
        guard let url = components?.url else {
            throw JobScrapingError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Add Supabase authentication headers
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JobScrapingError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Backend API error: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            throw JobScrapingError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        // Debug: Print the raw response
        if let responseString = String(data: data, encoding: .utf8) {
            print("📥 Backend response: \(responseString.prefix(500))") // Print first 500 chars
        }
        
        let decoder = JSONDecoder()
        // Don't use keyDecodingStrategy - JobPost has explicit CodingKeys that handle snake_case
        
        // Try to decode the response
        do {
            let jobs = try decoder.decode([JobPost].self, from: data)
            print("✅ Successfully decoded \(jobs.count) jobs from backend")
            
            // Filter jobs by career interests if provided
            let filtered = filterJobsByCareerInterests(jobs, careerInterests: careerInterests)
            print("✅ After filtering: \(filtered.count) jobs")
            return filtered
        } catch {
            print("❌ Failed to decode jobs: \(error)")
            print("❌ Response data: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
            throw JobScrapingError.parsingFailed
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

// MARK: - Job Scraping Errors
enum JobScrapingError: LocalizedError {
    case invalidURL
    case requestFailed
    case parsingFailed
    case rateLimited
    case httpError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL for job scraping"
        case .requestFailed:
            return "Failed to fetch jobs from source"
        case .parsingFailed:
            return "Failed to parse job data"
        case .rateLimited:
            return "Rate limited by job board. Please try again later."
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        }
    }
}


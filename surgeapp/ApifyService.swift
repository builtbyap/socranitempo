//
//  ApifyService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Apify Service
class ApifyService {
    static let shared = ApifyService()
    
    // Apify API token from Config.swift (gitignored)
    private let apifyToken = Config.apifyToken
    private let actorId = "worldunboxer~rapid-linkedin-scraper"
    
    private init() {}
    
    // MARK: - Run LinkedIn Job Scraper
    func runLinkedInScraper(
        jobTitle: String,
        location: String,
        jobType: String, // "F" for Full-time, "P" for Part-time
        jobsEntries: Int = 25
    ) async throws -> String {
        // Step 1: Start the actor run
        guard let url = URL(string: "https://api.apify.com/v2/acts/\(actorId)/runs?token=\(apifyToken)") else {
            throw ApifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "job_title": jobTitle,
            "job_type": jobType,
            "jobs_entries": jobsEntries,
            "location": location,
            "start_jobs": 0
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApifyError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorData = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Apify API error: HTTP \(httpResponse.statusCode) - \(errorData)")
            throw ApifyError.httpError(statusCode: httpResponse.statusCode, message: errorData)
        }
        
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let runId = json["data"] as? [String: Any],
              let id = runId["id"] as? String else {
            print("❌ Invalid Apify response format")
            throw ApifyError.invalidResponse
        }
        
        print("✅ Apify run started with ID: \(id)")
        return id
    }
    
    // MARK: - Wait for Actor to Finish
    func waitForActorCompletion(runId: String) async throws {
        print("⏳ Waiting for Apify actor to complete (this may take a while)...")
        
        // Poll the status instead of using waitForFinish (which might timeout)
        var attempts = 0
        let maxAttempts = 60 // Wait up to 5 minutes (60 * 5 seconds)
        
        while attempts < maxAttempts {
            guard let url = URL(string: "https://api.apify.com/v2/actor-runs/\(runId)?token=\(apifyToken)") else {
                throw ApifyError.invalidURL
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ApifyError.requestFailed
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let runData = json["data"] as? [String: Any],
                  let status = runData["status"] as? String else {
                throw ApifyError.invalidResponse
            }
            
            if status == "SUCCEEDED" {
                print("✅ Apify actor completed successfully")
                return
            } else if status == "FAILED" || status == "ABORTED" {
                throw ApifyError.requestFailed
            }
            
            // Still running, wait 5 seconds before checking again
            try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            attempts += 1
            
            if attempts % 6 == 0 { // Print every 30 seconds
                print("⏳ Still waiting... (\(attempts * 5) seconds)")
            }
        }
        
        throw ApifyError.requestFailed // Timeout
    }
    
    // MARK: - Get Dataset Results
    func getDatasetResults(datasetId: String) async throws -> [ApifyJobResult] {
        guard let url = URL(string: "https://api.apify.com/v2/datasets/\(datasetId)/items?token=\(apifyToken)") else {
            throw ApifyError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw ApifyError.requestFailed
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([ApifyJobResult].self, from: data)
    }
    
    // MARK: - Complete Scrape Flow
    func scrapeLinkedInJobs(
        jobTitle: String,
        location: String,
        jobType: String,
        jobsEntries: Int = 100
    ) async throws -> [ApifyJobResult] {
        // Step 1: Start the scraper
        let runId = try await runLinkedInScraper(
            jobTitle: jobTitle,
            location: location,
            jobType: jobType,
            jobsEntries: jobsEntries
        )
        
        // Step 2: Wait for completion
        try await waitForActorCompletion(runId: runId)
        
        // Step 3: Get the run details to find dataset ID
        guard let runUrl = URL(string: "https://api.apify.com/v2/actor-runs/\(runId)?token=\(apifyToken)") else {
            throw ApifyError.invalidURL
        }
        
        var runRequest = URLRequest(url: runUrl)
        runRequest.httpMethod = "GET"
        
        let (runData, _) = try await URLSession.shared.data(for: runRequest)
        guard let runJson = try JSONSerialization.jsonObject(with: runData) as? [String: Any],
              let runDataDict = runJson["data"] as? [String: Any],
              let defaultDatasetId = runDataDict["defaultDatasetId"] as? String else {
            throw ApifyError.invalidResponse
        }
        
        // Step 4: Get results
        return try await getDatasetResults(datasetId: defaultDatasetId)
    }
}

// MARK: - Apify Job Result Model
struct ApifyJobResult: Codable {
    let jobTitle: String?
    let company: String?
    let location: String?
    let jobDescription: String?
    let applyUrl: String?
    let salaryRange: String?
    let employmentType: String?
    let seniorityLevel: String?
    
    enum CodingKeys: String, CodingKey {
        case jobTitle = "job_title"
        case company
        case location
        case jobDescription = "job_description"
        case applyUrl = "apply_url"
        case salaryRange = "salary_range"
        case employmentType = "employment_type"
        case seniorityLevel = "seniority_level"
    }
}

enum ApifyError: LocalizedError {
    case invalidURL
    case requestFailed
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Apify API URL"
        case .requestFailed:
            return "Failed to communicate with Apify API"
        case .invalidResponse:
            return "Invalid response from Apify API"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        }
    }
}


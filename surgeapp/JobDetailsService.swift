//
//  JobDetailsService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Job Details Service
class JobDetailsService {
    static let shared = JobDetailsService()
    
    private init() {}
    
    // MARK: - Fetch Job Details from URL (via Edge Function)
    func fetchJobDetails(from urlString: String) async throws -> JobDetails {
        guard let edgeFunctionURL = URL(string: "\(Config.supabaseURL)/functions/v1/job-details") else {
            throw JobDetailsError.invalidURL
        }
        
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 15.0
        
        let requestBody: [String: Any] = ["jobUrl": urlString]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JobDetailsError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw JobDetailsError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Parse response - handle both wrapped and direct array formats
        print("📥 Job Details Response: \(String(data: data, encoding: .utf8) ?? "Unable to decode")")
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Handle wrapped format: { sections: [...] }
            if let sectionsArray = json["sections"] as? [[String: Any]] {
                print("✅ Found \(sectionsArray.count) sections in wrapped format")
                let sections = try sectionsArray.compactMap { sectionDict -> JobSection? in
                    do {
                        let sectionData = try JSONSerialization.data(withJSONObject: sectionDict)
                        return try JSONDecoder().decode(JobSection.self, from: sectionData)
                    } catch {
                        print("⚠️ Failed to decode section: \(error)")
                        return nil
                    }
                }
                return JobDetails(sections: sections)
            }
            
            // Check for error in response
            if let errorMessage = json["error"] as? String {
                print("❌ Edge Function error: \(errorMessage)")
                throw JobDetailsError.httpError(statusCode: 500)
            }
        }
        
        // Try parsing as direct array format: [...]
        if let sectionsArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            print("✅ Found \(sectionsArray.count) sections in array format")
            let sections = try sectionsArray.compactMap { sectionDict -> JobSection? in
                do {
                    let sectionData = try JSONSerialization.data(withJSONObject: sectionDict)
                    return try JSONDecoder().decode(JobSection.self, from: sectionData)
                } catch {
                    print("⚠️ Failed to decode section: \(error)")
                    return nil
                }
            }
            return JobDetails(sections: sections)
        }
        
        // If no sections found, return empty
        print("⚠️ No sections found in response")
        return JobDetails(sections: [])
    }
}

// MARK: - Job Details Model
struct JobDetails: Codable {
    let sections: [JobSection]
}

// MARK: - Job Details Error
enum JobDetailsError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case invalidResponse
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid job URL"
        case .httpError(let statusCode):
            return "Failed to fetch job details: HTTP \(statusCode)"
        case .invalidResponse:
            return "Invalid response from job page"
        case .parsingFailed:
            return "Failed to parse job details"
        }
    }
}


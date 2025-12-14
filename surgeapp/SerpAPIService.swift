//
//  SerpAPIService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - SerpAPI Service
class SerpAPIService {
    static let shared = SerpAPIService()
    
    // SerpAPI key from Config.swift (gitignored)
    private let apiKey = Config.serpApiKey
    
    private init() {}
    
    // MARK: - Search LinkedIn Profiles
    func searchLinkedInProfiles(position: String, company: String) async throws -> [LinkedInProfileResult] {
        // Build search query: LinkedIn + Position + Company -jobs -careers -openings site:linkedin.com
        let query = "LinkedIn \(position) \(company) -jobs -careers -openings site:linkedin.com"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        
        guard var urlComponents = URLComponents(string: "https://serpapi.com/search.json") else {
            throw SerpAPIError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "engine", value: "google"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            throw SerpAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SerpAPIError.requestFailed
        }
        
        let decoder = JSONDecoder()
        let serpResponse = try decoder.decode(SerpAPIResponse.self, from: data)
        
        // Process results
        var profiles: [LinkedInProfileResult] = []
        var seenLinks = Set<String>()
        
        for result in serpResponse.organicResults {
            // Extract name (remove " | LinkedIn" suffix)
            let name = result.title.replacingOccurrences(of: " | LinkedIn", with: "")
            
            // Filter out job-related results
            let lowerName = name.lowercased()
            if lowerName.contains("hiring") ||
               lowerName.contains("jobs") ||
               lowerName.contains("recruiting") ||
               lowerName.contains("careers") ||
               lowerName.contains("open positions") {
                continue
            }
            
            // Remove duplicates based on LinkedIn URL
            if !seenLinks.contains(result.link) {
                seenLinks.insert(result.link)
                profiles.append(LinkedInProfileResult(
                    name: name.isEmpty ? "N/A" : name,
                    linkedinUrl: result.link.isEmpty ? "N/A" : result.link
                ))
            }
        }
        
        return profiles
    }
}

// MARK: - SerpAPI Response Models
struct SerpAPIResponse: Codable {
    let organicResults: [OrganicResult]
    
    enum CodingKeys: String, CodingKey {
        case organicResults = "organic_results"
    }
}

struct OrganicResult: Codable {
    let title: String
    let link: String
}

struct LinkedInProfileResult {
    let name: String
    let linkedinUrl: String
}

enum SerpAPIError: LocalizedError {
    case invalidURL
    case requestFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid SerpAPI URL"
        case .requestFailed:
            return "Failed to search LinkedIn profiles using SerpAPI"
        }
    }
}


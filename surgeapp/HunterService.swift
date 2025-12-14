//
//  HunterService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Hunter.io Service
class HunterService {
    static let shared = HunterService()
    
    // Hunter.io API key from Config.swift (gitignored)
    private let apiKey = Config.hunterApiKey
    
    private init() {}
    
    // MARK: - Generate Domain from Company Name
    func generateDomain(from company: String) -> String {
        // Convert to lowercase, remove spaces, add .com
        let cleaned = company.lowercased().replacingOccurrences(of: " ", with: "")
        return "\(cleaned).com"
    }
    
    // MARK: - Find Email
    func findEmail(company: String, firstName: String, lastName: String) async throws -> HunterEmailResult {
        let domain = generateDomain(from: company)
        
        guard var urlComponents = URLComponents(string: "https://api.hunter.io/v2/email-finder") else {
            throw HunterError.invalidURL
        }
        
        urlComponents.queryItems = [
            URLQueryItem(name: "domain", value: domain),
            URLQueryItem(name: "first_name", value: firstName),
            URLQueryItem(name: "last_name", value: lastName),
            URLQueryItem(name: "api_key", value: apiKey)
        ]
        
        guard let url = urlComponents.url else {
            throw HunterError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw HunterError.requestFailed
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(HunterResponse.self, from: data)
        
        if let emailData = result.data {
            return HunterEmailResult(
                email: emailData.email,
                firstName: emailData.firstName ?? firstName,
                lastName: emailData.lastName ?? lastName,
                company: company,
                found: true
            )
        } else {
            return HunterEmailResult(
                email: nil,
                firstName: firstName,
                lastName: lastName,
                company: company,
                found: false
            )
        }
    }
}

// MARK: - Hunter.io Response Models
struct HunterResponse: Codable {
    let data: HunterEmailData?
    let meta: HunterMeta?
}

struct HunterEmailData: Codable {
    let email: String
    let firstName: String?
    let lastName: String?
    
    enum CodingKeys: String, CodingKey {
        case email
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct HunterMeta: Codable {
    let params: HunterParams?
}

struct HunterParams: Codable {
    let domain: String?
    let firstName: String?
    let lastName: String?
    
    enum CodingKeys: String, CodingKey {
        case domain
        case firstName = "first_name"
        case lastName = "last_name"
    }
}

struct HunterEmailResult {
    let email: String?
    let firstName: String
    let lastName: String
    let company: String
    let found: Bool
    
    var fullName: String {
        "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
    }
}

enum HunterError: LocalizedError {
    case invalidURL
    case requestFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Hunter.io API URL"
        case .requestFailed:
            return "Failed to find email using Hunter.io"
        }
    }
}


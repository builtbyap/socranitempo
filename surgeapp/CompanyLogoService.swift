//
//  CompanyLogoService.swift
//  surgeapp
//
//  Service to fetch and cache company logos
//

import Foundation
import SwiftUI

class CompanyLogoService {
    static let shared = CompanyLogoService()
    
    private var logoCache: [String: UIImage] = [:]
    private var failedLogos: Set<String> = []
    
    private init() {}
    
    // MARK: - Fetch Company Logo
    func fetchCompanyLogo(companyName: String, jobUrl: String? = nil) async -> UIImage? {
        // Check cache first
        if let cachedLogo = logoCache[companyName.lowercased()] {
            return cachedLogo
        }
        
        // Skip if we've already failed to fetch this logo
        if failedLogos.contains(companyName.lowercased()) {
            return nil
        }
        
        // Try to get domain from company name first (more reliable)
        // Job URLs often point to job boards (Adzuna, Indeed, etc.) not the company's website
        var domain: String? = nil
        
        // First, try to construct domain from company name (most reliable)
        domain = constructDomain(from: companyName)
        
        // Only use job URL if it's not from a known job board
        // Check if the domain from URL is a job board - if so, ignore it
        if let urlString = jobUrl, let url = URL(string: urlString), let host = url.host {
            let extractedDomain = extractDomain(from: host)
            // Only use if it's not empty (meaning it's not a job board) and we don't have a domain yet
            if !extractedDomain.isEmpty && domain == nil {
                domain = extractedDomain
            }
        }
        
        // Try fetching with initial domain
        if let domain = domain {
            if let logo = await fetchLogoFromDomain(domain) {
                logoCache[companyName.lowercased()] = logo
                return logo
            }
        }
        
        // If initial fetch failed, try using AI to find the correct domain
        if let aiDomain = await findCompanyDomainWithAI(companyName: companyName, jobUrl: jobUrl) {
            if let logo = await fetchLogoFromDomain(aiDomain) {
                logoCache[companyName.lowercased()] = logo
                return logo
            }
        }
        
        // All attempts failed
        failedLogos.insert(companyName.lowercased())
        return nil
    }
    
    // MARK: - Fetch Logo from Domain
    private func fetchLogoFromDomain(_ domain: String) async -> UIImage? {
        // Use logo.dev API (like sorce.jobs)
        // Format: https://img.logo.dev/{domain}?token={api_key}
        // If no API key, use the free tier (may have rate limits)
        let apiKey = Config.logoDevApiKey
        
        var logoURL: String
        if !apiKey.isEmpty {
            logoURL = "https://img.logo.dev/\(domain)?token=\(apiKey)&fallback=404"
        } else {
            // Try without API key (may work for some domains, but limited)
            logoURL = "https://img.logo.dev/\(domain)?fallback=404"
        }
        
        guard let url = URL(string: logoURL) else {
            return nil
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let image = UIImage(data: data) else {
                return nil
            }
            
            return image
            
        } catch {
            return nil
        }
    }
    
    // MARK: - Find Company Domain with AI
    private func findCompanyDomainWithAI(companyName: String, jobUrl: String?) async -> String? {
        // Use OpenAI to find the correct company domain
        let prompt = """
        Given the company name "\(companyName)"\(jobUrl != nil ? " and job URL \(jobUrl!)" : ""), 
        provide ONLY the company's main website domain (e.g., "apple.com", "google.com", "microsoft.com").
        Do not include "www." or "https://". Just return the domain name.
        If you cannot determine the domain, return "null".
        """
        
        do {
            let apiKey = Config.openAIKey
            guard !apiKey.isEmpty else {
                return nil
            }
            
            guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                return nil
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let requestBody: [String: Any] = [
                "model": "gpt-4o-mini",
                "messages": [
                    [
                        "role": "system",
                        "content": "You are a helpful assistant that provides company website domains. Return ONLY the domain name, nothing else."
                    ],
                    [
                        "role": "user",
                        "content": prompt
                    ]
                ],
                "temperature": 0.1,
                "max_tokens": 50
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                return nil
            }
            
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                return nil
            }
            
            let domain = content.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: "'", with: "")
                .lowercased()
            
            // Validate domain format
            if domain.contains(".") && !domain.contains(" ") && domain != "null" {
                return domain
            }
            
            return nil
            
        } catch {
            print("⚠️ AI domain lookup failed for \(companyName): \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Extract Domain from Host
    private func extractDomain(from host: String) -> String {
        // Remove www. prefix
        var domain = host.replacingOccurrences(of: "www.", with: "")
        
        // Skip job board domains - these are not the company's domain
        let jobBoardDomains = [
            "adzuna.com", "adzuna.co.uk", "adzuna.com.au",
            "indeed.com", "indeed.co.uk",
            "monster.com", "monster.co.uk",
            "glassdoor.com", "glassdoor.co.uk",
            "ziprecruiter.com",
            "linkedin.com", "linkedin.co.uk",
            "themuse.com",
            "myworkdayjobs.com", "workday.com",
            "greenhouse.io", "lever.co"
        ]
        
        for jobBoard in jobBoardDomains {
            if domain.contains(jobBoard) {
                // This is a job board URL, not the company's domain
                return ""
            }
        }
        
        // Remove common subdomains
        let subdomains = ["careers", "jobs", "job", "hiring", "recruiting", "talent"]
        for subdomain in subdomains {
            if domain.hasPrefix("\(subdomain).") {
                domain = String(domain.dropFirst(subdomain.count + 1))
                break
            }
        }
        
        return domain
    }
    
    // MARK: - Construct Domain from Company Name
    private func constructDomain(from companyName: String) -> String {
        // Clean company name
        var domain = companyName
            .lowercased()
            .replacingOccurrences(of: " inc", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " inc.", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " llc", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " corp", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " corporation", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ltd", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " limited", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " & ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " and ", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Add .com if no TLD
        if !domain.contains(".") {
            domain = "\(domain).com"
        }
        
        return domain
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        logoCache.removeAll()
        failedLogos.removeAll()
    }
}

// MARK: - AsyncImage Wrapper for Company Logo
struct CompanyLogoView: View {
    let companyName: String
    let jobUrl: String?
    let size: CGFloat
    
    @State private var logoImage: UIImage? = nil
    @State private var isLoading = false
    
    init(companyName: String, jobUrl: String? = nil, size: CGFloat = 48) {
        self.companyName = companyName
        self.jobUrl = jobUrl
        self.size = size
    }
    
    var body: some View {
        Group {
            if let logo = logoImage {
                Image(uiImage: logo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if isLoading {
                // Loading placeholder
                ZStack {
                    Circle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: size, height: size)
                    ProgressView()
                        .scaleEffect(0.6)
                }
            } else {
                // Fallback to letter placeholder
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: size, height: size)
                    Text(String(companyName.prefix(1)).uppercased())
                        .font(.system(size: size * 0.4, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            if logoImage == nil && !isLoading {
                loadLogo()
            }
        }
    }
    
    private func loadLogo() {
        isLoading = true
        Task {
            let logo = await CompanyLogoService.shared.fetchCompanyLogo(
                companyName: companyName,
                jobUrl: jobUrl
            )
            await MainActor.run {
                self.logoImage = logo
                self.isLoading = false
            }
        }
    }
}


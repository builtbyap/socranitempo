//
//  SupabaseService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Supabase Service
// TODO: Replace with your actual Supabase URL and anon key
class SupabaseService {
    static let shared = SupabaseService()
    
    // Supabase credentials from Config.swift (gitignored)
    private let supabaseURL = Config.supabaseURL
    private let supabaseKey = Config.supabaseKey
    
    private init() {}
    
    // MARK: - Job Posts
    func fetchJobPosts() async throws -> [JobPost] {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/job_posts?select=*&order=posted_date.desc") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([JobPost].self, from: data)
    }
    
    // MARK: - LinkedIn Profiles
    func fetchLinkedInProfiles() async throws -> [LinkedInProfile] {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/profiles?select=*") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([LinkedInProfile].self, from: data)
    }
    
    // MARK: - Email Contacts
    func fetchEmailContacts() async throws -> [EmailContact] {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/emails?select=*") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode([EmailContact].self, from: data)
    }
    
    // MARK: - Insert Job Posts
    func insertJobPosts(_ posts: [JobPost]) async throws {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/job_posts") else {
            throw SupabaseError.invalidURL
        }
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        
        var successCount = 0
        var errorMessages: [String] = []
        
        for (index, post) in posts.enumerated() {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("public", forHTTPHeaderField: "Accept-Profile")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            do {
                let postData = try encoder.encode(post)
                request.httpBody = postData
                
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    errorMessages.append("Post \(index + 1): Invalid response")
                    continue
                }
                
                if (200...299).contains(httpResponse.statusCode) {
                    successCount += 1
                } else {
                    let errorData = String(data: data, encoding: .utf8) ?? "Unknown error"
                    errorMessages.append("Post \(index + 1): HTTP \(httpResponse.statusCode) - \(errorData)")
                    print("❌ Failed to insert post \(index + 1): HTTP \(httpResponse.statusCode) - \(errorData)")
                }
            } catch {
                errorMessages.append("Post \(index + 1): \(error.localizedDescription)")
                print("❌ Error encoding/inserting post \(index + 1): \(error)")
            }
        }
        
        print("✅ Successfully inserted \(successCount) out of \(posts.count) job posts")
        
        if successCount == 0 && !errorMessages.isEmpty {
            throw SupabaseError.httpError(
                statusCode: 0,
                message: "Failed to insert any posts. First error: \(errorMessages.first ?? "Unknown")"
            )
        }
    }
    
    // MARK: - Insert Email Contact
    func insertEmailContact(_ contact: EmailContact) async throws {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/emails") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let contactData = try encoder.encode(contact)
        request.httpBody = contactData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
    }
    
    // MARK: - Insert LinkedIn Profiles
    func insertLinkedInProfiles(_ profiles: [LinkedInProfile]) async throws {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/profiles") else {
            throw SupabaseError.invalidURL
        }
        
        let encoder = JSONEncoder()
        
        for profile in profiles {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("public", forHTTPHeaderField: "Accept-Profile")
            request.setValue("return=representation", forHTTPHeaderField: "Prefer")
            
            let profileData = try encoder.encode(profile)
            request.httpBody = profileData
            
            let (_, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                // Continue with next profile even if one fails
                continue
            }
        }
    }
    
    // MARK: - Applications
    func fetchApplications() async throws -> [Application] {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/applications?select=*&order=applied_date.desc") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode([Application].self, from: data)
    }
    
    func insertApplication(_ application: Application) async throws {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/applications") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let applicationData = try encoder.encode(application)
        request.httpBody = applicationData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: "Failed to insert application: \(errorMessage)")
        }
    }
    
    // MARK: - Resume Data
    func insertResumeData(_ resumeData: ResumeData) async throws {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/resume_data") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        // Create a dictionary for encoding (to handle nested arrays properly)
        var resumeDict: [String: Any] = [
            "id": resumeData.id,
            "parsed_at": resumeData.parsedAt
        ]
        
        if let name = resumeData.name {
            resumeDict["name"] = name
        }
        if let email = resumeData.email {
            resumeDict["email"] = email
        }
        if let phone = resumeData.phone {
            resumeDict["phone"] = phone
        }
        if let skills = resumeData.skills {
            resumeDict["skills"] = skills
        }
        if let resumeUrl = resumeData.resumeUrl {
            resumeDict["resume_url"] = resumeUrl
        }
        
        // Encode work experience as JSONB
        if let workExp = resumeData.workExperience {
            let workExpEncoder = JSONEncoder()
            workExpEncoder.keyEncodingStrategy = .convertToSnakeCase
            if let workExpData = try? workExpEncoder.encode(workExp),
               let workExpJson = try? JSONSerialization.jsonObject(with: workExpData) {
                resumeDict["work_experience"] = workExpJson
            }
        }
        
        // Encode education as JSONB
        if let education = resumeData.education {
            let educationEncoder = JSONEncoder()
            educationEncoder.keyEncodingStrategy = .convertToSnakeCase
            if let educationData = try? educationEncoder.encode(education),
               let educationJson = try? JSONSerialization.jsonObject(with: educationData) {
                resumeDict["education"] = educationJson
            }
        }
        
        // Encode projects as JSONB
        if let projects = resumeData.projects {
            let projectsEncoder = JSONEncoder()
            projectsEncoder.keyEncodingStrategy = .convertToSnakeCase
            if let projectsData = try? projectsEncoder.encode(projects),
               let projectsJson = try? JSONSerialization.jsonObject(with: projectsData) {
                resumeDict["projects"] = projectsJson
            }
        }
        
        // Encode languages as JSONB
        if let languages = resumeData.languages {
            let languagesEncoder = JSONEncoder()
            languagesEncoder.keyEncodingStrategy = .convertToSnakeCase
            if let languagesData = try? languagesEncoder.encode(languages),
               let languagesJson = try? JSONSerialization.jsonObject(with: languagesData) {
                resumeDict["languages"] = languagesJson
            }
        }
        
        // Encode certifications as JSONB
        if let certifications = resumeData.certifications {
            let certsEncoder = JSONEncoder()
            certsEncoder.keyEncodingStrategy = .convertToSnakeCase
            if let certsData = try? certsEncoder.encode(certifications),
               let certsJson = try? JSONSerialization.jsonObject(with: certsData) {
                resumeDict["certifications"] = certsJson
            }
        }
        
        // Encode awards as JSONB
        if let awards = resumeData.awards {
            let awardsEncoder = JSONEncoder()
            awardsEncoder.keyEncodingStrategy = .convertToSnakeCase
            if let awardsData = try? awardsEncoder.encode(awards),
               let awardsJson = try? JSONSerialization.jsonObject(with: awardsData) {
                resumeDict["awards"] = awardsJson
            }
        }
        
        let resumeDataEncoded = try JSONSerialization.data(withJSONObject: resumeDict)
        request.httpBody = resumeDataEncoded
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: "Failed to insert resume data: \(errorMessage)")
        }
    }
}

enum SupabaseError: LocalizedError {
    case notConfigured
    case invalidURL
    case requestFailed
    case httpError(statusCode: Int, message: String)
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Supabase credentials not configured. Please add your Supabase URL and API key in SupabaseService.swift"
        case .invalidURL:
            return "Invalid Supabase URL"
        case .requestFailed:
            return "Failed to fetch data from Supabase"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        }
    }
}


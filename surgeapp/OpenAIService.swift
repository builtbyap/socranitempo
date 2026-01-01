//
//  OpenAIService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    
    private let apiKey = Config.openAIKey
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    // Cache for job description summaries to avoid re-fetching
    private var summaryCache: [String: JobDescriptionSummary] = [:]
    
    private init() {}
    
    // MARK: - Parse and Categorize Resume
    func parseAndCategorizeResume(text: String) async throws -> ResumeData {
        let prompt = createResumeParsingPrompt(text: text)
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Using gpt-4o-mini for cost efficiency
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert resume parser. Extract information from resumes and return ONLY valid, accurate data in the exact JSON format requested. Do not include any information that doesn't belong in a category. Be precise and accurate."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.1 // Low temperature for consistent, accurate results
        ]
        
        // Add response_format for JSON mode
        requestBody["response_format"] = ["type": "json_object"]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.requestFailed(message: "No HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.requestFailed(message: "HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse OpenAI response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse(message: "Invalid response format")
        }
        
        // Parse JSON content
        guard let jsonData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse(message: "Could not convert content to data")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let parsedResume = try decoder.decode(OpenAIResumeResponse.self, from: jsonData)
            return convertToResumeData(parsedResume)
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            print("📄 Response content: \(content)")
            throw OpenAIError.invalidResponse(message: "Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Summarize Job Description
    func summarizeJobDescription(_ description: String) async throws -> JobDescriptionSummary {
        // Create cache key from description hash (first 500 chars for uniqueness)
        let cacheKey = String(description.prefix(500))
        
        // Check cache first
        if let cachedSummary = summaryCache[cacheKey] {
            print("✅ Using cached summary for job description")
            return cachedSummary
        }
        
        // Truncate description to first 2000 characters for faster processing
        // Most important info is usually at the beginning
        let truncatedDescription = String(description.prefix(2000))
        let prompt = createJobDescriptionPrompt(description: truncatedDescription)
        
        guard let url = URL(string: baseURL) else {
            throw OpenAIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10.0 // Reduce timeout for faster failure handling
        
        var requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Already using fastest model
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert job description analyzer. Summarize job descriptions into organized bullet points with clear subcategories. Extract all important information and present it in a structured, easy-to-read format. Be concise and focus on key information."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.2, // Lower temperature for faster, more deterministic responses
            "max_tokens": 800 // Limit response size for faster generation
        ]
        
        // Add response_format for JSON mode
        requestBody["response_format"] = ["type": "json_object"]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIError.requestFailed(message: "No HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw OpenAIError.requestFailed(message: "HTTP \(httpResponse.statusCode): \(errorMessage)")
        }
        
        // Parse OpenAI response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw OpenAIError.invalidResponse(message: "Invalid response format")
        }
        
        // Parse JSON content
        guard let jsonData = content.data(using: .utf8) else {
            throw OpenAIError.invalidResponse(message: "Could not convert content to data")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        do {
            let summary = try decoder.decode(JobDescriptionSummaryResponse.self, from: jsonData)
            let convertedSummary = convertToJobDescriptionSummary(summary)
            
            // Cache the summary
            let cacheKey = String(description.prefix(500))
            summaryCache[cacheKey] = convertedSummary
            
            return convertedSummary
        } catch {
            print("❌ JSON Decoding Error: \(error)")
            print("📄 Response content: \(content)")
            throw OpenAIError.invalidResponse(message: "Failed to parse JSON: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Create Job Description Prompt
    private func createJobDescriptionPrompt(description: String) -> String {
        return """
        Analyze the following job description and summarize it into organized bullet points with clear subcategories. Extract all important information including responsibilities, requirements, qualifications, benefits, and any other relevant details.

        Return a JSON object with this exact structure:
        {
          "summary": "Brief 2-3 sentence overview of the role",
          "categories": [
            {
              "title": "Category name (e.g., 'Responsibilities', 'Requirements', 'Qualifications', 'Benefits', 'What You'll Do', etc.)",
              "items": [
                "Bullet point 1",
                "Bullet point 2",
                "Bullet point 3"
              ]
            }
          ]
        }

        Rules:
        1. Create logical subcategories based on the content (e.g., "Responsibilities", "Required Qualifications", "Preferred Skills", "Benefits", "Company Culture", etc.)
        2. Each category should have 3-8 bullet points
        3. Bullet points should be concise but informative (1-2 sentences max)
        4. Extract all important information - don't skip details
        5. Use clear, professional language
        6. If information doesn't fit a category, create an "Additional Information" category
        7. Ensure all key requirements, responsibilities, and benefits are captured

        Job description:
        \(description)
        """
    }
    
    // MARK: - Convert OpenAI Response to JobDescriptionSummary
    private func convertToJobDescriptionSummary(_ response: JobDescriptionSummaryResponse) -> JobDescriptionSummary {
        return JobDescriptionSummary(
            summary: response.summary ?? "",
            categories: response.categories?.map { category in
                JobDescriptionCategory(
                    title: category.title ?? "Information",
                    items: category.items ?? []
                )
            } ?? []
        )
    }
    
    // MARK: - Create Prompt
    private func createResumeParsingPrompt(text: String) -> String {
        return """
        Parse the following resume text and extract information into these exact categories. Return ONLY valid information - do not include placeholder text, incomplete entries, or information that doesn't belong.

        Return a JSON object with this exact structure:
        {
          "name": "Full name or null",
          "email": "Email address or null",
          "phone": "Phone number or null",
          "skills": ["skill1", "skill2"] or null,
          "work_experience": [
            {
              "title": "Job title",
              "company": "Company name",
              "duration": "Date range or null",
              "description": "Job description or null"
            }
          ] or null,
          "education": [
            {
              "degree": "Degree name",
              "school": "School name",
              "year": "Year or null"
            }
          ] or null,
          "projects": [
            {
              "name": "Project name",
              "description": "Description or null",
              "technologies": "Tech stack or null",
              "url": "Project URL or null"
            }
          ] or null,
          "languages": [
            {
              "name": "Language name",
              "proficiency": "Proficiency level or null"
            }
          ] or null,
          "certifications": [
            {
              "name": "Certification name",
              "issuer": "Issuing organization or null",
              "date": "Date earned or null",
              "expiry_date": "Expiry date or null"
            }
          ] or null,
          "awards": [
            {
              "title": "Award title",
              "issuer": "Issuing organization or null",
              "date": "Date received or null",
              "description": "Description or null"
            }
          ] or null
        }

        Rules:
        1. Only include complete, valid information
        2. Do not include placeholder text like "N/A", "TBD", "To be determined"
        3. Do not include incomplete entries (e.g., job titles without companies)
        4. Skills should be actual technical/professional skills, not generic words
        5. Work experience must have at least a title and company
        6. Education must have at least a degree and school
        7. If a category has no valid data, return null for that field
        8. Clean and normalize all text (remove extra spaces, fix capitalization)

        Resume text:
        \(text)
        """
    }
    
    // MARK: - Convert OpenAI Response to ResumeData
    private func convertToResumeData(_ response: OpenAIResumeResponse) -> ResumeData {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return ResumeData(
            id: UUID().uuidString,
            name: response.name?.isEmpty == false ? response.name : nil,
            email: response.email?.isEmpty == false ? response.email : nil,
            phone: response.phone?.isEmpty == false ? response.phone : nil,
            skills: response.skills?.isEmpty == false ? response.skills : nil,
            workExperience: response.workExperience?.isEmpty == false ? response.workExperience : nil,
            education: response.education?.isEmpty == false ? response.education : nil,
            projects: response.projects?.isEmpty == false ? response.projects : nil,
            languages: response.languages?.isEmpty == false ? response.languages : nil,
            certifications: response.certifications?.isEmpty == false ? response.certifications : nil,
            awards: response.awards?.isEmpty == false ? response.awards : nil,
            resumeUrl: nil,
            parsedAt: dateFormatter.string(from: Date())
        )
    }
}

// MARK: - OpenAI Response Models
struct OpenAIResumeResponse: Codable {
    let name: String?
    let email: String?
    let phone: String?
    let skills: [String]?
    let workExperience: [WorkExperience]?
    let education: [Education]?
    let projects: [Project]?
    let languages: [Language]?
    let certifications: [Certification]?
    let awards: [Award]?
}

// MARK: - Job Description Summary Models
struct JobDescriptionSummary {
    let summary: String
    let categories: [JobDescriptionCategory]
}

struct JobDescriptionCategory {
    let title: String
    let items: [String]
}

struct JobDescriptionSummaryResponse: Codable {
    let summary: String?
    let categories: [JobDescriptionCategoryResponse]?
}

struct JobDescriptionCategoryResponse: Codable {
    let title: String?
    let items: [String]?
}

enum OpenAIError: LocalizedError {
    case invalidURL
    case requestFailed(message: String)
    case invalidResponse(message: String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid OpenAI API URL"
        case .requestFailed(let message):
            return "OpenAI API request failed: \(message)"
        case .invalidResponse(let message):
            return "Invalid OpenAI API response: \(message)"
        }
    }
}


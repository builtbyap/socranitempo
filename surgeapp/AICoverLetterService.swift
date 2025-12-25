//
//  AICoverLetterService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - AI Cover Letter Service
class AICoverLetterService {
    static let shared = AICoverLetterService()
    
    private init() {}
    
    // MARK: - Generate AI Cover Letter
    func generateCoverLetter(
        for job: JobPost,
        userProfile: UserProfileData,
        resumeData: ResumeData?
    ) async throws -> String {
        // Build prompt for OpenAI
        let prompt = buildCoverLetterPrompt(job: job, userProfile: userProfile, resumeData: resumeData)
        
        // Call OpenAI API
        let coverLetter = try await callOpenAI(prompt: prompt)
        
        return coverLetter
    }
    
    // MARK: - Build Prompt
    private func buildCoverLetterPrompt(
        job: JobPost,
        userProfile: UserProfileData,
        resumeData: ResumeData?
    ) -> String {
        var prompt = """
        Write a professional, personalized cover letter for the following job application.
        
        JOB INFORMATION:
        - Position: \(job.title)
        - Company: \(job.company)
        - Location: \(job.location)
        - Description: \(job.description ?? "Not provided")
        
        APPLICANT INFORMATION:
        - Name: \(userProfile.firstName) \(userProfile.lastName)
        - Title: \(userProfile.title.isEmpty ? "Professional" : userProfile.title)
        - Location: \(userProfile.location)
        """
        
        if let resumeData = resumeData {
            prompt += "\n\nWORK EXPERIENCE:\n"
            if let workExp = resumeData.workExperience {
                for exp in workExp.prefix(3) {
                    prompt += "- \(exp.title) at \(exp.company)"
                    if let desc = exp.description {
                        prompt += ": \(desc.prefix(200))"
                    }
                    prompt += "\n"
                }
            }
            
            prompt += "\nEDUCATION:\n"
            if let education = resumeData.education {
                for edu in education.prefix(2) {
                    prompt += "- \(edu.degree) from \(edu.school)\n"
                }
            }
            
            prompt += "\nSKILLS:\n"
            if let skills = resumeData.skills {
                prompt += skills.prefix(10).joined(separator: ", ")
                prompt += "\n"
            }
        }
        
        prompt += """
        
        REQUIREMENTS:
        1. Keep it professional and concise (3-4 paragraphs)
        2. Highlight relevant experience and skills
        3. Show enthusiasm for the role and company
        4. Include a strong closing statement
        5. Use a professional tone
        6. Address it to "Hiring Manager" if no specific name is available
        
        Generate the cover letter now:
        """
        
        return prompt
    }
    
    // MARK: - Call OpenAI
    private func callOpenAI(prompt: String) async throws -> String {
        let apiKey = Config.openAIKey
        guard !apiKey.isEmpty else {
            throw NSError(domain: "AICoverLetterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "OpenAI API key not configured"])
        }
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw NSError(domain: "AICoverLetterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid API URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Using cheaper model, can upgrade to gpt-4 if needed
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional career coach and cover letter writer. Write compelling, personalized cover letters that help job applicants stand out."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "temperature": 0.7,
            "max_tokens": 1000
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "AICoverLetterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "AICoverLetterService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "API error: \(errorMessage)"])
        }
        
        // Parse response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw NSError(domain: "AICoverLetterService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


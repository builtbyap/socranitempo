//
//  AutoApplyService.swift
//  surgeapp
//
//  Service to call Fly.io Playwright service via Supabase Edge Function
//  Fully automates job applications like sorce.jobs
//

import Foundation

// MARK: - Auto Apply Service
class AutoApplyService {
    static let shared = AutoApplyService()
    
    private init() {}
    
    // MARK: - Auto Apply with Playwright
    func autoApply(
        job: JobPost,
        applicationData: ApplicationData
    ) async throws -> AutoApplyResult {
        guard let backendURL = URL(string: Config.autoApplyBackendURL) else {
            throw AutoApplyError.invalidURL
        }
        
        // Prepare resume base64 if available
        var resumeBase64: String? = nil
        var resumeFileName: String? = nil
        
        if let resumeURL = applicationData.resumeURL {
            if let url = URL(string: resumeURL), url.scheme == "file" || url.scheme == nil {
                // Local file path
                let filePath = url.path.isEmpty ? resumeURL : url.path
                if FileManager.default.fileExists(atPath: filePath),
                   let data = try? Data(contentsOf: URL(fileURLWithPath: filePath)) {
                    resumeBase64 = data.base64EncodedString()
                    resumeFileName = URL(fileURLWithPath: filePath).lastPathComponent
                }
            } else if let url = URL(string: resumeURL),
                      url.scheme != nil,
                      let data = try? Data(contentsOf: url) {
                // Remote URL
                resumeBase64 = data.base64EncodedString()
                resumeFileName = URL(string: resumeURL)?.lastPathComponent ?? "resume.pdf"
            }
        }
        
        // Prepare request body
        var appDataDict: [String: Any] = [
            "fullName": applicationData.fullName,
            "email": applicationData.email,
            "phone": applicationData.phone,
            "location": applicationData.location,
            "linkedIn": applicationData.linkedInURL,
            "github": applicationData.githubURL,
            "portfolio": applicationData.portfolioURL,
            "coverLetter": applicationData.coverLetter,
            "resumeUrl": applicationData.resumeURL ?? ""
        ]
        
        var requestBody: [String: Any] = [
            "jobUrl": job.url ?? "",
            "jobTitle": job.title,
            "company": job.company,
            "applicationData": appDataDict
        ]
        
        // Add base64 resume if available
        if let resumeBase64 = resumeBase64, let resumeFileName = resumeFileName {
            if var appData = requestBody["applicationData"] as? [String: Any] {
                appData["resumeBase64"] = resumeBase64
                appData["resumeFileName"] = resumeFileName
                requestBody["applicationData"] = appData
            }
        }
        
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 180.0 // 3 minutes timeout
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🚀 Calling Playwright service for: \(job.title) at \(job.company)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AutoApplyError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Auto-apply failed: HTTP \(httpResponse.statusCode) - \(errorMessage)")
            throw AutoApplyError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(AutoApplyResult.self, from: data)
        
        print("✅ Auto-apply result: success=\(result.success), filledFields=\(result.filledFields), atsSystem=\(result.atsSystem)")
        
        return result
    }
    
    // MARK: - Resume Application with Answers
    func resumeApplicationWithAnswers(
        application: Application,
        answers: [Int: String]
    ) async throws -> AutoApplyResult {
        guard let backendURL = URL(string: Config.autoApplyBackendURL) else {
            throw AutoApplyError.invalidURL
        }
        
        guard let jobUrl = application.jobUrl, !jobUrl.isEmpty else {
            throw AutoApplyError.invalidURL
        }
        
        // Get application data
        let profileData = SimpleApplyService.shared.getUserProfileData()
        let applicationData = SimpleApplyService.shared.generateApplicationData(
            for: JobPost(
                id: application.jobPostId,
                title: application.jobTitle,
                company: application.company,
                location: "",
                postedDate: application.appliedDate,
                description: nil,
                url: jobUrl,
                salary: nil,
                jobType: nil,
                sections: nil
            ),
            profileData: profileData
        )
        
        // Convert answers from [Int: String] to [String: String] for JSON
        var answersDict: [String: String] = [:]
        for (key, value) in answers {
            answersDict[String(key)] = value
        }
        
        // Prepare request body with answers
        var appDataDict: [String: Any] = [
            "fullName": applicationData.fullName,
            "email": applicationData.email,
            "phone": applicationData.phone,
            "location": applicationData.location,
            "linkedIn": applicationData.linkedInURL,
            "github": applicationData.githubURL,
            "portfolio": applicationData.portfolioURL,
            "coverLetter": applicationData.coverLetter,
            "resumeUrl": applicationData.resumeURL ?? ""
        ]
        
        var requestBody: [String: Any] = [
            "jobUrl": jobUrl,
            "jobTitle": application.jobTitle,
            "company": application.company,
            "applicationData": appDataDict,
            "answers": answersDict
        ]
        
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 180.0
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        print("🔄 Resuming application with answers for: \(application.jobTitle)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AutoApplyError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AutoApplyError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let decoder = JSONDecoder()
        let result = try decoder.decode(AutoApplyResult.self, from: data)
        
        return result
    }
}

// MARK: - Auto Apply Result
struct AutoApplyResult: Codable {
    let success: Bool
    let filledFields: Int
    let atsSystem: String
    let error: String?
    let screenshot: String? // Base64 screenshot for debugging
    let questions: [PendingQuestion]? // Questions that need user input
    let needsUserInput: Bool? // Whether user needs to answer questions
}

// MARK: - Auto Apply Error
enum AutoApplyError: LocalizedError {
    case invalidURL
    case noURL
    case requestFailed
    case httpError(statusCode: Int, message: String)
    case parsingFailed
    case processingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noURL:
            return "Job post does not have a valid application URL"
        case .requestFailed:
            return "Request failed"
        case .httpError(let statusCode, let message):
            return "HTTP \(statusCode): \(message)"
        case .parsingFailed:
            return "Failed to parse response"
        case .processingFailed:
            return "Failed to process auto-application"
        }
    }
    
    var localizedDescription: String {
        return errorDescription ?? "Unknown error"
    }
}


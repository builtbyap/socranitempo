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
        
        // First, try to decode directly (works if all fields are present)
        let decoder = JSONDecoder()
        // Don't use convertFromSnakeCase since Application has explicit CodingKeys
        
        do {
        return try decoder.decode([Application].self, from: data)
        } catch let decodingError as DecodingError {
            // Log the decoding error for debugging
            print("❌ Failed to decode applications: \(decodingError)")
            print("📋 Attempting fallback decoding with missing field handling...")
            
            // Fallback: Decode manually to handle missing fields
            guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                print("❌ Response is not a JSON array")
                throw SupabaseError.httpError(statusCode: 500, message: "Failed to decode applications: Invalid JSON format")
            }
            
            var applications: [Application] = []
            for json in jsonArray {
                do {
                    let app = try decodeApplication(from: json)
                    applications.append(app)
                } catch {
                    print("⚠️ Failed to decode one application, skipping: \(error)")
                    // Continue with other applications
                }
            }
            
            print("✅ Successfully decoded \(applications.count) out of \(jsonArray.count) applications")
            return applications
        }
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
        // Don't use convertToSnakeCase since Application has explicit CodingKeys
        // But we need to manually handle pending_questions as JSONB
        var jsonDict: [String: Any] = [:]
        jsonDict["id"] = application.id
        jsonDict["job_post_id"] = application.jobPostId
        jsonDict["job_title"] = application.jobTitle
        jsonDict["company"] = application.company
        jsonDict["status"] = application.status
        jsonDict["applied_date"] = application.appliedDate
        jsonDict["resume_url"] = application.resumeUrl as Any
        jsonDict["job_url"] = application.jobUrl as Any
        
        // Encode pending_questions as JSONB (array of objects)
        if let questions = application.pendingQuestions, !questions.isEmpty {
            do {
                let questionsData = try JSONEncoder().encode(questions)
                if let questionsArray = try? JSONSerialization.jsonObject(with: questionsData) as? [[String: Any]] {
                    jsonDict["pending_questions"] = questionsArray
                    print("📋 Encoding \(questions.count) questions as JSONB array")
                } else {
                    print("⚠️ Failed to convert questions to array format")
                }
            } catch {
                print("⚠️ Failed to encode questions: \(error)")
            }
        } else {
            jsonDict["pending_questions"] = NSNull()
        }
        
        let applicationData = try JSONSerialization.data(withJSONObject: jsonDict)
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
    
    // MARK: - Helper: Decode Application with missing fields handling
    private func decodeApplication(from json: [String: Any]) throws -> Application {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Decode pending_questions if present (it's JSONB in database)
        var pendingQuestions: [PendingQuestion]? = nil
        
        // Handle different JSONB formats from Supabase
        if let pendingQuestionsValue = json["pending_questions"] {
            print("🔍 Found pending_questions value, type: \(type(of: pendingQuestionsValue))")
            
            // Case 1: Already an array of dictionaries (most common for JSONB)
            if let pendingQuestionsArray = pendingQuestionsValue as? [[String: Any]] {
                print("📋 Decoding as array of dictionaries (\(pendingQuestionsArray.count) items)")
                pendingQuestions = pendingQuestionsArray.compactMap { questionJson in
                    do {
                        // Ensure all required fields have defaults
                        var safeQuestionJson = questionJson
                        if safeQuestionJson["fieldType"] == nil {
                            safeQuestionJson["fieldType"] = "input"
                        }
                        if safeQuestionJson["inputType"] == nil {
                            safeQuestionJson["inputType"] = "text"
                        }
                        if safeQuestionJson["name"] == nil {
                            safeQuestionJson["name"] = ""
                        }
                        if safeQuestionJson["required"] == nil {
                            safeQuestionJson["required"] = false
                        }
                        if safeQuestionJson["selector"] == nil {
                            safeQuestionJson["selector"] = ""
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: safeQuestionJson)
                        let question = try JSONDecoder().decode(PendingQuestion.self, from: jsonData)
                        print("✅ Decoded question: \(question.question)")
                        return question
                    } catch {
                        print("⚠️ Failed to decode question: \(error)")
                        if let questionText = questionJson["question"] as? String {
                            print("   Question text was: \(questionText)")
                        }
                        print("   Available keys: \(questionJson.keys.joined(separator: ", "))")
                        return nil
                    }
                }
            }
            // Case 2: JSON string that needs parsing
            else if let pendingQuestionsString = pendingQuestionsValue as? String,
                    !pendingQuestionsString.isEmpty,
                    pendingQuestionsString != "null" {
                print("📋 Decoding as JSON string")
                if let pendingQuestionsData = pendingQuestionsString.data(using: .utf8) {
                    // Try to decode as array directly
                    if let questions = try? JSONDecoder().decode([PendingQuestion].self, from: pendingQuestionsData) {
                        pendingQuestions = questions
                        print("✅ Decoded \(questions.count) questions from JSON string")
                    }
                    // Try to parse as JSON first, then decode
                    else if let jsonObject = try? JSONSerialization.jsonObject(with: pendingQuestionsData),
                            let questionsArray = jsonObject as? [[String: Any]] {
                        print("📋 Parsed JSON string to array (\(questionsArray.count) items)")
                        pendingQuestions = questionsArray.compactMap { questionJson in
                            do {
                                // Ensure all required fields have defaults
                                var safeQuestionJson = questionJson
                                if safeQuestionJson["fieldType"] == nil {
                                    safeQuestionJson["fieldType"] = "input"
                                }
                                if safeQuestionJson["inputType"] == nil {
                                    safeQuestionJson["inputType"] = "text"
                                }
                                if safeQuestionJson["name"] == nil {
                                    safeQuestionJson["name"] = ""
                                }
                                if safeQuestionJson["required"] == nil {
                                    safeQuestionJson["required"] = false
                                }
                                if safeQuestionJson["selector"] == nil {
                                    safeQuestionJson["selector"] = ""
                                }
                                
                                let jsonData = try JSONSerialization.data(withJSONObject: safeQuestionJson)
                                return try JSONDecoder().decode(PendingQuestion.self, from: jsonData)
                            } catch {
                                print("⚠️ Failed to decode question: \(error)")
                                return nil
                            }
                        }
                    }
                }
            }
            // Case 3: NSNull or nil
            else if pendingQuestionsValue is NSNull {
                print("📋 pending_questions is NSNull")
                pendingQuestions = nil
            } else {
                print("⚠️ Unknown pending_questions format: \(type(of: pendingQuestionsValue))")
            }
        } else {
            print("📋 No pending_questions field found in JSON")
        }
        
        print("📋 Final decoded count: \(pendingQuestions?.count ?? 0) pending questions")
        
        return Application(
            id: json["id"] as? String ?? UUID().uuidString,
            jobPostId: json["job_post_id"] as? String ?? "",
            jobTitle: json["job_title"] as? String ?? "",
            company: json["company"] as? String ?? "",
            status: json["status"] as? String ?? "applied",
            appliedDate: json["applied_date"] as? String ?? dateFormatter.string(from: Date()),
            resumeUrl: json["resume_url"] as? String,
            jobUrl: json["job_url"] as? String,
            pendingQuestions: pendingQuestions
        )
    }
    
    // MARK: - Update Application Status
    func updateApplicationStatus(_ applicationId: String, status: String) async throws {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/applications?id=eq.\(applicationId)") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("public", forHTTPHeaderField: "Accept-Profile")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        
        let updateData: [String: Any] = ["status": status]
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: "Failed to update application: \(errorMessage)")
        }
    }
    
    // MARK: - Supabase Storage Upload
    func uploadResumeToStorage(fileURL: URL, fileName: String) async throws -> String {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        // Read file data
        let fileData = try Data(contentsOf: fileURL)
        
        // Create unique path for the file
        let userId = UUID().uuidString // In production, use actual user ID
        let filePath = "resumes/\(userId)/\(fileName)"
        
        // Upload to Supabase Storage
        guard let url = URL(string: "\(supabaseURL)/storage/v1/object/resumes/\(filePath)") else {
            throw SupabaseError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseKey)", forHTTPHeaderField: "Authorization")
        
        // Determine content type
        let contentType: String
        if fileName.hasSuffix(".pdf") {
            contentType = "application/pdf"
        } else if fileName.hasSuffix(".docx") || fileName.hasSuffix(".doc") {
            contentType = "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        } else {
            contentType = "application/octet-stream"
        }
        
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("upsert", forHTTPHeaderField: "x-upsert")
        request.httpBody = fileData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SupabaseError.requestFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SupabaseError.httpError(statusCode: httpResponse.statusCode, message: "Failed to upload resume: \(errorMessage)")
        }
        
        // Return public URL
        return "\(supabaseURL)/storage/v1/object/public/resumes/\(filePath)"
    }
    
    // MARK: - Resume Data
    // MARK: - Insert Application Email
    func insertApplicationEmail(_ email: ApplicationEmail) async throws {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/application_emails") else {
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
        
        let jsonDict: [String: Any] = [
            "id": email.id,
            "from_email": email.from,
            "subject": email.subject,
            "body": email.body,
            "received_date": email.date,
            "is_application_confirmation": email.isApplicationConfirmation
        ]
        
        let jsonData = try JSONSerialization.data(withJSONObject: jsonDict)
        request.httpBody = jsonData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw SupabaseError.requestFailed
        }
    }
    
    // MARK: - Fetch Application Emails
    func fetchApplicationEmails() async throws -> [ApplicationEmail] {
        guard supabaseURL != "YOUR_SUPABASE_URL" else {
            throw SupabaseError.notConfigured
        }
        
        guard let url = URL(string: "\(supabaseURL)/rest/v1/application_emails?select=*&order=received_date.desc") else {
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
        
        guard let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        
        return jsonArray.compactMap { json in
            guard let id = json["id"] as? String,
                  let from = json["from_email"] as? String,
                  let subject = json["subject"] as? String,
                  let body = json["body"] as? String,
                  let date = json["received_date"] as? String else {
                return nil
            }
            
            return ApplicationEmail(
                id: id,
                from: from,
                subject: subject,
                body: body,
                date: date,
                isApplicationConfirmation: json["is_application_confirmation"] as? Bool ?? false
            )
        }
    }
    
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


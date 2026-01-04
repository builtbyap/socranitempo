//
//  SimpleApplyService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Simple Apply Service
class SimpleApplyService {
    static let shared = SimpleApplyService()
    
    private init() {}
    
    // MARK: - Get User Profile Data
    func getUserProfileData() -> UserProfileData {
        // Load from UserDefaults (where ProfileView saves data)
        let firstName = UserDefaults.standard.string(forKey: "profile_firstName") ?? ""
        let middleName = UserDefaults.standard.string(forKey: "profile_middleName") ?? ""
        let lastName = UserDefaults.standard.string(forKey: "profile_lastName") ?? ""
        let preferredName = UserDefaults.standard.string(forKey: "profile_preferredName") ?? ""
        let title = UserDefaults.standard.string(forKey: "profile_title") ?? ""
        let location = UserDefaults.standard.string(forKey: "profile_location") ?? ""
        let personalEmail = UserDefaults.standard.string(forKey: "profile_personalEmail") ?? ""
        let phone = UserDefaults.standard.string(forKey: "profile_phone") ?? ""
        let linkedInURL = UserDefaults.standard.string(forKey: "profile_linkedInURL") ?? ""
        let githubURL = UserDefaults.standard.string(forKey: "profile_githubURL") ?? ""
        let portfolioURL = UserDefaults.standard.string(forKey: "profile_portfolioURL") ?? ""
        
        // Load parsed resume data
        var parsedResumeData: ResumeData? = nil
        if let data = UserDefaults.standard.data(forKey: "savedParsedResumeData") {
            parsedResumeData = try? JSONDecoder().decode(ResumeData.self, from: data)
        }
        
        // Get resume file URL if available
        var resumeURL: String? = nil
        if let savedFilePath = UserDefaults.standard.string(forKey: "savedResumeFilePath"),
           FileManager.default.fileExists(atPath: savedFilePath) {
            resumeURL = savedFilePath
        }
        
        return UserProfileData(
            firstName: firstName,
            middleName: middleName,
            lastName: lastName,
            preferredName: preferredName,
            title: title,
            location: location,
            email: personalEmail,
            phone: phone,
            linkedInURL: linkedInURL,
            githubURL: githubURL,
            portfolioURL: portfolioURL,
            parsedResumeData: parsedResumeData,
            resumeURL: resumeURL
        )
    }
    
    // MARK: - Generate Application Data
    func generateApplicationData(for job: JobPost, profileData: UserProfileData) -> ApplicationData {
        // Build full name
        var fullName = profileData.firstName
        if !profileData.middleName.isEmpty {
            fullName += " \(profileData.middleName)"
        }
        if !profileData.lastName.isEmpty {
            fullName += " \(profileData.lastName)"
        }
        if fullName.isEmpty {
            fullName = profileData.preferredName.isEmpty ? "Applicant" : profileData.preferredName
        }
        
        // Build cover letter from profile data
        let coverLetter = generateCoverLetter(for: job, profileData: profileData)
        
        // Use thesocrani@gmail.com for all applications (so user receives confirmation emails)
        let applicationEmail = "thesocrani@gmail.com"
        
        return ApplicationData(
            fullName: fullName,
            email: applicationEmail,
            phone: profileData.phone,
            location: profileData.location,
            linkedInURL: profileData.linkedInURL,
            githubURL: profileData.githubURL,
            portfolioURL: profileData.portfolioURL,
            resumeData: profileData.parsedResumeData,
            resumeURL: profileData.resumeURL,
            coverLetter: coverLetter
        )
    }
    
    // MARK: - Generate Cover Letter
    private func generateCoverLetter(for job: JobPost, profileData: UserProfileData) -> String {
        var coverLetter = "Dear Hiring Manager,\n\n"
        
        coverLetter += "I am writing to express my interest in the \(job.title) position at \(job.company).\n\n"
        
        // Add relevant experience
        if let resumeData = profileData.parsedResumeData {
            if let workExp = resumeData.workExperience, !workExp.isEmpty {
                coverLetter += "With my experience as \(workExp[0].title) at \(workExp[0].company), I believe I would be a strong fit for this role.\n\n"
            }
            
            // Add relevant skills
            if let skills = resumeData.skills, !skills.isEmpty {
                let relevantSkills = skills.filter { skill in
                    let jobText = "\(job.title) \(job.description ?? "")".lowercased()
                    return jobText.contains(skill.lowercased())
                }
                if !relevantSkills.isEmpty {
                    coverLetter += "My skills in \(relevantSkills.prefix(3).joined(separator: ", ")) align well with the requirements for this position.\n\n"
                }
            }
        }
        
        coverLetter += "I am excited about the opportunity to contribute to \(job.company) and would welcome the chance to discuss how my background and experience can benefit your team.\n\n"
        coverLetter += "Thank you for considering my application.\n\n"
        coverLetter += "Best regards,\n\(profileData.firstName.isEmpty ? "Applicant" : profileData.firstName)"
        
        return coverLetter
    }
    
    // MARK: - Create In Progress Application
    func createInProgressApplication(job: JobPost, applicationData: ApplicationData) async throws -> Application {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Create application with "in_progress" status
        let application = Application(
            id: UUID().uuidString,
            jobPostId: job.id,
            jobTitle: job.title,
            company: job.company,
            status: "in_progress",
            appliedDate: dateFormatter.string(from: Date()),
            resumeUrl: applicationData.resumeURL,
            jobUrl: job.url,
            pendingQuestions: nil
        )
        
        // Save to Supabase
        try await SupabaseService.shared.insertApplication(application)
        
        print("✅ In-progress application created: \(application.id)")
        
        // Notify that application was created
        NotificationCenter.default.post(name: NSNotification.Name("ApplicationStatusUpdated"), object: nil)
        
        return application
    }
    
    // MARK: - Submit Application
    func submitApplication(job: JobPost, applicationData: ApplicationData) async throws {
        try await submitApplicationWithQuestions(job: job, applicationData: applicationData, questions: nil)
    }
    
    // MARK: - Update Application Status
    func updateApplicationStatus(applicationId: String, status: String) async throws {
        try await SupabaseService.shared.updateApplicationStatus(applicationId: applicationId, status: status)
        NotificationCenter.default.post(name: NSNotification.Name("ApplicationStatusUpdated"), object: nil)
    }
    
    // MARK: - Submit Application with Questions
    func submitApplicationWithQuestions(
        job: JobPost,
        applicationData: ApplicationData,
        questions: [PendingQuestion]?
    ) async throws {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Upload resume to Supabase Storage if available
        var resumePublicURL: String? = applicationData.resumeURL
        
        if let localResumePath = applicationData.resumeURL,
           FileManager.default.fileExists(atPath: localResumePath) {
            let fileURL: URL
            if let url = URL(string: localResumePath), url.scheme != nil {
                fileURL = url
            } else {
                fileURL = URL(fileURLWithPath: localResumePath)
            }
            do {
                let fileName = fileURL.lastPathComponent
                resumePublicURL = try await SupabaseService.shared.uploadResumeToStorage(
                    fileURL: fileURL,
                    fileName: fileName
                )
                print("✅ Resume uploaded to Supabase Storage: \(resumePublicURL ?? "unknown")")
            } catch {
                print("⚠️ Failed to upload resume to storage: \(error.localizedDescription)")
                // Continue with application even if upload fails
            }
        }
        
        // Determine status based on questions
        let status = (questions != nil && !questions!.isEmpty) ? "pending_questions" : "applied"
        
        print("💾 Saving application with status: \(status)")
        if let questions = questions, !questions.isEmpty {
            print("📋 Saving \(questions.count) questions:")
            for (index, question) in questions.enumerated() {
                print("   \(index + 1). \(question.question) (required: \(question.required))")
            }
        } else {
            print("📋 No questions to save")
        }
        
        // Create application record
        let application = Application(
            id: UUID().uuidString,
            jobPostId: job.id,
            jobTitle: job.title,
            company: job.company,
            status: status,
            appliedDate: dateFormatter.string(from: Date()),
            resumeUrl: resumePublicURL,
            jobUrl: job.url,
            pendingQuestions: questions
        )
        
        print("💾 Application created with pendingQuestions count: \(application.pendingQuestions?.count ?? 0)")
        
        // Save to Supabase
        try await SupabaseService.shared.insertApplication(application)
        
        print("✅ Application saved successfully")
        
        // Send email notification
        Task.detached {
            do {
                try await self.sendApplicationEmailNotification(
                    job: job,
                    applicationData: applicationData,
                    applicationId: application.id
                )
            } catch {
                print("⚠️ Failed to send email notification: \(error.localizedDescription)")
                // Don't fail the application if email fails
            }
        }
    }
    
    // MARK: - Send Email Notification
    private func sendApplicationEmailNotification(
        job: JobPost,
        applicationData: ApplicationData,
        applicationId: String
    ) async throws {
        guard let edgeFunctionURL = URL(string: "\(Config.supabaseURL)/functions/v1/send-application-email") else {
            throw NSError(domain: "SimpleApplyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
        }
        
        var request = URLRequest(url: edgeFunctionURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        
        let emailData: [String: Any] = [
            "to": applicationData.email,
            "jobTitle": job.title,
            "company": job.company,
            "applicantName": applicationData.fullName,
            "applicationId": applicationId
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: emailData)
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw NSError(domain: "SimpleApplyService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Email notification failed"])
        }
    }
}

// MARK: - User Profile Data Model
struct UserProfileData {
    let firstName: String
    let middleName: String
    let lastName: String
    let preferredName: String
    let title: String
    let location: String
    let email: String
    let phone: String
    let linkedInURL: String
    let githubURL: String
    let portfolioURL: String
    let parsedResumeData: ResumeData?
    let resumeURL: String?
}

// MARK: - Application Data Model
struct ApplicationData {
    let fullName: String
    let email: String
    let phone: String
    let location: String
    let linkedInURL: String
    let githubURL: String
    let portfolioURL: String
    let resumeData: ResumeData?
    let resumeURL: String?
    let coverLetter: String
}


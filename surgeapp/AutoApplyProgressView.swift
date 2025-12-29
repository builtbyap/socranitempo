//
//  AutoApplyProgressView.swift
//  surgeapp
//
//  Progress view for fully automated job applications (like sorce.jobs)
//

import SwiftUI

struct AutoApplyProgressView: View {
    let job: JobPost
    @Environment(\.dismiss) var dismiss
    @State private var currentStep: AutoApplyStep = .starting
    @State private var progressMessage: String = "Starting application..."
    @State private var showSuccess = false
    @State private var showError = false
    @State private var errorMessage: String?
    @State private var filledFields: Int = 0
    @State private var atsSystem: String = ""
    @State private var pendingQuestions: [PendingQuestion]? = nil
    @State private var showingQuestions = false
    @State private var applicationId: String? = nil
    
    enum AutoApplyStep {
        case starting
        case processing
        case completed
        case error
        case pendingQuestions
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                if currentStep == .completed {
                    // Success View
                    VStack(spacing: 24) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Application Submitted!")
                            .font(.system(size: 28, weight: .bold))
                        
                        VStack(spacing: 8) {
                            Text("Successfully applied to")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            Text(job.title)
                                .font(.system(size: 20, weight: .semibold))
                            
                            Text(job.company)
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        
                        if filledFields > 0 {
                            Text("Filled \(filledFields) fields")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        if !atsSystem.isEmpty && atsSystem != "unknown" {
                            Text("ATS: \(atsSystem.capitalized)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } else if currentStep == .error {
                    // Error View
                    VStack(spacing: 24) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.red)
                        
                        Text("Application Failed")
                            .font(.system(size: 28, weight: .bold))
                        
                        if let error = errorMessage {
                            Text(error)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                } else {
                    // Progress View
                    VStack(spacing: 24) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(progressMessage)
                            .font(.system(size: 18, weight: .medium))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            Text(job.title)
                                .font(.system(size: 20, weight: .semibold))
                            
                            Text(job.company)
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Applying...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if currentStep == .completed || currentStep == .error {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .onAppear {
                if currentStep != .pendingQuestions {
                    startAutoApply()
                }
            }
            .sheet(isPresented: $showingQuestions) {
                if let questions = pendingQuestions {
                    // Show questions inline (like sorce.jobs)
                    // We'll fetch the actual application from the database when submitting answers
                    QuestionAnswerView(
                        application: Application(
                            id: applicationId ?? UUID().uuidString,
                            jobPostId: job.id,
                            jobTitle: job.title,
                            company: job.company,
                            status: "pending_questions",
                            appliedDate: DateFormatter().string(from: Date()),
                            resumeUrl: nil,
                            jobUrl: job.url,
                            pendingQuestions: questions
                        ),
                        questions: questions
                    )
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ApplicationStatusUpdated"))) { _ in
                // After questions are answered, resume automation
                if currentStep == .pendingQuestions {
                    resumeApplicationAfterAnswers()
                }
            }
        }
    }
    
    private func resumeApplicationAfterAnswers() {
        Task {
            do {
                guard let appId = applicationId else { return }
                
                // Fetch the application to get updated status
                let applications = try await SupabaseService.shared.fetchApplications()
                guard let application = applications.first(where: { $0.id == appId }) else {
                    return
                }
                
                // If status changed to "applied", show success
                if application.status == "applied" {
                    await MainActor.run {
                        currentStep = .completed
                        showingQuestions = false
                    }
                }
            } catch {
                print("⚠️ Failed to check application status: \(error)")
            }
        }
    }
    
    private func startAutoApply() {
        Task {
            do {
                // Get application data
                let profileData = SimpleApplyService.shared.getUserProfileData()
                let applicationData = SimpleApplyService.shared.generateApplicationData(
                    for: job,
                    profileData: profileData
                )
                
                // Generate AI cover letter
                await MainActor.run {
                    progressMessage = "Generating personalized cover letter..."
                }
                
                var coverLetter = applicationData.coverLetter
                do {
                    let aiCoverLetter = try await AICoverLetterService.shared.generateCoverLetter(
                        for: job,
                        userProfile: profileData,
                        resumeData: applicationData.resumeData
                    )
                    coverLetter = aiCoverLetter
                } catch {
                    print("⚠️ AI cover letter generation failed, using template: \(error.localizedDescription)")
                }
                
                // Create updated application data with AI cover letter
                let updatedAppData = ApplicationData(
                    fullName: applicationData.fullName,
                    email: applicationData.email,
                    phone: applicationData.phone,
                    location: applicationData.location,
                    linkedInURL: applicationData.linkedInURL,
                    githubURL: applicationData.githubURL,
                    portfolioURL: applicationData.portfolioURL,
                    resumeData: applicationData.resumeData,
                    resumeURL: applicationData.resumeURL,
                    coverLetter: coverLetter
                )
                
                // Start automation
                await MainActor.run {
                    currentStep = .processing
                    progressMessage = "Automating application with Playwright..."
                }
                
                // Call Playwright service
                let result = try await AutoApplyService.shared.autoApply(
                    job: job,
                    applicationData: updatedAppData
                )
                
                if result.success {
                    // Save application to Supabase
                    await MainActor.run {
                        progressMessage = "Saving application..."
                    }
                    
                    try await SimpleApplyService.shared.submitApplication(
                        job: job,
                        applicationData: updatedAppData
                    )
                    
                    await MainActor.run {
                        filledFields = result.filledFields
                        atsSystem = result.atsSystem
                        currentStep = .completed
                    }
                } else if result.needsUserInput == true, let questions = result.questions, !questions.isEmpty {
                    // Questions detected - save as pending and show inline (like sorce.jobs)
                    await MainActor.run {
                        progressMessage = "Saving application with pending questions..."
                    }
                    
                    // Save application with pending questions status
                    try await SimpleApplyService.shared.submitApplicationWithQuestions(
                        job: job,
                        applicationData: updatedAppData,
                        questions: questions
                    )
                    
                    // Fetch the application we just created to get its ID
                    let applications = try await SupabaseService.shared.fetchApplications()
                    let savedApp = applications.first { app in
                        app.jobPostId == job.id && app.status == "pending_questions"
                    }
                    
                    // Show questions inline immediately (like sorce.jobs)
                    await MainActor.run {
                        pendingQuestions = questions
                        applicationId = savedApp?.id
                        currentStep = .pendingQuestions
                        showingQuestions = true
                    }
                } else {
                    await MainActor.run {
                        errorMessage = result.error ?? "Application failed"
                        currentStep = .error
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    currentStep = .error
                }
            }
        }
    }
}


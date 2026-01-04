//
//  AutoApplyProgressView.swift
//  surgeapp
//
//  Progress view for fully automated job applications (like sorce.jobs)
//

import SwiftUI
import UIKit

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
    @State private var submitted: Bool = false
    @State private var screenshot: String? = nil
    @State private var showingScreenshot = false
    @ObservedObject private var streamService = SSEStreamService.shared
    
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
                    ScrollView {
                        VStack(spacing: 24) {
                            Image(systemName: submitted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(submitted ? .green : .orange)
                            
                            Text(submitted ? "Application Submitted!" : "Application Filled")
                                .font(.system(size: 28, weight: .bold))
                            
                            VStack(spacing: 8) {
                                Text(submitted ? "Successfully applied to" : "Form filled for")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                
                                Text(job.title)
                                    .font(.system(size: 20, weight: .semibold))
                                
                                Text(job.company)
                                    .font(.system(size: 18))
                                    .foregroundColor(.secondary)
                            }
                            
                            // Status Details
                            VStack(spacing: 12) {
                                if filledFields > 0 {
                                    HStack {
                                        Image(systemName: "checkmark.circle")
                                            .foregroundColor(.green)
                                        Text("Filled \(filledFields) fields")
                                            .font(.system(size: 14))
                                    }
                                }
                                
                                if !atsSystem.isEmpty && atsSystem != "unknown" {
                                    HStack {
                                        Image(systemName: "building.2")
                                            .foregroundColor(.blue)
                                        Text("ATS: \(atsSystem.capitalized)")
                                            .font(.system(size: 14))
                                    }
                                }
                                
                                HStack {
                                    Image(systemName: submitted ? "paperplane.fill" : "exclamationmark.circle")
                                        .foregroundColor(submitted ? .green : .orange)
                                    Text(submitted ? "Form submitted successfully" : "Form filled but not submitted automatically")
                                        .font(.system(size: 14))
                                        .foregroundColor(submitted ? .green : .orange)
                                }
                                
                                if !submitted {
                                    Text("You may need to manually submit the application on the company's website.")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // Screenshot Preview
                            if let screenshot = screenshot {
                                VStack(spacing: 8) {
                                    Text("Verification Screenshot")
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    Button(action: {
                                        showingScreenshot = true
                                    }) {
                                        if let imageData = Data(base64Encoded: screenshot),
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(maxHeight: 200)
                                                .cornerRadius(8)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.blue, lineWidth: 2)
                                                )
                                        } else {
                                            Text("View Screenshot")
                                                .font(.system(size: 14))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    Text("Tap to view full screenshot")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                        }
                        .padding()
                    }
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
                } else if currentStep == .processing {
                    // Live Stream View (like sorce.jobs)
                    ScrollView {
                        VStack(spacing: 24) {
                            // Live stream display
                            if let liveFrame = streamService.currentFrame {
                                VStack(spacing: 12) {
                                    Text("Live Application Process")
                                        .font(.system(size: 20, weight: .semibold))
                                    
                                    Image(uiImage: liveFrame)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: .infinity, maxHeight: 500)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, lineWidth: 2)
                                        )
                                    
                                    if let step = streamService.currentStep {
                                        Text(step)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Connection status
                                    HStack {
                                        Circle()
                                            .fill(streamService.isConnected ? Color.green : Color.red)
                                            .frame(width: 8, height: 8)
                                        Text(streamService.isConnected ? "Live" : "Connecting...")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                            } else {
                                // Loading state - show progress even if stream fails
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                    
                                    Text(streamService.currentStep ?? progressMessage)
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                    
                                    if let error = streamService.error {
                                        VStack(spacing: 8) {
                                            Text("Stream unavailable")
                                                .font(.system(size: 14))
                                                .foregroundColor(.orange)
                                            Text("Application is still processing...")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding()
                            }
                            
                            // Progress message
                            Text(progressMessage)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding()
                    }
                } else {
                    // Starting/Other states
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
            .sheet(isPresented: $showingScreenshot) {
                if let screenshot = screenshot,
                   let imageData = Data(base64Encoded: screenshot),
                   let uiImage = UIImage(data: imageData) {
                    NavigationStack {
                        ScrollView {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                        }
                        .navigationTitle("Application Screenshot")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Done") {
                                    showingScreenshot = false
                                }
                            }
                        }
                    }
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
                        submitted = result.submitted ?? false
                        screenshot = result.screenshot
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
                    // Check if bot detection was encountered
                    if result.botDetected == true {
                        await MainActor.run {
                            errorMessage = result.error ?? "Bot detection encountered. Please apply manually."
                            screenshot = result.screenshot
                            currentStep = .error
                        }
                    } else {
                        await MainActor.run {
                            errorMessage = result.error ?? "Application failed"
                            screenshot = result.screenshot
                            currentStep = .error
                        }
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


//
//  AutoApplyQueueService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Auto Apply Queue Service
class AutoApplyQueueService {
    static let shared = AutoApplyQueueService()
    
    private var applicationQueue: [QueuedApplication] = []
    private var isProcessing = false
    private var processedJobIds: Set<String> = []
    
    private init() {
        loadProcessedJobs()
    }
    
    // MARK: - Queue Jobs for Auto-Apply
    func queueJobsForAutoApply(_ jobs: [JobPost]) {
        // Check if auto-apply is enabled
        let autoApplyEnabled = UserDefaults.standard.bool(forKey: "autoApplyEnabled")
        guard autoApplyEnabled else {
            print("ℹ️ Auto-apply is disabled")
            return
        }
        
        let profileData = SimpleApplyService.shared.getUserProfileData()
        
        // Filter jobs that:
        // 1. Have a valid URL
        // 2. Haven't been processed yet
        // 3. Are from company career pages (not job boards)
        let eligibleJobs = jobs.filter { job in
            guard let url = job.url, !url.isEmpty else { return false }
            guard !processedJobIds.contains(job.id) else { return false }
            
            // Prefer company career pages over job boards
            // Job boards: indeed.com, monster.com, glassdoor.com, ziprecruiter.com
            let urlLower = url.lowercased()
            let isJobBoard = urlLower.contains("indeed.com") ||
                           urlLower.contains("monster.com") ||
                           urlLower.contains("glassdoor.com") ||
                           urlLower.contains("ziprecruiter.com") ||
                           urlLower.contains("linkedin.com")
            
            // Only auto-apply to company career pages (not job boards)
            return !isJobBoard
        }
        
        // Create queued applications
        for job in eligibleJobs {
            let applicationData = SimpleApplyService.shared.generateApplicationData(for: job, profileData: profileData)
            let queuedApp = QueuedApplication(job: job, applicationData: applicationData)
            applicationQueue.append(queuedApp)
        }
        
        print("📋 Queued \(applicationQueue.count) jobs for auto-apply")
        
        // Start processing if not already processing
        if !isProcessing && !applicationQueue.isEmpty {
            Task {
                await processQueue()
            }
        }
    }
    
    // MARK: - Process Queue
    private func processQueue() async {
        guard !isProcessing else { return }
        isProcessing = true
        
        print("🚀 Starting auto-apply queue processing...")
        
        while !applicationQueue.isEmpty {
            let queuedApp = applicationQueue.removeFirst()
            
            // Skip if already processed
            if processedJobIds.contains(queuedApp.job.id) {
                continue
            }
            
            print("📝 Processing auto-apply for: \(queuedApp.job.title) at \(queuedApp.job.company)")
            
            // Process application
            do {
                try await processApplication(queuedApp)
                
                // Mark as processed
                processedJobIds.insert(queuedApp.job.id)
                saveProcessedJobs()
                
                print("✅ Successfully auto-applied to: \(queuedApp.job.title)")
                
                // Delay between applications to avoid rate limiting
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                
            } catch {
                print("❌ Failed to auto-apply to \(queuedApp.job.title): \(error.localizedDescription)")
                
                // Mark as failed but don't retry immediately
                processedJobIds.insert(queuedApp.job.id)
                saveProcessedJobs()
            }
        }
        
        isProcessing = false
        print("✅ Auto-apply queue processing completed")
    }
    
    // MARK: - Process Individual Application
    private func processApplication(_ queuedApp: QueuedApplication) async throws {
        guard let jobURL = queuedApp.job.url, !jobURL.isEmpty else {
            throw AutoApplyError.noURL
        }
        
        // Use WebAutomationService to detect ATS and fill forms
        let detectedATS = WebAutomationService.shared.detectATSSystem(url: jobURL)
        print("🔍 Detected ATS: \(detectedATS?.rawValue ?? "Unknown")")
        
        // Generate AI cover letter
        var coverLetter = queuedApp.applicationData.coverLetter
        do {
            let profileData = SimpleApplyService.shared.getUserProfileData()
            let generatedLetter = try await AICoverLetterService.shared.generateCoverLetter(
                for: queuedApp.job,
                userProfile: profileData,
                resumeData: queuedApp.applicationData.resumeData
            )
            coverLetter = generatedLetter
        } catch {
            print("⚠️ AI cover letter generation failed, using fallback: \(error.localizedDescription)")
        }
        
        // Submit the application data to Supabase
        // The actual web automation happens in AutoApplyView when user opens it
        // For now, we'll save the application and mark it for auto-apply
        
        try await SimpleApplyService.shared.submitApplication(
            job: queuedApp.job,
            applicationData: queuedApp.applicationData
        )
        
        // Update application status to "Auto-Applied"
        do {
            try await SupabaseService.shared.updateApplicationStatus(
                queuedApp.job.id,
                status: "Auto-Applied"
            )
        } catch {
            print("⚠️ Failed to update application status: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Processed Jobs Tracking
    private func loadProcessedJobs() {
        if let data = UserDefaults.standard.data(forKey: "autoApplyProcessedJobs"),
           let ids = try? JSONDecoder().decode(Set<String>.self, from: data) {
            processedJobIds = ids
        }
    }
    
    private func saveProcessedJobs() {
        if let data = try? JSONEncoder().encode(processedJobIds) {
            UserDefaults.standard.set(data, forKey: "autoApplyProcessedJobs")
        }
    }
    
    // MARK: - Clear Processed Jobs (for testing)
    func clearProcessedJobs() {
        processedJobIds.removeAll()
        UserDefaults.standard.removeObject(forKey: "autoApplyProcessedJobs")
    }
    
    // MARK: - Get Queue Status
    func getQueueStatus() -> (queued: Int, processed: Int) {
        return (queued: applicationQueue.count, processed: processedJobIds.count)
    }
    
    // MARK: - Check if Job is Processed
    func isJobProcessed(_ jobId: String) -> Bool {
        return processedJobIds.contains(jobId)
    }
}

// MARK: - Queued Application Model
struct QueuedApplication {
    let job: JobPost
    let applicationData: ApplicationData
}

// MARK: - Auto Apply Error
// Note: AutoApplyError is defined in AutoApplyService.swift to avoid duplication

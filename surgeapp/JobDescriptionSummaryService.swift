//
//  JobDescriptionSummaryService.swift
//  surgeapp
//
//  Service to bulk summarize job descriptions before display
//

import Foundation

class JobDescriptionSummaryService {
    static let shared = JobDescriptionSummaryService()
    
    // Cache of summaries by job ID
    private var summaryCache: [String: JobDescriptionSummary] = [:]
    
    private init() {}
    
    // MARK: - Bulk Summarize Job Descriptions
    func summarizeJobDescriptions(for jobs: [JobPost]) async {
        // Filter jobs that need summarization
        let jobsToSummarize = jobs.filter { job in
            // Only summarize if we have a description and don't already have a summary
            if let description = job.description, !description.isEmpty {
                return summaryCache[job.id] == nil
            }
            return false
        }
        
        print("📝 Summarizing \(jobsToSummarize.count) job descriptions...")
        
        // Summarize in batches to avoid overwhelming the API
        let batchSize = 5 // Process 5 at a time
        for i in stride(from: 0, to: jobsToSummarize.count, by: batchSize) {
            let endIndex = min(i + batchSize, jobsToSummarize.count)
            let batch = Array(jobsToSummarize[i..<endIndex])
            
            // Process batch in parallel
            await withTaskGroup(of: (String, JobDescriptionSummary?).self) { group in
                for job in batch {
                    group.addTask {
                        if let description = job.description, !description.isEmpty {
                            do {
                                let summary = try await OpenAIService.shared.summarizeJobDescription(description)
                                return (job.id, summary)
                            } catch {
                                print("⚠️ Failed to summarize job \(job.id): \(error.localizedDescription)")
                                return (job.id, nil)
                            }
                        }
                        return (job.id, nil)
                    }
                }
                
                // Collect results
                for await (jobId, summary) in group {
                    if let summary = summary {
                        await MainActor.run {
                            self.summaryCache[jobId] = summary
                        }
                    }
                }
            }
            
            // Small delay between batches to avoid rate limiting
            if endIndex < jobsToSummarize.count {
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            }
        }
        
        print("✅ Completed summarizing job descriptions")
    }
    
    // MARK: - Get Summary for Job
    func getSummary(for jobId: String) -> JobDescriptionSummary? {
        return summaryCache[jobId]
    }
    
    // MARK: - Clear Cache
    func clearCache() {
        summaryCache.removeAll()
    }
    
    // MARK: - Preload Summaries (for specific jobs)
    func preloadSummaries(for jobIds: [String], from jobs: [JobPost]) async {
        let jobsToLoad = jobs.filter { jobIds.contains($0.id) }
        await summarizeJobDescriptions(for: jobsToLoad)
    }
}


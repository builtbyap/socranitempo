//
//  JobSearchFormView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct JobSearchFormView: View {
    @Environment(\.dismiss) var dismiss
    @State private var position: String = ""
    @State private var minimumSalary: String = ""
    @State private var maximumSalary: String = ""
    @State private var location: String = ""
    @State private var jobType: String = "" // "F" for Full-time, "P" for Part-time
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Job Search Parameters")) {
                    TextField("Position", text: $position)
                        .textContentType(.jobTitle)
                    
                    TextField("Minimum Salary (Ex: 50,000)", text: $minimumSalary)
                        .keyboardType(.numberPad)
                    
                    TextField("Maximum Salary (Ex: 100,000)", text: $maximumSalary)
                        .keyboardType(.numberPad)
                    
                    TextField("Location (Ex: New York, NY)", text: $location)
                        .textContentType(.addressCity)
                    
                    TextField("Full-time Or Part-time (Enter F or P)", text: $jobType)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: jobType) { oldValue, newValue in
                            // Only allow F or P
                            if !newValue.isEmpty && newValue.uppercased() != "F" && newValue.uppercased() != "P" {
                                jobType = String(newValue.prefix(1).uppercased())
                            } else {
                                jobType = newValue.uppercased()
                            }
                        }
                }
                
                Section(header: Text("Instructions")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fill out the parameters above to search for LinkedIn job posts.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("• Position: The job title you're looking for")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Salary: Enter numbers only (e.g., 50000)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Job Type: Enter 'F' for Full-time or 'P' for Part-time")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("• Location: City and state (e.g., New York, NY)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Job Search")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Search") {
                        Task {
                            await submitSearch()
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(isSubmitting || !isFormValid)
                }
            }
            .overlay {
                if isSubmitting {
                    ZStack {
                        Color.black.opacity(0.3)
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Searching for jobs...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Job search completed! Results have been saved to the database.")
            }
        }
    }
    
    private var isFormValid: Bool {
        !position.isEmpty && !location.isEmpty && (jobType == "F" || jobType == "P")
    }
    
    private func submitSearch() async {
        guard isFormValid else {
            errorMessage = "Please fill in all required fields"
            return
        }
        
        isSubmitting = true
        errorMessage = nil
        
        do {
            // Step 1: Run the Apify scraper
            print("🔍 Starting Apify scraper...")
            let results = try await ApifyService.shared.scrapeLinkedInJobs(
                jobTitle: position,
                location: location,
                jobType: jobType,
                jobsEntries: 100
            )
            
            print("✅ Apify returned \(results.count) results")
            
            guard !results.isEmpty else {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "No job posts found. Please try different search parameters."
                }
                return
            }
            
            // Step 2: Convert Apify results to JobPost format and save to Supabase
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            let jobPosts = results.enumerated().map { index, result in
                JobPost(
                    id: UUID().uuidString,
                    title: result.jobTitle ?? "Unknown",
                    company: result.company ?? "Unknown Company",
                    location: result.location ?? location,
                    postedDate: dateFormatter.string(from: Date()),
                    description: result.jobDescription,
                    url: result.applyUrl,
                    salary: formatSalary(result.salaryRange, min: minimumSalary, max: maximumSalary),
                    jobType: result.employmentType ?? (jobType == "F" ? "Full-time" : "Part-time"),
                    sections: nil
                )
            }
            
            print("💾 Saving \(jobPosts.count) job posts to Supabase...")
            
            // Step 3: Save to Supabase
            try await SupabaseService.shared.insertJobPosts(jobPosts)
            
            print("✅ Successfully saved to Supabase")
            
            await MainActor.run {
                isSubmitting = false
                showSuccess = true
            }
        } catch {
            print("❌ Error: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            await MainActor.run {
                isSubmitting = false
                errorMessage = "Error: \(error.localizedDescription)\n\nCheck console for details."
            }
        }
    }
    
    private func formatSalary(_ salaryRange: String?, min: String, max: String) -> String? {
        if let range = salaryRange, !range.isEmpty {
            return range
        }
        if !min.isEmpty || !max.isEmpty {
            if !min.isEmpty && !max.isEmpty {
                return "$\(min) - $\(max)"
            } else if !min.isEmpty {
                return "$\(min)+"
            } else {
                return "Up to $\(max)"
            }
        }
        return nil
    }
}

#Preview {
    JobSearchFormView()
}


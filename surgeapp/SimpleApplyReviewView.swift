//
//  SimpleApplyReviewView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct SimpleApplyReviewView: View {
    let job: JobPost
    let applicationData: ApplicationData
    @Environment(\.dismiss) var dismiss
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showingFormHelper = false
    @State private var showingAutoApply = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Job Information
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Applying to")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        Text(job.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(job.company)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        if let location = job.location, !location.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                Text(location)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Personal Information
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Your Information")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        InfoRow(label: "Full Name", value: applicationData.fullName)
                        InfoRow(label: "Email", value: applicationData.email)
                        InfoRow(label: "Phone", value: applicationData.phone)
                        if !applicationData.location.isEmpty {
                            InfoRow(label: "Location", value: applicationData.location)
                        }
                        if !applicationData.linkedInURL.isEmpty {
                            InfoRow(label: "LinkedIn", value: applicationData.linkedInURL)
                        }
                        if !applicationData.githubURL.isEmpty {
                            InfoRow(label: "GitHub", value: applicationData.githubURL)
                        }
                        if !applicationData.portfolioURL.isEmpty {
                            InfoRow(label: "Portfolio", value: applicationData.portfolioURL)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    
                    // Resume Summary
                    if let resumeData = applicationData.resumeData {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Resume Summary")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if let workExp = resumeData.workExperience, !workExp.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Experience")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    ForEach(workExp.prefix(3), id: \.title) { exp in
                                        Text("• \(exp.title) at \(exp.company)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            
                            if let education = resumeData.education, !education.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Education")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    ForEach(education.prefix(2), id: \.degree) { edu in
                                        Text("• \(edu.degree) from \(edu.school)")
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            
                            if let skills = resumeData.skills, !skills.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Skills")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                    Text(skills.prefix(10).joined(separator: ", "))
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                    }
                    
                    // Cover Letter Preview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cover Letter")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(applicationData.coverLetter)
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                            .lineSpacing(4)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.separator), lineWidth: 1)
                    )
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Review Application")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button(action: {
                            // Start AI auto-apply
                            showingAutoApply = true
                        }) {
                            Label("AI Auto-Apply", systemImage: "wand.and.stars")
                        }
                        
                        Button(action: {
                            // Show form auto-fill helper
                            showingFormHelper = true
                        }) {
                            Label("Auto-Fill Helper", systemImage: "doc.text.fill")
                        }
                        
                        Button(action: submitApplication) {
                            Label("Submit Application", systemImage: "paperplane.fill")
                        }
                    } label: {
                        if isSubmitting {
                            ProgressView()
                        } else {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                    .disabled(isSubmitting || showSuccess)
                }
            }
            .sheet(isPresented: $showingFormHelper) {
                FormAutoFillView(applicationData: applicationData)
            }
            .fullScreenCover(isPresented: $showingAutoApply) {
                if let jobURL = job.url, !jobURL.isEmpty {
                    AutoApplyView(job: job, applicationData: applicationData)
                } else {
                    VStack {
                        Text("No application URL available")
                            .font(.headline)
                        Button("Close") {
                            showingAutoApply = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .alert("Application Submitted!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your application has been saved. You may need to complete the application on the company's website.")
            }
        }
    }
    
    private func submitApplication() {
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                try await SimpleApplyService.shared.submitApplication(job: job, applicationData: applicationData)
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit application: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label + ":")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value.isEmpty ? "Not provided" : value)
                .font(.system(size: 14))
                .foregroundColor(value.isEmpty ? .secondary : .primary)
            
            Spacer()
        }
    }
}


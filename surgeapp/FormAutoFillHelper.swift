//
//  FormAutoFillHelper.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Form Auto-Fill Helper
// This helper prepares application data in formats that can be easily copied/pasted
// or used with browser extensions for auto-filling forms
class FormAutoFillHelper {
    static let shared = FormAutoFillHelper()
    
    private init() {}
    
    // MARK: - Generate Form Data JSON
    func generateFormDataJSON(applicationData: ApplicationData) -> String {
        let formData: [String: Any] = [
            "fullName": applicationData.fullName,
            "email": applicationData.email,
            "phone": applicationData.phone,
            "location": applicationData.location,
            "linkedIn": applicationData.linkedInURL,
            "github": applicationData.githubURL,
            "portfolio": applicationData.portfolioURL,
            "coverLetter": applicationData.coverLetter,
            "workExperience": generateWorkExperienceJSON(resumeData: applicationData.resumeData),
            "education": generateEducationJSON(resumeData: applicationData.resumeData),
            "skills": generateSkillsJSON(resumeData: applicationData.resumeData)
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: formData, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{}"
    }
    
    // MARK: - Generate Plain Text Summary
    func generatePlainTextSummary(applicationData: ApplicationData) -> String {
        var text = "APPLICATION INFORMATION\n"
        text += "======================\n\n"
        text += "Full Name: \(applicationData.fullName)\n"
        text += "Email: \(applicationData.email)\n"
        text += "Phone: \(applicationData.phone)\n"
        text += "Location: \(applicationData.location)\n\n"
        
        if !applicationData.linkedInURL.isEmpty {
            text += "LinkedIn: \(applicationData.linkedInURL)\n"
        }
        if !applicationData.githubURL.isEmpty {
            text += "GitHub: \(applicationData.githubURL)\n"
        }
        if !applicationData.portfolioURL.isEmpty {
            text += "Portfolio: \(applicationData.portfolioURL)\n"
        }
        
        text += "\n---\n\n"
        text += "COVER LETTER\n"
        text += "============\n\n"
        text += applicationData.coverLetter
        
        if let resumeData = applicationData.resumeData {
            text += "\n\n---\n\n"
            text += "WORK EXPERIENCE\n"
            text += "==============\n\n"
            if let workExp = resumeData.workExperience {
                for exp in workExp {
                    text += "\(exp.title) at \(exp.company)\n"
                    if let description = exp.description {
                        text += "\(description)\n"
                    }
                    text += "\n"
                }
            }
            
            text += "\nEDUCATION\n"
            text += "=========\n\n"
            if let education = resumeData.education {
                for edu in education {
                    text += "\(edu.degree) from \(edu.school)\n"
                    if let year = edu.year {
                        text += "Year: \(year)\n"
                    }
                    text += "\n"
                }
            }
            
            text += "\nSKILLS\n"
            text += "======\n\n"
            if let skills = resumeData.skills {
                text += skills.joined(separator: ", ")
            }
        }
        
        return text
    }
    
    // MARK: - Generate Browser Extension Format
    func generateBrowserExtensionFormat(applicationData: ApplicationData) -> [String: String] {
        var data: [String: String] = [:]
        
        // Common form field names
        data["name"] = applicationData.fullName
        data["full_name"] = applicationData.fullName
        data["first_name"] = applicationData.fullName.components(separatedBy: " ").first ?? ""
        data["last_name"] = applicationData.fullName.components(separatedBy: " ").last ?? ""
        data["email"] = applicationData.email
        data["phone"] = applicationData.phone
        data["phone_number"] = applicationData.phone
        data["location"] = applicationData.location
        data["city"] = applicationData.location
        data["linkedin"] = applicationData.linkedInURL
        data["linkedin_url"] = applicationData.linkedInURL
        data["github"] = applicationData.githubURL
        data["github_url"] = applicationData.githubURL
        data["portfolio"] = applicationData.portfolioURL
        data["portfolio_url"] = applicationData.portfolioURL
        data["cover_letter"] = applicationData.coverLetter
        data["resume_url"] = applicationData.resumeURL ?? ""
        
        return data
    }
    
    // MARK: - Helper Methods
    private func generateWorkExperienceJSON(resumeData: ResumeData?) -> [[String: Any]] {
        guard let resumeData = resumeData,
              let workExp = resumeData.workExperience else {
            return []
        }
        
        return workExp.map { exp in
            var dict: [String: Any] = [
                "title": exp.title,
                "company": exp.company
            ]
            if let description = exp.description {
                dict["description"] = description
            }
            if let startDate = exp.startDate {
                dict["startDate"] = startDate
            }
            if let endDate = exp.endDate {
                dict["endDate"] = endDate
            }
            return dict
        }
    }
    
    private func generateEducationJSON(resumeData: ResumeData?) -> [[String: Any]] {
        guard let resumeData = resumeData,
              let education = resumeData.education else {
            return []
        }
        
        return education.map { edu in
            var dict: [String: Any] = [
                "degree": edu.degree,
                "school": edu.school
            ]
            if let year = edu.year {
                dict["year"] = year
            }
            if let gpa = edu.gpa {
                dict["gpa"] = gpa
            }
            return dict
        }
    }
    
    private func generateSkillsJSON(resumeData: ResumeData?) -> [String] {
        guard let resumeData = resumeData,
              let skills = resumeData.skills else {
            return []
        }
        return skills
    }
}

// MARK: - Form Auto-Fill View
struct FormAutoFillView: View {
    let applicationData: ApplicationData
    @Environment(\.dismiss) var dismiss
    @State private var selectedFormat: ExportFormat = .plainText
    @State private var showingShareSheet = false
    @State private var shareContent: String = ""
    
    enum ExportFormat: String, CaseIterable {
        case plainText = "Plain Text"
        case json = "JSON"
        case browserExtension = "Browser Extension Format"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Format Selector
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export Format")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Picker("Format", selection: $selectedFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                
                // Preview
                ScrollView {
                    Text(shareContent)
                        .font(.system(size: 14, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                
                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: copyToClipboard) {
                        HStack {
                            Image(systemName: "doc.on.doc")
                            Text("Copy to Clipboard")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Button(action: openInBrowser) {
                        HStack {
                            Image(systemName: "safari")
                            Text("Open Job URL & Prepare Data")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Form Auto-Fill Helper")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updateContent()
            }
            .onChange(of: selectedFormat) { _, _ in
                updateContent()
            }
        }
    }
    
    private func updateContent() {
        switch selectedFormat {
        case .plainText:
            shareContent = FormAutoFillHelper.shared.generatePlainTextSummary(applicationData: applicationData)
        case .json:
            shareContent = FormAutoFillHelper.shared.generateFormDataJSON(applicationData: applicationData)
        case .browserExtension:
            let data = FormAutoFillHelper.shared.generateBrowserExtensionFormat(applicationData: applicationData)
            if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                shareContent = jsonString
            } else {
                shareContent = "{}"
            }
        }
    }
    
    private func copyToClipboard() {
        UIPasteboard.general.string = shareContent
    }
    
    private func openInBrowser() {
        // This would open the job URL
        // The user can then use browser extensions or manual copy-paste
        // For now, we'll just copy the data
        copyToClipboard()
    }
}


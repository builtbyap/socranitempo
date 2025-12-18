//
//  ResumePreviewCard.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct ResumePreviewCard: View {
    let resumeData: ResumeData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Name and Contact Info
            if let name = resumeData.name {
                Text(name)
                    .font(.system(size: 20, weight: .bold))
            }
            
            HStack(spacing: 16) {
                if let email = resumeData.email {
                    Label(email, systemImage: "envelope.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let phone = resumeData.phone {
                    Label(phone, systemImage: "phone.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Quick Stats
            HStack(spacing: 20) {
                if let education = resumeData.education, !education.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(education.count)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.blue)
                        Text("Education")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let experience = resumeData.workExperience, !experience.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(experience.count)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.green)
                        Text("Experiences")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let skills = resumeData.skills, !skills.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(skills.count)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.red)
                        Text("Skills")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // Summary of sections
            VStack(alignment: .leading, spacing: 8) {
                if let education = resumeData.education, !education.isEmpty {
                    HStack {
                        Image(systemName: "graduationcap.fill")
                            .foregroundColor(.blue)
                            .font(.caption)
                        Text("\(education.count) education entries")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let experience = resumeData.workExperience, !experience.isEmpty {
                    HStack {
                        Image(systemName: "briefcase.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("\(experience.count) work experiences")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let projects = resumeData.projects, !projects.isEmpty {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.purple)
                            .font(.caption)
                        Text("\(projects.count) projects")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let languages = resumeData.languages, !languages.isEmpty {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("\(languages.count) languages")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let certifications = resumeData.certifications, !certifications.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.cyan)
                            .font(.caption)
                        Text("\(certifications.count) certifications")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let awards = resumeData.awards, !awards.isEmpty {
                    HStack {
                        Image(systemName: "trophy.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("\(awards.count) awards")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ResumePreviewCard(resumeData: ResumeData(
        id: "1",
        name: "John Doe",
        email: "john@example.com",
        phone: "+1 (555) 123-4567",
        skills: ["Swift", "iOS", "SwiftUI"],
        workExperience: [
            WorkExperience(title: "Software Engineer", company: "Tech Corp", duration: "2020-2023", description: nil)
        ],
        education: [
            Education(degree: "BS Computer Science", school: "University", year: "2020")
        ],
        projects: nil,
        languages: nil,
        certifications: nil,
        awards: nil,
        resumeUrl: nil,
        parsedAt: "2025-12-17"
    ))
    .padding()
}


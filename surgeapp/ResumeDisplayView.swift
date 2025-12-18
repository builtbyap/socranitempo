//
//  ResumeDisplayView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct ResumeDisplayView: View {
    let resumeData: ResumeData
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                if let name = resumeData.name {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(name)
                            .font(.system(size: 28, weight: .bold))
                        
                        HStack(spacing: 16) {
                            if let email = resumeData.email {
                                Label(email, systemImage: "envelope.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            if let phone = resumeData.phone {
                                Label(phone, systemImage: "phone.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                }
                
                // Education Section
                if let education = resumeData.education, !education.isEmpty {
                    ResumeSection(title: "Education", icon: "graduationcap.fill", color: .blue) {
                        ForEach(Array(education.enumerated()), id: \.offset) { index, edu in
                            EducationCard(education: edu)
                        }
                    }
                }
                
                // Experience Section
                if let experience = resumeData.workExperience, !experience.isEmpty {
                    ResumeSection(title: "Experiences", icon: "briefcase.fill", color: .green) {
                        ForEach(Array(experience.enumerated()), id: \.offset) { index, exp in
                            ExperienceCard(experience: exp)
                        }
                    }
                }
                
                // Projects Section
                if let projects = resumeData.projects, !projects.isEmpty {
                    ResumeSection(title: "Projects", icon: "folder.fill", color: .purple) {
                        ForEach(Array(projects.enumerated()), id: \.offset) { index, project in
                            ProjectCard(project: project)
                        }
                    }
                }
                
                // Languages Section
                if let languages = resumeData.languages, !languages.isEmpty {
                    ResumeSection(title: "Languages", icon: "globe", color: .orange) {
                        ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                            LanguageCard(language: language)
                        }
                    }
                }
                
                // Skills Section
                if let skills = resumeData.skills, !skills.isEmpty {
                    ResumeSection(title: "Skills", icon: "star.fill", color: .red) {
                        SkillsCard(skills: skills)
                    }
                }
                
                // Certifications Section
                if let certifications = resumeData.certifications, !certifications.isEmpty {
                    ResumeSection(title: "Certifications", icon: "checkmark.seal.fill", color: .cyan) {
                        ForEach(Array(certifications.enumerated()), id: \.offset) { index, cert in
                            CertificationCard(certification: cert)
                        }
                    }
                }
                
                // Awards Section
                if let awards = resumeData.awards, !awards.isEmpty {
                    ResumeSection(title: "Awards", icon: "trophy.fill", color: .yellow) {
                        ForEach(Array(awards.enumerated()), id: \.offset) { index, award in
                            AwardCard(award: award)
                        }
                    }
                }
            }
            .padding(.bottom, 40)
        }
        .navigationTitle("Resume Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ResumeSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let content: Content
    
    init(title: String, icon: String, color: Color, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                
                Text(title)
                    .font(.system(size: 22, weight: .bold))
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                content
            }
            .padding(.horizontal)
        }
    }
}

struct EducationCard: View {
    let education: Education
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(education.degree)
                .font(.system(size: 17, weight: .semibold))
            
            Text(education.school)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            if let year = education.year {
                Text(year)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ExperienceCard: View {
    let experience: WorkExperience
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(experience.title)
                .font(.system(size: 17, weight: .semibold))
            
            Text(experience.company)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            
            if let duration = experience.duration {
                Text(duration)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            if let description = experience.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProjectCard: View {
    let project: Project
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(project.name)
                .font(.system(size: 17, weight: .semibold))
            
            if let description = project.description {
                Text(description)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            if let technologies = project.technologies {
                HStack {
                    Image(systemName: "wrench.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(technologies)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            if let url = project.url, !url.isEmpty {
                Link(url, destination: URL(string: url)!)
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct LanguageCard: View {
    let language: Language
    
    var body: some View {
        HStack {
            Text(language.name)
                .font(.system(size: 16, weight: .medium))
            
            Spacer()
            
            if let proficiency = language.proficiency {
                Text(proficiency)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SkillsCard: View {
    let skills: [String]
    
    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(skills, id: \.self) { skill in
                Text(skill)
                    .font(.system(size: 14, weight: .medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CertificationCard: View {
    let certification: Certification
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(certification.name)
                .font(.system(size: 17, weight: .semibold))
            
            if let issuer = certification.issuer {
                Text(issuer)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                if let date = certification.date {
                    Label(date, systemImage: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                if let expiryDate = certification.expiryDate {
                    Label("Expires: \(expiryDate)", systemImage: "clock")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct AwardCard: View {
    let award: Award
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(award.title)
                .font(.system(size: 17, weight: .semibold))
            
            if let issuer = award.issuer {
                Text(issuer)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 16) {
                if let date = award.date {
                    Label(date, systemImage: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
            
            if let description = award.description {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// FlowLayout for skills tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.width ?? .infinity,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX,
                                     y: bounds.minY + result.frames[index].minY),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var frames: [CGRect] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }
                
                frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    NavigationView {
        ResumeDisplayView(resumeData: ResumeData(
            id: "1",
            name: "John Doe",
            email: "john@example.com",
            phone: "+1 (555) 123-4567",
            skills: ["Swift", "iOS", "SwiftUI"],
            workExperience: [
                WorkExperience(title: "Software Engineer", company: "Tech Corp", duration: "2020-2023", description: "Developed iOS apps")
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
    }
}


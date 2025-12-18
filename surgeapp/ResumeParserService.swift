//
//  ResumeParserService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation
import PDFKit

class ResumeParserService {
    static let shared = ResumeParserService()
    
    private init() {}
    
    // MARK: - Extract Text from File
    func extractText(from fileURL: URL) async throws -> String {
        let fileExtension = fileURL.pathExtension.lowercased()
        
        switch fileExtension {
        case "pdf":
            return try extractTextFromPDF(url: fileURL)
        case "doc", "docx":
            return try extractTextFromWord(url: fileURL)
        case "txt":
            return try String(contentsOf: fileURL, encoding: .utf8)
        default:
            throw ResumeParserError.unsupportedFormat
        }
    }
    
    // MARK: - Extract Text from PDF
    private func extractTextFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ResumeParserError.couldNotReadFile
        }
        
        var fullText = ""
        let pageCount = pdfDocument.pageCount
        
        for pageIndex in 0..<pageCount {
            if let page = pdfDocument.page(at: pageIndex) {
                if let pageText = page.string {
                    fullText += pageText + "\n"
                }
            }
        }
        
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Extract Text from Word Document
    private func extractTextFromWord(url: URL) throws -> String {
        // For .docx files, we can read the XML content
        // For .doc files, we'd need a library, but for now we'll try to read as text
        if url.pathExtension.lowercased() == "docx" {
            // .docx is a ZIP file containing XML
            // For simplicity, we'll try to read it as text (limited support)
            if let data = try? Data(contentsOf: url),
               let text = String(data: data, encoding: .utf8) {
                // Extract text between XML tags (basic extraction)
                return extractTextFromDocxXML(data: data)
            }
        }
        
        // Fallback: try reading as plain text
        if let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        
        throw ResumeParserError.couldNotReadFile
    }
    
    private func extractTextFromDocxXML(data: Data) -> String {
        // Basic extraction from DOCX XML structure
        // This is a simplified version - for production, use a proper DOCX parser
        guard let xmlString = String(data: data, encoding: .utf8) else {
            return ""
        }
        
        // Extract text between <w:t> tags (Word text elements)
        let pattern = "<w:t[^>]*>([^<]+)</w:t>"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(xmlString.startIndex..., in: xmlString)
        
        var extractedText = ""
        regex?.enumerateMatches(in: xmlString, options: [], range: range) { match, _, _ in
            if let match = match,
               let range = Range(match.range(at: 1), in: xmlString) {
                extractedText += String(xmlString[range]) + " "
            }
        }
        
        return extractedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Parse Resume Text (with OpenAI)
    func parseResume(text: String) async throws -> ResumeData {
        // Try OpenAI first for better accuracy
        do {
            print("🤖 Using OpenAI to parse and categorize resume...")
            let resumeData = try await OpenAIService.shared.parseAndCategorizeResume(text: text)
            print("✅ OpenAI parsing completed successfully")
            return resumeData
        } catch {
            print("⚠️ OpenAI parsing failed, falling back to rule-based parser: \(error.localizedDescription)")
            // Fallback to rule-based parsing if OpenAI fails
            return parseResumeFallback(text: text)
        }
    }
    
    // MARK: - Fallback Rule-Based Parser
    private func parseResumeFallback(text: String) -> ResumeData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        let name = extractName(from: lines)
        let email = extractEmail(from: text)
        let phone = extractPhone(from: text)
        let skills = extractSkills(from: text)
        let workExperience = extractWorkExperience(from: lines)
        let education = extractEducation(from: lines)
        let projects = extractProjects(from: lines)
        let languages = extractLanguages(from: text, lines: lines)
        let certifications = extractCertifications(from: lines)
        let awards = extractAwards(from: lines)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        return ResumeData(
            id: UUID().uuidString,
            name: name,
            email: email,
            phone: phone,
            skills: skills.isEmpty ? nil : skills,
            workExperience: workExperience.isEmpty ? nil : workExperience,
            education: education.isEmpty ? nil : education,
            projects: projects.isEmpty ? nil : projects,
            languages: languages.isEmpty ? nil : languages,
            certifications: certifications.isEmpty ? nil : certifications,
            awards: awards.isEmpty ? nil : awards,
            resumeUrl: nil,
            parsedAt: dateFormatter.string(from: Date())
        )
    }
    
    // MARK: - Extract Name
    private func extractName(from lines: [String]) -> String? {
        // Usually the first line or first few lines contain the name
        if let firstLine = lines.first, firstLine.count < 50 {
            // Check if it looks like a name (contains letters, may have spaces)
            if firstLine.range(of: "^[A-Za-z\\s'-]+$", options: .regularExpression) != nil {
                return firstLine
            }
        }
        
        // Try first two lines combined
        if lines.count >= 2 {
            let combined = "\(lines[0]) \(lines[1])"
            if combined.count < 50 && combined.range(of: "^[A-Za-z\\s'-]+$", options: .regularExpression) != nil {
                return combined
            }
        }
        
        return nil
    }
    
    // MARK: - Extract Email
    private func extractEmail(from text: String) -> String? {
        let emailPattern = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let regex = try? NSRegularExpression(pattern: emailPattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range),
           let emailRange = Range(match.range, in: text) {
            return String(text[emailRange])
        }
        
        return nil
    }
    
    // MARK: - Extract Phone
    private func extractPhone(from text: String) -> String? {
        let phonePatterns = [
            "\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}", // US format
            "\\+?\\d{1,3}[-.\\s]?\\(?\\d{3}\\)?[-.\\s]?\\d{3}[-.\\s]?\\d{4}", // International
            "\\d{10,}" // Simple 10+ digits
        ]
        
        for pattern in phonePatterns {
            let regex = try? NSRegularExpression(pattern: pattern, options: [])
            let range = NSRange(text.startIndex..., in: text)
            
            if let match = regex?.firstMatch(in: text, options: [], range: range),
               let phoneRange = Range(match.range, in: text) {
                let phone = String(text[phoneRange])
                // Filter out obvious non-phone numbers (too long, dates, etc.)
                if phone.count <= 15 && phone.count >= 10 {
                    return phone
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Extract Skills
    private func extractSkills(from text: String) -> [String] {
        let commonSkills = [
            "Swift", "Objective-C", "iOS", "Xcode", "UIKit", "SwiftUI",
            "JavaScript", "TypeScript", "React", "Node.js", "Python", "Java",
            "SQL", "PostgreSQL", "MongoDB", "Firebase", "Supabase",
            "Git", "GitHub", "Docker", "AWS", "Azure", "REST API",
            "Machine Learning", "AI", "Data Science", "Agile", "Scrum"
        ]
        
        var foundSkills: [String] = []
        let lowercasedText = text.lowercased()
        
        for skill in commonSkills {
            if lowercasedText.contains(skill.lowercased()) {
                foundSkills.append(skill)
            }
        }
        
        // Also look for skills section
        if let skillsSection = extractSection(text: text, sectionTitle: "skills") {
            let skills = skillsSection.components(separatedBy: CharacterSet(charactersIn: ",;•\n"))
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty && $0.count < 50 }
            foundSkills.append(contentsOf: skills)
        }
        
        return Array(Set(foundSkills)) // Remove duplicates
    }
    
    // MARK: - Extract Work Experience
    private func extractWorkExperience(from lines: [String]) -> [WorkExperience] {
        var experiences: [WorkExperience] = []
        
        // Look for work experience section
        var inExperienceSection = false
        var currentTitle: String?
        var currentCompany: String?
        var currentDuration: String?
        var currentDescription: String?
        
        for line in lines {
            let lowercased = line.lowercased()
            
            // Check if we're entering experience section
            if lowercased.contains("experience") && (lowercased.contains("work") || lowercased.contains("employment") || lowercased.contains("professional")) {
                inExperienceSection = true
                continue
            }
            
            if inExperienceSection {
                // Look for job title patterns
                if line.count < 100 && !line.contains("@") {
                    // Check if line looks like a job title
                    if line.range(of: "^[A-Z][a-z]+", options: .regularExpression) != nil {
                        // Save previous experience if exists
                        if let title = currentTitle {
                            experiences.append(WorkExperience(
                                title: title,
                                company: currentCompany ?? "",
                                duration: currentDuration,
                                description: currentDescription
                            ))
                        }
                        
                        // Try to parse title and company
                        let parts = line.components(separatedBy: " at ")
                            .map { $0.trimmingCharacters(in: .whitespaces) }
                        
                        if parts.count >= 2 {
                            currentTitle = parts[0]
                            currentCompany = parts[1]
                        } else {
                            currentTitle = line
                            currentCompany = ""
                        }
                        currentDuration = nil
                        currentDescription = nil
                    }
                    
                    // Look for duration (dates)
                    if line.range(of: "\\d{4}", options: .regularExpression) != nil {
                        currentDuration = line
                    }
                }
            }
        }
        
        // Add last experience
        if let title = currentTitle {
            experiences.append(WorkExperience(
                title: title,
                company: currentCompany ?? "",
                duration: currentDuration,
                description: currentDescription
            ))
        }
        
        return experiences
    }
    
    // MARK: - Extract Education
    private func extractEducation(from lines: [String]) -> [Education] {
        var educations: [Education] = []
        
        var inEducationSection = false
        
        for line in lines {
            let lowercased = line.lowercased()
            
            if lowercased.contains("education") {
                inEducationSection = true
                continue
            }
            
            if inEducationSection {
                // Look for degree patterns
                let degreeKeywords = ["bachelor", "master", "phd", "doctorate", "degree", "diploma", "certificate"]
                if degreeKeywords.contains(where: { lowercased.contains($0) }) {
                    let parts = line.components(separatedBy: ",")
                    if parts.count >= 2 {
                        educations.append(Education(
                            degree: parts[0].trimmingCharacters(in: .whitespaces),
                            school: parts[1].trimmingCharacters(in: .whitespaces),
                            year: parts.count >= 3 ? parts[2].trimmingCharacters(in: .whitespaces) : nil
                        ))
                    } else {
                        educations.append(Education(
                            degree: line,
                            school: "",
                            year: nil
                        ))
                    }
                }
            }
        }
        
        return educations
    }
    
    // MARK: - Extract Projects
    private func extractProjects(from lines: [String]) -> [Project] {
        var projects: [Project] = []
        var inProjectSection = false
        
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            if lowercased.contains("project") && !lowercased.contains("manager") {
                inProjectSection = true
                continue
            }
            
            if inProjectSection {
                // Stop if we hit another major section
                if lowercased.contains("experience") || lowercased.contains("education") || 
                   lowercased.contains("certification") || lowercased.contains("award") {
                    break
                }
                
                // Look for project names (usually capitalized, short lines)
                if line.count < 100 && line.count > 5 && !line.contains("@") {
                    let nextLine = index + 1 < lines.count ? lines[index + 1] : ""
                    
                    projects.append(Project(
                        name: line,
                        description: nextLine.isEmpty ? nil : nextLine,
                        technologies: nil,
                        url: nil
                    ))
                }
            }
        }
        
        return projects
    }
    
    // MARK: - Extract Languages
    private func extractLanguages(from text: String, lines: [String]) -> [Language] {
        var languages: [Language] = []
        var inLanguageSection = false
        
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            if lowercased.contains("language") {
                inLanguageSection = true
                continue
            }
            
            if inLanguageSection {
                // Stop if we hit another major section
                if lowercased.contains("experience") || lowercased.contains("education") || 
                   lowercased.contains("skill") {
                    break
                }
                
                // Look for language patterns (e.g., "English - Fluent", "Spanish - Native")
                let languagePattern = "([A-Za-z]+)\\s*-?\\s*(Native|Fluent|Proficient|Intermediate|Basic|Beginner)?"
                let regex = try? NSRegularExpression(pattern: languagePattern, options: [])
                let range = NSRange(line.startIndex..., in: line)
                
                if let match = regex?.firstMatch(in: line, options: [], range: range) {
                    if let nameRange = Range(match.range(at: 1), in: line) {
                        let name = String(line[nameRange])
                        var proficiency: String? = nil
                        
                        if match.numberOfRanges > 2 {
                            if let profRange = Range(match.range(at: 2), in: line) {
                                proficiency = String(line[profRange])
                            }
                        }
                        
                        languages.append(Language(name: name, proficiency: proficiency))
                    }
                }
            }
        }
        
        return languages
    }
    
    // MARK: - Extract Certifications
    private func extractCertifications(from lines: [String]) -> [Certification] {
        var certifications: [Certification] = []
        var inCertSection = false
        
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            if lowercased.contains("certification") || lowercased.contains("certificate") {
                inCertSection = true
                continue
            }
            
            if inCertSection {
                // Stop if we hit another major section
                if lowercased.contains("experience") || lowercased.contains("education") || 
                   lowercased.contains("award") {
                    break
                }
                
                // Look for certification patterns
                let certKeywords = ["certified", "certification", "certificate", "license", "licensed"]
                if certKeywords.contains(where: { lowercased.contains($0) }) || 
                   (line.count < 100 && line.count > 10) {
                    let parts = line.components(separatedBy: ",")
                    
                    certifications.append(Certification(
                        name: parts[0].trimmingCharacters(in: .whitespaces),
                        issuer: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil,
                        date: parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : nil,
                        expiryDate: nil
                    ))
                }
            }
        }
        
        return certifications
    }
    
    // MARK: - Extract Awards
    private func extractAwards(from lines: [String]) -> [Award] {
        var awards: [Award] = []
        var inAwardSection = false
        
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
            
            if lowercased.contains("award") || lowercased.contains("honor") || lowercased.contains("achievement") {
                inAwardSection = true
                continue
            }
            
            if inAwardSection {
                // Stop if we hit another major section
                if lowercased.contains("experience") || lowercased.contains("education") || 
                   lowercased.contains("certification") {
                    break
                }
                
                // Look for award patterns
                if line.count < 150 && line.count > 5 && !line.contains("@") {
                    let parts = line.components(separatedBy: ",")
                    
                    awards.append(Award(
                        title: parts[0].trimmingCharacters(in: .whitespaces),
                        issuer: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : nil,
                        date: parts.count > 2 ? parts[2].trimmingCharacters(in: .whitespaces) : nil,
                        description: parts.count > 3 ? parts[3...].joined(separator: ", ").trimmingCharacters(in: .whitespaces) : nil
                    ))
                }
            }
        }
        
        return awards
    }
    
    // MARK: - Extract Section
    private func extractSection(text: String, sectionTitle: String) -> String? {
        let pattern = "(?i)\(sectionTitle)[\\s:]*\\n([\\s\\S]*?)(?=\\n[A-Z][^\\n]*:|$)"
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        let range = NSRange(text.startIndex..., in: text)
        
        if let match = regex?.firstMatch(in: text, options: [], range: range),
           let sectionRange = Range(match.range(at: 1), in: text) {
            return String(text[sectionRange]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
}

enum ResumeParserError: LocalizedError {
    case unsupportedFormat
    case couldNotReadFile
    case parsingFailed
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat:
            return "Unsupported file format. Please upload PDF, DOC, DOCX, or TXT files."
        case .couldNotReadFile:
            return "Could not read the file. Please make sure the file is not corrupted."
        case .parsingFailed:
            return "Failed to parse resume. Please try again."
        }
    }
}


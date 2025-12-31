//
//  Models.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Job Post Model
struct JobPost: Identifiable, Codable {
    let id: String
    let title: String
    let company: String
    let location: String
    let postedDate: String
    let description: String?
    let url: String?
    let salary: String?
    let jobType: String?
    let sections: [JobSection]? // Structured sections like "What you'll do", "Requirements", etc.
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case company
        case location
        case postedDate = "posted_date"
        case description
        case url
        case salary
        case jobType = "job_type"
        case sections
    }
    
    // Regular initializer
    init(
        id: String,
        title: String,
        company: String,
        location: String,
        postedDate: String,
        description: String?,
        url: String?,
        salary: String?,
        jobType: String?,
        sections: [JobSection]?
    ) {
        self.id = id
        self.title = title
        self.company = company
        self.location = location
        self.postedDate = postedDate
        self.description = description
        self.url = url
        self.salary = salary
        self.jobType = jobType
        self.sections = sections
    }
    
    // Custom decoder to handle missing or invalid sections gracefully
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        company = try container.decode(String.self, forKey: .company)
        location = try container.decode(String.self, forKey: .location)
        postedDate = try container.decode(String.self, forKey: .postedDate)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        salary = try container.decodeIfPresent(String.self, forKey: .salary)
        jobType = try container.decodeIfPresent(String.self, forKey: .jobType)
        
        // Gracefully handle sections - if it fails to decode, set to nil
        if let sectionsData = try? container.decodeIfPresent([JobSection].self, forKey: .sections) {
            sections = sectionsData
        } else {
            sections = nil
        }
    }
}

// MARK: - Job Section Model
struct JobSection: Identifiable, Codable {
    let id: String
    let title: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
    }
}

// MARK: - LinkedIn Profile Model
struct LinkedInProfile: Identifiable, Codable {
    let id: String
    let name: String
    let title: String
    let company: String
    let connections: Int?
    let linkedin: String
}

// MARK: - Email Contact Model
struct EmailContact: Identifiable, Codable {
    let id: String
    let name: String
    let email: String
    let company: String
    let lastContact: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case company
        case lastContact = "last_contact"
    }
}

// MARK: - Application Model
struct Application: Identifiable, Codable {
    let id: String
    let jobPostId: String
    let jobTitle: String
    let company: String
    let status: String // "applied", "viewed", "interview", "rejected", "accepted", "pending_questions"
    let appliedDate: String
    let resumeUrl: String?
    let jobUrl: String? // Store job URL for resuming automation
    let pendingQuestions: [PendingQuestion]? // Questions that need user input
    
    enum CodingKeys: String, CodingKey {
        case id
        case jobPostId = "job_post_id"
        case jobTitle = "job_title"
        case company
        case status
        case appliedDate = "applied_date"
        case resumeUrl = "resume_url"
        case jobUrl = "job_url"
        case pendingQuestions = "pending_questions"
    }
}

// MARK: - Pending Question Model
struct PendingQuestion: Identifiable, Codable {
    let id: Int
    let fieldType: String
    let inputType: String
    let name: String
    let question: String
    let options: [AnswerOption]?
    let required: Bool
    let selector: String
    
    enum CodingKeys: String, CodingKey {
        case id = "index"
        case fieldType
        case inputType
        case name
        case question
        case options
        case required
        case selector
    }
    
    // Regular initializer for manual creation
    init(
        id: Int,
        fieldType: String,
        inputType: String,
        name: String,
        question: String,
        options: [AnswerOption]?,
        required: Bool,
        selector: String
    ) {
        self.id = id
        self.fieldType = fieldType
        self.inputType = inputType
        self.name = name
        self.question = question
        self.options = options
        self.required = required
        self.selector = selector
    }
    
    // Custom decoder to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        // Provide default for fieldType if missing
        fieldType = try container.decodeIfPresent(String.self, forKey: .fieldType) ?? "input"
        inputType = try container.decodeIfPresent(String.self, forKey: .inputType) ?? "text"
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        question = try container.decode(String.self, forKey: .question)
        options = try container.decodeIfPresent([AnswerOption].self, forKey: .options)
        required = try container.decodeIfPresent(Bool.self, forKey: .required) ?? false
        selector = try container.decodeIfPresent(String.self, forKey: .selector) ?? ""
    }
}

// MARK: - Work Experience Model
struct WorkExperience: Codable {
    let title: String
    let company: String
    let duration: String?
    let description: String?
}

// MARK: - Education Model
struct Education: Codable {
    let degree: String
    let school: String
    let year: String?
}

// MARK: - Project Model
struct Project: Codable {
    let name: String
    let description: String?
    let technologies: String?
    let url: String?
}

// MARK: - Language Model
struct Language: Codable, Identifiable, Hashable {
    var id: String { "\(name)-\(proficiency ?? "")" }
    let name: String
    let proficiency: String?
}

// MARK: - Certification Model
struct Certification: Codable, Identifiable, Hashable {
    var id: String { "\(name)-\(issuer ?? "")-\(date ?? "")" }
    let name: String
    let issuer: String?
    let date: String?
    let expiryDate: String?
}

// MARK: - Award Model
struct Award: Codable, Identifiable, Hashable {
    var id: String { "\(title)-\(issuer ?? "")-\(date ?? "")" }
    let title: String
    let issuer: String?
    let date: String?
    let description: String?
}

// MARK: - Resume Data Model
struct ResumeData: Identifiable, Codable {
    let id: String
    let name: String?
    let email: String?
    let phone: String?
    let skills: [String]?
    let workExperience: [WorkExperience]?
    let education: [Education]?
    let projects: [Project]?
    let languages: [Language]?
    let certifications: [Certification]?
    let awards: [Award]?
    let resumeUrl: String?
    let parsedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case skills
        case workExperience = "work_experience"
        case education
        case projects
        case languages
        case certifications
        case awards
        case resumeUrl = "resume_url"
        case parsedAt = "parsed_at"
    }
}


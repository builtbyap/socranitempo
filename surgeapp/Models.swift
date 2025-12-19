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
    let status: String // "applied", "viewed", "interview", "rejected", "accepted"
    let appliedDate: String
    let resumeUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case jobPostId = "job_post_id"
        case jobTitle = "job_title"
        case company
        case status
        case appliedDate = "applied_date"
        case resumeUrl = "resume_url"
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


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


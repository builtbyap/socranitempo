//
//  GoogleDriveAPIService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

class GoogleDriveAPIService {
    static let shared = GoogleDriveAPIService()
    
    private let baseURL = "https://www.googleapis.com/drive/v3"
    
    private init() {}
    
    // List files from Google Drive
    func listFiles(accessToken: String, mimeTypes: [String] = ["application/pdf", "application/msword", "application/vnd.openxmlformats-officedocument.wordprocessingml.document"]) async throws -> [GoogleDriveFile] {
        var urlComponents = URLComponents(string: "\(baseURL)/files")!
        
        // Build query string for MIME types
        let mimeTypeQuery = mimeTypes.map { "mimeType='\($0)'" }.joined(separator: " or ")
        urlComponents.queryItems = [
            URLQueryItem(name: "q", value: "\(mimeTypeQuery) and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,modifiedTime)"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc")
        ]
        
        guard let url = urlComponents.url else {
            throw GoogleDriveError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveError.requestFailed(statusCode: nil, message: "No HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleDriveError.requestFailed(statusCode: httpResponse.statusCode, message: "Failed to list files: \(errorMessage)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let responseData = try decoder.decode(GoogleDriveFileListResponse.self, from: data)
        
        return responseData.files
    }
    
    // Download file from Google Drive
    func downloadFile(fileId: String, accessToken: String) async throws -> Data {
        guard let url = URL(string: "\(baseURL)/files/\(fileId)?alt=media") else {
            throw GoogleDriveError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleDriveError.requestFailed(statusCode: nil, message: "No HTTP response")
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GoogleDriveError.requestFailed(statusCode: httpResponse.statusCode, message: "Failed to download file: \(errorMessage)")
        }
        
        return data
    }
}

// MARK: - Google Drive Models
struct GoogleDriveFileListResponse: Codable {
    let files: [GoogleDriveFile]
}

struct GoogleDriveFile: Identifiable, Codable {
    let id: String
    let name: String
    let mimeType: String
    let size: String?
    let modifiedTime: String?
    
    var fileSize: Int64? {
        guard let size = size else { return nil }
        return Int64(size)
    }
    
    var formattedSize: String? {
        guard let size = fileSize else { return nil }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

enum GoogleDriveError: LocalizedError {
    case invalidURL
    case requestFailed(statusCode: Int?, message: String)
    case notAuthenticated
    case fileNotFound
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Google Drive API URL."
        case .requestFailed(let statusCode, let message):
            return "Google Drive API request failed: \(statusCode.map { "HTTP \($0) - " } ?? "")\(message)"
        case .notAuthenticated:
            return "Not authenticated with Google. Please sign in."
        case .fileNotFound:
            return "File not found in Google Drive."
        }
    }
}


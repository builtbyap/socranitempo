//
//  FlyService.swift
//  surgeapp
//

import Foundation

/// Talks to your Fly.io backend (`socrani-api-proxy`). Base URL is set in Info.plist key `FlyServiceBaseURL`.
enum FlyService {
    private static let infoPlistKey = "FlyServiceBaseURL"
    private static let transcribePathPlistKey = "FlyTranscribeAudioPath"
    private static let urlNotesPathPlistKey = "FlyGenerateNotesFromURLPath"
    private static let documentNotesPathPlistKey = "FlyGenerateNotesFromDocumentPath"
    private static let imageSolvePathPlistKey = "FlySolveHomeworkFromImagePath"
    private static let defaultBase = "https://socrani-api-proxy.fly.dev"
    private static let defaultTranscribePath = "transcribe-audio"
    private static let defaultURLNotesPath = "generate-notes-from-url"
    private static let defaultDocumentNotesPath = "generate-notes-from-document"
    private static let defaultImageSolvePath = "solve-homework-from-image"

    /// Base URL with no trailing slash.
    static var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: infoPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let url = URL(string: trimmed) {
                return url
            }
        }
        return URL(string: defaultBase)!
    }

    /// Path appended to `baseURL` for audio-to-notes transcription.
    static var transcribeAudioPath: String {
        if let raw = Bundle.main.object(forInfoDictionaryKey: transcribePathPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }
        return defaultTranscribePath
    }

    /// Path appended to `baseURL` for website/YouTube-to-notes generation.
    static var generateNotesFromURLPath: String {
        if let raw = Bundle.main.object(forInfoDictionaryKey: urlNotesPathPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }
        return defaultURLNotesPath
    }

    /// Path appended to `baseURL` for uploaded-document-to-notes generation.
    static var generateNotesFromDocumentPath: String {
        if let raw = Bundle.main.object(forInfoDictionaryKey: documentNotesPathPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }
        return defaultDocumentNotesPath
    }

    /// Path appended to `baseURL` for homework solving from an uploaded image.
    static var solveHomeworkFromImagePath: String {
        if let raw = Bundle.main.object(forInfoDictionaryKey: imageSolvePathPlistKey) as? String {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }
        }
        return defaultImageSolvePath
    }

    /// GET `/health` — matches `fly-playwright-service/server.js` `{ status, service }`.
    static func fetchHealth() async throws -> FlyHealthResponse {
        let url = baseURL.appendingPathComponent("health")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FlyServiceError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw FlyServiceError.httpStatus(http.statusCode)
        }
        return try JSONDecoder().decode(FlyHealthResponse.self, from: data)
    }

    /// POST audio file as multipart/form-data and return generated notes/transcript text.
    static func transcribeAudioToNotes(
        fileURL: URL,
        outputMode: StudyGenerationOutput = .notes
    ) async throws -> FlyTranscriptionResult {
        let endpoint = baseURL.appendingPathComponent(transcribeAudioPath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        let mimeType = mimeTypeForAudio(fileURL: fileURL)
        let body = buildMultipartBody(
            boundary: boundary,
            fieldName: "file",
            filename: fileURL.lastPathComponent,
            mimeType: mimeType,
            fileData: audioData,
            additionalFields: ["outputMode": outputMode.rawValue]
        )
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FlyServiceError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw FlyServiceError.httpStatus(http.statusCode)
        }

        return try parseTranscriptionResponse(data)
    }

    /// POST website/YouTube URL and return generated notes.
    static func generateNotesFromURL(
        urlString: String,
        outputMode: StudyGenerationOutput = .notes
    ) async throws -> FlyTranscriptionResult {
        let endpoint = baseURL.appendingPathComponent(generateNotesFromURLPath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload: [String: String] = [
            "url": urlString,
            "outputMode": outputMode.rawValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FlyServiceError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw FlyServiceError.httpStatus(http.statusCode)
        }

        return try parseTranscriptionResponse(data)
    }

    /// POST document file as multipart/form-data and return generated notes.
    static func generateNotesFromDocument(
        fileURL: URL,
        outputMode: StudyGenerationOutput = .notes
    ) async throws -> FlyTranscriptionResult {
        let endpoint = baseURL.appendingPathComponent(generateNotesFromDocumentPath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let mimeType = mimeTypeForDocument(fileURL: fileURL)
        let body = buildMultipartBody(
            boundary: boundary,
            fieldName: "file",
            filename: fileURL.lastPathComponent,
            mimeType: mimeType,
            fileData: fileData,
            additionalFields: ["outputMode": outputMode.rawValue]
        )
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FlyServiceError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw FlyServiceError.httpStatus(http.statusCode)
        }

        return try parseTranscriptionResponse(data)
    }

    /// POST homework/problem image and return solved answer + explanation steps.
    static func solveHomeworkFromImage(fileURL: URL) async throws -> FlyTranscriptionResult {
        let endpoint = baseURL.appendingPathComponent(solveHomeworkFromImagePath)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 120

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let mimeType = mimeTypeForImage(fileURL: fileURL)
        let body = buildMultipartBody(
            boundary: boundary,
            fieldName: "file",
            filename: fileURL.lastPathComponent,
            mimeType: mimeType,
            fileData: fileData
        )
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FlyServiceError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw FlyServiceError.httpStatus(http.statusCode)
        }

        return try parseTranscriptionResponse(data)
    }

    private static func buildMultipartBody(
        boundary: String,
        fieldName: String,
        filename: String,
        mimeType: String,
        fileData: Data,
        additionalFields: [String: String] = [:]
    ) -> Data {
        var body = Data()
        for (key, value) in additionalFields {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
            body.append(value.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }

    private static func mimeTypeForAudio(fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "m4a": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "wav": return "audio/wav"
        case "aac": return "audio/aac"
        default: return "application/octet-stream"
        }
    }

    private static func mimeTypeForDocument(fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "pdf": return "application/pdf"
        case "doc": return "application/msword"
        case "docx": return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "ppt": return "application/vnd.ms-powerpoint"
        case "pptx": return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "txt": return "text/plain"
        case "rtf": return "application/rtf"
        case "md": return "text/markdown"
        default: return "application/octet-stream"
        }
    }

    private static func mimeTypeForImage(fileURL: URL) -> String {
        switch fileURL.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "heic": return "image/heic"
        case "webp": return "image/webp"
        default: return "application/octet-stream"
        }
    }

    private static func parseTranscriptionResponse(_ data: Data) throws -> FlyTranscriptionResult {
        if let decoded = try? JSONDecoder().decode(FlyTranscriptionResult.self, from: data) {
            if let qs = decoded.questions, !qs.isEmpty {
                return decoded
            }
            if let cs = decoded.cards, !cs.isEmpty {
                return decoded
            }
            let n = (decoded.notes ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty {
                return decoded
            }
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FlyServiceError.invalidPayload
        }

        if let cards = json["cards"] as? [[String: Any]], !cards.isEmpty {
            let title = json["title"] as? String
            let topic = json["topic"] as? String
            let pairs = cards.compactMap { row -> FlyFlashcardPairDTO? in
                guard let f = row["front"] as? String, let b = row["back"] as? String else { return nil }
                return FlyFlashcardPairDTO(front: f, back: b)
            }
            if !pairs.isEmpty {
                return FlyTranscriptionResult(title: title, notes: nil, topic: topic, cards: pairs, questions: nil)
            }
        }

        if let qs = json["questions"] as? [[String: Any]], !qs.isEmpty {
            let title = json["title"] as? String
            let topic = json["topic"] as? String
            let questions = qs.compactMap { row -> FlyQuizQuestionDTO? in
                guard let q = row["question"] as? String,
                      let opts = row["options"] as? [String],
                      let idx = row["correctIndex"] as? Int else { return nil }
                return FlyQuizQuestionDTO(question: q, options: opts, correctIndex: idx)
            }
            if !questions.isEmpty {
                return FlyTranscriptionResult(title: title, notes: nil, topic: topic, cards: nil, questions: questions)
            }
        }

        let notesCandidates = [
            json["notes"] as? String,
            json["summary"] as? String,
            json["transcript"] as? String,
            json["text"] as? String
        ]
        if let notes = notesCandidates.compactMap({ $0?.trimmingCharacters(in: .whitespacesAndNewlines) }).first(where: { !$0.isEmpty }) {
            let title = (json["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return FlyTranscriptionResult(title: title, notes: notes, topic: nil, cards: nil, questions: nil)
        }

        throw FlyServiceError.invalidPayload
    }
}

struct FlyHealthResponse: Codable {
    let status: String
    let service: String
}

struct FlyFlashcardPairDTO: Codable, Sendable {
    let front: String
    let back: String
}

struct FlyQuizQuestionDTO: Codable, Sendable {
    let question: String
    let options: [String]
    let correctIndex: Int
}

struct FlyTranscriptionResult: Codable, Sendable {
    let title: String?
    let notes: String?
    let topic: String?
    let cards: [FlyFlashcardPairDTO]?
    let questions: [FlyQuizQuestionDTO]?
}

enum FlyServiceError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Fly.io."
        case .httpStatus(let code):
            return "Fly.io returned HTTP \(code)."
        case .invalidPayload:
            return "Fly.io returned an unexpected transcription payload."
        }
    }
}

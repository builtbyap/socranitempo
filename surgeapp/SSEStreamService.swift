//
//  SSEStreamService.swift
//  surgeapp
//
//  Server-Sent Events (SSE) client for live streaming application process
//

import Foundation
import Combine
import UIKit

// MARK: - Stream Event Types
enum StreamEventType: String {
    case connected
    case navigating
    case filling_form
    case submitting
    case frame
    case completed
    case error
}

// MARK: - Stream Event
struct StreamEvent: Codable {
    let type: String
    let timestamp: Int64?
    let frame: String?
    let step: String?
    let url: String?
    let filledFields: Int?
    let submitted: Bool?
    let success: Bool?
    let requiresOAuth: Bool?
    let sessionId: String?
    let error: String?
    
    var eventType: StreamEventType? {
        return StreamEventType(rawValue: type)
    }
}

// MARK: - SSE Stream Service
class SSEStreamService: ObservableObject {
    static let shared = SSEStreamService()
    
    @Published var currentFrame: UIImage?
    @Published var currentStep: String?
    @Published var isConnected: Bool = false
    @Published var error: String?
    
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var currentSessionId: String?
    private var buffer: Data = Data()
    private var streamDelegate: StreamDelegate?
    
    private init() {}
    
    // MARK: - Connect to Stream
    func connect(sessionId: String, serviceURL: String) {
        // Disconnect existing connection if any
        disconnect()
        
        currentSessionId = sessionId
        let streamURL = "\(serviceURL)/stream/\(sessionId)"
        
        guard let url = URL(string: streamURL) else {
            self.error = "Invalid stream URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 300.0 // 5 minutes
        
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300.0
        configuration.timeoutIntervalForResource = 300.0
        
        // Create delegate and retain it
        streamDelegate = StreamDelegate(service: self)
        urlSession = URLSession(configuration: configuration, delegate: streamDelegate, delegateQueue: nil)
        
        dataTask = urlSession?.dataTask(with: request)
        dataTask?.resume()
    }
    
    // MARK: - Stream Delegate
    private class StreamDelegate: NSObject, URLSessionDataDelegate {
        weak var service: SSEStreamService?
        
        init(service: SSEStreamService) {
            self.service = service
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
            guard let httpResponse = response as? HTTPURLResponse else {
                DispatchQueue.main.async {
                    self.service?.error = "Invalid response from stream server"
                    self.service?.isConnected = false
                }
                completionHandler(.cancel)
                return
            }
            
            if (200...299).contains(httpResponse.statusCode) {
                DispatchQueue.main.async {
                    self.service?.isConnected = true
                    self.service?.error = nil
                    print("✅ SSE stream connected successfully")
                }
                completionHandler(.allow)
            } else {
                let errorMsg = "Failed to connect to stream (HTTP \(httpResponse.statusCode))"
                DispatchQueue.main.async {
                    self.service?.error = errorMsg
                    self.service?.isConnected = false
                }
                print("❌ \(errorMsg)")
                completionHandler(.cancel)
            }
        }
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            service?.processIncrementalData(data)
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
            if let error = error {
                let errorMessage = error.localizedDescription
                // Check if it's a cancellation (which might be expected in some cases)
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    // Connection was cancelled - might be intentional
                    print("⚠️ Stream connection cancelled")
                } else {
                    DispatchQueue.main.async {
                        self.service?.error = errorMessage
                        self.service?.isConnected = false
                    }
                }
            } else {
                // Connection completed normally (stream ended)
                DispatchQueue.main.async {
                    self.service?.isConnected = false
                }
            }
        }
    }
    
    // MARK: - Process Incremental SSE Data
    private func processIncrementalData(_ newData: Data) {
        buffer.append(newData)
        
        // Process complete SSE messages (ending with \n\n)
        while let range = buffer.range(of: "\n\n".data(using: .utf8)!) {
            let messageData = buffer.subdata(in: 0..<range.lowerBound)
            buffer.removeSubrange(0..<range.upperBound)
            
            if let string = String(data: messageData, encoding: .utf8) {
                processSSEMessage(string)
            }
        }
    }
    
    // MARK: - Process SSE Message
    private func processSSEMessage(_ message: String) {
        let lines = message.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6)) // Remove "data: " prefix
                
                guard let jsonData = jsonString.data(using: .utf8),
                      let event = try? JSONDecoder().decode(StreamEvent.self, from: jsonData) else {
                    continue
                }
                
                DispatchQueue.main.async {
                    self.handleEvent(event)
                }
            }
        }
    }
    
    // MARK: - Handle Stream Event
    private func handleEvent(_ event: StreamEvent) {
        switch event.eventType {
        case .connected:
            print("✅ SSE Stream connected: \(event.sessionId ?? "unknown")")
            
        case .navigating:
            currentStep = "Navigating to application form..."
            if let url = event.url {
                print("🌐 Navigating to: \(url)")
            }
            
        case .filling_form:
            currentStep = "Filling application form..."
            print("📝 Filling form...")
            
        case .submitting:
            currentStep = "Submitting application..."
            print("📤 Submitting...")
            
        case .frame:
            if let frameBase64 = event.frame,
               let frameData = Data(base64Encoded: frameBase64),
               let image = UIImage(data: frameData) {
                currentFrame = image
                
                if let step = event.step {
                    switch step {
                    case "navigated":
                        currentStep = "Application form loaded"
                    case "form_filled":
                        currentStep = "Form filled (\(event.filledFields ?? 0) fields)"
                    case "submitted":
                        currentStep = "Application submitted"
                    case "completed":
                        currentStep = "Application complete"
                    default:
                        currentStep = "Processing..."
                    }
                }
            }
            
        case .completed:
            currentStep = "Application complete"
            if let success = event.success, success {
                print("✅ Application completed successfully")
            }
            // Stream will close automatically
            
        case .error:
            if let errorMsg = event.error {
                error = errorMsg
                print("❌ Stream error: \(errorMsg)")
            }
            
        case .none:
            break
        }
    }
    
    // MARK: - Disconnect
    func disconnect() {
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        streamDelegate = nil
        buffer = Data()
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.currentFrame = nil
            self.currentStep = nil
            self.error = nil
        }
        
        currentSessionId = nil
    }
    
    deinit {
        disconnect()
    }
}


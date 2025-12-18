//
//  GoogleDriveBrowserView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct GoogleDriveBrowserView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var signInService = GoogleSignInService.shared
    @State private var files: [GoogleDriveFile] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedFile: GoogleDriveFile?
    @State private var isDownloading = false
    
    let onFileSelected: (URL, String) -> Void
    
    var body: some View {
        NavigationView {
            Group {
                if !signInService.isSignedIn {
                    // Sign In View
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
                        Text("Connect to Google Drive")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("Sign in to access your Google Drive files")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            signIn()
                        }) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                Text("Sign in with Google")
                            }
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        
                        Spacer()
                    }
                } else {
                    // File Browser View
                    if isLoading {
                        VStack {
                            Spacer()
                            ProgressView()
                            Text("Loading files...")
                                .foregroundColor(.secondary)
                                .padding(.top)
                            Spacer()
                        }
                    } else if let error = errorMessage {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.red)
                            Text("Error")
                                .font(.headline)
                            Text(error)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Button("Retry") {
                                loadFiles()
                            }
                            .padding(.top)
                            Spacer()
                        }
                    } else if files.isEmpty {
                        VStack(spacing: 16) {
                            Spacer()
                            Image(systemName: "doc.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("No files found")
                                .font(.headline)
                            Text("No PDF or Word documents found in your Google Drive")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Spacer()
                        }
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(files) { file in
                                    GoogleDriveFileRow(file: file) {
                                        downloadAndSelectFile(file)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Google Drive")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                if signInService.isSignedIn {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Sign Out") {
                            signInService.signOut()
                            files = []
                        }
                    }
                }
            }
            .overlay {
                if isDownloading {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Downloading file...")
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
        }
        .onAppear {
            if signInService.isSignedIn {
                loadFiles()
            }
        }
    }
    
    private func signIn() {
        isLoading = true
        errorMessage = nil
        
        GoogleSignInService.shared.signIn { [self] success, error in
            isLoading = false
            if success {
                loadFiles()
            } else {
                errorMessage = error?.localizedDescription ?? "Failed to sign in"
            }
        }
    }
    
    private func loadFiles() {
        guard let accessToken = signInService.getAccessToken() else {
            errorMessage = "Not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let driveFiles = try await GoogleDriveAPIService.shared.listFiles(accessToken: accessToken)
                await MainActor.run {
                    self.files = driveFiles
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }
    
    private func downloadAndSelectFile(_ file: GoogleDriveFile) {
        guard let accessToken = signInService.getAccessToken() else {
            errorMessage = "Not authenticated"
            return
        }
        
        isDownloading = true
        errorMessage = nil
        
        Task {
            do {
                let fileData = try await GoogleDriveAPIService.shared.downloadFile(fileId: file.id, accessToken: accessToken)
                
                // Save file to app's document directory
                let fileManager = FileManager.default
                let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let fileExtension = file.name.components(separatedBy: ".").last ?? "pdf"
                let fileName = "\(UUID().uuidString).\(fileExtension)"
                let destinationURL = documentsPath.appendingPathComponent(fileName)
                
                try fileData.write(to: destinationURL)
                
                await MainActor.run {
                    self.isDownloading = false
                    self.onFileSelected(destinationURL, file.name)
                    self.dismiss()
                }
            } catch {
                await MainActor.run {
                    self.isDownloading = false
                    self.errorMessage = "Failed to download file: \(error.localizedDescription)"
                }
            }
        }
    }
}

struct GoogleDriveFileRow: View {
    let file: GoogleDriveFile
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: fileIcon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    HStack(spacing: 12) {
                        if let size = file.formattedSize {
                            Text(size)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let modifiedTime = file.modifiedTime {
                            Text(formatDate(modifiedTime))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var fileIcon: String {
        if file.mimeType.contains("pdf") {
            return "doc.fill"
        } else if file.mimeType.contains("word") {
            return "doc.text.fill"
        }
        return "doc.fill"
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .short
            displayFormatter.timeStyle = .none
            return displayFormatter.string(from: date)
        }
        return dateString
    }
}


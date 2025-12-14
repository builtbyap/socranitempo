//
//  ResumeUploadView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI
import UniformTypeIdentifiers

struct ResumeUploadView: View {
    @State private var selectedFile: URL?
    @State private var fileName: String = ""
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var showFilePicker = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var uploadedResumeURL: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Section
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 100, height: 100)
                            Image(systemName: "doc.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                        }
                        
                        Text("Upload Your Resume")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text("Upload your resume to get personalized job recommendations")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 40)
                    
                    // File Selection Card
                    VStack(spacing: 16) {
                        if let file = selectedFile, !fileName.isEmpty {
                            // Selected File Display
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(fileName)
                                        .font(.system(size: 16, weight: .semibold))
                                        .lineLimit(1)
                                    
                                    if let fileSize = getFileSize(url: file) {
                                        Text(fileSize)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Button(action: {
                                    selectedFile = nil
                                    fileName = ""
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 24))
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            // Upload Button
                            Button(action: {
                                showFilePicker = true
                            }) {
                                VStack(spacing: 12) {
                                    Image(systemName: "arrow.up.doc.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.blue)
                                    
                                    Text("Choose File")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.blue)
                                    
                                    Text("PDF, DOC, DOCX up to 10MB")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [10]))
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Upload Button
                    if selectedFile != nil && !fileName.isEmpty {
                        Button(action: {
                            Task {
                                await uploadResume()
                            }
                        }) {
                            HStack {
                                if isUploading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 20))
                                }
                                
                                Text(isUploading ? "Uploading..." : "Upload Resume")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isUploading ? Color.blue.opacity(0.6) : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isUploading)
                        .padding(.horizontal)
                        
                        if isUploading {
                            ProgressView(value: uploadProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                                .padding(.horizontal)
                        }
                    }
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                            .padding(.horizontal)
                    }
                    
                    // Success Message
                    if showSuccess {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Resume Uploaded Successfully!")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Your resume has been uploaded and is ready to use.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    // Info Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Supported Formats")
                            .font(.system(size: 18, weight: .semibold))
                        
                        HStack(spacing: 16) {
                            FormatBadge(icon: "doc.fill", text: "PDF")
                            FormatBadge(icon: "doc.fill", text: "DOC")
                            FormatBadge(icon: "doc.fill", text: "DOCX")
                        }
                        
                        Text("• Maximum file size: 10MB")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        
                        Text("• Your resume will be used to match you with relevant job opportunities")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Resume")
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(selectedFile: $selectedFile, fileName: $fileName)
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    // Reset after success
                    selectedFile = nil
                    fileName = ""
                    showSuccess = false
                }
            } message: {
                Text("Your resume has been uploaded successfully!")
            }
        }
    }
    
    private func getFileSize(url: URL) -> String? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let size = attributes[.size] as? Int64 {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: size)
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func uploadResume() async {
        guard let file = selectedFile else { return }
        
        isUploading = true
        errorMessage = nil
        uploadProgress = 0.0
        
        do {
            // Simulate upload progress
            for i in 1...10 {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                await MainActor.run {
                    uploadProgress = Double(i) / 10.0
                }
            }
            
            // Read file data
            let fileData = try Data(contentsOf: file)
            
            // TODO: Upload to your backend/Supabase storage
            // For now, we'll simulate a successful upload
            // In production, you would upload to Supabase Storage or your backend
            
            print("📄 Resume uploaded: \(fileName)")
            print("📊 File size: \(fileData.count) bytes")
            
            // Simulate API call delay
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            
            await MainActor.run {
                isUploading = false
                uploadProgress = 1.0
                showSuccess = true
                uploadedResumeURL = "resumes/\(UUID().uuidString)/\(fileName)"
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = "Failed to upload resume: \(error.localizedDescription)"
            }
        }
    }
}

struct FormatBadge: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
            Text(text)
                .font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white)
        .cornerRadius(8)
    }
}

struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedFile: URL?
    @Binding var fileName: String
    @Environment(\.dismiss) var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        var contentTypes: [UTType] = [.pdf, .text, .plainText]
        
        // Add Word document types if available
        if let docType = UTType(filenameExtension: "doc") {
            contentTypes.append(docType)
        }
        if let docxType = UTType(filenameExtension: "docx") {
            contentTypes.append(docxType)
        }
        
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // Copy file to app's document directory for access
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
            
            do {
                // Remove existing file if it exists
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                
                // Copy file
                try fileManager.copyItem(at: url, to: destinationURL)
                
                parent.selectedFile = destinationURL
                parent.fileName = url.lastPathComponent
            } catch {
                print("Error copying file: \(error)")
            }
            
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    ResumeUploadView()
}


//
//  ResumeUploadView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI
import UniformTypeIdentifiers
import PDFKit
import UIKit

struct ResumeUploadView: View {
    @State private var selectedFile: URL?
    @State private var fileName: String = ""
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0.0
    @State private var showFilePicker = false
    @State private var showGoogleDriveBrowser = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var uploadedResumeURL: String?
    @State private var parsedResumeData: ResumeData?
    @State private var showResumeDetails = false
    @State private var isParsing = false
    @State private var showPreview = false
    @State private var showReviewView = false
    @State private var selectedPreviewTab = 0 // 0: Document, 1: Parsed Info
    
    var body: some View {
        NavigationView {
            Group {
                // Show loading screen when parsing or uploading
                if isParsing || isUploading {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        ProgressView()
                            .scaleEffect(2.0)
                            .tint(.blue)
                        
                        Text(isParsing ? "Analyzing Resume..." : "Uploading...")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        ProgressView(value: uploadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 250)
                            .tint(.blue)
                        
                        Text("\(Int(uploadProgress * 100))%")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground))
                } else {
                ScrollView {
                    VStack(spacing: 24) {
                        // File Selection/Preview Card
                        VStack(spacing: 16) {
                            if let file = selectedFile, !fileName.isEmpty {
                                // Resume Document Preview
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text("Resume Preview")
                                            .font(.system(size: 18, weight: .semibold))
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
                                    
                                    // Actual resume document preview
                                    if file.pathExtension.lowercased() == "pdf" {
                                        // PDF Preview
                                        PDFPreviewView(url: file)
                                            .frame(height: 500)
                                            .background(Color(.systemGray5))
                                            .cornerRadius(12)
                                    } else {
                                        // Word document - show file info with link to full preview
                                        NavigationLink(destination: ResumePreviewView(fileURL: file, fileName: fileName)) {
                                            VStack(spacing: 12) {
                                                Image(systemName: "doc.text.fill")
                                                    .font(.system(size: 50))
                                                    .foregroundColor(.blue)
                                                
                                                Text(fileName)
                                                    .font(.system(size: 16, weight: .semibold))
                                                
                                                if let fileSize = getFileSize(url: file) {
                                                    Text(fileSize)
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                }
                                                
                                                Text("Tap to view full document")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.blue)
                                                    .padding(.top, 4)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 40)
                                            .background(Color(.systemBackground))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                            )
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            } else {
                                // Upload Buttons
                                VStack(spacing: 16) {
                                    // Choose File Button
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
                                    
                                    // Upload from Google Drive Button
                                    Button(action: {
                                        showGoogleDriveBrowser = true
                                    }) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "icloud.fill")
                                                .font(.system(size: 24))
                                                .foregroundColor(.blue)
                                            
                                            Text("Upload from Google Drive")
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 14))
                                                .foregroundColor(.secondary)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .padding(.horizontal, 20)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                        )
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Upload Button
                        if selectedFile != nil && !fileName.isEmpty {
                            if !showPreview {
                            // Upload Resume Button (will parse first)
                            Button(action: {
                                Task {
                                    await parseAndShowPreview()
                                }
                            }) {
                                HStack {
                                    if isParsing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    } else {
                                        Image(systemName: "arrow.up.circle.fill")
                                            .font(.system(size: 20))
                                    }
                                    
                                    Text(isParsing ? "Analyzing Resume..." : "Upload Resume")
                                        .font(.system(size: 18, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(isParsing ? Color.blue.opacity(0.6) : Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(isParsing)
                            .padding(.horizontal)
                            
                            if isParsing {
                                ProgressView(value: uploadProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .padding(.horizontal)
                            }
                            } else {
                                // Preview Tabs and Action Buttons (shown after preview)
                                if showPreview {
                                    VStack(spacing: 16) {
                                        // Tab Selector
                                        Picker("", selection: $selectedPreviewTab) {
                                            Text("Document").tag(0)
                                            Text("Parsed Info").tag(1)
                                        }
                                        .pickerStyle(.segmented)
                                        .padding(.horizontal)
                                        
                                        // Tab Content
                                        if selectedPreviewTab == 0 {
                                            // Document Preview Tab
                                            if let file = selectedFile {
                                                VStack(alignment: .leading, spacing: 16) {
                                                    HStack {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .foregroundColor(.green)
                                                        Text("Resume Analyzed Successfully")
                                                            .font(.system(size: 18, weight: .semibold))
                                                        Spacer()
                                                    }
                                                    
                                                    Text("Review your resume document below:")
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.secondary)
                                                    
                                                    // Actual resume document preview
                                                    if file.pathExtension.lowercased() == "pdf" {
                                                        // PDF Preview
                                                        PDFPreviewView(url: file)
                                                            .frame(height: 500)
                                                            .background(Color(.systemGray5))
                                                            .cornerRadius(12)
                                                    } else {
                                                        // Word document - show file info with link to full preview
                                                        NavigationLink(destination: ResumePreviewView(fileURL: file, fileName: fileName)) {
                                                            VStack(spacing: 12) {
                                                                Image(systemName: "doc.text.fill")
                                                                    .font(.system(size: 50))
                                                                    .foregroundColor(.blue)
                                                                
                                                                Text(fileName)
                                                                    .font(.system(size: 16, weight: .semibold))
                                                                
                                                                if let fileSize = getFileSize(url: file) {
                                                                    Text(fileSize)
                                                                        .font(.system(size: 14))
                                                                        .foregroundColor(.secondary)
                                                                }
                                                                
                                                                Text("Tap to view full document")
                                                                    .font(.system(size: 14))
                                                                    .foregroundColor(.blue)
                                                                    .padding(.top, 4)
                                                            }
                                                            .frame(maxWidth: .infinity)
                                                            .padding(.vertical, 40)
                                                            .background(Color(.systemBackground))
                                                            .cornerRadius(12)
                                                            .overlay(
                                                                RoundedRectangle(cornerRadius: 12)
                                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                                            )
                                                        }
                                                        .buttonStyle(PlainButtonStyle())
                                                    }
                                                }
                                                .padding()
                                                .background(Color(.systemGray6))
                                                .cornerRadius(12)
                                                .padding(.horizontal)
                                            }
                                        } else {
                                            // Parsed Info Tab
                                            if let resumeData = parsedResumeData {
                                                ScrollView {
                                                    VStack(spacing: 24) {
                                                        // Header
                                                        VStack(spacing: 8) {
                                                            HStack {
                                                                Image(systemName: "checkmark.circle.fill")
                                                                    .foregroundColor(.green)
                                                                Text("Resume Analyzed Successfully")
                                                                    .font(.system(size: 18, weight: .semibold))
                                                                Spacer()
                                                            }
                                                            
                                                            Text("Review parsed information below:")
                                                                .font(.system(size: 14))
                                                                .foregroundColor(.secondary)
                                                        }
                                                        .padding(.horizontal)
                                                        .padding(.top)
                                                        
                                                        // Personal Information
                                                        if let name = resumeData.name, !name.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Name", icon: "person.fill", color: .blue) {
                                                                ParsedInfoBubble(text: name, color: .blue)
                                                            }
                                                        }
                                                        
                                                        if let email = resumeData.email, !email.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Email", icon: "envelope.fill", color: .green) {
                                                                ParsedInfoBubble(text: email, color: .green)
                                                            }
                                                        }
                                                        
                                                        if let phone = resumeData.phone, !phone.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Phone", icon: "phone.fill", color: .orange) {
                                                                ParsedInfoBubble(text: phone, color: .orange)
                                                            }
                                                        }
                                                        
                                                        // Skills
                                                        if let skills = resumeData.skills, !skills.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Skills", icon: "star.fill", color: .red) {
                                                                FlowLayout(spacing: 8) {
                                                                    ForEach(skills, id: \.self) { skill in
                                                                        ParsedInfoBubble(text: skill, color: .red)
                                                                    }
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Education
                                                        if let education = resumeData.education, !education.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Education", icon: "graduationcap.fill", color: .blue) {
                                                                ForEach(Array(education.enumerated()), id: \.offset) { index, edu in
                                                                    ParsedInfoCard(
                                                                        title: edu.degree,
                                                                        subtitle: edu.school,
                                                                        detail: edu.year,
                                                                        color: .blue
                                                                    )
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Work Experience
                                                        if let workExperience = resumeData.workExperience, !workExperience.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Experiences", icon: "briefcase.fill", color: .green) {
                                                                ForEach(Array(workExperience.enumerated()), id: \.offset) { index, exp in
                                                                    ParsedInfoCard(
                                                                        title: exp.title,
                                                                        subtitle: exp.company,
                                                                        detail: exp.duration,
                                                                        description: exp.description,
                                                                        color: .green
                                                                    )
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Projects
                                                        if let projects = resumeData.projects, !projects.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Projects", icon: "folder.fill", color: .purple) {
                                                                ForEach(Array(projects.enumerated()), id: \.offset) { index, project in
                                                                    ParsedInfoCard(
                                                                        title: project.name,
                                                                        subtitle: project.technologies,
                                                                        detail: project.url,
                                                                        description: project.description,
                                                                        color: .purple
                                                                    )
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Languages
                                                        if let languages = resumeData.languages, !languages.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Languages", icon: "globe", color: .orange) {
                                                                ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                                                                    HStack {
                                                                        Text(language.name)
                                                                            .font(.system(size: 14, weight: .medium))
                                                                        if let proficiency = language.proficiency {
                                                                            Text("• \(proficiency)")
                                                                                .font(.system(size: 14))
                                                                                .foregroundColor(.secondary)
                                                                        }
                                                                        Spacer()
                                                                    }
                                                                    .padding()
                                                                    .background(Color.white)
                                                                    .cornerRadius(8)
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Certifications
                                                        if let certifications = resumeData.certifications, !certifications.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Certifications", icon: "checkmark.seal.fill", color: .cyan) {
                                                                ForEach(Array(certifications.enumerated()), id: \.offset) { index, cert in
                                                                    ParsedInfoCard(
                                                                        title: cert.name,
                                                                        subtitle: cert.issuer,
                                                                        detail: cert.date,
                                                                        color: .cyan
                                                                    )
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Awards
                                                        if let awards = resumeData.awards, !awards.isEmpty {
                                                            ParsedInfoBubbleSection(title: "Awards", icon: "trophy.fill", color: .yellow) {
                                                                ForEach(Array(awards.enumerated()), id: \.offset) { index, award in
                                                                    ParsedInfoCard(
                                                                        title: award.title,
                                                                        subtitle: award.issuer,
                                                                        detail: award.date,
                                                                        description: award.description,
                                                                        color: .yellow
                                                                    )
                                                                }
                                                            }
                                                        }
                                                    }
                                                    .padding(.bottom, 100)
                                                }
                                            }
                                        }
                                        
                                        // Confirm Upload and Delete Buttons
                                        VStack(spacing: 12) {
                                            Button(action: {
                                                Task {
                                                    await uploadToSupabase()
                                                }
                                            }) {
                                                HStack {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .font(.system(size: 20))
                                                    Text("Confirm & Upload to Database")
                                                        .font(.system(size: 18, weight: .semibold))
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(Color.green)
                                                .foregroundColor(.white)
                                                .cornerRadius(12)
                                            }
                                            .disabled(parsedResumeData == nil)
                                            
                                            Button(action: {
                                                deleteResume()
                                            }) {
                                                HStack {
                                                    Image(systemName: "trash.fill")
                                                        .font(.system(size: 20))
                                                    Text("Delete & Start Over")
                                                        .font(.system(size: 18, weight: .semibold))
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 16)
                                                .background(Color.red)
                                                .foregroundColor(.white)
                                                .cornerRadius(12)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
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
                        
                        
                        // Success Message (after upload)
                        if showSuccess {
                            VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text("Resume Uploaded Successfully!")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Your resume has been saved to the database.")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            if parsedResumeData != nil {
                                Button(action: {
                                    showResumeDetails = true
                                }) {
                                    HStack {
                                        Image(systemName: "eye.fill")
                                        Text("View Full Resume Details")
                                    }
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                                .padding(.top, 8)
                            }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .navigationTitle("Resume")
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(selectedFile: $selectedFile, fileName: $fileName)
            }
            .sheet(isPresented: $showGoogleDriveBrowser) {
                GoogleDriveBrowserView { fileURL, fileName in
                    selectedFile = fileURL
                    self.fileName = fileName
                }
            }
            .sheet(isPresented: $showReviewView) {
                if let resumeData = parsedResumeData {
                    ResumeReviewView(resumeData: Binding(
                        get: { parsedResumeData ?? resumeData },
                        set: { parsedResumeData = $0 }
                    ))
                }
            }
            .sheet(isPresented: $showResumeDetails) {
                if let resumeData = parsedResumeData {
                    NavigationView {
                        ResumeDisplayView(resumeData: resumeData)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarTrailing) {
                                    Button("Done") {
                                        showResumeDetails = false
                                    }
                                }
                            }
                    }
                }
            }
            .alert("Success", isPresented: $showSuccess) {
                Button("OK") {
                    // Don't reset - keep data for viewing
                }
            } message: {
                Text("Your resume has been uploaded and analyzed successfully!")
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
    
    // MARK: - Parse Resume and Show Preview
    private func parseAndShowPreview() async {
        guard let file = selectedFile else { return }
        
        isParsing = true
        errorMessage = nil
        uploadProgress = 0.0
        showPreview = false
        
        do {
            // Ensure we have access to the file
            let accessing = file.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    file.stopAccessingSecurityScopedResource()
                }
            }
            
            // Step 1: Extract text from resume (50% progress)
            await MainActor.run {
                uploadProgress = 0.5
            }
            
            print("📄 Extracting text from resume...")
            let resumeText = try await ResumeParserService.shared.extractText(from: file)
            print("✅ Extracted \(resumeText.count) characters from resume")
            
            // Step 2: Parse resume data (100% progress)
            await MainActor.run {
                uploadProgress = 1.0
            }
            
            print("🔍 Parsing resume data with OpenAI...")
            let resumeData = try await ResumeParserService.shared.parseResume(text: resumeText)
            
            // Log parsed information
            if let name = resumeData.name {
                print("👤 Name: \(name)")
            }
            if let email = resumeData.email {
                print("📧 Email: \(email)")
            }
            if let phone = resumeData.phone {
                print("📱 Phone: \(phone)")
            }
            if let skills = resumeData.skills {
                print("🛠️ Skills: \(skills.joined(separator: ", "))")
            }
            if let workExp = resumeData.workExperience {
                print("💼 Work Experience: \(workExp.count) entries")
            }
            if let education = resumeData.education {
                print("🎓 Education: \(education.count) entries")
            }
            
            await MainActor.run {
                isParsing = false
                parsedResumeData = resumeData
                showPreview = true
                showReviewView = true // Show review page after parsing
            }
        } catch {
            await MainActor.run {
                isParsing = false
                errorMessage = "Failed to parse resume: \(error.localizedDescription)"
                print("❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Upload to Supabase (after confirmation)
    private func uploadToSupabase() async {
        guard let parsedData = parsedResumeData else { return }
        
        isUploading = true
        errorMessage = nil
        showSuccess = false
        
        do {
            // Generate new UUID for database insertion (to avoid duplicate key errors)
            let resumeUrl = "resumes/\(UUID().uuidString)/\(fileName)"
            let resumeData = ResumeData(
                id: UUID().uuidString, // Generate new ID for each upload
                name: parsedData.name,
                email: parsedData.email,
                phone: parsedData.phone,
                skills: parsedData.skills,
                workExperience: parsedData.workExperience,
                education: parsedData.education,
                projects: parsedData.projects,
                languages: parsedData.languages,
                certifications: parsedData.certifications,
                awards: parsedData.awards,
                resumeUrl: resumeUrl,
                parsedAt: parsedData.parsedAt
            )
            
            print("💾 Saving parsed resume data to Supabase...")
            try await SupabaseService.shared.insertResumeData(resumeData)
            print("✅ Resume data saved successfully!")
            
            await MainActor.run {
                isUploading = false
                showSuccess = true
                uploadedResumeURL = resumeUrl
                parsedResumeData = resumeData // Update with new ID
            }
        } catch {
            await MainActor.run {
                isUploading = false
                errorMessage = "Failed to upload resume: \(error.localizedDescription)"
                print("❌ Error: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Delete Resume
    private func deleteResume() {
        selectedFile = nil
        fileName = ""
        parsedResumeData = nil
        showPreview = false
        showSuccess = false
        errorMessage = nil
        uploadProgress = 0.0
        uploadedResumeURL = nil
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

// MARK: - Parsed Info Display Views
struct ParsedInfoBubbleSection<Content: View>: View {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title3)
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct ParsedInfoBubble: View {
    let text: String
    let color: Color
    
    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .medium))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
}

struct ParsedInfoCard: View {
    let title: String
    let subtitle: String?
    let detail: String?
    let description: String?
    let color: Color
    
    init(title: String, subtitle: String? = nil, detail: String? = nil, description: String? = nil, color: Color) {
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.description = description
        self.color = color
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
            
            if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            
            if let detail = detail, !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            if let description = description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
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
            
            // Start accessing security-scoped resource (required for iCloud Drive files)
            let accessing = url.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
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
                // Show error to user
                DispatchQueue.main.async {
                    // Error will be handled by the parent view
                }
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


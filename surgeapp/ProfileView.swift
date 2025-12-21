//
//  ProfileView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI
import GoogleSignIn
import UniformTypeIdentifiers
import PDFKit

struct ProfileView: View {
    @ObservedObject var signInService = GoogleSignInService.shared
    @State private var isLoading = false
    @State private var selectedFile: URL?
    @State private var fileName: String = ""
    @State private var showFilePicker = false
    @State private var showGoogleDriveBrowser = false
    @State private var cachedFileSize: String?
    @State private var shouldLoadPDFPreview = false
    @State private var parsedResumeData: ResumeData?
    @State private var isParsing = false
    @State private var uploadProgress: Double = 0.0
    @State private var selectedSection = 0 // 0: Resume, 1: Personal, 2: Files
    
    // Personal Information
    @State private var firstName: String = ""
    @State private var middleName: String = ""
    @State private var lastName: String = ""
    @State private var preferredName: String = ""
    @State private var title: String = ""
    @State private var location: String = ""
    @State private var dateOfBirth: String = ""
    @State private var personalEmail: String = ""
    @State private var phone: String = ""
    
    // Demographic Information
    @State private var age: String = ""
    @State private var gender: String = ""
    @State private var ethnicity: String = ""
    
    // Employment Information
    @State private var currentJob: String = ""
    @State private var employmentStatus: String = ""
    @State private var yearsOfExperience: String = ""
    
    // Social Links
    @State private var linkedInURL: String = ""
    @State private var twitterURL: String = ""
    @State private var githubURL: String = ""
    @State private var portfolioURL: String = ""
    
    // Additional Resume Information
    @State private var interests: [String] = []
    @State private var relevantCoursework: [String] = []
    
    // Career Archetypes
    @State private var careerArchetypes: [String] = []
    
    // Add sheet states
    @State private var showingAddLanguage = false
    @State private var showingAddCertification = false
    @State private var showingAddAward = false
    @State private var showingAddInterest = false
    @State private var showingAddCoursework = false
    @State private var showingAddWorkExperience = false
    @State private var showingAddProject = false
    @State private var showingAddSkill = false
    @State private var showingAddEducation = false
    @State private var showingAddCareerArchetype = false
    
    // Edit sheet states
    @State private var showingEditLanguage: Language?
    @State private var showingEditCertification: Certification?
    @State private var showingEditAward: Award?
    @State private var editingInterestIndex: Int?
    @State private var editingCourseworkIndex: Int?
    @State private var editingCareerArchetypeIndex: Int?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Section Selector
                Picker("", selection: $selectedSection) {
                    Text("Resume").tag(0)
                    Text("Personal").tag(1)
                    Text("Files").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Content based on selected section
                ScrollView {
                    VStack(spacing: 24) {
                        if selectedSection == 0 {
                            // Resume Section
                            resumeSection
                        } else if selectedSection == 1 {
                            // Personal Section
                            personalSection
                        } else {
                            // Files Section
                            filesSection
                        }
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(selectedFile: $selectedFile, fileName: $fileName)
            }
            .onChange(of: fileName) { oldValue, newValue in
                // When file name is set (from DocumentPicker), save the file
                if !newValue.isEmpty && selectedFile != nil {
                    saveResumeFile()
                }
            }
            .sheet(isPresented: $showGoogleDriveBrowser) {
                GoogleDriveBrowserView { fileURL, fileName in
                    selectedFile = fileURL
                    self.fileName = fileName
                    cachedFileSize = nil
                    shouldLoadPDFPreview = false
                    // Save the file when selected from Google Drive
                    saveResumeFile()
                }
            }
            .onChange(of: selectedFile) { oldValue, newValue in
                // Clear cached file size when file changes
                if newValue != oldValue {
                    cachedFileSize = nil
                    shouldLoadPDFPreview = false
                    // Save file and auto-parse when new file is selected (not when loading saved file)
                    if newValue != nil && oldValue == nil {
                        // New file selected (not from loadSavedResume), save it and parse
                        // Check if this is a new file by seeing if it's in the saved location
                        let fileManager = FileManager.default
                        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let fileExtension = newValue?.pathExtension ?? "pdf"
                        let savedResumeURL = documentsPath.appendingPathComponent("saved_resume.\(fileExtension)")
                        
                        // Only save and parse if this is NOT the saved file location
                        if newValue?.path != savedResumeURL.path {
                            saveResumeFile()
                            Task {
                                await parseResume()
                            }
                        }
                    } else if newValue == nil {
                        // File cleared
                        parsedResumeData = nil
                    }
                }
            }
            .onAppear {
                // Load saved resume data first (this sets selectedFile and parsedResumeData)
                let hadSavedData = parsedResumeData != nil
                loadSavedResume()
                
                // Load saved career archetypes (user's custom selections)
                loadCareerArchetypes()
                
                // If we have parsed resume data but no saved archetypes, detect them
                if let resumeData = parsedResumeData, careerArchetypes.isEmpty {
                    careerArchetypes = detectCareerArchetypes(from: resumeData)
                }
                
                // Reset PDF preview loading state when view appears
                if selectedFile != nil && !shouldLoadPDFPreview {
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        await MainActor.run {
                            shouldLoadPDFPreview = true
                        }
                    }
                }
                
                // If we loaded saved data but don't have parsed data, parse it
                if selectedFile != nil && parsedResumeData == nil {
                    Task {
                        await parseResume()
                    }
                }
            }
        }
    }
    
    // MARK: - Resume Section
    private var resumeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if isParsing {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Analyzing Resume...")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                ProgressView(value: uploadProgress)
                                    .progressViewStyle(LinearProgressViewStyle())
                                    .frame(width: 200)
                            }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            } else if let resumeData = parsedResumeData {
                // Show parsed resume information bubbles
                VStack(spacing: 12) {
                    // Career Interests - at the top
                    if !careerArchetypes.isEmpty {
                        ParsedInfoBubbleSection(title: "Career Interests", icon: "", color: .blue, onAdd: { showingAddCareerArchetype = true }) {
                            FlowLayout(spacing: 8) {
                                ForEach(Array(careerArchetypes.enumerated()), id: \.offset) { index, archetype in
                                    EditableCareerInterestBubble(
                                        text: archetype,
                                        color: .blue,
                                        onEdit: {
                                            // Find the current index using the text value to ensure accuracy
                                            let archetypeToEdit = archetype
                                            if let currentIndex = careerArchetypes.firstIndex(of: archetypeToEdit) {
                                                editingCareerArchetypeIndex = currentIndex
                                            } else {
                                                editingCareerArchetypeIndex = index
                                            }
                                        },
                                        onDelete: {
                                            // Find current index before deleting to ensure accuracy
                                            if let currentIndex = careerArchetypes.firstIndex(of: archetype) {
                                                careerArchetypes.remove(at: currentIndex)
                                            } else {
                                                careerArchetypes.remove(at: index)
                                            }
                                            saveCareerArchetypes()
                                        }
                                    )
                                }
                            }
                        }
                    } else {
                        AddableSectionRow(
                            title: "Career Interests",
                            count: careerArchetypes.count,
                            placeholder: "Add career interests",
                            onAdd: { showingAddCareerArchetype = true }
                        )
                        Divider()
                    }
                    
                    // Work Experience
                    if let workExp = resumeData.workExperience, !workExp.isEmpty {
                        ParsedInfoBubbleSection(title: "Work Experience", icon: "", color: .green, onAdd: { showingAddWorkExperience = true }) {
                            ForEach(Array(workExp.enumerated()), id: \.offset) { index, exp in
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
                    
                    // Education
                    if let education = resumeData.education, !education.isEmpty {
                        ParsedInfoBubbleSection(title: "Education", icon: "", color: .blue, onAdd: { showingAddEducation = true }) {
                            ForEach(Array(education.enumerated()), id: \.offset) { index, edu in
                                ParsedInfoCard(
                                    title: edu.degree,
                                    subtitle: edu.school,
                                    detail: edu.year,
                                    description: nil,
                                    color: .blue
                                )
                            }
                        }
                    }
                    
                    // Projects
                    if let projects = resumeData.projects, !projects.isEmpty {
                        ParsedInfoBubbleSection(title: "Projects", icon: "", color: .purple, onAdd: { showingAddProject = true }) {
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
                    
                    // Skills
                    if let skills = resumeData.skills, !skills.isEmpty {
                        ParsedInfoBubbleSection(title: "Skills", icon: "", color: .red, onAdd: { showingAddSkill = true }) {
                            FlowLayout(spacing: 8) {
                                ForEach(skills, id: \.self) { skill in
                                    ParsedInfoBubble(text: skill, color: .red)
                                }
                            }
                        }
                    }
                    
                    // Languages
                    if let languages = resumeData.languages, !languages.isEmpty {
                        ParsedInfoBubbleSection(title: "Languages", icon: "", color: .orange, onAdd: { showingAddLanguage = true }) {
                            ForEach(Array(languages.enumerated()), id: \.offset) { index, language in
                                ParsedInfoCard(
                                    title: language.name,
                                    subtitle: language.proficiency,
                                    detail: nil,
                                    description: nil,
                                    color: .orange,
                                    onEdit: {
                                        showingEditLanguage = language
                                    },
                                    onDelete: {
                                        var updatedLanguages = languages
                                        updatedLanguages.remove(at: index)
                                        updateLanguages(updatedLanguages)
                                    }
                                )
                            }
                        }
                    } else {
                        AddableSectionRow(
                            title: "Languages",
                            count: resumeData.languages?.count ?? 0,
                            placeholder: "Add languages",
                            onAdd: { showingAddLanguage = true }
                        )
                        Divider()
                    }
                    
                    // Interests
                    if !interests.isEmpty {
                        ParsedInfoBubbleSection(title: "Interests", icon: "", color: .pink, onAdd: { showingAddInterest = true }) {
                            ForEach(Array(interests.enumerated()), id: \.offset) { index, interest in
                                ParsedInfoCard(
                                    title: interest,
                                    subtitle: nil,
                                    detail: nil,
                                    description: nil,
                                    color: .pink,
                                    onEdit: {
                                        editingInterestIndex = index
                                    },
                                    onDelete: {
                                        interests.remove(at: index)
                                    }
                                )
                            }
                        }
                    } else {
                        AddableSectionRow(
                            title: "Interests",
                            count: interests.count,
                            placeholder: "Add interests",
                            onAdd: { showingAddInterest = true }
                        )
                        Divider()
                    }
                    
                    // Certifications
                    if let certifications = resumeData.certifications, !certifications.isEmpty {
                        ParsedInfoBubbleSection(title: "Certifications", icon: "", color: .cyan, onAdd: { showingAddCertification = true }) {
                            ForEach(Array(certifications.enumerated()), id: \.offset) { index, cert in
                                ParsedInfoCard(
                                    title: cert.name,
                                    subtitle: cert.issuer,
                                    detail: cert.date,
                                    description: cert.expiryDate != nil ? "Expires: \(cert.expiryDate!)" : nil,
                                    color: .cyan,
                                    onEdit: {
                                        showingEditCertification = cert
                                    },
                                    onDelete: {
                                        var updatedCerts = certifications
                                        updatedCerts.remove(at: index)
                                        updateCertifications(updatedCerts)
                                    }
                                )
                            }
                        }
                    } else {
                        AddableSectionRow(
                            title: "Certifications",
                            count: resumeData.certifications?.count ?? 0,
                            placeholder: "Add certifications",
                            onAdd: { showingAddCertification = true }
                        )
                        Divider()
                    }
                    
                    // Awards
                    if let awards = resumeData.awards, !awards.isEmpty {
                        ParsedInfoBubbleSection(title: "Awards", icon: "", color: .yellow, onAdd: { showingAddAward = true }) {
                            ForEach(Array(awards.enumerated()), id: \.offset) { index, award in
                                ParsedInfoCard(
                                    title: award.title,
                                    subtitle: award.issuer,
                                    detail: award.date,
                                    description: award.description,
                                    color: .yellow,
                                    onEdit: {
                                        showingEditAward = award
                                    },
                                    onDelete: {
                                        var updatedAwards = awards
                                        updatedAwards.remove(at: index)
                                        updateAwards(updatedAwards)
                                    }
                                )
                            }
                        }
                    } else {
                        AddableSectionRow(
                            title: "Awards",
                            count: resumeData.awards?.count ?? 0,
                            placeholder: "Add awards",
                            onAdd: { showingAddAward = true }
                        )
                        Divider()
                    }
                    
                    // Relevant Coursework
                    if !relevantCoursework.isEmpty {
                        ParsedInfoBubbleSection(title: "Relevant Coursework", icon: "", color: .indigo, onAdd: { showingAddCoursework = true }) {
                            ForEach(Array(relevantCoursework.enumerated()), id: \.offset) { index, coursework in
                                ParsedInfoCard(
                                    title: coursework,
                                    subtitle: nil,
                                    detail: nil,
                                    description: nil,
                                    color: .indigo,
                                    onEdit: {
                                        editingCourseworkIndex = index
                                    },
                                    onDelete: {
                                        relevantCoursework.remove(at: index)
                                    }
                                )
                            }
                        }
                    } else {
                        AddableSectionRow(
                            title: "Relevant Coursework",
                            count: relevantCoursework.count,
                            placeholder: "Add relevant coursework",
                            onAdd: { showingAddCoursework = true }
                        )
                    }
                }
            } else {
                // No resume data - show message
                VStack(spacing: 12) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No resume uploaded yet")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("Upload a resume in the Files section to see parsed information here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
        .sheet(isPresented: $showingAddLanguage) {
            AddLanguageView(languages: Binding(
                get: { parsedResumeData?.languages ?? [] },
                set: { newLanguages in
                    updateLanguages(newLanguages)
                }
            ))
        }
        .sheet(isPresented: $showingAddCertification) {
            AddCertificationView(certifications: Binding(
                get: { parsedResumeData?.certifications ?? [] },
                set: { newCerts in
                    updateCertifications(newCerts)
                }
            ))
        }
        .sheet(isPresented: $showingAddAward) {
            AddAwardView(awards: Binding(
                get: { parsedResumeData?.awards ?? [] },
                set: { newAwards in
                    updateAwards(newAwards)
                }
            ))
        }
        .sheet(isPresented: $showingAddInterest) {
            AddInterestView(interests: $interests)
        }
        .sheet(isPresented: $showingAddCoursework) {
            AddCourseworkView(coursework: $relevantCoursework)
        }
        .sheet(isPresented: $showingAddWorkExperience) {
            AddExperienceView(experience: Binding(
                get: { parsedResumeData?.workExperience ?? [] },
                set: { newExperience in
                    updateWorkExperience(newExperience)
                }
            ))
        }
        .sheet(isPresented: $showingAddProject) {
            AddProjectView(projects: Binding(
                get: { parsedResumeData?.projects ?? [] },
                set: { newProjects in
                    updateProjects(newProjects)
                }
            ))
        }
        .sheet(isPresented: $showingAddSkill) {
            AddSkillView(skills: Binding(
                get: { parsedResumeData?.skills ?? [] },
                set: { newSkills in
                    updateSkills(newSkills)
                }
            ))
        }
        .sheet(isPresented: $showingAddEducation) {
            AddEducationView(education: Binding(
                get: { parsedResumeData?.education ?? [] },
                set: { newEducation in
                    updateEducation(newEducation)
                }
            ))
        }
        .sheet(item: $showingEditLanguage) { language in
            EditLanguageSheet(language: language) { updatedLanguage in
                if var languages = parsedResumeData?.languages {
                    if let index = languages.firstIndex(where: { $0.id == language.id }) {
                        languages[index] = updatedLanguage
                        updateLanguages(languages)
                    }
                }
            }
        }
        .sheet(item: $showingEditCertification) { cert in
            EditCertificationSheet(certification: cert) { updatedCert in
                if var certifications = parsedResumeData?.certifications {
                    if let index = certifications.firstIndex(where: { $0.id == cert.id }) {
                        certifications[index] = updatedCert
                        updateCertifications(certifications)
                    }
                }
            }
        }
        .sheet(item: $showingEditAward) { award in
            EditAwardSheet(award: award) { updatedAward in
                if var awards = parsedResumeData?.awards {
                    if let index = awards.firstIndex(where: { $0.id == award.id }) {
                        awards[index] = updatedAward
                        updateAwards(awards)
                    }
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingInterestIndex != nil && interests.indices.contains(editingInterestIndex!) },
            set: { if !$0 { editingInterestIndex = nil } }
        )) {
            if let index = editingInterestIndex, interests.indices.contains(index) {
                EditInterestSheet(interest: interests[index]) { updatedInterest in
                    interests[index] = updatedInterest
                    editingInterestIndex = nil
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingCourseworkIndex != nil && relevantCoursework.indices.contains(editingCourseworkIndex!) },
            set: { if !$0 { editingCourseworkIndex = nil } }
        )) {
            if let index = editingCourseworkIndex, relevantCoursework.indices.contains(index) {
                EditCourseworkSheet(coursework: relevantCoursework[index]) { updatedCoursework in
                    relevantCoursework[index] = updatedCoursework
                    editingCourseworkIndex = nil
                }
            }
        }
        .sheet(isPresented: $showingAddCareerArchetype) {
            AddCareerArchetypeView(archetypes: $careerArchetypes) {
                saveCareerArchetypes()
            }
        }
        .sheet(isPresented: Binding(
            get: { 
                if let index = editingCareerArchetypeIndex {
                    return index >= 0 && index < careerArchetypes.count
                }
                return false
            },
            set: { 
                if !$0 { 
                    // Reset the index when sheet is dismissed
                    editingCareerArchetypeIndex = nil
                }
            }
        )) {
            if let index = editingCareerArchetypeIndex,
               index >= 0 && index < careerArchetypes.count {
                EditCareerArchetypeSheet(archetype: careerArchetypes[index]) { updatedArchetype in
                    // Update the array and reset state
                    if index >= 0 && index < careerArchetypes.count {
                        careerArchetypes[index] = updatedArchetype
                    }
                    // Reset state immediately to allow immediate re-editing
                    editingCareerArchetypeIndex = nil
                    saveCareerArchetypes()
                }
            }
        }
    }
    
    // MARK: - Personal Section
    private var personalSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Basic Information Section
            PersonalInfoSectionHeader(title: "Basic Information")
            
            PersonalInfoFieldRow(label: "First Name", value: $firstName, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Middle Name", value: $middleName, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Last Name", value: $lastName, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Preferred Name", value: $preferredName, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Title", value: $title, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Location", value: $location, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Date of Birth", value: $dateOfBirth, keyboardType: .default)
            Divider()
            
            // Contact Information
            PersonalInfoSectionHeader(title: "Contact Information")
            
            PersonalInfoFieldRow(label: "Email", value: $personalEmail, keyboardType: .emailAddress)
            Divider()
            
            PersonalInfoFieldRow(label: "Phone", value: $phone, keyboardType: .phonePad)
            Divider()
            
            // Demographic Information
            PersonalInfoSectionHeader(title: "Demographic Information")
            
            PersonalInfoFieldRow(label: "Age", value: $age, keyboardType: .numberPad)
            Divider()
            
            PersonalInfoFieldRow(label: "Gender", value: $gender, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Ethnicity", value: $ethnicity, keyboardType: .default)
            Divider()
            
            // Employment Information
            PersonalInfoSectionHeader(title: "Employment Information")
            
            PersonalInfoFieldRow(label: "Current Job", value: $currentJob, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Employment Status", value: $employmentStatus, keyboardType: .default)
            Divider()
            
            PersonalInfoFieldRow(label: "Years of Experience", value: $yearsOfExperience, keyboardType: .numberPad)
            Divider()
            
            // Social Links
            PersonalInfoSectionHeader(title: "Social Links")
            
            PersonalInfoFieldRow(label: "LinkedIn", value: $linkedInURL, keyboardType: .URL)
            Divider()
            
            PersonalInfoFieldRow(label: "Twitter", value: $twitterURL, keyboardType: .URL)
            Divider()
            
            PersonalInfoFieldRow(label: "GitHub", value: $githubURL, keyboardType: .URL)
            Divider()
            
            PersonalInfoFieldRow(label: "Portfolio", value: $portfolioURL, keyboardType: .URL)
            
            // Account Actions
            VStack(spacing: 12) {
                if signInService.isSignedIn {
                    // Sign Out Button
                    Button(action: {
                        signInService.signOut()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                                .font(.system(size: 20))
                            Text("Sign Out")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(.red)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                } else {
                    // Sign In Button
                    Button(action: {
                        signIn()
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 20))
                            Text("Sign In with Google")
                                .font(.system(size: 16, weight: .medium))
                            Spacer()
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal)
            .padding(.top)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Initialize from Google Sign-In if available
            if let user = signInService.currentUser {
                let fullName = user.profile?.name ?? ""
                if !fullName.isEmpty && firstName.isEmpty {
                    // Try to split name into first and last
                    let nameParts = fullName.split(separator: " ")
                    if nameParts.count > 0 {
                        firstName = String(nameParts[0])
                    }
                    if nameParts.count > 1 {
                        lastName = String(nameParts[nameParts.count - 1])
                    }
                    if nameParts.count > 2 {
                        middleName = nameParts[1..<nameParts.count - 1].joined(separator: " ")
                    }
                }
                if personalEmail.isEmpty {
                    personalEmail = user.profile?.email ?? ""
                }
            }
            // Initialize from parsed resume data if available
            if let resumeData = parsedResumeData {
                let fullName = resumeData.name ?? ""
                if !fullName.isEmpty && firstName.isEmpty {
                    // Try to split name into first and last
                    let nameParts = fullName.split(separator: " ")
                    if nameParts.count > 0 {
                        firstName = String(nameParts[0])
                    }
                    if nameParts.count > 1 {
                        lastName = String(nameParts[nameParts.count - 1])
                    }
                    if nameParts.count > 2 {
                        middleName = nameParts[1..<nameParts.count - 1].joined(separator: " ")
                    }
                }
                if personalEmail.isEmpty {
                    personalEmail = resumeData.email ?? ""
                }
                if phone.isEmpty {
                    phone = resumeData.phone ?? ""
                }
            }
        }
    }
}

// MARK: - Personal Info Section Header
struct PersonalInfoSectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.system(size: 18, weight: .semibold))
            .foregroundColor(.primary)
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 8)
    }
}

// MARK: - Personal Info Field Row
struct PersonalInfoFieldRow: View {
    let label: String
    @Binding var value: String
    let keyboardType: UIKeyboardType
    @State private var showingEditSheet = false
    
    var body: some View {
        Button(action: {
            showingEditSheet = true
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(value.isEmpty ? "Not set" : value)
                        .font(.system(size: 14))
                        .foregroundColor(value.isEmpty ? .secondary : .primary)
                }
                
                Spacer()
                
                Image(systemName: "pencil")
                    .font(.system(size: 16))
                    .foregroundColor(.green)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingEditSheet) {
            EditTextFieldView(title: label, text: $value, onSave: {
                // Text is already bound, will update automatically
            }, keyboardType: keyboardType)
        }
    }
}

// MARK: - Addable Section Row
struct AddableSectionRow: View {
    let title: String
    let count: Int
    let placeholder: String
    let onAdd: () -> Void
    
    var body: some View {
        Button(action: {
            onAdd()
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(title) (\(count))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(placeholder)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Interest View
struct AddInterestView: View {
    @Binding var interests: [String]
    @State private var newInterest = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Interest", text: $newInterest)
            }
            .navigationTitle("Add Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !newInterest.isEmpty {
                            interests.append(newInterest)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(newInterest.isEmpty)
                }
            }
        }
    }
}

// MARK: - Add Coursework View
struct AddCourseworkView: View {
    @Binding var coursework: [String]
    @State private var newCoursework = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Course", text: $newCoursework)
            }
            .navigationTitle("Add Coursework")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !newCoursework.isEmpty {
                            coursework.append(newCoursework)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(newCoursework.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Language Sheet
struct EditLanguageSheet: View {
    let language: Language
    let onSave: (Language) -> Void
    @State private var name: String
    @State private var selectedProficiency: AddLanguageView.ProficiencyOption
    @Environment(\.dismiss) var dismiss
    
    init(language: Language, onSave: @escaping (Language) -> Void) {
        self.language = language
        self.onSave = onSave
        _name = State(initialValue: language.name)
        let proficiencyValue = language.proficiency ?? ""
        _selectedProficiency = State(initialValue: AddLanguageView.ProficiencyOption(rawValue: proficiencyValue) ?? .none)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Language", text: $name)
                Picker("Proficiency", selection: $selectedProficiency) {
                    ForEach(AddLanguageView.ProficiencyOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            }
            .navigationTitle("Edit Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let proficiency = selectedProficiency == .none ? nil : selectedProficiency.rawValue
                        onSave(Language(name: name, proficiency: proficiency))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Certification Sheet
struct EditCertificationSheet: View {
    let certification: Certification
    let onSave: (Certification) -> Void
    @State private var name: String
    @State private var issuer: String
    @State private var date: String
    @State private var expiryDate: String
    @Environment(\.dismiss) var dismiss
    
    init(certification: Certification, onSave: @escaping (Certification) -> Void) {
        self.certification = certification
        self.onSave = onSave
        _name = State(initialValue: certification.name)
        _issuer = State(initialValue: certification.issuer ?? "")
        _date = State(initialValue: certification.date ?? "")
        _expiryDate = State(initialValue: certification.expiryDate ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Certification Name", text: $name)
                TextField("Issuer", text: $issuer)
                TextField("Date", text: $date)
                TextField("Expiry Date", text: $expiryDate)
            }
            .navigationTitle("Edit Certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(Certification(
                            name: name,
                            issuer: issuer.isEmpty ? nil : issuer,
                            date: date.isEmpty ? nil : date,
                            expiryDate: expiryDate.isEmpty ? nil : expiryDate
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Award Sheet
struct EditAwardSheet: View {
    let award: Award
    let onSave: (Award) -> Void
    @State private var title: String
    @State private var issuer: String
    @State private var date: String
    @State private var description: String
    @Environment(\.dismiss) var dismiss
    
    init(award: Award, onSave: @escaping (Award) -> Void) {
        self.award = award
        self.onSave = onSave
        _title = State(initialValue: award.title)
        _issuer = State(initialValue: award.issuer ?? "")
        _date = State(initialValue: award.date ?? "")
        _description = State(initialValue: award.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Award Title", text: $title)
                TextField("Issuer", text: $issuer)
                TextField("Date", text: $date)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Edit Award")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(Award(
                            title: title,
                            issuer: issuer.isEmpty ? nil : issuer,
                            date: date.isEmpty ? nil : date,
                            description: description.isEmpty ? nil : description
                        ))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Interest Sheet
struct EditInterestSheet: View {
    let interest: String
    let onSave: (String) -> Void
    @State private var text: String
    @Environment(\.dismiss) var dismiss
    
    init(interest: String, onSave: @escaping (String) -> Void) {
        self.interest = interest
        self.onSave = onSave
        _text = State(initialValue: interest)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Interest", text: $text)
            }
            .navigationTitle("Edit Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

// MARK: - Resume Preview Loader View
struct ResumePreviewLoaderView: View {
    let parsedResumeData: ResumeData?
    @Binding var selectedFile: URL?
    @Binding var fileName: String
    @Binding var cachedFileSize: String?
    @Binding var shouldLoadPDFPreview: Bool
    let onClear: () -> Void
    let onLoadFileSize: () async -> Void
    
    @State private var loadedFile: URL?
    
    var body: some View {
        Group {
            if let file = loadedFile ?? selectedFile {
                // Resume Preview Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Resume Preview")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                        }
                    }
                    
                    // Actual resume document preview
                    if file.pathExtension.lowercased() == "pdf" {
                        // PDF Preview - only load after view appears to prevent freezing
                        if shouldLoadPDFPreview {
                            PDFPreviewView(url: file)
                                .frame(height: 300)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                        } else {
                            // Placeholder while waiting for view to be ready
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text("Preparing preview...")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray5))
                            .cornerRadius(12)
                            .onAppear {
                                // Defer PDF loading until view is ready
                                Task {
                                    try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                                    await MainActor.run {
                                        shouldLoadPDFPreview = true
                                    }
                                }
                            }
                        }
                    } else {
                        // Word document - show file info
                        let displayFileName = fileName.isEmpty ? file.lastPathComponent : fileName
                        NavigationLink(destination: ResumePreviewView(fileURL: file, fileName: displayFileName)) {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                                
                                Text(displayFileName)
                                    .font(.system(size: 16, weight: .semibold))
                                
                                if let fileSize = cachedFileSize {
                                    Text(fileSize)
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("Loading...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .task {
                                            await onLoadFileSize()
                                        }
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
                // Fallback: Show info card if file doesn't exist
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Current Resume")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                        Button(action: onClear) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if !fileName.isEmpty {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text(fileName)
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                        
                        Text("Resume data is available. Upload a new resume to replace it.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .onAppear {
            // Load saved file if not already loaded
            if selectedFile == nil {
                let fileManager = FileManager.default
                if let savedFilePath = UserDefaults.standard.string(forKey: "savedResumeFilePath"),
                   fileManager.fileExists(atPath: savedFilePath) {
                    let fileURL = URL(fileURLWithPath: savedFilePath)
                    loadedFile = fileURL
                    selectedFile = fileURL
                    
                    if fileName.isEmpty {
                        fileName = UserDefaults.standard.string(forKey: "savedResumeFileName") ?? fileURL.lastPathComponent
                    }
                    
                    // Trigger PDF preview loading
                    Task {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                        await MainActor.run {
                            shouldLoadPDFPreview = true
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Add Career Interest View
struct AddCareerArchetypeView: View {
    @Binding var archetypes: [String]
    @State private var newArchetype = ""
    @Environment(\.dismiss) var dismiss
    let onSave: () -> Void
    
    // Predefined archetypes for quick selection
    let predefinedArchetypes = [
        "Software Engineer",
        "Data Analyst",
        "Product Manager",
        "Marketing Associate",
        "Finance Analyst"
    ]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Quick Select")) {
                    ForEach(predefinedArchetypes, id: \.self) { archetype in
                        Button(action: {
                            if !archetypes.contains(archetype) {
                                archetypes.append(archetype)
                                onSave()
                            }
                            dismiss()
                        }) {
                            HStack {
                                Text(archetype)
                                    .foregroundColor(.primary)
                                Spacer()
                                if archetypes.contains(archetype) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Custom Interest")) {
                    TextField("Enter career interest", text: $newArchetype)
                    Button("Add Custom") {
                        if !newArchetype.isEmpty && !archetypes.contains(newArchetype) {
                            archetypes.append(newArchetype)
                            newArchetype = ""
                            onSave()
                        }
                    }
                    .disabled(newArchetype.isEmpty || archetypes.contains(newArchetype))
                }
            }
            .navigationTitle("Add Career Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Editing Career Interest Item
struct EditingCareerInterest: Identifiable {
    let id = UUID()
    let index: Int
    let text: String
}

// MARK: - Editable Career Interest Bubble
struct EditableCareerInterestBubble: View {
    let text: String
    let color: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Menu {
            Button(action: onEdit) {
                Label("Edit", systemImage: "pencil")
            }
            Button(role: .destructive, action: onDelete) {
                Label("Delete", systemImage: "trash")
            }
        } label: {
            Text(text)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray5))
                .foregroundColor(.primary)
                .cornerRadius(8)
        }
    }
}

// MARK: - Edit Career Interest Sheet
struct EditCareerArchetypeSheet: View {
    let archetype: String
    let onSave: (String) -> Void
    @State private var editedArchetype: String
    @Environment(\.dismiss) var dismiss
    
    init(archetype: String, onSave: @escaping (String) -> Void) {
        self.archetype = archetype
        self.onSave = onSave
        _editedArchetype = State(initialValue: archetype)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Career Interest", text: $editedArchetype)
            }
            .navigationTitle("Edit Career Interest")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(editedArchetype)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedArchetype.isEmpty)
                }
            }
        }
    }
}

// MARK: - Edit Coursework Sheet
struct EditCourseworkSheet: View {
    let coursework: String
    let onSave: (String) -> Void
    @State private var text: String
    @Environment(\.dismiss) var dismiss
    
    init(coursework: String, onSave: @escaping (String) -> Void) {
        self.coursework = coursework
        self.onSave = onSave
        _text = State(initialValue: coursework)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Course", text: $text)
            }
            .navigationTitle("Edit Coursework")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(text)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                }
            }
        }
    }
}

extension ProfileView {
    // MARK: - Files Section
    private var filesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 12) {
                // Show resume preview if file exists OR if parsed resume data exists (indicating a resume was uploaded)
                // Determine which file to display - check multiple sources
                let displayFile: URL? = {
                    // First priority: selectedFile (if set)
                    if let file = selectedFile {
                        return file
                    }
                    // Second priority: Check UserDefaults for saved file path
                    let fileManager = FileManager.default
                    if let savedFilePath = UserDefaults.standard.string(forKey: "savedResumeFilePath"),
                       fileManager.fileExists(atPath: savedFilePath) {
                        return URL(fileURLWithPath: savedFilePath)
                    }
                    return nil
                }()
                
                // Determine which file name to display
                let displayFileName: String = {
                    // First priority: fileName (if set)
                    if !fileName.isEmpty {
                        return fileName
                    }
                    // Second priority: Check UserDefaults for saved file name
                    if let savedFileName = UserDefaults.standard.string(forKey: "savedResumeFileName") {
                        return savedFileName
                    }
                    // Third priority: Use file name from displayFile
                    if let file = displayFile {
                        return file.lastPathComponent
                    }
                    return ""
                }()
                
                // Show preview if we have a file OR if parsed resume data exists (indicating resume was uploaded)
                if let file = displayFile, !displayFileName.isEmpty {
                    // Resume Preview Card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Resume Preview")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Button(action: {
                                clearSavedResume()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                            }
                        }
                        
                        // Actual resume document preview
                        if file.pathExtension.lowercased() == "pdf" {
                            // PDF Preview - only load after view appears to prevent freezing
                            if shouldLoadPDFPreview {
                                PDFPreviewView(url: file)
                                    .frame(height: 300)
                                    .background(Color(.systemGray5))
                                    .cornerRadius(12)
                            } else {
                                // Placeholder while waiting for view to be ready
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Preparing preview...")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                }
                                .frame(height: 300)
                                .frame(maxWidth: .infinity)
                                .background(Color(.systemGray5))
                                .cornerRadius(12)
                                .onAppear {
                                    // Defer PDF loading until view is ready
                                    Task {
                                        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                                        await MainActor.run {
                                            shouldLoadPDFPreview = true
                                        }
                                    }
                                }
                            }
                        } else {
                            // Word document - show file info
                            NavigationLink(destination: ResumePreviewView(fileURL: file, fileName: displayFileName)) {
                                VStack(spacing: 12) {
                                    Image(systemName: "doc.text.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.blue)
                                    
                                    Text(displayFileName)
                                        .font(.system(size: 16, weight: .semibold))
                                    
                                    if let fileSize = cachedFileSize {
                                        Text(fileSize)
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Loading...")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                            .task {
                                                await loadFileSize()
                                            }
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
                    .onAppear {
                        // Update selectedFile and fileName if they're not set
                        // This ensures the preview always shows when saved resume exists
                        if selectedFile == nil {
                            selectedFile = file
                        }
                        if fileName.isEmpty {
                            fileName = displayFileName
                        }
                        // Trigger PDF preview loading if needed
                        if !shouldLoadPDFPreview {
                            Task {
                                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                                await MainActor.run {
                                    shouldLoadPDFPreview = true
                                }
                            }
                        }
                    }
                } else if parsedResumeData != nil {
                    // If we have parsed data but file isn't loaded yet, show a loading state
                    // This ensures users know a resume exists even if file loading is delayed
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Resume Preview")
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Button(action: {
                                clearSavedResume()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 24))
                            }
                        }
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading resume preview...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 300)
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .task {
                        // Try to load the saved file if not already loaded
                        if selectedFile == nil {
                            let fileManager = FileManager.default
                            if let savedFilePath = UserDefaults.standard.string(forKey: "savedResumeFilePath"),
                               fileManager.fileExists(atPath: savedFilePath) {
                                let savedFileURL = URL(fileURLWithPath: savedFilePath)
                                await MainActor.run {
                                    selectedFile = savedFileURL
                                    if fileName.isEmpty {
                                        fileName = UserDefaults.standard.string(forKey: "savedResumeFileName") ?? savedFileURL.lastPathComponent
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Always show upload section below the preview
                VStack(spacing: 12) {
                    // Upload Resume Button
                    Button(action: {
                        showFilePicker = true
                    }) {
                        VStack(spacing: 12) {
                            Image(systemName: "arrow.up.doc.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.blue)
                            
                            Text(selectedFile != nil || parsedResumeData != nil ? "Replace Resume" : "Upload a Resume")
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
                
                // Upload from Google Drive Button
                Button(action: {
                    showGoogleDriveBrowser = true
                }) {
                    HStack {
                        Image(systemName: "icloud.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Upload from Google Drive")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            Text("Access files from your Google Drive")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                // File Management Info
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "doc.text.fill")
                            .foregroundColor(.blue)
                        Text("Supported Formats")
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                    }
                    
                    Text("PDF, DOC, DOCX up to 10MB")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding(.horizontal)
        }
    }
    
    private func signIn() {
        isLoading = true
        GoogleSignInService.shared.signIn { success, error in
            isLoading = false
            if let error = error {
                print("Sign in error: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadFileSize() async {
        guard let file = selectedFile else { return }
        
        // Load file size on background thread to avoid blocking
        let fileSize: String? = await Task.detached(priority: .userInitiated) {
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
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
        }.value
        
        await MainActor.run {
            cachedFileSize = fileSize
        }
    }
    
    private func parseResume() async {
        guard let file = selectedFile else { return }
        
        await MainActor.run {
            isParsing = true
            uploadProgress = 0.0
        }
        
        do {
            // Step 1: Extract text from resume
            await MainActor.run {
                uploadProgress = 0.5
            }
            
            let resumeText = try await ResumeParserService.shared.extractText(from: file)
            
            guard !resumeText.isEmpty else {
                throw ResumeParserError.couldNotReadFile
            }
            
            // Step 2: Parse resume data
            await MainActor.run {
                uploadProgress = 0.75
            }
            
            let resumeData = try await ResumeParserService.shared.parseResume(text: resumeText)
            
            await MainActor.run {
                uploadProgress = 1.0
                isParsing = false
                parsedResumeData = resumeData
                // Save parsed resume data
                saveParsedResumeData(resumeData)
                // Detect career archetypes from resume data (only if user hasn't customized them)
                if careerArchetypes.isEmpty {
                    careerArchetypes = detectCareerArchetypes(from: resumeData)
                    saveCareerArchetypes()
                }
            }
        } catch {
            await MainActor.run {
                isParsing = false
                print("❌ Error parsing resume: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Update Functions
    private func updateLanguages(_ newLanguages: [Language]) {
        guard var currentData = parsedResumeData else { return }
        parsedResumeData = ResumeData(
            id: currentData.id,
            name: currentData.name,
            email: currentData.email,
            phone: currentData.phone,
            skills: currentData.skills,
            workExperience: currentData.workExperience,
            education: currentData.education,
            projects: currentData.projects,
            languages: newLanguages.isEmpty ? nil : newLanguages,
            certifications: currentData.certifications,
            awards: currentData.awards,
            resumeUrl: currentData.resumeUrl,
            parsedAt: currentData.parsedAt
        )
        if let updatedData = parsedResumeData {
            saveParsedResumeData(updatedData)
        }
    }
    
    private func updateCertifications(_ newCerts: [Certification]) {
        guard var currentData = parsedResumeData else { return }
        parsedResumeData = ResumeData(
            id: currentData.id,
            name: currentData.name,
            email: currentData.email,
            phone: currentData.phone,
            skills: currentData.skills,
            workExperience: currentData.workExperience,
            education: currentData.education,
            projects: currentData.projects,
            languages: currentData.languages,
            certifications: newCerts.isEmpty ? nil : newCerts,
            awards: currentData.awards,
            resumeUrl: currentData.resumeUrl,
            parsedAt: currentData.parsedAt
        )
        if let updatedData = parsedResumeData {
            saveParsedResumeData(updatedData)
        }
    }
    
    private func updateAwards(_ newAwards: [Award]) {
        guard var currentData = parsedResumeData else { return }
        parsedResumeData = ResumeData(
            id: currentData.id,
            name: currentData.name,
            email: currentData.email,
            phone: currentData.phone,
            skills: currentData.skills,
            workExperience: currentData.workExperience,
            education: currentData.education,
            projects: currentData.projects,
            languages: currentData.languages,
            certifications: currentData.certifications,
            awards: newAwards.isEmpty ? nil : newAwards,
            resumeUrl: currentData.resumeUrl,
            parsedAt: currentData.parsedAt
        )
        if let updatedData = parsedResumeData {
            saveParsedResumeData(updatedData)
        }
    }
    
    private func updateEducation(_ newEducation: [Education]) {
        guard var currentData = parsedResumeData else { return }
        parsedResumeData = ResumeData(
            id: currentData.id,
            name: currentData.name,
            email: currentData.email,
            phone: currentData.phone,
            skills: currentData.skills,
            workExperience: currentData.workExperience,
            education: newEducation.isEmpty ? nil : newEducation,
            projects: currentData.projects,
            languages: currentData.languages,
            certifications: currentData.certifications,
            awards: currentData.awards,
            resumeUrl: currentData.resumeUrl,
            parsedAt: currentData.parsedAt
        )
        if let updatedData = parsedResumeData {
            saveParsedResumeData(updatedData)
        }
    }
    
    private func updateWorkExperience(_ newExperience: [WorkExperience]) {
        guard var currentData = parsedResumeData else { return }
        parsedResumeData = ResumeData(
            id: currentData.id,
            name: currentData.name,
            email: currentData.email,
            phone: currentData.phone,
            skills: currentData.skills,
            workExperience: newExperience.isEmpty ? nil : newExperience,
            education: currentData.education,
            projects: currentData.projects,
            languages: currentData.languages,
            certifications: currentData.certifications,
            awards: currentData.awards,
            resumeUrl: currentData.resumeUrl,
            parsedAt: currentData.parsedAt
        )
        if let updatedData = parsedResumeData {
            saveParsedResumeData(updatedData)
        }
    }
    
    private func updateProjects(_ newProjects: [Project]) {
        guard var currentData = parsedResumeData else { return }
        parsedResumeData = ResumeData(
            id: currentData.id,
            name: currentData.name,
            email: currentData.email,
            phone: currentData.phone,
            skills: currentData.skills,
            workExperience: currentData.workExperience,
            education: currentData.education,
            projects: newProjects.isEmpty ? nil : newProjects,
            languages: currentData.languages,
            certifications: currentData.certifications,
            awards: currentData.awards,
            resumeUrl: currentData.resumeUrl,
            parsedAt: currentData.parsedAt
        )
        if let updatedData = parsedResumeData {
            saveParsedResumeData(updatedData)
        }
    }
    
    private func updateSkills(_ newSkills: [String]) {
        guard var currentData = parsedResumeData else { return }
        parsedResumeData = ResumeData(
            id: currentData.id,
            name: currentData.name,
            email: currentData.email,
            phone: currentData.phone,
            skills: newSkills.isEmpty ? nil : newSkills,
            workExperience: currentData.workExperience,
            education: currentData.education,
            projects: currentData.projects,
            languages: currentData.languages,
            certifications: currentData.certifications,
            awards: currentData.awards,
            resumeUrl: currentData.resumeUrl,
            parsedAt: currentData.parsedAt
        )
        if let updatedData = parsedResumeData {
            saveParsedResumeData(updatedData)
        }
    }
    
    // MARK: - Persistence Functions
    private func saveResumeFile() {
        guard let file = selectedFile else { return }
        
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Determine file extension
        let fileExtension = file.pathExtension.isEmpty ? "pdf" : file.pathExtension
        let savedResumeURL = documentsPath.appendingPathComponent("saved_resume.\(fileExtension)")
        
        // Check if file is already in the document directory with the saved name
        if file.path == savedResumeURL.path {
            // File is already saved, just update the stored path
            UserDefaults.standard.set(fileName, forKey: "savedResumeFileName")
            UserDefaults.standard.set(savedResumeURL.path, forKey: "savedResumeFilePath")
            print("✅ Resume file already saved")
            return
        }
        
        do {
            // Remove old saved resume if it exists
            if fileManager.fileExists(atPath: savedResumeURL.path) {
                try fileManager.removeItem(at: savedResumeURL)
            }
            
            // Ensure we have access to the source file
            let accessing = file.startAccessingSecurityScopedResource()
            defer {
                if accessing {
                    file.stopAccessingSecurityScopedResource()
                }
            }
            
            // Copy current file to saved location
            try fileManager.copyItem(at: file, to: savedResumeURL)
            
            // Update selectedFile to point to saved location
            selectedFile = savedResumeURL
            
            // Save file name
            UserDefaults.standard.set(fileName, forKey: "savedResumeFileName")
            UserDefaults.standard.set(savedResumeURL.path, forKey: "savedResumeFilePath")
            
            print("✅ Resume file saved to: \(savedResumeURL.path)")
        } catch {
            print("❌ Error saving resume file: \(error.localizedDescription)")
        }
    }
    
    private func saveParsedResumeData(_ resumeData: ResumeData) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(resumeData)
            UserDefaults.standard.set(data, forKey: "savedParsedResumeData")
            print("✅ Parsed resume data saved")
        } catch {
            print("❌ Error saving parsed resume data: \(error.localizedDescription)")
        }
    }
    
    private func loadSavedResume() {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Load saved file path
        if let savedFilePath = UserDefaults.standard.string(forKey: "savedResumeFilePath"),
           fileManager.fileExists(atPath: savedFilePath) {
            let savedFileURL = URL(fileURLWithPath: savedFilePath)
            selectedFile = savedFileURL
            
            // Load saved file name
            if let savedFileName = UserDefaults.standard.string(forKey: "savedResumeFileName") {
                fileName = savedFileName
            } else {
                fileName = savedFileURL.lastPathComponent
            }
            
            print("✅ Loaded saved resume file: \(fileName)")
        }
        
        // Load saved parsed resume data
        if let data = UserDefaults.standard.data(forKey: "savedParsedResumeData") {
            do {
                let decoder = JSONDecoder()
                let resumeData = try decoder.decode(ResumeData.self, from: data)
                parsedResumeData = resumeData
                // Load saved career archetypes (user's custom selections)
                loadCareerArchetypes()
                // If no saved archetypes, detect them from resume data
                if careerArchetypes.isEmpty {
                    careerArchetypes = detectCareerArchetypes(from: resumeData)
                    saveCareerArchetypes()
                }
                print("✅ Loaded saved parsed resume data")
            } catch {
                print("❌ Error loading parsed resume data: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Career Archetype Detection
    private func detectCareerArchetypes(from resumeData: ResumeData) -> [String] {
        var archetypes: Set<String> = []
        var allText = ""
        
        // Collect all text from resume for analysis
        var skillsText = ""
        if let skills = resumeData.skills {
            skillsText = skills.joined(separator: " ").lowercased()
            allText += skillsText + " "
        }
        
        // Analyze work experience
        if let workExp = resumeData.workExperience {
            for exp in workExp {
                let title = exp.title.lowercased()
                let company = exp.company.lowercased()
                let description = (exp.description ?? "").lowercased()
                allText += title + " " + company + " " + description + " "
            }
        }
        
        // Analyze education
        if let education = resumeData.education {
            for edu in education {
                let degree = edu.degree.lowercased()
                let school = edu.school.lowercased()
                allText += degree + " " + school + " "
            }
        }
        
        // Analyze projects
        if let projects = resumeData.projects {
            for project in projects {
                let name = project.name.lowercased()
                let description = (project.description ?? "").lowercased()
                let technologies = (project.technologies ?? "").lowercased()
                allText += name + " " + description + " " + technologies + " "
            }
        }
        
        allText = allText.lowercased()
        
        // Software Engineer detection
        let softwareKeywords = ["software", "developer", "programming", "code", "python", "javascript", "java", "react", "node", "api", "backend", "frontend", "full stack", "web development", "mobile app", "ios", "android", "swift", "kotlin", "git", "github", "agile", "scrum", "software engineer", "software developer", "programmer", "coding", "algorithm", "data structure", "database", "sql", "nosql", "docker", "kubernetes", "aws", "cloud", "devops"]
        let softwareScore = softwareKeywords.reduce(0) { score, keyword in
            score + (allText.contains(keyword) ? 1 : 0)
        }
        if softwareScore >= 3 {
            archetypes.insert("Software Engineer")
        }
        
        // Data Analyst detection
        let dataAnalystKeywords = ["data analyst", "data analysis", "data science", "analytics", "sql", "excel", "tableau", "power bi", "python", "r", "statistics", "statistical", "data visualization", "dashboard", "reporting", "business intelligence", "bi", "etl", "data mining", "machine learning", "ml", "data modeling", "regression", "forecasting", "data warehouse", "big data", "hadoop", "spark"]
        let dataAnalystScore = dataAnalystKeywords.reduce(0) { score, keyword in
            score + (allText.contains(keyword) ? 1 : 0)
        }
        if dataAnalystScore >= 3 {
            archetypes.insert("Data Analyst")
        }
        
        // Product Manager detection
        let productManagerKeywords = ["product manager", "product management", "product strategy", "roadmap", "agile", "scrum", "kanban", "user story", "requirements", "stakeholder", "cross-functional", "go-to-market", "gtm", "launch", "feature", "prioritization", "user experience", "ux", "user research", "market research", "competitive analysis", "kpi", "metrics", "analytics", "a/b testing", "mvp", "minimum viable product"]
        let productManagerScore = productManagerKeywords.reduce(0) { score, keyword in
            score + (allText.contains(keyword) ? 1 : 0)
        }
        if productManagerScore >= 3 {
            archetypes.insert("Product Manager")
        }
        
        // Marketing Associate detection
        let marketingKeywords = ["marketing", "digital marketing", "social media", "content marketing", "seo", "sem", "ppc", "google ads", "facebook ads", "email marketing", "campaign", "brand", "branding", "public relations", "pr", "event", "trade show", "market research", "customer acquisition", "lead generation", "conversion", "roi", "analytics", "google analytics", "advertising", "copywriting", "creative", "graphic design", "canva", "adobe"]
        let marketingScore = marketingKeywords.reduce(0) { score, keyword in
            score + (allText.contains(keyword) ? 1 : 0)
        }
        if marketingScore >= 3 {
            archetypes.insert("Marketing Associate")
        }
        
        // Finance Analyst detection
        let financeKeywords = ["finance", "financial", "accounting", "cpa", "cfa", "financial analysis", "financial modeling", "valuation", "budget", "forecasting", "p&l", "profit and loss", "balance sheet", "cash flow", "financial reporting", "gaap", "ifrs", "audit", "tax", "taxation", "investment", "portfolio", "risk management", "compliance", "sox", "sarbanes-oxley", "excel", "financial statement", "revenue", "expense", "cost", "margin", "ebitda"]
        let financeScore = financeKeywords.reduce(0) { score, keyword in
            score + (allText.contains(keyword) ? 1 : 0)
        }
        if financeScore >= 3 {
            archetypes.insert("Finance Analyst")
        }
        
        return Array(archetypes).sorted()
    }
    
    // MARK: - Save Career Archetypes
    private func saveCareerArchetypes() {
        // Save career archetypes to UserDefaults
        if let data = try? JSONEncoder().encode(careerArchetypes) {
            UserDefaults.standard.set(data, forKey: "savedCareerArchetypes")
        }
    }
    
    private func loadCareerArchetypes() {
        // Load saved career archetypes from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "savedCareerArchetypes"),
           let savedArchetypes = try? JSONDecoder().decode([String].self, from: data) {
            careerArchetypes = savedArchetypes
        }
    }
    
    private func clearSavedResume() {
        // Clear state
        selectedFile = nil
        fileName = ""
        cachedFileSize = nil
        shouldLoadPDFPreview = false
        parsedResumeData = nil
        
        // Clear saved file
        if let savedFilePath = UserDefaults.standard.string(forKey: "savedResumeFilePath") {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: savedFilePath) {
                try? fileManager.removeItem(atPath: savedFilePath)
            }
        }
        
        // Clear UserDefaults
        UserDefaults.standard.removeObject(forKey: "savedResumeFileName")
        UserDefaults.standard.removeObject(forKey: "savedResumeFilePath")
        UserDefaults.standard.removeObject(forKey: "savedParsedResumeData")
        
        print("✅ Cleared saved resume data")
    }
}

#Preview {
    ProfileView()
}


//
//  ResumeReviewView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct ResumeReviewView: View {
    @Binding var resumeData: ResumeData
    @Environment(\.dismiss) var dismiss
    
    @State private var editedName: String
    @State private var editedEmail: String
    @State private var editedPhone: String
    @State private var editedSkills: [String]
    @State private var editedWorkExperience: [WorkExperience]
    @State private var editedEducation: [Education]
    @State private var editedProjects: [Project]
    @State private var editedLanguages: [Language]
    @State private var editedCertifications: [Certification]
    @State private var editedAwards: [Award]
    
    @State private var showingAddSkill = false
    @State private var showingAddEducation = false
    @State private var showingAddExperience = false
    @State private var showingAddProject = false
    @State private var showingAddLanguage = false
    @State private var showingAddCertification = false
    @State private var showingAddAward = false
    @State private var newSkill = ""
    @State private var editingIndex: Int?
    @State private var editingSection: EditingSection?
    
    init(resumeData: Binding<ResumeData>) {
        self._resumeData = resumeData
        _editedName = State(initialValue: resumeData.wrappedValue.name ?? "")
        _editedEmail = State(initialValue: resumeData.wrappedValue.email ?? "")
        _editedPhone = State(initialValue: resumeData.wrappedValue.phone ?? "")
        _editedSkills = State(initialValue: resumeData.wrappedValue.skills ?? [])
        _editedWorkExperience = State(initialValue: resumeData.wrappedValue.workExperience ?? [])
        _editedEducation = State(initialValue: resumeData.wrappedValue.education ?? [])
        _editedProjects = State(initialValue: resumeData.wrappedValue.projects ?? [])
        _editedLanguages = State(initialValue: resumeData.wrappedValue.languages ?? [])
        _editedCertifications = State(initialValue: resumeData.wrappedValue.certifications ?? [])
        _editedAwards = State(initialValue: resumeData.wrappedValue.awards ?? [])
    }
    
    enum EditingSection {
        case workExperience(Int)
        case education(Int)
        case project(Int)
        case language(Int)
        case certification(Int)
        case award(Int)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Review Your Resume")
                            .font(.system(size: 24, weight: .bold))
                        Text("Tap any field to edit")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top)
                    
                    // Personal Information
                    EditableBubbleSection(title: "Name", icon: "person.fill", color: .blue) {
                        EditableBubble(text: $editedName, color: .blue, keyboardType: .default)
                    }
                    
                    EditableBubbleSection(title: "Email", icon: "envelope.fill", color: .green) {
                        EditableBubble(text: $editedEmail, color: .green, keyboardType: .emailAddress)
                    }
                    
                    EditableBubbleSection(title: "Phone", icon: "phone.fill", color: .orange) {
                        EditableBubble(text: $editedPhone, color: .orange, keyboardType: .phonePad)
                    }
                    
                    // Skills
                    EditableBubbleSection(title: "Skills", icon: "star.fill", color: .red, onAdd: {
                        showingAddSkill = true
                    }) {
                        FlowLayout(spacing: 8) {
                            ForEach(Array(editedSkills.enumerated()), id: \.offset) { index, skill in
                                EditableBubble(text: Binding(
                                    get: { editedSkills[index] },
                                    set: { editedSkills[index] = $0 }
                                ), color: .red, onDelete: {
                                    editedSkills.remove(at: index)
                                }, keyboardType: .default)
                            }
                        }
                    }
                    
                    // Education
                    EditableBubbleSection(title: "Education", icon: "graduationcap.fill", color: .blue, onAdd: {
                        showingAddEducation = true
                    }) {
                        ForEach(Array(editedEducation.enumerated()), id: \.offset) { index, edu in
                            EditableEducationCard(education: Binding(
                                get: { editedEducation[index] },
                                set: { editedEducation[index] = $0 }
                            ), onDelete: {
                                editedEducation.remove(at: index)
                            })
                        }
                    }
                    
                    // Work Experience
                    EditableBubbleSection(title: "Experiences", icon: "briefcase.fill", color: .green, onAdd: {
                        showingAddExperience = true
                    }) {
                        ForEach(Array(editedWorkExperience.enumerated()), id: \.offset) { index, exp in
                            EditableExperienceCard(experience: Binding(
                                get: { editedWorkExperience[index] },
                                set: { editedWorkExperience[index] = $0 }
                            ), onDelete: {
                                editedWorkExperience.remove(at: index)
                            })
                        }
                    }
                    
                    // Projects
                    EditableBubbleSection(title: "Projects", icon: "folder.fill", color: .purple, onAdd: {
                        showingAddProject = true
                    }) {
                        ForEach(Array(editedProjects.enumerated()), id: \.offset) { index, project in
                            EditableProjectCard(project: Binding(
                                get: { editedProjects[index] },
                                set: { editedProjects[index] = $0 }
                            ), onDelete: {
                                editedProjects.remove(at: index)
                            })
                        }
                    }
                    
                    // Languages
                    EditableBubbleSection(title: "Languages", icon: "globe", color: .orange, onAdd: {
                        showingAddLanguage = true
                    }) {
                        ForEach(Array(editedLanguages.enumerated()), id: \.offset) { index, language in
                            EditableLanguageCard(language: Binding(
                                get: { editedLanguages[index] },
                                set: { editedLanguages[index] = $0 }
                            ), onDelete: {
                                editedLanguages.remove(at: index)
                            })
                        }
                    }
                    
                    // Certifications
                    EditableBubbleSection(title: "Certifications", icon: "checkmark.seal.fill", color: .cyan, onAdd: {
                        showingAddCertification = true
                    }) {
                        ForEach(Array(editedCertifications.enumerated()), id: \.offset) { index, cert in
                            EditableCertificationCard(certification: Binding(
                                get: { editedCertifications[index] },
                                set: { editedCertifications[index] = $0 }
                            ), onDelete: {
                                editedCertifications.remove(at: index)
                            })
                        }
                    }
                    
                    // Awards
                    EditableBubbleSection(title: "Awards", icon: "trophy.fill", color: .yellow, onAdd: {
                        showingAddAward = true
                    }) {
                        ForEach(Array(editedAwards.enumerated()), id: \.offset) { index, award in
                            EditableAwardCard(award: Binding(
                                get: { editedAwards[index] },
                                set: { editedAwards[index] = $0 }
                            ), onDelete: {
                                editedAwards.remove(at: index)
                            })
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 100)
            }
            .navigationTitle("Edit Resume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddSkill) {
                AddSkillView(skills: $editedSkills)
            }
            .sheet(isPresented: $showingAddEducation) {
                AddEducationView(education: $editedEducation)
            }
            .sheet(isPresented: $showingAddExperience) {
                AddExperienceView(experience: $editedWorkExperience)
            }
            .sheet(isPresented: $showingAddProject) {
                AddProjectView(projects: $editedProjects)
            }
            .sheet(isPresented: $showingAddLanguage) {
                AddLanguageView(languages: $editedLanguages)
            }
            .sheet(isPresented: $showingAddCertification) {
                AddCertificationView(certifications: $editedCertifications)
            }
            .sheet(isPresented: $showingAddAward) {
                AddAwardView(awards: $editedAwards)
            }
        }
    }
    
    private func saveChanges() {
        resumeData = ResumeData(
            id: resumeData.id,
            name: editedName.isEmpty ? nil : editedName,
            email: editedEmail.isEmpty ? nil : editedEmail,
            phone: editedPhone.isEmpty ? nil : editedPhone,
            skills: editedSkills.isEmpty ? nil : editedSkills,
            workExperience: editedWorkExperience.isEmpty ? nil : editedWorkExperience,
            education: editedEducation.isEmpty ? nil : editedEducation,
            projects: editedProjects.isEmpty ? nil : editedProjects,
            languages: editedLanguages.isEmpty ? nil : editedLanguages,
            certifications: editedCertifications.isEmpty ? nil : editedCertifications,
            awards: editedAwards.isEmpty ? nil : editedAwards,
            resumeUrl: resumeData.resumeUrl,
            parsedAt: resumeData.parsedAt
        )
    }
}

struct EditableBubbleSection<Content: View>: View {
    let title: String
    let icon: String
    let color: Color
    let onAdd: (() -> Void)?
    let content: Content
    
    init(title: String, icon: String, color: Color, onAdd: (() -> Void)? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.color = color
        self.onAdd = onAdd
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
                Spacer()
                if let onAdd = onAdd {
                    Button(action: onAdd) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(color)
                            .font(.title3)
                    }
                }
            }
            
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

struct EditableBubble: View {
    @Binding var text: String
    let color: Color
    var onDelete: (() -> Void)? = nil
    var keyboardType: UIKeyboardType = .default
    
    @State private var showingEditSheet = false
    
    var body: some View {
        HStack(spacing: 6) {
            Text(text.isEmpty ? "Tap to add" : text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(text.isEmpty ? .secondary : .black)
            
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray5))
        .cornerRadius(8)
        .onTapGesture {
            showingEditSheet = true
        }
        .sheet(isPresented: $showingEditSheet) {
            EditTextFieldView(title: "Edit", text: $text, onSave: {
                // Text is already bound, will update automatically
            }, keyboardType: keyboardType)
        }
    }
}

struct EditableEducationCard: View {
    @Binding var education: Education
    let onDelete: () -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(education.degree)
                        .font(.system(size: 16, weight: .semibold))
                    Text(education.school)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    if let year = education.year {
                        Text(year)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditEducationView(education: $education)
        }
    }
}

struct EditableExperienceCard: View {
    @Binding var experience: WorkExperience
    let onDelete: () -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(experience.title)
                        .font(.system(size: 16, weight: .semibold))
                    Text(experience.company)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    if let duration = experience.duration {
                        Text(duration)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditExperienceView(experience: $experience)
        }
    }
}

struct EditableProjectCard: View {
    @Binding var project: Project
    let onDelete: () -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.system(size: 16, weight: .semibold))
                    if let description = project.description {
                        Text(description)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditProjectView(project: $project)
        }
    }
}

struct EditableLanguageCard: View {
    @Binding var language: Language
    let onDelete: () -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        HStack {
            Text(language.name)
                .font(.system(size: 14, weight: .medium))
            if let proficiency = language.proficiency {
                Text("• \(proficiency)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditLanguageView(language: $language)
        }
    }
}

struct EditableCertificationCard: View {
    @Binding var certification: Certification
    let onDelete: () -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(certification.name)
                        .font(.system(size: 16, weight: .semibold))
                    if let issuer = certification.issuer {
                        Text(issuer)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditCertificationView(certification: $certification)
        }
    }
}

struct EditableAwardCard: View {
    @Binding var award: Award
    let onDelete: () -> Void
    
    @State private var showingEdit = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(award.title)
                        .font(.system(size: 16, weight: .semibold))
                    if let issuer = award.issuer {
                        Text(issuer)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .onTapGesture {
            showingEdit = true
        }
        .sheet(isPresented: $showingEdit) {
            EditAwardView(award: $award)
        }
    }
}

// MARK: - Edit Views
struct EditTextFieldView: View {
    let title: String
    @Binding var text: String
    let onSave: () -> Void
    var keyboardType: UIKeyboardType = .default
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField(title, text: $text)
                    .keyboardType(keyboardType)
            }
            .navigationTitle("Edit \(title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct AddSkillView: View {
    @Binding var skills: [String]
    @State private var newSkill = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Skill name", text: $newSkill)
            }
            .navigationTitle("Add Skill")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !newSkill.isEmpty {
                            skills.append(newSkill)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(newSkill.isEmpty)
                }
            }
        }
    }
}

struct AddEducationView: View {
    @Binding var education: [Education]
    @State private var degree = ""
    @State private var school = ""
    @State private var year = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Degree", text: $degree)
                TextField("School", text: $school)
                TextField("Year", text: $year)
            }
            .navigationTitle("Add Education")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !degree.isEmpty && !school.isEmpty {
                            education.append(Education(degree: degree, school: school, year: year.isEmpty ? nil : year))
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(degree.isEmpty || school.isEmpty)
                }
            }
        }
    }
}

struct AddExperienceView: View {
    @Binding var experience: [WorkExperience]
    @State private var title = ""
    @State private var company = ""
    @State private var duration = ""
    @State private var description = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Job Title", text: $title)
                TextField("Company", text: $company)
                TextField("Duration", text: $duration)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Add Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !title.isEmpty && !company.isEmpty {
                            experience.append(WorkExperience(
                                title: title,
                                company: company,
                                duration: duration.isEmpty ? nil : duration,
                                description: description.isEmpty ? nil : description
                            ))
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty || company.isEmpty)
                }
            }
        }
    }
}

struct AddProjectView: View {
    @Binding var projects: [Project]
    @State private var name = ""
    @State private var description = ""
    @State private var technologies = ""
    @State private var url = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Project Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Technologies", text: $technologies)
                TextField("URL", text: $url)
            }
            .navigationTitle("Add Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !name.isEmpty {
                            projects.append(Project(
                                name: name,
                                description: description.isEmpty ? nil : description,
                                technologies: technologies.isEmpty ? nil : technologies,
                                url: url.isEmpty ? nil : url
                            ))
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct AddLanguageView: View {
    @Binding var languages: [Language]
    @State private var name = ""
    @State private var selectedProficiency: ProficiencyOption = .none
    @Environment(\.dismiss) var dismiss
    
    enum ProficiencyOption: String, CaseIterable {
        case none = "None"
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case expert = "Expert"
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Language", text: $name)
                Picker("Proficiency", selection: $selectedProficiency) {
                    ForEach(ProficiencyOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            }
            .navigationTitle("Add Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !name.isEmpty {
                            let proficiency = selectedProficiency == .none ? nil : selectedProficiency.rawValue
                            languages.append(Language(name: name, proficiency: proficiency))
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct AddCertificationView: View {
    @Binding var certifications: [Certification]
    @State private var name = ""
    @State private var issuer = ""
    @State private var date = ""
    @State private var expiryDate = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Certification Name", text: $name)
                TextField("Issuer", text: $issuer)
                TextField("Date", text: $date)
                TextField("Expiry Date", text: $expiryDate)
            }
            .navigationTitle("Add Certification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !name.isEmpty {
                            certifications.append(Certification(
                                name: name,
                                issuer: issuer.isEmpty ? nil : issuer,
                                date: date.isEmpty ? nil : date,
                                expiryDate: expiryDate.isEmpty ? nil : expiryDate
                            ))
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

struct AddAwardView: View {
    @Binding var awards: [Award]
    @State private var title = ""
    @State private var issuer = ""
    @State private var date = ""
    @State private var description = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Award Title", text: $title)
                TextField("Issuer", text: $issuer)
                TextField("Date", text: $date)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Add Award")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        if !title.isEmpty {
                            awards.append(Award(
                                title: title,
                                issuer: issuer.isEmpty ? nil : issuer,
                                date: date.isEmpty ? nil : date,
                                description: description.isEmpty ? nil : description
                            ))
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}

struct EditEducationView: View {
    @Binding var education: Education
    @State private var degree: String
    @State private var school: String
    @State private var year: String
    @Environment(\.dismiss) var dismiss
    
    init(education: Binding<Education>) {
        self._education = education
        _degree = State(initialValue: education.wrappedValue.degree)
        _school = State(initialValue: education.wrappedValue.school)
        _year = State(initialValue: education.wrappedValue.year ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Degree", text: $degree)
                TextField("School", text: $school)
                TextField("Year", text: $year)
            }
            .navigationTitle("Edit Education")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        education = Education(degree: degree, school: school, year: year.isEmpty ? nil : year)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct EditExperienceView: View {
    @Binding var experience: WorkExperience
    @State private var title: String
    @State private var company: String
    @State private var duration: String
    @State private var description: String
    @Environment(\.dismiss) var dismiss
    
    init(experience: Binding<WorkExperience>) {
        self._experience = experience
        _title = State(initialValue: experience.wrappedValue.title)
        _company = State(initialValue: experience.wrappedValue.company)
        _duration = State(initialValue: experience.wrappedValue.duration ?? "")
        _description = State(initialValue: experience.wrappedValue.description ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Job Title", text: $title)
                TextField("Company", text: $company)
                TextField("Duration", text: $duration)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
            }
            .navigationTitle("Edit Experience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        experience = WorkExperience(
                            title: title,
                            company: company,
                            duration: duration.isEmpty ? nil : duration,
                            description: description.isEmpty ? nil : description
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct EditProjectView: View {
    @Binding var project: Project
    @State private var name: String
    @State private var description: String
    @State private var technologies: String
    @State private var url: String
    @Environment(\.dismiss) var dismiss
    
    init(project: Binding<Project>) {
        self._project = project
        _name = State(initialValue: project.wrappedValue.name)
        _description = State(initialValue: project.wrappedValue.description ?? "")
        _technologies = State(initialValue: project.wrappedValue.technologies ?? "")
        _url = State(initialValue: project.wrappedValue.url ?? "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Project Name", text: $name)
                TextField("Description", text: $description, axis: .vertical)
                    .lineLimit(3...6)
                TextField("Technologies", text: $technologies)
                TextField("URL", text: $url)
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        project = Project(
                            name: name,
                            description: description.isEmpty ? nil : description,
                            technologies: technologies.isEmpty ? nil : technologies,
                            url: url.isEmpty ? nil : url
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct EditLanguageView: View {
    @Binding var language: Language
    @State private var name: String
    @State private var selectedProficiency: ProficiencyOption
    @Environment(\.dismiss) var dismiss
    
    enum ProficiencyOption: String, CaseIterable {
        case none = "None"
        case beginner = "Beginner"
        case intermediate = "Intermediate"
        case expert = "Expert"
    }
    
    init(language: Binding<Language>) {
        self._language = language
        _name = State(initialValue: language.wrappedValue.name)
        let proficiencyValue = language.wrappedValue.proficiency ?? ""
        _selectedProficiency = State(initialValue: ProficiencyOption(rawValue: proficiencyValue) ?? .none)
    }
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Language", text: $name)
                Picker("Proficiency", selection: $selectedProficiency) {
                    ForEach(ProficiencyOption.allCases, id: \.self) { option in
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
                        language = Language(name: name, proficiency: proficiency)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct EditCertificationView: View {
    @Binding var certification: Certification
    @State private var name: String
    @State private var issuer: String
    @State private var date: String
    @State private var expiryDate: String
    @Environment(\.dismiss) var dismiss
    
    init(certification: Binding<Certification>) {
        self._certification = certification
        _name = State(initialValue: certification.wrappedValue.name)
        _issuer = State(initialValue: certification.wrappedValue.issuer ?? "")
        _date = State(initialValue: certification.wrappedValue.date ?? "")
        _expiryDate = State(initialValue: certification.wrappedValue.expiryDate ?? "")
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
                        certification = Certification(
                            name: name,
                            issuer: issuer.isEmpty ? nil : issuer,
                            date: date.isEmpty ? nil : date,
                            expiryDate: expiryDate.isEmpty ? nil : expiryDate
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

struct EditAwardView: View {
    @Binding var award: Award
    @State private var title: String
    @State private var issuer: String
    @State private var date: String
    @State private var description: String
    @Environment(\.dismiss) var dismiss
    
    init(award: Binding<Award>) {
        self._award = award
        _title = State(initialValue: award.wrappedValue.title)
        _issuer = State(initialValue: award.wrappedValue.issuer ?? "")
        _date = State(initialValue: award.wrappedValue.date ?? "")
        _description = State(initialValue: award.wrappedValue.description ?? "")
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
                        award = Award(
                            title: title,
                            issuer: issuer.isEmpty ? nil : issuer,
                            date: date.isEmpty ? nil : date,
                            description: description.isEmpty ? nil : description
                        )
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ResumeReviewView(resumeData: .constant(ResumeData(
        id: "1",
        name: "John Doe",
        email: "john@example.com",
        phone: "+1 (555) 123-4567",
        skills: ["Swift", "iOS"],
        workExperience: [
            WorkExperience(title: "Engineer", company: "Tech", duration: "2020-2023", description: nil)
        ],
        education: [
            Education(degree: "BS CS", school: "University", year: "2020")
        ],
        projects: nil,
        languages: nil,
        certifications: nil,
        awards: nil,
        resumeUrl: nil,
        parsedAt: "2025-12-17"
    )))
}


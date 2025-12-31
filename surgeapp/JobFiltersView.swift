//
//  JobFiltersView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct JobFiltersView: View {
    @Binding var filters: JobFilters
    @Environment(\.dismiss) var dismiss
    @State private var selectedJobTitles: Set<String> = []
    @State private var selectedLocations: Set<String> = []
    @State private var showingJobTitlePicker = false
    @State private var showingLocationPicker = false
    
    // Load career interests and user location on appear
    private func loadDefaults() {
        // Load career interests as job titles
        if let data = UserDefaults.standard.data(forKey: "savedCareerArchetypes"),
           let careerInterests = try? JSONDecoder().decode([String].self, from: data) {
            selectedJobTitles = Set(careerInterests)
            filters.jobTitles = Set(careerInterests)
        }
        
        // Load user's location as default location
        if let userLocation = UserDefaults.standard.string(forKey: "profile_location"),
           !userLocation.isEmpty {
            selectedLocations.insert(userLocation)
            filters.locations.insert(userLocation)
            filters.location = userLocation
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Job Titles Section
                    FilterSection(
                        title: "Job Titles",
                        count: selectedJobTitles.count,
                        showInfo: true
                    ) {
                        if selectedJobTitles.isEmpty {
                            Button(action: {
                                showingJobTitlePicker = true
                            }) {
                                Text("Add Job Titles")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                // Show first 2 titles, then "+ X more"
                                let titlesArray = Array(selectedJobTitles)
                                ForEach(Array(titlesArray.prefix(2)), id: \.self) { title in
                                    HStack {
                                        Text(title)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Button(action: {
                                            selectedJobTitles.remove(title)
                                            filters.jobTitles.remove(title)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: 16))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                                
                                if selectedJobTitles.count > 2 {
                                    Text("+ \(selectedJobTitles.count - 2) more")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                
                                Button(action: {
                                    showingJobTitlePicker = true
                                }) {
                                    Text("+ Add More")
                                        .font(.system(size: 14))
                                        .foregroundColor(.blue)
                                }
                                .padding(.top, 4)
                            }
                        }
                    }
                    
                    // Locations Section
                    FilterSection(
                        title: "Locations",
                        count: selectedLocations.count,
                        showInfo: true
                    ) {
                        if selectedLocations.isEmpty {
                            Button(action: {
                                showingLocationPicker = true
                            }) {
                                Text("Add Location")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        } else {
                            ForEach(Array(selectedLocations), id: \.self) { location in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(location)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                        Text("50m")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button(action: {
                                        selectedLocations.remove(location)
                                        filters.locations.remove(location)
                                        if filters.location == location {
                                            filters.location = selectedLocations.first ?? ""
                                        }
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 16))
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Button(action: {
                                showingLocationPicker = true
                            }) {
                                Text("+ Add More")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // Premium Filters Section
                    FilterSection(
                        title: "Premium Filters",
                        count: nil,
                        showInfo: false,
                        titleColor: .green
                    ) {
                        PillButton(
                            text: "New",
                            isSelected: false,
                            color: .blue
                        ) {
                            // Premium filter action
                        }
                    }
                    
                    // Work Arrangements Section
                    FilterSection(
                        title: "Work arrangements",
                        count: nil,
                        showInfo: false
                    ) {
                        HStack(spacing: 8) {
                            PillButton(
                                text: "Remote",
                                isSelected: filters.locationTypes.contains(.remote),
                                color: .blue
                            ) {
                                if filters.locationTypes.contains(.remote) {
                                    filters.locationTypes.remove(.remote)
                                } else {
                                    filters.locationTypes.insert(.remote)
                                }
                            }
                            
                            PillButton(
                                text: "Hybrid",
                                isSelected: filters.locationTypes.contains(.hybrid),
                                color: .blue
                            ) {
                                if filters.locationTypes.contains(.hybrid) {
                                    filters.locationTypes.remove(.hybrid)
                                } else {
                                    filters.locationTypes.insert(.hybrid)
                                }
                            }
                            
                            PillButton(
                                text: "In Person",
                                isSelected: filters.locationTypes.contains(.onSite),
                                color: .blue
                            ) {
                                if filters.locationTypes.contains(.onSite) {
                                    filters.locationTypes.remove(.onSite)
                                } else {
                                    filters.locationTypes.insert(.onSite)
                                }
                            }
                        }
                    }
                    
                    // Job Types Section
                    FilterSection(
                        title: "Job Types",
                        count: nil,
                        showInfo: false
                    ) {
                        FlowLayout(spacing: 8) {
                            ForEach(JobType.allCases, id: \.self) { type in
                                PillButton(
                                    text: type.rawValue,
                                    isSelected: filters.jobTypes.contains(type),
                                    color: .blue
                                ) {
                                    if filters.jobTypes.contains(type) {
                                        filters.jobTypes.remove(type)
                                    } else {
                                        filters.jobTypes.insert(type)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Job Levels Section
                    FilterSection(
                        title: "Job Levels",
                        count: nil,
                        showInfo: false
                    ) {
                        FlowLayout(spacing: 8) {
                            ForEach(ExperienceLevel.allCases, id: \.self) { level in
                                PillButton(
                                    text: level.rawValue,
                                    isSelected: filters.experienceLevels.contains(level),
                                    color: .gray
                                ) {
                                    if filters.experienceLevels.contains(level) {
                                        filters.experienceLevels.remove(level)
                                    } else {
                                        filters.experienceLevels.insert(level)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Job Requirements Section
                    FilterSection(
                        title: "Job Requirements",
                        count: nil,
                        showInfo: false
                    ) {
                        PillButton(
                            text: "Sponsors H1B",
                            isSelected: false,
                            color: .gray
                        ) {
                            // Job requirement action
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Edit Job Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if filters.hasActiveFilters {
                            Button("Clear") {
                                filters = JobFilters()
                                selectedJobTitles.removeAll()
                                selectedLocations.removeAll()
                                // Reload defaults after clearing
                                loadDefaults()
                            }
                            .foregroundColor(.primary)
                        }
                        
                        Button("Apply") {
                            // Sync all state to filters before dismissing
                            filters.jobTitles = selectedJobTitles
                            filters.locations = selectedLocations
                            if let firstLocation = selectedLocations.first {
                                filters.location = firstLocation
                            }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showingJobTitlePicker) {
                JobTitlePickerView(selectedTitles: $selectedJobTitles, filters: $filters)
            }
            .sheet(isPresented: $showingLocationPicker) {
                LocationPickerView(selectedLocations: $selectedLocations, filters: $filters)
            }
            .onAppear {
                loadDefaults()
            }
        }
    }
}

// MARK: - Filter Section Header
struct FilterSection<Content: View>: View {
    let title: String
    let count: Int?
    let showInfo: Bool
    var titleColor: Color = .primary
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(titleColor)
                
                if let count = count {
                    Text("(\(count))")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                if showInfo {
                    Button(action: {
                        // Show info
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            
            content
        }
    }
}

// MARK: - Pill Button
struct PillButton: View {
    let text: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isSelected ? Color(.systemGray5) : Color(.systemGray6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Job Title Picker View
struct JobTitlePickerView: View {
    @Binding var selectedTitles: Set<String>
    @Binding var filters: JobFilters
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    // Load career interests as default options, plus common job titles
    private var availableTitles: [String] {
        var titles: [String] = []
        
        // First, add career interests from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "savedCareerArchetypes"),
           let careerInterests = try? JSONDecoder().decode([String].self, from: data) {
            titles.append(contentsOf: careerInterests)
        }
        
        // Add common job titles (excluding ones already in career interests)
        let commonTitles = [
            "Software Engineer", "Data Analyst", "Product Manager", "Marketing Associate",
            "Finance Analyst", "Mechanical Engineer", "Mechatronics Engineer", "Mechanical Engineering",
            "UX Designer", "Product Designer", "Sales Manager", "Business Analyst",
            "Software Developer", "Full Stack Developer", "Frontend Developer", "Backend Developer",
            "Data Scientist", "Machine Learning Engineer", "DevOps Engineer", "QA Engineer"
        ]
        
        for title in commonTitles {
            if !titles.contains(title) {
                titles.append(title)
            }
        }
        
        return titles
    }
    
    var filteredTitles: [String] {
        if searchText.isEmpty {
            return availableTitles
        }
        return availableTitles.filter { $0.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                TextField("Search job titles", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                List {
                    ForEach(filteredTitles, id: \.self) { title in
                        HStack {
                            Text(title)
                            Spacer()
                            if selectedTitles.contains(title) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedTitles.contains(title) {
                                selectedTitles.remove(title)
                                filters.jobTitles.remove(title)
                            } else {
                                selectedTitles.insert(title)
                                filters.jobTitles.insert(title)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Job Titles")
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

// MARK: - Location Picker View
struct LocationPickerView: View {
    @Binding var selectedLocations: Set<String>
    @Binding var filters: JobFilters
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    @State private var radius: Int = 50
    
    // Get available locations - user's location first, then common locations
    private var availableLocations: [String] {
        var locations: [String] = []
        
        // Add user's location first if available
        if let userLocation = UserDefaults.standard.string(forKey: "profile_location"),
           !userLocation.isEmpty {
            locations.append(userLocation)
        }
        
        // Add common locations (excluding user's location if already added)
        let commonLocations = [
            "San Francisco, California, United States",
            "New York, New York, United States",
            "Austin, Texas, United States",
            "Seattle, Washington, United States",
            "Boston, Massachusetts, United States",
            "Chicago, Illinois, United States",
            "Los Angeles, California, United States",
            "Duluth, Georgia, United States"
        ]
        
        for location in commonLocations {
            if !locations.contains(location) {
                locations.append(location)
            }
        }
        
        return locations
    }
    
    var filteredLocations: [String] {
        if searchText.isEmpty {
            return availableLocations
        }
        return availableLocations.filter { $0.lowercased().contains(searchText.lowercased()) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Search locations", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                
                HStack {
                    Text("Radius: \(radius) miles")
                    Slider(value: Binding(
                        get: { Double(radius) },
                        set: { radius = Int($0) }
                    ), in: 10...100, step: 10)
                }
                .padding(.horizontal)
                
                List {
                    ForEach(filteredLocations, id: \.self) { location in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(location)
                                Text("\(radius)m")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if selectedLocations.contains(location) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedLocations.contains(location) {
                                selectedLocations.remove(location)
                                filters.locations.remove(location)
                            } else {
                                selectedLocations.insert(location)
                                filters.locations.insert(location)
                                // Update filters.location to the first selected location
                                if filters.location.isEmpty {
                                    filters.location = location
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Locations")
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

// MARK: - Job Filters Model
struct JobFilters {
    var jobTitles: Set<String> = [] // Career interests / job titles
    var jobTypes: Set<JobType> = []
    var locationTypes: Set<LocationType> = []
    var locations: Set<String> = [] // Selected locations
    var location: String = "" // Primary location for filtering
    var minSalary: Int? = nil
    var maxSalary: Int? = nil
    var experienceLevels: Set<ExperienceLevel> = []
    var datePosted: DatePostedFilter? = nil
    var companySizes: Set<CompanySize> = []
    
    var hasActiveFilters: Bool {
        !jobTitles.isEmpty ||
        !jobTypes.isEmpty ||
        !locationTypes.isEmpty ||
        !locations.isEmpty ||
        !location.isEmpty ||
        minSalary != nil ||
        maxSalary != nil ||
        !experienceLevels.isEmpty ||
        datePosted != nil ||
        !companySizes.isEmpty
    }
    
    func apply(to jobs: [JobPost]) -> [JobPost] {
        var filtered = jobs
        
        // Filter by job titles (career interests)
        if !jobTitles.isEmpty {
            filtered = filtered.filter { job in
                let jobText = "\(job.title) \(job.description ?? "")".lowercased()
                return jobTitles.contains { title in
                    let titleLower = title.lowercased()
                    return jobText.contains(titleLower) || 
                           job.title.lowercased().contains(titleLower)
                }
            }
        }
        
        // Filter by job type
        if !jobTypes.isEmpty {
            filtered = filtered.filter { job in
                        let titleLower = job.title.lowercased()
                let descriptionLower = (job.description ?? "").lowercased()
                let combinedText = "\(titleLower) \(descriptionLower)"
                
                // Check if job type is specified
                if let jobType = job.jobType {
                    let jobTypeLower = jobType.lowercased()
                    return jobTypes.contains { type in
                        let typeLower = type.rawValue.lowercased()
                        // Direct match
                        if jobTypeLower.contains(typeLower) || typeLower.contains(jobTypeLower) {
                            return true
                        }
                        // Special handling for internship
                        if type == .internship {
                            return jobTypeLower.contains("intern") || 
                                   titleLower.contains("intern") ||
                                   titleLower.contains("internship")
                    }
                    return false
                }
                } else {
                    // If job type is not specified, check title and description for keywords
                return jobTypes.contains { type in
                        switch type {
                        case .internship:
                            return titleLower.contains("intern") || 
                                   titleLower.contains("internship") ||
                                   combinedText.contains("intern") ||
                                   combinedText.contains("internship")
                        case .fullTime:
                            return titleLower.contains("full") && titleLower.contains("time") ||
                                   combinedText.contains("full-time") ||
                                   combinedText.contains("full time")
                        case .partTime:
                            return titleLower.contains("part") && titleLower.contains("time") ||
                                   combinedText.contains("part-time") ||
                                   combinedText.contains("part time")
                        case .contract:
                            return titleLower.contains("contract") ||
                                   combinedText.contains("contract")
                        case .temporary:
                            return titleLower.contains("temporary") ||
                                   titleLower.contains("temp") ||
                                   combinedText.contains("temporary") ||
                                   combinedText.contains("temp")
                        }
                    }
                }
            }
        }
        
        // Filter by location type
        if !locationTypes.isEmpty {
            filtered = filtered.filter { job in
                let locationLower = job.location.lowercased()
                return locationTypes.contains { type in
                    switch type {
                    case .remote:
                        return locationLower.contains("remote") || locationLower.contains("anywhere")
                    case .onSite:
                        return !locationLower.contains("remote") && !locationLower.contains("anywhere")
                    case .hybrid:
                        return locationLower.contains("hybrid")
                    }
                }
            }
        }
        
        // Filter by specific locations
        if !locations.isEmpty {
            filtered = filtered.filter { job in
                return locations.contains { selectedLocation in
                    job.location.lowercased().contains(selectedLocation.lowercased()) ||
                    selectedLocation.lowercased().contains(job.location.lowercased())
                }
            }
        } else if !location.isEmpty {
            // Fallback to single location filter
            filtered = filtered.filter { job in
                job.location.lowercased().contains(location.lowercased())
            }
        }
        
        // Filter by salary range (minimum and maximum)
        if minSalary != nil || maxSalary != nil {
            filtered = filtered.filter { job in
                guard let salary = job.salary else { return false }
                
                // Extract salary range from string (e.g., "$120,000 - $150,000")
                // Try to extract both min and max, or just a single value
                let salaryLower = salary.lowercased()
                let numbers = salary.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
                
                // Try to parse range (e.g., "120000" and "150000" from "$120,000 - $150,000")
                var minValue: Int?
                var maxValue: Int?
                
                if numbers.count >= 2 {
                    // Has range: use first as min, last as max
                    if let first = Int(numbers[0]), let last = Int(numbers[numbers.count - 1]) {
                        minValue = min(first, last)
                        maxValue = max(first, last)
                    }
                } else if numbers.count == 1 {
                    // Single value: use as both min and max
                    if let value = Int(numbers[0]) {
                        minValue = value
                        maxValue = value
                    }
                }
                
                // Check minimum salary filter
                if let minSalary = minSalary {
                    guard let jobMin = minValue, jobMin >= minSalary else {
                        return false
                    }
                }
                
                // Check maximum salary filter
                if let maxSalary = maxSalary {
                    guard let jobMax = maxValue, jobMax <= maxSalary else {
                        return false
                    }
                }
                
                return true
            }
        }
        
        // Filter by experience level (based on title keywords)
        if !experienceLevels.isEmpty {
            filtered = filtered.filter { job in
                let titleLower = job.title.lowercased()
                return experienceLevels.contains { level in
                    switch level {
                    case .entry:
                        return titleLower.contains("entry") || titleLower.contains("junior") || titleLower.contains("associate")
                    case .mid:
                        return titleLower.contains("mid") || (!titleLower.contains("senior") && !titleLower.contains("entry") && !titleLower.contains("junior"))
                    case .senior:
                        return titleLower.contains("senior") || titleLower.contains("sr.") || titleLower.contains("lead")
                    case .executive:
                        return titleLower.contains("executive") || titleLower.contains("director") || titleLower.contains("vp") || titleLower.contains("chief")
                    }
                }
            }
        }
        
        // Filter by date posted
        if let dateFilter = datePosted {
            let calendar = Calendar.current
            let now = Date()
            let cutoffDate: Date?
            
            switch dateFilter {
            case .last24Hours:
                cutoffDate = calendar.date(byAdding: .hour, value: -24, to: now)
            case .lastWeek:
                cutoffDate = calendar.date(byAdding: .day, value: -7, to: now)
            case .lastMonth:
                cutoffDate = calendar.date(byAdding: .month, value: -1, to: now)
            case .last3Months:
                cutoffDate = calendar.date(byAdding: .month, value: -3, to: now)
            }
            
            if let cutoffDate = cutoffDate {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                
                filtered = filtered.filter { job in
                    if let jobDate = formatter.date(from: job.postedDate) {
                        return jobDate >= cutoffDate
                    }
                    return false
                }
            }
        }
        
        // Filter by company size (this would require additional data, so we'll skip for now)
        // Company size filtering would need company data from an external API
        
        return filtered
    }
}

// MARK: - Filter Enums
enum JobType: String, CaseIterable {
    case fullTime = "Full Time"
    case partTime = "Part Time"
    case contract = "Contract"
    case internship = "Internship"
    case temporary = "Temporary"
}

enum LocationType: String, CaseIterable {
    case remote = "Remote"
    case onSite = "On-site"
    case hybrid = "Hybrid"
}

enum ExperienceLevel: String, CaseIterable {
    case entry = "Entry Level"
    case mid = "Mid Level"
    case senior = "Senior Level"
    case executive = "Executive"
}

enum DatePostedFilter: String, CaseIterable {
    case last24Hours = "Last 24 Hours"
    case lastWeek = "Last Week"
    case lastMonth = "Last Month"
    case last3Months = "Last 3 Months"
}

enum CompanySize: String, CaseIterable {
    case startup = "Startup (1-50)"
    case small = "Small (51-200)"
    case medium = "Medium (201-1000)"
    case large = "Large (1000+)"
}

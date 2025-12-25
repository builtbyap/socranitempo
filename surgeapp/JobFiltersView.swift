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
    
    var body: some View {
        NavigationStack {
            Form {
                // Job Type Section
                Section(header: Text("Job Type")) {
                    ForEach(JobType.allCases, id: \.self) { type in
                        Toggle(type.rawValue, isOn: Binding(
                            get: { filters.jobTypes.contains(type) },
                            set: { isOn in
                                if isOn {
                                    filters.jobTypes.insert(type)
                                } else {
                                    filters.jobTypes.remove(type)
                                }
                            }
                        ))
                    }
                }
                
                // Location Type Section
                Section(header: Text("Location")) {
                    ForEach(LocationType.allCases, id: \.self) { location in
                        Toggle(location.rawValue, isOn: Binding(
                            get: { filters.locationTypes.contains(location) },
                            set: { isOn in
                                if isOn {
                                    filters.locationTypes.insert(location)
                                } else {
                                    filters.locationTypes.remove(location)
                                }
                            }
                        ))
                    }
                    
                    TextField("City, State, or Zip Code", text: $filters.location)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Salary Range Section
                Section(header: Text("Salary Range")) {
                    Picker("Minimum Salary", selection: $filters.minSalary) {
                        Text("Any").tag(nil as Int?)
                        Text("$50,000+").tag(50000 as Int?)
                        Text("$75,000+").tag(75000 as Int?)
                        Text("$100,000+").tag(100000 as Int?)
                        Text("$125,000+").tag(125000 as Int?)
                        Text("$150,000+").tag(150000 as Int?)
                        Text("$200,000+").tag(200000 as Int?)
                    }
                }
                
                // Experience Level Section
                Section(header: Text("Experience Level")) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Toggle(level.rawValue, isOn: Binding(
                            get: { filters.experienceLevels.contains(level) },
                            set: { isOn in
                                if isOn {
                                    filters.experienceLevels.insert(level)
                                } else {
                                    filters.experienceLevels.remove(level)
                                }
                            }
                        ))
                    }
                }
                
                // Date Posted Section
                Section(header: Text("Date Posted")) {
                    Picker("Posted Within", selection: $filters.datePosted) {
                        Text("Any Time").tag(nil as DatePostedFilter?)
                        Text("Last 24 Hours").tag(DatePostedFilter.last24Hours)
                        Text("Last Week").tag(DatePostedFilter.lastWeek)
                        Text("Last Month").tag(DatePostedFilter.lastMonth)
                        Text("Last 3 Months").tag(DatePostedFilter.last3Months)
                    }
                }
                
                // Company Size Section
                Section(header: Text("Company Size")) {
                    ForEach(CompanySize.allCases, id: \.self) { size in
                        Toggle(size.rawValue, isOn: Binding(
                            get: { filters.companySizes.contains(size) },
                            set: { isOn in
                                if isOn {
                                    filters.companySizes.insert(size)
                                } else {
                                    filters.companySizes.remove(size)
                                }
                            }
                        ))
                    }
                }
                
                // Reset Button
                Section {
                    Button("Reset All Filters") {
                        filters = JobFilters()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Job Filters Model
struct JobFilters {
    var jobTypes: Set<JobType> = []
    var locationTypes: Set<LocationType> = []
    var location: String = ""
    var minSalary: Int? = nil
    var experienceLevels: Set<ExperienceLevel> = []
    var datePosted: DatePostedFilter? = nil
    var companySizes: Set<CompanySize> = []
    
    var hasActiveFilters: Bool {
        !jobTypes.isEmpty ||
        !locationTypes.isEmpty ||
        !location.isEmpty ||
        minSalary != nil ||
        !experienceLevels.isEmpty ||
        datePosted != nil ||
        !companySizes.isEmpty
    }
    
    func apply(to jobs: [JobPost]) -> [JobPost] {
        var filtered = jobs
        
        // Filter by job type
        if !jobTypes.isEmpty {
            filtered = filtered.filter { job in
                guard let jobType = job.jobType else {
                    // If job type is not specified, check title for internship keywords
                    if jobTypes.contains(.internship) {
                        let titleLower = job.title.lowercased()
                        return titleLower.contains("intern") || titleLower.contains("internship")
                    }
                    return false
                }
                return jobTypes.contains { type in
                    let jobTypeLower = jobType.lowercased()
                    let typeLower = type.rawValue.lowercased()
                    return jobTypeLower.contains(typeLower) || 
                           (type == .internship && (jobTypeLower.contains("intern") || job.title.lowercased().contains("intern")))
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
        
        // Filter by specific location
        if !location.isEmpty {
            filtered = filtered.filter { job in
                job.location.lowercased().contains(location.lowercased())
            }
        }
        
        // Filter by minimum salary
        if let minSalary = minSalary {
            filtered = filtered.filter { job in
                guard let salary = job.salary else { return false }
                // Extract numbers from salary string (e.g., "$120,000 - $150,000" -> 120000)
                let numbers = salary.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                if let salaryValue = Int(numbers) {
                    return salaryValue >= minSalary
                }
                return false
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
    case fullTime = "Full-time"
    case partTime = "Part-time"
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


//
//  ApplicationsView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct ApplicationsView: View {
    @State private var applications: [Application] = []
    @State private var loading = false
    @State private var error: String?
    @State private var selectedSection: ApplicationSection? = nil
    @State private var showingAllApplications = false
    
    enum ApplicationSection: String, Identifiable {
        case attention = "attention"
        case submitted = "submitted"
        case pending = "pending"
        case failed = "failed"
        case passed = "passed"
        
        var id: String { rawValue }
    }
    
    // Only show applications where user actually applied (status is "applied" or post-application statuses)
    var appliedApplications: [Application] {
        return applications.filter { application in
            application.status == "applied" || 
            application.status == "interview" || 
            application.status == "rejected" || 
            application.status == "accepted" ||
            application.status == "pending_questions"
        }
    }
    
    // Applications with pending questions (for notifications)
    var pendingQuestionsApplications: [Application] {
        return applications.filter { $0.status == "pending_questions" }
    }
    
    // Submitted applications (applied, interview, accepted)
    var submittedApplications: [Application] {
        return appliedApplications.filter { 
            $0.status == "applied" || 
            $0.status == "interview" || 
            $0.status == "accepted"
        }
    }
    
    // Pending applications (not yet submitted, waiting)
    var pendingApplications: [Application] {
        return appliedApplications.filter { $0.status == "pending_questions" }
    }
    
    // Failed applications (rejected)
    var failedApplications: [Application] {
        return appliedApplications.filter { $0.status == "rejected" }
    }
    
    // Recent applications (last 5, sorted by date)
    var recentApplications: [Application] {
        return appliedApplications
            .sorted { app1, app2 in
                app1.appliedDate > app2.appliedDate
            }
            .prefix(5)
            .map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            if let section = selectedSection {
                // Show filtered section view
                SectionDetailView(
                    section: section,
                    applications: getApplicationsForSection(section),
                    onBack: {
                        selectedSection = nil
                    }
                )
            } else {
                // Main applications view (like sorce.jobs)
                ScrollView {
                    VStack(spacing: 24) {
                        // Attention Banner (if there are pending questions)
                        if !pendingQuestionsApplications.isEmpty {
                            Button(action: {
                                selectedSection = .attention
                            }) {
                                HStack {
                                    Text("\(pendingQuestionsApplications.count)")
                                        .font(.system(size: 32, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("Applications need your attention")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(20)
                                .background(
                                    LinearGradient(
                                        colors: [Color(red: 1.0, green: 0.85, blue: 0.0), Color(red: 1.0, green: 0.9, blue: 0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color(.systemGray5), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 20)
                        }
                        
                        // Summary Section
                        VStack(alignment: .leading, spacing: 16) {
                            Text("Summary")
                                .font(.system(size: 24, weight: .bold))
                                .padding(.horizontal, 20)
                            
                            HStack(spacing: 12) {
                                // Submitted Card
                                SummaryCard(
                                    icon: "checkmark.circle.fill",
                                    title: "Submitted",
                                    count: submittedApplications.count,
                                    color: .blue
                                ) {
                                    selectedSection = .submitted
                                }
                                
                                // Pending Card
                                SummaryCard(
                                    icon: "clock.fill",
                                    title: "Pending",
                                    count: pendingApplications.count,
                                    color: .orange
                                ) {
                                    selectedSection = .pending
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .overlay(
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(Color(.systemGray5)),
                            alignment: .bottom
                        )
                        
                        // Additional Status Sections
                        VStack(spacing: 0) {
                            // Failed Applications
                            if !failedApplications.isEmpty {
                                SectionRow(
                                    icon: "exclamationmark.circle.fill",
                                    title: "Failed applications",
                                    count: failedApplications.count
                                ) {
                                    selectedSection = .failed
                                }
                                .overlay(
                                    Rectangle()
                                        .frame(height: 1)
                                        .foregroundColor(Color(.systemGray5)),
                                    alignment: .bottom
                                )
                            }
                            
                            // Jobs You Passed On (for future use)
                            SectionRow(
                                icon: "hand.thumbsup.fill",
                                title: "Jobs you passed on",
                                count: 0
                            ) {
                                // Future implementation
                            }
                            .overlay(
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundColor(Color(.systemGray5)),
                                alignment: .bottom
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                        
                        // Recent Applications Section
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text("Your recent applications")
                                    .font(.system(size: 24, weight: .bold))
                                
                                Spacer()
                                
                                Button(action: {
                                    showingAllApplications = true
                                }) {
                                    Text("See all")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                    + Text(" >")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 20)
                            
                            VStack(spacing: 12) {
                                ForEach(recentApplications) { application in
                                    RecentApplicationCard(application: application)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.vertical, 16)
                        .background(Color(.systemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray5), lineWidth: 1)
                        )
                    }
                    .padding(.vertical, 20)
                }
                .navigationTitle("Applications")
                .navigationBarTitleDisplayMode(.large)
                .sheet(isPresented: $showingAllApplications) {
                    AllApplicationsView(applications: appliedApplications)
                }
            }
        }
        .onAppear {
            Task {
                await fetchApplications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ApplicationStatusUpdated"))) { _ in
            Task {
                await fetchApplications()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ApplicationPendingQuestions"))) { _ in
            Task {
                await fetchApplications()
            }
        }
    }
    
    private func getApplicationsForSection(_ section: ApplicationSection) -> [Application] {
        switch section {
        case .attention:
            return pendingQuestionsApplications
        case .submitted:
            return submittedApplications
        case .pending:
            return pendingApplications
        case .failed:
            return failedApplications
        case .passed:
            return []
        }
    }
    
    private func fetchApplications() async {
        loading = true
        error = nil
        
        do {
            let apps = try await SupabaseService.shared.fetchApplications()
            await MainActor.run {
                self.applications = apps
                self.loading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.loading = false
            }
        }
    }
}

// MARK: - Summary Card
struct SummaryCard: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text("\(count)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Section Row
struct SectionRow: View {
    let icon: String
    let title: String
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
                    .frame(width: 40, height: 40)
                
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Application Card
struct RecentApplicationCard: View {
    let application: Application
    @State private var showingStatusUpdate = false
    
    var statusColor: Color {
        switch application.status {
        case "applied": return .blue
        case "pending_questions": return .orange
        case "interview": return .purple
        case "rejected": return .red
        case "accepted": return .green
        default: return .gray
        }
    }
    
    var statusText: String {
        switch application.status {
        case "applied": return "Applied"
        case "pending_questions": return "In progress"
        case "interview": return "Interview"
        case "rejected": return "Rejected"
        case "accepted": return "Accepted"
        default: return application.status.capitalized
        }
    }
    
    var body: some View {
        Button(action: {
            showingStatusUpdate = true
        }) {
            HStack(spacing: 12) {
                // Company Avatar
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                    
                    Text(String(application.company.prefix(1)).uppercased())
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        // Status Badge
                        HStack(spacing: 4) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 8, height: 8)
                            
                            Text(statusText)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(statusColor)
                        }
                        
                        Spacer()
                        
                        // Time ago
                        Text(formatTimeAgo(application.appliedDate))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Text(application.jobTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text(application.company)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray5), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingStatusUpdate) {
            StatusUpdateView(application: application, onUpdate: { newStatus in
                NotificationCenter.default.post(name: NSNotification.Name("ApplicationStatusUpdated"), object: nil)
            })
        }
    }
    
    private func formatTimeAgo(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateString) else {
            return dateString
        }
        
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            if days == 1 {
                return "1d ago"
            } else if days < 7 {
                return "\(days)d ago"
            } else {
                return "\(days / 7)w ago"
            }
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)h ago"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)m ago"
        } else {
            return "Just now"
        }
    }
}

// MARK: - Section Detail View
struct SectionDetailView: View {
    let section: ApplicationsView.ApplicationSection
    let applications: [Application]
    let onBack: () -> Void
    
    var sectionTitle: String {
        switch section {
        case .attention: return "Action Required"
        case .submitted: return "Submitted"
        case .pending: return "Pending"
        case .failed: return "Failed Applications"
        case .passed: return "Jobs You Passed On"
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if section == .attention {
                        // Show pending questions cards
                        ForEach(applications) { application in
                            PendingQuestionsCard(application: application)
                                .padding(.horizontal, 20)
                        }
                    } else {
                        // Show regular application cards
                        ForEach(applications) { application in
                            ApplicationCard(application: application)
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle(sectionTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - All Applications View
struct AllApplicationsView: View {
    let applications: [Application]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(applications.sorted { $0.appliedDate > $1.appliedDate }) { application in
                        RecentApplicationCard(application: application)
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
            .navigationTitle("All Applications")
            .navigationBarTitleDisplayMode(.large)
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

// Status Filter Button Component
struct StatusFilterButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.systemGray5))
                        .cornerRadius(8)
                }
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray6))
            .cornerRadius(20)
        }
    }
}

struct ApplicationCard: View {
    let application: Application
    @State private var showingStatusUpdate = false
    @State private var isUpdating = false
    
    var statusColor: Color {
        switch application.status {
        case "applied": return .blue
        case "viewed": return .orange
        case "interview": return .purple
        case "rejected": return .red
        case "accepted": return .green
        default: return .gray
        }
    }
    
    var statusIcon: String {
        switch application.status {
        case "applied": return "paperplane.fill"
        case "viewed": return "eye.fill"
        case "interview": return "calendar.fill"
        case "rejected": return "xmark.circle.fill"
        case "accepted": return "checkmark.circle.fill"
        default: return "circle.fill"
        }
    }
    
    var body: some View {
        Button(action: {
            showingStatusUpdate = true
        }) {
            HStack(spacing: 16) {
                // Status indicator (like sorce.jobs)
                RoundedRectangle(cornerRadius: 4)
                    .fill(statusColor)
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(application.jobTitle)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(2)
                            
                            Text(application.company)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Status badge
                        Text(application.status.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(statusColor.opacity(0.1))
                            .cornerRadius(8)
                    }
                    
                    // Date
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(formatDate(application.appliedDate))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingStatusUpdate) {
            StatusUpdateView(application: application, onUpdate: { newStatus in
                updateStatus(newStatus)
            })
        }
    }
    
    private func updateStatus(_ newStatus: String) {
        isUpdating = true
        Task {
            do {
                try await SupabaseService.shared.updateApplicationStatus(
                    application.id,
                    status: newStatus
                )
                await MainActor.run {
                    isUpdating = false
                    showingStatusUpdate = false
                }
                // Refresh the applications list
                NotificationCenter.default.post(name: NSNotification.Name("ApplicationStatusUpdated"), object: nil)
            } catch {
                await MainActor.run {
                    isUpdating = false
                }
                print("❌ Failed to update status: \(error.localizedDescription)")
            }
        }
    }
    
    private func formatDate(_ dateString: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            let daysAgo = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
            
            if daysAgo == 0 {
                return "today"
            } else if daysAgo == 1 {
                return "yesterday"
            } else if daysAgo < 7 {
                return "\(daysAgo) days ago"
            } else {
                formatter.dateStyle = .medium
                return formatter.string(from: date)
            }
        }
        return dateString
    }
}

#Preview {
    ApplicationsView()
}

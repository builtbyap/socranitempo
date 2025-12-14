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
    @State private var selectedStatus: String = "all"
    
    var filteredApplications: [Application] {
        if selectedStatus == "all" {
            return applications
        }
        return applications.filter { $0.status == selectedStatus }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Status Filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        StatusFilterButton(title: "All", status: "all", selectedStatus: $selectedStatus)
                        StatusFilterButton(title: "Applied", status: "applied", selectedStatus: $selectedStatus)
                        StatusFilterButton(title: "Viewed", status: "viewed", selectedStatus: $selectedStatus)
                        StatusFilterButton(title: "Interview", status: "interview", selectedStatus: $selectedStatus)
                        StatusFilterButton(title: "Rejected", status: "rejected", selectedStatus: $selectedStatus)
                        StatusFilterButton(title: "Accepted", status: "accepted", selectedStatus: $selectedStatus)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                
                // Applications List
                if loading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else if let error = error {
                    Spacer()
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    }
                    Spacer()
                } else if filteredApplications.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text(selectedStatus == "all" ? "No applications yet" : "No \(selectedStatus) applications")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("Swipe right on jobs to apply")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(filteredApplications) { application in
                                ApplicationCard(application: application)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }
            .navigationTitle("Applications")
            .onAppear {
                Task {
                    await fetchApplications()
                }
            }
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

struct StatusFilterButton: View {
    let title: String
    let status: String
    @Binding var selectedStatus: String
    
    var isSelected: Bool {
        selectedStatus == status
    }
    
    var body: some View {
        Button(action: {
            selectedStatus = status
        }) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemBackground))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.blue.opacity(isSelected ? 0 : 0.3), lineWidth: 1)
                )
        }
    }
}

struct ApplicationCard: View {
    let application: Application
    
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
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: statusIcon)
                        .foregroundColor(statusColor)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(application.jobTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    Text(application.company)
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Status Badge
                Text(application.status.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(12)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            Divider()
                .padding(.horizontal, 16)
            
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                Text("Applied \(formatDate(application.appliedDate))")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray5), lineWidth: 0.5)
        )
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


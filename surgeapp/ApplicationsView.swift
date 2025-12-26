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
    
    // Only show applications where user actually applied (status is "applied" or post-application statuses)
    var appliedApplications: [Application] {
        return applications.filter { application in
            // Show all applications - they're all ones the user applied to
            // Filter out any that might have status "viewed" or other non-application statuses
            application.status == "applied" || 
            application.status == "interview" || 
            application.status == "rejected" || 
            application.status == "accepted"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
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
                } else if appliedApplications.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "briefcase.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        Text("No applications yet")
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
                            ForEach(appliedApplications) { application in
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ApplicationStatusUpdated"))) { _ in
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
                
                // Status Badge (tappable)
                Button(action: {
                    showingStatusUpdate = true
                }) {
                Text(application.status.capitalized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(statusColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor.opacity(0.1))
                    .cornerRadius(12)
                }
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
                
                Spacer()
                
                if isUpdating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
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


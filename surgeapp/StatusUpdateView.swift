//
//  StatusUpdateView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct StatusUpdateView: View {
    let application: Application
    let onUpdate: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedStatus: String
    
    let statuses = [
        ("applied", "Applied", Color.blue, "paperplane.fill"),
        ("viewed", "Viewed", Color.orange, "eye.fill"),
        ("interview", "Interview", Color.purple, "calendar.fill"),
        ("rejected", "Rejected", Color.red, "xmark.circle.fill"),
        ("accepted", "Accepted", Color.green, "checkmark.circle.fill")
    ]
    
    init(application: Application, onUpdate: @escaping (String) -> Void) {
        self.application = application
        self.onUpdate = onUpdate
        _selectedStatus = State(initialValue: application.status)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Current Application Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Application Status")
                        .font(.system(size: 18, weight: .semibold))
                    
                    Text(application.jobTitle)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Text(application.company)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Status Options
                VStack(alignment: .leading, spacing: 16) {
                    Text("Update Status")
                        .font(.system(size: 18, weight: .semibold))
                    
                    ForEach(statuses, id: \.0) { status in
                        Button(action: {
                            selectedStatus = status.0
                        }) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(status.2.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                    Image(systemName: status.3)
                                        .foregroundColor(status.2)
                                        .font(.system(size: 18))
                                }
                                
                                Text(status.1)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if selectedStatus == status.0 {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 20))
                                }
                            }
                            .padding()
                            .background(selectedStatus == status.0 ? status.2.opacity(0.1) : Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(selectedStatus == status.0 ? status.2 : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Update Button
                Button(action: {
                    if selectedStatus != application.status {
                        onUpdate(selectedStatus)
                    } else {
                        dismiss()
                    }
                }) {
                    HStack {
                        Spacer()
                        Text(selectedStatus == application.status ? "Cancel" : "Update Status")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(selectedStatus == application.status ? Color.gray : Color.blue)
                    .cornerRadius(12)
                }
                .padding()
            }
            .padding()
            .navigationTitle("Update Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}


//
//  InProgressApplicationCard.swift
//  surgeapp
//
//  Card view for in-progress applications with live stream (like sorce.jobs)
//

import SwiftUI
import UIKit

struct InProgressApplicationCard: View {
    let application: Application
    @State private var showingLiveStream = false
    @ObservedObject private var streamService = SSEStreamService.shared
    
    var body: some View {
        Button(action: {
            showingLiveStream = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with live indicator
                HStack {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                    
                    Text("In Progress")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.purple)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(8)
                }
                
                // Job Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(application.jobTitle)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    Text(application.company)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                // Live Stream Preview
                if let liveFrame = streamService.currentFrame {
                    Image(uiImage: liveFrame)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 180)
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.green, lineWidth: 2)
                        )
                } else {
                    // Placeholder or loading state
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray5))
                            .frame(height: 180)
                        
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Connecting to live stream...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Status text
                if let step = streamService.currentStep {
                    Text(step)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingLiveStream) {
            InProgressLiveStreamView(application: application)
        }
    }
}

// MARK: - In Progress Live Stream View
struct InProgressLiveStreamView: View {
    let application: Application
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var streamService = SSEStreamService.shared
    @State private var streamSessionId: String?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Job Info Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text(application.jobTitle)
                            .font(.system(size: 24, weight: .bold))
                        
                        Text(application.company)
                            .font(.system(size: 18))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    
                    // Live Stream Display
                    if let liveFrame = streamService.currentFrame {
                        VStack(spacing: 12) {
                            HStack {
                                Circle()
                                    .fill(streamService.isConnected ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                                Text(streamService.isConnected ? "LIVE" : "Connecting...")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(streamService.isConnected ? .green : .red)
                            }
                            
                            Image(uiImage: liveFrame)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: 500)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                            
                            if let step = streamService.currentStep {
                                Text(step)
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                            
                            if let error = streamService.error {
                                Text("Stream error: \(error)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                                    .padding()
                            }
                        }
                        .padding()
                    } else {
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                            
                            Text(streamService.error != nil ? "Stream unavailable" : "Connecting to live stream...")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                            
                            if let error = streamService.error {
                                Text("Error: \(error)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.red)
                                    .multilineTextAlignment(.center)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Application Progress")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Connect to stream if we have a session ID
                // Note: This would need to be stored when application starts
                // For now, we'll need to get it from the application or start a new stream
            }
            .onDisappear {
                streamService.disconnect()
            }
        }
    }
}


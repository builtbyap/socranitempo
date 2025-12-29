//
//  PendingQuestionsCard.swift
//  surgeapp
//
//  Card to show applications with pending questions (like sorce.jobs)
//

import SwiftUI

struct PendingQuestionsCard: View {
    let application: Application
    @State private var showingQuestionView = false
    
    var body: some View {
        Button(action: {
            print("🔍 Opening question view for: \(application.jobTitle)")
            print("📋 Pending questions count: \(application.pendingQuestions?.count ?? 0)")
            if let questions = application.pendingQuestions {
                print("📝 Questions: \(questions)")
            } else {
                print("⚠️ No questions found in application")
            }
            showingQuestionView = true
        }) {
            HStack(spacing: 16) {
                // Orange status indicator (like sorce.jobs)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.orange)
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
                            
                            if let questions = application.pendingQuestions, !questions.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(.orange)
                                    Text("\(questions.count) question\(questions.count == 1 ? "" : "s") need answering")
                                        .font(.system(size: 13))
                                        .foregroundColor(.orange)
                                }
                                .padding(.top, 2)
                            }
                        }
                        
                        Spacer()
                        
                        // Action button
                        Text("Answer")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color.orange)
                            .cornerRadius(8)
                    }
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .sheet(isPresented: $showingQuestionView) {
            if let questions = application.pendingQuestions, !questions.isEmpty {
                QuestionAnswerView(
                    application: application,
                    questions: questions
                )
            } else {
                // Fallback view if questions are missing
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    Text("No Questions Found")
                        .font(.headline)
                    Text("The questions for this application could not be loaded.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding()
                    Button("Close") {
                        showingQuestionView = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .presentationDetents([.medium])
            }
        }
    }
}


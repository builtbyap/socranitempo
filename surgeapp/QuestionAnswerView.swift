//
//  QuestionAnswerView.swift
//  surgeapp
//
//  View for users to answer questions from job applications (like sorce.jobs)
//

import SwiftUI

struct QuestionAnswerView: View {
    let application: Application
    let questions: [PendingQuestion]
    @Environment(\.dismiss) var dismiss
    @State private var currentQuestionIndex = 0
    @State private var answers: [Int: String] = [:]
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var currentQuestion: PendingQuestion {
        guard currentQuestionIndex < questions.count else {
            return questions[0] // Fallback to first question
        }
        return questions[currentQuestionIndex]
    }
    
    var body: some View {
        NavigationStack {
            Group {
                // Safety check: if no questions, show error
                if questions.isEmpty {
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
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .onAppear {
                        print("⚠️ QuestionAnswerView: questions array is empty")
                        print("   Application: \(application.jobTitle) at \(application.company)")
                        print("   Status: \(application.status)")
                    }
                } else {
                    // Normal question view
                    VStack(spacing: 24) {
                        // Progress Indicator
                        VStack(spacing: 8) {
                            ProgressView(value: Double(currentQuestionIndex + 1), total: Double(questions.count))
                                .progressViewStyle(LinearProgressViewStyle())
                            
                            Text("Question \(currentQuestionIndex + 1) of \(questions.count)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Job Info
                        VStack(spacing: 8) {
                            Text(application.jobTitle)
                                .font(.system(size: 20, weight: .bold))
                    
                            Text(application.company)
                        .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        
                        // Question
                        VStack(alignment: .leading, spacing: 16) {
                        // Question Text
                        VStack(alignment: .leading, spacing: 4) {
                            if !currentQuestion.question.isEmpty {
                                Text(currentQuestion.question)
                                    .font(.system(size: 18, weight: .semibold))
                                    .padding(.horizontal)
                            } else {
                                Text("Question \(currentQuestionIndex + 1)")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                            }
                            
                            // Debug info (remove in production)
                            #if DEBUG
                            Text("Debug: ID=\(currentQuestion.id), Type=\(currentQuestion.inputType), Field=\(currentQuestion.fieldType)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            #endif
                        }
                        
                        if currentQuestion.required {
                        Text("Required")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                                .padding(.horizontal)
                    }
                
                // Answer Input
                        if currentQuestion.inputType == "select" || currentQuestion.fieldType == "select" || currentQuestion.inputType == "radio" || (currentQuestion.options != nil && !currentQuestion.options!.isEmpty) {
                            // Multiple choice options as bubbles (like sorce.jobs)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Choose your answer:")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                    
                                if let options = currentQuestion.options, !options.isEmpty {
                                    // Show options as tappable bubbles
                                    VStack(alignment: .leading, spacing: 10) {
                                        ForEach(options, id: \.value) { option in
                                        Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    answers[currentQuestion.id] = option.value
                                                }
                                        }) {
                                                HStack(spacing: 12) {
                                                    // Selection indicator
                                                    ZStack {
                                                        Circle()
                                                            .fill(answers[currentQuestion.id] == option.value ? Color.blue : Color.clear)
                                                            .frame(width: 24, height: 24)
                                                        
                                                        if answers[currentQuestion.id] == option.value {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 14, weight: .bold))
                                                                .foregroundColor(.white)
                                                        } else {
                                                            Circle()
                                                                .stroke(Color(.systemGray3), lineWidth: 2)
                                                                .frame(width: 24, height: 24)
                                                        }
                                                    }
                                                    
                                                    // Option text
                                                Text(option.text.isEmpty ? option.value : option.text)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.primary)
                                                        .multilineTextAlignment(.leading)
                                                
                                                Spacer()
                                            }
                                                .padding(.vertical, 14)
                                                .padding(.horizontal, 16)
                                                .background(
                                                    answers[currentQuestion.id] == option.value 
                                                        ? Color.blue.opacity(0.1) 
                                                        : Color(.systemGray6)
                                                )
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                        .stroke(
                                                            answers[currentQuestion.id] == option.value 
                                                                ? Color.blue 
                                                                : Color.clear,
                                                            lineWidth: 2
                                                        )
                                            )
                                        }
                                            .buttonStyle(.plain)
                                }
                            }
                                    .padding(.horizontal)
                        } else {
                                    Text("No options available")
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal)
                                }
                        }
                        } else if currentQuestion.inputType == "textarea" || currentQuestion.fieldType == "textarea" {
                            // Text Area
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your answer:")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                TextEditor(text: Binding(
                                    get: { answers[currentQuestion.id] ?? "" },
                                    set: { answers[currentQuestion.id] = $0 }
                                ))
                                .frame(height: 150)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .padding(.horizontal)
                            }
                        } else {
                            // Text Input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Your answer:")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal)
                                
                                TextField("Type your answer here", text: Binding(
                                    get: { answers[currentQuestion.id] ?? "" },
                                    set: { answers[currentQuestion.id] = $0 }
                                ))
                                .textFieldStyle(.roundedBorder)
                                .padding(.horizontal)
                            }
                        }
                    }
                    .padding(.vertical)
                    .onAppear {
                        print("📋 QuestionAnswerView appeared")
                        print("   Total questions: \(questions.count)")
                        print("   Current index: \(currentQuestionIndex)")
                        print("   Current question ID: \(currentQuestion.id)")
                        print("📋 Displaying question \(currentQuestionIndex + 1):")
                        print("   Question: \(currentQuestion.question)")
                        print("   Input type: \(currentQuestion.inputType)")
                        print("   Field type: \(currentQuestion.fieldType)")
                        print("   Options count: \(currentQuestion.options?.count ?? 0)")
                        if let options = currentQuestion.options {
                            for (index, option) in options.enumerated() {
                                print("   Option \(index + 1): \(option.text) (value: \(option.value))")
                            }
                        }
                    }
                
                Spacer()
                
                    // Navigation Buttons
                    HStack(spacing: 16) {
                        if currentQuestionIndex > 0 {
                            Button("Previous") {
                                withAnimation {
                                    currentQuestionIndex -= 1
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Spacer()
                        
                        if currentQuestionIndex < questions.count - 1 {
                            Button("Next") {
                                // Validate current answer if required
                                if currentQuestion.required && (answers[currentQuestion.id]?.isEmpty ?? true) {
                                    errorMessage = "This question is required"
                                    return
                                }
                                
                                withAnimation {
                                    currentQuestionIndex += 1
                                    errorMessage = nil
                                }
                    }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Submit Answers") {
                                submitAnswers()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isSubmitting)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    if let error = errorMessage {
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
            }
            }
            .navigationTitle("Answer Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Answers Submitted!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your answers have been submitted. The application will be completed automatically.")
            }
        }
    }
    
    private func submitAnswers() {
        // Validate all required questions
        for question in questions {
            if question.required && (answers[question.id]?.isEmpty ?? true) {
                errorMessage = "Please answer all required questions"
                return
        }
    }
    
        isSubmitting = true
        errorMessage = nil
        
        Task {
            do {
                // Resume automation with answers
                try await AutoApplyService.shared.resumeApplicationWithAnswers(
                    application: application,
                    answers: answers
                )
                
                // Update application status
                try await SupabaseService.shared.updateApplicationStatus(
                    application.id,
                    status: "applied"
                )
                
                // Clear pending questions
                // Note: You may want to update the application record to clear questions
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
                
                // Post notification to refresh applications list and resume automation
                NotificationCenter.default.post(
                    name: NSNotification.Name("ApplicationStatusUpdated"),
                    object: nil
                )
                
                // Also post a specific notification that questions were answered
                NotificationCenter.default.post(
                    name: NSNotification.Name("QuestionsAnswered"),
                    object: nil,
                    userInfo: ["applicationId": application.id]
                )
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = "Failed to submit answers: \(error.localizedDescription)"
        }
    }
}
    }
}

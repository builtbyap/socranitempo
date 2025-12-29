//
//  InlineQuestionAnswerView.swift
//  surgeapp
//
//  Inline question answering view (shown during automation, like sorce.jobs)
//

import SwiftUI

struct InlineQuestionAnswerView: View {
    let questions: [PendingQuestion]
    let jobTitle: String
    let company: String
    let onAnswersSubmitted: ([Int: String]) -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentQuestionIndex = 0
    @State private var answers: [Int: String] = [:]
    @State private var errorMessage: String?
    
    var currentQuestion: PendingQuestion {
        questions[currentQuestionIndex]
    }
    
    var body: some View {
        NavigationStack {
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
                    Text(jobTitle)
                        .font(.system(size: 20, weight: .bold))
                    
                    Text(company)
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding()
                
                // Question
                VStack(alignment: .leading, spacing: 16) {
                    Text(currentQuestion.question)
                        .font(.system(size: 18, weight: .semibold))
                        .padding(.horizontal)
                    
                    if currentQuestion.required {
                        Text("Required")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Answer Input
                    if currentQuestion.inputType == "select" || (currentQuestion.options != nil && !currentQuestion.options!.isEmpty) {
                        // Dropdown/Select
                        Picker("Answer", selection: Binding(
                            get: { answers[currentQuestion.id] ?? "" },
                            set: { answers[currentQuestion.id] = $0 }
                        )) {
                            Text("Select an option").tag("")
                            ForEach(currentQuestion.options ?? [], id: \.value) { option in
                                Text(option.text).tag(option.value)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal)
                    } else if currentQuestion.inputType == "textarea" || currentQuestion.fieldType == "textarea" {
                        // Text Area
                        TextEditor(text: Binding(
                            get: { answers[currentQuestion.id] ?? "" },
                            set: { answers[currentQuestion.id] = $0 }
                        ))
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    } else {
                        // Text Input
                        TextField("Your answer", text: Binding(
                            get: { answers[currentQuestion.id] ?? "" },
                            set: { answers[currentQuestion.id] = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                Spacer()
                
                // Navigation Buttons
                HStack(spacing: 16) {
                    if currentQuestionIndex > 0 {
                        Button("Previous") {
                            withAnimation {
                                currentQuestionIndex -= 1
                                errorMessage = nil
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
                        Button("Submit & Continue") {
                            submitAnswers()
                        }
                        .buttonStyle(.borderedProminent)
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
            .navigationTitle("Answer Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
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
        
        // Submit answers
        onAnswersSubmitted(answers)
        dismiss()
    }
}


//
//  QuestionAnswerView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI

struct QuestionAnswerView: View {
    let question: DetectedQuestion
    let onAnswer: (String) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedAnswer: String = ""
    @State private var textAnswer: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                // Question Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.blue)
                        Text("Question Required")
                            .font(.system(size: 18, weight: .semibold))
                    }
                    
                    Text(question.question)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .padding(.top, 4)
                    
                    if question.required {
                        Text("Required")
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Answer Input
                VStack(alignment: .leading, spacing: 16) {
                    Text("Your Answer")
                        .font(.system(size: 16, weight: .semibold))
                    
                    if question.inputType == "select" || question.inputType == "radio" {
                        // Show options
                        if !question.options.isEmpty {
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(question.options, id: \.value) { option in
                                        Button(action: {
                                            selectedAnswer = option.value
                                        }) {
                                            HStack {
                                                Text(option.text.isEmpty ? option.value : option.text)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(.primary)
                                                
                                                Spacer()
                                                
                                                if selectedAnswer == option.value {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.blue)
                                                        .font(.system(size: 20))
                                                } else {
                                                    Image(systemName: "circle")
                                                        .foregroundColor(.gray)
                                                        .font(.system(size: 20))
                                                }
                                            }
                                            .padding()
                                            .background(selectedAnswer == option.value ? Color.blue.opacity(0.1) : Color(.systemGray6))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(selectedAnswer == option.value ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                        }
                                    }
                                }
                            }
                        } else {
                            // No options, use text input
                            TextField("Enter your answer", text: $textAnswer)
                                .textFieldStyle(.roundedBorder)
                                .focused($isTextFieldFocused)
                                .padding(.vertical, 8)
                        }
                    } else {
                        // Text input
                        if question.inputType == "textarea" {
                            TextEditor(text: $textAnswer)
                                .frame(minHeight: 120)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(.separator), lineWidth: 1)
                                )
                        } else {
                            TextField("Enter your answer", text: $textAnswer)
                                .textFieldStyle(.roundedBorder)
                                .focused($isTextFieldFocused)
                                .keyboardType(getKeyboardType())
                        }
                    }
                }
                .padding()
                
                Spacer()
                
                // Submit Button
                Button(action: submitAnswer) {
                    HStack {
                        Spacer()
                        Text("Submit Answer")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding()
                    .background(canSubmit ? Color.blue : Color.gray)
                    .cornerRadius(12)
                }
                .disabled(!canSubmit)
                .padding()
            }
            .padding()
            .navigationTitle("Answer Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip") {
                        onAnswer("")
                        dismiss()
                    }
                    .disabled(question.required)
                }
            }
            .onAppear {
                // Auto-focus text field if applicable
                if question.inputType != "select" && question.inputType != "radio" {
                    isTextFieldFocused = true
                }
            }
        }
    }
    
    private var canSubmit: Bool {
        if question.inputType == "select" || question.inputType == "radio" {
            return !selectedAnswer.isEmpty
        } else {
            return !textAnswer.isEmpty
        }
    }
    
    private func submitAnswer() {
        let answer: String
        if question.inputType == "select" || question.inputType == "radio" {
            answer = selectedAnswer
        } else {
            answer = textAnswer.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        guard !answer.isEmpty else { return }
        
        onAnswer(answer)
        dismiss()
    }
    
    private func getKeyboardType() -> UIKeyboardType {
        let questionLower = question.question.lowercased()
        if questionLower.contains("email") {
            return .emailAddress
        } else if questionLower.contains("phone") || questionLower.contains("number") {
            return .phonePad
        } else if questionLower.contains("url") || questionLower.contains("website") {
            return .URL
        } else {
            return .default
        }
    }
}


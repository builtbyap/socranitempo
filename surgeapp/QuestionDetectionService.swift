//
//  QuestionDetectionService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation

// MARK: - Question Detection Service
class QuestionDetectionService {
    static let shared = QuestionDetectionService()
    
    private init() {}
    
    // MARK: - Detect Questions in Form
    func detectQuestions() -> String {
        return """
        (function() {
            const questions = [];
            
            // Find all input fields that might be questions
            const inputs = document.querySelectorAll('input, textarea, select');
            
            inputs.forEach((input, index) => {
                // Skip hidden, submit, and button inputs
                if (input.type === 'hidden' || input.type === 'submit' || input.type === 'button' || input.type === 'checkbox' || input.type === 'radio') {
                    return;
                }
                
                // Skip if already has a value
                if (input.value && input.value.trim() !== '') {
                    return;
                }
                
                // Try to find the question/label
                let questionText = '';
                let answerOptions = [];
                
                // Strategy 1: Find associated label
                if (input.id) {
                    const label = document.querySelector(`label[for="${input.id}"]`);
                    if (label) {
                        questionText = label.textContent.trim();
                    }
                }
                
                // Strategy 2: Find parent label
                if (!questionText) {
                    const parentLabel = input.closest('label');
                    if (parentLabel) {
                        questionText = parentLabel.textContent.trim();
                    }
                }
                
                // Strategy 3: Find nearby text (question-like patterns)
                if (!questionText) {
                    const parent = input.parentElement;
                    if (parent) {
                        // Look for text nodes or elements with question-like text
                        const textElements = Array.from(parent.querySelectorAll('p, div, span, h1, h2, h3, h4, h5, h6'))
                            .map(el => el.textContent.trim())
                            .filter(text => text.length > 0 && text.length < 200);
                        
                        // Check if text looks like a question
                        for (const text of textElements) {
                            if (text.includes('?') || 
                                text.toLowerCase().includes('select') ||
                                text.toLowerCase().includes('choose') ||
                                text.toLowerCase().includes('please') ||
                                text.toLowerCase().includes('required')) {
                                questionText = text;
                                break;
                            }
                        }
                    }
                }
                
                // Strategy 4: Check placeholder
                if (!questionText && input.placeholder) {
                    questionText = input.placeholder;
                }
                
                // Get answer options for select/radio
                if (input.tagName === 'SELECT') {
                    const options = Array.from(input.querySelectorAll('option'));
                    answerOptions = options
                        .filter(opt => opt.value && opt.value !== '')
                        .map(opt => ({
                            value: opt.value,
                            text: opt.textContent.trim()
                        }));
                } else if (input.type === 'radio') {
                    const name = input.name;
                    if (name) {
                        const radios = document.querySelectorAll(`input[type="radio"][name="${name}"]`);
                        answerOptions = Array.from(radios).map(radio => ({
                            value: radio.value,
                            text: radio.nextElementSibling?.textContent.trim() || radio.value
                        }));
                    }
                }
                
                // Only include if we found a question
                if (questionText && questionText.length > 3) {
                    questions.push({
                        index: index,
                        fieldType: input.tagName.toLowerCase(),
                        inputType: input.type || 'text',
                        name: input.name || '',
                        id: input.id || '',
                        question: questionText,
                        options: answerOptions,
                        required: input.required || input.hasAttribute('required'),
                        selector: getSelector(input)
                    });
                }
            });
            
            // Helper to get unique selector
            function getSelector(element) {
                if (element.id) return '#' + element.id;
                if (element.name) return `[name="${element.name}"]`;
                return '';
            }
            
            return JSON.stringify(questions);
        })();
        """
    }
    
    // MARK: - Fill Answer into Form
    func fillAnswerScript(questionIndex: Int, answer: String) -> String {
        return """
        (function() {
            const inputs = document.querySelectorAll('input, textarea, select');
            const input = inputs[\(questionIndex)];
            
            if (!input) {
                return { success: false, message: 'Field not found' };
            }
            
            // Fill based on input type
            if (input.tagName === 'SELECT') {
                // Try to find option by value or text
                const options = Array.from(input.querySelectorAll('option'));
                const option = options.find(opt => 
                    opt.value.toLowerCase() === '\(answer.lowercased())' ||
                    opt.textContent.toLowerCase().includes('\(answer.lowercased())')
                );
                if (option) {
                    input.value = option.value;
                } else {
                    input.value = '\(answer)';
                }
            } else if (input.type === 'radio') {
                // Find radio button with matching value
                const name = input.name;
                if (name) {
                    const radios = document.querySelectorAll(`input[type="radio"][name="${name}"]`);
                    const radio = Array.from(radios).find(r => 
                        r.value.toLowerCase() === '\(answer.lowercased())' ||
                        r.nextElementSibling?.textContent.toLowerCase().includes('\(answer.lowercased())')
                    );
                    if (radio) {
                        radio.checked = true;
                    }
                }
            } else {
                // Text input, textarea, etc.
                input.value = '\(answer)';
            }
            
            // Trigger events
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            
            return { success: true, message: 'Answer filled' };
        })();
        """
    }
}

// MARK: - Question Model
struct DetectedQuestion: Identifiable, Codable {
    let id: Int
    let fieldType: String
    let inputType: String
    let name: String
    let question: String
    let options: [AnswerOption]
    let required: Bool
    let selector: String
    
    enum CodingKeys: String, CodingKey {
        case id = "index"
        case fieldType
        case inputType
        case name
        case question
        case options
        case required
        case selector
    }
}

struct AnswerOption: Codable {
    let value: String
    let text: String
}


//
//  WebAutomationService.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import Foundation
import WebKit

// MARK: - Web Automation Service
class WebAutomationService: NSObject {
    static let shared = WebAutomationService()
    
    private override init() {
        super.init()
    }
    
    // MARK: - Form Field Detection JavaScript
    func getFormDetectionScript() -> String {
        return """
        (function() {
            // Find all input fields
            const inputs = document.querySelectorAll('input, textarea, select');
            const formFields = [];
            
            inputs.forEach((input, index) => {
                const field = {
                    index: index,
                    type: input.tagName.toLowerCase(),
                    name: input.name || '',
                    id: input.id || '',
                    placeholder: input.placeholder || '',
                    label: '',
                    value: input.value || ''
                };
                
                // Try to find associated label
                if (input.id) {
                    const label = document.querySelector(`label[for="${input.id}"]`);
                    if (label) field.label = label.textContent.trim();
                }
                
                // Try to find parent label
                if (!field.label) {
                    const parentLabel = input.closest('label');
                    if (parentLabel) field.label = parentLabel.textContent.trim();
                }
                
                // Try to find nearby text
                if (!field.label) {
                    const parent = input.parentElement;
                    if (parent) {
                        const textNodes = Array.from(parent.childNodes)
                            .filter(n => n.nodeType === 3)
                            .map(n => n.textContent.trim())
                            .filter(t => t.length > 0);
                        if (textNodes.length > 0) field.label = textNodes[0];
                    }
                }
                
                formFields.push(field);
            });
            
            return JSON.stringify(formFields);
        })();
        """
    }
    
    // MARK: - Detect Total Fields
    func getFieldDetectionScript() -> String {
        return """
        (function() {
            const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]), textarea, select');
            return {
                total: inputs.length,
                filled: Array.from(inputs).filter(inp => inp.value && inp.value.trim() !== '').length
            };
        })();
        """
    }
    
    // MARK: - Auto-Fill JavaScript
    func getAutoFillScript(formData: [String: String]) -> String {
        // Create a mapping of common field names to user data
        let fieldMappings: [String: String] = [
            "name": formData["fullName"] ?? "",
            "full_name": formData["fullName"] ?? "",
            "first_name": formData["firstName"] ?? "",
            "last_name": formData["lastName"] ?? "",
            "email": formData["email"] ?? "",
            "phone": formData["phone"] ?? "",
            "phone_number": formData["phone"] ?? "",
            "location": formData["location"] ?? "",
            "city": formData["location"] ?? "",
            "address": formData["location"] ?? "",
            "linkedin": formData["linkedIn"] ?? "",
            "linkedin_url": formData["linkedIn"] ?? "",
            "github": formData["github"] ?? "",
            "portfolio": formData["portfolio"] ?? "",
            "resume": formData["resumeUrl"] ?? "",
            "cover_letter": formData["coverLetter"] ?? "",
            "message": formData["coverLetter"] ?? "",
            "why_work_here": formData["coverLetter"] ?? ""
        ]
        
        // Build JavaScript to fill forms
        var script = """
        (function() {
            const formData = \(try! JSONSerialization.data(withJSONObject: fieldMappings).base64EncodedString());
            const data = JSON.parse(atob(formData));
            
            // Function to match field names
            function matchesField(field, value) {
                const fieldLower = field.toLowerCase();
                const valueLower = value.toLowerCase();
                return fieldLower.includes(valueLower) || valueLower.includes(fieldLower);
            }
            
            // Find and fill all input fields
            const inputs = document.querySelectorAll('input, textarea, select');
            let filledCount = 0;
            
            inputs.forEach(input => {
                const name = (input.name || '').toLowerCase();
                const id = (input.id || '').toLowerCase();
                const placeholder = (input.placeholder || '').toLowerCase();
                const type = input.type.toLowerCase();
                
                // Skip hidden, submit, and button inputs
                if (type === 'hidden' || type === 'submit' || type === 'button' || type === 'checkbox' || type === 'radio') {
                    return;
                }
                
                // Try to match field
                let valueToFill = null;
                
                // Check name
                for (const [key, value] of Object.entries(data)) {
                    if (value && (matchesField(name, key) || matchesField(id, key) || matchesField(placeholder, key))) {
                        valueToFill = value;
                        break;
                    }
                }
                
                // Fill the field
                if (valueToFill && !input.value) {
                    input.value = valueToFill;
                    input.dispatchEvent(new Event('input', { bubbles: true }));
                    input.dispatchEvent(new Event('change', { bubbles: true }));
                    filledCount++;
                }
            });
            
            // Scroll to first filled field
            if (filledCount > 0) {
                const firstFilled = document.querySelector('input[value]:not([value=""]), textarea[value]:not([value=""])');
                if (firstFilled) {
                    firstFilled.scrollIntoView({ behavior: 'smooth', block: 'center' });
                }
            }
            
            return {
                success: true,
                filled: filledCount,
                message: `Filled ${filledCount} fields`
            };
        })();
        """
        
        return script
    }
    
    // MARK: - Detect ATS System
    func detectATSSystem(url: String) -> ATSSystem? {
        let urlLower = url.lowercased()
        
        // Common ATS systems
        if urlLower.contains("workday") || urlLower.contains("myworkdayjobs") {
            return .workday
        } else if urlLower.contains("greenhouse") || urlLower.contains("boards.greenhouse.io") {
            return .greenhouse
        } else if urlLower.contains("lever") || urlLower.contains("lever.co") {
            return .lever
        } else if urlLower.contains("smartrecruiters") {
            return .smartrecruiters
        } else if urlLower.contains("jobvite") {
            return .jobvite
        } else if urlLower.contains("icims") {
            return .icims
        } else if urlLower.contains("taleo") {
            return .taleo
        } else if urlLower.contains("bamboohr") {
            return .bamboohr
        }
        
        return nil
    }
    
    // MARK: - Get ATS-Specific Script
    func getATSSpecificScript(ats: ATSSystem, formData: [String: String]) -> String {
        // ATS-specific form filling logic
        // Each ATS has different form structures
        switch ats {
        case .workday:
            return getWorkdayScript(formData: formData)
        case .greenhouse:
            return getGreenhouseScript(formData: formData)
        case .lever:
            return getLeverScript(formData: formData)
        default:
            return getAutoFillScript(formData: formData)
        }
    }
    
    // MARK: - ATS-Specific Scripts
    private func getWorkdayScript(formData: [String: String]) -> String {
        // Workday-specific selectors and logic
        return getAutoFillScript(formData: formData) + """
        
        // Workday-specific handling
        setTimeout(() => {
            // Workday often uses iframes
            const iframes = document.querySelectorAll('iframe');
            iframes.forEach(iframe => {
                try {
                    const iframeDoc = iframe.contentDocument || iframe.contentWindow.document;
                    const inputs = iframeDoc.querySelectorAll('input, textarea');
                    // Fill iframe inputs similarly
                } catch (e) {
                    console.log('Cannot access iframe:', e);
                }
            });
        }, 1000);
        """
    }
    
    private func getGreenhouseScript(formData: [String: String]) -> String {
        return getAutoFillScript(formData: formData) + """
        
        // Greenhouse-specific handling
        setTimeout(() => {
            // Greenhouse uses specific class names
            document.querySelectorAll('.field input, .field textarea').forEach(input => {
                // Additional Greenhouse-specific logic
            });
        }, 1000);
        """
    }
    
    private func getLeverScript(formData: [String: String]) -> String {
        return getAutoFillScript(formData: formData)
    }
}

// MARK: - ATS System Enum
enum ATSSystem: String {
    case workday = "Workday"
    case greenhouse = "Greenhouse"
    case lever = "Lever"
    case smartrecruiters = "SmartRecruiters"
    case jobvite = "Jobvite"
    case icims = "iCIMS"
    case taleo = "Taleo"
    case bamboohr = "BambooHR"
    case generic = "Generic"
}


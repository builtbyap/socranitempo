//
//  AutoApplyView.swift
//  surgeapp
//
//  Created by Abong Mabo on 12/12/25.
//

import SwiftUI
import WebKit
import Combine

struct AutoApplyView: View {
    let job: JobPost
    let applicationData: ApplicationData
    @Environment(\.dismiss) var dismiss
    @StateObject private var webViewModel = WebViewModel()
    @State private var isGeneratingCoverLetter = false
    @State private var isFillingForms = false
    @State private var filledFieldsCount = 0
    @State private var currentStep: AutomationStep = .loading
    @State private var errorMessage: String?
    @State private var aiCoverLetter: String = ""
    @State private var detectedATS: ATSSystem?
    @State private var totalFields = 0
    @State private var autoSubmitAttempted = false
    @State private var detectedQuestions: [DetectedQuestion] = []
    @State private var currentQuestionIndex = 0
    @State private var showingQuestion = false
    @State private var questionAnswers: [Int: String] = [:]
    
    enum AutomationStep {
        case loading
        case detecting
        case generatingCoverLetter
        case fillingForms
        case submitting
        case review
        case completed
        case error
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Success Message
                if currentStep == .completed {
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Application Submitted!")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("Your application has been successfully submitted.")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
                
                // Progress Indicator
                if currentStep != .review && currentStep != .completed {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text(stepDescription)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        if currentStep == .fillingForms && filledFieldsCount > 0 {
                            Text("Filled \(filledFieldsCount) fields")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
                
                // Web View
                if currentStep == .review || currentStep == .fillingForms || currentStep == .submitting {
                    WebViewContainer(viewModel: webViewModel)
                        .onReceive(webViewModel.$filledFieldsCount) { count in
                            filledFieldsCount = count
                        }
                        .onReceive(webViewModel.$totalFieldsDetected) { total in
                            totalFields = total
                        }
                }
                
                // Error Message
                if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        
                        Text("Error")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Retry") {
                            startAutomation()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
            .navigationTitle("Auto Apply")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if currentStep == .review {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Submit") {
                            Task {
                                await autoSubmitApplication()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
                
                if currentStep == .completed {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .onAppear {
                startAutomation()
            }
            .sheet(isPresented: $showingQuestion) {
                if !detectedQuestions.isEmpty {
                    // Convert DetectedQuestion to PendingQuestion for compatibility
                    let pendingQuestions = detectedQuestions.map { detected in
                        PendingQuestion(
                            id: detected.id,
                            fieldType: detected.fieldType,
                            inputType: detected.inputType,
                            name: detected.name,
                            question: detected.question,
                            options: detected.options.isEmpty ? nil : detected.options,
                            required: detected.required,
                            selector: detected.selector
                        )
                    }
                    
                    InlineQuestionAnswerView(
                        questions: pendingQuestions,
                        jobTitle: job.title,
                        company: job.company,
                        onAnswersSubmitted: { answers in
                            // Fill all answers into the form
                            for (questionId, answer) in answers {
                                let fillScript = QuestionDetectionService.shared.fillAnswerScript(
                                    questionIndex: questionId,
                                    answer: answer
                                )
                                webViewModel.executeScript(fillScript)
                            }
                            
                            // Wait a moment for answers to be filled
                            Task {
                                try? await Task.sleep(nanoseconds: 1_000_000_000)
                                showingQuestion = false
                                await autoSubmitApplication()
                            }
                        }
                    )
                }
            }
        }
    }
    
    private var stepDescription: String {
        switch currentStep {
        case .loading:
            return "Loading job application page..."
        case .detecting:
            return "Detecting application system..."
        case .generatingCoverLetter:
            return "Generating AI cover letter..."
        case .fillingForms:
            return "Filling application forms..."
        case .submitting:
            return "Submitting application..."
        case .review:
            return "Review and submit"
        case .completed:
            return "Application submitted!"
        case .error:
            return "An error occurred"
        }
    }
    
    private func startAutomation() {
        guard let jobURL = job.url, let url = URL(string: jobURL) else {
            errorMessage = "Invalid job URL"
            currentStep = .error
            return
        }
        
        Task {
            // Step 1: Load the page
            await MainActor.run {
                currentStep = .loading
                webViewModel.loadURL(url)
            }
            
            // Wait for page to load
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            
            // Step 2: Detect ATS
            await MainActor.run {
                currentStep = .detecting
                detectedATS = WebAutomationService.shared.detectATSSystem(url: jobURL)
            }
            
            // Step 3: Generate AI cover letter
            await MainActor.run {
                currentStep = .generatingCoverLetter
                isGeneratingCoverLetter = true
            }
            
            do {
                let profileData = SimpleApplyService.shared.getUserProfileData()
                let generatedLetter = try await AICoverLetterService.shared.generateCoverLetter(
                    for: job,
                    userProfile: profileData,
                    resumeData: applicationData.resumeData
                )
                
                await MainActor.run {
                    aiCoverLetter = generatedLetter
                    isGeneratingCoverLetter = false
                }
            } catch {
                await MainActor.run {
                    // Use fallback cover letter if AI generation fails
                    aiCoverLetter = applicationData.coverLetter
                    isGeneratingCoverLetter = false
                    print("⚠️ AI cover letter generation failed: \(error.localizedDescription)")
                }
            }
            
            // Step 4: Detect questions first
            await MainActor.run {
                currentStep = .fillingForms
                isFillingForms = true
            }
            
            // Detect questions that need user input
            let questionDetectionScript = QuestionDetectionService.shared.detectQuestions()
            await MainActor.run {
                webViewModel.executeScript(questionDetectionScript)
            }
            
            // Wait for question detection
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Get detected questions (we'll need to parse from web view response)
            // For now, we'll detect questions after initial form fill
            
            // Step 5: Fill forms with known data
            await MainActor.run {
                currentStep = .fillingForms
                isFillingForms = true
            }
            
            // Prepare form data
            var formData = FormAutoFillHelper.shared.generateBrowserExtensionFormat(applicationData: applicationData)
            formData["coverLetter"] = aiCoverLetter
            formData["fullName"] = applicationData.fullName
            formData["firstName"] = applicationData.fullName.components(separatedBy: " ").first ?? ""
            formData["lastName"] = applicationData.fullName.components(separatedBy: " ").last ?? ""
            
            // Get appropriate script
            let script: String
            if let ats = detectedATS {
                script = WebAutomationService.shared.getATSSpecificScript(ats: ats, formData: formData)
            } else {
                script = WebAutomationService.shared.getAutoFillScript(formData: formData)
            }
            
            // Execute script
            await MainActor.run {
                webViewModel.executeScript(script)
            }
            
            // Step 6: Detect and handle questions
            await detectAndHandleQuestions()
            
            // Wait for forms to fill and check progress
            for attempt in 0..<8 { // Check up to 8 times (8 seconds max)
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Check if all fields are filled
                let checkScript = WebAutomationService.shared.getFieldDetectionScript()
                await MainActor.run {
                    webViewModel.executeScript(checkScript)
                }
                
                // Wait a bit for the script result
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                
                // If most fields filled (80% or more), proceed to submit
                if totalFields > 0 && filledFieldsCount >= Int(Double(totalFields) * 0.8) {
                    break
                }
                
                // If we've filled at least some fields and waited enough, proceed
                if attempt >= 5 && filledFieldsCount > 0 {
                    break
                }
            }
            
            // After initial fill, check for questions again
            await detectAndHandleQuestions()
            
            // Step 5: Auto-submit
            await MainActor.run {
                currentStep = .submitting
                isFillingForms = false
            }
            
            // Wait a moment for any final field updates
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Auto-submit the application
            await autoSubmitApplication()
        }
    }
    
    // MARK: - Question Detection and Handling
    private func detectAndHandleQuestions() async {
        // Detect questions
        let questionScript = QuestionDetectionService.shared.detectQuestions()
        
        // Execute script and get result
        let result = await webViewModel.executeScriptAndGetResult(questionScript)
        
        guard let jsonString = result as? String,
              let jsonData = jsonString.data(using: .utf8),
              let questions = try? JSONDecoder().decode([DetectedQuestion].self, from: jsonData) else {
            // No questions detected or parsing failed, continue
            return
        }
        
        // Filter out questions that already have answers or are not meaningful
        let unansweredQuestions = questions.filter { question in
            // Show required questions and questions with clear text
            return (question.required || question.question.count > 10) && 
                   !question.question.lowercased().contains("email") && // We already have email
                   !question.question.lowercased().contains("name") && // We already have name
                   !question.question.lowercased().contains("phone") // We already have phone
        }
        
        guard !unansweredQuestions.isEmpty else {
            return // No questions to answer
        }
        
        await MainActor.run {
            detectedQuestions = unansweredQuestions
            currentQuestionIndex = 0
            showingQuestion = true
        }
    }
    
    private func handleQuestionAnswer(_ answer: String) {
        guard currentQuestionIndex < detectedQuestions.count else { return }
        
        let question = detectedQuestions[currentQuestionIndex]
        questionAnswers[question.id] = answer
        
        // Fill the answer into the form
        let fillScript = QuestionDetectionService.shared.fillAnswerScript(
            questionIndex: question.id,
            answer: answer
        )
        
        webViewModel.executeScript(fillScript)
        
        // Move to next question or continue
        if currentQuestionIndex < detectedQuestions.count - 1 {
            // Show next question after a brief delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await MainActor.run {
                    currentQuestionIndex += 1
                    // Sheet will automatically show next question
                }
            }
        } else {
            // All questions answered, continue with submission
            showingQuestion = false
            Task {
                // Wait a moment for answer to be filled
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await autoSubmitApplication()
            }
        }
    }
    
    private func autoSubmitApplication() async {
        await MainActor.run {
            autoSubmitAttempted = true
            currentStep = .submitting
        }
        
        // Try to find and click submit button
        let submitScript = """
        (function() {
            // Try multiple strategies to find submit button
            const strategies = [
                // Strategy 1: Standard submit buttons
                () => document.querySelector('button[type="submit"]'),
                () => document.querySelector('input[type="submit"]'),
                
                // Strategy 2: Buttons with submit-related text
                () => Array.from(document.querySelectorAll('button')).find(btn => {
                    const text = btn.textContent.toLowerCase();
                    return text.includes('submit') || text.includes('apply') || text.includes('send');
                }),
                
                // Strategy 3: Buttons with submit-related IDs/classes
                () => document.querySelector('button#submit, button.submit, input#submit, input.submit'),
                () => document.querySelector('[data-testid*="submit"], [data-testid*="apply"]'),
                
                // Strategy 4: Form submit
                () => {
                    const forms = document.querySelectorAll('form');
                    if (forms.length === 1) {
                        return forms[0];
                    }
                    return null;
                },
                
                // Strategy 5: Buttons with specific aria labels
                () => Array.from(document.querySelectorAll('button')).find(btn => {
                    const ariaLabel = btn.getAttribute('aria-label')?.toLowerCase() || '';
                    return ariaLabel.includes('submit') || ariaLabel.includes('apply');
                })
            ];
            
            for (const strategy of strategies) {
                const element = strategy();
                if (element) {
                    // Scroll to element
                    element.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    
                    // Wait a bit then click
                    setTimeout(() => {
                        if (element.tagName === 'FORM') {
                            element.submit();
                        } else {
                            element.click();
                        }
                    }, 500);
                    
                    return {
                        success: true,
                        message: 'Submit button clicked',
                        element: element.tagName + (element.id ? '#' + element.id : '')
                    };
                }
            }
            
            return {
                success: false,
                message: 'Submit button not found'
            };
        })();
        """
        
        // Execute submit script
        await MainActor.run {
            webViewModel.executeScript(submitScript)
        }
        
        // Wait for submission to process
        try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
        
        // Save application to database
        do {
            try await SimpleApplyService.shared.submitApplication(job: job, applicationData: applicationData)
            
            await MainActor.run {
                currentStep = .completed
                
                // Show success message
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Application submitted on website, but failed to save: \(error.localizedDescription)"
                currentStep = .error
            }
        }
    }
    
}

// MARK: - Web View Model
class WebViewModel: NSObject, ObservableObject, WKNavigationDelegate {
    @Published var filledFieldsCount: Int = 0
    @Published var totalFieldsDetected: Int = 0
    var webView: WKWebView?
    
    func loadURL(_ url: URL) {
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self, name: "automationHandler")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView
        
        webView.load(URLRequest(url: url))
    }
    
    func executeScript(_ script: String) {
        webView?.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("❌ Script error: \(error.localizedDescription)")
            } else if let result = result as? [String: Any] {
                if let filled = result["filled"] as? Int {
                    DispatchQueue.main.async {
                        self.filledFieldsCount = filled
                    }
                }
                if let total = result["total"] as? Int {
                    DispatchQueue.main.async {
                        self.totalFieldsDetected = total
                    }
                }
            }
        }
    }
    
    func executeScriptAndGetResult(_ script: String) async -> Any? {
        return await withCheckedContinuation { continuation in
            webView?.evaluateJavaScript(script) { result, error in
                if let error = error {
                    print("❌ Script error: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                } else {
                    continuation.resume(returning: result)
                }
            }
        }
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ Page loaded")
    }
}

extension WebViewModel: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "automationHandler" {
            if let data = message.body as? [String: Any] {
                if let filled = data["filled"] as? Int {
                    DispatchQueue.main.async {
                        self.filledFieldsCount = filled
                    }
                }
            }
        }
    }
}

// MARK: - Web View Container
struct WebViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: WebViewModel
    
    func makeUIView(context: Context) -> WKWebView {
        if viewModel.webView == nil {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.add(viewModel, name: "automationHandler")
            
            let webView = WKWebView(frame: .zero, configuration: configuration)
            webView.navigationDelegate = viewModel
            viewModel.webView = webView
        }
        
        return viewModel.webView!
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // Updates handled by view model
    }
}


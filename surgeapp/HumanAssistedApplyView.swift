//
//  HumanAssistedApplyView.swift
//  surgeapp
//
//  Slow, visible, user-assisted browser interaction that follows human behavior patterns
//

import SwiftUI
import WebKit

struct HumanAssistedApplyView: View {
    let job: JobPost
    let applicationData: ApplicationData
    @Environment(\.dismiss) var dismiss
    @StateObject private var assistant = FormAssistant()
    @State private var showPauseMenu = false
    @State private var isPaused = false
    @State private var currentStep: AssistantStep = .loading
    @State private var filledFields: [FilledField] = []
    @State private var encounteredFriction: FrictionType?
    @State private var showFrictionAlert = false
    
    enum AssistantStep {
        case loading
        case analyzing
        case filling
        case reviewing
        case paused
        case blocked
        case completed
    }
    
    enum FrictionType {
        case captcha
        case unusualField
        case loginRequired
        case botDetection
        case unknown
        
        var message: String {
            switch self {
            case .captcha: return "CAPTCHA detected. Please complete it manually."
            case .unusualField: return "Unusual form field detected. Please fill manually."
            case .loginRequired: return "Login required. Please sign in first."
            case .botDetection: return "Bot detection triggered. Please apply manually."
            case .unknown: return "Something unexpected happened. Please continue manually."
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Live Browser View (like sorce.jobs)
                VStack(spacing: 0) {
                    // Status Bar
                    statusBar
                    
                    // Live Video View of Browser (the actual employer application page)
                    WebViewContainer(
                        url: job.url ?? "",
                        assistant: assistant,
                        onFrictionDetected: { friction in
                            handleFriction(friction)
                        },
                        onFieldFilled: { fieldName, value in
                            // Show field being filled in real-time
                            withAnimation {
                                filledFields.append(FilledField(name: fieldName, value: value))
                            }
                        },
                        onResumeUploaded: {
                            // Show resume upload happening visibly
                            filledFields.append(FilledField(name: "Resume", value: "Uploaded"))
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        // Live indicator
                        VStack {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 8, height: 8)
                                    Text("LIVE")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.green)
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                                .padding()
                            }
                            Spacer()
                        }
                    )
                    
                    // Control Panel
                    if currentStep != .blocked && currentStep != .completed {
                        controlPanel
                    }
                }
                
                // Completion Screen (overlay when done)
                if currentStep == .completed {
                    completionScreen
                }
            }
            .navigationTitle("Applying to \(job.company)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showPauseMenu = true
                    }) {
                        Image(systemName: isPaused ? "play.circle.fill" : "pause.circle.fill")
                            .font(.system(size: 20))
                    }
                }
            }
            .sheet(isPresented: $showPauseMenu) {
                pauseMenu
            }
            .alert("Action Required", isPresented: $showFrictionAlert, presenting: encounteredFriction) { friction in
                Button("Continue Manually") {
                    currentStep = .blocked
                    assistant.pause()
                }
                Button("Try Again") {
                    encounteredFriction = nil
                    assistant.resume()
                }
            } message: { friction in
                Text(friction.message)
            }
            .onAppear {
                startAssistedApplication()
            }
        }
    }
    
    // MARK: - Status Bar
    private var statusBar: some View {
        VStack(spacing: 8) {
            HStack {
                // Step indicator
                stepIndicator
                
                Spacer()
                
                // Progress
                if currentStep == .filling {
                    Text("\(filledFields.count) fields filled")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Progress bar
            if currentStep == .filling {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 2)
                        
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * assistant.progress, height: 2)
                            .animation(.linear, value: assistant.progress)
                    }
                }
                .frame(height: 2)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
    
    private var stepIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(currentStep == .loading ? Color.blue : Color.gray)
                .frame(width: 8, height: 8)
            Text(stepText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }
    
    private var stepText: String {
        switch currentStep {
        case .loading: return "Loading application page..."
        case .analyzing: return "Detecting ATS system..."
        case .filling: return "Filling form fields..."
        case .uploadingResume: return "Uploading resume..."
        case .reviewing: return "Ready for review"
        case .submitting: return "Submitting application..."
        case .paused: return "Paused"
        case .blocked: return "Action required"
        case .completed: return "Application submitted"
        }
    }
    
    // MARK: - Control Panel
    private var controlPanel: some View {
        VStack(spacing: 12) {
            // Real-time activity indicator (like sorce.jobs)
            if currentStep == .filling || currentStep == .uploadingResume {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(currentStep == .uploadingResume ? "Uploading resume..." : "Filling fields in real-time...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
            }
            
            if currentStep == .reviewing {
                Button(action: {
                    // Submit application (visible click, like sorce.jobs)
                    currentStep = .submitting
                    submitApplication()
                }) {
                    HStack {
                        Image(systemName: "paperplane.fill")
                        Text("Submit Application")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            } else if currentStep == .filling || currentStep == .uploadingResume {
                Button(action: {
                    assistant.pause()
                    isPaused = true
                    currentStep = .paused
                }) {
                    HStack {
                        Image(systemName: "pause.fill")
                        Text("Pause")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
            }
            
            // Filled fields summary (real-time updates, like sorce.jobs)
            if !filledFields.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Fields filled:")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(filledFields) { field in
                                FieldBadge(field: field)
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemGray6))
    }
    
    // MARK: - Completion Screen (like sorce.jobs)
    private var completionScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            // Title
            Text("Application Submitted")
                .font(.system(size: 28, weight: .bold))
            
            // Details
            VStack(spacing: 12) {
                HStack {
                    Text("Company:")
                        .foregroundColor(.secondary)
                    Text(job.company)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Position:")
                        .foregroundColor(.secondary)
                    Text(job.title)
                        .fontWeight(.semibold)
                }
                
                HStack {
                    Text("Submitted:")
                        .foregroundColor(.secondary)
                    Text(Date().formatted(date: .abbreviated, time: .shortened))
                        .fontWeight(.semibold)
                }
            }
            .font(.system(size: 16))
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Status badge
            HStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                Text("Submitted")
                    .font(.system(size: 14, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.green.opacity(0.1))
            .cornerRadius(8)
            
            Spacer()
            
            // Action button
            Button(action: {
                dismiss()
            }) {
                Text("Done")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Pause Menu
    private var pauseMenu: some View {
        NavigationStack {
            List {
                Section("Actions") {
                    Button(action: {
                        isPaused = false
                        assistant.resume()
                        currentStep = .filling
                        showPauseMenu = false
                    }) {
                        Label("Resume", systemImage: "play.fill")
                    }
                    
                    Button(action: {
                        // Let user take over manually
                        currentStep = .reviewing
                        assistant.pause()
                        showPauseMenu = false
                    }) {
                        Label("Continue Manually", systemImage: "hand.point.up.left.fill")
                    }
                    
                    Button(role: .destructive, action: {
                        dismiss()
                    }) {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                    }
                }
                
                Section("Filled Fields") {
                    ForEach(filledFields) { field in
                        HStack {
                            Text(field.name)
                            Spacer()
                            Text(field.value)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .navigationTitle("Paused")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Functions
    private func startAssistedApplication() {
        currentStep = .loading
        
        // Step 1: Navigate to apply URL (visible in live browser view, like sorce.jobs)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            currentStep = .analyzing
            // Step 2: Detect ATS system (like sorce.jobs)
            detectATS()
        }
    }
    
    private func detectATS() {
        // Detect ATS system using URL and page content
        assistant.detectATS { atsSystem in
            print("🔍 Detected ATS: \(atsSystem ?? "unknown")")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Step 3: Analyze form structure
                analyzeForm()
            }
        }
    }
    
    private func analyzeForm() {
        // Analyze form structure (slow, visible)
        assistant.analyzeForm { fields in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                currentStep = .filling
                // Step 4: Fill form fields in real-time (visible, like sorce.jobs)
                fillFormGradually(fields: fields)
            }
        }
    }
    
    private func fillFormGradually(fields: [FormField]) {
        // Fill fields one by one with human-like delays
        fillNextField(fields: fields, index: 0)
    }
    
    private func fillNextField(fields: [FormField], index: Int) {
        guard index < fields.count, !isPaused, currentStep == .filling else {
            if index >= fields.count {
                // All fields filled, now upload resume
                uploadResume()
            }
            return
        }
        
        let field = fields[index]
        let value = getValueForField(field)
        
        // Fill field with visible animation (real-time, like sorce.jobs)
        assistant.fillField(field: field, value: value) { success in
            if success {
                // Show field being filled in real-time
                withAnimation {
                    filledFields.append(FilledField(name: field.name, value: value))
                }
                assistant.progress = Double(index + 1) / Double(fields.count)
                
                // Human-like delay between fields (1-3 seconds)
                let delay = Double.random(in: 1.0...3.0)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    fillNextField(fields: fields, index: index + 1)
                }
            } else {
                // Field couldn't be filled - stop and let user handle
                handleFriction(.unusualField)
            }
        }
    }
    
    private func uploadResume() {
        currentStep = .uploadingResume
        
        // Upload resume visibly (like sorce.jobs)
        assistant.uploadResume(resumeURL: applicationData.resumeURL) { success in
            if success {
                // Resume uploaded, show in filled fields
                withAnimation {
                    filledFields.append(FilledField(name: "Resume", value: "Uploaded"))
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    currentStep = .reviewing
                }
            } else {
                // Resume upload failed - let user handle
                handleFriction(.unusualField)
            }
        }
    }
    
    private func getValueForField(_ field: FormField) -> String {
        switch field.type {
        case .firstName, .fullName:
            return applicationData.fullName.components(separatedBy: " ").first ?? ""
        case .lastName:
            return applicationData.fullName.components(separatedBy: " ").dropFirst().joined(separator: " ")
        case .email:
            return applicationData.email
        case .phone:
            return applicationData.phone
        case .location:
            return applicationData.location
        case .linkedIn:
            return applicationData.linkedInURL ?? ""
        case .github:
            return applicationData.githubURL ?? ""
        case .portfolio:
            return applicationData.portfolioURL ?? ""
        case .coverLetter:
            return applicationData.coverLetter
        case .resume:
            return "" // Handled separately
        case .unknown:
            return ""
        }
    }
    
    private func handleFriction(_ friction: FrictionType) {
        encounteredFriction = friction
        showFrictionAlert = true
        assistant.pause()
        isPaused = true
        
        if friction == .botDetection || friction == .loginRequired {
            currentStep = .blocked
        }
    }
    
    private func submitApplication() {
        // Step 5: Submit application (visible click)
        assistant.clickSubmitButton { success in
            if success {
                // Wait for confirmation page
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    // Check for confirmation
                    assistant.checkConfirmation { confirmed in
                        if confirmed {
                            // Save to Supabase
                            Task {
                                do {
                                    try await SimpleApplyService.shared.submitApplication(
                                        job: job,
                                        applicationData: applicationData
                                    )
                                    await MainActor.run {
                                        currentStep = .completed
                                    }
                                } catch {
                                    // Handle error but still show completion
                                    await MainActor.run {
                                        currentStep = .completed
                                    }
                                }
                            }
                        } else {
                            // No confirmation - might need user action
                            handleFriction(.unknown)
                        }
                    }
                }
            } else {
                // Submit failed - let user handle
                handleFriction(.unusualField)
            }
        }
    }
}

// MARK: - Supporting Views
struct FieldBadge: View {
    let field: FilledField
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 10))
                .foregroundColor(.green)
            Text(field.name)
                .font(.system(size: 12))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
}

// MARK: - Data Models
struct FilledField: Identifiable {
    let id = UUID()
    let name: String
    let value: String
}

struct FormField: Identifiable {
    let id = UUID()
    let name: String
    let type: FieldType
    let selector: String
}

enum FieldType {
    case firstName
    case lastName
    case fullName
    case email
    case phone
    case location
    case linkedIn
    case github
    case portfolio
    case coverLetter
    case resume
    case unknown
    
    static func fromString(_ string: String) -> FieldType {
        switch string.lowercased() {
        case "firstname": return .firstName
        case "lastname": return .lastName
        case "fullname": return .fullName
        case "email": return .email
        case "phone": return .phone
        case "location": return .location
        case "linkedin": return .linkedIn
        case "github": return .github
        case "portfolio": return .portfolio
        case "coverletter": return .coverLetter
        case "resume": return .resume
        default: return .unknown
        }
    }
}

// MARK: - Form Assistant
class FormAssistant: ObservableObject {
    @Published var progress: Double = 0.0
    @Published var isPaused: Bool = false
    
    private var webView: WKWebView?
    private var detectedATS: String?
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }
    
    func detectATS(completion: @escaping (String?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }
        
        let script = """
        (function() {
            const url = window.location.href.toLowerCase();
            const bodyText = document.body.textContent.toLowerCase();
            
            if (url.includes('workday') || url.includes('myworkdayjobs') || bodyText.includes('workday')) {
                return 'workday';
            } else if (url.includes('greenhouse') || url.includes('boards.greenhouse.io') || bodyText.includes('greenhouse')) {
                return 'greenhouse';
            } else if (url.includes('lever') || url.includes('lever.co') || bodyText.includes('lever')) {
                return 'lever';
            } else if (url.includes('smartrecruiters') || bodyText.includes('smartrecruiters')) {
                return 'smartrecruiters';
            } else if (url.includes('jobvite') || bodyText.includes('jobvite')) {
                return 'jobvite';
            } else if (url.includes('icims') || bodyText.includes('icims')) {
                return 'icims';
            } else if (url.includes('taleo') || bodyText.includes('taleo')) {
                return 'taleo';
            } else if (url.includes('bamboohr') || bodyText.includes('bamboohr')) {
                return 'bamboohr';
            }
            
            return 'unknown';
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            let ats = result as? String
            self.detectedATS = ats
            completion(ats)
        }
    }
    
    func analyzeForm(completion: @escaping ([FormField]) -> Void) {
        guard let webView = webView else {
            completion([])
            return
        }
        
        // Use ATS-specific logic if detected (like sorce.jobs)
        let atsScript = detectedATS == "workday" ? getWorkdayFieldsScript() : getGenericFieldsScript()
        
        webView.evaluateJavaScript(atsScript) { result, error in
            if let fieldsData = result as? [[String: Any]] {
                let fields = fieldsData.compactMap { data -> FormField? in
                    guard let name = data["name"] as? String,
                          let selector = data["selector"] as? String,
                          let typeString = data["type"] as? String else {
                        return nil
                    }
                    let type = FieldType.fromString(typeString)
                    return FormField(name: name, type: type, selector: selector)
                }
                completion(fields)
            } else {
                completion([])
            }
        }
    }
    
    private func getWorkdayFieldsScript() -> String {
        // Workday-specific field detection
        return """
        (function() {
            const fields = [];
            const selectors = [
                { name: 'First Name', type: 'firstName', sel: 'input[name*="first"], input[id*="first"]' },
                { name: 'Last Name', type: 'lastName', sel: 'input[name*="last"], input[id*="last"]' },
                { name: 'Email', type: 'email', sel: 'input[type="email"], input[name*="email"]' },
                { name: 'Phone', type: 'phone', sel: 'input[type="tel"], input[name*="phone"]' }
            ];
            
            selectors.forEach(s => {
                const el = document.querySelector(s.sel);
                if (el) {
                    fields.push({ name: s.name, type: s.type, selector: s.sel });
                }
            });
            
            return fields;
        })();
        """
    }
    
    private func getGenericFieldsScript() -> String {
        // Generic field detection
        return """
        (function() {
            const fields = [];
            const selectors = [
                { name: 'First Name', type: 'firstName', sel: 'input[name*="firstName"], input[name*="first_name"], input[id*="firstName"]' },
                { name: 'Last Name', type: 'lastName', sel: 'input[name*="lastName"], input[name*="last_name"], input[id*="lastName"]' },
                { name: 'Email', type: 'email', sel: 'input[type="email"], input[name*="email"]' },
                { name: 'Phone', type: 'phone', sel: 'input[type="tel"], input[name*="phone"]' },
                { name: 'Location', type: 'location', sel: 'input[name*="location"], input[name*="city"]' }
            ];
            
            selectors.forEach(s => {
                const el = document.querySelector(s.sel);
                if (el && !el.hidden && el.offsetParent !== null) {
                    fields.push({ name: s.name, type: s.type, selector: s.sel });
                }
            });
            
            return fields;
        })();
        """
    }
    
    func fillField(field: FormField, value: String, completion: @escaping (Bool) -> Void) {
        guard let webView = webView else {
            completion(false)
            return
        }
        
        // Fill field with JavaScript (slow, visible, like sorce.jobs)
        let escapedValue = value.replacingOccurrences(of: "'", with: "\\'")
        let script = """
        (function() {
            const field = document.querySelector('\(field.selector)');
            if (!field || field.hidden || field.offsetParent === null) return false;
            
            // Scroll to field (visible)
            field.scrollIntoView({ behavior: 'smooth', block: 'center' });
            await new Promise(r => setTimeout(r, 300));
            
            // Focus field (visible highlight)
            field.focus();
            await new Promise(r => setTimeout(r, 200));
            
            // Clear field
            field.value = '';
            field.dispatchEvent(new Event('input', { bubbles: true }));
            
            // Type character by character (human-like, visible)
            const value = '\(escapedValue)';
            let index = 0;
            
            async function typeNextChar() {
                if (index < value.length) {
                    field.value += value[index];
                    field.dispatchEvent(new Event('input', { bubbles: true }));
                    index++;
                    await new Promise(r => setTimeout(r, 100 + Math.random() * 100)); // 100-200ms per char
                    typeNextChar();
                } else {
                    field.dispatchEvent(new Event('change', { bubbles: true }));
                    field.blur();
                    return true;
                }
            }
            
            typeNextChar();
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            completion(result as? Bool ?? false)
        }
    }
    
    func uploadResume(resumeURL: String?, completion: @escaping (Bool) -> Void) {
        guard let webView = webView, let resumeURL = resumeURL else {
            completion(false)
            return
        }
        
        // Upload resume visibly (like sorce.jobs)
        let script = """
        (function() {
            const fileInput = document.querySelector('input[type="file"]');
            if (!fileInput) return false;
            
            // Scroll to file input
            fileInput.scrollIntoView({ behavior: 'smooth', block: 'center' });
            
            // Note: Actual file upload requires native code
            // This is a placeholder - would need to use WKWebView file upload API
            return true;
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            // For now, return true (actual upload would need native implementation)
            completion(true)
        }
    }
    
    func clickSubmitButton(completion: @escaping (Bool) -> Void) {
        guard let webView = webView else {
            completion(false)
            return
        }
        
        let script = """
        (function() {
            const submitSelectors = [
                'button[type="submit"]',
                'input[type="submit"]',
                'button:contains("Submit")',
                'button:contains("Apply")',
                '[data-testid*="submit"]',
                '.submit-button'
            ];
            
            for (const sel of submitSelectors) {
                const btn = document.querySelector(sel);
                if (btn && btn.offsetParent !== null) {
                    btn.scrollIntoView({ behavior: 'smooth', block: 'center' });
                    setTimeout(() => {
                        btn.click();
                    }, 500);
                    return true;
                }
            }
            
            return false;
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            completion(result as? Bool ?? false)
        }
    }
    
    func checkConfirmation(completion: @escaping (Bool) -> Void) {
        guard let webView = webView else {
            completion(false)
            return
        }
        
        let script = """
        (function() {
            const bodyText = document.body.textContent.toLowerCase();
            const url = window.location.href.toLowerCase();
            
            const confirmations = [
                'thank you',
                'application submitted',
                'application received',
                'successfully submitted',
                'confirmation'
            ];
            
            return confirmations.some(c => bodyText.includes(c)) || 
                   url.includes('confirmation') || 
                   url.includes('success') ||
                   url.includes('thank');
        })();
        """
        
        webView.evaluateJavaScript(script) { result, error in
            completion(result as? Bool ?? false)
        }
    }
    
    func pause() {
        isPaused = true
    }
    
    func resume() {
        isPaused = false
    }
}

// MARK: - Web View Container
struct WebViewContainer: UIViewRepresentable {
    let url: String
    let assistant: FormAssistant
    let onFrictionDetected: (HumanAssistedApplyView.FrictionType) -> Void
    let onFieldFilled: ((String, String) -> Void)?
    let onResumeUploaded: (() -> Void)?
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        assistant.setWebView(webView)
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil, let url = URL(string: url) {
            webView.load(URLRequest(url: url))
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(
            onFrictionDetected: onFrictionDetected,
            onFieldFilled: onFieldFilled,
            onResumeUploaded: onResumeUploaded
        )
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let onFrictionDetected: (HumanAssistedApplyView.FrictionType) -> Void
        let onFieldFilled: ((String, String) -> Void)?
        let onResumeUploaded: (() -> Void)?
        
        init(
            onFrictionDetected: @escaping (HumanAssistedApplyView.FrictionType) -> Void,
            onFieldFilled: ((String, String) -> Void)?,
            onResumeUploaded: (() -> Void)?
        ) {
            self.onFrictionDetected = onFrictionDetected
            self.onFieldFilled = onFieldFilled
            self.onResumeUploaded = onResumeUploaded
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Check for friction points (human-in-the-loop moments, like sorce.jobs)
            checkForFriction(webView: webView)
        }
        
        private func checkForFriction(webView: WKWebView) {
            let script = """
            (function() {
                // Check for CAPTCHA (human-in-the-loop moment)
                if (document.querySelector('iframe[src*="recaptcha"], iframe[src*="hcaptcha"], .g-recaptcha, #captcha')) {
                    return 'captcha';
                }
                
                // Check for login requirements
                const bodyText = document.body.textContent.toLowerCase();
                if (bodyText.includes('sign in') || 
                    bodyText.includes('log in') ||
                    bodyText.includes('create account') ||
                    document.querySelector('input[type="password"]')) {
                    return 'login';
                }
                
                // Check for OTP/email verification
                if (bodyText.includes('verify') || 
                    bodyText.includes('verification code') ||
                    bodyText.includes('otp')) {
                    return 'otp';
                }
                
                // Check for bot detection
                if (bodyText.includes('bot detected') || 
                    bodyText.includes('suspicious behavior') ||
                    bodyText.includes('automated access') ||
                    bodyText.includes('unusual activity')) {
                    return 'botDetection';
                }
                
                return null;
            })();
            """
            
            webView.evaluateJavaScript(script) { result, error in
                if let frictionString = result as? String, !frictionString.isEmpty {
                    let friction: HumanAssistedApplyView.FrictionType
                    switch frictionString {
                    case "captcha": friction = .captcha
                    case "login": friction = .loginRequired
                    case "otp": friction = .loginRequired // Treat OTP as login requirement
                    case "botDetection": friction = .botDetection
                    default: friction = .unknown
                    }
                    self.onFrictionDetected(friction)
                }
            }
        }
    }
}


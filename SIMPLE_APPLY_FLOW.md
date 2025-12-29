# Simple Apply Process Flow

## Overview

When a user taps the **"Simple Apply"** button on a job posting, the app follows one of two paths depending on whether the job has an application URL.

## Flow Diagram

```
User Taps "Simple Apply" Button
         │
         ├─► Job has URL? ──YES──► Auto-Apply Flow (WKWebView)
         │                          │
         │                          ├─► Load job application page
         │                          ├─► Detect ATS system
         │                          ├─► Generate AI cover letter
         │                          ├─► Fill form fields automatically
         │                          ├─► Handle questions (if any)
         │                          ├─► User reviews & submits
         │                          └─► Save to Supabase
         │
         └─► Job has URL? ──NO───► Review Screen Flow
                                    │
                                    ├─► Show application review
                                    ├─► User can edit info
                                    ├─► User submits manually
                                    └─► Save to Supabase
```

## Detailed Step-by-Step Process

### Step 1: User Taps "Simple Apply" Button

**Location**: `FeedView.swift` (line 90-104)

```swift
onSimpleApply: {
    // Get profile data
    let profileData = SimpleApplyService.shared.getUserProfileData()
    let appData = SimpleApplyService.shared.generateApplicationData(for: post, profileData: profileData)
    applicationData = appData
    
    // Check if job has URL for auto-apply
    if let jobURL = post.url, !jobURL.isEmpty {
        // Directly start AI Auto-Apply (like sorce.jobs)
        showingAutoApply = post
    } else {
        // No URL, show review screen instead
        showingSimpleApply = post
    }
}
```

**What happens:**
1. Retrieves user profile data from `UserDefaults` (name, email, phone, location, LinkedIn, GitHub, portfolio, resume)
2. Generates application data by combining profile data with a cover letter
3. Checks if the job has an application URL

---

### Step 2A: Job Has URL → Auto-Apply Flow

**Location**: `AutoApplyView.swift`

#### 2A.1: Load Application Page
- Opens `WKWebView` with the job application URL
- Waits 3 seconds for page to load

#### 2A.2: Detect ATS System
- Analyzes URL to detect ATS (Workday, Greenhouse, Lever, etc.)
- Uses `WebAutomationService.detectATSSystem()`

#### 2A.3: Generate AI Cover Letter
- Calls `AICoverLetterService.generateCoverLetter()`
- Uses OpenAI GPT-4o-mini to create personalized cover letter
- Falls back to template cover letter if AI fails

#### 2A.4: Fill Form Fields
- Prepares form data (name, email, phone, location, LinkedIn, GitHub, portfolio, cover letter)
- Executes JavaScript injection to fill form fields
- Uses ATS-specific scripts for better compatibility
- Tracks filled field count

#### 2A.5: Handle Questions
- Detects questions that need user input
- Prompts user to answer if needed
- Waits for user responses

#### 2A.6: User Review & Submit
- User reviews filled form in `WKWebView`
- User can manually submit or app auto-submits
- Takes screenshot for verification

#### 2A.7: Save Application
- Calls `SimpleApplyService.submitApplication()`
- Uploads resume to Supabase Storage (if available)
- Creates application record in Supabase
- Sends email notification
- Shows success message

---

### Step 2B: Job Has No URL → Review Screen Flow

**Location**: `SimpleApplyReviewView.swift`

#### 2B.1: Display Review Screen
- Shows job information (title, company, location)
- Displays user information (name, email, phone, etc.)
- Shows resume summary (work experience, skills, education)
- Displays cover letter preview

#### 2B.2: User Options
User can access three options via menu (⋯):

1. **AI Auto-Apply** (if job URL becomes available)
   - Opens `AutoApplyView` for automated application

2. **Auto-Fill Helper**
   - Opens `FormAutoFillView` to help fill forms manually

3. **Submit Application**
   - Saves application to Supabase
   - Does NOT submit to company website (no URL)

#### 2B.3: Submit Application
- Calls `SimpleApplyService.submitApplication()`
- Uploads resume to Supabase Storage
- Creates application record
- Sends email notification
- Shows success message

---

### Step 3: Submit Application (Common to Both Flows)

**Location**: `SimpleApplyService.swift` (line 124-179)

#### 3.1: Upload Resume
```swift
if let localResumePath = applicationData.resumeURL,
   FileManager.default.fileExists(atPath: localResumePath) {
    resumePublicURL = try await SupabaseService.shared.uploadResumeToStorage(
        fileURL: fileURL,
        fileName: fileName
    )
}
```

#### 3.2: Create Application Record
```swift
let application = Application(
    id: UUID().uuidString,
    jobPostId: job.id,
    jobTitle: job.title,
    company: job.company,
    status: "applied",
    appliedDate: dateFormatter.string(from: Date()),
    resumeUrl: resumePublicURL
)
```

#### 3.3: Save to Supabase
```swift
try await SupabaseService.shared.insertApplication(application)
```

#### 3.4: Send Email Notification
- Calls Supabase Edge Function: `send-application-email`
- Sends confirmation email to user

---

## Data Flow

### Profile Data Collection
**Source**: `UserDefaults` (saved from Profile tab)
- First Name, Middle Name, Last Name
- Preferred Name
- Title
- Location
- Email
- Phone
- LinkedIn URL
- GitHub URL
- Portfolio URL
- Resume file path
- Parsed resume data (work experience, skills, education, etc.)

### Application Data Generation
**Location**: `SimpleApplyService.generateApplicationData()`

1. **Full Name**: Combines first, middle, last name
2. **Cover Letter**: Generated from template + resume data
3. **All Profile Fields**: Copied to `ApplicationData` struct

### Cover Letter Generation
**Location**: `SimpleApplyService.generateCoverLetter()`

Template structure:
```
Dear Hiring Manager,

I am writing to express my interest in the [Job Title] position at [Company].

[Relevant Experience from Resume]

[Relevant Skills]

I am excited about the opportunity to contribute to [Company]...

Thank you for considering my application.

Best regards,
[First Name]
```

---

## Integration with Fly.io Playwright Service

**Current Status**: Not yet integrated

**Future Enhancement**: 
When integrated, the flow would be:

1. User taps "Simple Apply"
2. App calls Supabase Edge Function: `auto-apply`
3. Edge Function calls Fly.io Playwright service
4. Playwright service:
   - Navigates to job URL
   - Detects ATS
   - Fills form automatically
   - Returns success status + screenshot
5. App saves application to Supabase

**Benefits**:
- Fully automated (no user interaction needed)
- Server-side execution (no device browser)
- More reliable form filling
- Better ATS compatibility

---

## Key Files

1. **`FeedView.swift`**: Entry point - handles "Simple Apply" button tap
2. **`SimpleApplyService.swift`**: Core service - generates data, submits applications
3. **`SimpleApplyReviewView.swift`**: Review screen for jobs without URLs
4. **`AutoApplyView.swift`**: Automated application flow with WKWebView
5. **`WebAutomationService.swift`**: JavaScript injection for form filling
6. **`AICoverLetterService.swift`**: AI-powered cover letter generation
7. **`SupabaseService.swift`**: Database operations

---

## Error Handling

### Common Errors:

1. **No Profile Data**
   - User must fill profile in Profile tab first
   - App shows error message

2. **No Job URL**
   - Falls back to review screen
   - User can only save application (not submit to company)

3. **Form Filling Fails**
   - App shows error message
   - User can manually fill form

4. **Resume Upload Fails**
   - Application continues without resume
   - Error logged but doesn't block submission

5. **Supabase Save Fails**
   - Error shown to user
   - Application not saved

---

## User Experience

### With URL (Auto-Apply):
1. Tap "Simple Apply" → Loading screen
2. Page loads → ATS detected
3. AI cover letter generated
4. Forms auto-filled
5. User reviews → Submits
6. Success message → Application saved

### Without URL (Review):
1. Tap "Simple Apply" → Review screen appears
2. User reviews information
3. User taps menu → "Submit Application"
4. Success message → Application saved

---

## Future Improvements

1. **Integrate Fly.io Playwright Service**
   - Fully automated applications
   - No user interaction needed

2. **Better Error Recovery**
   - Retry failed form fills
   - Better error messages

3. **Application Status Tracking**
   - Track if application was viewed
   - Track interview status

4. **Batch Applications**
   - Apply to multiple jobs at once
   - Queue system for auto-apply


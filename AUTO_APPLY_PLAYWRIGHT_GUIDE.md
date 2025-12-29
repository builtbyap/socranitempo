# Playwright Auto-Apply Implementation Guide

## Overview

This guide explains how to use Playwright in a Supabase Edge Function to **fully automate** job applications server-side, so users don't need to manually apply.

## ✅ What This Does

The `edge-function-auto-apply.ts` function:
1. **Navigates** to job application pages using Playwright
2. **Detects** the ATS system (Workday, Greenhouse, Lever, etc.)
3. **Fills** all form fields automatically (name, email, phone, etc.)
4. **Uploads** resume files
5. **Handles** ATS-specific form structures
6. **Returns** results with success status and filled field count

## 🚀 Setup Steps

### Step 1: Deploy the Edge Function

1. Go to **Supabase Dashboard** → **Edge Functions**
2. Click **"Create a new function"** → **"Via Editor"**
3. Name it: `auto-apply`
4. Copy the contents of `edge-function-auto-apply.ts` into the editor
5. Click **"Deploy"**

### Step 2: Update Config.swift

Add the edge function URL to your config:

```swift
// In Config.swift
static let autoApplyBackendURL = "https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/auto-apply"
```

### Step 3: Create Swift Service (Optional but Recommended)

Create a new file `AutoApplyService.swift`:

```swift
import Foundation

class AutoApplyService {
    static let shared = AutoApplyService()
    
    private init() {}
    
    func autoApply(
        job: JobPost,
        applicationData: ApplicationData,
        resumeBase64: String? = nil
    ) async throws -> AutoApplyResult {
        guard let backendURL = URL(string: Config.autoApplyBackendURL) else {
            throw AutoApplyError.invalidURL
        }
        
        var request = URLRequest(url: backendURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        
        // Prepare request body
        var requestBody: [String: Any] = [
            "jobUrl": job.url ?? "",
            "jobTitle": job.title,
            "company": job.company,
            "applicationData": [
                "fullName": applicationData.fullName,
                "email": applicationData.email,
                "phone": applicationData.phone,
                "location": applicationData.location ?? "",
                "linkedIn": applicationData.linkedInURL ?? "",
                "github": applicationData.githubURL ?? "",
                "portfolio": applicationData.portfolioURL ?? "",
                "coverLetter": applicationData.coverLetter,
                "resumeUrl": applicationData.resumeURL
            ]
        ]
        
        // Add base64 resume if provided
        if let resumeBase64 = resumeBase64,
           let resumeFileName = applicationData.resumeURL?.components(separatedBy: "/").last {
            requestBody["applicationData"]?["resumeBase64"] = resumeBase64
            requestBody["applicationData"]?["resumeFileName"] = resumeFileName
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AutoApplyError.requestFailed
        }
        
        let result = try JSONDecoder().decode(AutoApplyResult.self, from: data)
        return result
    }
}

struct AutoApplyResult: Codable {
    let success: Bool
    let filledFields: Int
    let atsSystem: String
    let error: String?
    let screenshot: String? // Base64 screenshot for debugging
}

enum AutoApplyError: Error {
    case invalidURL
    case requestFailed
    case parsingFailed
}
```

### Step 4: Integrate with Your App

In `AutoApplyQueueService.swift` or `AutoApplyView.swift`:

```swift
// Instead of opening WebView, call the edge function
Task {
    do {
        let profileData = SimpleApplyService.shared.getUserProfileData()
        let applicationData = SimpleApplyService.shared.generateApplicationData(
            for: job,
            profileData: profileData
        )
        
        // Convert resume to base64 if needed
        var resumeBase64: String? = nil
        if let resumeURL = applicationData.resumeURL,
           let url = URL(string: resumeURL),
           let data = try? Data(contentsOf: url) {
            resumeBase64 = data.base64EncodedString()
        }
        
        // Call Playwright edge function
        let result = try await AutoApplyService.shared.autoApply(
            job: job,
            applicationData: applicationData,
            resumeBase64: resumeBase64
        )
        
        if result.success {
            print("✅ Auto-applied successfully! Filled \(result.filledFields) fields")
            // Save application to Supabase
            try await SimpleApplyService.shared.submitApplication(
                job: job,
                applicationData: applicationData
            )
        } else {
            print("❌ Auto-apply failed: \(result.error ?? "Unknown error")")
        }
    } catch {
        print("❌ Error: \(error)")
    }
}
```

## ⚠️ Important Considerations

### 1. **Auto-Submission is Disabled by Default**

The edge function **fills** the form but **does NOT auto-submit** by default. This is intentional for:
- **Legal compliance**: Some ATS ToS may prohibit automation
- **CAPTCHA handling**: Many sites have CAPTCHAs
- **Additional questions**: Forms may have dynamic questions
- **User verification**: Users should review before submitting

**To enable auto-submit**, add this to the edge function after filling:

```typescript
// After filling form, find and click submit button
const submitSelectors = [
  'button[type="submit"]',
  'input[type="submit"]',
  'button:contains("Submit")',
  'button:contains("Apply")',
  '#submit',
  '.submit-button'
]

for (const selector of submitSelectors) {
  try {
    const submitButton = await page.$(selector)
    if (submitButton) {
      await page.click(selector)
      await page.waitForNavigation({ timeout: 10000 })
      console.log('✅ Form submitted')
      break
    }
  } catch (e) {
    continue
  }
}
```

### 2. **Resume Upload**

The function supports two methods:
- **URL**: Provide `resumeUrl` pointing to Supabase Storage or external URL
- **Base64**: Provide `resumeBase64` + `resumeFileName` for direct upload

### 3. **Timeout Settings**

Edge functions have a **60-second timeout** by default. For complex forms, you may need to:
- Increase timeout in Supabase project settings
- Optimize the function to be faster
- Handle timeouts gracefully

### 4. **Rate Limiting**

Be mindful of:
- **Rate limits** from ATS systems
- **IP blocking** if too many requests
- **User-Agent** rotation (already implemented)
- **Delays** between applications

### 5. **Error Handling**

The function returns:
- `success`: Boolean indicating if form was filled
- `filledFields`: Number of fields successfully filled
- `atsSystem`: Detected ATS system
- `error`: Error message if failed
- `screenshot`: Base64 screenshot for debugging

## 📊 Comparison: Current vs Playwright

| Feature | Current (WKWebView + JS) | Playwright (Edge Function) |
|---------|-------------------------|----------------------------|
| **User Interaction** | Required (review & submit) | Fully automated |
| **Reliability** | Medium (JS injection) | High (native browser) |
| **Complex Forms** | Limited | Excellent |
| **Iframes** | Difficult | Handles well |
| **Server-Side** | No (runs on device) | Yes (edge function) |
| **Battery Usage** | High (device browser) | None (server) |
| **Network Usage** | Device bandwidth | Server bandwidth |

## 🎯 Recommended Approach

**Hybrid Strategy** (Best of both worlds):

1. **Use Playwright** for fully automated background applications
2. **Use WKWebView** for user-initiated applications where review is needed
3. **Let users choose**:
   - "Auto-Apply Now" → Playwright (fully automated)
   - "Review & Apply" → WKWebView (user reviews)

## 🔧 Troubleshooting

### Issue: Timeout errors
**Solution**: Increase edge function timeout or optimize form filling logic

### Issue: Resume not uploading
**Solution**: Check resume URL/Base64 format, ensure file is accessible

### Issue: Forms not filling
**Solution**: 
- Check screenshot (returned in response) to see page state
- Add more selectors for specific ATS systems
- Verify field names match your application data

### Issue: Playwright not available in Deno
**Solution**: Ensure you're using the correct import:
```typescript
import { chromium } from "https://deno.land/x/playwright@1.40.0/mod.ts"
```

## 📝 Next Steps

1. **Test the edge function** with a simple job application
2. **Review the screenshot** to verify form filling
3. **Add auto-submit** if desired (see considerations above)
4. **Integrate with your iOS app**
5. **Handle edge cases** (CAPTCHAs, additional questions, etc.)

## 🚨 Legal Disclaimer

Automating job applications may violate:
- Terms of Service of ATS platforms
- Company application policies
- Local regulations

**Use at your own risk**. Consider:
- Reading ATS ToS before automating
- Getting user consent
- Providing transparency about automation
- Handling errors gracefully
- Respecting rate limits


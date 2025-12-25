# AI Auto-Apply Feature Guide

## Overview

The AI Auto-Apply feature automatically navigates employer websites, fills out application forms, and generates personalized cover letters using AI. This creates a one-swipe application process.

## How It Works

### 1. **AI Cover Letter Generation**
- Uses OpenAI GPT-4o-mini to generate personalized cover letters
- Analyzes job description and user's resume
- Creates compelling, tailored content for each application

### 2. **ATS System Detection**
- Automatically detects common ATS systems:
  - Workday
  - Greenhouse
  - Lever
  - SmartRecruiters
  - Jobvite
  - iCIMS
  - Taleo
  - BambooHR

### 3. **Form Auto-Filling**
- Detects form fields using multiple strategies:
  - Field names (name, email, phone, etc.)
  - Field IDs
  - Placeholders
  - Associated labels
- Fills forms intelligently based on detected patterns
- Handles ATS-specific form structures

### 4. **Automated Navigation**
- Loads job application pages
- Waits for forms to load
- Fills all relevant fields
- Scrolls to filled fields for review

## User Flow

1. **User taps "Simple Apply"** on a job posting
2. **Review screen appears** with application data
3. **User taps menu (⋯) → "AI Auto-Apply"**
4. **Automation starts**:
   - Page loads
   - ATS system detected
   - AI cover letter generated
   - Forms automatically filled
5. **User reviews** the filled form
6. **User submits** (or app auto-submits)

## Features

### ✅ AI-Powered Cover Letters
- Personalized for each job
- Highlights relevant experience
- Professional tone
- 3-4 paragraphs, optimized length

### ✅ Smart Form Detection
- Multiple detection strategies
- Handles various form layouts
- Works with iframes (Workday, etc.)
- Field name pattern matching

### ✅ ATS-Specific Handling
- Custom scripts for major ATS systems
- Handles unique form structures
- Adapts to different submission flows

### ✅ Progress Tracking
- Real-time status updates
- Shows filled field count
- Clear step indicators

## Technical Implementation

### Files Created

1. **AICoverLetterService.swift**
   - Generates AI cover letters using OpenAI
   - Builds prompts from job and user data
   - Handles API calls and responses

2. **WebAutomationService.swift**
   - Form detection JavaScript
   - Auto-fill scripts
   - ATS system detection
   - ATS-specific form filling

3. **AutoApplyView.swift**
   - Main automation UI
   - WKWebView integration
   - Progress tracking
   - Step management

### Key Components

#### Form Detection
```javascript
// Detects all input fields
// Finds associated labels
// Identifies field types
// Returns structured data
```

#### Auto-Fill Script
```javascript
// Maps user data to form fields
// Uses intelligent matching
// Handles various field types
// Triggers change events
```

#### ATS Detection
```swift
// Analyzes URL patterns
// Identifies ATS system
// Returns appropriate script
```

## Setup Requirements

### 1. OpenAI API Key
- Already configured in `Config.swift`
- Uses `gpt-4o-mini` model (cost-effective)
- Can upgrade to `gpt-4` for better quality

### 2. Web View Permissions
- iOS automatically handles WKWebView permissions
- No additional setup needed

### 3. Job URL Requirements
- Job posting must have a valid `url` field
- URL must be accessible
- Some sites may require authentication

## Limitations & Considerations

### ⚠️ Website Restrictions
- Some sites block automated form filling
- CAPTCHA may appear
- Some forms require manual interaction
- Anti-bot measures may prevent automation

### ⚠️ Form Complexity
- Multi-step forms may need manual navigation
- File uploads may require manual selection
- Some fields may need manual review

### ⚠️ ATS Variations
- Not all ATS systems are supported
- Custom ATS systems may not work
- Form structures change over time

### ⚠️ Legal Considerations
- Always review filled forms before submitting
- Ensure accuracy of information
- Some employers may prohibit automated applications

## Best Practices

### For Users
1. **Always Review**: Check filled forms before submitting
2. **Verify Information**: Ensure all data is correct
3. **Manual Override**: Edit fields if needed
4. **Test First**: Try on a test application first

### For Developers
1. **Error Handling**: Gracefully handle failures
2. **User Feedback**: Show clear progress indicators
3. **Fallback Options**: Provide manual fill option
4. **Update Scripts**: Keep ATS scripts updated

## Troubleshooting

### Cover Letter Not Generating
- **Check**: OpenAI API key is valid
- **Check**: Internet connection
- **Solution**: Falls back to template cover letter

### Forms Not Filling
- **Check**: Page has loaded completely
- **Check**: Forms are visible
- **Solution**: Try manual fill or refresh

### ATS Not Detected
- **Check**: URL is correct
- **Solution**: Uses generic form filling

### Submit Button Not Found
- **Check**: Form structure
- **Solution**: User can manually click submit

## Future Enhancements

### Planned Features
1. **Multi-Step Form Handling**
   - Automatic navigation between steps
   - Progress tracking across pages

2. **File Upload Automation**
   - Automatic resume upload
   - Portfolio file selection

3. **CAPTCHA Handling**
   - Integration with CAPTCHA solving services
   - Manual CAPTCHA option

4. **Application Tracking**
   - Track automation success rate
   - Log filled fields
   - Analytics dashboard

5. **More ATS Support**
   - Additional ATS systems
   - Custom ATS detection
   - Community-contributed scripts

## Usage Example

```swift
// User flow:
1. Tap "Simple Apply" on job card
2. Review application data
3. Tap menu → "AI Auto-Apply"
4. Watch automation progress:
   - Loading page...
   - Detecting system...
   - Generating cover letter...
   - Filling forms... (X fields filled)
5. Review filled form
6. Tap "Submit"
7. Application saved!
```

## Cost Considerations

### OpenAI API
- **Model**: gpt-4o-mini (cheaper)
- **Cost**: ~$0.01-0.02 per cover letter
- **Alternative**: Use template if API fails

### Network Usage
- Loading job pages
- Minimal data usage
- Cached where possible

## Security & Privacy

- **Data Handling**: All data stays on device until submission
- **API Calls**: Only cover letter generation uses external API
- **Form Data**: Not stored externally
- **User Control**: User can cancel at any time

## Support

For issues:
1. Check console logs for errors
2. Verify OpenAI API key
3. Test with different job URLs
4. Try manual fill as fallback

---

**Note**: This feature is designed to assist users, not replace careful review. Always verify information before submitting applications.


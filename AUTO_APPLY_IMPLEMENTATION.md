# Auto-Apply Implementation (Like sorce.jobs)

## Overview
After job posts are scraped, the app automatically applies to company career pages on behalf of the user, similar to sorce.jobs.

## How It Works

### 1. Job Scraping
- Jobs are scraped from multiple sources (Adzuna, The Muse, Indeed, Monster, Glassdoor, ZipRecruiter)
- Jobs are filtered by user's career interests
- Jobs are displayed in the Feed tab

### 2. Auto-Apply Queue
- After jobs are scraped, eligible jobs are automatically queued for auto-apply
- **Eligible jobs** are those that:
  - Have a valid application URL
  - Are from company career pages (not job boards like Indeed, Monster, etc.)
  - Haven't been processed yet
  - Match user's career interests

### 3. Processing Queue
- The queue is processed automatically when:
  - Jobs are fetched and displayed
  - The app is in the foreground
  - Auto-apply is enabled in settings

### 4. Application Process
For each queued job:
1. **Detect ATS System**: Identifies the Applicant Tracking System (Workday, Greenhouse, Lever, etc.)
2. **Generate AI Cover Letter**: Creates a personalized cover letter using OpenAI
3. **Fill Application Form**: Automatically fills all form fields with user's profile data
4. **Handle Questions**: If the form has questions, prompts the user to answer
5. **Submit Application**: Automatically submits the completed application
6. **Track Status**: Saves application to Supabase with "Auto-Applied" status

## User Settings

### Enable/Disable Auto-Apply
- Go to **Profile** tab → **Personal** section → **Application Settings**
- Toggle "Auto-Apply to Jobs" on/off
- When enabled, jobs are automatically queued and processed
- When disabled, users must manually apply to jobs

## Technical Details

### Files
- `AutoApplyQueueService.swift`: Manages the queue and processing
- `AutoApplyView.swift`: Handles web automation and form filling
- `WebAutomationService.swift`: Detects ATS systems and generates automation scripts
- `AICoverLetterService.swift`: Generates AI-powered cover letters
- `SimpleApplyService.swift`: Collects user profile data and generates application data

### Limitations
- **Background Processing**: WKWebView cannot run in the background on iOS, so applications are processed when the app is in the foreground
- **Job Boards**: Auto-apply only works for company career pages, not job boards (Indeed, Monster, Glassdoor, etc.)
- **Rate Limiting**: 5-second delay between applications to avoid rate limiting

## Future Enhancements
- Background processing using a backend service
- Support for more ATS systems
- Better error handling and retry logic
- User notifications for application status
- Analytics dashboard for application success rate


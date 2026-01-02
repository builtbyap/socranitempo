# Where to Find Job Descriptions from JobSpy

## Quick Answer

**Job descriptions from JobSpy appear in the same place as all other job descriptions** - in the **"Job description"** section on each job card in your feed.

## Location in the App

### In the Job Card (JobSearchView)

1. **Open the app** and navigate to the Feed
2. **Swipe through job cards** until you see a job from JobSpy
3. **Scroll down** on the job card
4. **Look for the "Job description" section** (below the job title, company, and info bubbles)
5. The description will appear there

### Visual Location

```
┌─────────────────────────────────┐
│ Job Title                        │
│ Company Name                     │
│ [Info Bubbles: Location, Salary] │
│                                  │
│ Job description                  │ ← HERE
│ ───────────────────────────────  │
│ [Full job description text]       │
│                                  │
│ [AI Summary if available]        │
└─────────────────────────────────┘
```

## How Descriptions Work

### 1. **JobSpy Service**
   - Scrapes descriptions from job boards (Indeed, LinkedIn, Glassdoor, ZipRecruiter, Google)
   - Returns descriptions in the `description` field of each job

### 2. **Edge Function**
   - Receives jobs from JobSpy service
   - Maps `description` field to `description: job.description || null`
   - Passes it through to the iOS app

### 3. **iOS App (JobPostCard)**
   - Displays description in the "Job description" section
   - Shows original description immediately
   - AI summarizes it in the background (if OpenAI is configured)
   - Once summarized, shows the AI summary with bullet points

## Description Availability by Source

| Source | Description Available? | Notes |
|--------|----------------------|-------|
| **Indeed** | ✅ Yes | Full descriptions included |
| **LinkedIn** | ✅ Yes (with update) | Now fetches full descriptions (`linkedin_fetch_description=True`) |
| **Glassdoor** | ✅ Yes | Descriptions included |
| **ZipRecruiter** | ✅ Yes | Descriptions included |
| **Google** | ⚠️ Varies | Depends on source job board |

## What You'll See

### If Description is Available:
```
Job description
────────────────
[Full job description text here...]

[After AI processing:]
Brief summary of the role...

Key Responsibilities
• Responsibility 1
• Responsibility 2

Requirements
• Requirement 1
• Requirement 2
```

### If Description is Missing:
```
Job description
────────────────
No description available
```

## Recent Updates

I just updated the JobSpy service to:
1. ✅ **Enable LinkedIn description fetching** - LinkedIn jobs now get full descriptions
2. ✅ **Use markdown format** - Better formatting for descriptions
3. ✅ **Better description extraction** - Improved handling of missing/empty descriptions

The service has been redeployed with these improvements.

## Troubleshooting

### No Description Showing?

1. **Check if it's a LinkedIn job**:
   - LinkedIn descriptions require `linkedin_fetch_description=True`
   - This is now enabled automatically

2. **Check the job source**:
   - Some job boards don't provide descriptions
   - Google Jobs may not always have descriptions

3. **Check Edge Function logs**:
   - Look for `✅ JobSpy: Found X jobs` in Supabase logs
   - Check if descriptions are in the response

4. **Test the service directly**:
   ```bash
   curl "https://jobspy-service-proud-feather-2790.fly.dev/scrape?search_term=software%20engineer&location=San%20Francisco&results_wanted=1"
   ```
   - Check if `description` field is present in the JSON response

### Description is Truncated?

- Descriptions are shown in full in the app
- The AI summary may truncate very long descriptions
- Original description is always available

## Code References

- **JobSpy Service**: `jobspy-service/main.py` (line 126, 203)
- **Edge Function**: `edge-function-code-with-adzuna.ts` (line 2164)
- **iOS Display**: `surgeapp/JobSearchView.swift` (lines 557-633)

## Summary

**Job descriptions from JobSpy appear in the "Job description" section on each job card**, just like descriptions from other sources (Adzuna, The Muse, Workday). They're displayed immediately and then AI-summarized in the background for better readability.


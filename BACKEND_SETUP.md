# Backend API Setup Guide

This guide explains how to configure your backend API for job scraping and what format it should return.

## Step 1: Update the Backend URL

### Option A: Direct Update in JobScrapingService.swift

1. Open `surgeapp/JobScrapingService.swift`
2. Find line ~287 where it says:
   ```swift
   guard let backendURL = URL(string: "https://your-backend-api.com/api/jobs") else {
   ```
3. Replace `"https://your-backend-api.com/api/jobs"` with your actual backend URL
   ```swift
   guard let backendURL = URL(string: "https://api.yourdomain.com/v1/jobs") else {
   ```

### Option B: Use Config.swift (Recommended)

1. Open `surgeapp/Config.swift`
2. Add a new property for the backend URL:
   ```swift
   static let jobScrapingBackendURL = "https://api.yourdomain.com/v1/jobs"
   ```
3. Update `JobScrapingService.swift` line ~287 to use it:
   ```swift
   guard let backendURL = URL(string: Config.jobScrapingBackendURL) else {
   ```

## Step 2: Backend API Requirements

Your backend API should:

### Accept GET Requests
- Endpoint: Your configured URL (e.g., `https://api.yourdomain.com/v1/jobs`)

### Accept Query Parameters
- `keywords` (optional): Search keywords string (e.g., "Software Engineer OR Data Analyst")
- `location` (optional): Location string (e.g., "San Francisco, CA")
- `career_interests` (optional): JSON array string of career interests (e.g., `["Software Engineer", "Data Analyst"]`)

### Example Request
```
GET https://api.yourdomain.com/v1/jobs?keywords=Software%20Engineer%20OR%20Data%20Analyst&location=San%20Francisco&career_interests=["Software%20Engineer","Data%20Analyst"]
```

### Return JSON Response
Your backend should return a JSON array of job objects matching the `JobPost` structure:

```json
[
  {
    "id": "unique-job-id-1",
    "title": "Senior Software Engineer",
    "company": "Tech Company Inc",
    "location": "San Francisco, CA",
    "posted_date": "2025-01-15",
    "description": "We are looking for a Senior Software Engineer...",
    "url": "https://company.com/jobs/123",
    "salary": "$120,000 - $150,000",
    "job_type": "Full-time"
  },
  {
    "id": "unique-job-id-2",
    "title": "Data Analyst",
    "company": "Analytics Corp",
    "location": "Remote",
    "posted_date": "2025-01-14",
    "description": "Join our data team...",
    "url": "https://analytics.com/careers/456",
    "salary": null,
    "job_type": "Full-time"
  }
]
```

### Required Fields
- `id` (string): Unique identifier for the job
- `title` (string): Job title
- `company` (string): Company name
- `location` (string): Job location
- `posted_date` (string): Date when job was posted (format: "YYYY-MM-DD" or ISO 8601)

### Optional Fields
- `description` (string or null): Job description
- `url` (string or null): Link to apply or view job details
- `salary` (string or null): Salary range or compensation info
- `job_type` (string or null): Employment type (e.g., "Full-time", "Part-time", "Contract")

## Step 3: How Results Are Combined

The iOS app automatically combines results from multiple sources:

1. **Supabase Database**: Fetches existing jobs from your Supabase `job_posts` table
2. **Backend API**: Fetches scraped jobs from your backend service
3. **Deduplication**: Removes duplicate jobs based on title, company, and location
4. **Filtering**: Filters all jobs by user's career interests (if set)
5. **Sorting**: Sorts by posted date (most recent first)

### Flow Diagram
```
┌─────────────────┐
│  FeedView       │
│  (User opens)   │
└────────┬────────┘
         │
         ├─► Load Career Interests from UserDefaults
         │
         ├─► Fetch from Supabase
         │   └─► Filter by career interests
         │
         ├─► Fetch from Backend API
         │   └─► Send career_interests parameter
         │   └─► Filter response by career interests
         │
         └─► Combine & Deduplicate
             └─► Sort by date
                 └─► Display to user
```

## Step 4: Backend Implementation Examples

### Node.js/Express Example

```javascript
const express = require('express');
const app = express();

app.get('/api/jobs', async (req, res) => {
  const { keywords, location, career_interests } = req.query;
  
  // Parse career interests if provided
  let interests = [];
  if (career_interests) {
    try {
      interests = JSON.parse(career_interests);
    } catch (e) {
      interests = [];
    }
  }
  
  // Scrape jobs from various sources
  const jobs = await scrapeJobs({
    keywords: keywords || interests.join(' OR '),
    location: location,
    interests: interests
  });
  
  // Return in the expected format
  res.json(jobs.map(job => ({
    id: job.id,
    title: job.title,
    company: job.company,
    location: job.location,
    posted_date: job.postedDate,
    description: job.description,
    url: job.url,
    salary: job.salary,
    job_type: job.jobType
  })));
});

app.listen(3000);
```

### Python/Flask Example

```python
from flask import Flask, request, jsonify
import json

app = Flask(__name__)

@app.route('/api/jobs', methods=['GET'])
def get_jobs():
    keywords = request.args.get('keywords')
    location = request.args.get('location')
    career_interests = request.args.get('career_interests')
    
    # Parse career interests if provided
    interests = []
    if career_interests:
        try:
            interests = json.loads(career_interests)
        except:
            interests = []
    
    # Scrape jobs from various sources
    jobs = scrape_jobs(
        keywords=keywords or ' OR '.join(interests),
        location=location,
        interests=interests
    )
    
    # Return in the expected format
    return jsonify([{
        'id': job['id'],
        'title': job['title'],
        'company': job['company'],
        'location': job['location'],
        'posted_date': job['posted_date'],
        'description': job.get('description'),
        'url': job.get('url'),
        'salary': job.get('salary'),
        'job_type': job.get('job_type')
    } for job in jobs])
```

## Step 5: Testing Your Backend

### Test with cURL

```bash
# Basic request
curl "https://api.yourdomain.com/v1/jobs"

# With keywords
curl "https://api.yourdomain.com/v1/jobs?keywords=Software%20Engineer"

# With career interests
curl "https://api.yourdomain.com/v1/jobs?career_interests=[\"Software%20Engineer\",\"Data%20Analyst\"]"

# Full request
curl "https://api.yourdomain.com/v1/jobs?keywords=Software%20Engineer&location=San%20Francisco&career_interests=[\"Software%20Engineer\"]"
```

### Expected Response Format

Make sure your backend returns:
- HTTP Status: 200-299
- Content-Type: `application/json`
- Body: Array of job objects matching the `JobPost` structure

## Troubleshooting

### Common Issues

1. **"Invalid URL" error**: Check that your backend URL is a valid HTTPS URL
2. **"Request Failed" error**: Check that your backend is accessible and returns 200 status
3. **"Parsing Failed" error**: Verify your JSON matches the `JobPost` structure exactly
4. **No jobs showing**: Check that your backend is returning jobs and they match career interests

### Debug Tips

1. Check Xcode console for error messages
2. Verify your backend URL is correct
3. Test your backend API directly with cURL or Postman
4. Ensure your backend returns valid JSON
5. Check that field names match (snake_case for `posted_date`, `job_type`)

## Next Steps

1. Set up your backend service (Node.js, Python, etc.)
2. Implement scraping for job boards (Indeed, Monster, Glassdoor, etc.)
3. Implement parsing for company career pages
4. Implement parsing for ATS-hosted pages (Greenhouse, Lever, Workday)
5. Update the backend URL in `JobScrapingService.swift`
6. Test the integration


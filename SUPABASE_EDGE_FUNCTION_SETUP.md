# Supabase Edge Function Setup Guide

## Which Method Should You Use?

### 🎯 **Recommended: Via Editor (Easiest for Getting Started)**

**Best for:**
- Quick testing and learning
- First-time setup
- Simple functions
- No local development setup needed

**Steps:**
1. Go to Supabase Dashboard → Edge Functions
2. Click "Create a new function"
3. Choose "Via Editor"
4. Name it `scrape-jobs`
5. Write your code in the browser editor
6. Click "Deploy"
7. Copy the function URL

**Pros:**
- ✅ No installation needed
- ✅ Instant deployment
- ✅ Easy to test and iterate
- ✅ Works from any computer

**Cons:**
- ❌ No version control
- ❌ Can't test locally easily
- ❌ Limited for complex projects

---

### 💻 **Via CLI (Best for Production)**

**Best for:**
- Production deployments
- Version control (Git)
- Local testing
- Team collaboration
- Complex functions

**Steps:**
1. Install Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

3. Link your project:
   ```bash
   supabase link --project-ref jlkebdnvjjdwedmbfqou
   ```

4. Create function:
   ```bash
   supabase functions new scrape-jobs
   ```

5. Edit the function code locally

6. Deploy:
   ```bash
   supabase functions deploy scrape-jobs
   ```

**Pros:**
- ✅ Version control with Git
- ✅ Test locally before deploying
- ✅ Better for production
- ✅ Can use TypeScript/JavaScript
- ✅ Better debugging

**Cons:**
- ❌ Requires CLI installation
- ❌ More setup steps
- ❌ Need to manage files locally

---

### 🤖 **Via AI Assistant (Experimental)**

**Best for:**
- Quick code generation
- Learning from examples
- Getting started templates

**Note:** This is newer and may have limitations. Good for generating initial code, but you'll likely want to edit it.

---

## My Recommendation: Start with Editor, Move to CLI Later

### Phase 1: Quick Start (Use Editor)
1. Use **Via Editor** to create your first function
2. Test it works
3. Get your URL and update Config.swift
4. Verify the iOS app can call it

### Phase 2: Production (Use CLI)
Once you know it works:
1. Set up CLI
2. Migrate your function code
3. Use Git for version control
4. Deploy via CLI for production

---

## Quick Start: Using the Editor

### Step 1: Create Function
1. Go to: https://supabase.com/dashboard/project/jlkebdnvjjdwedmbfqou/functions
2. Click **"Create a new function"**
3. Select **"Via Editor"**
4. Name: `scrape-jobs`
5. Click **"Create function"**

### Step 2: Write the Function Code

Replace the default code with:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { corsHeaders } from '../_shared/cors.ts'

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get query parameters
    const url = new URL(req.url)
    const keywords = url.searchParams.get('keywords') || ''
    const location = url.searchParams.get('location') || ''
    const careerInterestsParam = url.searchParams.get('career_interests')
    
    // Parse career interests if provided
    let careerInterests: string[] = []
    if (careerInterestsParam) {
      try {
        careerInterests = JSON.parse(careerInterestsParam)
      } catch {
        careerInterests = []
      }
    }

    // TODO: Implement actual job scraping logic here
    // For now, return sample data that matches your JobPost structure
    const jobs = [
      {
        id: "1",
        title: "Software Engineer",
        company: "Tech Corp",
        location: location || "San Francisco, CA",
        posted_date: new Date().toISOString().split('T')[0],
        description: "We are looking for a software engineer...",
        url: "https://example.com/job/1",
        salary: "$120,000 - $150,000",
        job_type: "Full-time"
      },
      {
        id: "2",
        title: "Data Analyst",
        company: "Analytics Inc",
        location: location || "Remote",
        posted_date: new Date().toISOString().split('T')[0],
        description: "Join our data team...",
        url: "https://example.com/job/2",
        salary: null,
        job_type: "Full-time"
      }
    ]

    // Filter by career interests if provided
    let filteredJobs = jobs
    if (careerInterests.length > 0) {
      filteredJobs = jobs.filter(job => {
        const jobText = `${job.title} ${job.company} ${job.description || ''}`.toLowerCase()
        return careerInterests.some(interest => 
          jobText.includes(interest.toLowerCase())
        )
      })
    }

    return new Response(
      JSON.stringify(filteredJobs),
      {
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        },
      }
    )
  }
})
```

**Note:** You might need to create a `_shared/cors.ts` file. If the editor shows an error, use this simpler version:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get query parameters
    const url = new URL(req.url)
    const keywords = url.searchParams.get('keywords') || ''
    const location = url.searchParams.get('location') || ''
    const careerInterestsParam = url.searchParams.get('career_interests')
    
    // Parse career interests if provided
    let careerInterests: string[] = []
    if (careerInterestsParam) {
      try {
        careerInterests = JSON.parse(careerInterestsParam)
      } catch {
        careerInterests = []
      }
    }

    // TODO: Implement actual job scraping logic here
    // For now, return sample data
    const jobs = [
      {
        id: "1",
        title: "Software Engineer",
        company: "Tech Corp",
        location: location || "San Francisco, CA",
        posted_date: new Date().toISOString().split('T')[0],
        description: "We are looking for a software engineer...",
        url: "https://example.com/job/1",
        salary: "$120,000 - $150,000",
        job_type: "Full-time"
      }
    ]

    // Filter by career interests if provided
    let filteredJobs = jobs
    if (careerInterests.length > 0) {
      filteredJobs = jobs.filter(job => {
        const jobText = `${job.title} ${job.company} ${job.description || ''}`.toLowerCase()
        return careerInterests.some(interest => 
          jobText.includes(interest.toLowerCase())
        )
      })
    }

    return new Response(
      JSON.stringify(filteredJobs),
      {
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        },
      }
    )
  }
})
```

### Step 3: Deploy
1. Click **"Deploy"** button
2. Wait for deployment to complete
3. Copy the function URL (it will look like):
   ```
   https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/scrape-jobs
   ```

### Step 4: Update Config.swift
1. Open `surgeapp/Config.swift`
2. Update line 22:
   ```swift
   static let jobScrapingBackendURL = "https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/scrape-jobs"
   ```
   (Replace with your actual function URL)

### Step 5: Test
1. Run your iOS app
2. Go to the Feed tab
3. Jobs should appear (sample data for now)
4. Once you implement real scraping, replace the sample data in the function

---

## Next Steps: Implement Real Scraping

Once your function is working with sample data, you can:

1. Add job board scraping libraries (e.g., Puppeteer, Cheerio for Node.js)
2. Implement scraping for Indeed, Monster, Glassdoor, etc.
3. Parse company career pages
4. Handle ATS-hosted pages

The function structure is ready - just replace the sample `jobs` array with real scraping logic.

---

## Troubleshooting

### Function not found
- Make sure you deployed the function
- Check the function name matches exactly

### CORS errors
- The CORS headers in the code should handle this
- Make sure you're returning the headers in all responses

### Wrong data format
- Ensure your JSON matches the JobPost structure exactly
- Check field names (snake_case: `posted_date`, `job_type`)

### Testing the function
You can test it directly in your browser or with curl:
```bash
curl "https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/scrape-jobs?keywords=Software%20Engineer"
```


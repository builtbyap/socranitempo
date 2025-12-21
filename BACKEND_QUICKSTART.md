# Quick Start: Setting Up Your Backend URL

You have several options to get a backend URL for job scraping:

## Option 1: Use a Backend-as-a-Service (Easiest - Recommended)

### A. Supabase Edge Functions (Recommended if you're already using Supabase)

Since you're already using Supabase, you can create an Edge Function:

1. **Go to your Supabase Dashboard**: https://supabase.com/dashboard
2. **Navigate to Edge Functions**
3. **Create a new function** called `scrape-jobs`
4. **Deploy the function** - it will give you a URL like:
   ```
   https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/scrape-jobs
   ```
5. **Update Config.swift**:
   ```swift
   static let jobScrapingBackendURL = "https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/scrape-jobs"
   ```

### B. Vercel (Free tier available)

1. **Sign up**: https://vercel.com
2. **Create a new project** from a template or your own code
3. **Deploy** - you'll get a URL like:
   ```
   https://your-project.vercel.app/api/jobs
   ```
4. **Update Config.swift** with your Vercel URL

### C. Railway (Free tier available)

1. **Sign up**: https://railway.app
2. **Create a new project**
3. **Deploy** - you'll get a URL like:
   ```
   https://your-project.up.railway.app/api/jobs
   ```
4. **Update Config.swift** with your Railway URL

### D. Render (Free tier available)

1. **Sign up**: https://render.com
2. **Create a new Web Service**
3. **Deploy** - you'll get a URL like:
   ```
   https://your-service.onrender.com/api/jobs
   ```
4. **Update Config.swift** with your Render URL

## Option 2: Deploy Your Own Backend

### Quick Node.js/Express Example

1. **Create a new folder** for your backend:
   ```bash
   mkdir job-scraper-backend
   cd job-scraper-backend
   ```

2. **Initialize Node.js project**:
   ```bash
   npm init -y
   npm install express cors
   ```

3. **Create `server.js`**:
   ```javascript
   const express = require('express');
   const cors = require('cors');
   const app = express();

   app.use(cors());
   app.use(express.json());

   app.get('/api/jobs', async (req, res) => {
     const { keywords, location, career_interests } = req.query;
     
     // TODO: Implement actual scraping logic here
     // For now, return sample data
     const jobs = [
       {
         id: "1",
         title: "Software Engineer",
         company: "Tech Corp",
         location: "San Francisco, CA",
         posted_date: "2025-01-15",
         description: "We are looking for a software engineer...",
         url: "https://techcorp.com/jobs/1",
         salary: "$120,000 - $150,000",
         job_type: "Full-time"
       }
     ];
     
     res.json(jobs);
   });

   const PORT = process.env.PORT || 3000;
   app.listen(PORT, () => {
     console.log(`Server running on port ${PORT}`);
   });
   ```

4. **Deploy to one of the platforms above** (Vercel, Railway, Render, etc.)

5. **Get your deployment URL** and update Config.swift

## Option 3: Use a Local Development Server (For Testing)

If you want to test locally first:

1. **Run your backend locally** (e.g., `node server.js` on port 3000)
2. **Use ngrok to expose it**:
   ```bash
   # Install ngrok: https://ngrok.com/download
   ngrok http 3000
   ```
3. **Copy the ngrok URL** (e.g., `https://abc123.ngrok.io`)
4. **Update Config.swift**:
   ```swift
   static let jobScrapingBackendURL = "https://abc123.ngrok.io/api/jobs"
   ```

**Note**: ngrok URLs change each time you restart, so this is only for testing.

## Option 4: Use an Existing Job API (If Available)

Some job boards offer APIs (though many require approval):

- **Adzuna API**: https://developer.adzuna.com
- **The Muse API**: https://www.themuse.com/developers/api/v2
- **GitHub Jobs API**: https://jobs.github.com/api (deprecated but still works)

If you use one of these, update Config.swift with their endpoint.

## Recommended: Supabase Edge Function (Since you're already using Supabase)

Here's a quick Supabase Edge Function setup:

1. **Install Supabase CLI**:
   ```bash
   npm install -g supabase
   ```

2. **Initialize Supabase in your project**:
   ```bash
   supabase init
   ```

3. **Create the function**:
   ```bash
   supabase functions new scrape-jobs
   ```

4. **Edit `supabase/functions/scrape-jobs/index.ts`**:
   ```typescript
   import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

   serve(async (req) => {
     const { keywords, location, career_interests } = await req.json()
     
     // TODO: Implement scraping logic
     const jobs = [
       {
         id: "1",
         title: "Software Engineer",
         company: "Tech Corp",
         location: "San Francisco, CA",
         posted_date: "2025-01-15",
         description: "Job description...",
         url: "https://example.com/job/1",
         salary: null,
         job_type: "Full-time"
       }
     ]
     
     return new Response(JSON.stringify(jobs), {
       headers: { "Content-Type": "application/json" },
     })
   })
   ```

5. **Deploy**:
   ```bash
   supabase functions deploy scrape-jobs
   ```

6. **Get your function URL** from the output and update Config.swift

## What to Do Right Now

**If you don't have a backend yet**, you can:

1. **Temporarily disable backend scraping** by commenting out the backend call in `FeedView.swift`
2. **Use only Supabase** for now (jobs you manually add to your database)
3. **Set up the backend later** when you're ready

To temporarily disable backend scraping, edit `FeedView.swift` and comment out lines 152-164:

```swift
// Fetch from job scraping service (job boards, company pages, ATS)
// do {
//     let scrapedPosts = try await JobScrapingService.shared.fetchJobsFromBackend(
//         careerInterests: careerInterests
//     )
//     allPosts.append(contentsOf: scrapedPosts)
// } catch {
//     // If backend API is not available, try direct scraping (limited)
//     print("⚠️ Backend API not available, attempting direct scraping...")
//     do {
//         let directPosts = try await JobScrapingService.shared.fetchJobsFromAllSources(
//             careerInterests: careerInterests
//         )
//         allPosts.append(contentsOf: directPosts)
//     } catch {
//         print("⚠️ Direct scraping also failed: \(error.localizedDescription)")
//     }
// }
```

The app will still work and show jobs from Supabase, just without the scraped jobs from job boards.

## Next Steps

1. Choose a hosting option (Supabase Edge Functions recommended)
2. Set up your backend service
3. Implement job scraping logic
4. Deploy and get your URL
5. Update `Config.swift` with your backend URL


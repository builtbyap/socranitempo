# Deploy Playwright-Based Workday Scraping

The Playwright service has been deployed with the new `/scrape` endpoint. Now you need to deploy the updated Edge Function.

## Step 1: Go to Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project (`jlkebdnvjjdwedmbfqou`)

## Step 2: Navigate to Edge Functions

1. Click **"Edge Functions"** in the left sidebar
2. Find the function named **`smooth-endpoint`** (this is your job scraping function)

## Step 3: Update the Function Code

1. Click on **`smooth-endpoint`** to open it
2. Click **"Edit"** or the code editor icon
3. **Select ALL** the existing code (Cmd+A or Ctrl+A)
4. **Delete it**
5. **Open** `edge-function-code-with-adzuna.ts` from your project
6. **Copy ALL** the code from that file
7. **Paste** it into the Supabase editor

## Step 4: Set Environment Variable

1. In the Edge Function editor, look for **"Environment Variables"** or **"Secrets"** section
2. Add or update:
   - **Key**: `FLY_PLAYWRIGHT_SERVICE_URL`
   - **Value**: `https://surgeapp-playwright.fly.dev`
3. Save the environment variable

## Step 5: Deploy

1. Click **"Deploy"** button (usually top right)
2. Wait for deployment (you'll see a loading indicator)
3. When it says "Deployed" or shows a success message, you're done!

## Step 6: Test

After deployment, test by:
1. Running your iOS app
2. Checking the console logs
3. You should see jobs being scraped from Workday

## Troubleshooting

If you still get 0 jobs:

1. **Check Edge Function logs**:
   - Go to Supabase Dashboard → Edge Functions → smooth-endpoint
   - Click **"Logs"** tab
   - Look for errors like:
     - `Playwright service error: 502`
     - `Failed to scrape with Playwright`
     - `FLY_PLAYWRIGHT_SERVICE_URL is not set`

2. **Check Playwright service**:
   ```bash
   curl https://surgeapp-playwright.fly.dev/health
   ```
   Should return: `{"status":"ok","service":"playwright-automation"}`

3. **Test the scrape endpoint**:
   ```bash
   curl -X POST https://surgeapp-playwright.fly.dev/scrape \
     -H "Content-Type: application/json" \
     -d '{"companyUrl":"https://apple.wd3.myworkdayjobs.com/apple_Careers","keywords":"Software Engineer","location":""}'
   ```

4. **Verify environment variable**:
   - Make sure `FLY_PLAYWRIGHT_SERVICE_URL` is set in Supabase Edge Function settings
   - It should be: `https://surgeapp-playwright.fly.dev`

## What Changed

- **Before**: Used Cheerio (static HTML parsing) - couldn't see JavaScript-rendered content
- **After**: Uses Playwright (browser automation) - can see JavaScript-rendered Workday pages

This should fix the issue of getting 0 jobs from your career interests!


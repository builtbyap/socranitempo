# Troubleshooting: No Job Posts Appearing

If you're not seeing any job posts when searching, check the following:

## 1. Check Edge Function Deployment

The app uses the Supabase Edge Function `smooth-endpoint` for job scraping.

**To verify it's deployed:**
1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Go to **Edge Functions** in the left sidebar
4. Look for a function named `smooth-endpoint`
5. If it doesn't exist, you need to deploy it (see below)

**If the function exists, check its logs:**
1. Click on `smooth-endpoint`
2. Go to the **Logs** tab
3. Look for errors or warnings
4. Try invoking the function with test parameters

## 2. Deploy the Edge Function

If `smooth-endpoint` doesn't exist or needs updating:

1. Go to Supabase Dashboard → Edge Functions
2. Click **Create a new function** or edit existing `smooth-endpoint`
3. Copy ALL code from `edge-function-code-with-adzuna.ts`
4. Paste it into the function editor
5. Click **Deploy**

**Function URL should be:**
```
https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/smooth-endpoint
```

This should match `Config.jobScrapingBackendURL` in `Config.swift`

## 3. Check Environment Variables

The edge function needs these environment variables set in Supabase:

1. Go to Edge Functions → `smooth-endpoint` → Settings
2. Check for **Environment Variables** or **Secrets**
3. Ensure these are set:
   - `JOBSPY_SERVICE_URL` - URL of your deployed JobSpy service (if using JobSpy)

**If JOBSPY_SERVICE_URL is not set:**
- JobSpy scraping will fail
- You'll only get jobs from The Muse and Workday

## 4. Check Console Logs

In Xcode, check the console output when you search for jobs. Look for:

- `🔍 Fetching jobs from backend...` - Request started
- `✅ Fetched X jobs from backend` - Success
- `⚠️ WARNING: Backend returned 0 jobs!` - Edge function returned empty array
- `❌ Backend API error: ...` - Request failed

## 5. Test the Edge Function Directly

Test the edge function with curl or in Supabase Dashboard:

**In Supabase Dashboard:**
1. Go to Edge Functions → `smooth-endpoint`
2. Click **Invoke function**
3. Use these query parameters:
   ```
   keywords=software engineer
   location=San Francisco
   ```
4. Click **Invoke**
5. Check the **Response** tab

**Expected response:**
- Array of job objects with `id`, `title`, `company`, `location`, etc.
- If empty array `[]`, the function is working but found no jobs
- If error, check the Logs tab

## 6. Common Issues

### Issue: "Backend returned 0 jobs"
**Possible causes:**
- Edge function is working but found no matching jobs
- Filters are too strict
- Career interests/keywords don't match any jobs
- JobSpy service is not deployed (if using JobSpy)

**Solution:**
- Check Edge Function logs
- Try searching with broader keywords
- Verify JobSpy service is deployed (if using JobSpy)

### Issue: "Backend API error: HTTP 404"
**Cause:** Edge function `smooth-endpoint` doesn't exist

**Solution:**
- Deploy the edge function (see step 2)

### Issue: "Backend API error: HTTP 500"
**Cause:** Edge function has an error

**Solution:**
- Check Edge Function logs in Supabase Dashboard
- Look for JavaScript errors or missing environment variables

### Issue: "Request timed out"
**Cause:** Edge function is taking too long (>180 seconds)

**Solution:**
- Check Edge Function logs
- The function might be scraping too many companies
- Consider reducing the number of sources or queries

## 7. Verify Config.swift

Make sure `Config.swift` has the correct URL:

```swift
static let jobScrapingBackendURL = "https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/smooth-endpoint"
```

This should match your actual Supabase project URL and function name.

## 8. Quick Test

Try a simple test search:
1. Open the app
2. Go to the Feed tab
3. Make sure you have career interests set (or use default)
4. Pull to refresh
5. Check console logs for the backend request

If you see `⚠️ WARNING: Backend returned 0 jobs!`, the edge function is working but found no jobs. Check the logs to see why.

If you see `❌ Backend API error: ...`, there's an issue with the edge function deployment or configuration.


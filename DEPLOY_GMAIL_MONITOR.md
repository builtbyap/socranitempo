# Deploy Gmail Monitor Edge Function

The 404 error means the function isn't deployed yet. Follow these steps:

## Step 1: Go to Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project (`jlkebdnvjjdwedmbfqou`)

## Step 2: Navigate to Edge Functions

1. Click **"Edge Functions"** in the left sidebar
2. You should see a list of your functions (or an empty list if none exist)

## Step 3: Create New Function

1. Click **"Create a new function"** button (usually top right)
2. Choose **"Via Editor"** (easiest option)
3. Name it: `gmail-monitor` (exactly this, lowercase with hyphen)
4. Click **"Create"** or **"Continue"**

## Step 4: Paste the Code

1. The editor will open with some default code
2. **Select ALL** the default code (Cmd+A or Ctrl+A)
3. **Delete it**
4. **Open** `edge-function-gmail-monitor.ts` from your project
5. **Copy ALL** the code from that file
6. **Paste** it into the Supabase editor

## Step 5: Deploy

1. Click **"Deploy"** button (usually top right)
2. Wait for deployment (you'll see a loading indicator)
3. When it says "Deployed" or shows a success message, you're done!

## Step 6: Get the Function URL

After deployment, you'll see the function URL:
```
https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
```

**Copy this URL** - you'll need it for the cron job.

## Step 7: Set Environment Variables

The function needs Gmail API credentials:

1. Go to **Project Settings** → **Edge Functions** → **Secrets**
2. Add these environment variables:
   - `GMAIL_CLIENT_ID` = Your Google OAuth Client ID
   - `GMAIL_CLIENT_SECRET` = Your Google OAuth Client Secret
   - `GMAIL_REFRESH_TOKEN` = Your Gmail refresh token (from OAuth Playground)

## Step 8: Test the Function

Test it works:

1. In Supabase Dashboard → Edge Functions → gmail-monitor
2. Click **"Invoke function"**
3. Click **"Invoke"**
4. Check the **Response** tab

**Expected response:**
```json
{
  "success": true,
  "checked": 5,
  "found": 0,
  "emails": []
}
```

If you see this, the function is working! ✅

## Step 9: Update Cron Job URL

Now update your cron-job.org settings:

1. Go to [cron-job.org](https://cron-job.org)
2. Edit your cron job
3. Make sure the URL is exactly:
   ```
   https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
   ```
4. Save

## Troubleshooting

### Still getting 404?
- Make sure the function name is exactly `gmail-monitor` (lowercase, hyphen)
- Check the URL in cron-job.org matches exactly
- Wait a minute after deployment for it to propagate

### Getting 500 error?
- Check Edge Function logs in Dashboard
- Verify environment variables are set (GMAIL_CLIENT_ID, etc.)
- Make sure Gmail refresh token is valid

### Function not showing up?
- Refresh the Edge Functions page
- Check if deployment completed successfully
- Look for any error messages in the deployment log


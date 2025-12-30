# Gmail Monitoring Quick Start

This is a simplified guide to get Gmail monitoring working quickly.

## Prerequisites

1. Google Cloud Project with Gmail API enabled
2. OAuth 2.0 credentials (Web application type)
3. Supabase project with Edge Functions enabled

## Step 1: Get OAuth Credentials

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create/select a project
3. Enable **Gmail API**
4. Go to "Credentials" > "Create Credentials" > "OAuth client ID"
5. Choose "Web application"
6. Add redirect URI: `https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-oauth-callback`
7. Save **Client ID** and **Client Secret**

## Step 2: Deploy Edge Functions

### Deploy Gmail Monitor Function

```bash
cd /Users/abongmabo/Desktop/surgeapp
supabase functions deploy gmail-monitor --project-ref jlkebdnvjjdwedmbfqou
```

### Set Environment Variables

In Supabase Dashboard > Edge Functions > Secrets:

```bash
GMAIL_CLIENT_ID=your-client-id-here
GMAIL_CLIENT_SECRET=your-client-secret-here
GMAIL_REFRESH_TOKEN=will-be-set-after-oauth
```

## Step 3: Create Database Table

Run this SQL in Supabase SQL Editor:

```sql
CREATE TABLE IF NOT EXISTS application_emails (
  id TEXT PRIMARY KEY,
  from_email TEXT NOT NULL,
  subject TEXT NOT NULL,
  body TEXT,
  received_date TEXT,
  is_application_confirmation BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

ALTER TABLE application_emails ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations" ON application_emails
  FOR ALL USING (true);
```

## Step 4: Get Refresh Token (One-Time Setup)

### ⚠️ IMPORTANT: Configure Redirect URI First

Before using OAuth Playground, you must add the redirect URI to your OAuth client:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project → **APIs & Services** → **Credentials**
3. Click on your OAuth 2.0 Client ID (Web application type)
4. Under **"Authorized redirect URIs"**, add:
   ```
   https://developers.google.com/oauthplayground
   ```
5. Click **"Save"**
6. Wait a few seconds for changes to propagate

### Option A: Using OAuth Playground (Easiest)

**⚠️ IMPORTANT: Add Test Users First**

If your OAuth consent screen is in "Testing" mode, you must add test users:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project → **APIs & Services** → **OAuth consent screen**
3. Scroll to **"Test users"** section
4. Click **"+ ADD USERS"**
5. Add: `thesocrani@gmail.com`
6. Click **"Add"** and **"Save"**

**Now proceed with OAuth Playground:**

1. Go to [OAuth 2.0 Playground](https://developers.google.com/oauthplayground/)
2. Click the gear icon (⚙️) > Check "Use your own OAuth credentials"
3. Enter your Client ID and Client Secret
4. Click "Close"
5. In the left panel, find "Gmail API v1"
6. Select `https://www.googleapis.com/auth/gmail.readonly`
7. Click "Authorize APIs"
8. Sign in with `thesocrani@gmail.com` (must be a test user)
9. Click "Exchange authorization code for tokens"
10. Copy the **Refresh token**
11. Add it to Supabase Edge Function secrets as `GMAIL_REFRESH_TOKEN`

**Troubleshooting:**
- If you get "redirect_uri_mismatch", see `FIX_OAUTH_REDIRECT.md`
- If you get "access_denied" or "not completed verification", see `FIX_OAUTH_TESTING_MODE.md`

### Option B: Using iOS App (Future)

The app will eventually support OAuth flow directly, but for now use Option A.

## Step 5: Set Up Scheduled Monitoring

### Using Supabase Cron (Recommended)

**First, enable the extensions:**
1. Go to Supabase Dashboard > Database > Extensions
2. Enable `pg_cron` extension
3. Enable `http` or `pg_net` extension (for HTTP requests)

**Then, create the cron job:**

Go to **SQL Editor** and run:

```sql
SELECT cron.schedule(
  'gmail-monitor-job',
  '*/5 * * * *',  -- Every 5 minutes
  $$
  SELECT net.http_post(
    url := 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_ANON_KEY_HERE',
      'apikey', 'YOUR_ANON_KEY_HERE'
    ),
    body := '{}'::jsonb
  ) AS request_id;
  $$
);
```

**Replace `YOUR_ANON_KEY_HERE`** with your Supabase anon key (found in Dashboard → Settings → API)

**See `SUPABASE_CRON_SETUP.md` for detailed instructions.**

### Using External Cron Service

Use [cron-job.org](https://cron-job.org) or similar:

- **URL**: `https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor`
- **Method**: POST
- **Headers**:
  - `Authorization: Bearer YOUR_ANON_KEY`
  - `apikey: YOUR_ANON_KEY`
- **Schedule**: Every 5 minutes

## Step 6: Test

1. Send a test email to `thesocrani@gmail.com` with subject "Application Received"
2. Wait for cron job to run (or manually call the edge function)
3. Check Supabase `application_emails` table
4. Check iOS app for push notification

## Step 7: View Emails in App

The `ApplicationEmailsView` is ready to use. You can:
- Add it as a new tab in `ContentView.swift`
- Or add it as a section in `ApplicationsView.swift`

## Troubleshooting

### "Failed to refresh token"
- Verify `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`, and `GMAIL_REFRESH_TOKEN` are set correctly
- Make sure the refresh token hasn't expired (they can be revoked)

### "No emails found"
- Check that emails are unread
- Verify the search query in `edge-function-gmail-monitor.ts`
- Make sure the email address is `thesocrani@gmail.com`

### "Gmail API error: 401"
- Token expired or invalid
- Re-authenticate and get a new refresh token

## Next Steps

1. Implement OAuth flow in iOS app (see `GMAIL_SETUP_GUIDE.md`)
2. Add email detail view
3. Add email filtering and search
4. Link emails to applications automatically


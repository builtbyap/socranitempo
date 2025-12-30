# Add Gmail Secrets to Supabase

Follow these steps to add your Gmail API credentials to Supabase Edge Functions.

## Step 1: Go to Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project (`jlkebdnvjjdwedmbfqou`)

## Step 2: Navigate to Edge Function Secrets

1. Click **"Project Settings"** (gear icon in left sidebar)
2. Click **"Edge Functions"** in the settings menu
3. Scroll down to **"Secrets"** section

## Step 3: Add Gmail Credentials

Add these three secrets (click "Add new secret" for each):

### Secret 1: GMAIL_REFRESH_TOKEN
- **Name**: `GMAIL_REFRESH_TOKEN`
- **Value**: `YOUR_REFRESH_TOKEN_HERE` (get from OAuth Playground - see GMAIL_QUICK_START.md)
- Click **"Save"**

### Secret 2: GMAIL_CLIENT_ID
- **Name**: `GMAIL_CLIENT_ID`
- **Value**: Your Google OAuth Client ID (from Google Cloud Console)
- Click **"Save"**

### Secret 3: GMAIL_CLIENT_SECRET
- **Name**: `GMAIL_CLIENT_SECRET`
- **Value**: Your Google OAuth Client Secret (from Google Cloud Console)
- Click **"Save"**

## Step 4: Verify Secrets Are Set

You should see all three secrets listed:
- ✅ `GMAIL_REFRESH_TOKEN`
- ✅ `GMAIL_CLIENT_ID`
- ✅ `GMAIL_CLIENT_SECRET`

## Step 5: Test the Function

After adding the secrets, test the function:

```bash
curl -L -X POST 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impsa2ViZG52ampkd2VkbWJmcW91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE0NzU5NjQsImV4cCI6MjA1NzA1MTk2NH0.0dyDFawIks508PffUcovXN-M8kaAOgomOhe5OiEal3o' \
  -H 'apikey: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Impsa2ViZG52ampkd2VkbWJmcW91Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE0NzU5NjQsImV4cCI6MjA1NzA1MTk2NH0.0dyDFawIks508PffUcovXN-M8kaAOgomOhe5OiEal3o' \
  -H 'Content-Type: application/json'
```

**Expected response:**
```json
{
  "success": true,
  "checked": 5,
  "found": 0,
  "emails": []
}
```

## Where to Find Client ID and Secret

If you don't have your Client ID and Secret:

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Credentials**
4. Find your OAuth 2.0 Client ID (Web application type)
5. Click on it to see:
   - **Client ID** (copy this)
   - **Client secret** (copy this)

## Troubleshooting

### "Failed to get Gmail access token"
- Make sure all three secrets are set correctly
- Check for typos in secret names (must be exact: `GMAIL_REFRESH_TOKEN`, `GMAIL_CLIENT_ID`, `GMAIL_CLIENT_SECRET`)
- Verify the refresh token is valid (not expired)

### "Invalid client"
- Check that Client ID and Secret are correct
- Make sure they're from the same Google Cloud project

### "Invalid grant"
- Refresh token may be expired or revoked
- Get a new refresh token from OAuth Playground


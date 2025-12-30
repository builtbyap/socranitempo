# Gmail API Integration Setup Guide

This guide will help you set up Gmail API monitoring to receive notifications when companies send application confirmation emails to `thesocrani@gmail.com`.

## Step 1: Create Google Cloud Project

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select an existing one
3. Enable the **Gmail API**:
   - Go to "APIs & Services" > "Library"
   - Search for "Gmail API"
   - Click "Enable"

## Step 2: Create OAuth 2.0 Credentials

1. Go to "APIs & Services" > "Credentials"
2. Click "Create Credentials" > "OAuth client ID"
3. Choose "iOS" as the application type
4. Enter your bundle identifier (e.g., `com.yourcompany.surgeapp`)
5. Download the configuration file
6. Also create a "Web application" credential (needed for refresh tokens)

### For Web Application (Refresh Token):
1. Create another OAuth client ID
2. Choose "Web application"
3. Add authorized redirect URIs:
   - `https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-oauth-callback`
4. Save the **Client ID** and **Client Secret**

## Step 3: Configure OAuth Scopes

The app needs these Gmail API scopes:
- `https://www.googleapis.com/auth/gmail.readonly` - Read emails
- `https://www.googleapis.com/auth/gmail.modify` - Mark emails as read

## Step 4: Set Up Supabase Environment Variables

Add these to your Supabase Edge Function secrets:

```bash
# In Supabase Dashboard > Edge Functions > Secrets
GMAIL_CLIENT_ID=your-web-client-id
GMAIL_CLIENT_SECRET=your-web-client-secret
GMAIL_REFRESH_TOKEN=will-be-set-after-oauth-flow
```

## Step 5: Implement OAuth Flow in iOS App

The iOS app needs to:
1. Request Google Sign-In with Gmail scopes
2. Get the authorization code
3. Exchange it for access and refresh tokens
4. Store refresh token in Supabase (via Edge Function)

### Update GoogleSignInService.swift

```swift
import GoogleSignIn

class GoogleSignInService {
    static let shared = GoogleSignInService()
    
    func signInWithGmail() async throws -> (accessToken: String, refreshToken: String?) {
        guard let presentingViewController = await UIApplication.shared.windows.first?.rootViewController else {
            throw GmailError.notAuthenticated
        }
        
        let config = GIDConfiguration(clientID: Config.googleClientID)
        GIDSignIn.sharedInstance.configuration = config
        
        // Request Gmail scopes
        let scopes = [
            "https://www.googleapis.com/auth/gmail.readonly",
            "https://www.googleapis.com/auth/gmail.modify"
        ]
        
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: presentingViewController,
            hint: nil,
            additionalScopes: scopes
        )
        
        guard let accessToken = result.user.accessToken.tokenString else {
            throw GmailError.notAuthenticated
        }
        
        // Get refresh token (requires server-side exchange)
        // You'll need to exchange the authorization code server-side
        // For now, store access token
        GmailMonitoringService.shared.setAccessToken(accessToken)
        
        return (accessToken, nil)
    }
}
```

## Step 6: Create OAuth Callback Edge Function

Create `edge-function-gmail-oauth-callback.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const url = new URL(req.url)
  const code = url.searchParams.get('code')
  
  if (!code) {
    return new Response('Missing authorization code', { status: 400 })
  }
  
  const clientId = Deno.env.get('GMAIL_CLIENT_ID')
  const clientSecret = Deno.env.get('GMAIL_CLIENT_SECRET')
  const redirectUri = `${Deno.env.get('SUPABASE_URL')}/functions/v1/gmail-oauth-callback`
  
  // Exchange code for tokens
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: clientId!,
      client_secret: clientSecret!,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code',
    }),
  })
  
  const tokens = await response.json()
  
  // Store refresh token in Supabase (you'll need to create a table for this)
  // For now, save to environment variable manually
  
  return new Response('Gmail connected! You can close this window.', {
    headers: { 'Content-Type': 'text/html' },
  })
})
```

## Step 7: Set Up Scheduled Monitoring

### Option A: Supabase Cron Job (Recommended)

1. Go to Supabase Dashboard > Database > Cron Jobs
2. Create a new cron job:
   - **Name**: `gmail-monitor`
   - **Schedule**: `*/5 * * * *` (every 5 minutes)
   - **SQL**: 
   ```sql
   SELECT net.http_post(
     url := 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor',
     headers := '{"Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb
   );
   ```

### Option B: External Cron Service

Use a service like [cron-job.org](https://cron-job.org) to call:
```
POST https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
Headers:
  Authorization: Bearer YOUR_ANON_KEY
```

## Step 8: Create Supabase Table

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

-- Enable RLS
ALTER TABLE application_emails ENABLE ROW LEVEL SECURITY;

-- Create policy (adjust as needed)
CREATE POLICY "Allow all operations" ON application_emails
  FOR ALL USING (true);
```

## Step 9: Request Notification Permissions

In your iOS app, request notification permissions:

```swift
import UserNotifications

func requestNotificationPermissions() {
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
        if granted {
            print("✅ Notification permissions granted")
        } else {
            print("⚠️ Notification permissions denied")
        }
    }
}
```

## Step 10: Start Monitoring

In your app's `AppDelegate` or main view:

```swift
// Request permissions
requestNotificationPermissions()

// Start Gmail monitoring (checks every 5 minutes)
GmailMonitoringService.shared.startMonitoring(interval: 300)
```

## Testing

1. Send a test email to `thesocrani@gmail.com` with subject "Application Received"
2. Wait for the cron job to run (or manually trigger the edge function)
3. Check if you receive a push notification
4. Check the `application_emails` table in Supabase

## Troubleshooting

### "Gmail API is not authenticated"
- Make sure you've completed the OAuth flow
- Check that refresh token is stored in Supabase

### "No emails found"
- Verify the email address is correct
- Check that emails are unread
- Adjust the search query in `edge-function-gmail-monitor.ts`

### "Failed to refresh token"
- Check that `GMAIL_CLIENT_ID` and `GMAIL_CLIENT_SECRET` are set correctly
- Verify the refresh token is valid

## Security Notes

- Never commit OAuth credentials to git
- Store refresh tokens securely in Supabase
- Use Row Level Security (RLS) policies to protect email data
- Consider encrypting email bodies in the database


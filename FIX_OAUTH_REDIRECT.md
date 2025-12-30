# Fix OAuth Redirect URI Mismatch

The error "redirect_uri_mismatch" means your OAuth client doesn't have the correct redirect URI authorized.

## Solution: Add OAuth Playground Redirect URI

### Step 1: Go to Google Cloud Console

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Select your project
3. Go to **APIs & Services** → **Credentials**
4. Find your OAuth 2.0 Client ID (the one ending in `.apps.googleusercontent.com`)
5. Click on it to edit

### Step 2: Add Authorized Redirect URIs

In the OAuth client settings, find **"Authorized redirect URIs"** and add:

```
https://developers.google.com/oauthplayground
```

**Important**: Add this exact URI (no trailing slash).

### Step 3: Save

1. Click **"Save"** at the bottom
2. Wait a few seconds for changes to propagate

### Step 4: Try OAuth Playground Again

1. Go back to [OAuth 2.0 Playground](https://developers.google.com/oauthplayground/)
2. Click the gear icon (⚙️)
3. Check "Use your own OAuth credentials"
4. Enter your Client ID and Secret
5. Click "Close"
6. Try authorizing again

## Alternative: Use a Different Method

If OAuth Playground still doesn't work, you can create a simple web page to get the refresh token:

### Option A: Use Supabase Edge Function for OAuth

Create a simple OAuth callback function in Supabase that handles the redirect and gets the refresh token.

### Option B: Use Google's OAuth 2.0 Tool

1. Go to [Google OAuth 2.0 Playground](https://developers.google.com/oauthplayground/)
2. But first, make sure the redirect URI is added to your OAuth client

### Option C: Manual OAuth Flow

You can manually construct the OAuth URL and handle the callback, but this is more complex.

## Quick Fix Checklist

- [ ] Added `https://developers.google.com/oauthplayground` to Authorized redirect URIs
- [ ] Saved the OAuth client settings
- [ ] Waited a few seconds for changes to propagate
- [ ] Tried OAuth Playground again with your credentials
- [ ] Successfully got refresh token

## Still Not Working?

If you still get the error after adding the redirect URI:

1. **Check the exact redirect URI**: Make sure it's exactly `https://developers.google.com/oauthplayground` (no trailing slash, no http)
2. **Wait longer**: Sometimes Google takes a minute to propagate changes
3. **Clear browser cache**: Try in an incognito/private window
4. **Check OAuth client type**: Make sure it's a "Web application" type, not "Desktop app"


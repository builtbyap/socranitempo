# Troubleshooting Gmail Authentication

If you're still getting "Failed to get Gmail access token" after adding secrets, try these fixes:

## Check 1: Verify Secrets Are Set Correctly

1. Go to **Supabase Dashboard** → **Project Settings** → **Edge Functions** → **Secrets**
2. Verify you see all three secrets:
   - `GMAIL_REFRESH_TOKEN`
   - `GMAIL_CLIENT_ID`
   - `GMAIL_CLIENT_SECRET`
3. Make sure the names are **exactly** as shown (case-sensitive, no extra spaces)

## Check 2: Redeploy the Edge Function

After adding secrets, you may need to redeploy the function:

1. Go to **Edge Functions** → **gmail-monitor**
2. Click **"Redeploy"** or **"Deploy"** (even if no code changed)
3. Wait for deployment to complete

## Check 3: Check Edge Function Logs

1. Go to **Edge Functions** → **gmail-monitor** → **Logs**
2. Look for error messages that might indicate:
   - Which secret is missing
   - Token refresh errors
   - API errors

## Check 4: Test Token Refresh Manually

The function needs to refresh the access token. Test if the refresh token works:

```bash
# Replace with your actual values
CLIENT_ID="your-client-id"
CLIENT_SECRET="your-client-secret"
REFRESH_TOKEN="YOUR_REFRESH_TOKEN_HERE"

curl -X POST https://oauth2.googleapis.com/token \
  -d "client_id=$CLIENT_ID" \
  -d "client_secret=$CLIENT_SECRET" \
  -d "refresh_token=$REFRESH_TOKEN" \
  -d "grant_type=refresh_token"
```

**Expected response:**
```json
{
  "access_token": "ya29...",
  "expires_in": 3599,
  "scope": "...",
  "token_type": "Bearer"
}
```

If this fails, the refresh token might be invalid.

## Check 5: Verify Secret Names in Code

The Edge Function code expects these exact names:
- `GMAIL_REFRESH_TOKEN`
- `GMAIL_CLIENT_ID`
- `GMAIL_CLIENT_SECRET`

Make sure they match exactly in Supabase.

## Check 6: Common Issues

### Issue: Secrets not accessible
- **Fix**: Make sure you're adding secrets in the correct project
- **Fix**: Redeploy the function after adding secrets

### Issue: Refresh token expired
- **Fix**: Get a new refresh token from OAuth Playground
- **Fix**: Make sure you're using the refresh token (not access token)

### Issue: Client ID/Secret mismatch
- **Fix**: Make sure Client ID and Secret are from the same OAuth client
- **Fix**: Verify they're for a "Web application" type client

## Quick Fix: Add Debug Logging

If you want to see what's happening, you can temporarily add logging to the Edge Function:

```typescript
// In edge-function-gmail-monitor.ts, in getAccessToken function:
console.log('GMAIL_REFRESH_TOKEN exists:', !!Deno.env.get('GMAIL_REFRESH_TOKEN'))
console.log('GMAIL_CLIENT_ID exists:', !!Deno.env.get('GMAIL_CLIENT_ID'))
console.log('GMAIL_CLIENT_SECRET exists:', !!Deno.env.get('GMAIL_CLIENT_SECRET'))
```

Then check the logs to see which secret is missing.

## Still Not Working?

1. **Double-check all three secrets are set** in Supabase
2. **Redeploy the Edge Function** after adding secrets
3. **Check the logs** for specific error messages
4. **Verify the refresh token** works with the manual curl test above


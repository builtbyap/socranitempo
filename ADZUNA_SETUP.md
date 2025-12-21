# Adzuna API Setup Instructions

## Your API Credentials

- **Application ID:** `ff850947`
- **API Key:** `114516221e332fe7ddb772224a68e0bb`

## Option 1: Use Environment Variables (Recommended)

### Step 1: Add to Supabase Edge Function Environment Variables

1. Go to Supabase Dashboard
2. Navigate to: **Edge Functions** → **Settings** (or your function settings)
3. Add these environment variables:
   - `ADZUNA_APP_ID` = `ff850947`
   - `ADZUNA_APP_KEY` = `114516221e332fe7ddb772224a68e0bb`

### Step 2: Deploy the Code

1. Copy the code from `edge-function-code-with-adzuna.ts`
2. Paste into your Supabase Edge Function (`smooth-endpoint`)
3. The code will automatically use the environment variables
4. Click **Deploy**

## Option 2: Hardcode (For Testing Only)

The code I provided has your credentials as fallbacks, but **this is not recommended for production** as it exposes your API keys.

## Testing

After deploying, test your endpoint:

```bash
curl -X GET "https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/smooth-endpoint?keywords=software%20engineer&location=San%20Francisco" \
  -H "apikey: YOUR_SUPABASE_KEY" \
  -H "Authorization: Bearer YOUR_SUPABASE_KEY"
```

You should see real job listings from Adzuna!

## API Limits

- **Free Tier:** 50 requests per day
- **Paid Plans:** Higher limits available

## Supported Countries

Change the `country` variable in the code to:
- `us` - United States
- `uk` - United Kingdom
- `ca` - Canada
- `au` - Australia
- `de` - Germany
- And more...

## What You'll Get

The API returns real, current job listings with:
- Job titles
- Company names
- Locations
- Salaries (when available)
- Job descriptions
- Application URLs
- Posted dates

All formatted to match your `JobPost` structure!


# Fix: "schema net does not exist" Error

The error means the `http` extension isn't enabled or uses a different function name. Here are solutions:

## Solution 1: Enable the Correct Extension

1. Go to **Supabase Dashboard** → **Database** → **Extensions**
2. Look for and enable one of these:
   - `pg_net` (recommended for newer Supabase projects)
   - `http`
   - `plpgsql_http`

## Solution 2: Use pg_net (If Available)

If `pg_net` is available, update your cron job:

```sql
-- First, unschedule the old job
SELECT cron.unschedule('gmail-monitor-job');

-- Create new job with pg_net
SELECT cron.schedule(
  'gmail-monitor-job',
  '*/5 * * * *',
  $$
  SELECT pg_net.http_post(
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

## Solution 3: Create a Database Function (Recommended)

This is more reliable and works even if HTTP extensions aren't available:

```sql
-- Create a function that calls the Edge Function
CREATE OR REPLACE FUNCTION call_gmail_monitor()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  response_status int;
  response_body text;
BEGIN
  -- Use pg_net if available
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    PERFORM pg_net.http_post(
      url := 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_ANON_KEY_HERE',
        'apikey', 'YOUR_ANON_KEY_HERE'
      ),
      body := '{}'::jsonb
    );
  ELSE
    -- Fallback: Log that extension is needed
    RAISE NOTICE 'pg_net extension not available. Please enable it or use external cron service.';
  END IF;
END;
$$;

-- Schedule the function
SELECT cron.unschedule('gmail-monitor-job');
SELECT cron.schedule(
  'gmail-monitor-job',
  '*/5 * * * *',
  'SELECT call_gmail_monitor();'
);
```

## Solution 4: Use External Cron Service (Easiest)

If extensions aren't available, use an external service:

### Option A: cron-job.org (Free)

1. Go to [cron-job.org](https://cron-job.org)
2. Sign up (free)
3. Click "Create cronjob"
4. Fill in:
   - **Title**: Gmail Monitor
   - **Address**: `https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor`
   - **Schedule**: Every 5 minutes
   - **Request method**: POST
   - **Request headers**:
     ```
     Authorization: Bearer YOUR_ANON_KEY
     apikey: YOUR_ANON_KEY
     Content-Type: application/json
     ```
   - **Request body**: `{}`
5. Click "Create cronjob"

### Option B: GitHub Actions (Free)

Create `.github/workflows/gmail-monitor.yml`:

```yaml
name: Gmail Monitor

on:
  schedule:
    - cron: '*/5 * * * *'  # Every 5 minutes
  workflow_dispatch:  # Allow manual trigger

jobs:
  monitor:
    runs-on: ubuntu-latest
    steps:
      - name: Call Gmail Monitor
        run: |
          curl -X POST \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "apikey: ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Content-Type: application/json" \
            https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
```

Add `SUPABASE_ANON_KEY` to GitHub Secrets (Settings → Secrets → Actions).

## Solution 5: Check Available Extensions

Run this to see what's available:

```sql
SELECT * FROM pg_available_extensions WHERE name LIKE '%http%' OR name LIKE '%net%';
```

Then check what's enabled:

```sql
SELECT * FROM pg_extension;
```

## Recommended: Quick Fix with External Service

Since Supabase Cron extensions can be tricky, I **strongly recommend** using **cron-job.org** (Solution 4, Option A) - it's:
- ✅ Free
- ✅ Easy to set up (5 minutes)
- ✅ More reliable than database cron
- ✅ No database extensions needed
- ✅ Can monitor execution history
- ✅ Email alerts on failures

**If your cron job is still failing, see `DEBUG_CRON_FAILURE.md` for step-by-step debugging.**

## Test the Fix

After applying any solution, verify it's working:

### Quick Test (Manual)

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
```

You should see a response with `"success": true` and email count.

### Verify Cron Job is Running

Run this SQL to check execution history:

```sql
SELECT 
  start_time,
  status,
  return_message,
  end_time - start_time AS duration
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 5;
```

**Success indicators:**
- ✅ `status` = `succeeded`
- ✅ Recent `start_time` (within last 10 minutes)
- ✅ No error in `return_message`

**See `VERIFY_CRON_JOB.md` for complete verification guide.**


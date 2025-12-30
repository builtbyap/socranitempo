# Debugging Cron Job Failures

If your cron job status is still "failed", follow these steps to identify and fix the issue.

## Step 1: Get the Exact Error Message

Run this SQL to see the detailed error:

```sql
SELECT 
  start_time,
  status,
  return_message,
  command
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 1;
```

**Copy the `return_message`** - this tells us exactly what's wrong.

## Common Errors and Fixes

### Error 1: "schema net does not exist" or "schema pg_net does not exist"

**Problem**: HTTP extension not enabled or wrong function name.

**Fix Options**:

**Option A: Enable pg_net Extension**
1. Go to Dashboard → Database → Extensions
2. Search for `pg_net`
3. Enable it
4. Update cron job to use `pg_net.http_post`:

```sql
SELECT cron.unschedule('gmail-monitor-job');

SELECT cron.schedule(
  'gmail-monitor-job',
  '*/5 * * * *',
  $$
  SELECT pg_net.http_post(
    url := 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer YOUR_ANON_KEY',
      'apikey', 'YOUR_ANON_KEY'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

**Option B: Use External Cron Service (Recommended)**
If extensions aren't available, use cron-job.org instead - it's more reliable.

### Error 2: "function does not exist"

**Problem**: Wrong function name or extension not properly enabled.

**Fix**: Check which extensions are available:

```sql
SELECT * FROM pg_extension WHERE extname LIKE '%net%' OR extname LIKE '%http%';
```

Then use the correct function:
- If `pg_net` exists: use `pg_net.http_post`
- If `http` exists: use `http_post` or `net.http_post`
- If neither exists: use external cron service

### Error 3: "permission denied" or "must be superuser"

**Problem**: Cron jobs need proper permissions.

**Fix**: Make sure you're running the SQL as a user with proper permissions. Try creating a function with `SECURITY DEFINER`:

```sql
-- Create a function that can be called by cron
CREATE OR REPLACE FUNCTION call_gmail_monitor()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  -- Try pg_net first
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_net') THEN
    PERFORM pg_net.http_post(
      url := 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer YOUR_ANON_KEY',
        'apikey', 'YOUR_ANON_KEY'
      ),
      body := '{}'::jsonb
    );
  ELSE
    RAISE EXCEPTION 'pg_net extension not available. Please enable it or use external cron service.';
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

### Error 4: Edge Function returns error (401, 500, etc.)

**Problem**: The Edge Function itself is failing, not the cron job.

**Fix**: Test the Edge Function directly:

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
```

Check the response. Common issues:
- **401 Unauthorized**: Wrong anon key
- **500 Internal Server Error**: Check Edge Function logs in Dashboard
- **Missing environment variables**: Gmail credentials not set

### Error 5: "syntax error" or "invalid input"

**Problem**: SQL syntax error in the cron job command.

**Fix**: Check your SQL syntax. Make sure:
- All quotes are properly escaped
- Dollar-quoting (`$$`) is used correctly
- No typos in function names

## Recommended Solution: Use External Cron Service

If Supabase Cron keeps failing, use an external service - it's often more reliable:

### cron-job.org (Free, Recommended)

1. Go to [cron-job.org](https://cron-job.org)
2. Sign up (free)
3. Click **"Create cronjob"**
4. Fill in:
   - **Title**: `Gmail Monitor`
   - **Address**: `https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor`
   - **Schedule**: Every 5 minutes
   - **Request method**: `POST`
   - **Request headers** (click "Add header" for each):
     - `Authorization`: `Bearer YOUR_ANON_KEY`
     - `apikey`: `YOUR_ANON_KEY`
     - `Content-Type`: `application/json`
   - **Request body**: `{}`
5. Click **"Create cronjob"**

**Benefits**:
- ✅ No database extensions needed
- ✅ More reliable
- ✅ Execution history and monitoring
- ✅ Email alerts on failures
- ✅ Easy to pause/resume

## Step-by-Step Debugging

1. **Get the error message** (Step 1 above)
2. **Match it to one of the errors above**
3. **Apply the fix**
4. **Wait 5-10 minutes** for next cron run
5. **Check status again**:

```sql
SELECT 
  start_time,
  status,
  return_message
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 1;
```

## Still Not Working?

If none of the fixes work:

1. **Check Edge Function logs**:
   - Dashboard → Edge Functions → gmail-monitor → Logs
   - Look for errors or warnings

2. **Verify Edge Function works manually**:
   ```bash
   curl -X POST \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "apikey: YOUR_ANON_KEY" \
     https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
   ```

3. **Use external cron service** (cron-job.org) - it's the most reliable option

4. **Check Supabase plan limitations**:
   - Some plans may have restrictions on cron jobs
   - Check your project settings

## Quick Fix Checklist

- [ ] Checked `return_message` for exact error
- [ ] Enabled `pg_net` extension
- [ ] Updated cron job to use `pg_net.http_post`
- [ ] Tested Edge Function manually (works?)
- [ ] Verified anon key is correct
- [ ] Checked Edge Function logs
- [ ] Considered using external cron service


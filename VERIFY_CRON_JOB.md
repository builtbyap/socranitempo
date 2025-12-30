# How to Verify Your Cron Job is Working

Follow these steps to check if your Gmail monitoring cron job is running successfully.

## Step 1: Check if the Cron Job is Scheduled

Run this SQL in Supabase SQL Editor:

```sql
SELECT * FROM cron.job WHERE jobname = 'gmail-monitor-job';
```

You should see:
- `jobid`: A unique ID
- `schedule`: `*/5 * * * *` (every 5 minutes)
- `active`: `true`

If you see the job, it's scheduled correctly! ✅

## Step 2: Check Execution History

Check if the job has run and if it succeeded:

```sql
SELECT 
  jobid,
  runid,
  job_pid,
  database,
  username,
  command,
  status,
  return_message,
  start_time,
  end_time,
  end_time - start_time AS duration
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 10;
```

### What to Look For:

✅ **Success**: 
- `status` = `succeeded`
- `return_message` = `null` or shows a request ID
- `end_time` is recent (within last 10 minutes)

❌ **Failed**:
- `status` = `failed`
- `return_message` shows an error (like "schema net does not exist")

## Step 3: Check Recent Executions (Last Hour)

See all runs in the last hour:

```sql
SELECT 
  start_time,
  status,
  return_message,
  end_time - start_time AS duration
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
  AND start_time > NOW() - INTERVAL '1 hour'
ORDER BY start_time DESC;
```

## Step 4: Manually Test the Edge Function

Test if the Edge Function itself works (bypassing cron):

### Option A: Using curl (Terminal)

```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "apikey: YOUR_ANON_KEY" \
  -H "Content-Type: application/json" \
  https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
```

**Expected Response:**
```json
{
  "success": true,
  "checked": 5,
  "found": 2,
  "emails": [...]
}
```

### Option B: Using Supabase Dashboard

1. Go to **Edge Functions** → **gmail-monitor**
2. Click **Invoke function**
3. Click **Invoke**
4. Check the **Response** tab for results

### Option C: Using SQL (If pg_net is working)

```sql
SELECT pg_net.http_post(
  url := 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor',
  headers := jsonb_build_object(
    'Content-Type', 'application/json',
    'Authorization', 'Bearer YOUR_ANON_KEY',
    'apikey', 'YOUR_ANON_KEY'
  ),
  body := '{}'::jsonb
) AS request_id;
```

## Step 5: Check Edge Function Logs

1. Go to **Supabase Dashboard** → **Edge Functions** → **gmail-monitor**
2. Click **Logs** tab
3. Look for recent entries showing:
   - `📧 Starting Gmail monitoring check...`
   - `📬 Found X unread emails`
   - `✅ Found application confirmation: ...`

## Step 6: Check Database for New Emails

Verify emails are being saved:

```sql
SELECT 
  id,
  from_email,
  subject,
  received_date,
  is_application_confirmation,
  created_at
FROM application_emails
ORDER BY created_at DESC
LIMIT 10;
```

If you see emails here, the system is working! ✅

## Step 7: Wait and Monitor

After fixing the cron job:

1. **Wait 5-10 minutes** for the next scheduled run
2. Check execution history again (Step 2)
3. Look for new entries with `status = 'succeeded'`

## Troubleshooting Checklist

### ❌ Cron Job Not Scheduled
- **Fix**: Run the `cron.schedule()` command again

### ❌ Status = "failed", Error = "schema net does not exist"
- **Fix**: Enable `pg_net` extension or use external cron service
- See `SUPABASE_CRON_FIX.md`

### ❌ Status = "failed", Error = "function does not exist"
- **Fix**: Use `pg_net.http_post` instead of `net.http_post`

### ❌ Status = "succeeded" but no emails in database
- **Possible causes**:
  - No unread emails in Gmail
  - Gmail API authentication failed (check refresh token)
  - Edge Function error (check logs)

### ❌ Edge Function returns error
- **Check**:
  - Gmail API credentials are set in Edge Function secrets
  - Refresh token is valid
  - Edge Function logs for specific errors

## Quick Verification Script

Run this all-in-one check:

```sql
-- 1. Check if job exists
SELECT 
  'Job Scheduled' AS check_type,
  CASE 
    WHEN EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'gmail-monitor-job') 
    THEN '✅ YES' 
    ELSE '❌ NO' 
  END AS status;

-- 2. Check last execution
SELECT 
  'Last Execution' AS check_type,
  start_time,
  status,
  CASE 
    WHEN status = 'succeeded' THEN '✅ SUCCESS'
    WHEN status = 'failed' THEN '❌ FAILED: ' || return_message
    ELSE '⏳ PENDING'
  END AS result
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 1;

-- 3. Check emails in database
SELECT 
  'Emails Saved' AS check_type,
  COUNT(*) AS total_emails,
  COUNT(*) FILTER (WHERE is_application_confirmation = true) AS confirmations
FROM application_emails;
```

## Success Indicators

Your cron job is working if:

✅ Job appears in `cron.job` table  
✅ Recent executions show `status = 'succeeded'`  
✅ Edge Function logs show activity  
✅ Emails appear in `application_emails` table  
✅ Manual curl test returns success  

## Next Steps

Once verified:
1. Send a test email to `thesocrani@gmail.com` with subject "Application Received"
2. Wait 5-10 minutes
3. Check `application_emails` table for the new email
4. Check iOS app for push notification (if app is running)


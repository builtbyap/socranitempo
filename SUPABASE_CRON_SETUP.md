# Supabase Cron Setup Guide

Supabase Cron uses PostgreSQL's `pg_cron` extension to schedule recurring tasks. Here's how to set it up for Gmail monitoring.

## Step 1: Enable pg_cron Extension

1. Go to your [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project
3. Navigate to **Database** → **Extensions**
4. Search for `pg_cron`
5. Click **Enable** (or toggle it on)

## Step 2: Enable http Extension (for calling Edge Functions)

1. In the same **Extensions** page
2. Search for `http`, `pg_net`, or `plpgsql_http`
3. Enable one of these extensions:
   - **pg_net** (recommended, newer Supabase projects)
   - **http** (older projects)
   - **plpgsql_http** (alternative)

**Note**: If these extensions aren't available in your Supabase project, use an external cron service instead (see "Alternative: External Cron Service" below).

This allows you to make HTTP requests from SQL to call your Edge Functions.

## Step 3: Create the Cron Job

**First, check which HTTP extension is available:**

```sql
-- Check available extensions
SELECT * FROM pg_available_extensions WHERE name LIKE '%http%' OR name LIKE '%net%';

-- Check enabled extensions
SELECT * FROM pg_extension;
```

**Then, create the cron job based on what's available:**

### Option A: Using pg_net (Recommended if available)

```sql
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

### Option B: Using net.http_post (If http extension is enabled)

```sql
SELECT cron.schedule(
  'gmail-monitor-job',
  '*/5 * * * *',
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

**Important**: 
- Replace `YOUR_ANON_KEY_HERE` with your actual Supabase anon key from Dashboard → Settings → API → `anon` `public` key
- If you get "schema net does not exist" error, see `SUPABASE_CRON_FIX.md` for solutions

## Alternative: Using Supabase Dashboard UI

If your Supabase project has the Cron UI:

1. Go to **Database** → **Cron Jobs** (or **Integrations** → **Cron**)
2. Click **Create job** or **New job**
3. Fill in:
   - **Name**: `gmail-monitor-job`
   - **Schedule**: `*/5 * * * *` (every 5 minutes)
   - **SQL Command**: 
   ```sql
   SELECT net.http_post(
     url := 'https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor',
     headers := jsonb_build_object(
       'Content-Type', 'application/json',
       'Authorization', 'Bearer YOUR_ANON_KEY',
       'apikey', 'YOUR_ANON_KEY'
     ),
     body := '{}'::jsonb
   );
   ```
4. Click **Save** or **Create**

## Cron Schedule Syntax

The schedule uses standard cron syntax: `minute hour day month weekday`

Examples:
- `*/5 * * * *` - Every 5 minutes
- `0 * * * *` - Every hour
- `0 */2 * * *` - Every 2 hours
- `0 9 * * *` - Every day at 9:00 AM
- `0 9 * * 1` - Every Monday at 9:00 AM

## Verify the Cron Job

Check if your job is scheduled:

```sql
SELECT * FROM cron.job;
```

You should see your `gmail-monitor-job` in the list.

## View Job Execution History

Check if the job is running successfully:

```sql
SELECT * FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 10;
```

## Update the Cron Job

To change the schedule or SQL:

```sql
-- First, unschedule the old job
SELECT cron.unschedule('gmail-monitor-job');

-- Then, create a new one with updated settings
SELECT cron.schedule(
  'gmail-monitor-job',
  '*/10 * * * *',  -- Changed to every 10 minutes
  $$ YOUR_UPDATED_SQL $$
);
```

## Delete the Cron Job

To remove the cron job:

```sql
SELECT cron.unschedule('gmail-monitor-job');
```

## Troubleshooting

### "Extension pg_cron does not exist"
- Make sure you've enabled the `pg_cron` extension in Database → Extensions

### "Function net.http_post does not exist" or "schema net does not exist"
- **Check available extensions**: Run `SELECT * FROM pg_available_extensions WHERE name LIKE '%http%' OR name LIKE '%net%';`
- **Enable the correct extension**: Try `pg_net`, `http`, or `plpgsql_http`
- **Use the correct function name**: 
  - If `pg_net` is enabled, use `pg_net.http_post`
  - If `http` is enabled, use `net.http_post` or `http_post`
- **Alternative**: Use an external cron service (see "Alternative: External Cron Service" below) - this is often easier and more reliable
- **See `SUPABASE_CRON_FIX.md`** for detailed troubleshooting

### "Permission denied"
- Make sure you're using the SQL Editor with proper permissions
- Some Supabase plans may have restrictions on cron jobs

### Job not running
- Check the cron job exists: `SELECT * FROM cron.job;`
- Check execution history: `SELECT * FROM cron.job_run_details;`
- Verify your Edge Function URL is correct
- Check Edge Function logs in Dashboard → Edge Functions → gmail-monitor → Logs

## Alternative: External Cron Service

If Supabase Cron isn't available or you prefer external scheduling:

### Option 1: cron-job.org (Free)

1. Go to [cron-job.org](https://cron-job.org)
2. Create account and add new cron job
3. Settings:
   - **URL**: `https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor`
   - **Method**: POST
   - **Headers**:
     - `Authorization: Bearer YOUR_ANON_KEY`
     - `apikey: YOUR_ANON_KEY`
   - **Schedule**: Every 5 minutes

### Option 2: GitHub Actions (Free)

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
            https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
```

Add `SUPABASE_ANON_KEY` to GitHub Secrets.

## Testing

After setting up the cron job:

1. Wait 5 minutes for it to run automatically, OR
2. Manually trigger the Edge Function:
   ```bash
   curl -X POST \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "apikey: YOUR_ANON_KEY" \
     https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/gmail-monitor
   ```
3. Check Edge Function logs in Supabase Dashboard
4. Check `application_emails` table for new entries

## Next Steps

Once the cron job is set up:
1. The Gmail monitor will run every 5 minutes
2. New application confirmation emails will be detected
3. Emails will be saved to the database
4. Push notifications will be sent to the iOS app


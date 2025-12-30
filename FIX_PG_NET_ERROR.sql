-- Step 1: Check if pg_net extension is available
SELECT * FROM pg_available_extensions WHERE name = 'pg_net';

-- Step 2: Check if it's enabled
SELECT * FROM pg_extension WHERE extname = 'pg_net';

-- Step 3: If available but not enabled, enable it
-- (Run this only if Step 1 shows pg_net is available)
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Step 4: After enabling, update the cron job
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


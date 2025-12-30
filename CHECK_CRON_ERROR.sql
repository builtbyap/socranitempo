-- Check the exact error message from your cron job
-- Run this in Supabase SQL Editor

SELECT 
  start_time,
  status,
  return_message,
  command
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 1;


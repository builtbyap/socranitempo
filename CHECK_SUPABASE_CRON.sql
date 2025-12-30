-- Check if Supabase cron job exists and its status
SELECT 
  jobid,
  jobname,
  schedule,
  active,
  command
FROM cron.job 
WHERE jobname = 'gmail-monitor-job';

-- Check recent execution history
SELECT 
  start_time,
  status,
  return_message,
  end_time - start_time AS duration
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 5;


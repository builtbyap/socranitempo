-- Step 1: Check if the cron job exists and is scheduled
SELECT 
  jobid,
  schedule,
  command,
  nodename,
  nodeport,
  database,
  username,
  active,
  jobname
FROM cron.job 
WHERE jobname = 'gmail-monitor-job';

-- Step 2: If job exists, check if it has run (may be empty if not run yet)
SELECT 
  start_time,
  status,
  return_message,
  end_time
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'gmail-monitor-job')
ORDER BY start_time DESC 
LIMIT 5;

-- Step 3: Check all cron jobs (to see what's scheduled)
SELECT 
  jobname,
  schedule,
  active,
  jobid
FROM cron.job
ORDER BY jobname;


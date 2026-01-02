# Deploy JobSpy Service

This guide explains how to deploy the JobSpy service that integrates with your Deno Edge Function.

## Overview

The JobSpy service is a Python FastAPI application that wraps the JobSpy library to scrape jobs from multiple job boards (LinkedIn, Indeed, Glassdoor, ZipRecruiter, Google).

## Deployment Options

### Option 1: Fly.io (Recommended)

1. **Install Fly.io CLI**:
   ```bash
   curl -L https://fly.io/install.sh | sh
   ```

2. **Login to Fly.io**:
   ```bash
   fly auth login
   ```

3. **Navigate to service directory**:
   ```bash
   cd jobspy-service
   ```

4. **Create Fly.io app**:
   ```bash
   fly launch --no-deploy
   ```

5. **Deploy**:
   ```bash
   fly deploy
   ```

6. **Get your service URL**:
   ```bash
   fly status
   ```
   Your service will be available at: `https://your-app-name.fly.dev`

7. **Set environment variable in Supabase**:
   - Go to Supabase Dashboard → Project Settings → Edge Functions → Secrets
   - Add: `JOBSPY_SERVICE_URL=https://your-app-name.fly.dev`

### Option 2: Railway

1. **Install Railway CLI**:
   ```bash
   npm i -g @railway/cli
   ```

2. **Login**:
   ```bash
   railway login
   ```

3. **Initialize project**:
   ```bash
   cd jobspy-service
   railway init
   ```

4. **Deploy**:
   ```bash
   railway up
   ```

5. **Get service URL** from Railway dashboard

6. **Set environment variable in Supabase** (same as above)

### Option 3: Render

1. **Create new Web Service** on Render
2. **Connect your GitHub repository**
3. **Set build command**: `pip install -r requirements.txt`
4. **Set start command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`
5. **Deploy**

### Option 4: Local Development

For testing locally:

1. **Install dependencies**:
   ```bash
   cd jobspy-service
   pip install -r requirements.txt
   ```

2. **Run the service**:
   ```bash
   python main.py
   ```

3. **Test the service**:
   ```bash
   curl "http://localhost:8000/health"
   ```

4. **Update Edge Function** to use `http://localhost:8000` (only for local testing)

## Environment Variables

The service doesn't require any environment variables, but you can set:

- `PORT` - Server port (default: 8000)
- `LOG_LEVEL` - Logging level (default: INFO)

## Testing the Service

Once deployed, test with:

```bash
curl "https://your-service-url/scrape?search_term=software%20engineer&location=San%20Francisco&results_wanted=10"
```

Or use the POST endpoint:

```bash
curl -X POST "https://your-service-url/scrape" \
  -H "Content-Type: application/json" \
  -d '{
    "search_term": "software engineer",
    "location": "San Francisco, CA",
    "results_wanted": 10,
    "site_name": ["indeed", "linkedin"]
  }'
```

## Integration with Edge Function

After deploying, update your Supabase Edge Function:

1. **Add secret**:
   ```bash
   supabase secrets set JOBSPY_SERVICE_URL=https://your-service-url
   ```

2. **The Edge Function will automatically use JobSpy** when it's in the sources list

## Monitoring

- Check service logs: `fly logs` (Fly.io) or Railway/Render dashboard
- Monitor health: `curl https://your-service-url/health`
- Check Edge Function logs in Supabase Dashboard

## Troubleshooting

### Service not responding
- Check if service is running: `fly status` or dashboard
- Check logs for errors
- Verify the service URL is correct in Supabase secrets

### Timeout errors
- JobSpy scraping can take time, especially for multiple sites
- Consider reducing `results_wanted` or limiting `site_name`
- Increase timeout in Edge Function if needed

### Rate limiting
- Job boards (especially LinkedIn) have rate limits
- Consider using proxies (JobSpy supports this)
- Add delays between requests if needed

## Cost Considerations

- **Fly.io**: Free tier available, then pay-as-you-go
- **Railway**: Free tier with limits, then $5/month minimum
- **Render**: Free tier available, then $7/month minimum

Choose based on your usage and budget.


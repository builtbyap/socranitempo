# How to Get Your JobSpy Service URL

## Quick Answer

**You get the URL after deploying the service.** The URL depends on which platform you use:

- **Fly.io**: `https://your-app-name.fly.dev`
- **Railway**: `https://your-app-name.up.railway.app`
- **Render**: `https://your-app-name.onrender.com`

## Step-by-Step: Fly.io (Recommended)

Since you're already using Fly.io for Playwright, this is the easiest option:

### 1. Navigate to the service directory
```bash
cd /Users/abongmabo/Desktop/surgeapp/jobspy-service
```

### 2. Create and deploy the Fly.io app
```bash
# First time only - creates the app
fly launch --no-deploy

# This will ask you:
# - App name? (e.g., "surgeapp-jobspy" or "jobspy-service")
# - Region? (choose closest to you)
# - Would you like to set up a Postgresql database? → No
# - Would you like to set up an Upstash Redis database? → No

# Then deploy
fly deploy
```

### 3. Get your service URL

After deployment, you'll see output like:
```
✓ Image available in a registry
✓ Image size: 450 MB
==> Creating release...
Release v1 created

Visit your newly deployed app at https://surgeapp-jobspy.fly.dev
```

**Your URL is**: `https://surgeapp-jobspy.fly.dev` (or whatever name you chose)

### 4. Verify it's working
```bash
# Check status
fly status

# Test the health endpoint
curl https://your-app-name.fly.dev/health
```

You should see: `{"status":"ok","service":"jobspy-service"}`

### 5. Get the URL anytime

If you forgot the URL, you can get it with:
```bash
fly status
# or
fly apps list
# or check the Fly.io dashboard: https://fly.io/dashboard
```

## Step-by-Step: Railway

### 1. Install Railway CLI
```bash
npm i -g @railway/cli
```

### 2. Login and deploy
```bash
cd /Users/abongmabo/Desktop/surgeapp/jobspy-service
railway login
railway init
railway up
```

### 3. Get your URL

After deployment, Railway will show you the URL, or:
- Check the Railway dashboard: https://railway.app/dashboard
- Run: `railway domain`

Your URL will be: `https://your-app-name.up.railway.app`

## Step-by-Step: Render

### 1. Go to Render Dashboard
- Visit: https://render.com/dashboard
- Click "New +" → "Web Service"

### 2. Connect your repository
- Connect your GitHub repo
- Select the `jobspy-service` directory

### 3. Configure
- **Name**: `surgeapp-jobspy` (or any name)
- **Build Command**: `pip install -r requirements.txt`
- **Start Command**: `uvicorn main:app --host 0.0.0.0 --port $PORT`

### 4. Deploy
- Click "Create Web Service"
- Wait for deployment

### 5. Get your URL
- After deployment, Render shows the URL
- Format: `https://surgeapp-jobspy.onrender.com`

## After Getting Your URL

### Set it in Supabase

1. **Via Dashboard**:
   - Go to Supabase Dashboard
   - Project Settings → Edge Functions → Secrets
   - Click "Add new secret"
   - Name: `JOBSPY_SERVICE_URL`
   - Value: `https://your-app-name.fly.dev` (your actual URL)
   - Click "Save"

2. **Via CLI** (if you have Supabase CLI):
   ```bash
   supabase secrets set JOBSPY_SERVICE_URL=https://your-app-name.fly.dev
   ```

### Test the Integration

Once the secret is set, test it:

```bash
# Test the service directly
curl "https://your-app-name.fly.dev/scrape?search_term=software%20engineer&location=San%20Francisco&results_wanted=5"

# Should return JSON with jobs
```

## Quick Reference

| Platform | How to Get URL | Example URL |
|----------|---------------|-------------|
| **Fly.io** | `fly status` or dashboard | `https://surgeapp-jobspy.fly.dev` |
| **Railway** | Dashboard or `railway domain` | `https://surgeapp-jobspy.up.railway.app` |
| **Render** | Dashboard after deployment | `https://surgeapp-jobspy.onrender.com` |

## Troubleshooting

### "Service not found" or 404
- Make sure the service is deployed and running
- Check: `fly status` (Fly.io) or dashboard (Railway/Render)

### "Connection refused"
- Service might be starting up (wait 30 seconds)
- Check service logs: `fly logs` (Fly.io)

### "Invalid URL"
- Make sure you include `https://` in the URL
- Don't include trailing slash: `https://app.fly.dev` ✅ not `https://app.fly.dev/` ❌

## Need Help?

- **Fly.io**: Check `fly status` or https://fly.io/dashboard
- **Railway**: Check https://railway.app/dashboard
- **Render**: Check https://render.com/dashboard

Your service URL is shown in the dashboard after deployment!


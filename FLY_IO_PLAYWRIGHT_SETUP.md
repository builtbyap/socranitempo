# Fly.io Playwright Setup Guide

## Overview

Since Playwright doesn't work directly in Supabase Edge Functions (Deno runtime), we deploy Playwright as a **separate Node.js service on Fly.io** and call it from the Edge Function.

## ✅ Why Fly.io?

- **Free Tier**: 3 shared-cpu-1x VMs with 256MB RAM (perfect for testing)
- **Node.js Support**: Full Node.js runtime, perfect for Playwright
- **Easy Deployment**: Simple Docker-based deployment
- **Auto-scaling**: Can scale to zero when not in use
- **Global**: Deploy close to your users

## 🚀 Setup Steps

### Step 1: Install Fly.io CLI

```bash
# macOS
brew install flyctl

# Or download from: https://fly.io/docs/getting-started/installing-flyctl/
```

### Step 2: Login to Fly.io

```bash
flyctl auth login
```

### Step 3: Navigate to Service Directory

```bash
cd fly-playwright-service
```

### Step 4: Create Fly.io App

```bash
flyctl launch
```

This will:
- Ask for an app name (or generate one)
- Detect your Dockerfile
- Ask about regions (choose one close to you)
- Create the app

### Step 5: Deploy the Service

```bash
flyctl deploy
```

This will:
- Build the Docker image
- Install Playwright and dependencies
- Deploy to Fly.io
- Give you a URL like: `https://your-app-name.fly.dev`

### Step 6: Get Your Service URL

After deployment, you'll see:
```
Deployed to: https://your-app-name.fly.dev
```

Or check with:
```bash
flyctl status
```

### Step 7: Test the Service

```bash
curl https://your-app-name.fly.dev/health
```

Should return:
```json
{"status":"ok","service":"playwright-automation"}
```

### Step 8: Add URL to Supabase

1. Go to **Supabase Dashboard** → **Project Settings** → **Edge Functions**
2. Scroll to **"Environment Variables"**
3. Add:
   - **`FLY_PLAYWRIGHT_SERVICE_URL`** = `https://your-app-name.fly.dev`

### Step 9: Deploy Edge Function

1. Go to **Supabase Dashboard** → **Edge Functions**
2. Create a new function: `auto-apply`
3. Copy contents of `edge-function-auto-apply-fly.ts`
4. Deploy

## 📝 Configuration

### Update fly.toml

Edit `fly.toml` and change:
```toml
app = "your-playwright-service"  # Change to your app name
```

### Memory Settings

The default is 2GB RAM. For free tier, you might want to reduce:

```toml
[[vm]]
  memory_mb = 1024  # 1GB (minimum for Playwright)
  cpu_kind = "shared"
  cpus = 1
```

### Auto-scaling

The service is configured to:
- **Auto-start** when receiving requests
- **Auto-stop** when idle (saves resources)
- **Scale to zero** when not in use

## 💰 Pricing

### Free Tier
- **3 shared-cpu-1x VMs** with 256MB RAM
- **3GB outbound data transfer** per month
- Perfect for testing and low-volume usage

### Paid Plans
- Start at **$1.94/month** per VM
- More RAM/CPU options available
- Pay only for what you use

## 🔧 Troubleshooting

### Issue: "Cannot find module 'playwright'"
**Solution**: Make sure Playwright is installed:
```bash
cd fly-playwright-service
npm install
flyctl deploy
```

### Issue: Service times out
**Solution**: 
- Increase timeout in Edge Function
- Check Fly.io logs: `flyctl logs`
- Increase VM memory if needed

### Issue: "Out of memory"
**Solution**: Increase memory in `fly.toml`:
```toml
[[vm]]
  memory_mb = 2048  # 2GB
```

### Issue: Service not responding
**Solution**:
- Check if service is running: `flyctl status`
- Check logs: `flyctl logs`
- Restart: `flyctl restart`

### Issue: Cold start is slow
**Solution**: 
- Keep at least 1 machine running: Set `min_machines_running = 1` in `fly.toml`
- Or accept the cold start (usually 5-10 seconds)

## 📊 Monitoring

### View Logs
```bash
flyctl logs
```

### Check Status
```bash
flyctl status
```

### View Metrics
```bash
flyctl metrics
```

Or visit: https://fly.io/dashboard

## 🔄 Updating the Service

1. Make changes to `server.js`
2. Deploy:
   ```bash
   flyctl deploy
   ```

## 🎯 Alternative: Railway or Render

If Fly.io doesn't work for you, you can also use:

### Railway
```bash
railway login
railway init
railway up
```

### Render
- Connect GitHub repo
- Set build command: `npm install`
- Set start command: `node server.js`

Both work similarly to Fly.io.

## 📚 Next Steps

1. **Deploy the Fly.io service** (follow steps above)
2. **Get the service URL**
3. **Add to Supabase environment variables**
4. **Deploy the edge function**
5. **Test with a real job application**
6. **Integrate with your iOS app**

## 🆘 Need Help?

- **Fly.io Docs**: https://fly.io/docs
- **Fly.io Discord**: https://fly.io/discord
- **Playwright Docs**: https://playwright.dev

## ⚠️ Important Notes

1. **Cold Starts**: First request after idle period may take 5-10 seconds
2. **Memory**: Playwright needs at least 1GB RAM
3. **Timeout**: Edge Functions have 60s timeout, Fly.io service should respond faster
4. **Costs**: Monitor usage on Fly.io dashboard
5. **Scaling**: Service auto-scales, but you can manually scale if needed

## 🔐 Security

Consider adding authentication to your Fly.io service:

```javascript
// In server.js
const API_KEY = process.env.API_KEY;

app.post('/automate', async (req, res) => {
  const apiKey = req.headers['x-api-key'];
  if (apiKey !== API_KEY) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  // ... rest of code
});
```

Then add `API_KEY` to Fly.io secrets:
```bash
flyctl secrets set API_KEY=your-secret-key
```

And update the edge function to send the key:
```typescript
headers: {
  'Content-Type': 'application/json',
  'x-api-key': Deno.env.get('PLAYWRIGHT_API_KEY') || ''
}
```


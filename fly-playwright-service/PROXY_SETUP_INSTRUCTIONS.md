# Residential Proxy Setup Instructions

## Quick Setup (5 minutes)

### Option 1: Smartproxy (Recommended - $75/month)

1. **Sign up**: Go to https://smartproxy.com
2. **Choose plan**: Select "Residential Proxies" → $75/month (10GB)
3. **Get credentials**: After signup, you'll see:
   - Endpoint: `gate.smartproxy.com:7000`
   - Username: (your account username)
   - Password: (your account password)

4. **Set environment variables in Fly.io**:
   ```bash
   cd fly-playwright-service
   fly secrets set PROXY_ENABLED=true
   fly secrets set PROXY_ENDPOINT=gate.smartproxy.com:7000
   fly secrets set PROXY_USERNAME=your_username_here
   fly secrets set PROXY_PASSWORD=your_password_here
   ```

5. **Deploy**:
   ```bash
   fly deploy
   ```

That's it! The service will now use residential proxies.

### Option 2: Bright Data ($500/month)

1. Sign up at https://brightdata.com
2. Create a residential proxy zone
3. Get your endpoint and credentials
4. Set the same environment variables as above

### Option 3: Oxylabs ($300/month)

1. Sign up at https://oxylabs.io
2. Get residential proxy credentials
3. Set environment variables

## Testing Without Proxy

To test without proxy (use your current setup):
```bash
fly secrets set PROXY_ENABLED=false
fly deploy
```

## How It Works

- When `PROXY_ENABLED=true`, all requests go through residential IPs
- Each request gets a different residential IP (rotating)
- Job boards see requests from real home IPs, not datacenter IPs
- This dramatically reduces bot detection

## Cost Per Application

- **Smartproxy**: $0.0075 per application (10GB = ~10,000 apps)
- **Bright Data**: $0.05 per application
- **Without proxy**: $0 but high failure rate

## Monitoring

Check your proxy dashboard to see:
- How much data you've used
- Success rates
- IP rotation

## Troubleshooting

If proxy doesn't work:
1. Check credentials are correct
2. Verify proxy endpoint is accessible
3. Check Fly.io logs: `fly logs`
4. Test proxy manually with curl


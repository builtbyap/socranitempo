# Residential Proxy Setup Guide

## What Are Residential Proxies?

Residential proxies use real home internet IP addresses instead of datacenter IPs. This makes your requests look like they come from actual users, not bots.

## Why You Need Them

- **Datacenter IPs** (Fly.io, AWS, etc.) → Job boards flag these immediately
- **Residential IPs** → Look like real users browsing from home

## Recommended Services

### 1. **Smartproxy** (Best Value) ⭐
- **Price**: $75/month for 10GB (enough for ~10,000 job applications)
- **Features**: Residential + datacenter, good API
- **URL**: https://smartproxy.com
- **Best for**: Starting out, cost-effective

### 2. **Bright Data** (Most Reliable)
- **Price**: $500/month for 20GB
- **Features**: Highest quality, best success rate
- **URL**: https://brightdata.com
- **Best for**: Production, high volume

### 3. **Oxylabs** (Good Balance)
- **Price**: $300/month for residential
- **Features**: Good quality, reliable
- **URL**: https://oxylabs.io
- **Best for**: Medium volume

### 4. **IPRoyal** (Budget Option)
- **Price**: $7/GB (pay as you go)
- **Features**: Cheaper, good for testing
- **URL**: https://iproyal.com
- **Best for**: Testing, low volume

## Quick Start: Smartproxy (Recommended)

### Step 1: Sign Up
1. Go to https://smartproxy.com
2. Sign up for "Residential Proxies"
3. Choose the $75/month plan (10GB)

### Step 2: Get Credentials
After signup, you'll get:
- **Endpoint**: `gate.smartproxy.com:7000`
- **Username**: Your account username
- **Password**: Your account password

### Step 3: Configure in Code
See implementation below.

## Implementation

The code will automatically use residential proxies when configured. See `fly-playwright-service/server.js` for the implementation.

## Environment Variables

Add to Fly.io secrets:
```bash
fly secrets set PROXY_ENABLED=true
fly secrets set PROXY_ENDPOINT=gate.smartproxy.com:7000
fly secrets set PROXY_USERNAME=your_username
fly secrets set PROXY_PASSWORD=your_password
```

## Cost Breakdown

- **Smartproxy**: $75/month = ~$0.0075 per job application (10GB = ~10,000 apps)
- **Bright Data**: $500/month = ~$0.05 per job application
- **Without proxies**: $0/month but high failure rate

## Testing

1. Start with Smartproxy's trial or smallest plan
2. Test with a few job applications
3. Monitor success rate improvement
4. Scale up if needed

## Alternative: Rotating Proxies

Some services offer "rotating" proxies that change IP on each request automatically. This is even better for avoiding detection.


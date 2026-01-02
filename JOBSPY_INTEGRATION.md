# JobSpy Integration Guide

## Overview

JobSpy has been integrated into your job scraping system to provide comprehensive job search across multiple job boards (LinkedIn, Indeed, Glassdoor, ZipRecruiter, Google).

## Architecture

```
iOS App (FeedView)
    ↓
Deno Edge Function (edge-function-code-with-adzuna.ts)
    ↓
JobSpy Service (Python FastAPI) ← NEW
    ↓
JobSpy Library (scrapes LinkedIn, Indeed, Glassdoor, ZipRecruiter, Google)
```

## What's Included

### 1. **JobSpy Service** (`jobspy-service/`)
   - Python FastAPI service that wraps JobSpy
   - Handles user filtering (location, job type, salary range, etc.)
   - Converts JobSpy results to your JobPost format
   - Supports multiple job boards concurrently

### 2. **Edge Function Integration**
   - Added `fetchFromJobSpy()` function
   - Integrated into the sources list alongside Adzuna, The Muse, and Workday
   - Passes all user filter parameters (location, salary range, career interests)

### 3. **Deployment Guide**
   - `DEPLOY_JOBSPY_SERVICE.md` with step-by-step instructions
   - Supports Fly.io, Railway, Render, or local development

## Features

### Supported Job Boards
- **LinkedIn** - Professional network job board
- **Indeed** - Largest job aggregator
- **Glassdoor** - Jobs with company reviews
- **ZipRecruiter** - Job board with AI matching
- **Google** - Google Jobs search results

### Filtering Support
- ✅ Search term / Keywords
- ✅ Location
- ✅ Job type (fulltime, parttime, internship, contract)
- ✅ Remote jobs
- ✅ Salary range (min/max)
- ✅ Hours old (recent jobs)
- ✅ Country selection

## Setup Instructions

### Step 1: Deploy JobSpy Service

Follow the instructions in `jobspy-service/DEPLOY_JOBSPY_SERVICE.md` to deploy the service.

**Quick start (Fly.io)**:
```bash
cd jobspy-service
fly launch --no-deploy
fly deploy
```

### Step 2: Set Environment Variable

In Supabase Dashboard:
1. Go to **Project Settings** → **Edge Functions** → **Secrets**
2. Add: `JOBSPY_SERVICE_URL=https://your-service-url.fly.dev`

Or via CLI:
```bash
supabase secrets set JOBSPY_SERVICE_URL=https://your-service-url.fly.dev
```

### Step 3: Deploy Updated Edge Function

The edge function already includes JobSpy integration. Just deploy it:

1. Go to Supabase Dashboard → **Edge Functions**
2. Select your function (or create new one)
3. Paste the code from `edge-function-code-with-adzuna.ts`
4. Deploy

## How It Works

### User Flow

1. **User sets filters** in iOS app (location, job type, salary range, career interests)
2. **App calls Edge Function** with filter parameters
3. **Edge Function** calls multiple sources concurrently:
   - Adzuna API
   - The Muse API
   - Workday scraping
   - **JobSpy service** ← NEW
4. **JobSpy service** scrapes from multiple job boards:
   - Indeed (most reliable, no rate limits)
   - LinkedIn (rate limited, needs proxies for high volume)
   - Glassdoor
   - ZipRecruiter
   - Google
5. **Results aggregated** and returned to app

### Filter Mapping

| User Filter | JobSpy Parameter |
|------------|------------------|
| Career Interests | `search_term` (joined with OR) |
| Location | `location` |
| Job Type | `job_type` (fulltime/parttime/internship/contract) |
| Salary Range | `min_salary`, `max_salary` (in thousands) |
| Remote | `is_remote` (boolean) |
| Hours Old | `hours_old` (integer) |

## Benefits

### 1. **Comprehensive Coverage**
   - Searches 5 major job boards simultaneously
   - More job results than single-source scraping

### 2. **Better Filtering**
   - JobSpy handles filtering at the source level
   - Reduces need for post-processing

### 3. **Reliability**
   - Multiple sources = redundancy
   - If one source fails, others still work

### 4. **Scalability**
   - JobSpy handles rate limiting and proxies
   - Can be scaled independently

## Limitations

### 1. **Rate Limiting**
   - LinkedIn has strict rate limits (~10 pages per IP)
   - Use proxies for high-volume LinkedIn scraping
   - Indeed is more lenient

### 2. **Service Dependency**
   - Requires separate Python service deployment
   - Adds another service to maintain

### 3. **Latency**
   - Scraping multiple sites takes time
   - Service has 60-second timeout
   - Consider reducing `results_wanted` if slow

### 4. **Cost**
   - Hosting the Python service costs money
   - Free tiers available but with limits

## Configuration

### Adjusting Sites

In `edge-function-code-with-adzuna.ts`, modify the `sites` array:

```typescript
const sites = ['indeed', 'linkedin', 'zip_recruiter', 'glassdoor']
```

Available options:
- `indeed` - Most reliable
- `linkedin` - Rate limited
- `zip_recruiter` - Good coverage
- `glassdoor` - Company reviews
- `google` - Broad search

### Adjusting Results

Change `results_wanted` in the JobSpy call:

```typescript
url.searchParams.set('results_wanted', '30') // Per site
```

Lower = faster, Higher = more results but slower

## Monitoring

### Check Service Health

```bash
curl https://your-service-url/health
```

### Check Service Logs

**Fly.io**:
```bash
fly logs
```

**Railway/Render**: Check dashboard

### Check Edge Function Logs

Supabase Dashboard → Edge Functions → Logs

## Troubleshooting

### Service Not Responding

1. Check service is running: `fly status` or dashboard
2. Check service logs for errors
3. Verify `JOBSPY_SERVICE_URL` is set correctly

### Timeout Errors

1. Reduce `results_wanted` per site
2. Limit number of sites scraped
3. Increase timeout in edge function (currently 60s)

### Rate Limiting

1. Add proxies to JobSpy service (see JobSpy docs)
2. Reduce request frequency
3. Focus on Indeed (less restrictive)

### No Results

1. Check search terms are valid
2. Verify location format
3. Check service logs for errors
4. Test service directly with curl

## Testing

### Test Service Locally

```bash
cd jobspy-service
pip install -r requirements.txt
python main.py
```

Then test:
```bash
curl "http://localhost:8000/scrape?search_term=software%20engineer&location=San%20Francisco&results_wanted=5"
```

### Test from Edge Function

1. Set `JOBSPY_SERVICE_URL=http://localhost:8000` (for local testing)
2. Call edge function with test parameters
3. Check logs for JobSpy results

## Next Steps

1. **Deploy the service** (see `DEPLOY_JOBSPY_SERVICE.md`)
2. **Set environment variable** in Supabase
3. **Test the integration** with a real search
4. **Monitor performance** and adjust as needed
5. **Add proxies** if you need higher volume LinkedIn scraping

## Support

- JobSpy docs: https://github.com/cullenwatson/JobSpy
- Service logs: Check deployment platform dashboard
- Edge Function logs: Supabase Dashboard


# Alternative Job Scraping Methods

This guide covers various ways to scrape job listings beyond the Adzuna API approach we've implemented.

## 1. Job Board APIs (Easiest & Most Reliable)

### Adzuna API ✅ (Already Implemented)
- **Status:** Currently using
- **Free Tier:** 50 requests/day
- **Coverage:** US, UK, Canada, Australia, and more
- **Pros:** Reliable, legal, structured data
- **Cons:** Limited free tier

### The Muse API
```typescript
const response = await fetch(
  `https://www.themuse.com/api/public/jobs?page=1&category=Software%20Engineering&location=San%20Francisco%2C%20CA`,
  {
    headers: {
      'Authorization': 'Bearer YOUR_API_KEY'
    }
  }
)
```
- **Sign up:** https://www.themuse.com/developers/api/v2
- **Pros:** Good for tech jobs, startup-focused
- **Cons:** Requires API key approval

### GitHub Jobs API (Deprecated but Still Works)
```typescript
const response = await fetch("https://jobs.github.com/positions.json?description=software+engineer&location=san+francisco")
const jobs = await response.json()
```
- **Status:** Deprecated but functional
- **Pros:** Free, no API key needed
- **Cons:** Limited to tech jobs, may stop working

### Juju API
- **URL:** https://www.juju.com/publisher
- **Pros:** Aggregates from multiple sources
- **Cons:** Requires partnership/approval

### Reed API (UK)
- **URL:** https://www.reed.co.uk/developers
- **Coverage:** UK jobs only
- **Pros:** Large UK job database
- **Cons:** UK only

## 2. RSS Feeds (Simple & Free)

Many job boards provide RSS feeds that you can parse:

### Indeed RSS
```typescript
const rssUrl = `https://www.indeed.com/rss?q=software+engineer&l=San+Francisco%2C+CA`
const response = await fetch(rssUrl)
const xml = await response.text()
// Parse XML to extract jobs
```

### LinkedIn Jobs RSS
```typescript
const rssUrl = `https://www.linkedin.com/jobs/search/rss?keywords=software+engineer&location=San+Francisco`
```

### Monster RSS
```typescript
const rssUrl = `https://rss.monster.com/rssquery.ashx?q=software+engineer&where=San+Francisco`
```

**Pros:**
- ✅ Free
- ✅ No API keys needed
- ✅ Simple XML parsing
- ✅ Legal and allowed

**Cons:**
- ❌ Limited data (title, description, URL)
- ❌ May not have all fields (salary, company details)
- ❌ Some sites don't offer RSS

## 3. Web Scraping with Different Tools

### A. Puppeteer (Headless Browser)
```typescript
import puppeteer from "https://deno.land/x/puppeteer@16.2.0/mod.ts"

const browser = await puppeteer.launch()
const page = await browser.newPage()
await page.goto("https://www.indeed.com/jobs?q=software+engineer")

const jobs = await page.evaluate(() => {
  return Array.from(document.querySelectorAll('.job_seen_beacon')).map(job => ({
    title: job.querySelector('.jobTitle a')?.textContent,
    company: job.querySelector('.companyName')?.textContent,
    location: job.querySelector('.companyLocation')?.textContent,
  }))
})

await browser.close()
```

**Pros:**
- ✅ Handles JavaScript-heavy sites
- ✅ Can interact with pages
- ✅ Works for dynamic content

**Cons:**
- ❌ Slow (runs full browser)
- ❌ High resource usage
- ❌ Can be detected by anti-bot systems

### B. Playwright (Alternative to Puppeteer)
```typescript
import { chromium } from "https://deno.land/x/playwright@1.40.0/mod.ts"

const browser = await chromium.launch()
const page = await browser.newPage()
await page.goto("https://www.indeed.com/jobs?q=software+engineer")
// Similar to Puppeteer
```

**Pros:**
- ✅ More reliable than Puppeteer
- ✅ Better for modern web apps
- ✅ Cross-browser support

**Cons:**
- ❌ Larger bundle size
- ❌ Still slower than Cheerio

### C. Cheerio (Fast HTML Parsing)
```typescript
import { load } from "https://deno.land/x/cheerio@1.0.0-rc.3/mod.ts"

const response = await fetch("https://www.indeed.com/jobs?q=software+engineer")
const html = await response.text()
const $ = load(html)

const jobs = $('.job_seen_beacon').map((i, el) => ({
  title: $(el).find('.jobTitle a').text(),
  company: $(el).find('.companyName').text(),
})).get()
```

**Pros:**
- ✅ Very fast
- ✅ Low resource usage
- ✅ jQuery-like syntax

**Cons:**
- ❌ Doesn't execute JavaScript
- ❌ Won't work for SPAs
- ❌ Limited to static HTML

## 4. Company Career Pages

### Pattern Recognition Approach
```typescript
const companies = ['google.com', 'apple.com', 'microsoft.com']
const commonPaths = ['/careers', '/jobs', '/careers/jobs', '/open-positions']

for (const company of companies) {
  for (const path of commonPaths) {
    try {
      const url = `https://${company}${path}`
      const jobs = await scrapeCompanyPage(url)
      // Extract jobs
    } catch (error) {
      // Skip if page doesn't exist
    }
  }
}
```

### Common ATS Systems

#### Greenhouse
```typescript
// Pattern: company.greenhouse.io or boards.greenhouse.io/company
const url = "https://boards.greenhouse.io/COMPANY_NAME"
// Many Greenhouse sites have JSON endpoints
const apiUrl = "https://boards-api.greenhouse.io/v1/boards/COMPANY_NAME/jobs"
```

#### Lever
```typescript
// Pattern: jobs.lever.co/company
const url = "https://jobs.lever.co/COMPANY_NAME"
// Lever often has API endpoints
const apiUrl = "https://api.lever.co/v0/postings/COMPANY_NAME"
```

#### Workday
```typescript
// Pattern: company.wd3.myworkdayjobs.com
// Usually requires more complex scraping
```

#### SmartRecruiters
```typescript
// Pattern: jobs.smartrecruiters.com/company
const url = "https://jobs.smartrecruiters.com/COMPANY_NAME"
```

## 5. Job Aggregator Services

### ScraperAPI
```typescript
const response = await fetch(
  `https://api.scraperapi.com/?api_key=YOUR_KEY&url=https://www.indeed.com/jobs?q=software+engineer`
)
```
- **URL:** https://www.scraperapi.com
- **Pros:** Handles anti-bot measures, proxy rotation
- **Cons:** Paid service (has free tier)

### Bright Data (formerly Luminati)
- **URL:** https://brightdata.com
- **Pros:** Enterprise-grade scraping infrastructure
- **Cons:** Expensive, overkill for most use cases

### Apify
```typescript
// Get your API token from https://apify.com
const response = await fetch(
  `https://api.apify.com/v2/acts/YOUR_ACTOR_ID/runs?token=YOUR_TOKEN`
)
```
- **URL:** https://apify.com
- **Pros:** Pre-built scrapers, handles complexity
- **Cons:** Requires actor setup

**Apify Actors for Jobs:**
- `apify/indeed-scraper`
- `apify/linkedin-jobs-scraper`
- `apify/glassdoor-scraper`

## 6. Social Media & Professional Networks

### LinkedIn Jobs (Scraping)
```typescript
// Requires authentication and careful handling
// LinkedIn has strict anti-scraping measures
```
- **Pros:** Large job database
- **Cons:** Very difficult to scrape, may violate ToS

### Twitter/X Job Postings
```typescript
// Search for job-related hashtags
const response = await fetch(
  `https://api.twitter.com/2/tweets/search/recent?query=#hiring%20software%20engineer`,
  {
    headers: {
      'Authorization': 'Bearer YOUR_TWITTER_BEARER_TOKEN'
    }
  }
)
```
- **Pros:** Real-time job postings
- **Cons:** Requires Twitter API access, noisy data

## 7. Government Job Boards

### USAJobs API (Federal Jobs)
```typescript
const response = await fetch(
  `https://data.usajobs.gov/api/Search?Keyword=software+engineer&LocationName=San+Francisco`,
  {
    headers: {
      'Host': 'data.usajobs.gov',
      'User-Agent': 'YOUR_EMAIL',
      'Authorization-Key': 'YOUR_API_KEY'
    }
  }
)
```
- **URL:** https://developer.usajobs.gov
- **Pros:** Official API, free
- **Cons:** Only federal jobs

### State/Local Job Boards
- Many state and local governments have job boards
- Usually have RSS feeds or simple HTML to scrape

## 8. Niche Job Boards

### Stack Overflow Jobs
```typescript
// Stack Overflow has an API
const response = await fetch("https://api.stackexchange.com/2.3/jobs?order=desc&sort=creation&tagged=javascript")
```

### Remote.co
- Remote job listings
- Can be scraped with Cheerio

### We Work Remotely
- Remote job board
- Simple HTML structure

### AngelList (Startup Jobs)
```typescript
// AngelList has an API
const response = await fetch("https://api.angel.co/1/jobs")
```

## 9. Hybrid Approach (Recommended)

Combine multiple methods for best results:

```typescript
async function fetchJobsFromAllSources(keywords, location) {
  const allJobs = []
  
  // 1. APIs (most reliable)
  allJobs.push(...await fetchFromAdzuna(keywords, location))
  allJobs.push(...await fetchFromTheMuse(keywords, location))
  
  // 2. RSS Feeds (simple)
  allJobs.push(...await fetchFromIndeedRSS(keywords, location))
  allJobs.push(...await fetchFromMonsterRSS(keywords, location))
  
  // 3. Scraping (for sites without APIs)
  allJobs.push(...await scrapeLinkedIn(keywords, location))
  allJobs.push(...await scrapeGlassdoor(keywords, location))
  
  // 4. Company pages (targeted)
  allJobs.push(...await scrapeCompanyCareerPages(keywords))
  
  // Deduplicate and return
  return deduplicateJobs(allJobs)
}
```

## 10. Best Practices

### Rate Limiting
```typescript
// Add delays between requests
await new Promise(resolve => setTimeout(resolve, 1000)) // 1 second delay
```

### Caching
```typescript
// Cache results in Supabase to reduce API calls
const cachedJobs = await getCachedJobs(keywords, location)
if (cachedJobs && isCacheValid(cachedJobs)) {
  return cachedJobs
}
```

### Error Handling
```typescript
try {
  const jobs = await fetchFromSource()
} catch (error) {
  console.error('Source failed:', error)
  // Fallback to another source
}
```

### User-Agent Rotation
```typescript
const userAgents = [
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
  // ... more user agents
]
const randomUA = userAgents[Math.floor(Math.random() * userAgents.length)]
```

## 11. Recommended Stack for Your App

Based on what you have:

1. **Primary:** Adzuna API ✅ (already implemented)
2. **Secondary:** RSS Feeds (Indeed, Monster, LinkedIn)
3. **Tertiary:** Apify Actors (you have a token!)
4. **Fallback:** Company career pages (targeted scraping)

## 12. Quick Implementation: RSS Feeds

Here's a quick RSS feed parser you can add:

```typescript
async function fetchFromIndeedRSS(keywords: string, location: string) {
  const rssUrl = `https://www.indeed.com/rss?q=${encodeURIComponent(keywords)}&l=${encodeURIComponent(location)}`
  const response = await fetch(rssUrl)
  const xml = await response.text()
  
  // Parse XML (you can use a library like 'xml2js' or simple regex)
  const jobs = parseRSSXML(xml)
  
  return jobs.map((item: any) => ({
    id: `indeed_rss_${item.guid || Date.now()}`,
    title: item.title,
    company: extractCompanyFromTitle(item.title), // Parse from title
    location: location,
    posted_date: new Date(item.pubDate).toISOString().split('T')[0],
    description: item.description,
    url: item.link,
    salary: null,
    job_type: null,
  }))
}
```

## Summary

**Easiest to Implement:**
1. ✅ Adzuna API (already done)
2. RSS Feeds
3. Apify Actors (you have token)

**Most Reliable:**
1. APIs (Adzuna, The Muse)
2. RSS Feeds
3. Government APIs

**Most Comprehensive:**
1. Hybrid approach (combine multiple sources)
2. Web scraping with Puppeteer
3. Company career pages

**Best for Your Use Case:**
- Keep Adzuna API as primary
- Add RSS feeds for more sources
- Use Apify for complex sites
- Add company pages for targeted searches


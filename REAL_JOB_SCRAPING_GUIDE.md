# Real Job Scraping Implementation Guide

This guide explains what tools and technologies you'd use to scrape real jobs from various sources.

## Overview

For real job scraping, you'll need different approaches depending on the source:

1. **Public Job Boards** (Indeed, Monster, Glassdoor, etc.) - Web scraping
2. **Company Career Pages** - Web scraping with pattern recognition
3. **ATS-Hosted Pages** (Greenhouse, Lever, Workday) - API access or scraping
4. **Job Aggregator APIs** - Direct API access (if available)

---

## 1. Web Scraping Libraries

### For Node.js/Deno (Supabase Edge Functions)

#### **Puppeteer** (Recommended for JavaScript-heavy sites)
```typescript
import puppeteer from "https://deno.land/x/puppeteer@16.2.0/mod.ts"

const browser = await puppeteer.launch()
const page = await browser.newPage()
await page.goto("https://www.indeed.com/jobs?q=software+engineer")
const jobs = await page.evaluate(() => {
  // Extract job data from DOM
  return Array.from(document.querySelectorAll('.job_seen_beacon')).map(job => ({
    title: job.querySelector('.jobTitle a')?.textContent,
    company: job.querySelector('.companyName')?.textContent,
    location: job.querySelector('.companyLocation')?.textContent,
    // ... more fields
  }))
})
await browser.close()
```

**Pros:**
- Handles JavaScript-heavy sites
- Can interact with pages (click buttons, fill forms)
- Good for dynamic content

**Cons:**
- Slower (runs full browser)
- Higher resource usage
- Can be detected by anti-bot systems

#### **Cheerio** (Fast HTML parsing)
```typescript
import { load } from "https://deno.land/x/cheerio@1.0.0-rc.3/mod.ts"

const response = await fetch("https://www.indeed.com/jobs?q=software+engineer")
const html = await response.text()
const $ = load(html)

const jobs = $('.job_seen_beacon').map((i, el) => ({
  title: $(el).find('.jobTitle a').text(),
  company: $(el).find('.companyName').text(),
  location: $(el).find('.companyLocation').text(),
})).get()
```

**Pros:**
- Very fast
- Low resource usage
- jQuery-like syntax

**Cons:**
- Doesn't execute JavaScript
- Won't work for SPAs (Single Page Applications)
- Limited to static HTML

#### **Playwright** (Alternative to Puppeteer)
```typescript
import { chromium } from "https://deno.land/x/playwright@1.40.0/mod.ts"

const browser = await chromium.launch()
const page = await browser.newPage()
await page.goto("https://www.indeed.com/jobs?q=software+engineer")
// Similar to Puppeteer
```

**Pros:**
- Better for modern web apps
- More reliable than Puppeteer
- Cross-browser support

**Cons:**
- Larger bundle size
- Still slower than Cheerio

### For Python (Alternative Backend)

#### **BeautifulSoup + Requests**
```python
import requests
from bs4 import BeautifulSoup

response = requests.get("https://www.indeed.com/jobs?q=software+engineer")
soup = BeautifulSoup(response.content, 'html.parser')

jobs = []
for job in soup.find_all('div', class_='job_seen_beacon'):
    jobs.append({
        'title': job.find('a', class_='jobTitle').text,
        'company': job.find('span', class_='companyName').text,
        'location': job.find('div', class_='companyLocation').text,
    })
```

#### **Selenium** (For JavaScript-heavy sites)
```python
from selenium import webdriver
from selenium.webdriver.common.by import By

driver = webdriver.Chrome()
driver.get("https://www.indeed.com/jobs?q=software+engineer")
jobs = driver.find_elements(By.CLASS_NAME, "job_seen_beacon")
# Extract data...
```

---

## 2. Job Board APIs (If Available)

### **Adzuna API** (Free tier available)
```typescript
const response = await fetch(
  `https://api.adzuna.com/v1/api/jobs/us/search/1?app_id=YOUR_APP_ID&app_key=YOUR_APP_KEY&results_per_page=50&what=software%20engineer&where=san%20francisco`
)
const data = await response.json()
const jobs = data.results.map(job => ({
  id: job.id,
  title: job.title,
  company: job.company.display_name,
  location: job.location.display_name,
  posted_date: job.created,
  description: job.description,
  url: job.redirect_url,
  salary: job.salary_min ? `$${job.salary_min} - $${job.salary_max}` : null,
}))
```

**Sign up:** https://developer.adzuna.com

### **The Muse API**
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

**Sign up:** https://www.themuse.com/developers/api/v2

### **GitHub Jobs API** (Deprecated but still works)
```typescript
const response = await fetch("https://jobs.github.com/positions.json?description=software+engineer&location=san+francisco")
const jobs = await response.json()
```

**Note:** This API is deprecated but still functional.

---

## 3. Company Career Pages

### Pattern Recognition Approach

Most companies follow common patterns:
- `/careers`
- `/jobs`
- `/careers/jobs`
- `/open-positions`

```typescript
const companies = ['google.com', 'apple.com', 'microsoft.com']
const jobs = []

for (const company of companies) {
  const paths = ['/careers', '/jobs', '/careers/jobs']
  
  for (const path of paths) {
    try {
      const url = `https://${company}${path}`
      const response = await fetch(url)
      const html = await response.text()
      
      // Use Cheerio or regex to find job listings
      // Look for common patterns:
      // - Job title links
      // - "Apply" buttons
      // - Job listing containers
      
      const foundJobs = extractJobsFromHTML(html, company)
      jobs.push(...foundJobs)
    } catch (error) {
      // Skip if page doesn't exist
    }
  }
}
```

### Common ATS Systems

#### **Greenhouse** (greenhouse.io)
```typescript
// Greenhouse jobs are usually at: company.greenhouse.io
const response = await fetch("https://boards.greenhouse.io/COMPANY_NAME")
// Parse HTML or use their API if available
```

#### **Lever** (lever.co)
```typescript
// Lever jobs: jobs.lever.co/COMPANY_NAME
const response = await fetch("https://jobs.lever.co/COMPANY_NAME")
// Parse job listings
```

#### **Workday** (workday.com)
```typescript
// Workday: company.wd3.myworkdayjobs.com
// Usually requires more complex scraping due to dynamic loading
```

---

## 4. Complete Implementation Example

Here's how you'd update your Supabase Edge Function with real scraping:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { load } from "https://deno.land/x/cheerio@1.0.0-rc.3/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const url = new URL(req.url)
    const keywords = url.searchParams.get('keywords') || ''
    const location = url.searchParams.get('location') || ''
    
    const allJobs = []
    
    // 1. Scrape Indeed
    try {
      const indeedJobs = await scrapeIndeed(keywords, location)
      allJobs.push(...indeedJobs)
    } catch (error) {
      console.error('Indeed scraping failed:', error)
    }
    
    // 2. Use Adzuna API
    try {
      const adzunaJobs = await fetchFromAdzuna(keywords, location)
      allJobs.push(...adzunaJobs)
    } catch (error) {
      console.error('Adzuna API failed:', error)
    }
    
    // 3. Scrape company career pages
    try {
      const companyJobs = await scrapeCompanyPages(keywords)
      allJobs.push(...companyJobs)
    } catch (error) {
      console.error('Company pages scraping failed:', error)
    }
    
    // Deduplicate and return
    const uniqueJobs = deduplicateJobs(allJobs)
    
    return new Response(
      JSON.stringify(uniqueJobs),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

async function scrapeIndeed(keywords: string, location: string) {
  const url = `https://www.indeed.com/jobs?q=${encodeURIComponent(keywords)}&l=${encodeURIComponent(location)}`
  const response = await fetch(url, {
    headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
  })
  const html = await response.text()
  const $ = load(html)
  
  const jobs = []
  $('.job_seen_beacon').each((i, el) => {
    jobs.push({
      id: `indeed_${i}_${Date.now()}`,
      title: $(el).find('.jobTitle a').text().trim(),
      company: $(el).find('.companyName').text().trim(),
      location: $(el).find('.companyLocation').text().trim(),
      posted_date: new Date().toISOString().split('T')[0],
      description: $(el).find('.job-snippet').text().trim(),
      url: `https://www.indeed.com${$(el).find('.jobTitle a').attr('href')}`,
      salary: $(el).find('.salary-snippet').text().trim() || null,
      job_type: null,
    })
  })
  
  return jobs
}

async function fetchFromAdzuna(keywords: string, location: string) {
  const APP_ID = Deno.env.get('ADZUNA_APP_ID')
  const APP_KEY = Deno.env.get('ADZUNA_APP_KEY')
  
  if (!APP_ID || !APP_KEY) {
    return []
  }
  
  const url = `https://api.adzuna.com/v1/api/jobs/us/search/1?app_id=${APP_ID}&app_key=${APP_KEY}&results_per_page=50&what=${encodeURIComponent(keywords)}&where=${encodeURIComponent(location)}`
  const response = await fetch(url)
  const data = await response.json()
  
  return data.results.map((job: any) => ({
    id: `adzuna_${job.id}`,
    title: job.title,
    company: job.company.display_name,
    location: job.location.display_name,
    posted_date: new Date(job.created).toISOString().split('T')[0],
    description: job.description,
    url: job.redirect_url,
    salary: job.salary_min ? `$${job.salary_min} - $${job.salary_max}` : null,
    job_type: job.contract_type || null,
  }))
}

function deduplicateJobs(jobs: any[]) {
  const seen = new Set()
  return jobs.filter(job => {
    const key = `${job.title}_${job.company}_${job.location}`.toLowerCase()
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}
```

---

## 5. Important Considerations

### Rate Limiting
- Don't scrape too aggressively
- Add delays between requests
- Respect robots.txt
- Use rate limiting libraries

### Legal & Ethical
- Check Terms of Service
- Some sites prohibit scraping
- Consider using official APIs when available
- Be respectful of server resources

### Anti-Bot Measures
- Use realistic User-Agent headers
- Rotate IP addresses (if needed)
- Handle CAPTCHAs (may need services like 2Captcha)
- Some sites require authentication

### Error Handling
- Sites change their HTML structure frequently
- Have fallback sources
- Cache results to reduce requests
- Monitor for breaking changes

### Performance
- Scraping can be slow
- Consider caching results
- Use parallel requests where possible
- Set reasonable timeouts

---

## 6. Recommended Stack

For a production system:

1. **Backend:** Node.js/Deno (Supabase Edge Functions)
2. **Scraping:** Puppeteer for JS sites, Cheerio for static HTML
3. **APIs:** Adzuna, The Muse (when available)
4. **Database:** Supabase (store scraped jobs)
5. **Scheduling:** Cron jobs or Supabase Edge Functions with scheduled triggers
6. **Monitoring:** Log errors and track success rates

---

## 7. Next Steps

1. **Start with APIs** (Adzuna, The Muse) - easiest and most reliable
2. **Add simple scraping** (Cheerio for static sites)
3. **Add advanced scraping** (Puppeteer for dynamic sites)
4. **Implement caching** (store results in Supabase)
5. **Add scheduling** (scrape periodically)
6. **Monitor and maintain** (sites change frequently)

---

## Resources

- **Puppeteer Docs:** https://pptr.dev
- **Cheerio Docs:** https://cheerio.js.org
- **Adzuna API:** https://developer.adzuna.com
- **The Muse API:** https://www.themuse.com/developers/api/v2
- **Web Scraping Best Practices:** https://www.scrapehero.com/web-scraping-best-practices/


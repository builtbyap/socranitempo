import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { load } from "https://esm.sh/cheerio@1.0.0-rc.12?target=deno"

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
    const careerInterestsParam = url.searchParams.get('career_interests')
    
    let careerInterests: string[] = []
    if (careerInterestsParam) {
      try {
        careerInterests = JSON.parse(decodeURIComponent(careerInterestsParam))
      } catch {
        try {
          careerInterests = JSON.parse(careerInterestsParam)
        } catch {
          careerInterests = []
        }
      }
    }

    const allJobs = []

    // Build search queries from career interests
    const searchQueries: string[] = []
    if (careerInterests.length > 0) {
      // Search each career interest separately
      for (const interest of careerInterests) {
        searchQueries.push(interest)
        // Also add internship variant
        searchQueries.push(`${interest} internship`)
      }
    } else {
      searchQueries.push(keywords || 'software engineer')
    }
    
    // Limit queries to avoid timeout
    const queriesToSearch = searchQueries.slice(0, 3)
    
    console.log(`🌐 Starting web scraping from job boards and ATS systems...`)
    
    // Scrape from multiple sources in parallel
    const scrapingPromises: Promise<any[]>[] = []
    
    for (const query of queriesToSearch) {
      // Job Boards
      scrapingPromises.push(
        scrapeIndeed(query, location).catch(err => {
          console.error(`❌ Indeed scraping failed for "${query}":`, err)
          return []
        }),
        scrapeMonster(query, location).catch(err => {
          console.error(`❌ Monster scraping failed for "${query}":`, err)
          return []
        }),
        scrapeGlassdoor(query, location).catch(err => {
          console.error(`❌ Glassdoor scraping failed for "${query}":`, err)
          return []
        }),
        scrapeZipRecruiter(query, location).catch(err => {
          console.error(`❌ ZipRecruiter scraping failed for "${query}":`, err)
          return []
        })
      )
      
      // ATS Systems
      scrapingPromises.push(
        scrapeGreenhouse(query, location).catch(err => {
          console.error(`❌ Greenhouse scraping failed for "${query}":`, err)
          return []
        }),
        scrapeLever(query, location).catch(err => {
          console.error(`❌ Lever scraping failed for "${query}":`, err)
          return []
        }),
        scrapeWorkday(query, location).catch(err => {
          console.error(`❌ Workday scraping failed for "${query}":`, err)
          return []
        })
      )
      
      // Small delay between queries to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 300))
    }
    
    // Wait for all scraping to complete (with timeout)
    try {
      const scrapingResults = await Promise.race([
        Promise.all(scrapingPromises),
        new Promise((_, reject) => 
          setTimeout(() => reject(new Error('Scraping timeout')), 30000) // 30 second timeout
        )
      ]) as any[][]
      
      for (const jobs of scrapingResults) {
        if (jobs && jobs.length > 0) {
          allJobs.push(...jobs)
          console.log(`✅ Added ${jobs.length} jobs from scraping`)
        }
      }
    } catch (timeoutErr) {
      console.log(`⏱️ Web scraping timed out (continuing with jobs found so far)`)
      // Continue with jobs we already have
    }

    // Only return sample data if all scraping failed
    if (allJobs.length === 0) {
      console.log('⚠️ No jobs found from scraping, returning sample data as fallback')
      allJobs.push(...getSampleJobs(location))
    }

    // Deduplicate jobs
    const uniqueJobs = deduplicateJobs(allJobs)

    // Filter by career interests if provided
    let filteredJobs = uniqueJobs
    if (careerInterests.length > 0) {
      filteredJobs = uniqueJobs.filter(job => {
        const jobText = `${job.title} ${job.company} ${job.description || ''}`.toLowerCase()
        return careerInterests.some(interest => {
          const interestLower = interest.toLowerCase()
          return jobText.includes(interestLower) || 
                 job.title.toLowerCase().includes(interestLower)
        })
      })
      
      // If filtering resulted in 0 jobs, return all jobs
      if (filteredJobs.length === 0) {
        filteredJobs = uniqueJobs
      }
    }

    return new Response(
      JSON.stringify(filteredJobs),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('❌ Error in edge function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Scrape Greenhouse (ATS)
async function scrapeGreenhouse(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    // Greenhouse has a public API endpoint for many companies
    // We'll try to scrape from known Greenhouse job boards
    // Pattern: boards.greenhouse.io/COMPANY_NAME or COMPANY_NAME.greenhouse.io
    
    // List of popular companies using Greenhouse (you can expand this)
    const greenhouseCompanies = [
      'stripe', 'airbnb', 'reddit', 'pinterest', 'shopify', 
      'uber', 'lyft', 'doordash', 'instacart', 'coinbase'
    ]
    
    for (const company of greenhouseCompanies.slice(0, 5)) { // Limit to 5 to avoid timeout
      try {
        // Try Greenhouse API endpoint first
        const apiUrl = `https://boards-api.greenhouse.io/v1/boards/${company}/jobs`
        const response = await fetch(apiUrl, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          }
        })
        
        if (response.ok) {
          const data = await response.json()
          if (data.jobs && Array.isArray(data.jobs)) {
            for (const job of data.jobs) {
              // Filter by keywords if provided
              if (keywords) {
                const jobText = `${job.title} ${job.content || ''}`.toLowerCase()
                if (!jobText.includes(keywords.toLowerCase())) {
                  continue
                }
              }
              
              jobs.push({
                id: `greenhouse_${company}_${job.id || Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                title: job.title || 'Job Title',
                company: job.departments?.[0]?.name || company,
                location: job.location?.name || location || 'Location not specified',
                posted_date: job.updated_at ? new Date(job.updated_at).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
                description: job.content || null,
                url: job.absolute_url || `https://boards.greenhouse.io/${company}/jobs/${job.id}`,
                salary: null,
                job_type: null,
              })
            }
          }
        }
      } catch (err) {
        // Skip this company if it fails
        continue
      }
      
      // Small delay between companies
      await new Promise(resolve => setTimeout(resolve, 200))
    }
    
    console.log(`✅ Scraped ${jobs.length} jobs from Greenhouse`)
  } catch (error) {
    console.error('❌ Greenhouse scraping error:', error)
  }
  
  return jobs
}

// Scrape Lever (ATS)
async function scrapeLever(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    // Lever has a public API endpoint
    // Pattern: jobs.lever.co/COMPANY_NAME or api.lever.co/v0/postings/COMPANY_NAME
    
    const leverCompanies = [
      'lever', 'netflix', 'dropbox', 'slack', 'square',
      'twitch', 'github', 'asana', 'notion', 'figma'
    ]
    
    for (const company of leverCompanies.slice(0, 5)) {
      try {
        const apiUrl = `https://api.lever.co/v0/postings/${company}`
        const response = await fetch(apiUrl, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
          }
        })
        
        if (response.ok) {
          const data = await response.json()
          if (data && Array.isArray(data)) {
            for (const job of data) {
              // Filter by keywords if provided
              if (keywords) {
                const jobText = `${job.text} ${job.descriptionPlain || ''}`.toLowerCase()
                if (!jobText.includes(keywords.toLowerCase())) {
                  continue
                }
              }
              
              jobs.push({
                id: `lever_${company}_${job.id || Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                title: job.text || 'Job Title',
                company: company,
                location: job.categories?.location || location || 'Location not specified',
                posted_date: job.createdAt ? new Date(job.createdAt).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
                description: job.descriptionPlain || null,
                url: job.hostedUrl || job.applyUrl || `https://jobs.lever.co/${company}/${job.id}`,
                salary: null,
                job_type: job.categories?.commitment || null,
              })
            }
          }
        }
      } catch (err) {
        continue
      }
      
      await new Promise(resolve => setTimeout(resolve, 200))
    }
    
    console.log(`✅ Scraped ${jobs.length} jobs from Lever`)
  } catch (error) {
    console.error('❌ Lever scraping error:', error)
  }
  
  return jobs
}

// Scrape Workday (ATS)
async function scrapeWorkday(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    // Workday is more complex - companies use different subdomains
    // Pattern: COMPANY.wd3.myworkdayjobs.com or COMPANY.myworkdayjobs.com
    
    const workdayCompanies = [
      'apple', 'microsoft', 'amazon', 'google', 'meta',
      'nvidia', 'oracle', 'salesforce', 'adobe', 'intel'
    ]
    
    for (const company of workdayCompanies.slice(0, 3)) { // Limit to 3 (Workday is slower)
      try {
        // Try common Workday URL patterns
        const workdayUrls = [
          `https://${company}.wd3.myworkdayjobs.com/${company}_Careers`,
          `https://${company}.myworkdayjobs.com/${company}_Careers`
        ]
        
        for (const workdayUrl of workdayUrls) {
          try {
            const response = await fetch(workdayUrl, {
              headers: {
                'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
              }
            })
            
            if (response.ok) {
              const html = await response.text()
              const $ = load(html)
              
              // Workday uses specific data attributes and structures
              $('[data-automation-id="jobTitle"], .job-title, [data-testid="job-title"]').each((i: number, element: any) => {
                try {
                  const $el = $(element)
                  const title = $el.text().trim()
                  
                  // Filter by keywords
                  if (keywords && !title.toLowerCase().includes(keywords.toLowerCase())) {
                    return
                  }
                  
                  const jobUrl = $el.attr('href') || $el.find('a').attr('href')
                  const fullUrl = jobUrl && !jobUrl.startsWith('http') 
                    ? `${workdayUrl}${jobUrl}` 
                    : jobUrl
                  
                  // Try to find location and other details
                  const locationText = $el.closest('[data-automation-id="jobPosting"]').find('[data-automation-id="jobLocation"]').text().trim() || location
                  
                  jobs.push({
                    id: `workday_${company}_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                    title: title || 'Job Title',
                    company: company,
                    location: locationText || 'Location not specified',
                    posted_date: new Date().toISOString().split('T')[0],
                    description: null,
                    url: fullUrl || null,
                    salary: null,
                    job_type: null,
                  })
                } catch (err) {
                  // Skip individual job parsing errors
                }
              })
              
              // If we found jobs, break (don't try other URL pattern)
              if (jobs.length > 0) {
                break
              }
            }
          } catch (err) {
            continue
          }
        }
      } catch (err) {
        continue
      }
      
      await new Promise(resolve => setTimeout(resolve, 500)) // Longer delay for Workday
    }
    
    console.log(`✅ Scraped ${jobs.length} jobs from Workday`)
  } catch (error) {
    console.error('❌ Workday scraping error:', error)
  }
  
  return jobs
}

// Web Scraping Functions for Job Boards
// Using Cheerio for fast HTML parsing

// Scrape Indeed
async function scrapeIndeed(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    const searchUrl = `https://www.indeed.com/jobs?q=${encodeURIComponent(keywords)}&l=${encodeURIComponent(location || '')}`
    
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      }
    })

    if (!response.ok) {
      console.error(`❌ Indeed request failed: ${response.status}`)
      return jobs
    }

    const html = await response.text()
    const $ = load(html)

    // Indeed job listings are in cards with class 'job_seen_beacon' or 'slider_container'
    $('.job_seen_beacon, .slider_container').each((i: number, element: any) => {
      try {
        const $el = $(element)
        
        // Extract job title
        const titleLink = $el.find('h2.jobTitle a, .jobTitle a, a[data-jk]').first()
        const title = titleLink.text().trim() || $el.find('h2.jobTitle').text().trim()
        
        // Extract company
        const company = $el.find('.companyName, [data-testid="company-name"]').text().trim()
        
        // Extract location
        const jobLocation = $el.find('.companyLocation, [data-testid="text-location"]').text().trim()
        
        // Extract salary
        const salary = $el.find('.salary-snippet-container, .attribute_snippet').text().trim() || null
        
        // Extract job URL
        let jobUrl = titleLink.attr('href')
        if (jobUrl && !jobUrl.startsWith('http')) {
          jobUrl = `https://www.indeed.com${jobUrl}`
        }
        
        // Extract description/snippet
        const description = $el.find('.job-snippet, .summary').text().trim()

        if (title && company) {
          jobs.push({
            id: `indeed_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            title: title,
            company: company,
            location: jobLocation || location || 'Location not specified',
            posted_date: new Date().toISOString().split('T')[0],
            description: description || null,
            url: jobUrl || null,
            salary: salary,
            job_type: null,
          })
        }
      } catch (err) {
        // Skip individual job parsing errors
      }
    })

    console.log(`✅ Scraped ${jobs.length} jobs from Indeed`)
  } catch (error) {
    console.error('❌ Indeed scraping error:', error)
  }

  return jobs
}

// Scrape Monster
async function scrapeMonster(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    const searchUrl = `https://www.monster.com/jobs/search/?q=${encodeURIComponent(keywords)}&where=${encodeURIComponent(location || '')}`
    
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    })

    if (!response.ok) {
      console.error(`❌ Monster request failed: ${response.status}`)
      return jobs
    }

    const html = await response.text()
    const $ = load(html)

    // Monster job listings structure
    $('[data-testid="organic-job"], .card-content, .summary').each((i: number, element: any) => {
      try {
        const $el = $(element)
        
        const title = $el.find('h2 a, h3 a, .title a').text().trim()
        const company = $el.find('.company, [data-testid="company-name"]').text().trim()
        const jobLocation = $el.find('.location, [data-testid="job-location"]').text().trim()
        const description = $el.find('.summary, .description').text().trim()
        
        let jobUrl = $el.find('h2 a, h3 a, .title a').attr('href')
        if (jobUrl && !jobUrl.startsWith('http')) {
          jobUrl = `https://www.monster.com${jobUrl}`
        }

        if (title && company) {
          jobs.push({
            id: `monster_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            title: title,
            company: company,
            location: jobLocation || location || 'Location not specified',
            posted_date: new Date().toISOString().split('T')[0],
            description: description || null,
            url: jobUrl || null,
            salary: null,
            job_type: null,
          })
        }
      } catch (err) {
        // Skip individual job parsing errors
      }
    })

    console.log(`✅ Scraped ${jobs.length} jobs from Monster`)
  } catch (error) {
    console.error('❌ Monster scraping error:', error)
  }

  return jobs
}

// Scrape Glassdoor
async function scrapeGlassdoor(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    const searchUrl = `https://www.glassdoor.com/Job/jobs.htm?sc.keyword=${encodeURIComponent(keywords)}&locT=C&locId=${encodeURIComponent(location || '')}`
    
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    })

    if (!response.ok) {
      console.error(`❌ Glassdoor request failed: ${response.status}`)
      return jobs
    }

    const html = await response.text()
    const $ = load(html)

    // Glassdoor job listings
    $('[data-test="job-listing"], .jobContainer, .react-job-listing').each((i: number, element: any) => {
      try {
        const $el = $(element)
        
        const title = $el.find('[data-test="job-title"], .jobTitle a').text().trim()
        const company = $el.find('[data-test="employer-name"], .employerName').text().trim()
        const jobLocation = $el.find('[data-test="job-location"], .location').text().trim()
        const description = $el.find('.jobDescriptionContent, .jobDescription').text().trim()
        
        let jobUrl = $el.find('[data-test="job-title"] a, .jobTitle a').attr('href')
        if (jobUrl && !jobUrl.startsWith('http')) {
          jobUrl = `https://www.glassdoor.com${jobUrl}`
        }

        if (title && company) {
          jobs.push({
            id: `glassdoor_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            title: title,
            company: company,
            location: jobLocation || location || 'Location not specified',
            posted_date: new Date().toISOString().split('T')[0],
            description: description || null,
            url: jobUrl || null,
            salary: null,
            job_type: null,
          })
        }
      } catch (err) {
        // Skip individual job parsing errors
      }
    })

    console.log(`✅ Scraped ${jobs.length} jobs from Glassdoor`)
  } catch (error) {
    console.error('❌ Glassdoor scraping error:', error)
  }

  return jobs
}

// Scrape ZipRecruiter
async function scrapeZipRecruiter(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    const searchUrl = `https://www.ziprecruiter.com/jobs-search?search=${encodeURIComponent(keywords)}&location=${encodeURIComponent(location || '')}`
    
    const response = await fetch(searchUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    })

    if (!response.ok) {
      console.error(`❌ ZipRecruiter request failed: ${response.status}`)
      return jobs
    }

    const html = await response.text()
    const $ = load(html)

    // ZipRecruiter job listings
    $('.job_content, .job_result, [data-testid="job-card"]').each((i: number, element: any) => {
      try {
        const $el = $(element)
        
        const title = $el.find('h2 a, .job_title a, [data-testid="job-title"]').text().trim()
        const company = $el.find('.company_name, [data-testid="company-name"]').text().trim()
        const jobLocation = $el.find('.job_location, [data-testid="job-location"]').text().trim()
        const description = $el.find('.job_snippet, .job_description').text().trim()
        
        let jobUrl = $el.find('h2 a, .job_title a').attr('href')
        if (jobUrl && !jobUrl.startsWith('http')) {
          jobUrl = `https://www.ziprecruiter.com${jobUrl}`
        }

        if (title && company) {
          jobs.push({
            id: `ziprecruiter_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            title: title,
            company: company,
            location: jobLocation || location || 'Location not specified',
            posted_date: new Date().toISOString().split('T')[0],
            description: description || null,
            url: jobUrl || null,
            salary: null,
            job_type: null,
          })
        }
      } catch (err) {
        // Skip individual job parsing errors
      }
    })

    console.log(`✅ Scraped ${jobs.length} jobs from ZipRecruiter`)
  } catch (error) {
    console.error('❌ ZipRecruiter scraping error:', error)
  }

  return jobs
}

// Format salary from Adzuna API
function formatSalary(min: number | null, max: number | null): string | null {
  if (!min && !max) return null
  
  if (min && max) {
    return `$${min.toLocaleString()} - $${max.toLocaleString()}`
  } else if (min) {
    return `$${min.toLocaleString()}+`
  } else if (max) {
    return `Up to $${max.toLocaleString()}`
  }
  
  return null
}

// Sample jobs as fallback
function getSampleJobs(location: string): any[] {
  return [
    {
      id: "sample_1",
      title: "Software Engineer",
      company: "Tech Corp",
      location: location || "San Francisco, CA",
      posted_date: new Date().toISOString().split('T')[0],
      description: "We are looking for a software engineer with experience in Swift, iOS development, and modern app architecture.",
      url: "https://example.com/job/1",
      salary: "$120,000 - $150,000",
      job_type: "Full-time"
    },
    {
      id: "sample_2",
      title: "Data Analyst",
      company: "Analytics Inc",
      location: location || "Remote",
      posted_date: new Date().toISOString().split('T')[0],
      description: "Join our data team to analyze user behavior and drive product decisions.",
      url: "https://example.com/job/2",
      salary: null,
      job_type: "Full-time"
    }
  ]
}

// Deduplicate jobs based on title, company, and location
function deduplicateJobs(jobs: any[]): any[] {
  const seen = new Set<string>()
  const unique: any[] = []

  for (const job of jobs) {
    const key = `${job.title}_${job.company}_${job.location}`.toLowerCase().replace(/\s+/g, '_')
    if (!seen.has(key)) {
      seen.add(key)
      unique.push(job)
    }
  }

  return unique
}


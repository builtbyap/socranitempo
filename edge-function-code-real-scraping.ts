import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { load } from "https://deno.land/x/cheerio@1.0.0-rc.3/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get query parameters
    const url = new URL(req.url)
    const keywords = url.searchParams.get('keywords') || ''
    const location = url.searchParams.get('location') || ''
    const careerInterestsParam = url.searchParams.get('career_interests')
    
    // Parse career interests if provided
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

    // Build search query from career interests or keywords
    const searchQuery = careerInterests.length > 0 
      ? careerInterests.join(' OR ')
      : keywords || 'software engineer'

    const allJobs = []

    // Scrape from multiple sources in parallel
    const scrapingPromises = [
      scrapeIndeed(searchQuery, location).catch(err => {
        console.error('Indeed scraping failed:', err)
        return []
      }),
      scrapeMonster(searchQuery, location).catch(err => {
        console.error('Monster scraping failed:', err)
        return []
      }),
      scrapeGlassdoor(searchQuery, location).catch(err => {
        console.error('Glassdoor scraping failed:', err)
        return []
      }),
    ]

    const results = await Promise.all(scrapingPromises)
    for (const jobs of results) {
      allJobs.push(...jobs)
    }

    // Deduplicate jobs
    const uniqueJobs = deduplicateJobs(allJobs)

    // Filter by career interests if provided (client-side filtering)
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
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        },
      }
    )
  } catch (error) {
    console.error('Error in edge function:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        status: 500,
        headers: { 
          ...corsHeaders,
          'Content-Type': 'application/json' 
        },
      }
    )
  }
})

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
      console.error(`Indeed request failed: ${response.status}`)
      return jobs
    }

    const html = await response.text()
    const $ = load(html)

    // Indeed job listings are in cards with class 'job_seen_beacon' or 'slider_container'
    $('.job_seen_beacon, .slider_container').each((i, element) => {
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
        console.error('Error parsing Indeed job:', err)
      }
    })

    console.log(`Scraped ${jobs.length} jobs from Indeed`)
  } catch (error) {
    console.error('Indeed scraping error:', error)
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
      console.error(`Monster request failed: ${response.status}`)
      return jobs
    }

    const html = await response.text()
    const $ = load(html)

    // Monster job listings structure
    $('[data-testid="organic-job"], .card-content, .summary').each((i, element) => {
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
        console.error('Error parsing Monster job:', err)
      }
    })

    console.log(`Scraped ${jobs.length} jobs from Monster`)
  } catch (error) {
    console.error('Monster scraping error:', error)
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
      console.error(`Glassdoor request failed: ${response.status}`)
      return jobs
    }

    const html = await response.text()
    const $ = load(html)

    // Glassdoor job listings
    $('[data-test="job-listing"], .jobContainer, .react-job-listing').each((i, element) => {
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
        console.error('Error parsing Glassdoor job:', err)
      }
    })

    console.log(`Scraped ${jobs.length} jobs from Glassdoor`)
  } catch (error) {
    console.error('Glassdoor scraping error:', error)
  }

  return jobs
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


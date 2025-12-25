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

    // Fetch from Adzuna API (primary source)
    // If career interests exist, search for each one separately (Adzuna doesn't support OR)
    if (careerInterests.length > 0) {
      console.log(`🔍 Searching Adzuna for ${careerInterests.length} career interests`)
      // Search for each career interest separately
      for (const interest of careerInterests) {
        try {
          // Search for regular positions
          const adzunaJobs = await fetchFromAdzunaAPI(interest, location)
          console.log(`✅ Fetched ${adzunaJobs.length} jobs from Adzuna for "${interest}"`)
          if (adzunaJobs.length > 0) {
            allJobs.push(...adzunaJobs)
          }
          
          // Also search for internships
          const internshipQuery = `${interest} internship`
          const internshipJobs = await fetchFromAdzunaAPI(internshipQuery, location)
          console.log(`✅ Fetched ${internshipJobs.length} internships from Adzuna for "${interest}"`)
          if (internshipJobs.length > 0) {
            allJobs.push(...internshipJobs)
          }
          
          // Small delay to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, 200))
        } catch (err) {
          console.error(`❌ Adzuna API failed for "${interest}":`, err)
        }
      }
    } else {
      // Use keywords or default search
      const searchQuery = keywords || 'software engineer'
      try {
        // Search for regular positions
        const adzunaJobs = await fetchFromAdzunaAPI(searchQuery, location)
        console.log(`✅ Fetched ${adzunaJobs.length} jobs from Adzuna API for "${searchQuery}"`)
        if (adzunaJobs.length > 0) {
          allJobs.push(...adzunaJobs)
        }
        
        // Also search for internships
        const internshipQuery = `${searchQuery} internship`
        const internshipJobs = await fetchFromAdzunaAPI(internshipQuery, location)
        console.log(`✅ Fetched ${internshipJobs.length} internships from Adzuna API`)
        if (internshipJobs.length > 0) {
          allJobs.push(...internshipJobs)
        }
      } catch (err) {
        console.error('❌ Adzuna API failed:', err)
        console.error('❌ Error details:', JSON.stringify(err))
      }
    }

    // Fetch from The Muse API (secondary source)
    if (careerInterests.length > 0) {
      console.log(`🔍 Searching The Muse for ${careerInterests.length} career interests`)
      for (const interest of careerInterests) {
        try {
          // Search for regular positions
          const museJobs = await fetchFromTheMuseAPI(interest, location)
          console.log(`✅ Fetched ${museJobs.length} jobs from The Muse for "${interest}"`)
          if (museJobs.length > 0) {
            allJobs.push(...museJobs)
          }
          
          // Also search for internships
          const internshipQuery = `${interest} internship`
          const internshipJobs = await fetchFromTheMuseAPI(internshipQuery, location)
          console.log(`✅ Fetched ${internshipJobs.length} internships from The Muse for "${interest}"`)
          if (internshipJobs.length > 0) {
            allJobs.push(...internshipJobs)
          }
          
          // Small delay to avoid rate limiting
          await new Promise(resolve => setTimeout(resolve, 200))
        } catch (err) {
          console.error(`❌ The Muse API failed for "${interest}":`, err)
        }
      }
    } else {
      const searchQuery = keywords || 'software engineer'
      try {
        // Search for regular positions
        const museJobs = await fetchFromTheMuseAPI(searchQuery, location)
        console.log(`✅ Fetched ${museJobs.length} jobs from The Muse API for "${searchQuery}"`)
        if (museJobs.length > 0) {
          allJobs.push(...museJobs)
        }
        
        // Also search for internships
        const internshipQuery = `${searchQuery} internship`
        const internshipJobs = await fetchFromTheMuseAPI(internshipQuery, location)
        console.log(`✅ Fetched ${internshipJobs.length} internships from The Muse API`)
        if (internshipJobs.length > 0) {
          allJobs.push(...internshipJobs)
        }
      } catch (err) {
        console.error('❌ The Muse API failed:', err)
      }
    }

    // Fetch from Web Scraping (Indeed, Monster, Glassdoor, ZipRecruiter)
    // This is faster and more reliable than Apify
    if (allJobs.length < 100) { // Only scrape if we need more jobs
      console.log(`🌐 Starting web scraping from job boards...`)
      
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
      
      // Limit to first 2 queries to avoid timeout
      const queriesToSearch = searchQueries.slice(0, 2)
      
      // Scrape from multiple job boards in parallel
      const scrapingPromises: Promise<any[]>[] = []
      
      for (const query of queriesToSearch) {
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
        
        // Small delay between queries to avoid rate limiting
        await new Promise(resolve => setTimeout(resolve, 500))
      }
      
      // Wait for all scraping to complete (with timeout)
      try {
        const scrapingResults = await Promise.race([
          Promise.all(scrapingPromises),
          new Promise((_, reject) => 
            setTimeout(() => reject(new Error('Scraping timeout')), 20000) // 20 second timeout
          )
        ]) as any[][]
        
        for (const jobs of scrapingResults) {
          if (jobs && jobs.length > 0) {
            allJobs.push(...jobs)
            console.log(`✅ Added ${jobs.length} jobs from web scraping`)
          }
        }
      } catch (timeoutErr) {
        console.log(`⏱️ Web scraping timed out (this is normal - continuing with existing jobs)`)
        // Continue with jobs we already have
      }
    } else {
      console.log('ℹ️ Skipping web scraping (already have enough jobs)')
    }

    // Only return sample data if Adzuna completely failed AND we have no jobs
    if (allJobs.length === 0) {
      console.log('⚠️ No jobs from Adzuna, returning sample data as fallback')
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

// Fetch jobs from Adzuna API
async function fetchFromAdzunaAPI(keywords: string, location: string): Promise<any[]> {
  // Get API keys from environment variables (recommended) or use defaults
  const APP_ID = Deno.env.get('ADZUNA_APP_ID') || 'ff850947'
  const APP_KEY = Deno.env.get('ADZUNA_APP_KEY') || '114516221e332fe7ddb772224a68e0bb'
  
  try {
    // Adzuna API endpoint for US jobs
    const country = 'us' // Change to 'uk', 'ca', 'au', etc. for other countries
    
    // Build URL - use location if provided, otherwise don't include where parameter
    let url = `https://api.adzuna.com/v1/api/jobs/${country}/search/1?app_id=${APP_ID}&app_key=${APP_KEY}&results_per_page=50&what=${encodeURIComponent(keywords)}&sort_by=date`
    
    // Only add location if it's a specific city/state, not "United States"
    if (location && location.toLowerCase() !== 'united states' && location.toLowerCase() !== 'us') {
      url += `&where=${encodeURIComponent(location)}`
    }
    
    console.log(`🔍 Fetching from Adzuna: "${keywords}"${location ? ` in ${location}` : ''}`)
    console.log(`🔗 URL: ${url.replace(APP_KEY, '***')}`) // Hide API key in logs
    
    const response = await fetch(url)
    
    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Adzuna API error: ${response.status} - ${errorText}`)
    }

    const data = await response.json()
    
    console.log(`📊 Adzuna API response: count=${data.count}, results=${data.results?.length || 0}`)
    
    if (!data.results || data.results.length === 0) {
      console.log('⚠️ No results from Adzuna API')
      return []
    }
    
    // Transform Adzuna jobs to our JobPost format
    const transformedJobs = data.results.map((job: any) => ({
      id: `adzuna_${job.id}`,
      title: job.title || 'Job Title',
      company: job.company?.display_name || job.company?.name || 'Company not specified',
      location: job.location?.display_name || job.location?.area?.join(', ') || location || 'Location not specified',
      posted_date: job.created ? new Date(job.created).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
      description: job.description || null,
      url: job.redirect_url || job.url || null,
      salary: formatSalary(job.salary_min, job.salary_max),
      job_type: job.contract_type || job.contract_time || null,
    }))
    
    console.log(`✅ Transformed ${transformedJobs.length} jobs from Adzuna`)
    return transformedJobs
  } catch (error) {
    console.error('❌ Adzuna API error:', error)
    console.error('❌ Error message:', error.message)
    console.error('❌ Error stack:', error.stack)
    throw error
  }
}

// Fetch jobs from The Muse API
async function fetchFromTheMuseAPI(keywords: string, location: string): Promise<any[]> {
  // Get API key from environment variables or use default
  const API_KEY = Deno.env.get('THE_MUSE_API_KEY') || 'e176261d566e51adae621988bd6fcc8538f804c0525037c9684085e08f0131e8'
  
  try {
    // The Muse API endpoint
    let url = `https://www.themuse.com/api/public/jobs?page=1&api_key=${API_KEY}`
    
    // Add category/keywords
    if (keywords) {
      // The Muse uses categories, so try to map keywords to categories
      const category = mapKeywordsToCategory(keywords)
      if (category) {
        url += `&category=${encodeURIComponent(category)}`
      }
    }
    
    // Add location if provided
    if (location && location.toLowerCase() !== 'united states' && location.toLowerCase() !== 'us') {
      url += `&location=${encodeURIComponent(location)}`
    }
    
    console.log(`🔍 Fetching from The Muse: "${keywords}"${location ? ` in ${location}` : ''}`)
    
    const response = await fetch(url)
    
    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`The Muse API error: ${response.status} - ${errorText}`)
    }

    const data = await response.json()
    
    if (!data.results || data.results.length === 0) {
      console.log('⚠️ No results from The Muse API')
      return []
    }
    
    // Transform The Muse jobs to our JobPost format
    const transformedJobs = data.results
      .filter((job: any) => {
        // Filter by keywords if provided (The Muse doesn't have great keyword search)
        if (keywords) {
          const jobText = `${job.name} ${job.company?.name || ''} ${job.contents || ''}`.toLowerCase()
          return jobText.includes(keywords.toLowerCase())
        }
        return true
      })
      .map((job: any) => ({
        id: `themuse_${job.id}`,
        title: job.name || 'Job Title',
        company: job.company?.name || 'Company not specified',
        location: job.locations?.[0]?.name || location || 'Location not specified',
        posted_date: job.publication_date ? new Date(job.publication_date).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
        description: job.contents || null,
        url: job.refs?.landing_page || job.url || null,
        salary: null, // The Muse doesn't always provide salary in API
        job_type: job.type || null,
      }))
    
    console.log(`✅ Transformed ${transformedJobs.length} jobs from The Muse`)
    return transformedJobs
  } catch (error) {
    console.error('❌ The Muse API error:', error)
    return [] // Return empty array instead of throwing
  }
}

// Map keywords to The Muse categories
function mapKeywordsToCategory(keywords: string): string | null {
  const keywordLower = keywords.toLowerCase()
  
  // The Muse categories
  if (keywordLower.includes('software') || keywordLower.includes('engineer') || keywordLower.includes('developer')) {
    return 'Software Engineering'
  }
  if (keywordLower.includes('data') || keywordLower.includes('analyst')) {
    return 'Data Science'
  }
  if (keywordLower.includes('product') || keywordLower.includes('manager')) {
    return 'Product'
  }
  if (keywordLower.includes('marketing')) {
    return 'Marketing'
  }
  if (keywordLower.includes('finance') || keywordLower.includes('accounting')) {
    return 'Finance'
  }
  if (keywordLower.includes('design') || keywordLower.includes('designer')) {
    return 'Design'
  }
  
  return null // No specific category match
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


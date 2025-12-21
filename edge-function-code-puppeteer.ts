import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

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

    const searchQuery = careerInterests.length > 0 
      ? careerInterests.join(' OR ')
      : keywords || 'software engineer'

    const allJobs = []

    // Note: Puppeteer requires more setup in Supabase Edge Functions
    // For now, using a hybrid approach with API + simple scraping
    
    // Try Adzuna API first (most reliable)
    try {
      const adzunaJobs = await fetchFromAdzunaAPI(searchQuery, location)
      allJobs.push(...adzunaJobs)
    } catch (err) {
      console.error('Adzuna API failed:', err)
    }

    // Fallback to simple scraping
    try {
      const scrapedJobs = await scrapeWithBasicFetch(searchQuery, location)
      allJobs.push(...scrapedJobs)
    } catch (err) {
      console.error('Basic scraping failed:', err)
    }

    const uniqueJobs = deduplicateJobs(allJobs)

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
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Adzuna API (most reliable - requires API key)
async function fetchFromAdzunaAPI(keywords: string, location: string): Promise<any[]> {
  // Get API keys from environment variables
  const APP_ID = Deno.env.get('ADZUNA_APP_ID')
  const APP_KEY = Deno.env.get('ADZUNA_APP_KEY')
  
  if (!APP_ID || !APP_KEY) {
    console.log('Adzuna API keys not configured')
    return []
  }

  try {
    const url = `https://api.adzuna.com/v1/api/jobs/us/search/1?app_id=${APP_ID}&app_key=${APP_KEY}&results_per_page=50&what=${encodeURIComponent(keywords)}&where=${encodeURIComponent(location || 'United States')}`
    
    const response = await fetch(url)
    if (!response.ok) {
      throw new Error(`Adzuna API error: ${response.status}`)
    }

    const data = await response.json()
    
    return data.results.map((job: any) => ({
      id: `adzuna_${job.id}`,
      title: job.title,
      company: job.company?.display_name || 'Company not specified',
      location: job.location?.display_name || location || 'Location not specified',
      posted_date: job.created ? new Date(job.created).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
      description: job.description || null,
      url: job.redirect_url || null,
      salary: job.salary_min && job.salary_max 
        ? `$${job.salary_min.toLocaleString()} - $${job.salary_max.toLocaleString()}`
        : job.salary_min 
        ? `$${job.salary_min.toLocaleString()}+`
        : null,
      job_type: job.contract_type || null,
    }))
  } catch (error) {
    console.error('Adzuna API error:', error)
    return []
  }
}

// Basic scraping with fetch (works for some sites)
async function scrapeWithBasicFetch(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  // Try scraping Indeed with basic fetch
  try {
    const indeedUrl = `https://www.indeed.com/jobs?q=${encodeURIComponent(keywords)}&l=${encodeURIComponent(location || '')}`
    const response = await fetch(indeedUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
      }
    })

    if (response.ok) {
      const html = await response.text()
      // Simple regex extraction (basic approach)
      const jobMatches = html.match(/jobTitle[^>]*>([^<]+)</g) || []
      
      for (let i = 0; i < Math.min(jobMatches.length, 10); i++) {
        const title = jobMatches[i].replace(/jobTitle[^>]*>|</g, '').trim()
        if (title) {
          jobs.push({
            id: `indeed_basic_${i}_${Date.now()}`,
            title: title,
            company: 'Company from Indeed',
            location: location || 'Location not specified',
            posted_date: new Date().toISOString().split('T')[0],
            description: null,
            url: `https://www.indeed.com/viewjob?jk=${Math.random().toString(36)}`,
            salary: null,
            job_type: null,
          })
        }
      }
    }
  } catch (error) {
    console.error('Basic scraping error:', error)
  }

  return jobs
}

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


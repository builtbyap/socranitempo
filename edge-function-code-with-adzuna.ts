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

    const allJobs = []

    // Fetch from Adzuna API (primary source)
    // If career interests exist, search for each one separately (Adzuna doesn't support OR)
    if (careerInterests.length > 0) {
      console.log(`🔍 Searching Adzuna for ${careerInterests.length} career interests`)
      // Search for each career interest separately
      for (const interest of careerInterests) {
        try {
          const adzunaJobs = await fetchFromAdzunaAPI(interest, location)
          console.log(`✅ Fetched ${adzunaJobs.length} jobs from Adzuna for "${interest}"`)
          if (adzunaJobs.length > 0) {
            allJobs.push(...adzunaJobs)
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
        const adzunaJobs = await fetchFromAdzunaAPI(searchQuery, location)
        console.log(`✅ Fetched ${adzunaJobs.length} jobs from Adzuna API for "${searchQuery}"`)
        if (adzunaJobs.length > 0) {
          allJobs.push(...adzunaJobs)
        } else {
          console.log('⚠️ Adzuna API returned 0 jobs')
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
          const museJobs = await fetchFromTheMuseAPI(interest, location)
          console.log(`✅ Fetched ${museJobs.length} jobs from The Muse for "${interest}"`)
          if (museJobs.length > 0) {
            allJobs.push(...museJobs)
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
        const museJobs = await fetchFromTheMuseAPI(searchQuery, location)
        console.log(`✅ Fetched ${museJobs.length} jobs from The Muse API for "${searchQuery}"`)
        if (museJobs.length > 0) {
          allJobs.push(...museJobs)
        }
      } catch (err) {
        console.error('❌ The Muse API failed:', err)
      }
    }

    // Fetch from Apify LinkedIn Scraper (third source)
    if (careerInterests.length > 0) {
      console.log(`🔍 Searching LinkedIn via Apify for ${careerInterests.length} career interests`)
      for (const interest of careerInterests) {
        try {
          const linkedInJobs = await fetchFromApifyLinkedIn(interest, location)
          console.log(`✅ Fetched ${linkedInJobs.length} jobs from LinkedIn for "${interest}"`)
          if (linkedInJobs.length > 0) {
            allJobs.push(...linkedInJobs)
          }
          // Longer delay for Apify (more resource intensive)
          await new Promise(resolve => setTimeout(resolve, 1000))
        } catch (err) {
          console.error(`❌ Apify LinkedIn scraper failed for "${interest}":`, err)
        }
      }
    } else {
      const searchQuery = keywords || 'software engineer'
      try {
        const linkedInJobs = await fetchFromApifyLinkedIn(searchQuery, location)
        console.log(`✅ Fetched ${linkedInJobs.length} jobs from LinkedIn for "${searchQuery}"`)
        if (linkedInJobs.length > 0) {
          allJobs.push(...linkedInJobs)
        }
      } catch (err) {
        console.error('❌ Apify LinkedIn scraper failed:', err)
      }
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

// Fetch jobs from Apify LinkedIn Scraper
async function fetchFromApifyLinkedIn(keywords: string, location: string): Promise<any[]> {
  // Get API token from environment variables
  const APIFY_TOKEN = Deno.env.get('APIFY_TOKEN')
  
  if (!APIFY_TOKEN) {
    console.error('❌ APIFY_TOKEN not set in environment variables')
    return []
  }
  const ACTOR_ID = 'worldunboxer~rapid-linkedin-scraper'
  
  try {
    console.log(`🔍 Starting Apify LinkedIn scraper for: "${keywords}"${location ? ` in ${location}` : ''}`)
    
    // Step 1: Start the actor run
    const runUrl = `https://api.apify.com/v2/acts/${ACTOR_ID}/runs?token=${APIFY_TOKEN}`
    const runResponse = await fetch(runUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        job_title: keywords,
        job_type: 'F', // F for full-time, P for part-time
        jobs_entries: 25, // Number of jobs to fetch
        location: location || '',
        start_jobs: 0
      })
    })

    if (!runResponse.ok) {
      const errorText = await runResponse.text()
      throw new Error(`Apify run failed: ${runResponse.status} - ${errorText}`)
    }

    const runData = await runResponse.json()
    const runId = runData.data.id
    
    console.log(`⏳ Apify run started: ${runId}, waiting for completion...`)

    // Step 2: Wait for the run to complete (with timeout)
    const maxWaitTime = 60000 // 60 seconds
    const startTime = Date.now()
    let runStatus = 'RUNNING'
    
    while (runStatus === 'RUNNING' && (Date.now() - startTime) < maxWaitTime) {
      await new Promise(resolve => setTimeout(resolve, 2000)) // Check every 2 seconds
      
      const statusUrl = `https://api.apify.com/v2/actor-runs/${runId}?token=${APIFY_TOKEN}`
      const statusResponse = await fetch(statusUrl)
      
      if (statusResponse.ok) {
        const statusData = await statusResponse.json()
        runStatus = statusData.data.status
        
        if (runStatus === 'SUCCEEDED') {
          break
        } else if (runStatus === 'FAILED' || runStatus === 'ABORTED') {
          throw new Error(`Apify run ${runStatus.toLowerCase()}`)
        }
      }
    }

    if (runStatus !== 'SUCCEEDED') {
      throw new Error('Apify run timed out or failed')
    }

    console.log(`✅ Apify run completed, fetching dataset...`)

    // Step 3: Get the dataset
    const datasetUrl = `https://api.apify.com/v2/datasets/${runData.data.defaultDatasetId}/items?token=${APIFY_TOKEN}`
    const datasetResponse = await fetch(datasetUrl)

    if (!datasetResponse.ok) {
      throw new Error(`Failed to fetch dataset: ${datasetResponse.status}`)
    }

    const datasetData = await datasetResponse.json()
    
    if (!datasetData || datasetData.length === 0) {
      console.log('⚠️ No results from Apify LinkedIn scraper')
      return []
    }

    console.log(`📊 Apify returned ${datasetData.length} jobs`)

    // Step 4: Transform Apify LinkedIn jobs to our JobPost format
    const transformedJobs = datasetData.map((job: any) => ({
      id: `linkedin_apify_${job.job_id || job.id || Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      title: job.job_title || job.title || 'Job Title',
      company: job.company_name || job.company || 'Company not specified',
      location: job.location || location || 'Location not specified',
      posted_date: job.posted_date ? new Date(job.posted_date).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
      description: job.job_description || job.description || null,
      url: job.apply_url || job.job_url || job.url || null,
      salary: job.salary_range || job.salary || null,
      job_type: job.employment_type || job.job_type || null,
    }))

    console.log(`✅ Transformed ${transformedJobs.length} jobs from Apify LinkedIn`)
    return transformedJobs
  } catch (error) {
    console.error('❌ Apify LinkedIn scraper error:', error)
    return [] // Return empty array instead of throwing
  }
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


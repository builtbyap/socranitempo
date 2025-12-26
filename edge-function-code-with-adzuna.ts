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
    let location = url.searchParams.get('location') || ''
    const careerInterestsParam = url.searchParams.get('career_interests')
    
    // Normalize location - if empty or "none", use empty string (will search all locations)
    if (location.toLowerCase() === 'none' || location.trim() === '') {
      location = ''
    }
    
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
    
    console.log('📥 Edge Function called with:')
    console.log(`   - Keywords: "${keywords}"`)
    console.log(`   - Location: "${location || 'all locations'}"`)
    console.log(`   - Career Interests: ${JSON.stringify(careerInterests)}`)

    const allJobs: any[] = []
    const sourceStats: { [key: string]: number } = {}

    // Build search queries from career interests
    const searchQueries: string[] = []
    if (careerInterests.length > 0) {
      // Limit to 2 career interests to avoid timeout (searching many companies)
      for (const interest of careerInterests.slice(0, 2)) {
        searchQueries.push(interest)
      }
    } else if (keywords) {
      // Split keywords by "OR" to create separate queries
      const keywordParts = keywords.split(/\s+OR\s+/i).map(k => k.trim())
      searchQueries.push(...keywordParts.slice(0, 2)) // Limit to 2 queries
    } else {
      searchQueries.push('software engineer')
    }
    
    // Search all queries (limit to 2 to avoid timeout)
    const queriesToSearch = searchQueries.slice(0, 2)
    
    console.log(`🌐 Starting job search from ATS systems...`)
    console.log(`   - Search queries: ${JSON.stringify(queriesToSearch)}`)
    console.log(`   - Searching ${queriesToSearch.length} queries across 3 ATS sources`)
    
    // Use Workday, Greenhouse, and Lever - these search across many companies
    const sources = [
      { name: 'Greenhouse', fn: scrapeGreenhouse },
      { name: 'Lever', fn: scrapeLever },
      { name: 'Workday', fn: scrapeWorkday }
    ]
    
    console.log(`🔍 Searching ${sources.length} ATS sources (Greenhouse, Lever, Workday)...`)
    
    // Early return threshold - if we get enough jobs, return immediately
    const EARLY_RETURN_THRESHOLD = 30 // Return early if we have 30+ jobs (lowered to return faster)
    let shouldEarlyReturn = false
    
    // Search each query across all sources
    queryLoop: for (const query of queriesToSearch) {
      console.log(`\n🔎 Searching for: "${query}"`)
      
      // Run sources sequentially to avoid resource limits
      for (const source of sources) {
        // Early return if we have enough jobs
        if (allJobs.length >= EARLY_RETURN_THRESHOLD) {
          console.log(`✅ Early return: Found ${allJobs.length} jobs (threshold: ${EARLY_RETURN_THRESHOLD})`)
          shouldEarlyReturn = true
          break queryLoop
        }
        
        try {
          console.log(`⏳ Starting ${source.name} for "${query}"...`)
          const jobs = await Promise.race([
            source.fn(query, location),
            new Promise<any[]>((_, reject) => 
              setTimeout(() => reject(new Error('Source timeout')), 10000) // 10 second timeout per source
            )
          ])
          
          if (jobs && jobs.length > 0) {
            console.log(`📊 ${source.name}: Found ${jobs.length} jobs before filtering`)
            
            // Filter out any test/sample data
            const realJobs = jobs.filter(job => {
              // Exclude jobs with sample/test indicators
              const isTestData = 
                job.id?.includes('sample_') ||
                job.url?.includes('example.com') ||
                job.company?.toLowerCase().includes('tech corp') ||
                job.company?.toLowerCase().includes('analytics inc')
              return !isTestData
            })
            
            if (realJobs.length > 0) {
              allJobs.push(...realJobs)
              sourceStats[source.name] = (sourceStats[source.name] || 0) + realJobs.length
              console.log(`✅ ${source.name}: Added ${realJobs.length} real jobs (filtered out ${jobs.length - realJobs.length} test jobs)`)
            } else if (jobs.length > 0) {
              console.warn(`⚠️ ${source.name}: All ${jobs.length} jobs were filtered out as test data`)
            }
          } else {
            console.log(`ℹ️ ${source.name}: No jobs found`)
          }
        } catch (err) {
          console.error(`❌ ${source.name} scraping failed for "${query}":`, err)
          // Continue to next source
        }
        
        // Small delay between sources (reduced for speed)
        await new Promise(resolve => setTimeout(resolve, 100))
        
        // Early return check
        if (allJobs.length >= EARLY_RETURN_THRESHOLD) {
          shouldEarlyReturn = true
          break queryLoop
        }
      }
      
      // Early return check between queries
      if (allJobs.length >= EARLY_RETURN_THRESHOLD || shouldEarlyReturn) {
        console.log(`✅ Early return between queries: Found ${allJobs.length} jobs`)
        break queryLoop
      }
      
      // Small delay between queries (reduced for speed)
      await new Promise(resolve => setTimeout(resolve, 200))
    }
    
    console.log(`\n✅ Job search complete - Found jobs from Greenhouse, Lever, and Workday`)

    // Only return real scraped jobs - no test/sample data
    console.log('\n📊 Scraping Summary:')
    console.log(`   - Searched ${queriesToSearch.length} queries: ${queriesToSearch.join(', ')}`)
    console.log(`   - Location: ${location || 'all locations'}`)
    console.log(`   - Career interests: ${careerInterests.length > 0 ? careerInterests.join(', ') : 'none'}`)
    console.log(`   - Total jobs found: ${allJobs.length}`)
    console.log('📊 Jobs by source:')
    for (const [source, count] of Object.entries(sourceStats)) {
      console.log(`   - ${source}: ${count} jobs`)
    }
    
    if (allJobs.length === 0) {
      console.log('⚠️ No jobs found from scraping - returning empty array (no test data)')
      console.log('💡 This could be due to:')
      console.log('   - Keyword filtering too strict')
      console.log('   - Anti-scraping measures blocking requests')
      console.log('   - No matching jobs in the searched companies')
    } else {
      console.log(`✅ Successfully scraped ${allJobs.length} real jobs from web scraping`)
    }

    // Deduplicate jobs and ensure no test data
    const uniqueJobs = deduplicateJobs(allJobs).filter(job => {
      // Final check to ensure no test data
      return !job.id?.includes('sample_') && 
             !job.url?.includes('example.com') &&
             job.company?.toLowerCase() !== 'tech corp' &&
             job.company?.toLowerCase() !== 'analytics inc'
    })
    
    console.log(`📊 Final job count: ${uniqueJobs.length} real jobs (all test data filtered out)`)

    // Don't filter by career interests again - we already filtered during scraping
    // This was causing double filtering and removing too many jobs
    let filteredJobs = uniqueJobs
    
    // Only apply career interests filter if we have way too many jobs (>100)
    // Otherwise, return all unique jobs
    if (careerInterests.length > 0 && uniqueJobs.length > 100) {
      console.log(`📊 Applying career interests filter (${uniqueJobs.length} jobs, threshold: 100)`)
      filteredJobs = uniqueJobs.filter(job => {
        const jobText = `${job.title} ${job.company} ${job.description || ''}`.toLowerCase()
        return careerInterests.some(interest => {
          const interestLower = interest.toLowerCase()
          return jobText.includes(interestLower) || 
                 job.title.toLowerCase().includes(interestLower)
        })
      })
      
      // If filtering resulted in too few jobs, return all jobs
      if (filteredJobs.length < 10) {
        console.log(`⚠️ Career interests filter too strict (${filteredJobs.length} jobs), returning all ${uniqueJobs.length} jobs`)
        filteredJobs = uniqueJobs
      } else {
        console.log(`✅ Career interests filter: ${uniqueJobs.length} → ${filteredJobs.length} jobs`)
      }
    } else {
      console.log(`ℹ️ Skipping career interests filter (${uniqueJobs.length} jobs, threshold: 100)`)
    }

    return new Response(
      JSON.stringify(filteredJobs),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  } catch (error) {
    console.error('❌ Error in edge function:', error)
    const errorMessage = error instanceof Error ? error.message : String(error)
    return new Response(
      JSON.stringify({ error: errorMessage }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Adzuna API - PRIMARY SOURCE (searches all jobs by keywords, like sorce.jobs)
async function fetchFromAdzunaAPI(keywords: string, location: string): Promise<any[]> {
  // Get API keys from environment variables
  const APP_ID = Deno.env.get('ADZUNA_APP_ID') || 'ff850947' // Fallback for testing
  const APP_KEY = Deno.env.get('ADZUNA_APP_KEY') || '114516221e332fe7ddb772224a68e0bb' // Fallback for testing
  
  if (!APP_ID || !APP_KEY) {
    console.log('⚠️ Adzuna API keys not configured')
    return []
  }

  try {
    // Adzuna API searches across ALL companies by keywords (not specific companies)
    const country = 'us' // Change to your country code if needed
    const locationParam = location || 'United States'
    const url = `https://api.adzuna.com/v1/api/jobs/${country}/search/1?app_id=${APP_ID}&app_key=${APP_KEY}&results_per_page=50&what=${encodeURIComponent(keywords)}&where=${encodeURIComponent(locationParam)}`
    
    console.log(`   📡 Adzuna API: Searching for "${keywords}" in "${locationParam}"`)
    const response = await fetch(url)
    
    if (!response.ok) {
      console.error(`   ❌ Adzuna API error: ${response.status} ${response.statusText}`)
      return []
    }

    const data = await response.json()
    
    if (!data.results || !Array.isArray(data.results)) {
      console.log(`   ℹ️ Adzuna API: No results found`)
      return []
    }
    
    const jobs = data.results.map((job: any) => ({
      id: `adzuna_${job.id || Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      title: job.title || 'Job Title',
      company: job.company?.display_name || job.company?.name || 'Company not specified',
      location: job.location?.display_name || locationParam || 'Location not specified',
      posted_date: job.created ? new Date(job.created).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
      description: job.description || null,
      url: job.redirect_url || job.url || null,
      salary: job.salary_min && job.salary_max 
        ? `$${job.salary_min.toLocaleString()} - $${job.salary_max.toLocaleString()}`
        : job.salary_min 
        ? `$${job.salary_min.toLocaleString()}+`
        : job.salary_max
        ? `Up to $${job.salary_max.toLocaleString()}`
        : "Salary not specified",
      job_type: job.contract_type || job.job_type || null,
    }))
    
    console.log(`   ✅ Adzuna API: Found ${jobs.length} jobs`)
    return jobs
  } catch (error) {
    console.error('❌ Adzuna API error:', error)
    return []
  }
}

// Scrape Greenhouse (ATS)
async function scrapeGreenhouse(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    // Greenhouse has a public API endpoint for many companies
    // We'll try to scrape from known Greenhouse job boards
    // Pattern: boards.greenhouse.io/COMPANY_NAME or COMPANY_NAME.greenhouse.io
    
    // Expanded list of popular companies using Greenhouse
    // Prioritize companies that likely have jobs matching common search terms
    const greenhouseCompanies = [
      'stripe', 'airbnb', 'reddit', 'pinterest', 'shopify', 
      'uber', 'lyft', 'doordash', 'instacart', 'coinbase',
      'robinhood', 'plaid', 'square', 'twilio',
      'asana', 'notion', 'figma', 'linear', 'vercel',
      'github', 'gitlab', 'docker', 'mongodb', 'databricks',
      'okta', 'splunk', 'datadog', 'zendesk', 'salesforce',
      'atlassian', 'zoom', 'slack', 'dropbox', 'box',
      'palantir', 'snowflake', 'databricks', 'elastic', 'confluent',
      'hashicorp', 'cloudflare', 'fastly', 'akamai', 'cloudflare',
      'braintree', 'paypal', 'adobe', 'autodesk', 'intuit'
    ]
    
    // Limit companies to avoid timeout - search first 25 companies
    // With early return, we'll stop when we have enough jobs
    const companiesToSearch = greenhouseCompanies.slice(0, 25) // Limit to 25 companies
    
    console.log(`🔍 Greenhouse: Searching ${companiesToSearch.length} companies (of ${greenhouseCompanies.length} total) with keyword-based filtering: "${keywords || 'all jobs'}"`)
    
    for (const company of companiesToSearch) {
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
            console.log(`   📊 ${company}: Found ${data.jobs.length} total jobs from Greenhouse API`)
            // Collect all jobs first, then filter (less strict)
            const allCompanyJobs = data.jobs || []
            let matchedJobs = 0
            let jobsBeforeFilter = allCompanyJobs.length
            
            for (const job of allCompanyJobs) {
              // KEYWORD-BASED FILTERING - filter jobs by keywords/career interests
              let shouldInclude = true
              
              // Extract job location for use later
              const jobLocation = job.location?.name || ''
              
              // Apply keyword-based filtering (like sorce.jobs)
              if (keywords && keywords.trim().length > 0) {
                const jobText = `${job.title} ${job.content || ''} ${job.departments?.[0]?.name || company}`.toLowerCase()
                const keywordsLower = keywords.toLowerCase()
                // Split keywords by "OR" and check if any match
                const keywordParts = keywordsLower.split(/\s+or\s+/).map(k => k.trim())
                const matchesKeyword = keywordParts.some(part => {
                  // Check if any part of the keyword matches (flexible matching)
                  const parts = part.split(/\s+/)
                  return parts.some(p => jobText.includes(p)) || jobText.includes(part)
                })
                shouldInclude = matchesKeyword
              }
              
              // Apply location filtering
              if (shouldInclude && location && location.trim().length > 0) {
                // Only filter if location is a specific city/state, not broad terms
                if (location !== 'United States' && location !== 'Remote' && location !== 'US' && location !== 'USA') {
                  const locationLower = location.toLowerCase()
                  const jobLocationLower = jobLocation.toLowerCase()
                  // Allow if job location contains the search location or vice versa
                  if (!jobLocationLower.includes(locationLower) && !locationLower.includes(jobLocationLower)) {
                    // Still include remote jobs even if location doesn't match
                    if (!jobLocationLower.includes('remote') && !jobLocationLower.includes('anywhere')) {
                      shouldInclude = false
                    }
                  }
                }
              }
              
              if (!shouldInclude) {
                continue
              }
              
              matchedJobs++
              
              // Extract salary from Greenhouse job data
              let salary = "Salary not specified"
              if (job.content) {
                const salaryMatch = job.content.match(/\$[\d,]+(?:-\$?[\d,]+)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr))?/gi)
                if (salaryMatch && salaryMatch.length > 0) {
                  salary = salaryMatch[0]
                }
              }
              // Check if Greenhouse API provides salary data
              if (job.salary || job.compensation) {
                salary = job.salary || job.compensation
              }
              
              const jobUrl = job.absolute_url || `https://boards.greenhouse.io/${company}/jobs/${job.id}`
              
              // Don't fetch from full job post to save resources
              
              jobs.push({
                id: `greenhouse_${company}_${job.id || Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                title: job.title || 'Job Title',
                company: job.departments?.[0]?.name || company,
                location: jobLocation || location || 'Location not specified',
                posted_date: job.updated_at ? new Date(job.updated_at).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
                description: job.content || null,
                url: jobUrl,
                salary: salary,
                job_type: null,
              })
            }
            if (matchedJobs > 0 && jobsBeforeFilter > 0) {
              if (matchedJobs < jobsBeforeFilter) {
                console.log(`   ✅ ${company}: Added ${matchedJobs} jobs (location filter: ${jobsBeforeFilter - matchedJobs} filtered out)`)
              } else {
                console.log(`   ✅ ${company}: Added ${matchedJobs} jobs (all jobs included)`)
              }
            }
          }
        }
      } catch (err) {
        // Log error but continue to next company
        console.log(`   ⚠️ ${company}: Failed to fetch (${err instanceof Error ? err.message : String(err)})`)
        continue
      }
      
      // Small delay between companies
      await new Promise(resolve => setTimeout(resolve, 200))
    }
    
    if (jobs.length > 0) {
      console.log(`✅ Scraped ${jobs.length} jobs from Greenhouse (all jobs, location: "${location || 'all'}")`)
    } else {
      console.log(`ℹ️ Greenhouse: No jobs found (location: "${location || 'all'}")`)
    }
  } catch (error) {
    console.error('❌ Greenhouse scraping error:', error)
    console.error(`   - Keywords: "${keywords}", Location: "${location || 'all'}"`)
  }
  
  return jobs
}

// Scrape Lever (ATS)
async function scrapeLever(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    // Lever has a public API endpoint
    // Pattern: jobs.lever.co/COMPANY_NAME or api.lever.co/v0/postings/COMPANY_NAME
    
    // Expanded list of companies using Lever
    // Prioritize companies that likely have jobs matching common search terms
    const leverCompanies = [
      'lever', 'netflix', 'dropbox', 'slack', 'square',
      'twitch', 'github', 'asana', 'notion', 'figma',
      'spotify', 'reddit', 'pinterest', 'airbnb', 'uber',
      'lyft', 'doordash', 'instacart', 'coinbase', 'robinhood',
      'plaid', 'twilio', 'stripe', 'linear', 'vercel',
      'okta', 'splunk', 'datadog', 'zendesk', 'salesforce',
      'atlassian', 'zoom', 'box', 'palantir', 'snowflake',
      'elastic', 'confluent', 'hashicorp', 'cloudflare', 'fastly',
      'braintree', 'paypal', 'adobe', 'autodesk', 'intuit',
      'microsoft', 'google', 'meta', 'apple', 'amazon'
    ]
    
    // Limit companies to avoid timeout - search first 25 companies
    // With early return, we'll stop when we have enough jobs
    const companiesToSearch = leverCompanies.slice(0, 25) // Limit to 25 companies
    
    console.log(`🔍 Lever: Searching ${companiesToSearch.length} companies (of ${leverCompanies.length} total) with keyword-based filtering: "${keywords || 'all jobs'}"`)
    
    for (const company of companiesToSearch) {
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
            console.log(`   📊 ${company}: Found ${data.length} total jobs from Lever API`)
            // Collect all jobs first, then filter (less strict)
            const allCompanyJobs = data || []
            let matchedJobs = 0
            let jobsBeforeFilter = allCompanyJobs.length
            
            for (const job of allCompanyJobs) {
              // KEYWORD-BASED FILTERING - filter jobs by keywords/career interests
              let shouldInclude = true
              
              // Extract job location for use later
              const jobLocation = job.categories?.location || ''
              
              // Apply keyword-based filtering (like sorce.jobs)
              if (keywords && keywords.trim().length > 0) {
                const jobText = `${job.text} ${job.descriptionPlain || ''} ${company}`.toLowerCase()
                const keywordsLower = keywords.toLowerCase()
                // Split keywords by "OR" and check if any match
                const keywordParts = keywordsLower.split(/\s+or\s+/).map(k => k.trim())
                const matchesKeyword = keywordParts.some(part => {
                  // Check if any part of the keyword matches (flexible matching)
                  const parts = part.split(/\s+/)
                  return parts.some(p => jobText.includes(p)) || jobText.includes(part)
                })
                shouldInclude = matchesKeyword
              }
              
              // Apply location filtering
              if (shouldInclude && location && location.trim().length > 0) {
                // Only filter if location is a specific city/state, not broad terms
                if (location !== 'United States' && location !== 'Remote' && location !== 'US' && location !== 'USA') {
                  const locationLower = location.toLowerCase()
                  const jobLocationLower = jobLocation.toLowerCase()
                  // Allow if job location contains the search location or vice versa
                  if (!jobLocationLower.includes(locationLower) && !locationLower.includes(jobLocationLower)) {
                    // Still include remote jobs even if location doesn't match
                    if (!jobLocationLower.includes('remote') && !jobLocationLower.includes('anywhere')) {
                      shouldInclude = false
                    }
                  }
                }
              }
              
              if (!shouldInclude) {
                continue
              }
              
              matchedJobs++
              
              // Extract salary from Lever job data - enhanced patterns
              let salary = "Salary not specified"
              
              // Check if Lever API provides salary data first
              if (job.salaryRange || job.compensation) {
                salary = job.salaryRange || job.compensation
              } else if (job.descriptionPlain) {
                // Enhanced salary pattern matching
                const desc = job.descriptionPlain.toLowerCase()
                const salaryPatterns = [
                  /\$[\d,]+(?:k|K)?\s*-\s*\$?[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
                  /\$[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
                  /(?:salary|compensation|pay|wage).*?\$[\d,]+(?:-\$?[\d,]+)?/gi,
                  /\$[\d,]+(?:-\$?[\d,]+)?\s*(?:annually|yearly|per year|per month|per hour|hourly|monthly)/gi
                ]
                
                for (const pattern of salaryPatterns) {
                  const match = desc.match(pattern)
                  if (match && match.length > 0) {
                    salary = match[0].trim()
                    break
                  }
                }
              }
              
              const jobUrl = job.hostedUrl || job.applyUrl || `https://jobs.lever.co/${company}/${job.id}`
              
              // Salary extraction complete - no need to fetch from job post
              
              jobs.push({
                id: `lever_${company}_${job.id || Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                title: job.text || 'Job Title',
                company: company,
                location: jobLocation || location || 'Location not specified',
                posted_date: job.createdAt ? new Date(job.createdAt).toISOString().split('T')[0] : new Date().toISOString().split('T')[0],
                description: job.descriptionPlain || null,
                url: jobUrl,
                salary: salary,
                job_type: job.categories?.commitment || null,
              })
            }
            if (matchedJobs > 0 && jobsBeforeFilter > 0) {
              if (matchedJobs < jobsBeforeFilter) {
                console.log(`   ✅ ${company}: Added ${matchedJobs} jobs (location filter: ${jobsBeforeFilter - matchedJobs} filtered out)`)
              } else {
                console.log(`   ✅ ${company}: Added ${matchedJobs} jobs (all jobs included)`)
              }
            }
          }
        }
      } catch (err) {
        console.log(`   ⚠️ ${company}: Failed to fetch (${err instanceof Error ? err.message : String(err)})`)
        continue
      }
      
      await new Promise(resolve => setTimeout(resolve, 200))
    }
    
    if (jobs.length > 0) {
      console.log(`✅ Scraped ${jobs.length} jobs from Lever (keyword-based search: "${keywords || 'all'}", location: "${location || 'all'}")`)
    } else {
      console.log(`ℹ️ Lever: No jobs found matching keywords "${keywords || 'all'}" (location: "${location || 'all'}")`)
    }
  } catch (error) {
    console.error('❌ Lever scraping error:', error)
    console.error(`   - Keywords: "${keywords}", Location: "${location || 'all'}"`)
  }
  
  return jobs
}

// Scrape Workday (ATS)
async function scrapeWorkday(keywords: string, location: string): Promise<any[]> {
  const jobs: any[] = []
  
  try {
    // Workday is more complex - companies use different subdomains
    // Pattern: COMPANY.wd3.myworkdayjobs.com or COMPANY.myworkdayjobs.com
    
    // Expanded list of companies using Workday
    const workdayCompanies = [
      'apple', 'microsoft', 'amazon', 'google', 'meta',
      'nvidia', 'oracle', 'salesforce', 'adobe', 'intel',
      'ibm', 'cisco', 'hp', 'dell', 'vmware',
      'paypal', 'visa', 'mastercard', 'jpmorgan', 'goldmansachs'
    ]
    
    // Limit companies to avoid timeout - search first 15 companies (Workday is slower)
    // With early return, we'll stop when we have enough jobs
    const companiesToSearch = workdayCompanies.slice(0, 15) // Limit to 15 companies
    
    console.log(`🔍 Workday: Searching ${companiesToSearch.length} companies (of ${workdayCompanies.length} total) with keyword-based filtering: "${keywords || 'all jobs'}"`)
    
    for (const company of companiesToSearch) {
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
              const workdayJobPromises: Promise<void>[] = []
              
              $('[data-automation-id="jobTitle"], .job-title, [data-testid="job-title"]').each((i: number, element: any) => {
                const jobPromise = (async () => {
                  try {
                    const $el = $(element)
                    const title = $el.text().trim()
                    
                    // KEYWORD-BASED FILTERING - filter jobs by keywords/career interests
                    if (keywords && keywords.trim().length > 0) {
                      const jobCard = $el.closest('[data-automation-id="jobPosting"]')
                      const description = jobCard.find('[data-automation-id="jobDescription"]').text() || ''
                      const jobText = `${title} ${description} ${company}`.toLowerCase()
                      const keywordsLower = keywords.toLowerCase()
                      
                      // Split keywords by "OR" and check if any match
                      const keywordParts = keywordsLower.split(/\s+or\s+/).map(k => k.trim())
                      const matchesKeyword = keywordParts.some(part => {
                        // Check if any part of the keyword matches (flexible matching)
                        const parts = part.split(/\s+/)
                        return parts.some(p => jobText.includes(p)) || jobText.includes(part)
                      })
                      
                      if (!matchesKeyword) {
                        return // Skip this job if it doesn't match keywords
                      }
                    }
                    
                    const jobUrl = $el.attr('href') || $el.find('a').attr('href')
                    const fullUrl = jobUrl && !jobUrl.startsWith('http') 
                      ? `${workdayUrl}${jobUrl}` 
                      : jobUrl
                    
                    // Try to find location and other details
                    const locationText = $el.closest('[data-automation-id="jobPosting"]').find('[data-automation-id="jobLocation"]').text().trim() || location
                    
                    // Extract salary from Workday job listing - enhanced patterns
                    let salary = "Salary not specified"
                    const jobCard = $el.closest('[data-automation-id="jobPosting"]')
                    const salaryText = jobCard.find('[data-automation-id="compensationText"], .salary, .compensation').text().trim()
                    
                    if (salaryText) {
                      salary = salaryText
                    } else {
                      // Try to extract from description with enhanced patterns
                      const desc = jobCard.find('[data-automation-id="jobDescription"]').text()
                      if (desc) {
                        const descLower = desc.toLowerCase()
                        const salaryPatterns = [
                          /\$[\d,]+(?:k|K)?\s*-\s*\$?[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
                          /\$[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
                          /(?:salary|compensation|pay|wage).*?\$[\d,]+(?:-\$?[\d,]+)?/gi,
                          /\$[\d,]+(?:-\$?[\d,]+)?\s*(?:annually|yearly|per year|per month|per hour|hourly|monthly)/gi
                        ]
                        
                        for (const pattern of salaryPatterns) {
                          const match = descLower.match(pattern)
                          if (match && match.length > 0) {
                            salary = match[0].trim()
                            break
                          }
                        }
                      }
                    }
                    
                    jobs.push({
                      id: `workday_${company}_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
                      title: title || 'Job Title',
                      company: company,
                      location: locationText || 'Location not specified',
                      posted_date: new Date().toISOString().split('T')[0],
                      description: null,
                      url: fullUrl || null,
                      salary: salary,
                      job_type: null,
                    })
                  } catch (err) {
                    // Skip individual job parsing errors
                  }
                })()
                
                workdayJobPromises.push(jobPromise)
              })
              
              // Wait for all Workday jobs to be processed
              await Promise.race([
                Promise.all(workdayJobPromises),
                new Promise(resolve => setTimeout(resolve, 20000)) // 20 second timeout for Workday
              ])
              
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
      
      await new Promise(resolve => setTimeout(resolve, 200)) // Reduced delay for Workday
    }
    
    if (jobs.length > 0) {
      console.log(`✅ Scraped ${jobs.length} jobs from Workday (keyword-based search: "${keywords || 'all'}", location: "${location || 'all'}")`)
    } else {
      console.log(`ℹ️ Workday: No jobs found matching keywords "${keywords || 'all'}" (location: "${location || 'all'}")`)
    }
  } catch (error) {
    console.error('❌ Workday scraping error:', error)
  }
  
  return jobs
}

// Helper function to extract salary from full job post page
async function extractSalaryFromJobPost(jobUrl: string | null, source: string): Promise<string> {
  if (!jobUrl) {
    return "Salary not specified"
  }
  
  try {
    const response = await fetch(jobUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.5',
      }
    })
    
    if (!response.ok) {
      return "Salary not specified"
    }
    
    const html = await response.text()
    const $ = load(html)
    
    // Try multiple selectors based on source
    let salary = ""
    
    if (source === 'indeed') {
      salary = $('.jobsearch-JobMetadataHeader-item, .jobsearch-JobComponent-description, [data-testid="job-salary"]').text().trim()
      // Also check in job description
      const description = $('.jobsearch-jobDescriptionText, #jobDescriptionText').text()
      const salaryMatch = description.match(/\$[\d,]+(?:-\$?[\d,]+)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi)
      if (salaryMatch && salaryMatch.length > 0) {
        salary = salaryMatch[0]
      }
    } else if (source === 'monster') {
      salary = $('.salary, .compensation, [data-testid="salary"]').text().trim()
      const description = $('.job-description, .jobDescription').text()
      const salaryMatch = description.match(/\$[\d,]+(?:-\$?[\d,]+)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi)
      if (salaryMatch && salaryMatch.length > 0) {
        salary = salaryMatch[0]
      }
    } else if (source === 'glassdoor') {
      salary = $('[data-test="detailSalary"], .salary, .estimated-salary, .jobSalary').text().trim()
      const description = $('.jobDescriptionContent, .jobDescription').text()
      const salaryMatch = description.match(/\$[\d,]+(?:-\$?[\d,]+)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi)
      if (salaryMatch && salaryMatch.length > 0) {
        salary = salaryMatch[0]
      }
    } else if (source === 'ziprecruiter') {
      salary = $('.salary, .compensation, [data-testid="salary"]').text().trim()
      const description = $('.job_description, .jobDescription').text()
      const salaryMatch = description.match(/\$[\d,]+(?:-\$?[\d,]+)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi)
      if (salaryMatch && salaryMatch.length > 0) {
        salary = salaryMatch[0]
      }
    } else {
      // Generic extraction for other sources
      salary = $('.salary, .compensation, [data-testid="salary"], [itemprop="baseSalary"]').text().trim()
      const description = $('body').text()
      const salaryMatch = description.match(/\$[\d,]+(?:-\$?[\d,]+)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi)
      if (salaryMatch && salaryMatch.length > 0) {
        salary = salaryMatch[0]
      }
    }
    
    // Clean up salary text
    if (salary) {
      salary = salary.replace(/\s+/g, ' ').trim()
      // If it's too long, try to extract just the salary range
      if (salary.length > 100) {
        const rangeMatch = salary.match(/\$[\d,]+(?:-\$?[\d,]+)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi)
        if (rangeMatch && rangeMatch.length > 0) {
          salary = rangeMatch[0]
        }
      }
    }
    
    return salary || "Salary not specified"
  } catch (error) {
    console.error(`Error fetching salary from job post (${source}):`, error)
    return "Salary not specified"
  }
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
    console.log(`📄 Indeed: Received ${html.length} bytes of HTML for "${keywords}"`)
    
    if (html.length < 1000) {
      console.warn(`⚠️ Indeed: HTML response seems too short, might be blocked or error page`)
      return jobs
    }
    
    const $ = load(html)
    
    // Try multiple selectors for Indeed job listings (they change frequently)
    const selectors = [
      '.job_seen_beacon',
      '.slider_container', 
      '[data-jk]',
      '.jobCard',
      '.jobsearch-SerpJobCard'
    ]
    
    let jobElements: any = null
    for (const selector of selectors) {
      jobElements = $(selector)
      if (jobElements.length > 0) {
        console.log(`🔍 Indeed: Found ${jobElements.length} job elements using selector "${selector}"`)
        break
      }
    }
    
    if (!jobElements || jobElements.length === 0) {
      console.warn(`⚠️ Indeed: No job elements found with any selector`)
      console.log(`   - Tried selectors: ${selectors.join(', ')}`)
      return jobs
    }

    // Process jobs synchronously to avoid timeout issues
    jobElements.each((i: number, element: any) => {
      try {
        const $el = $(element)
        
        // Extract job title - try multiple selectors
        let titleLink = $el.find('h2.jobTitle a').first()
        if (titleLink.length === 0) {
          titleLink = $el.find('.jobTitle a, a[data-jk]').first()
        }
        const title = titleLink.text().trim() || $el.find('h2.jobTitle, .jobTitle').text().trim()
        
        // Extract company - try multiple selectors
        let company = $el.find('.companyName').text().trim()
        if (!company) {
          company = $el.find('[data-testid="company-name"], .company').text().trim()
        }
        
        // Extract location
        let jobLocation = $el.find('.companyLocation').text().trim()
        if (!jobLocation) {
          jobLocation = $el.find('[data-testid="text-location"], .location').text().trim()
        }
        
        // Extract job URL
        let jobUrl = titleLink.attr('href')
        if (jobUrl && !jobUrl.startsWith('http')) {
          jobUrl = `https://www.indeed.com${jobUrl}`
        }
        
        // Extract salary - enhanced pattern matching
        let salary = $el.find('.salary-snippet-container, .attribute_snippet, [data-testid="attribute_snippet"]').text().trim()
        
        // Try to find salary in description/summary with enhanced patterns
        if (!salary) {
          const desc = $el.find('.job-snippet, .summary').text()
          const allText = `${desc} ${$el.text()}`.toLowerCase()
          
          // Enhanced salary patterns: $XX,XXX - $XX,XXX, $XXk - $XXk, $XX/hour, etc.
          const salaryPatterns = [
            /\$[\d,]+(?:k|K)?\s*-\s*\$?[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
            /\$[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
            /(?:salary|compensation|pay|wage).*?\$[\d,]+(?:-\$?[\d,]+)?/gi,
            /\$[\d,]+(?:-\$?[\d,]+)?\s*(?:annually|yearly|per year|per month|per hour|hourly|monthly)/gi
          ]
          
          for (const pattern of salaryPatterns) {
            const match = allText.match(pattern)
            if (match && match.length > 0) {
              salary = match[0].trim()
              break
            }
          }
        }
        
        // Default if no salary found
        if (!salary) {
          salary = "Salary not specified"
        }
        
        // Extract description/snippet
        const description = $el.find('.job-snippet, .summary').text().trim()

        // Require title, but company can be optional (some job boards don't show company immediately)
        if (title) {
          jobs.push({
            id: `indeed_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
            title: title,
            company: company || 'Company not specified',
            location: jobLocation || location || 'Location not specified',
            posted_date: new Date().toISOString().split('T')[0],
            description: description || null,
            url: jobUrl || null,
            salary: salary,
            job_type: null,
          })
        } else {
          console.warn(`⚠️ Indeed job ${i}: Missing title, skipping`)
        }
      } catch (err) {
        console.error(`❌ Error parsing Indeed job ${i}:`, err)
      }
    })

    if (jobs.length === 0) {
      console.warn(`⚠️ Indeed: No jobs found for "${keywords}" in "${location || 'all locations'}"`)
      console.log(`   - This could be due to: no matching jobs, anti-scraping measures, or changed HTML structure`)
    } else {
      console.log(`✅ Scraped ${jobs.length} jobs from Indeed`)
    }
  } catch (error) {
    console.error('❌ Indeed scraping error:', error)
    console.error(`   - Keywords: "${keywords}", Location: "${location || 'all'}"`)
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
    const jobPromises: Promise<void>[] = []
    
    $('[data-testid="organic-job"], .card-content, .summary').each((i: number, element: any) => {
      const jobPromise = (async () => {
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
          
          // Extract salary - comprehensive pattern matching
          let salary = $el.find('.salary, .compensation, [data-testid="salary"], .job-salary, .pay-range').text().trim()
          
          // Try to find salary in description and all text
          if (!salary) {
            const allText = `${description} ${$el.text()}`.toLowerCase()
            // Look for various salary patterns
            const salaryPatterns = [
              /\$[\d,]+(?:k|K)?\s*-\s*\$?[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
              /\$[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
              /(?:salary|compensation|pay|wage).*?\$[\d,]+(?:-\$?[\d,]+)?/gi,
              /\$[\d,]+(?:-\$?[\d,]+)?\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly)/gi
            ]
            
            for (const pattern of salaryPatterns) {
              const match = allText.match(pattern)
              if (match && match.length > 0) {
                salary = match[0].trim()
                break
              }
            }
          }
          
          // Default if no salary found
          if (!salary) {
            salary = "Salary not specified"
          }

          // Require title, but company can be optional
          if (title) {
            jobs.push({
              id: `monster_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
              title: title,
              company: company || 'Company not specified',
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
      })()
      
      jobPromises.push(jobPromise)
    })
    
    await Promise.race([
      Promise.all(jobPromises),
      new Promise(resolve => setTimeout(resolve, 30000))
    ])

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
    const jobPromises: Promise<void>[] = []
    
    $('[data-test="job-listing"], .jobContainer, .react-job-listing').each((i: number, element: any) => {
      const jobPromise = (async () => {
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
          
          // Extract salary - comprehensive pattern matching
          let salary = $el.find('[data-test="detailSalary"], .salary, .estimated-salary, .jobSalary, .pay-range').text().trim()
          
          // Try to find salary in description and all text
          if (!salary) {
            const allText = `${description} ${$el.text()}`.toLowerCase()
            // Look for various salary patterns
            const salaryPatterns = [
              /\$[\d,]+(?:k|K)?\s*-\s*\$?[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
              /\$[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
              /(?:salary|compensation|pay|wage).*?\$[\d,]+(?:-\$?[\d,]+)?/gi,
              /\$[\d,]+(?:-\$?[\d,]+)?\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly)/gi
            ]
            
            for (const pattern of salaryPatterns) {
              const match = allText.match(pattern)
              if (match && match.length > 0) {
                salary = match[0].trim()
                break
              }
            }
          }
          
          // Default if no salary found
          if (!salary) {
            salary = "Salary not specified"
          }

          // Require title, but company can be optional
          if (title) {
            jobs.push({
              id: `glassdoor_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
              title: title,
              company: company || 'Company not specified',
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
      })()
      
      jobPromises.push(jobPromise)
    })
    
    await Promise.race([
      Promise.all(jobPromises),
      new Promise(resolve => setTimeout(resolve, 30000))
    ])

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
    const jobPromises: Promise<void>[] = []
    
    $('.job_content, .job_result, [data-testid="job-card"]').each((i: number, element: any) => {
      const jobPromise = (async () => {
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
          
          // Extract salary - comprehensive pattern matching
          let salary = $el.find('.salary, .compensation, [data-testid="salary"], .job-salary, .pay-range').text().trim()
          
          // Try to find salary in description and all text
          if (!salary) {
            const allText = `${description} ${$el.text()}`.toLowerCase()
            // Look for various salary patterns
            const salaryPatterns = [
              /\$[\d,]+(?:k|K)?\s*-\s*\$?[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
              /\$[\d,]+(?:k|K)?(?:\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly))?/gi,
              /(?:salary|compensation|pay|wage).*?\$[\d,]+(?:-\$?[\d,]+)?/gi,
              /\$[\d,]+(?:-\$?[\d,]+)?\s*(?:per|\/)\s*(?:year|month|hour|yr|mo|hr|annually|monthly|hourly)/gi
            ]
            
            for (const pattern of salaryPatterns) {
              const match = allText.match(pattern)
              if (match && match.length > 0) {
                salary = match[0].trim()
                break
              }
            }
          }
          
          // Default if no salary found
          if (!salary) {
            salary = "Salary not specified"
          }

          // Require title, but company can be optional
          if (title) {
            jobs.push({
              id: `ziprecruiter_${i}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
              title: title,
              company: company || 'Company not specified',
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
      })()
      
      jobPromises.push(jobPromise)
    })
    
    await Promise.race([
      Promise.all(jobPromises),
      new Promise(resolve => setTimeout(resolve, 30000))
    ])

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

// Sample jobs function - NOT USED (removed to ensure only real scraped data is returned)
// This function is kept for reference but is never called
/*
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
      salary: "$70,000 - $90,000",
      job_type: "Full-time"
    }
  ]
}
*/

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


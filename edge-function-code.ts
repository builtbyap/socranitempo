import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

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
        // If parsing fails, try without decodeURIComponent
        try {
          careerInterests = JSON.parse(careerInterestsParam)
        } catch {
          careerInterests = []
        }
      }
    }

    // TODO: Implement actual job scraping logic here
    // This is sample data that matches your JobPost structure
    const jobs = [
      {
        id: "1",
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
        id: "2",
        title: "Data Analyst",
        company: "Analytics Inc",
        location: location || "Remote",
        posted_date: new Date().toISOString().split('T')[0],
        description: "Join our data team to analyze user behavior and drive product decisions.",
        url: "https://example.com/job/2",
        salary: null,
        job_type: "Full-time"
      },
      {
        id: "3",
        title: "Product Manager",
        company: "StartupXYZ",
        location: location || "New York, NY",
        posted_date: new Date().toISOString().split('T')[0],
        description: "Lead product development and work with engineering teams to build great products.",
        url: "https://example.com/job/3",
        salary: "$130,000 - $160,000",
        job_type: "Full-time"
      },
      {
        id: "4",
        title: "Marketing Associate",
        company: "Growth Co",
        location: location || "Los Angeles, CA",
        posted_date: new Date().toISOString().split('T')[0],
        description: "Help grow our brand through digital marketing campaigns and social media.",
        url: "https://example.com/job/4",
        salary: "$60,000 - $80,000",
        job_type: "Full-time"
      },
      {
        id: "5",
        title: "Finance Analyst",
        company: "Finance Corp",
        location: location || "Chicago, IL",
        posted_date: new Date().toISOString().split('T')[0],
        description: "Analyze financial data, create reports, and support strategic decision-making.",
        url: "https://example.com/job/5",
        salary: "$70,000 - $90,000",
        job_type: "Full-time"
      }
    ]

    // Filter by career interests if provided
    let filteredJobs = jobs
    if (careerInterests.length > 0) {
      filteredJobs = jobs.filter(job => {
        const jobText = `${job.title} ${job.company} ${job.description || ''}`.toLowerCase()
        return careerInterests.some(interest => 
          jobText.includes(interest.toLowerCase())
        )
      })
    }

    // Filter by keywords if provided
    if (keywords) {
      const keywordLower = keywords.toLowerCase()
      filteredJobs = filteredJobs.filter(job => {
        const jobText = `${job.title} ${job.company} ${job.description || ''}`.toLowerCase()
        return jobText.includes(keywordLower)
      })
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


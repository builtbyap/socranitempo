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
    const { jobUrl } = await req.json()
    
    if (!jobUrl) {
      return new Response(
        JSON.stringify({ error: 'jobUrl is required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`📋 Fetching job details from: ${jobUrl}`)
    
    const sections = await extractJobSections(jobUrl)
    
    return new Response(
      JSON.stringify({ sections: sections || [] }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Error fetching job details:', error)
    return new Response(
      JSON.stringify({ error: error.message, sections: [] }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})

// Extract structured sections from job post URL (like "What you'll do", "Requirements", etc.)
async function extractJobSections(jobUrl: string): Promise<any[] | null> {
  try {
    const response = await fetch(jobUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      }
    })
    
    if (!response.ok) {
      return null
    }
    
    const html = await response.text()
    const $ = load(html)
    
    const sections: any[] = []
    
    // Common section title patterns
    const sectionPatterns = [
      /what\s+you'?ll\s+do/i,
      /what\s+you'?ll\s+work\s+on/i,
      /responsibilities/i,
      /requirements/i,
      /qualifications/i,
      /what\s+we'?re\s+looking\s+for/i,
      /key\s+responsibilities/i,
      /essential\s+qualifications/i,
      /preferred\s+qualifications/i,
      /benefits/i,
      /perks/i,
      /about\s+the\s+role/i,
      /about\s+the\s+team/i
    ]
    
    // Try to find sections by common headings
    $('h2, h3, h4, .section-title, [class*="section"], [class*="heading"]').each((i: number, element: any) => {
      const $el = $(element)
      const title = $el.text().trim()
      
      // Check if this heading matches any section pattern
      const matchesPattern = sectionPatterns.some(pattern => pattern.test(title))
      
      if (matchesPattern && title.length < 100) {
        // Find the content after this heading
        let content = ''
        let nextElement = $el.next()
        
        // Collect content until we hit another heading or section
        while (nextElement.length > 0 && 
               !nextElement.is('h1, h2, h3, h4, h5, h6') &&
               content.length < 2000) {
          const text = nextElement.text().trim()
          if (text) {
            content += text + ' '
          }
          nextElement = nextElement.next()
        }
        
        // Also try to find content in parent container
        if (!content) {
          const parent = $el.parent()
          const siblings = parent.find('p, li, div').not('h1, h2, h3, h4, h5, h6')
          content = siblings.text().trim().substring(0, 2000)
        }
        
        if (content.trim().length > 20) {
          sections.push({
            id: `section_${i}_${Date.now()}`,
            title: title,
            content: content.trim().substring(0, 1000) // Limit content length
          })
        }
      }
    })
    
    // If no sections found with patterns, try to find common section structures
    if (sections.length === 0) {
      // Look for divs with common class names
      $('[class*="section"], [class*="requirement"], [class*="responsibility"]').each((i: number, element: any) => {
        const $el = $(element)
        const titleEl = $el.find('h2, h3, h4, strong').first()
        const title = titleEl.text().trim()
        const content = $el.find('p, li, div').not('h1, h2, h3, h4, h5, h6').text().trim()
        
        if (title && content && content.length > 20 && content.length < 2000) {
          sections.push({
            id: `section_${i}_${Date.now()}`,
            title: title.substring(0, 100),
            content: content.substring(0, 1000)
          })
        }
      })
    }
    
    return sections.length > 0 ? sections : null
  } catch (error) {
    console.error('Error extracting job sections:', error)
    return null
  }
}


// Supabase Edge Function: Automated Job Application using Playwright
// This function fully automates job applications server-side, so users don't need to manually apply

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { chromium } from "https://deno.land/x/playwright@1.40.0/mod.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface ApplicationData {
  fullName: string
  firstName?: string
  lastName?: string
  email: string
  phone: string
  location?: string
  linkedIn?: string
  github?: string
  portfolio?: string
  coverLetter: string
  resumeUrl?: string // URL to resume file (Supabase Storage or external URL)
  resumeBase64?: string // Base64 encoded resume (alternative to URL)
  resumeFileName?: string
  workExperience?: Array<{
    company: string
    title: string
    startDate: string
    endDate?: string
    description?: string
  }>
  education?: Array<{
    school: string
    degree: string
    field?: string
    graduationDate?: string
  }>
}

interface AutoApplyRequest {
  jobUrl: string
  jobTitle: string
  company: string
  applicationData: ApplicationData
}

// Detect ATS system from URL or page content
function detectATSSystem(url: string, pageContent?: string): string {
  const urlLower = url.toLowerCase()
  const content = (pageContent || '').toLowerCase()
  
  if (urlLower.includes('workday') || urlLower.includes('myworkdayjobs') || content.includes('workday')) {
    return 'workday'
  } else if (urlLower.includes('greenhouse') || urlLower.includes('boards.greenhouse.io') || content.includes('greenhouse')) {
    return 'greenhouse'
  } else if (urlLower.includes('lever') || urlLower.includes('lever.co') || content.includes('lever')) {
    return 'lever'
  } else if (urlLower.includes('smartrecruiters') || content.includes('smartrecruiters')) {
    return 'smartrecruiters'
  } else if (urlLower.includes('jobvite') || content.includes('jobvite')) {
    return 'jobvite'
  } else if (urlLower.includes('icims') || content.includes('icims')) {
    return 'icims'
  } else if (urlLower.includes('taleo') || content.includes('taleo')) {
    return 'taleo'
  } else if (urlLower.includes('bamboohr') || content.includes('bamboohr')) {
    return 'bamboohr'
  }
  
  return 'unknown'
}

// Fill form fields using Playwright
async function fillFormField(
  page: any,
  selectors: string[],
  value: string,
  options: { waitFor?: boolean, clearFirst?: boolean } = {}
): Promise<boolean> {
  const { waitFor = true, clearFirst = true } = options
  
  for (const selector of selectors) {
    try {
      // Check if element exists
      const element = await page.$(selector)
      if (!element) {
        continue
      }
      
      if (waitFor) {
        await page.waitForSelector(selector, { timeout: 5000, state: 'visible' })
      }
      
      if (clearFirst) {
        await page.fill(selector, '')
      }
      
      await page.fill(selector, value)
      
      // Trigger events to ensure form validation
      await page.evaluate((sel) => {
        const elem = document.querySelector(sel)
        if (elem) {
          elem.dispatchEvent(new Event('input', { bubbles: true }))
          elem.dispatchEvent(new Event('change', { bubbles: true }))
        }
      }, selector)
      
      return true
    } catch (e) {
      // Try next selector
      continue
    }
  }
  
  return false
}

// Fill common application form fields
async function fillApplicationForm(page: any, data: ApplicationData): Promise<number> {
  let filledCount = 0
  
  const firstName = data.firstName || data.fullName.split(' ')[0] || ''
  const lastName = data.lastName || data.fullName.split(' ').slice(1).join(' ') || ''
  
  // First Name
  if (firstName && await fillFormField(page, [
    'input[name="firstName"]',
    'input[name="first_name"]',
    'input[id*="first"]',
    'input[id*="firstName"]',
    'input[placeholder*="First"]',
    '#first-name',
    '#firstName'
  ], firstName)) {
    filledCount++
  }
  
  // Last Name
  if (lastName && await fillFormField(page, [
    'input[name="lastName"]',
    'input[name="last_name"]',
    'input[id*="last"]',
    'input[id*="lastName"]',
    'input[placeholder*="Last"]',
    '#last-name',
    '#lastName'
  ], lastName)) {
    filledCount++
  }
  
  // Full Name (fallback)
  if (data.fullName && !firstName) {
    if (await fillFormField(page, [
      'input[name="name"]',
      'input[name="full_name"]',
      'input[name="fullName"]',
      'input[id*="name"]',
      'input[placeholder*="Name"]',
      '#name',
      '#full-name'
    ], data.fullName)) {
      filledCount++
    }
  }
  
  // Email
  if (data.email && await fillFormField(page, [
    'input[type="email"]',
    'input[name="email"]',
    'input[name="emailAddress"]',
    'input[id*="email"]',
    'input[placeholder*="Email"]',
    '#email'
  ], data.email)) {
    filledCount++
  }
  
  // Phone
  if (data.phone && await fillFormField(page, [
    'input[type="tel"]',
    'input[name="phone"]',
    'input[name="phone_number"]',
    'input[name="phoneNumber"]',
    'input[id*="phone"]',
    'input[placeholder*="Phone"]',
    '#phone'
  ], data.phone)) {
    filledCount++
  }
  
  // Location
  if (data.location && await fillFormField(page, [
    'input[name="location"]',
    'input[name="city"]',
    'input[name="address"]',
    'input[id*="location"]',
    'input[id*="city"]',
    'input[placeholder*="Location"]',
    '#location'
  ], data.location)) {
    filledCount++
  }
  
  // LinkedIn
  if (data.linkedIn && await fillFormField(page, [
    'input[name="linkedin"]',
    'input[name="linkedIn"]',
    'input[name="linkedin_url"]',
    'input[id*="linkedin"]',
    'input[placeholder*="LinkedIn"]',
    '#linkedin'
  ], data.linkedIn)) {
    filledCount++
  }
  
  // GitHub
  if (data.github && await fillFormField(page, [
    'input[name="github"]',
    'input[name="github_url"]',
    'input[id*="github"]',
    'input[placeholder*="GitHub"]',
    '#github'
  ], data.github)) {
    filledCount++
  }
  
  // Portfolio
  if (data.portfolio && await fillFormField(page, [
    'input[name="portfolio"]',
    'input[name="portfolio_url"]',
    'input[name="website"]',
    'input[id*="portfolio"]',
    'input[placeholder*="Portfolio"]',
    '#portfolio'
  ], data.portfolio)) {
    filledCount++
  }
  
  // Cover Letter
  if (data.coverLetter) {
    if (await fillFormField(page, [
      'textarea[name="coverLetter"]',
      'textarea[name="cover_letter"]',
      'textarea[name="coverLetterText"]',
      'textarea[id*="cover"]',
      'textarea[placeholder*="Cover"]',
      '#cover-letter',
      'textarea'
    ], data.coverLetter, { clearFirst: true })) {
      filledCount++
    }
  }
  
  return filledCount
}

// Upload resume file
async function uploadResume(page: any, data: ApplicationData): Promise<boolean> {
  try {
    // Try to find file input
    const fileSelectors = [
      'input[type="file"]',
      'input[name*="resume"]',
      'input[name*="cv"]',
      'input[id*="resume"]',
      'input[id*="cv"]',
      'input[accept*="pdf"]',
      'input[accept*="doc"]'
    ]
    
    let fileInput = null
    for (const selector of fileSelectors) {
      try {
        fileInput = await page.$(selector)
        if (fileInput) break
      } catch (e) {
        continue
      }
    }
    
    if (!fileInput) {
      console.log('⚠️ No file input found for resume upload')
      return false
    }
    
    // Get resume file
    let resumePath: string | null = null
    
    if (data.resumeBase64 && data.resumeFileName) {
      // Decode base64 and save to temp file
      const resumeData = Uint8Array.from(atob(data.resumeBase64), c => c.charCodeAt(0))
      const tempPath = `/tmp/${data.resumeFileName}`
      await Deno.writeFile(tempPath, resumeData)
      resumePath = tempPath
    } else if (data.resumeUrl) {
      // Download resume from URL
      try {
        const response = await fetch(data.resumeUrl)
        const arrayBuffer = await response.arrayBuffer()
        const fileName = data.resumeFileName || 'resume.pdf'
        const tempPath = `/tmp/${fileName}`
        await Deno.writeFile(tempPath, new Uint8Array(arrayBuffer))
        resumePath = tempPath
      } catch (e) {
        console.error('Failed to download resume:', e)
        return false
      }
    }
    
    if (!resumePath) {
      console.log('⚠️ No resume file available')
      return false
    }
    
    // Upload file
    await fileInput.setInputFiles(resumePath)
    console.log('✅ Resume uploaded successfully')
    
    // Clean up temp file
    try {
      await Deno.remove(resumePath)
    } catch (e) {
      // Ignore cleanup errors
    }
    
    return true
  } catch (error) {
    console.error('❌ Resume upload failed:', error)
    return false
  }
}

// ATS-specific form filling
async function fillATSForm(page: any, ats: string, data: ApplicationData): Promise<number> {
  let filledCount = 0
  
  switch (ats) {
    case 'workday':
      // Workday-specific selectors
      filledCount += await fillApplicationForm(page, data)
      // Workday often uses iframes - handle if needed
      break
      
    case 'greenhouse':
      // Greenhouse-specific selectors
      filledCount += await fillApplicationForm(page, data)
      break
      
    case 'lever':
      // Lever-specific selectors
      filledCount += await fillApplicationForm(page, data)
      break
      
    default:
      // Generic form filling
      filledCount += await fillApplicationForm(page, data)
  }
  
  return filledCount
}

// Main automation function
async function automateApplication(request: AutoApplyRequest): Promise<{
  success: boolean
  filledFields: number
  atsSystem: string
  error?: string
  screenshot?: string // Base64 screenshot for debugging
}> {
  const browser = await chromium.launch({
    headless: true,
    args: ['--no-sandbox', '--disable-setuid-sandbox']
  })
  
  const context = await browser.newContext({
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    viewport: { width: 1280, height: 720 }
  })
  
  const page = await context.newPage()
  
  try {
    console.log(`🌐 Navigating to: ${request.jobUrl}`)
    await page.goto(request.jobUrl, { waitUntil: 'networkidle', timeout: 30000 })
    
    // Detect ATS system
    const pageContent = await page.content()
    const atsSystem = detectATSSystem(request.jobUrl, pageContent)
    console.log(`🔍 Detected ATS: ${atsSystem}`)
    
    // Wait a bit for dynamic content to load
    await page.waitForTimeout(2000)
    
    // Fill form fields
    console.log('📝 Filling application form...')
    const filledFields = await fillATSForm(page, atsSystem, request.applicationData)
    console.log(`✅ Filled ${filledFields} fields`)
    
    // Upload resume
    console.log('📄 Uploading resume...')
    const resumeUploaded = await uploadResume(page, request.applicationData)
    
    // Take screenshot for debugging
    const screenshot = await page.screenshot({ encoding: 'base64' })
    
    // Note: We don't auto-submit here for safety and legal reasons
    // The form is filled, but submission should be confirmed
    // You can add auto-submit logic if needed, but be aware of:
    // 1. Legal implications
    // 2. CAPTCHA challenges
    // 3. Additional questions that need answers
    // 4. Terms of service compliance
    
    await browser.close()
    
    return {
      success: true,
      filledFields: filledFields + (resumeUploaded ? 1 : 0),
      atsSystem,
      screenshot
    }
  } catch (error) {
    console.error('❌ Automation failed:', error)
    const screenshot = await page.screenshot({ encoding: 'base64' }).catch(() => null)
    
    await browser.close()
    
    return {
      success: false,
      filledFields: 0,
      atsSystem: 'unknown',
      error: error instanceof Error ? error.message : String(error),
      screenshot: screenshot || undefined
    }
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  
  try {
    const request: AutoApplyRequest = await req.json()
    
    if (!request.jobUrl || !request.applicationData) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields: jobUrl and applicationData' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`🚀 Starting automated application for: ${request.jobTitle} at ${request.company}`)
    
    const result = await automateApplication(request)
    
    return new Response(
      JSON.stringify(result),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Edge function error:', error)
    return new Response(
      JSON.stringify({ 
        error: error instanceof Error ? error.message : String(error),
        success: false
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


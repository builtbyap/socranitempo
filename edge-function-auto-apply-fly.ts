// Supabase Edge Function: Automated Job Application using Fly.io Playwright Service
// This calls a Playwright service deployed on Fly.io

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// Fly.io service URL
// Get this from: flyctl status or flyctl open
// Default to the deployed service URL
const FLY_PLAYWRIGHT_SERVICE_URL = Deno.env.get('FLY_PLAYWRIGHT_SERVICE_URL') || 'https://surgeapp-playwright.fly.dev'

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
  resumeUrl?: string
  resumeBase64?: string
  resumeFileName?: string
}

interface AutoApplyRequest {
  jobUrl: string
  jobTitle: string
  company: string
  applicationData: ApplicationData
  answers?: { [key: string]: string } // Answers to questions (key is question index as string)
  streamSessionId?: string // Session ID for live streaming
}

// Call Fly.io Playwright service
async function automateWithFlyService(
  jobUrl: string,
  applicationData: ApplicationData,
  answers?: { [key: string]: string }
): Promise<{
  success: boolean
  filledFields: number
  atsSystem: string
  error?: string
  screenshot?: string
  questions?: any[]
  needsUserInput?: boolean
}> {
  try {
    const response = await fetch(`${FLY_PLAYWRIGHT_SERVICE_URL}/automate`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        jobUrl,
        applicationData,
        answers: answers || undefined,
        streamSessionId: request.streamSessionId || undefined // Pass through session ID for streaming
      })
    })
    
    if (!response.ok) {
      const errorText = await response.text()
      throw new Error(`Fly.io service error: ${response.status} - ${errorText}`)
    }
    
    const result = await response.json()
    return result
  } catch (error) {
    console.error('Fly.io service call failed:', error)
    return {
      success: false,
      filledFields: 0,
      atsSystem: 'unknown',
      error: error instanceof Error ? error.message : String(error)
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
    
    if (!FLY_PLAYWRIGHT_SERVICE_URL || FLY_PLAYWRIGHT_SERVICE_URL.includes('your-playwright-service')) {
      return new Response(
        JSON.stringify({ 
          error: 'FLY_PLAYWRIGHT_SERVICE_URL environment variable is not set. Deploy the Fly.io service first.',
          success: false
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`🚀 Starting automated application for: ${request.jobTitle} at ${request.company}`)
    
    const result = await automateWithFlyService(
      request.jobUrl, 
      request.applicationData,
      request.answers
    )
    
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


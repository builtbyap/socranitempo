// Gmail Monitoring Edge Function
// This function periodically checks Gmail for application confirmation emails
// It should be called via a cron job or scheduled task

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const GMAIL_API_BASE = 'https://gmail.googleapis.com/gmail/v1'

interface GmailMessage {
  id: string
  threadId: string
}

interface GmailMessageDetail {
  id: string
  payload: {
    headers: Array<{ name: string; value: string }>
    body?: { data?: string }
    parts?: Array<{ body?: { data?: string }; mimeType?: string }>
  }
  snippet: string
}

interface ApplicationEmail {
  id: string
  from: string
  subject: string
  body: string
  date: string
  isApplicationConfirmation: boolean
}

// Get access token from Supabase (stored after OAuth)
async function getAccessToken(): Promise<string | null> {
  // In production, store the refresh token in Supabase and refresh it here
  // For now, return from environment variable
  const refreshToken = Deno.env.get('GMAIL_REFRESH_TOKEN')
  if (!refreshToken) {
    console.error('❌ GMAIL_REFRESH_TOKEN not set')
    return null
  }

  // Refresh the access token
  const clientId = Deno.env.get('GMAIL_CLIENT_ID')
  const clientSecret = Deno.env.get('GMAIL_CLIENT_SECRET')
  
  if (!clientId || !clientSecret) {
    console.error('❌ Gmail OAuth credentials not configured')
    return null
  }

  try {
    const response = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: clientSecret,
        refresh_token: refreshToken,
        grant_type: 'refresh_token',
      }),
    })

    if (!response.ok) {
      const error = await response.text()
      console.error('❌ Failed to refresh token:', error)
      return null
    }

    const data = await response.json()
    return data.access_token
  } catch (error) {
    console.error('❌ Error refreshing token:', error)
    return null
  }
}

// Search for new emails
async function searchEmails(accessToken: string, query: string): Promise<GmailMessage[]> {
  const encodedQuery = encodeURIComponent(query)
  const url = `${GMAIL_API_BASE}/users/me/messages?q=${encodedQuery}`

  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
    },
  })

  if (!response.ok) {
    throw new Error(`Gmail API error: ${response.status} ${response.statusText}`)
  }

  const data = await response.json()
  return data.messages || []
}

// Get message details
async function getMessageDetails(accessToken: string, messageId: string): Promise<GmailMessageDetail> {
  const url = `${GMAIL_API_BASE}/users/me/messages/${messageId}`

  const response = await fetch(url, {
    headers: {
      'Authorization': `Bearer ${accessToken}`,
    },
  })

  if (!response.ok) {
    throw new Error(`Failed to fetch message: ${response.status}`)
  }

  return await response.json()
}

// Extract email content
function extractEmailContent(message: GmailMessageDetail): ApplicationEmail {
  const headers = message.payload.headers || []
  let from = ''
  let subject = ''
  let date = ''

  for (const header of headers) {
    const name = header.name.toLowerCase()
    if (name === 'from') from = header.value
    if (name === 'subject') subject = header.value
    if (name === 'date') date = header.value
  }

  // Extract body
  let body = ''
  if (message.payload.body?.data) {
    try {
      body = atob(message.payload.body.data.replace(/-/g, '+').replace(/_/g, '/'))
    } catch (e) {
      console.error('Failed to decode body:', e)
    }
  } else if (message.payload.parts) {
    for (const part of message.payload.parts) {
      if (part.mimeType === 'text/plain' && part.body?.data) {
        try {
          body = atob(part.body.data.replace(/-/g, '+').replace(/_/g, '/'))
          break
        } catch (e) {
          console.error('Failed to decode part:', e)
        }
      }
    }
  }

  // Check if it's an application confirmation
  const isApplicationConfirmation = isConfirmationEmail(subject, body)

  return {
    id: message.id,
    from,
    subject,
    body,
    date,
    isApplicationConfirmation,
  }
}

// Detect application confirmation emails
function isConfirmationEmail(subject: string, body: string): boolean {
  const subjectLower = subject.toLowerCase()
  const bodyLower = body.toLowerCase()

  const keywords = [
    'application received',
    'thank you for applying',
    'application submitted',
    'we received your application',
    'application confirmation',
    'your application has been',
    'application status',
    'application update',
    'next steps',
    'interview',
    'screening',
    'application review',
  ]

  for (const keyword of keywords) {
    if (subjectLower.includes(keyword) || bodyLower.includes(keyword)) {
      return true
    }
  }

  return false
}

// Save email to Supabase
async function saveEmailToSupabase(email: ApplicationEmail): Promise<void> {
  const supabaseUrl = Deno.env.get('SUPABASE_URL')
  const supabaseKey = Deno.env.get('SUPABASE_ANON_KEY')

  if (!supabaseUrl || !supabaseKey) {
    throw new Error('Supabase credentials not configured')
  }

  const response = await fetch(`${supabaseUrl}/rest/v1/application_emails`, {
    method: 'POST',
    headers: {
      'apikey': supabaseKey,
      'Authorization': `Bearer ${supabaseKey}`,
      'Content-Type': 'application/json',
      'Prefer': 'return=representation',
    },
    body: JSON.stringify({
      id: email.id,
      from_email: email.from,
      subject: email.subject,
      body: email.body,
      received_date: email.date,
      is_application_confirmation: email.isApplicationConfirmation,
    }),
  })

  if (!response.ok) {
    const error = await response.text()
    throw new Error(`Failed to save email: ${response.status} - ${error}`)
  }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    console.log('📧 Starting Gmail monitoring check...')

    // Get access token
    const accessToken = await getAccessToken()
    if (!accessToken) {
      return new Response(
        JSON.stringify({ error: 'Failed to get Gmail access token. Please authenticate.' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Search for unread emails from last 24 hours
    const query = 'is:unread newer_than:1d'
    const messages = await searchEmails(accessToken, query)

    console.log(`📬 Found ${messages.length} unread emails`)

    const applicationEmails: ApplicationEmail[] = []

    // Process each message
    for (const message of messages.slice(0, 50)) { // Limit to 50 to avoid timeout
      try {
        const messageDetail = await getMessageDetails(accessToken, message.id)
        const email = extractEmailContent(messageDetail)

        if (email.isApplicationConfirmation) {
          applicationEmails.push(email)
          // Save to Supabase
          await saveEmailToSupabase(email)
          console.log(`✅ Found application confirmation: ${email.subject}`)
        }
      } catch (error) {
        console.error(`⚠️ Error processing message ${message.id}:`, error)
        // Continue with next message
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        checked: messages.length,
        found: applicationEmails.length,
        emails: applicationEmails,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Gmail monitoring error:', error)
    return new Response(
      JSON.stringify({
        error: error instanceof Error ? error.message : String(error),
      }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


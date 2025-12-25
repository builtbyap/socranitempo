// Supabase Edge Function: Send Application Email Notification
// Deploy this to: supabase/functions/send-application-email/index.ts

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
    const { to, jobTitle, company, applicantName, applicationId } = await req.json()

    if (!to || !jobTitle || !company) {
      return new Response(
        JSON.stringify({ error: 'Missing required fields' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Use Supabase's built-in email service (Resend integration)
    // Or use a service like SendGrid, Mailgun, etc.
    // For now, we'll use a simple email template
    
    const emailSubject = `Application Confirmation: ${jobTitle} at ${company}`
    const emailBody = `
      <html>
        <body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
          <div style="max-width: 600px; margin: 0 auto; padding: 20px;">
            <h2 style="color: #2563eb;">Application Submitted Successfully</h2>
            
            <p>Dear ${applicantName || 'Applicant'},</p>
            
            <p>Thank you for applying to the <strong>${jobTitle}</strong> position at <strong>${company}</strong>.</p>
            
            <p>Your application has been received and saved. Here are the details:</p>
            
            <div style="background-color: #f3f4f6; padding: 15px; border-radius: 8px; margin: 20px 0;">
              <p style="margin: 5px 0;"><strong>Position:</strong> ${jobTitle}</p>
              <p style="margin: 5px 0;"><strong>Company:</strong> ${company}</p>
              <p style="margin: 5px 0;"><strong>Application ID:</strong> ${applicationId}</p>
              <p style="margin: 5px 0;"><strong>Date:</strong> ${new Date().toLocaleDateString()}</p>
            </div>
            
            <p><strong>Next Steps:</strong></p>
            <ul>
              <li>Your application has been saved in your Applications tab</li>
              <li>You can track the status of your application in the app</li>
              <li>The company may contact you directly if they're interested</li>
            </ul>
            
            <p>Good luck with your application!</p>
            
            <hr style="border: none; border-top: 1px solid #e5e7eb; margin: 30px 0;">
            
            <p style="font-size: 12px; color: #6b7280;">
              This is an automated confirmation email. Please do not reply to this message.
            </p>
          </div>
        </body>
      </html>
    `

    // Option 1: Use Supabase's built-in email (if configured)
    // This requires Supabase Auth email templates or Resend integration
    
    // Option 2: Use a third-party service like SendGrid
    // For now, we'll log and return success
    // In production, integrate with your email service
    
    console.log(`📧 Email notification prepared for ${to}`)
    console.log(`   Subject: ${emailSubject}`)
    console.log(`   Application ID: ${applicationId}`)
    
    // TODO: Integrate with actual email service
    // Example with SendGrid:
    /*
    const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')
    const response = await fetch('https://api.sendgrid.com/v3/mail/send', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${SENDGRID_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        personalizations: [{
          to: [{ email: to }],
          subject: emailSubject,
        }],
        from: { email: 'noreply@yourapp.com' },
        content: [{
          type: 'text/html',
          value: emailBody,
        }],
      }),
    })
    */

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Email notification queued',
        // In production, return actual email service response
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('❌ Error sending email:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})


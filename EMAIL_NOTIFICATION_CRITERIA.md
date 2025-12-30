# Email Notification Criteria

The app sends push notifications for emails that match **application confirmation** keywords. Here's what triggers a notification:

## Detection Criteria

The system checks **both the subject line and email body** for these keywords:

### Confirmation Keywords:
- ✅ "application received"
- ✅ "thank you for applying"
- ✅ "application submitted"
- ✅ "we received your application"
- ✅ "application confirmation"
- ✅ "your application has been"
- ✅ "application status"
- ✅ "application update"
- ✅ "next steps"
- ✅ "interview"
- ✅ "screening"
- ✅ "application review"

## How It Works

1. **Edge Function** (runs every 5 minutes):
   - Checks Gmail for **unread emails from the last 24 hours**
   - Looks for emails matching the keywords above
   - Saves matching emails to the database

2. **iOS App** (checks every 5 minutes):
   - Fetches new emails from the database
   - Sends push notifications for emails you haven't been notified about yet
   - Tracks which emails were notified (no duplicates)

## Examples of Emails That Trigger Notifications

✅ **Will trigger notification:**
- Subject: "Thank you for applying to [Company]"
- Subject: "Application Received - [Position]"
- Subject: "Your application has been received"
- Subject: "Next steps in your application"
- Subject: "Interview invitation for [Position]"
- Body contains: "We received your application and will review it..."

❌ **Won't trigger notification:**
- Regular job postings
- Marketing emails
- Newsletter subscriptions
- General company updates
- Emails without confirmation keywords

## Notification Details

When a matching email is found, you'll receive a push notification with:
- **Title**: "New Application Confirmation"
- **Body**: "[Sender Email]: [Email Subject]"
- **Sound**: Default notification sound
- **Badge**: App badge count increases

## Customization

If you want to add more keywords or change the detection logic:

1. **Edge Function** (`edge-function-gmail-monitor.ts`):
   - Edit the `isConfirmationEmail()` function
   - Add/remove keywords in the `keywords` array

2. **iOS App** (`GmailMonitoringService.swift`):
   - The app uses the same keywords (for consistency)
   - You can update the `confirmationKeywords` array

## Testing

To test if an email triggers a notification:

1. Send an email to `thesocrani@gmail.com` with one of the keywords in the subject or body
2. Wait 5-10 minutes for:
   - Edge Function to check Gmail
   - Email to be saved to database
3. Open your iOS app (or keep it running)
4. Within 5 minutes, you should receive a notification

## Current Settings

- **Check frequency**: Every 5 minutes
- **Email age**: Last 24 hours (unread only)
- **Notification tracking**: Prevents duplicate notifications
- **Email storage**: All matching emails saved to `application_emails` table


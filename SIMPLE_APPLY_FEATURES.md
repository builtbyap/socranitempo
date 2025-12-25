# Simple Apply Features Documentation

This document explains the four advanced features added to the Simple Apply functionality.

## 1. ✅ Resume Upload to Supabase Storage

### What It Does
When a user submits an application, their resume file is automatically uploaded to Supabase Storage and a public URL is generated. This URL is then attached to the application record.

### How It Works
- **Location**: `SupabaseService.swift` → `uploadResumeToStorage()`
- **Storage Bucket**: `resumes` (must be created in Supabase Dashboard)
- **File Path**: `resumes/{userId}/{fileName}`
- **Public URL**: Automatically generated and saved to the application

### Setup Required

1. **Create Storage Bucket in Supabase**:
   - Go to Supabase Dashboard → Storage
   - Create a new bucket named `resumes`
   - Set it to **Public** (or configure RLS policies)
   - Set file size limit (recommended: 10MB)

2. **Storage Policies** (if using RLS):
   ```sql
   -- Allow authenticated users to upload
   CREATE POLICY "Users can upload resumes"
   ON storage.objects FOR INSERT
   TO authenticated
   WITH CHECK (bucket_id = 'resumes');
   
   -- Allow public read access
   CREATE POLICY "Public can read resumes"
   ON storage.objects FOR SELECT
   TO public
   USING (bucket_id = 'resumes');
   ```

### Usage
The upload happens automatically when:
- User submits an application via Simple Apply
- Resume file exists in the app's local storage
- File is successfully uploaded before application is saved

---

## 2. 📧 Email Notifications

### What It Does
Sends a confirmation email to the user when they submit an application.

### How It Works
- **Edge Function**: `send-application-email` (Supabase Edge Function)
- **Trigger**: Called automatically after application is saved
- **Email Content**: Includes job details, application ID, and next steps

### Setup Required

1. **Deploy Edge Function**:
   - Copy `edge-function-send-email.ts` to your Supabase project
   - Deploy to: `supabase/functions/send-application-email/index.ts`
   - Run: `supabase functions deploy send-application-email`

2. **Configure Email Service** (Choose one):

   **Option A: Supabase Auth Email** (Simplest)
   - Uses Supabase's built-in email service
   - Configure in Supabase Dashboard → Authentication → Email Templates
   - Limited customization

   **Option B: SendGrid** (Recommended for production)
   - Sign up at [SendGrid](https://sendgrid.com)
   - Get API key
   - Add to Edge Function secrets: `SENDGRID_API_KEY`
   - Uncomment SendGrid code in `edge-function-send-email.ts`

   **Option C: Resend** (Modern alternative)
   - Sign up at [Resend](https://resend.com)
   - Get API key
   - Add to Edge Function secrets: `RESEND_API_KEY`
   - Integrate Resend SDK in Edge Function

3. **Update Edge Function**:
   ```typescript
   // In edge-function-send-email.ts, uncomment and configure:
   const SENDGRID_API_KEY = Deno.env.get('SENDGRID_API_KEY')
   // ... SendGrid integration code
   ```

### Email Template
The email includes:
- Job title and company
- Application ID
- Application date
- Next steps information
- Professional HTML formatting

---

## 3. 📊 Application Status Tracking

### What It Does
Allows users to track and update the status of their applications through different stages:
- **Applied** → **Viewed** → **Interview** → **Accepted/Rejected**

### How It Works
- **UI**: Tap status badge on any application card
- **Update**: Select new status from modal
- **Storage**: Status saved to Supabase `applications` table
- **Real-time**: Applications list refreshes automatically

### Features
- **Status Options**:
  - 🟦 Applied (Blue)
  - 🟧 Viewed (Orange)
  - 🟪 Interview (Purple)
  - 🟥 Rejected (Red)
  - 🟩 Accepted (Green)

- **Visual Indicators**:
  - Color-coded status badges
  - Icons for each status
  - Easy-to-use update interface

### Usage
1. Go to **Applications** tab
2. Tap the status badge on any application
3. Select new status
4. Status updates automatically

### Database Schema
The `applications` table already has a `status` column:
```sql
status TEXT -- 'applied', 'viewed', 'interview', 'rejected', 'accepted'
```

---

## 4. 📋 Form Auto-Fill Helper

### What It Does
Prepares application data in multiple formats that can be easily copied and pasted into external job application forms.

### How It Works
- **Access**: Tap menu (⋯) in Simple Apply review screen → "Auto-Fill Helper"
- **Formats**: Plain Text, JSON, Browser Extension Format
- **Export**: Copy to clipboard or prepare for browser extensions

### Formats Available

#### 1. Plain Text
- Human-readable format
- Easy to copy-paste into forms
- Includes all information in organized sections

#### 2. JSON
- Structured data format
- Can be imported into form-filling tools
- Includes nested work experience and education

#### 3. Browser Extension Format
- Pre-formatted for common form field names
- Compatible with browser extensions like:
  - **Autofill** (Chrome/Edge)
  - **Form Filler** (Firefox)
  - **LastPass** form fill
  - **1Password** form fill

### Field Mappings
The browser extension format includes common field name variations:
- `name`, `full_name`, `first_name`, `last_name`
- `email`
- `phone`, `phone_number`
- `location`, `city`
- `linkedin`, `linkedin_url`
- `github`, `github_url`
- `portfolio`, `portfolio_url`
- `cover_letter`
- `resume_url`

### Usage
1. In **Simple Apply Review** screen, tap menu (⋯)
2. Select **"Auto-Fill Helper"**
3. Choose export format
4. **Copy to Clipboard** or use with browser extensions
5. Open job application URL in browser
6. Use browser extension or manual paste to fill form

### Browser Extension Setup
1. Install a form-filling extension (e.g., "Autofill" for Chrome)
2. Copy the JSON format from Auto-Fill Helper
3. Import into extension
4. Extension will auto-detect and fill forms

---

## Implementation Details

### Files Created/Modified

1. **SupabaseService.swift**
   - Added `uploadResumeToStorage()`
   - Added `updateApplicationStatus()`

2. **SimpleApplyService.swift**
   - Updated `submitApplication()` to upload resume
   - Added `sendApplicationEmailNotification()`

3. **SimpleApplyReviewView.swift**
   - Added menu with "Auto-Fill Helper" option

4. **ApplicationsView.swift**
   - Updated `ApplicationCard` with status update functionality
   - Added notification listener for status updates

5. **StatusUpdateView.swift** (New)
   - Status update modal interface

6. **FormAutoFillHelper.swift** (New)
   - Form data preparation and export

7. **edge-function-send-email.ts** (New)
   - Email notification Edge Function

---

## Testing Checklist

### Resume Upload
- [ ] Create `resumes` bucket in Supabase Storage
- [ ] Set bucket to public or configure RLS policies
- [ ] Submit application with resume file
- [ ] Verify resume URL is saved in application record
- [ ] Verify resume is accessible via public URL

### Email Notifications
- [ ] Deploy `send-application-email` Edge Function
- [ ] Configure email service (SendGrid/Resend/etc.)
- [ ] Add API key to Edge Function secrets
- [ ] Submit test application
- [ ] Verify email is received

### Status Tracking
- [ ] Submit test application
- [ ] Go to Applications tab
- [ ] Tap status badge
- [ ] Update status
- [ ] Verify status updates in UI
- [ ] Verify status is saved in database

### Form Auto-Fill
- [ ] Open Simple Apply review screen
- [ ] Tap menu → Auto-Fill Helper
- [ ] Test all three formats
- [ ] Copy to clipboard
- [ ] Test with browser extension (optional)

---

## Troubleshooting

### Resume Upload Fails
- **Check**: Storage bucket exists and is accessible
- **Check**: File size is within limits
- **Check**: RLS policies allow uploads
- **Solution**: Verify bucket name is `resumes` (lowercase)

### Email Not Sending
- **Check**: Edge Function is deployed
- **Check**: Email service API key is set
- **Check**: Edge Function logs for errors
- **Solution**: Test Edge Function directly with curl

### Status Not Updating
- **Check**: Application ID is correct
- **Check**: Supabase connection is working
- **Check**: Status value is valid
- **Solution**: Check SupabaseService logs

### Auto-Fill Helper Not Showing
- **Check**: Menu button is visible in review screen
- **Check**: Application data is loaded
- **Solution**: Ensure `applicationData` is not nil

---

## Next Steps (Optional Enhancements)

1. **Resume Upload**:
   - Add progress indicator
   - Support multiple file formats
   - Add resume versioning

2. **Email Notifications**:
   - Add email templates customization
   - Support multiple recipients
   - Add email tracking

3. **Status Tracking**:
   - Add status change history
   - Add notes/comments per status
   - Add reminders for follow-ups

4. **Form Auto-Fill**:
   - Direct browser integration (WKWebView)
   - Auto-detect form fields
   - Save form templates

---

## Support

For issues or questions:
1. Check Supabase logs: Dashboard → Logs → Edge Functions
2. Check app console logs for errors
3. Verify all setup steps are completed
4. Test each feature individually


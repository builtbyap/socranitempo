# Deployment Steps for Question Detection Feature

## ✅ What's Been Implemented

The question detection feature is complete in your code. Now you need to deploy the updated services.

## 🚀 Step-by-Step Deployment

### Step 1: Deploy Updated Fly.io Playwright Service

1. **Navigate to the service directory**:
   ```bash
   cd fly-playwright-service
   ```

2. **Deploy to Fly.io**:
   ```bash
   flyctl deploy
   ```

   This will:
   - Build the Docker image with question detection
   - Deploy to your Fly.io app (`surgeapp-playwright`)
   - Make the service available at `https://surgeapp-playwright.fly.dev`

3. **Verify deployment**:
   ```bash
   flyctl status
   ```

### Step 2: Deploy Updated Supabase Edge Function

1. **Go to Supabase Dashboard**:
   - Visit: https://supabase.com/dashboard
   - Select your project

2. **Navigate to Edge Functions**:
   - Click **"Edge Functions"** in the left sidebar
   - Find the `auto-apply` function (or create it if it doesn't exist)

3. **Update the function**:
   - Click **"Edit"** or **"Create a new function"**
   - Copy the contents of `edge-function-auto-apply-fly.ts`
   - Paste into the editor
   - Click **"Deploy"**

4. **Verify environment variable**:
   - Go to **Project Settings** → **Edge Functions** → **Environment Variables**
   - Ensure `FLY_PLAYWRIGHT_SERVICE_URL` is set to: `https://surgeapp-playwright.fly.dev`
   - If not set, add it now

### Step 3: Update Database Schema (if needed)

The `Application` model now includes:
- `job_url` (String, nullable)
- `pending_questions` (JSON, nullable)

If your Supabase table doesn't have these columns:

1. **Go to Supabase Dashboard** → **SQL Editor**
2. **Run this SQL**:
   ```sql
   -- Add job_url column if it doesn't exist
   ALTER TABLE applications 
   ADD COLUMN IF NOT EXISTS job_url TEXT;

   -- Add pending_questions column if it doesn't exist
   ALTER TABLE applications 
   ADD COLUMN IF NOT EXISTS pending_questions JSONB;
   ```

### Step 4: Test the Feature

1. **Build and run your iOS app**:
   ```bash
   # In Xcode, build and run the app
   ```

2. **Test the flow**:
   - Find a job posting with a URL
   - Tap **"Simple Apply"**
   - If the job has questions, you should see:
     - Progress screen showing automation
     - If questions detected: Error message saying "X question(s) need to be answered"
   - Go to **Applications** tab
   - You should see:
     - Badge with question count
     - Orange card showing pending questions
   - Tap **"Answer"** button
   - Answer the questions
   - Submit answers
   - Application should complete automatically

## 🔍 Troubleshooting

### If questions aren't detected:

1. **Check Fly.io logs**:
   ```bash
   flyctl logs
   ```
   Look for: `❓ Found X questions`

2. **Check Supabase Edge Function logs**:
   - Go to Supabase Dashboard → Edge Functions → `auto-apply` → Logs
   - Look for errors or question detection messages

3. **Check iOS app console**:
   - Look for: `⚠️ Questions detected - returning for user to answer`

### If answers aren't being filled:

1. **Verify answers are being sent**:
   - Check iOS console for: `🔄 Resuming application with answers`
   - Check Fly.io logs for: `📝 Filling user-provided answers...`

2. **Check question index mapping**:
   - Questions use `index` field to map to form fields
   - Ensure the index matches the form field position

### If badge doesn't appear:

1. **Check application status**:
   - Application should have status `"pending_questions"`
   - Check Supabase database: `SELECT * FROM applications WHERE status = 'pending_questions'`

2. **Refresh Applications view**:
   - Pull down to refresh
   - Or restart the app

## 📋 Quick Checklist

- [ ] Fly.io service deployed (`flyctl deploy`)
- [ ] Supabase Edge Function updated
- [ ] Environment variable `FLY_PLAYWRIGHT_SERVICE_URL` set
- [ ] Database columns added (if needed)
- [ ] iOS app built and running
- [ ] Tested with a real job application
- [ ] Questions detected and shown
- [ ] Answers submitted successfully
- [ ] Application completed automatically

## 🎉 Success Indicators

You'll know it's working when:
- ✅ Badge appears on Applications tab
- ✅ Orange "Pending Questions" card shows
- ✅ Question view opens when tapping "Answer"
- ✅ Answers are submitted successfully
- ✅ Application status changes to "applied" after answers

## 📞 Need Help?

If you encounter issues:
1. Check the logs (Fly.io and Supabase)
2. Verify all services are deployed
3. Test with a simple job application first
4. Check that the job URL is valid and accessible

Good luck! 🚀


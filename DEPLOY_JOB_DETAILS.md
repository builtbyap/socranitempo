# Deploy Job Details Edge Function

The 404 error means the `job-details` function isn't deployed yet. Follow these steps:

## Step 1: Go to Supabase Dashboard

1. Go to [Supabase Dashboard](https://supabase.com/dashboard)
2. Select your project (`jlkebdnvjjdwedmbfqou`)

## Step 2: Navigate to Edge Functions

1. Click **"Edge Functions"** in the left sidebar
2. You should see a list of your functions

## Step 3: Create New Function

1. Click **"Create a new function"** button (usually top right)
2. Choose **"Via Editor"** (easiest option)
3. Name it: `job-details` (exactly this, lowercase with hyphen)
4. Click **"Create"** or **"Continue"**

## Step 4: Paste the Code

1. The editor will open with some default code
2. **Select ALL** the default code (Cmd+A or Ctrl+A)
3. **Delete it**
4. **Open** `edge-function-job-details.ts` from your project
5. **Copy ALL** the code from that file
6. **Paste** it into the Supabase editor

## Step 5: Deploy

1. Click **"Deploy"** button (usually top right)
2. Wait for deployment (you'll see a loading indicator)
3. When it says "Deployed" or shows a success message, you're done!

## Step 6: Verify the Function URL

After deployment, you'll see the function URL:
```
https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/job-details
```

This URL should match what's in `JobDetailsService.swift` (it uses `Config.supabaseURL` + `/functions/v1/job-details`).

## Step 7: Test the Function

Test it works:

1. In Supabase Dashboard → Edge Functions → job-details
2. Click **"Invoke function"**
3. In the request body, paste:
   ```json
   {
     "jobUrl": "https://example.com/job/123"
   }
   ```
4. Click **"Invoke"**
5. Check the **Response** tab

**Expected response:**
```json
{
  "sections": [
    {
      "id": "section_0_1234567890",
      "title": "What you'll do",
      "content": "Job responsibilities content..."
    }
  ]
}
```

## Troubleshooting

### Still getting 404?
- Make sure the function name is exactly `job-details` (lowercase, with hyphen)
- Check that it's deployed (should show "Active" status)
- Try refreshing the app after deployment

### Getting timeout errors?
- Some job URLs may be slow to respond
- The function has a 10-second timeout per request
- This is normal for some job sites

### No sections found?
- Some job sites don't have structured sections
- The function will return an empty array `[]` if no sections are found
- This is expected behavior


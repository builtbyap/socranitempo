# Where to Paste the Edge Function Code in Supabase

## Step-by-Step Instructions

### Step 1: Go to Supabase Dashboard
1. Open your browser
2. Go to: https://supabase.com/dashboard
3. Log in if needed
4. Select your project (the one with ID: `jlkebdnvjjdwedmbfqou`)

### Step 2: Navigate to Edge Functions
1. In the left sidebar, look for **"Edge Functions"**
2. Click on **"Edge Functions"**
   - If you don't see it, it might be under "Project Settings" or in the main menu
   - It should be in the left navigation menu

### Step 3: Create a New Function
1. Click the **"Create a new function"** button (usually at the top right)
2. You'll see three options:
   - **Via Editor** ← Choose this one
   - Via CLI
   - Via AI Assistant
3. Click **"Via Editor"**

### Step 4: Name Your Function
1. A dialog or form will appear
2. Enter the function name: `scrape-jobs`
   - Make sure it's exactly: `scrape-jobs` (lowercase, with a hyphen)
3. Click **"Create"** or **"Continue"**

### Step 5: The Code Editor Appears
1. You'll see a code editor in the browser
2. It will have some default/template code that looks like:
   ```typescript
   import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
   
   serve(async (req) => {
     // ... some default code
   })
   ```

### Step 6: Replace All the Code
1. **Select ALL the existing code** in the editor:
   - Click in the editor
   - Press `Cmd+A` (Mac) or `Ctrl+A` (Windows) to select all
   - Or triple-click to select all
2. **Delete it** (press Delete or Backspace)
3. **Paste the new code** I provided:
   - Press `Cmd+V` (Mac) or `Ctrl+V` (Windows)
   - Or right-click and select "Paste"

### Step 7: Deploy
1. Look for a **"Deploy"** button (usually at the top right of the editor)
2. Click **"Deploy"**
3. Wait for it to deploy (you'll see a loading indicator)
4. When it says "Deployed" or "Success", you're done!

### Step 8: Copy the Function URL
1. After deployment, you'll see the function URL
2. It will look like:
   ```
   https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/scrape-jobs
   ```
3. **Copy this URL** (select it and copy)

### Step 9: Update Config.swift
1. Open your Xcode project
2. Open the file: `surgeapp/Config.swift`
3. Find line 22 that says:
   ```swift
   static let jobScrapingBackendURL = "https://your-backend-api.com/api/jobs"
   ```
4. Replace it with your function URL:
   ```swift
   static let jobScrapingBackendURL = "https://jlkebdnvjjdwedmbfqou.supabase.co/functions/v1/scrape-jobs"
   ```
   (Use the actual URL you copied)

## Visual Guide

```
Supabase Dashboard
├── Left Sidebar
│   ├── Table Editor
│   ├── Authentication
│   ├── Storage
│   ├── Edge Functions  ← Click here
│   └── ...
│
Edge Functions Page
├── Top Right: "Create a new function" button ← Click
│
Create Function Dialog
├── Option 1: Via Editor ← Choose this
├── Option 2: Via CLI
└── Option 3: Via AI Assistant
│
Function Name Input
├── Enter: scrape-jobs
└── Click: "Create"
│
Code Editor Opens
├── Default template code appears
├── Select All (Cmd+A / Ctrl+A)
├── Delete
├── Paste your code (Cmd+V / Ctrl+V)
└── Click: "Deploy" button
│
Deployment Success
├── Function URL appears
└── Copy the URL
```

## Troubleshooting

### Can't find "Edge Functions" in the sidebar?
- It might be under "Project Settings" → "Edge Functions"
- Or look for "Functions" (without "Edge")
- Make sure you're in the correct project

### The editor doesn't appear?
- Make sure you selected "Via Editor" (not CLI or AI)
- Try refreshing the page
- Check if you have the right permissions

### Code won't paste?
- Make sure you selected all the existing code first
- Try right-clicking in the editor and selecting "Paste"
- Or try `Cmd+Shift+V` (Mac) or `Ctrl+Shift+V` (Windows) for paste without formatting

### Deploy button is grayed out?
- Make sure you pasted valid code
- Check for syntax errors (red underlines)
- The code should be valid TypeScript

### Can't find the function URL after deployment?
- Look at the top of the function page
- It should show the URL in the function details
- Or click on the function name to see its details

## Quick Checklist

- [ ] Logged into Supabase Dashboard
- [ ] Selected correct project
- [ ] Clicked "Edge Functions" in sidebar
- [ ] Clicked "Create a new function"
- [ ] Selected "Via Editor"
- [ ] Named function: `scrape-jobs`
- [ ] Selected all default code and deleted it
- [ ] Pasted the new code I provided
- [ ] Clicked "Deploy"
- [ ] Copied the function URL
- [ ] Updated Config.swift with the URL

## Need Help?

If you're stuck at any step, let me know which step you're on and I can help you navigate!


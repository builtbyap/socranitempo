# Surge App - Job Search iOS Application

A modern iOS app for job searching with swipe-to-apply functionality, inspired by source.jobs.

## Features

- 🔍 **Job Search**: Search and browse job postings from LinkedIn
- 👆 **Swipe-to-Apply**: Swipe right to apply, left to pass on job cards
- 📋 **Application Tracking**: Track your applications with status updates
- 💼 **LinkedIn Profile Search**: Find LinkedIn profiles by position and company
- 📧 **Email Search**: Find email contacts using Hunter.io
- 📄 **Resume Upload**: Upload and manage your resume

## Setup Instructions

### 1. Clone the Repository

```bash
git clone https://github.com/builtbyap/socranitempo.git
cd surgeapp
```

### 2. Configure API Keys

**IMPORTANT**: API keys are stored in `surgeapp/Config.swift` which is gitignored for security.

1. Copy the example config file:
   ```bash
   cp Config.example.swift surgeapp/Config.swift
   ```

2. Open `surgeapp/Config.swift` and add your API keys:
   ```swift
   struct Config {
       static let supabaseURL = "YOUR_SUPABASE_URL"
       static let supabaseKey = "YOUR_SUPABASE_ANON_KEY"
       static let apifyToken = "YOUR_APIFY_API_TOKEN"
       static let hunterApiKey = "YOUR_HUNTER_API_KEY"
       static let serpApiKey = "YOUR_SERPAPI_KEY"
   }
   ```

### 3. Set Up Supabase Database

Run the SQL scripts in your Supabase SQL Editor:

1. **Create applications table**: Run `supabase_applications_setup.sql`
2. **Ensure RLS policies exist**: Run `supabase/migrations/add_insert_policies.sql` (if needed)

### 4. Build and Run

1. Open `surgeapp.xcodeproj` in Xcode
2. Select your target device/simulator
3. Build and run (⌘R)

## API Keys Required

- **Supabase**: Get your URL and anon key from [Supabase Dashboard](https://supabase.com/dashboard)
- **Apify**: Get your API token from [Apify Console](https://console.apify.com/)
- **Hunter.io**: Get your API key from [Hunter.io](https://hunter.io/)
- **SerpAPI**: Get your API key from [SerpAPI](https://serpapi.com/)

## Security Note

⚠️ **Never commit `Config.swift` to GitHub**. It's already in `.gitignore`, but always double-check before committing.

## Project Structure

```
surgeapp/
├── Models.swift              # Data models
├── SupabaseService.swift     # Supabase integration
├── ApifyService.swift        # Apify API integration
├── HunterService.swift       # Hunter.io integration
├── SerpAPIService.swift      # SerpAPI integration
├── JobSearchView.swift       # Main job search view
├── ApplicationsView.swift   # Application tracking view
├── SwipeableJobCardView.swift # Swipeable card component
├── ResumeUploadView.swift    # Resume upload view
└── Config.swift              # API keys (gitignored)
```

## License

[Your License Here]


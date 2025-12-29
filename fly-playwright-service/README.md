# Playwright Automation Service for Fly.io

This is a Node.js service that runs Playwright for automated job applications. It's designed to be deployed on Fly.io and called from Supabase Edge Functions.

## Quick Start

1. **Install Fly.io CLI**:
   ```bash
   brew install flyctl
   ```

2. **Login**:
   ```bash
   flyctl auth login
   ```

3. **Deploy**:
   ```bash
   flyctl launch
   flyctl deploy
   ```

4. **Get your URL**:
   ```bash
   flyctl status
   ```

5. **Add URL to Supabase**:
   - Go to Supabase Dashboard → Edge Functions → Environment Variables
   - Add: `FLY_PLAYWRIGHT_SERVICE_URL` = `https://your-app.fly.dev`

## API Endpoints

### `GET /health`
Health check endpoint.

**Response**:
```json
{
  "status": "ok",
  "service": "playwright-automation"
}
```

### `POST /automate`
Automate a job application.

**Request Body**:
```json
{
  "jobUrl": "https://example.com/job/apply",
  "applicationData": {
    "fullName": "John Doe",
    "email": "john@example.com",
    "phone": "555-1234",
    "coverLetter": "I am interested...",
    "resumeUrl": "https://..."
  }
}
```

**Response**:
```json
{
  "success": true,
  "filledFields": 8,
  "atsSystem": "greenhouse",
  "screenshot": "base64-encoded-screenshot"
}
```

## Local Development

1. **Install dependencies**:
   ```bash
   npm install
   ```

2. **Run locally**:
   ```bash
   npm start
   ```

3. **Test**:
   ```bash
   curl http://localhost:3000/health
   ```

## Files

- `server.js` - Main Express server with Playwright automation
- `package.json` - Node.js dependencies
- `Dockerfile` - Docker configuration for Fly.io
- `fly.toml` - Fly.io deployment configuration

## See Also

- `../FLY_IO_PLAYWRIGHT_SETUP.md` - Full setup guide
- `../edge-function-auto-apply-fly.ts` - Supabase Edge Function that calls this service


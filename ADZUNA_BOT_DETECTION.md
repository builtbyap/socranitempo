# Handling Adzuna Bot Detection

## Problem

Adzuna has strict bot detection that blocks automated access from Playwright. When you try to apply to a job from Adzuna, you'll see a page saying:

> "Our systems have detected suspicious behaviour associated with this request."

## What We've Done

### 1. **Enhanced Stealth Configuration**

The Playwright service now includes:
- **Better browser fingerprinting**: Removes automation flags, adds realistic headers
- **Stealth scripts**: Hides `navigator.webdriver`, overrides plugins, adds chrome runtime
- **Realistic browser context**: Proper viewport, locale, timezone, geolocation
- **Extra HTTP headers**: Makes requests look more like a real browser

### 2. **Bot Detection Detection**

The service now detects when Adzuna (or other sites) show a bot detection page:
- Checks for keywords: "suspicious behaviour", "unusual behaviour", "detected"
- Returns a specific error message
- Captures a screenshot for verification
- Sets `botDetected: true` in the response

### 3. **Better Error Handling**

The iOS app now:
- Shows a clear error message when bot detection is encountered
- Displays the screenshot so you can see what happened
- Provides guidance on what to do next

## What You'll See

When bot detection is encountered:

1. **Error Screen** with:
   - Red warning icon
   - "Application Failed" message
   - Specific error: "Bot detection: This job board (Adzuna) has detected automated access. Please apply manually through the website."
   - Screenshot showing the bot detection page
   - Helpful tip: "This job board has detected automated access. You'll need to apply manually by opening the job URL in your browser."

## Solutions

### Option 1: Apply Manually (Recommended)

Since Adzuna blocks automation, the best approach is to apply manually:

1. Copy the job URL from the app
2. Open it in your browser
3. Fill out the application form manually
4. Submit the application

### Option 2: Use WKWebView Instead

For Adzuna jobs specifically, you could:
1. Detect Adzuna URLs in the app
2. Open them in WKWebView instead of Playwright
3. Let users fill and submit manually within the app

### Option 3: Skip Adzuna Jobs for Auto-Apply

You could filter out Adzuna jobs from auto-apply:
- Only auto-apply to direct company career pages
- Skip job boards like Adzuna, Indeed, etc.

## Technical Details

### Stealth Techniques Used

```javascript
// Remove webdriver property
Object.defineProperty(navigator, 'webdriver', {
  get: () => false,
});

// Override plugins
Object.defineProperty(navigator, 'plugins', {
  get: () => [1, 2, 3, 4, 5],
});

// Add chrome runtime
window.chrome = { runtime: {} };
```

### Browser Launch Args

```javascript
args: [
  '--no-sandbox',
  '--disable-setuid-sandbox',
  '--disable-dev-shm-usage',
  '--disable-blink-features=AutomationControlled', // Hide automation flags
  '--disable-features=IsolateOrigins,site-per-process',
  '--disable-web-security',
  '--disable-features=VizDisplayCompositor'
]
```

### HTTP Headers

```javascript
extraHTTPHeaders: {
  'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  'Accept-Language': 'en-US,en;q=0.9',
  'Accept-Encoding': 'gzip, deflate, br',
  'DNT': '1',
  'Connection': 'keep-alive',
  'Upgrade-Insecure-Requests': '1',
  'Sec-Fetch-Dest': 'document',
  'Sec-Fetch-Mode': 'navigate',
  'Sec-Fetch-Site': 'none',
  'Sec-Fetch-User': '?1',
  'Cache-Control': 'max-age=0'
}
```

## Why Adzuna Blocks Automation

Adzuna uses advanced bot detection that checks:
- Browser fingerprinting
- Behavioral patterns (mouse movements, typing speed, etc.)
- IP reputation
- Request headers
- JavaScript execution patterns

Even with stealth techniques, sophisticated bot detection can still identify automation.

## Recommendations

1. **For Adzuna jobs**: Apply manually or use WKWebView
2. **For other job boards**: Test if they also block automation
3. **For company career pages**: These usually work better with automation (Workday, Greenhouse, Lever)
4. **Monitor success rate**: Track which sources work best with automation

## Future Improvements

Possible enhancements:
1. **Proxy rotation**: Use different IPs to avoid detection
2. **Residential proxies**: More expensive but harder to detect
3. **Browser fingerprint rotation**: Change fingerprints between requests
4. **Human-like delays**: Add random delays to mimic human behavior
5. **CAPTCHA solving**: Integrate CAPTCHA solving services (costs money)

However, these add complexity and cost. For most users, manual application for job board listings is the most reliable approach.


# Human-Assisted Apply Design

## Philosophy

**Simple Apply** is redesigned as a slow, visible, user-assisted browser interaction that stays within expected human behavior patterns. We focus on product design, not evasion.

## Core Principles

### 1. Keep Users in the Loop
- Users see every action happening in real-time
- Users can pause, resume, or take over at any time
- Clear status indicators show what's happening
- No "black box" automation

### 2. Avoid Bulk Automation
- One application at a time
- Human-like delays between actions (1-3 seconds)
- Character-by-character typing (100-200ms per character)
- Natural pauses and scrolling

### 3. Treat Job Boards as UIs, Not APIs
- Use actual browser (WKWebView)
- Interact with forms as a human would
- Scroll to fields before filling
- Focus fields visibly
- Respect page structure

### 4. Stop When Friction Appears
- Detect CAPTCHAs → Stop and alert user
- Detect login requirements → Stop and alert user
- Detect bot detection → Stop and alert user
- Detect unusual fields → Stop and let user handle
- Never try to bypass security measures

## User Experience Flow

### Step 1: Initiate
User taps "Simple Apply" → Shows `HumanAssistedApplyView`

### Step 2: Loading
- WebView loads the job application page
- Status: "Loading page..."
- User sees the page loading naturally

### Step 3: Analyzing
- Assistant analyzes form structure
- Status: "Analyzing form..."
- Takes 1-2 seconds (visible delay)

### Step 4: Filling (The Main Experience)
- Fields are filled one by one
- Status: "Filling form..." with progress bar
- Each field:
  1. Scrolls into view (smooth animation)
  2. Focuses the field (visible highlight)
  3. Types character by character (100-200ms per char)
  4. Waits 1-3 seconds before next field
- User sees exactly what's being filled
- User can pause at any time

### Step 5: Review
- Status: "Ready for review"
- User can scroll through filled form
- User can edit any field manually
- User clicks "Submit Application"

### Step 6: Friction Handling
If friction is detected:
- Process stops immediately
- Alert explains what happened
- User can:
  - Continue manually
  - Try again (if appropriate)
  - Cancel

## Visual Design

### Status Bar
- Always visible at top
- Shows current step
- Progress bar during filling
- Field count indicator

### WebView
- Full-screen browser view
- User can scroll and interact
- Fields highlight when being filled
- Smooth animations

### Control Panel
- Pause/Resume button
- Filled fields badges
- Submit button (when ready)

### Pause Menu
- Resume automation
- Continue manually
- Cancel
- View filled fields list

## Technical Implementation

### FormAssistant Class
- Manages form filling logic
- Handles JavaScript injection
- Tracks progress
- Detects friction

### WebViewContainer
- WKWebView wrapper
- Navigation delegate
- Friction detection
- Real-time monitoring

### Human-Like Behavior
- **Typing**: 100-200ms per character (randomized)
- **Field delays**: 1-3 seconds between fields
- **Scrolling**: Smooth, centered on field
- **Focusing**: Visible highlight
- **Pauses**: Natural breaks

## Friction Detection

### CAPTCHA
- Detects reCAPTCHA, hCaptcha iframes
- Stops immediately
- Alerts user to complete manually

### Login Required
- Detects password fields
- Detects "sign in" text
- Stops and alerts user

### Bot Detection
- Detects bot detection messages
- Stops immediately
- Alerts user to apply manually

### Unusual Fields
- Fields that can't be auto-filled
- Stops and lets user handle
- Marks as "action required"

## Benefits

1. **Transparency**: User sees everything
2. **Control**: User can intervene anytime
3. **Natural**: Follows human patterns
4. **Respectful**: Stops at security measures
5. **Reliable**: Less likely to be flagged
6. **Trustworthy**: No "magic" happening

## Comparison to Automated Approach

| Aspect | Automated (Playwright) | Human-Assisted |
|--------|----------------------|----------------|
| Speed | Fast (seconds) | Slow (minutes) |
| Visibility | Hidden | Visible |
| User Control | None | Full |
| Friction Handling | Tries to bypass | Stops and alerts |
| Bot Detection Risk | High | Low |
| User Trust | Low | High |

## When to Use Each

- **Automated (Playwright)**: Bulk applications, user trusts automation
- **Human-Assisted**: Quality over quantity, user wants control, avoiding detection


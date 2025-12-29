# Question Detection Feature (Like sorce.jobs)

## ✅ Implementation Complete

I've implemented a feature that detects questions during automated job applications and notifies users in the Applications section, just like sorce.jobs does.

## 🎯 How It Works

### 1. **Question Detection During Automation**

When Playwright automates a job application:
- Fills all standard fields (name, email, phone, etc.)
- Uploads resume
- **Detects questions** that need user input
- Returns questions to the iOS app

### 2. **User Notification**

If questions are detected:
- Application is saved with status `"pending_questions"`
- **Notification badge** appears on Applications tab showing count
- **Special card** appears at top of Applications list
- User can tap "Answer" to respond

### 3. **Answer Questions**

User experience:
- Opens question view with progress indicator
- Shows one question at a time
- Supports:
  - Text inputs
  - Text areas
  - Dropdowns/selects
- Validates required questions
- Shows progress: "Question 1 of 3"

### 4. **Resume Automation**

After user answers:
- Answers are sent back to Playwright service
- Playwright fills the answers into the form
- Application is completed automatically
- Status updated to `"applied"`

## 📁 Files Created/Modified

### New Files:
- `surgeapp/PendingQuestionsCard.swift` - Card showing applications with pending questions
- `surgeapp/QuestionAnswerView.swift` - View for answering questions

### Modified Files:
- `surgeapp/Models.swift` - Added `PendingQuestion` model and updated `Application` model
- `surgeapp/AutoApplyService.swift` - Added `resumeApplicationWithAnswers()` method
- `surgeapp/AutoApplyProgressView.swift` - Handles questions in response
- `surgeapp/ApplicationsView.swift` - Shows pending questions cards and badge
- `surgeapp/SimpleApplyService.swift` - Added `submitApplicationWithQuestions()` method
- `fly-playwright-service/server.js` - Added `detectQuestions()` and `fillAnswers()` functions
- `edge-function-auto-apply-fly.ts` - Passes answers to Playwright service

## 🔄 Flow Diagram

```
User Taps "Simple Apply"
         ↓
Playwright Automates Application
         ↓
Questions Detected?
    ↓              ↓
   NO              YES
    ↓              ↓
Success      Save as "pending_questions"
              Show notification badge
              Show pending card
         ↓
User Taps "Answer"
         ↓
Question View Opens
         ↓
User Answers All Questions
         ↓
Submit Answers
         ↓
Playwright Resumes Automation
         ↓
Application Completed
         ↓
Status Updated to "applied"
```

## 🎨 UI Features

### Applications View:
- **Badge**: Shows count of pending questions
- **Pending Questions Card**: 
  - Orange highlight
  - Shows job title and company
  - Shows question count
  - "Answer" button

### Question Answer View:
- Progress indicator
- Job info at top
- Question text
- Input field (text/textarea/dropdown)
- Required indicator
- Previous/Next navigation
- Submit button on last question

## 📊 Database Schema

The `Application` model now includes:
- `jobUrl: String?` - Store job URL for resuming
- `pendingQuestions: [PendingQuestion]?` - Store questions as JSON
- `status: String` - Can be `"pending_questions"`

## 🚀 Next Steps

1. **Deploy Updated Fly.io Service**:
   ```bash
   cd fly-playwright-service
   flyctl deploy
   ```

2. **Deploy Updated Edge Function**:
   - Go to Supabase Dashboard
   - Update `auto-apply` function with new code

3. **Test**:
   - Apply to a job with questions
   - Verify notification appears
   - Answer questions
   - Verify application completes

## ✨ Key Features

- ✅ **Automatic Detection**: Playwright detects questions automatically
- ✅ **User-Friendly UI**: Clean interface for answering questions
- ✅ **Progress Tracking**: Shows progress through questions
- ✅ **Validation**: Ensures required questions are answered
- ✅ **Resume Automation**: Automatically completes application after answers
- ✅ **Notifications**: Badge and cards show pending questions
- ✅ **Like sorce.jobs**: Same user experience as sorce.jobs

## 🎉 Result

Your app now handles questions exactly like sorce.jobs:
- Detects questions automatically
- Notifies users in Applications section
- Allows users to answer questions
- Automatically completes application after answers


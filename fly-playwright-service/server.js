// Fly.io Playwright Service
// This Node.js service runs Playwright and can be called from Supabase Edge Functions

const express = require('express');
const { chromium } = require('playwright');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'playwright-automation' });
});

// Main automation endpoint
app.post('/automate', async (req, res) => {
  // Set timeout for the response (45 seconds max)
  req.setTimeout(45000);
  res.setTimeout(45000);
  
  let browser = null;
  let page = null;
  
  try {
    const { jobUrl, applicationData, answers } = req.body;
    
    if (!jobUrl || !applicationData) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: jobUrl and applicationData' 
      });
    }
    
    console.log(`🚀 Starting automation for: ${jobUrl}`);
    
    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });
    
    const context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1280, height: 720 }
    });
    
    page = await context.newPage();
    
    console.log(`🌐 Navigating to: ${jobUrl}`);
    await page.goto(jobUrl, { waitUntil: 'domcontentloaded', timeout: 20000 });
    
    // Detect ATS system
    const pageContent = await page.content();
    const atsSystem = detectATSSystem(jobUrl, pageContent);
    console.log(`🔍 Detected ATS: ${atsSystem}`);
    
    // Wait for dynamic content (reduced timeout)
    await page.waitForTimeout(1000);
    
    // Fill form fields
    console.log('📝 Filling application form...');
    const filledFields = await fillApplicationForm(page, applicationData);
    console.log(`✅ Filled ${filledFields} fields`);
    
    // Upload resume if provided
    let resumeUploaded = false;
    if (applicationData.resumeUrl || applicationData.resumeBase64) {
      console.log('📄 Uploading resume...');
      resumeUploaded = await uploadResume(page, applicationData);
    }
    
    // Fill answers if provided (resuming after user answered questions)
    if (answers && Object.keys(answers).length > 0) {
      console.log('📝 Filling user-provided answers...');
      const answersFilled = await fillAnswers(page, answers);
      console.log(`✅ Filled ${answersFilled} answers`);
    }
    
    // Detect questions that need user input (only if no answers provided)
    let questions = [];
    if (!answers || Object.keys(answers).length === 0) {
      console.log('❓ Detecting questions...');
      questions = await detectQuestions(page);
      console.log(`❓ Found ${questions.length} questions`);
      
      // If there are questions, return them for user to answer
      if (questions.length > 0) {
        console.log('⚠️ Questions detected - returning for user to answer');
        const screenshot = await page.screenshot({ encoding: 'base64' });
        
        await browser.close();
        browser = null;
        
        res.json({
          success: false,
          filledFields: filledFields + (resumeUploaded ? 1 : 0),
          atsSystem,
          screenshot: screenshot.toString('base64'),
          questions: questions,
          needsUserInput: true,
          error: `${questions.length} question(s) need to be answered`
        });
        return;
      }
    }
    
    // Attempt to submit the form
    console.log('📤 Attempting to submit application...');
    let submitted = false;
    try {
      // Try to find and click submit button
      const submitSelectors = [
        'button[type="submit"]',
        'input[type="submit"]',
        'button:has-text("Submit")',
        'button:has-text("Apply")',
        'button:has-text("Send")',
        'button[id*="submit"]',
        'button[id*="apply"]',
        'button[class*="submit"]',
        'button[class*="apply"]',
        '[data-testid*="submit"]',
        '[data-testid*="apply"]'
      ];
      
      for (const selector of submitSelectors) {
        try {
          const submitButton = await page.$(selector);
          if (submitButton) {
            console.log(`🔘 Found submit button: ${selector}`);
            await submitButton.click();
            await page.waitForTimeout(2000); // Wait for submission
            submitted = true;
            console.log('✅ Form submitted successfully');
            break;
          }
        } catch (e) {
          continue;
        }
      }
      
      // If no submit button found, try form submission
      if (!submitted) {
        try {
          const form = await page.$('form');
          if (form) {
            await form.evaluate(f => f.submit());
            await page.waitForTimeout(2000);
            submitted = true;
            console.log('✅ Form submitted via form.submit()');
          }
        } catch (e) {
          console.log('⚠️ Could not submit form automatically');
        }
      }
    } catch (error) {
      console.log('⚠️ Form submission error:', error.message);
    }
    
    // Take screenshot
    const screenshot = await page.screenshot({ encoding: 'base64' });
    
    console.log(`✅ Automation completed - Filled: ${filledFields + (resumeUploaded ? 1 : 0)} fields, Submitted: ${submitted}`);
    
    res.json({
      success: true,
      filledFields: filledFields + (resumeUploaded ? 1 : 0),
      atsSystem,
      screenshot: screenshot.toString('base64'),
      questions: [],
      needsUserInput: false,
      submitted: submitted
    });
  } catch (error) {
    console.error('❌ Automation failed:', error);
    
    let screenshot = null;
    try {
      if (page) {
        screenshot = await page.screenshot({ encoding: 'base64' });
      }
    } catch (screenshotError) {
      console.error('Failed to take screenshot:', screenshotError);
    }
    
    if (browser) {
      try {
        await browser.close();
      } catch (closeError) {
        console.error('Failed to close browser:', closeError);
      }
    }
    
    res.status(500).json({
      success: false,
      filledFields: 0,
      atsSystem: 'unknown',
      error: error.message || String(error),
      screenshot: screenshot ? screenshot.toString('base64') : undefined
    });
  }
});

// Detect ATS system
function detectATSSystem(url, pageContent = '') {
  const urlLower = url.toLowerCase();
  const content = (pageContent || '').toLowerCase();
  
  if (urlLower.includes('workday') || urlLower.includes('myworkdayjobs') || content.includes('workday')) {
    return 'workday';
  } else if (urlLower.includes('greenhouse') || urlLower.includes('boards.greenhouse.io') || content.includes('greenhouse')) {
    return 'greenhouse';
  } else if (urlLower.includes('lever') || urlLower.includes('lever.co') || content.includes('lever')) {
    return 'lever';
  } else if (urlLower.includes('smartrecruiters') || content.includes('smartrecruiters')) {
    return 'smartrecruiters';
  } else if (urlLower.includes('jobvite') || content.includes('jobvite')) {
    return 'jobvite';
  } else if (urlLower.includes('icims') || content.includes('icims')) {
    return 'icims';
  } else if (urlLower.includes('taleo') || content.includes('taleo')) {
    return 'taleo';
  } else if (urlLower.includes('bamboohr') || content.includes('bamboohr')) {
    return 'bamboohr';
  }
  
  return 'unknown';
}

// Fill form field helper
async function fillFormField(page, selectors, value, options = {}) {
  const { waitFor = true, clearFirst = true } = options;
  
  for (const selector of selectors) {
    try {
      const element = await page.$(selector);
      if (!element) continue;
      
      if (waitFor) {
        await page.waitForSelector(selector, { timeout: 5000, state: 'visible' });
      }
      
      if (clearFirst) {
        await page.fill(selector, '');
      }
      
      await page.fill(selector, value);
      
      // Trigger events
      await page.evaluate((sel) => {
        const elem = document.querySelector(sel);
        if (elem) {
          elem.dispatchEvent(new Event('input', { bubbles: true }));
          elem.dispatchEvent(new Event('change', { bubbles: true }));
        }
      }, selector);
      
      return true;
    } catch (e) {
      continue;
    }
  }
  
  return false;
}

// Fill application form
async function fillApplicationForm(page, data) {
  let filledCount = 0;
  
  const firstName = data.firstName || data.fullName.split(' ')[0] || '';
  const lastName = data.lastName || data.fullName.split(' ').slice(1).join(' ') || '';
  
  // First Name
  if (firstName && await fillFormField(page, [
    'input[name="firstName"]',
    'input[name="first_name"]',
    'input[id*="first"]',
    'input[id*="firstName"]',
    'input[placeholder*="First"]',
    '#first-name',
    '#firstName'
  ], firstName)) {
    filledCount++;
  }
  
  // Last Name
  if (lastName && await fillFormField(page, [
    'input[name="lastName"]',
    'input[name="last_name"]',
    'input[id*="last"]',
    'input[id*="lastName"]',
    'input[placeholder*="Last"]',
    '#last-name',
    '#lastName'
  ], lastName)) {
    filledCount++;
  }
  
  // Full Name (fallback)
  if (data.fullName && !firstName) {
    if (await fillFormField(page, [
      'input[name="name"]',
      'input[name="full_name"]',
      'input[name="fullName"]',
      'input[id*="name"]',
      'input[placeholder*="Name"]',
      '#name',
      '#full-name'
    ], data.fullName)) {
      filledCount++;
    }
  }
  
  // Email
  if (data.email && await fillFormField(page, [
    'input[type="email"]',
    'input[name="email"]',
    'input[name="emailAddress"]',
    'input[id*="email"]',
    'input[placeholder*="Email"]',
    '#email'
  ], data.email)) {
    filledCount++;
  }
  
  // Phone
  if (data.phone && await fillFormField(page, [
    'input[type="tel"]',
    'input[name="phone"]',
    'input[name="phone_number"]',
    'input[name="phoneNumber"]',
    'input[id*="phone"]',
    'input[placeholder*="Phone"]',
    '#phone'
  ], data.phone)) {
    filledCount++;
  }
  
  // Location
  if (data.location && await fillFormField(page, [
    'input[name="location"]',
    'input[name="city"]',
    'input[name="address"]',
    'input[id*="location"]',
    'input[id*="city"]',
    'input[placeholder*="Location"]',
    '#location'
  ], data.location)) {
    filledCount++;
  }
  
  // LinkedIn
  if (data.linkedIn && await fillFormField(page, [
    'input[name="linkedin"]',
    'input[name="linkedIn"]',
    'input[name="linkedin_url"]',
    'input[id*="linkedin"]',
    'input[placeholder*="LinkedIn"]',
    '#linkedin'
  ], data.linkedIn)) {
    filledCount++;
  }
  
  // GitHub
  if (data.github && await fillFormField(page, [
    'input[name="github"]',
    'input[name="github_url"]',
    'input[id*="github"]',
    'input[placeholder*="GitHub"]',
    '#github'
  ], data.github)) {
    filledCount++;
  }
  
  // Portfolio
  if (data.portfolio && await fillFormField(page, [
    'input[name="portfolio"]',
    'input[name="portfolio_url"]',
    'input[name="website"]',
    'input[id*="portfolio"]',
    'input[placeholder*="Portfolio"]',
    '#portfolio'
  ], data.portfolio)) {
    filledCount++;
  }
  
  // Cover Letter
  if (data.coverLetter) {
    if (await fillFormField(page, [
      'textarea[name="coverLetter"]',
      'textarea[name="cover_letter"]',
      'textarea[name="coverLetterText"]',
      'textarea[id*="cover"]',
      'textarea[placeholder*="Cover"]',
      '#cover-letter',
      'textarea'
    ], data.coverLetter, { clearFirst: true })) {
      filledCount++;
    }
  }
  
  return filledCount;
}

// Detect questions that need user input
async function detectQuestions(page) {
  try {
    const questions = await page.evaluate(() => {
      const detectedQuestions = [];
      // Exclude search, hidden, submit, button inputs
      const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]):not([type="search"]), textarea, select');
      
      // Helper to check if element is in navigation/header area
      function isInNavigationArea(element) {
        const nav = element.closest('nav, header, [role="navigation"], [class*="nav"], [class*="header"], [class*="search"]');
        return nav !== null;
      }
      
      // Helper to check if it's a search/navigation field
      function isSearchOrNavigationField(input) {
        const name = (input.name || '').toLowerCase();
        const id = (input.id || '').toLowerCase();
        const placeholder = (input.placeholder || '').toLowerCase();
        const className = (input.className || '').toLowerCase();
        const type = (input.type || '').toLowerCase();
        
        // Check for search indicators
        if (type === 'search') return true;
        if (name.includes('search') || id.includes('search') || placeholder.includes('search') || className.includes('search')) return true;
        if (name.includes('q ') || id.includes('q ') || placeholder.includes('search')) return true;
        
        // Check if in navigation area
        if (isInNavigationArea(input)) return true;
        
        return false;
      }
      
      // Track radio button groups we've already processed
      const processedRadioGroups = new Set();
      
      inputs.forEach((input, index) => {
        // Skip if already has a value
        if (input.value && input.value.trim() !== '') {
          return;
        }
        
        // Handle radio buttons as groups
        if (input.type === 'radio') {
          const radioName = input.name;
          if (!radioName || processedRadioGroups.has(radioName)) {
            return; // Skip if already processed this radio group
          }
          processedRadioGroups.add(radioName);
          
          // Get all radio buttons in this group
          const radioGroup = document.querySelectorAll(`input[type="radio"][name="${radioName}"]`);
          if (radioGroup.length === 0) return;
          
          // Check if any radio in the group is already selected
          const hasSelected = Array.from(radioGroup).some(radio => radio.checked);
          if (hasSelected) return;
          
          // Find question text for the radio group
          let questionText = '';
          const firstRadio = radioGroup[0];
          
          // Try to find label or question text
          if (firstRadio.id) {
            const label = document.querySelector(`label[for="${firstRadio.id}"]`);
            if (label) {
              questionText = label.textContent.trim();
            }
          }
          
          // Look for fieldset legend or parent question
          if (!questionText) {
            const fieldset = firstRadio.closest('fieldset');
            if (fieldset) {
              const legend = fieldset.querySelector('legend');
              if (legend) {
                questionText = legend.textContent.trim();
              }
            }
          }
          
          // Look for parent label or nearby text
          if (!questionText) {
            const parent = firstRadio.closest('div, li, label, p');
            if (parent) {
              const prevSibling = parent.previousElementSibling;
              if (prevSibling) {
                const text = prevSibling.textContent.trim();
                if (text.length > 3 && text.length < 200) {
                  questionText = text;
                }
              }
            }
          }
          
          // Get answer options from radio buttons
          const answerOptions = Array.from(radioGroup).map(radio => {
            // Try to find label for this radio
            let optionText = radio.value;
            if (radio.id) {
              const label = document.querySelector(`label[for="${radio.id}"]`);
              if (label) {
                optionText = label.textContent.trim();
              }
            } else {
              // Check next sibling or parent text
              const nextSibling = radio.nextSibling;
              if (nextSibling && nextSibling.nodeType === 3) {
                optionText = nextSibling.textContent.trim();
              } else if (radio.parentElement) {
                const parentText = radio.parentElement.textContent.trim();
                if (parentText) {
                  optionText = parentText;
                }
              }
            }
            
            return {
              value: radio.value,
              text: optionText || radio.value
            };
          });
          
          // Only include if we found a question and it's not a standard field
          if (questionText && questionText.length > 5) {
            const questionLower = questionText.toLowerCase();
            const isStandardField = 
              questionLower.includes('email') ||
              questionLower.includes('name') ||
              questionLower.includes('phone') ||
              questionLower.includes('address') ||
              questionLower.includes('city') ||
              questionLower.includes('zip') ||
              questionLower.includes('state') ||
              questionLower.includes('country') ||
              questionLower.includes('linkedin') ||
              questionLower.includes('github') ||
              questionLower.includes('portfolio') ||
              questionLower.includes('website') ||
              questionLower.includes('cover letter') ||
              questionLower.includes('resume') ||
              questionLower.includes('cv');
            
            if (!isStandardField || firstRadio.required) {
              detectedQuestions.push({
                index: index,
                fieldType: 'input',
                inputType: 'radio',
                name: radioName,
                id: firstRadio.id || '',
                question: questionText,
                options: answerOptions,
                required: firstRadio.required || firstRadio.hasAttribute('required'),
                selector: `input[type="radio"][name="${radioName}"]`
              });
            }
          }
          return; // Skip normal processing for radio buttons
        }
        
        // Skip checkboxes (they're usually optional and can be skipped)
        if (input.type === 'checkbox') {
          return;
        }
        
        // Skip search and navigation fields
        if (isSearchOrNavigationField(input)) {
          return;
        }
        
        // Skip if input is clearly not part of the application form
        // (e.g., in sidebar, footer, or other non-form areas)
        const form = input.closest('form, [role="form"], [class*="form"], [class*="application"], [class*="apply"]');
        if (!form && !input.closest('[data-testid*="form"], [data-testid*="application"]')) {
          // Only skip if it's clearly in a non-form area (like footer, sidebar)
          const nonFormAreas = input.closest('footer, aside, [role="complementary"], [class*="sidebar"], [class*="footer"]');
          if (nonFormAreas) {
            return;
          }
        }
        
        // Try to find the question/label
        let questionText = '';
        let answerOptions = [];
        
        // Strategy 1: Find associated label
        if (input.id) {
          const label = document.querySelector(`label[for="${input.id}"]`);
          if (label) {
            questionText = label.textContent.trim();
          }
        }
        
        // Strategy 2: Find parent label
        if (!questionText) {
          const parentLabel = input.closest('label');
          if (parentLabel) {
            questionText = parentLabel.textContent.trim();
          }
        }
        
        // Strategy 3: Find nearby text (question-like patterns)
        if (!questionText) {
          const parent = input.parentElement;
          if (parent) {
            // Look for text in parent or previous sibling
            const prevSibling = parent.previousElementSibling;
            if (prevSibling) {
              const text = prevSibling.textContent.trim();
              if (text.length > 3 && text.length < 200) {
                questionText = text;
              }
            }
            
            // Fallback to parent text
            if (!questionText) {
              const textNodes = Array.from(parent.childNodes)
                .filter(n => n.nodeType === 3)
                .map(n => n.textContent.trim())
                .filter(t => t.length > 0);
              if (textNodes.length > 0) {
                questionText = textNodes[0];
              }
            }
          }
        }
        
        // Strategy 4: Use placeholder (but filter out search-related)
        if (!questionText && input.placeholder) {
          const placeholder = input.placeholder.toLowerCase();
          if (!placeholder.includes('search') && !placeholder.includes('find')) {
            questionText = input.placeholder;
          }
        }
        
        // Get answer options for select
        if (input.tagName === 'SELECT') {
          const options = Array.from(input.querySelectorAll('option'));
          answerOptions = options
            .filter(opt => opt.value && opt.value !== '')
            .map(opt => ({
              value: opt.value,
              text: opt.textContent.trim()
            }));
        }
        
        // Helper to get selector
        function getSelector(element) {
          if (element.id) return '#' + element.id;
          if (element.name) return `[name="${element.name}"]`;
          return '';
        }
        
        // Only include if we found a question and it's not a standard field
        if (questionText && questionText.length > 3) {
          const questionLower = questionText.toLowerCase();
          
          // Filter out search/navigation terms
          if (questionLower === 'search' || questionLower.includes('search for') || questionLower === 'find') {
            return;
          }
          
          const isStandardField = 
            questionLower.includes('email') ||
            questionLower.includes('name') ||
            questionLower.includes('phone') ||
            questionLower.includes('address') ||
            questionLower.includes('city') ||
            questionLower.includes('zip') ||
            questionLower.includes('state') ||
            questionLower.includes('country') ||
            questionLower.includes('linkedin') ||
            questionLower.includes('github') ||
            questionLower.includes('portfolio') ||
            questionLower.includes('website') ||
            questionLower.includes('cover letter') ||
            questionLower.includes('resume') ||
            questionLower.includes('cv');
          
          // Only include if it's a real question (not a standard field, or if required)
          // Also exclude very short or very long text (likely not a question)
          if ((!isStandardField || input.required) && questionText.length > 5 && questionText.length < 200) {
            detectedQuestions.push({
              index: index,
              fieldType: input.tagName.toLowerCase(),
              inputType: input.type || 'text',
              name: input.name || '',
              id: input.id || '',
              question: questionText,
              options: answerOptions,
              required: input.required || input.hasAttribute('required'),
              selector: getSelector(input)
            });
          }
        }
      });
      
      return detectedQuestions;
    });
    
    // Filter out questions we can answer automatically
    const unansweredQuestions = questions.filter(q => {
      const questionLower = q.question.toLowerCase();
      
      // Exclude search/navigation fields
      if (questionLower === 'search' || questionLower.includes('search for') || questionLower === 'find') {
        return false;
      }
      
      return !questionLower.includes('email') &&
             !questionLower.includes('name') &&
             !questionLower.includes('phone') &&
             !questionLower.includes('address') &&
             !questionLower.includes('city') &&
             !questionLower.includes('zip') &&
             !questionLower.includes('state') &&
             !questionLower.includes('country') &&
             !questionLower.includes('linkedin') &&
             !questionLower.includes('github') &&
             !questionLower.includes('portfolio') &&
             !questionLower.includes('website') &&
             !questionLower.includes('cover letter') &&
             !questionLower.includes('resume') &&
             !questionLower.includes('cv');
    });
    
    console.log(`📋 Filtered questions: ${questions.length} total, ${unansweredQuestions.length} need user input`);
    
    return unansweredQuestions;
  } catch (error) {
    console.error('Failed to detect questions:', error);
    return [];
  }
}

// Fill answers to questions
async function fillAnswers(page, answers) {
  let filledCount = 0;
  
  try {
    for (const [questionIndex, answer] of Object.entries(answers)) {
      const index = parseInt(questionIndex);
      
      // Try to find the input by index and fill it
      const result = await page.evaluate((idx, ans) => {
        const inputs = document.querySelectorAll('input:not([type="hidden"]):not([type="submit"]):not([type="button"]), textarea, select');
        if (idx >= 0 && idx < inputs.length) {
          const input = inputs[idx];
          
          if (input.tagName === 'SELECT') {
            input.value = ans;
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          } else if (input.tagName === 'TEXTAREA') {
            input.value = ans;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          } else {
            input.value = ans;
            input.dispatchEvent(new Event('input', { bubbles: true }));
            input.dispatchEvent(new Event('change', { bubbles: true }));
            return true;
          }
        }
        return false;
      }, index, answer);
      
      if (result) {
        filledCount++;
      }
    }
  } catch (error) {
    console.error('Failed to fill answers:', error);
  }
  
  return filledCount;
}

// Upload resume
async function uploadResume(page, data) {
  try {
    const fileSelectors = [
      'input[type="file"]',
      'input[name*="resume"]',
      'input[name*="cv"]',
      'input[id*="resume"]',
      'input[id*="cv"]',
      'input[accept*="pdf"]',
      'input[accept*="doc"]'
    ];
    
    let fileInput = null;
    for (const selector of fileSelectors) {
      try {
        fileInput = await page.$(selector);
        if (fileInput) break;
      } catch (e) {
        continue;
      }
    }
    
    if (!fileInput) {
      console.log('⚠️ No file input found for resume upload');
      return false;
    }
    
    // Handle resume upload
    if (data.resumeBase64 && data.resumeFileName) {
      // Convert base64 to buffer
      const resumeBuffer = Buffer.from(data.resumeBase64, 'base64');
      const tempPath = `/tmp/${data.resumeFileName}`;
      require('fs').writeFileSync(tempPath, resumeBuffer);
      await fileInput.setInputFiles(tempPath);
      require('fs').unlinkSync(tempPath); // Clean up
      return true;
    } else if (data.resumeUrl) {
      // Download and upload resume
      const response = await fetch(data.resumeUrl);
      const arrayBuffer = await response.arrayBuffer();
      const buffer = Buffer.from(arrayBuffer);
      const fileName = data.resumeFileName || 'resume.pdf';
      const tempPath = `/tmp/${fileName}`;
      require('fs').writeFileSync(tempPath, buffer);
      await fileInput.setInputFiles(tempPath);
      require('fs').unlinkSync(tempPath); // Clean up
      return true;
    }
    
    return false;
  } catch (error) {
    console.error('❌ Resume upload failed:', error);
    return false;
  }
}

// Job scraping endpoint (for Workday and other JS-rendered sites)
app.post('/scrape', async (req, res) => {
  req.setTimeout(60000); // 60 second timeout for scraping
  res.setTimeout(60000);
  
  let browser = null;
  let page = null;
  
  try {
    const { companyUrl, keywords, location } = req.body;
    
    if (!companyUrl) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required field: companyUrl' 
      });
    }
    
    console.log(`🔍 Scraping jobs from: ${companyUrl}`);
    if (keywords) {
      console.log(`   Keywords: ${keywords}`);
    }
    
    browser = await chromium.launch({
      headless: true,
      args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
    });
    
    const context = await browser.newContext({
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      viewport: { width: 1280, height: 720 }
    });
    
    page = await context.newPage();
    
    console.log(`🌐 Navigating to: ${companyUrl}`);
    await page.goto(companyUrl, { waitUntil: 'networkidle', timeout: 30000 });
    
    // Wait for job listings to load (Workday uses dynamic content)
    console.log(`⏳ Waiting for job listings to load...`);
    await page.waitForTimeout(3000); // Wait 3 seconds for JS to render
    
    // Try to wait for job elements to appear
    try {
      await page.waitForSelector('[data-automation-id="jobTitle"], .job-title, [data-testid="job-title"], a[href*="/jobs/"]', { 
        timeout: 10000 
      });
    } catch (e) {
      console.log(`⚠️ Job elements not found immediately, continuing anyway...`);
    }
    
    // Scrape jobs from the page
    const jobs = await page.evaluate((keywords, location) => {
      const jobList = [];
      
      // Try multiple selectors for job titles
      const jobSelectors = [
        '[data-automation-id="jobTitle"]',
        '.job-title',
        '[data-testid="job-title"]',
        'a[href*="/jobs/"]',
        '[data-automation-id="jobPosting"]',
        '.job-posting',
        '[class*="job"]'
      ];
      
      let jobElements = [];
      for (const selector of jobSelectors) {
        const elements = document.querySelectorAll(selector);
        if (elements.length > 0) {
          jobElements = Array.from(elements);
          console.log(`Found ${elements.length} jobs with selector: ${selector}`);
          break;
        }
      }
      
      jobElements.forEach((element, index) => {
        try {
          // Get job title
          const titleElement = element.tagName === 'A' ? element : 
                              element.querySelector('a, [data-automation-id="jobTitle"], .job-title') || element;
          const title = titleElement.textContent?.trim() || '';
          
          if (!title || title.length < 3) return; // Skip if no title
          
          // Get job URL
          let jobUrl = null;
          if (element.tagName === 'A') {
            jobUrl = element.href;
          } else {
            const link = element.querySelector('a[href*="/jobs/"], a[href*="/job/"]');
            if (link) {
              jobUrl = link.href;
            } else if (element.href) {
              jobUrl = element.href;
            }
          }
          
          // Make URL absolute if relative
          if (jobUrl && !jobUrl.startsWith('http')) {
            jobUrl = new URL(jobUrl, window.location.href).href;
          }
          
          // Get job card/parent element for additional info
          const jobCard = element.closest('[data-automation-id="jobPosting"], .job-posting, [class*="job-card"]') || element.parentElement;
          
          // Get location
          const locationElement = jobCard?.querySelector('[data-automation-id="jobLocation"], .job-location, [class*="location"]');
          const jobLocation = locationElement?.textContent?.trim() || location || 'Location not specified';
          
          // Get description/snippet
          const descriptionElement = jobCard?.querySelector('[data-automation-id="jobDescription"], .job-description, [class*="description"]');
          const description = descriptionElement?.textContent?.trim() || '';
          
          // Get salary
          const salaryElement = jobCard?.querySelector('[data-automation-id="compensationText"], .salary, [class*="salary"], [class*="compensation"]');
          const salary = salaryElement?.textContent?.trim() || 'Salary not specified';
          
          // Keyword filtering (lenient)
          let shouldInclude = true;
          if (keywords && keywords.trim().length > 0) {
            const jobText = `${title} ${description}`.toLowerCase();
            const keywordsLower = keywords.toLowerCase();
            
            // Split by "OR" for multiple keywords
            const keywordParts = keywordsLower.split(/\s+or\s+/).map(k => k.trim());
            const matchesKeyword = keywordParts.some(part => {
              const parts = part.split(/\s+/).filter(p => p.length > 2);
              if (parts.length === 0) return true;
              return parts.some(p => jobText.includes(p)) || jobText.includes(part);
            });
            
            // Very lenient: include if matches OR if we have very few jobs
            if (!matchesKeyword && jobList.length >= 10) {
              shouldInclude = false;
            }
          }
          
          if (shouldInclude && title) {
            jobList.push({
              title: title,
              company: window.location.hostname.split('.')[0] || 'Unknown',
              location: jobLocation,
              description: description.substring(0, 500) || null, // Limit description length
              url: jobUrl,
              salary: salary,
              jobType: null
            });
          }
        } catch (err) {
          console.error(`Error parsing job ${index}:`, err);
        }
      });
      
      return jobList;
    }, keywords || '', location || '');
    
    console.log(`✅ Scraped ${jobs.length} jobs from ${companyUrl}`);
    
    await browser.close();
    browser = null;
    
    res.json({
      success: true,
      jobs: jobs,
      count: jobs.length
    });
    
  } catch (error) {
    console.error('❌ Scraping failed:', error);
    
    if (browser) {
      try {
        await browser.close();
      } catch (closeError) {
        console.error('Failed to close browser:', closeError);
      }
    }
    
    res.status(500).json({
      success: false,
      jobs: [],
      count: 0,
      error: error.message || String(error)
    });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Playwright automation service running on port ${PORT}`);
});


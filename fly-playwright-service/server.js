// Fly.io Playwright Service
// This Node.js service runs Playwright and can be called from Supabase Edge Functions

const express = require('express');
const { chromium } = require('playwright');
const cors = require('cors');
const multer = require('multer');
const fs = require('fs');
const app = express();
const upload = multer({ dest: '/tmp' });

// Helper function to get proxy configuration (like sorce.jobs)
function getProxyConfig() {
  const proxyEnabled = process.env.PROXY_ENABLED === 'true';
  
  if (!proxyEnabled) {
    return null; // No proxy configured
  }
  
  const endpoint = process.env.PROXY_ENDPOINT; // e.g., "gate.smartproxy.com:7000"
  const username = process.env.PROXY_USERNAME;
  const password = process.env.PROXY_PASSWORD;
  
  if (!endpoint || !username || !password) {
    console.log('⚠️ Proxy enabled but credentials missing - running without proxy');
    return null;
  }
  
  // Format: http://username:password@host:port
  const proxyServer = `http://${username}:${password}@${endpoint}`;
  
  return {
    server: proxyServer,
    username,
    password
  };
}

app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Store active streams (sessionId -> response object)
const activeStreams = new Map();

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'ok', service: 'playwright-automation' });
});

function getGeminiApiKey() {
  return process.env.GEMINI_API_KEY || process.env.GOOGLE_API_KEY || '';
}

function getOpenAIApiKey() {
  return process.env.OPENAI_API_KEY || '';
}

async function transcribeAudioWithOpenAI(filePath, mimeType, originalName) {
  const apiKey = getOpenAIApiKey();
  if (!apiKey) {
    throw new Error('Missing OPENAI_API_KEY on server');
  }

  const fileData = fs.readFileSync(filePath);
  const audioBlob = new Blob([fileData], { type: mimeType || 'audio/mp4' });
  const form = new FormData();
  form.append('file', audioBlob, originalName || 'audio.m4a');
  form.append('model', process.env.OPENAI_TRANSCRIBE_MODEL || 'gpt-4o-mini-transcribe');
  form.append('response_format', 'text');

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`
    },
    body: form
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenAI transcription failed (${response.status}): ${text}`);
  }

  const transcript = (await response.text()).trim();
  if (!transcript) {
    throw new Error('OpenAI returned empty transcript');
  }
  return transcript;
}

async function generateNotesWithOpenAI(prompt, options = {}) {
  const apiKey = getOpenAIApiKey();
  if (!apiKey) {
    throw new Error('Missing OPENAI_API_KEY on server');
  }

  const model = options.model || process.env.OPENAI_NOTES_MODEL || 'gpt-4o-mini';
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.1,
      max_tokens: 8192
    })
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`OpenAI request failed (${response.status}): ${text}`);
  }

  const json = await response.json();
  let text = json?.choices?.[0]?.message?.content?.trim();
  if (!text) {
    throw new Error('OpenAI returned empty response');
  }
  text = decodeHtmlEntities(text);
  return text;
}

async function generateNotesWithGemini(parts, options = {}) {
  const apiKey = getGeminiApiKey();
  if (!apiKey) {
    throw new Error('Missing GEMINI_API_KEY on server');
  }

  const model = options.model || process.env.GEMINI_MODEL || 'gemini-2.5-flash';
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;
  const body = {
    contents: [{ role: 'user', parts }],
    generationConfig: {
      temperature: 0.1,
      maxOutputTokens: 8192
    }
  };

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });

  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Gemini request failed (${response.status}): ${text}`);
  }

  const json = await response.json();
  let text = json?.candidates?.[0]?.content?.parts
    ?.map(p => p.text || '')
    .join('\n')
    .trim();
  if (!text) {
    throw new Error('Gemini returned empty response');
  }
  // Decode any HTML entities Gemini may include
  text = text
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
  return text;
}

function decodeHtmlEntities(text) {
  return text
    .replace(/&#39;/g, "'")
    .replace(/&#x27;/g, "'")
    .replace(/&apos;/g, "'")
    .replace(/&quot;/g, '"')
    .replace(/&lt;/g, '<')
    .replace(/&gt;/g, '>')
    .replace(/&amp;/g, '&');
}

async function formatNotesForApp(rawNotes, contextLabel = 'study notes', options = {}) {
  const { forceSecondPass = false } = options;
  const cleaned = decodeHtmlEntities((rawNotes || '').trim());
  if (!cleaned) return rawNotes;

  // Keep only if content already matches the app's target Turbo format.
  const hasBriefOverview = cleaned.includes('\n## Brief Overview') || cleaned.startsWith('## Brief Overview');
  const hasKeyPoints = cleaned.includes('\n## Key Points') || cleaned.startsWith('## Key Points');
  const hasTopicHeadings = cleaned.includes('\n## ');
  const hasBullets = cleaned.includes('\n- ');
  const hasBlockquotes = cleaned.includes('\n> ');
  if (!forceSecondPass && hasBriefOverview && hasKeyPoints && hasTopicHeadings && hasBullets && hasBlockquotes) {
    return cleaned;
  }

  // Second-pass: reformat into Turbo AI–style study sheet.
  try {
    const reformatPrompt = [
      `Reformat the following ${contextLabel} into a polished study sheet.`,
      'CRITICAL: Keep ALL information. Do not remove or summarize away any facts.',
      '',
      'Required markdown format (follow exactly):',
      '1. Start with "## Brief Overview" — a short paragraph summarizing the content.',
      '2. Then "## Key Points" — bullet list (- ) of main ideas.',
      '3. Then additional topic sections using "## " headings with a relevant emoji prefix (e.g. "## ⚡ Kirchhoff\'s Laws").',
      '4. Under each section use "### " subheadings for subtopics.',
      '5. Use blockquotes (> ) for definitions and key concepts.',
      '6. Use "Tip:", "Key Insight:", "Definition:", "Warning:" prefixes on lines where applicable.',
      '7. Use numbered lists (1. 2. 3.) for sequential steps or procedures.',
      '8. Use bullet lists (- ) for non-sequential facts.',
      '9. Use --- horizontal rules between major sections.',
      '10. Keep equations in readable plain text/Unicode. For superscripts use ^ with parentheses for groups: x^2, x^(a+b), x^(n-1). For subscripts use _ with parentheses: a_n, x_(i+1). Never use LaTeX or curly braces {}.',
      '11. No code fences. No prose paragraphs longer than 3 sentences.',
      '12. When the source has tables, diagrams, or comparison data, reproduce them as markdown tables (| Header | Header |).',
      '',
      'Input text to reformat:',
      cleaned
    ].join('\n');
    const formatted = await generateNotesWithOpenAI(reformatPrompt);
    return decodeHtmlEntities(formatted?.trim() || cleaned);
  } catch (e) {
    return cleaned;
  }
}

function cleanupUploadedFile(filePath) {
  if (!filePath) return;
  fs.unlink(filePath, () => {});
}

function normalizeOutputMode(v) {
  const s = String(v || 'notes').toLowerCase().trim();
  if (s === 'flashcards' || s === 'flashcard') return 'flashcards';
  if (s === 'quiz') return 'quiz';
  return 'notes';
}

function extractJsonObjectLoose(text) {
  let t = (text || '').trim();
  if (t.startsWith('```')) {
    t = t.replace(/^```(?:json)?\s*/i, '').trim();
    const fenceEnd = t.indexOf('```');
    if (fenceEnd !== -1) t = t.slice(0, fenceEnd).trim();
  }
  const start = t.indexOf('{');
  const end = t.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('No JSON object in model response');
  }
  return JSON.parse(t.slice(start, end + 1));
}

async function generateFlashcardsPayloadFromText(sourceLabel, content) {
  const prompt = [
    'You create study flashcards from source material.',
    'Return ONLY valid JSON (no markdown code fences) with this exact shape:',
    '{"title":"short deck title","topic":"short topic label","cards":[{"front":"question or term","back":"answer or definition"}]}',
    'Rules:',
    '- Use 10-28 cards depending on how much material there is; each front/back under 500 characters.',
    '- Front = prompt to recall; back = clear concise answer.',
    '- Cover the most important facts.',
    '',
    `Source (${sourceLabel}):`,
    (content || '').slice(0, 120000)
  ].join('\n');
  const raw = await generateNotesWithOpenAI(prompt, { model: process.env.OPENAI_FLASHCARDS_MODEL || 'gpt-4o-mini' });
  const obj = extractJsonObjectLoose(raw);
  const cards = Array.isArray(obj.cards) ? obj.cards : [];
  const normalized = cards
    .map((c) => ({ front: String(c.front || '').trim(), back: String(c.back || '').trim() }))
    .filter((c) => c.front && c.back);
  return {
    title: String(obj.title || '').trim() || 'Flashcards',
    topic: String(obj.topic || '').trim() || 'General',
    cards: normalized
  };
}

async function generateQuizPayloadFromText(sourceLabel, content) {
  const prompt = [
    'Create a multiple-choice quiz from the source material.',
    'Return ONLY valid JSON (no markdown fences):',
    '{"title":"...","topic":"...","questions":[{"question":"...","options":["A","B","C","D"],"correctIndex":0}]}',
    'Rules:',
    '- 8-18 questions; each with exactly 4 options.',
    '- correctIndex is 0-3.',
    '- Questions test understanding.',
    '',
    `Source (${sourceLabel}):`,
    (content || '').slice(0, 120000)
  ].join('\n');
  const raw = await generateNotesWithOpenAI(prompt, { model: process.env.OPENAI_QUIZ_MODEL || 'gpt-4o-mini' });
  const obj = extractJsonObjectLoose(raw);
  const questions = Array.isArray(obj.questions) ? obj.questions : [];
  const normalized = questions
    .map((q) => {
      const opts = Array.isArray(q.options) ? q.options.map((o) => String(o).trim()).filter(Boolean) : [];
      let idx = Number(q.correctIndex);
      if (Number.isNaN(idx)) idx = 0;
      idx = Math.max(0, Math.min(3, Math.round(idx)));
      return {
        question: String(q.question || '').trim(),
        options: opts.length >= 4 ? opts.slice(0, 4) : opts,
        correctIndex: idx
      };
    })
    .filter((q) => q.question && q.options.length === 4);
  return {
    title: String(obj.title || '').trim() || 'Quiz',
    topic: String(obj.topic || '').trim() || 'General',
    questions: normalized
  };
}

// YouTube helpers

function extractYouTubeVideoId(urlStr) {
  try {
    const u = new URL(urlStr);
    const host = u.hostname.replace('www.', '');
    if (host === 'youtu.be') return u.pathname.slice(1).split('/')[0];
    if (host.includes('youtube.com') || host.includes('youtube-nocookie.com')) {
      if (u.searchParams.has('v')) return u.searchParams.get('v');
      if (u.pathname.startsWith('/embed/')) return u.pathname.split('/')[2];
      if (u.pathname.startsWith('/shorts/')) return u.pathname.split('/')[2];
    }
  } catch (_) {}
  return null;
}

async function fetchYouTubeMetadata(videoId) {
  let title = '';
  let author = '';

  try {
    const oembedResp = await fetch(
      `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`
    );
    if (oembedResp.ok) {
      const data = await oembedResp.json();
      title = data.title || '';
      author = data.author_name || '';
    }
  } catch (_) {}

  return { title, author };
}

function isYouTubeURL(urlStr) {
  try {
    const host = new URL(urlStr).hostname.replace('www.', '');
    return host.includes('youtube.com') || host === 'youtu.be' || host.includes('youtube-nocookie.com');
  } catch (_) {
    return false;
  }
}

// Turbo AI prompt template for structured notes
const TURBO_NOTES_PROMPT_RULES = [
  'STRICT formatting rules (follow exactly):',
  '1. Start with "## Brief Overview" — a short paragraph summarizing the content.',
  '2. Then "## Key Points" — a bullet list (- ) of the main ideas.',
  '3. Then additional topic sections using "## " headings with a relevant emoji prefix (e.g. "## ⚡ Topic Name").',
  '4. Under each section use "### " subheadings for subtopics.',
  '5. Use blockquotes (> ) for definitions and key concepts (one blockquote per definition).',
  '6. Prefix important callout lines with "Tip:", "Key Insight:", "Definition:", or "Warning:" as appropriate.',
  '7. Use numbered lists (1. 2. 3.) for sequential steps or procedures.',
  '8. Use bullet lists (- ) for non-sequential facts.',
  '9. Put --- horizontal rules between major sections.',
  '10. Keep equations in readable plain text/Unicode. For superscripts use ^ with parentheses for groups: x^2, x^(a+b), x^(n-1). For subscripts use _ with parentheses: a_n, x_(i+1). Never use LaTeX or curly braces {}.',
  '11. No code fences. No prose paragraphs longer than 3 sentences.',
  '12. When the source has tables, diagrams, or comparison data, reproduce them as markdown tables (| Header | Header |).'
].join('\n');

// Generate notes from website or YouTube URL
app.post('/generate-notes-from-url', async (req, res) => {
  try {
    const { url, outputMode: rawMode } = req.body || {};
    const outputMode = normalizeOutputMode(rawMode);
    if (!url || typeof url !== 'string') {
      return res.status(400).json({ error: 'Missing required field: url' });
    }

    let isYT = isYouTubeURL(url);

    // ─── YouTube path: use Gemini's knowledge of the video ───
    if (isYT) {
      const videoId = extractYouTubeVideoId(url);
      const meta = videoId ? await fetchYouTubeMetadata(videoId) : { title: '', author: '' };
      const videoTitle = meta.title || '';
      const videoAuthor = meta.author || '';

      console.log(`📹 YouTube video: "${videoTitle}" by ${videoAuthor} (${videoId})`);

      const ytPrompt = [
        'You are an expert study-note generator.',
        'You are given a YouTube video. Generate COMPREHENSIVE, DETAILED study notes covering EVERYTHING discussed in the video.',
        'Include all key topics, concepts, examples, demonstrations, steps, and conclusions.',
        'Be thorough — imagine a student needs these notes to learn the full material without watching the video.',
        '',
        TURBO_NOTES_PROMPT_RULES,
        '',
        `YouTube URL: ${url}`,
        videoTitle ? `Video title: "${videoTitle}"` : '',
        videoAuthor ? `Channel / Author: ${videoAuthor}` : ''
      ].join('\n');

      const rawNotes = await generateNotesWithOpenAI(ytPrompt);

      if (outputMode === 'flashcards') {
        const payload = await generateFlashcardsPayloadFromText('YouTube video', rawNotes);
        if (!payload.cards.length) {
          return res.status(422).json({ error: 'Could not generate flashcards from this video.' });
        }
        return res.json({
          title: payload.title || videoTitle || 'Flashcards',
          topic: payload.topic,
          cards: payload.cards
        });
      }

      if (outputMode === 'quiz') {
        const payload = await generateQuizPayloadFromText('YouTube video', rawNotes);
        if (!payload.questions.length) {
          return res.status(422).json({ error: 'Could not generate a quiz from this video.' });
        }
        return res.json({
          title: payload.title || videoTitle || 'Quiz',
          topic: payload.topic,
          questions: payload.questions
        });
      }

      const notes = await formatNotesForApp(rawNotes, 'YouTube video notes');

      return res.json({
        title: videoTitle || 'YouTube notes',
        notes
      });
    }

    // ─── Website path: fetch page HTML and extract text ───
    let pageText = '';
    let pageTitle = '';

    // Step 1: Try simple fetch (fast, works for most sites)
    try {
      const webpageResponse = await fetch(url, {
        method: 'GET',
        redirect: 'follow',
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'en-US,en;q=0.9'
        }
      });
      const html = await webpageResponse.text();

      const titleMatch = html.match(/<title>([^<]*)<\/title>/i);
      if (titleMatch) pageTitle = titleMatch[1].trim();

      const isChallengePage =
        html.includes('Just a moment') ||
        html.includes('cf-browser-verification') ||
        html.includes('challenge-platform') ||
        html.includes('cf-chl-bypass') ||
        (html.includes('Enable JavaScript') && html.length < 15000);

      if (!isChallengePage) {
        pageText = html
          .replace(/<script[\s\S]*?<\/script>/gi, ' ')
          .replace(/<style[\s\S]*?<\/style>/gi, ' ')
          .replace(/<[^>]+>/g, ' ')
          .replace(/\s+/g, ' ')
          .trim()
          .slice(0, 120000);
      } else {
        console.log('⚠️ Simple fetch hit a challenge page, will use Playwright');
      }
    } catch (e) {
      console.log('⚠️ Simple fetch failed:', e.message);
    }

    // Step 2: If simple fetch got no usable content, try Firecrawl (handles JS + Cloudflare, returns markdown)
    if (!pageText || pageText.length < 200) {
      console.log('🌐 Trying Firecrawl to fetch page content...');
      const firecrawlKey = process.env.FIRECRAWL_API_KEY || 'fc-9ca327ba8a5547b7af27fbd77059b7bf';
      try {
        const fcResponse = await fetch('https://api.firecrawl.dev/v1/scrape', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${firecrawlKey}`
          },
          body: JSON.stringify({ url, formats: ['markdown'] }),
          signal: AbortSignal.timeout(30000)
        });
        if (fcResponse.ok) {
          const fcData = await fcResponse.json();
          const md = fcData?.data?.markdown || '';
          if (md.trim().length > 200) {
            pageText = md.trim().slice(0, 120000);
            if (!pageTitle && fcData?.data?.metadata?.title) {
              pageTitle = fcData.data.metadata.title;
            }
            console.log(`✅ Firecrawl fetched ${pageText.length} chars from page`);
          }
        } else {
          const errText = await fcResponse.text().catch(() => '');
          console.log(`⚠️ Firecrawl returned ${fcResponse.status}: ${errText.slice(0, 200)}`);
        }
      } catch (e) {
        console.log('⚠️ Firecrawl failed:', e.message);
      }
    }

    // Step 3: Last resort — use Playwright headless browser (heavy but handles toughest cases)
    if (!pageText || pageText.length < 200) {
      console.log('🌐 Falling back to Playwright to fetch page content...');
      let browser = null;
      try {
        browser = await chromium.launch({
          headless: true,
          args: ['--no-sandbox', '--disable-setuid-sandbox', '--disable-dev-shm-usage']
        });
        const context = await browser.newContext({
          userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          viewport: { width: 1280, height: 900 }
        });
        const page = await context.newPage();
        await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 25000 });
        await page.waitForTimeout(4000);

        pageTitle = await page.title().catch(() => '') || pageTitle;
        pageText = await page.evaluate(() => document.body.innerText).catch(() => '');
        pageText = (pageText || '').trim().slice(0, 120000);

        await browser.close();
        browser = null;
        console.log(`✅ Playwright fetched ${pageText.length} chars from page`);
      } catch (e) {
        console.log('⚠️ Playwright fetch also failed:', e.message);
        if (browser) {
          try { await browser.close(); } catch (_) {}
        }
      }
    }

    if (outputMode === 'flashcards') {
      if (!pageText || pageText.length < 50) {
        return res.status(422).json({ error: 'Could not read enough text from this page to make flashcards.' });
      }
      const payload = await generateFlashcardsPayloadFromText('webpage', pageText);
      if (!payload.cards.length) {
        return res.status(422).json({ error: 'Could not generate flashcards from this page.' });
      }
      return res.json({
        title: payload.title || pageTitle || 'Flashcards',
        topic: payload.topic,
        cards: payload.cards
      });
    }

    if (outputMode === 'quiz') {
      if (!pageText || pageText.length < 50) {
        return res.status(422).json({ error: 'Could not read enough text from this page to make a quiz.' });
      }
      const payload = await generateQuizPayloadFromText('webpage', pageText);
      if (!payload.questions.length) {
        return res.status(422).json({ error: 'Could not generate a quiz from this page.' });
      }
      return res.json({
        title: payload.title || pageTitle || 'Quiz',
        topic: payload.topic,
        questions: payload.questions
      });
    }

    const prompt = [
      'You are an expert study-note generator.',
      'Analyze the following webpage content and generate COMPREHENSIVE study notes that TEACH the underlying concepts.',
      '',
      'IMPORTANT — If the page contains quizzes, tests, practice problems, or exercises:',
      '- Do NOT just list the questions and selected answers.',
      '- Identify the TOPICS and CONCEPTS being tested.',
      '- Create study notes that EXPLAIN those concepts with clear definitions and reasoning.',
      '- Include worked examples showing HOW to solve each type of problem step by step.',
      '- Show the correct answer AND explain WHY it is correct and why the other options are wrong.',
      '',
      'If the page contains articles, lectures, or reference material:',
      '- Extract all key information and organize it into clear study notes.',
      '- Do not omit details or summarize away facts.',
      '',
      TURBO_NOTES_PROMPT_RULES,
      '',
      `Source URL: ${url}`,
      pageText ? `Source text:\n${pageText}` : ''
    ].join('\n');

    const rawNotes = await generateNotesWithOpenAI(prompt);
    const notes = await formatNotesForApp(rawNotes, 'web source notes');

    return res.json({
      title: pageTitle || 'Web notes',
      notes
    });
  } catch (error) {
    console.error('❌ generate-notes-from-url failed:', error);
    return res.status(500).json({ error: error.message || String(error) });
  }
});

// Generate notes from uploaded document
app.post('/generate-notes-from-document', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Missing required multipart file field: file' });
    }

    const fileData = fs.readFileSync(req.file.path);
    const base64Data = fileData.toString('base64');
    const mimeType = req.file.mimetype || 'application/octet-stream';
    const originalName = req.file.originalname || 'Document';
    const outputMode = normalizeOutputMode(req.body?.outputMode);
    const baseTitle = originalName.replace(/\.[^.]+$/, '');

    const inlinePart = {
      inline_data: {
        mime_type: mimeType,
        data: base64Data
      }
    };

    if (outputMode === 'flashcards') {
      const raw = await generateNotesWithGemini([
        {
          text: [
            'Read this entire document.',
            'Output ONLY valid JSON (no markdown, no code fences) with this exact shape:',
            '{"title":"short title","topic":"short label","cards":[{"front":"term or question","back":"definition or answer"}]}',
            'Create 15-30 high-quality flashcards from the material.',
            'If the file is unreadable, return {"title":"Unreadable","topic":"General","cards":[]}.'
          ].join('\n')
        },
        inlinePart
      ]);
      let obj;
      try {
        obj = extractJsonObjectLoose(raw);
      } catch (e) {
        cleanupUploadedFile(req.file.path);
        return res.status(422).json({ error: 'Could not parse flashcards from document.' });
      }
      const cards = Array.isArray(obj.cards) ? obj.cards : [];
      const normalized = cards
        .map((c) => ({ front: String(c.front || '').trim(), back: String(c.back || '').trim() }))
        .filter((c) => c.front && c.back);
      cleanupUploadedFile(req.file.path);
      if (!normalized.length) {
        return res.status(422).json({ error: 'Could not generate flashcards from this document.' });
      }
      return res.json({
        title: String(obj.title || '').trim() || baseTitle,
        topic: String(obj.topic || '').trim() || 'General',
        cards: normalized
      });
    }

    if (outputMode === 'quiz') {
      const raw = await generateNotesWithGemini([
        {
          text: [
            'Read this entire document.',
            'Output ONLY valid JSON (no markdown, no code fences) with this exact shape:',
            '{"title":"short title","topic":"short label","questions":[{"question":"...","options":["A","B","C","D"],"correctIndex":0}]}',
            'Create 10-20 multiple-choice questions with exactly 4 options each. correctIndex is 0-3.',
            'If the file is unreadable, return {"title":"Unreadable","topic":"General","questions":[]}.'
          ].join('\n')
        },
        inlinePart
      ]);
      let obj;
      try {
        obj = extractJsonObjectLoose(raw);
      } catch (e) {
        cleanupUploadedFile(req.file.path);
        return res.status(422).json({ error: 'Could not parse quiz from document.' });
      }
      const questions = Array.isArray(obj.questions) ? obj.questions : [];
      const normalized = questions
        .map((q) => {
          const opts = Array.isArray(q.options) ? q.options.map((o) => String(o).trim()).filter(Boolean) : [];
          let idx = Number(q.correctIndex);
          if (Number.isNaN(idx)) idx = 0;
          idx = Math.max(0, Math.min(3, Math.round(idx)));
          return {
            question: String(q.question || '').trim(),
            options: opts.length >= 4 ? opts.slice(0, 4) : opts,
            correctIndex: idx
          };
        })
        .filter((q) => q.question && q.options.length === 4);
      cleanupUploadedFile(req.file.path);
      if (!normalized.length) {
        return res.status(422).json({ error: 'Could not generate a quiz from this document.' });
      }
      return res.json({
        title: String(obj.title || '').trim() || baseTitle,
        topic: String(obj.topic || '').trim() || 'General',
        questions: normalized
      });
    }

    const rawNotes = await generateNotesWithGemini([
      {
        text: [
          'Extract ALL information from this uploaded document and output a polished markdown study sheet.',
          'Do not omit any facts, definitions, numbers, dates, or steps.',
          '',
          'STRICT formatting rules (follow exactly):',
          '1. Start with "## Brief Overview" — a short paragraph summarizing the document.',
          '2. Then "## Key Points" — a bullet list (- ) of the main ideas.',
          '3. Then additional topic sections using "## " headings with a relevant emoji prefix (e.g. "## 🔌 Topic Name").',
          '4. Under each section use "### " subheadings for subtopics.',
          '5. Use blockquotes (> ) for definitions and key concepts.',
          '6. Prefix important callout lines with "Tip:", "Key Insight:", "Definition:", or "Warning:".',
          '7. Use numbered lists (1. 2. 3.) for sequential steps or procedures.',
          '8. Use bullet lists (- ) for non-sequential facts.',
          '9. Put --- horizontal rules between major sections.',
          '10. Keep equations in readable plain text/Unicode. For superscripts use ^ with parentheses for groups: x^2, x^(a+b), x^(n-1). For subscripts use _ with parentheses: a_n, x_(i+1). Never use LaTeX or curly braces {}.',
          '11. No code fences. No long prose paragraphs.',
          '12. When the source has tables, diagrams, or comparison data, reproduce them as markdown tables (| Header | Header |).'
        ].join('\n')
      },
      inlinePart
    ]);
    const notes = await formatNotesForApp(rawNotes, 'document notes');

    cleanupUploadedFile(req.file.path);

    return res.json({
      title: baseTitle,
      notes
    });
  } catch (error) {
    console.error('❌ generate-notes-from-document failed:', error);
    cleanupUploadedFile(req.file?.path);
    return res.status(500).json({ error: error.message || String(error) });
  }
});

// Solve homework problems from uploaded/captured image
app.post('/solve-homework-from-image', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Missing required multipart file field: file' });
    }

    const fileData = fs.readFileSync(req.file.path);
    const base64Data = fileData.toString('base64');
    const mimeType = req.file.mimetype || 'image/jpeg';

    const solution = await generateNotesWithGemini([
      {
        text: [
          'You are an expert homework problem solver.',
          'Analyze this image and solve every visible problem.',
          'If multiple problems are shown, solve each one in order.',
          '',
          'Output markdown with this exact structure:',
          '## Final Answer',
          '- Provide the direct final answer(s) first.',
          '',
          '## Step-by-Step Explanation',
          '1. Show each step clearly and in order.',
          '2. Explain formulas and substitutions briefly.',
          '3. Include units where relevant.',
          '',
          '## Quick Check',
          '- Briefly verify the answer is reasonable.',
          '',
          'Rules:',
          '- Do not omit visible information.',
          '- Keep equations in readable plain text/Unicode (no LaTeX).',
          '- If text is unclear, state assumptions before solving.'
        ].join('\n')
      },
      {
        inline_data: {
          mime_type: mimeType,
          data: base64Data
        }
      }
    ]);

    cleanupUploadedFile(req.file.path);

    return res.json({
      title: 'Homework solution',
      notes: solution
    });
  } catch (error) {
    console.error('❌ solve-homework-from-image failed:', error);
    cleanupUploadedFile(req.file?.path);
    return res.status(500).json({ error: error.message || String(error) });
  }
});

// Transcribe audio and generate notes
app.post('/transcribe-audio', upload.single('file'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Missing required multipart file field: file' });
    }

    const mimeType = req.file.mimetype || 'audio/mp4';
    const originalName = req.file.originalname || 'audio.m4a';

    const transcriptText = await transcribeAudioWithOpenAI(req.file.path, mimeType, originalName);
    const outputMode = normalizeOutputMode(req.body?.outputMode);

    if (outputMode === 'flashcards') {
      const payload = await generateFlashcardsPayloadFromText('audio transcript', transcriptText);
      cleanupUploadedFile(req.file.path);
      if (!payload.cards.length) {
        return res.status(422).json({ error: 'Could not generate flashcards from this audio.' });
      }
      return res.json({
        title: payload.title,
        topic: payload.topic,
        cards: payload.cards
      });
    }

    if (outputMode === 'quiz') {
      const payload = await generateQuizPayloadFromText('audio transcript', transcriptText);
      cleanupUploadedFile(req.file.path);
      if (!payload.questions.length) {
        return res.status(422).json({ error: 'Could not generate a quiz from this audio.' });
      }
      return res.json({
        title: payload.title,
        topic: payload.topic,
        questions: payload.questions
      });
    }

    const notesPrompt = [
      'Convert the following transcript into an exhaustive markdown study sheet.',
      'Do not omit any details from the transcript.',
      '',
      'STRICT formatting rules (follow exactly):',
      '1. Start with "## Brief Overview" — a short paragraph summarizing the content.',
      '2. Then "## Key Points" — a bullet list (- ) of the main ideas.',
      '3. Then additional topic sections using "## " headings with a relevant emoji prefix (e.g. "## 📝 Topic Name").',
      '4. Under each section use "### " subheadings for subtopics.',
      '5. Use blockquotes (> ) for definitions and key concepts.',
      '6. Prefix important callout lines with "Tip:", "Key Insight:", "Definition:", or "Warning:".',
      '7. Use numbered lists (1. 2. 3.) for sequential steps or procedures.',
      '8. Use bullet lists (- ) for non-sequential facts.',
      '9. Put --- horizontal rules between major sections.',
      '10. Keep equations in readable plain text/Unicode. For superscripts use ^ with parentheses for groups: x^2, x^(a+b), x^(n-1). For subscripts use _ with parentheses: a_n, x_(i+1). Never use LaTeX or curly braces {}.',
      '11. No code fences. No long prose paragraphs.',
      '12. When the source has tables, diagrams, or comparison data, reproduce them as markdown tables (| Header | Header |).',
      '',
      'Transcript:',
      transcriptText
    ].join('\n');

    const titlePrompt = [
      'Given the following audio transcript, generate a short, descriptive title (5-10 words max) that captures the main topic.',
      'Return ONLY the title text, nothing else. No quotes, no formatting, no explanation.',
      '',
      'Transcript:',
      transcriptText.slice(0, 3000)
    ].join('\n');

    const [rawNotes, generatedTitle] = await Promise.all([
      generateNotesWithOpenAI(notesPrompt),
      generateNotesWithOpenAI(titlePrompt, { model: 'gpt-4o-mini' })
    ]);
    const notes = await formatNotesForApp(rawNotes, 'audio lecture notes', { forceSecondPass: true });
    const title = generatedTitle.replace(/^["']|["']$/g, '').trim() || 'Lecture notes';

    cleanupUploadedFile(req.file.path);

    return res.json({
      title,
      notes
    });
  } catch (error) {
    console.error('❌ transcribe-audio failed:', error);
    cleanupUploadedFile(req.file?.path);
    return res.status(500).json({ error: error.message || String(error) });
  }
});

// SSE endpoint for live streaming
app.get('/stream/:sessionId', (req, res) => {
  const { sessionId } = req.params;
  
  console.log(`📡 SSE stream connection request for session: ${sessionId}`);
  
  // Set headers for SSE
  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('X-Accel-Buffering', 'no'); // Disable buffering for nginx
  
  // Store the response for this session
  activeStreams.set(sessionId, res);
  console.log(`✅ Registered stream for session: ${sessionId} (total active: ${activeStreams.size})`);
  
  // Send initial connection message
  try {
    res.write(`data: ${JSON.stringify({ type: 'connected', sessionId, timestamp: Date.now() })}\n\n`);
  } catch (error) {
    console.error(`Error sending initial connection message:`, error);
  }
  
  // Handle client disconnect
  req.on('close', () => {
    console.log(`📡 Client disconnected from stream: ${sessionId}`);
    activeStreams.delete(sessionId);
    if (!res.destroyed) {
      res.end();
    }
  });
  
  req.on('error', (error) => {
    console.error(`📡 Stream error for ${sessionId}:`, error);
    activeStreams.delete(sessionId);
  });
});

// Helper function to send frame to stream
function sendFrame(sessionId, frameData, metadata = {}) {
  const res = activeStreams.get(sessionId);
  if (res && !res.destroyed) {
    try {
      res.write(`data: ${JSON.stringify({ 
        type: 'frame', 
        frame: frameData,
        timestamp: Date.now(),
        ...metadata
      })}\n\n`);
    } catch (error) {
      console.error(`Error sending frame to ${sessionId}:`, error);
      activeStreams.delete(sessionId);
    }
  }
}

// Helper function to send event to stream
function sendEvent(sessionId, eventType, data = {}) {
  const res = activeStreams.get(sessionId);
  if (res && !res.destroyed) {
    try {
      res.write(`data: ${JSON.stringify({ 
        type: eventType,
        timestamp: Date.now(),
        ...data
      })}\n\n`);
    } catch (error) {
      console.error(`Error sending event to ${sessionId}:`, error);
      activeStreams.delete(sessionId);
    }
  }
}

// Main automation endpoint
app.post('/automate', async (req, res) => {
  // Set timeout for the response (45 seconds max)
  req.setTimeout(45000);
  res.setTimeout(45000);
  
  let browser = null;
  let page = null;
  
  try {
    const { jobUrl, applicationData, answers, streamSessionId } = req.body;
    
    if (!jobUrl || !applicationData) {
      return res.status(400).json({ 
        success: false, 
        error: 'Missing required fields: jobUrl and applicationData' 
      });
    }
    
    console.log(`🚀 Starting automation for: ${jobUrl}`);
    
    // Configure residential proxy (like sorce.jobs)
    const proxyConfig = getProxyConfig();
    const launchArgs = [
      '--no-sandbox',
      '--disable-setuid-sandbox',
      '--disable-dev-shm-usage',
      '--disable-blink-features=AutomationControlled', // Hide automation flags
      '--disable-features=IsolateOrigins,site-per-process',
      '--disable-web-security',
      '--disable-features=VizDisplayCompositor'
    ];
    
    // Add proxy server if configured
    if (proxyConfig && proxyConfig.server) {
      launchArgs.push(`--proxy-server=${proxyConfig.server}`);
      console.log(`🌐 Using residential proxy: ${proxyConfig.server.replace(/:[^:]*$/, ':****')}`);
    }
    
    browser = await chromium.launch({
      headless: true,
      args: launchArgs
    });
    
    // Rotate user agents and fingerprints to avoid detection (like sorce.jobs)
    const userAgents = [
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
      'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    ];
    
    const viewports = [
      { width: 1920, height: 1080 },
      { width: 1366, height: 768 },
      { width: 1536, height: 864 },
      { width: 1440, height: 900 },
      { width: 1280, height: 720 }
    ];
    
    const timezones = [
      { id: 'America/New_York', lat: 40.7128, lon: -74.0060 },
      { id: 'America/Los_Angeles', lat: 34.0522, lon: -118.2437 },
      { id: 'America/Chicago', lat: 41.8781, lon: -87.6298 },
      { id: 'America/Denver', lat: 39.7392, lon: -104.9903 }
    ];
    
    // Randomly select fingerprint
    const randomUA = userAgents[Math.floor(Math.random() * userAgents.length)];
    const randomViewport = viewports[Math.floor(Math.random() * viewports.length)];
    const randomTz = timezones[Math.floor(Math.random() * timezones.length)];
    
    // More realistic browser context with rotated fingerprinting (like sorce.jobs)
    const contextOptions = {
      userAgent: randomUA,
      viewport: randomViewport,
      locale: 'en-US',
      timezoneId: randomTz.id,
      permissions: ['geolocation'],
      geolocation: { latitude: randomTz.lat, longitude: randomTz.lon },
      colorScheme: 'light',
      // Add extra headers to look more like a real browser
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
    };
    
    // Add proxy to context if configured (Playwright handles proxy auth via launch args)
    // The proxy is already set in launch args, so we don't need to set it here
    
    const context = await browser.newContext(contextOptions);
    
    // Remove webdriver property and add more anti-detection measures
    await context.addInitScript(() => {
      // Remove webdriver property
      Object.defineProperty(navigator, 'webdriver', {
        get: () => false,
      });
      
      // Override the plugins property to use a custom getter
      Object.defineProperty(navigator, 'plugins', {
        get: () => [1, 2, 3, 4, 5],
      });
      
      // Override the languages property to use a custom getter
      Object.defineProperty(navigator, 'languages', {
        get: () => ['en-US', 'en'],
      });
      
      // Override chrome property
      window.chrome = {
        runtime: {},
      };
      
      // Override permissions
      const originalQuery = window.navigator.permissions.query;
      window.navigator.permissions.query = (parameters) => (
        parameters.name === 'notifications' ?
          Promise.resolve({ state: Notification.permission }) :
          originalQuery(parameters)
      );
      
      // Add more realistic properties
      Object.defineProperty(navigator, 'hardwareConcurrency', {
        get: () => 8,
      });
      
      Object.defineProperty(navigator, 'deviceMemory', {
        get: () => 8,
      });
      
      // Override getBattery if it exists
      if (navigator.getBattery) {
        navigator.getBattery = () => Promise.resolve({
          charging: true,
          chargingTime: 0,
          dischargingTime: Infinity,
          level: 1.0
        });
      }
      
      // Remove automation indicators
      delete window.cdc_adoQpoasnfa76pfcZLmcfl_Array;
      delete window.cdc_adoQpoasnfa76pfcZLmcfl_Promise;
      delete window.cdc_adoQpoasnfa76pfcZLmcfl_Symbol;
    });
    
    page = await context.newPage();
    
    console.log(`🌐 Navigating to: ${jobUrl}`);
    
    // Send navigation event if streaming
    if (streamSessionId) {
      sendEvent(streamSessionId, 'navigating', { url: jobUrl });
    }
    
    // Follow redirects and wait for final page to load
    try {
      await page.goto(jobUrl, { 
        waitUntil: 'domcontentloaded', 
        timeout: 20000 
      });
      
      // Add human-like delay and mouse movement to avoid detection
      await page.waitForTimeout(1000 + Math.random() * 2000); // Random delay 1-3 seconds
      
      // Simulate human-like mouse movement
      try {
        await page.mouse.move(100, 100);
        await page.waitForTimeout(200);
        await page.mouse.move(200, 200);
        await page.waitForTimeout(200);
      } catch (e) {
        // Ignore mouse movement errors
      }
      
      // Wait for any redirects to complete
      await page.waitForTimeout(2000);
      
      // Check if URL changed (redirect happened)
      const finalUrl = page.url();
      if (finalUrl !== jobUrl) {
        console.log(`🔄 Redirected from ${jobUrl} to ${finalUrl}`);
        // Wait a bit more after redirect
        await page.waitForTimeout(2000);
      }
      
      // Send frame after navigation if streaming
      if (streamSessionId) {
        try {
          const screenshot = await page.screenshot({ encoding: 'base64' });
          sendFrame(streamSessionId, screenshot.toString('base64'), { 
            step: 'navigated',
            url: finalUrl 
          });
        } catch (e) {
          console.log('⚠️ Failed to capture navigation screenshot:', e.message);
        }
      }
    } catch (error) {
      console.log(`⚠️ Navigation error: ${error.message}`);
      // Continue anyway - page might have loaded partially
    }
    
    // Wait a bit for page to fully load
    await page.waitForTimeout(2000);
    
    // Check for bot detection pages
    const pageContent = await page.content();
    const pageText = await page.textContent('body').catch(() => '');
    const currentUrl = page.url();
    
    // Detect bot detection pages - be more specific to avoid false positives
    // Only trigger if we see clear bot detection messages AND can't proceed
    const botDetectionKeywords = [
      'suspicious behaviour',
      'suspicious behavior', 
      'unusual behaviour',
      'unusual behavior',
      'automated access detected',
      'bot detected',
      'access denied',
      'blocked',
      'verify you are human',
      'captcha'
    ];
    
    const hasBotDetectionKeyword = botDetectionKeywords.some(keyword => 
      pageText.toLowerCase().includes(keyword.toLowerCase())
    );
    
    // Also check if page has CAPTCHA or verification elements
    const hasCaptcha = await page.$('iframe[src*="recaptcha"], iframe[src*="hcaptcha"], .g-recaptcha, #captcha, [class*="captcha"]').catch(() => null);
    
    // Check if we have form fields to fill (if yes, we can still try to proceed)
    const hasFormFields = await page.$('input:not([type="hidden"]), textarea, select').catch(() => null);
    
    // Only block if we have bot detection AND no form fields (can't proceed)
    const isBotDetectionPage = hasBotDetectionKeyword && !hasFormFields;
    
    // If we have bot detection but also have form fields, try to proceed anyway
    if (hasBotDetectionKeyword && hasFormFields) {
      console.log('⚠️ Bot detection warning detected, but form fields are present - attempting to proceed');
    }
    
    // Only block if we're actually on a bot detection page with no way to proceed
    if (isBotDetectionPage || (hasCaptcha && !hasFormFields)) {
      console.log('⚠️ Bot detection page detected');
      const screenshot = await page.screenshot({ encoding: 'base64' });
      
      await browser.close();
      browser = null;
      
      // Determine which site detected the bot (generic message, don't call out specific sites)
      let siteName = 'job board';
      if (currentUrl.includes('indeed.com')) {
        siteName = 'Indeed';
      } else if (currentUrl.includes('linkedin.com')) {
        siteName = 'LinkedIn';
      } else if (currentUrl.includes('glassdoor.com')) {
        siteName = 'Glassdoor';
      } else if (currentUrl.includes('ziprecruiter.com')) {
        siteName = 'ZipRecruiter';
      }
      
      return res.json({
        success: false,
        filledFields: 0,
        atsSystem: siteName.toLowerCase(),
        error: `Bot detection: This job board has detected automated access. Please apply manually through the website.`,
        screenshot: screenshot.toString('base64'),
        questions: [],
        needsUserInput: false,
        submitted: false,
        botDetected: true
      });
    }
    
    // If we're on a job board listing page, try to follow redirect to actual application form
    // (handled by the job board listing detection code below)
    
    // Detect ATS system
    const atsSystem = detectATSSystem(jobUrl, pageContent);
    console.log(`🔍 Detected ATS: ${atsSystem}`);
    
    // Check if we're on a job board listing page (not an application form)
    const currentUrlAfterLoad = page.url();
    const isJobBoardListing = currentUrlAfterLoad.includes('indeed.com') ||
                             currentUrlAfterLoad.includes('monster.com') ||
                             currentUrlAfterLoad.includes('glassdoor.com') ||
                             currentUrlAfterLoad.includes('ziprecruiter.com') ||
                             pageText.includes('Filter results') ||
                             pageText.includes('Jobs in') ||
                             pageContent.includes('job-listing') ||
                             pageContent.includes('job-card');
    
    if (isJobBoardListing) {
      console.log('⚠️ WARNING: On job board listing page, not application form');
      console.log('⚠️ This URL may not be a direct application link');
      
      // Try to extract the actual application URL from the page
      console.log('🔍 Attempting to find application form URL...');
      
      try {
        // First, try to find an "Apply" or "Easy Apply" button/link
        const applyButtonSelectors = [
          'a[href*="apply"]',
          'a[href*="application"]',
          'a[href*="careers"]',
          'button:has-text("Apply")',
          'button:has-text("Easy Apply")',
          'a:has-text("Apply")',
          'a:has-text("Easy Apply")',
          '[data-testid*="apply"]',
          '[data-automation-id*="apply"]',
          '.apply-button',
          '.apply-link',
          '#apply-button',
          '#apply-link'
        ];
        
        let foundApplyButton = false;
        
        for (const selector of applyButtonSelectors) {
          try {
            // Try to find the element
            const applyButton = await page.$(selector);
            if (applyButton) {
              // Check if it's a link (has href)
              const href = await applyButton.evaluate(el => el.href || el.getAttribute('href'));
              
              if (href && !href.includes('javascript:') && !href.includes('#')) {
                console.log(`🔗 Found apply link: ${href} - navigating directly`);
                await page.goto(href, { waitUntil: 'domcontentloaded', timeout: 15000 });
                await page.waitForTimeout(3000);
                foundApplyButton = true;
                break;
              } else {
                // It's a button, try clicking it
                console.log(`🔘 Found apply button: ${selector} - clicking to navigate`);
                await applyButton.click();
                
                // Wait for navigation (could be same page or new page)
                try {
                  await Promise.race([
                    page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 10000 }),
                    page.waitForTimeout(5000)
                  ]);
                } catch (navError) {
                  // Navigation timeout is okay - might be same-page form
                }
                
                await page.waitForTimeout(3000);
                foundApplyButton = true;
                break;
              }
            }
          } catch (e) {
            continue;
          }
        }
        
        if (!foundApplyButton) {
          // Try to extract application URL from page content (some sites embed it)
          try {
            const applicationUrl = await page.evaluate(() => {
              // Look for common patterns in page source
              const scripts = Array.from(document.querySelectorAll('script'));
              for (const script of scripts) {
                const content = script.textContent || '';
                // Look for URLs in JSON or JavaScript
                const urlMatch = content.match(/["'](https?:\/\/[^"']*\/apply[^"']*)["']/i) ||
                                content.match(/["'](https?:\/\/[^"']*\/application[^"']*)["']/i) ||
                                content.match(/applyUrl["']?\s*[:=]\s*["']([^"']+)["']/i);
                if (urlMatch && urlMatch[1]) {
                  return urlMatch[1];
                }
              }
              
              // Look for meta tags or data attributes
              const metaTags = Array.from(document.querySelectorAll('meta[property*="url"], meta[name*="url"]'));
              for (const meta of metaTags) {
                const content = meta.getAttribute('content');
                if (content && (content.includes('/apply') || content.includes('/application'))) {
                  return content;
                }
              }
              
              return null;
            });
            
            if (applicationUrl) {
              console.log(`🔗 Extracted application URL from page: ${applicationUrl}`);
              await page.goto(applicationUrl, { waitUntil: 'domcontentloaded', timeout: 15000 });
              await page.waitForTimeout(3000);
              foundApplyButton = true;
            }
          } catch (e) {
            console.log('⚠️ Could not extract application URL from page content');
          }
        }
        
        if (!foundApplyButton) {
          console.log('⚠️ Could not find apply button or application URL - may need manual application');
          console.log('⚠️ Current page might already be the application form, or requires manual navigation');
        } else {
          // Update page content after navigation
          const newPageText = await page.textContent('body').catch(() => '') || '';
          const newPageContent = await page.content();
          const newUrl = page.url();
          
          // Check if we're still on a listing page
          const stillOnListing = newUrl.includes('indeed.com') ||
                                newPageText.includes('Filter results') ||
                                newPageText.includes('Jobs in');
          
          if (stillOnListing) {
            console.log('⚠️ Still on job board listing after navigation - application form may not be accessible');
          } else {
            console.log('✅ Navigated to application form or job details page');
          }
        }
      } catch (e) {
        console.log(`⚠️ Error trying to find application form: ${e.message}`);
      }
    }
    
    // Wait for dynamic content (reduced timeout)
    await page.waitForTimeout(1000);
    
    // Check if we were redirected to OAuth/login page (LinkedIn, Google, etc.)
    const currentUrlBeforeFill = page.url();
    const isOAuthRedirect = currentUrlBeforeFill.includes('linkedin.com') ||
                            currentUrlBeforeFill.includes('accounts.google.com') ||
                            currentUrlBeforeFill.includes('login') ||
                            currentUrlBeforeFill.includes('oauth') ||
                            currentUrlBeforeFill.includes('auth');
    
    if (isOAuthRedirect && atsSystem === 'lever') {
      console.log('⚠️ Detected OAuth redirect (likely LinkedIn) - Lever may require authentication');
      console.log('⚠️ Attempting to navigate back to Lever form...');
      
      // Try to go back or wait for redirect back to Lever
      try {
        // Wait a bit to see if it redirects back automatically
        await page.waitForTimeout(5000);
        
        const urlAfterWait = page.url();
        if (urlAfterWait.includes('lever.co') || urlAfterWait.includes('lever')) {
          console.log('✅ Redirected back to Lever form');
        } else {
          // Try going back
          await page.goBack({ waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
          await page.waitForTimeout(2000);
          
          const urlAfterBack = page.url();
          if (urlAfterBack.includes('lever.co') || urlAfterBack.includes('lever')) {
            console.log('✅ Navigated back to Lever form');
          } else {
            console.log('⚠️ Still on OAuth page - form may require manual authentication');
            // Continue anyway - might be able to fill some fields
          }
        }
      } catch (e) {
        console.log('⚠️ Error handling OAuth redirect:', e.message);
      }
    }
    
    // Fill form fields
    console.log('📝 Filling application form...');
    if (streamSessionId) {
      sendEvent(streamSessionId, 'filling_form');
    }
    
    const filledFields = await fillApplicationForm(page, applicationData, streamSessionId);
    console.log(`✅ Filled ${filledFields} fields`);
    
    // Send frame after form filling if streaming
    if (streamSessionId) {
      try {
        const screenshot = await page.screenshot({ encoding: 'base64' });
        sendFrame(streamSessionId, screenshot.toString('base64'), { 
          step: 'form_filled',
          filledFields 
        });
      } catch (e) {
        console.log('⚠️ Failed to capture form filled screenshot:', e.message);
      }
    }
    
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
    const urlBeforeSubmit = page.url();
    
    try {
      // Only try to submit if we actually filled fields or uploaded resume
      if (filledFields > 0 || resumeUploaded) {
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
              
              // Wait for navigation or page change (up to 5 seconds)
              try {
                await Promise.race([
                  page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 5000 }),
                  page.waitForTimeout(5000)
                ]);
              } catch (navError) {
                // Navigation timeout is okay - page might update without navigation
              }
              
              // Wait a bit more for any async updates
              await page.waitForTimeout(2000);
              
              // Send frame after clicking submit if streaming
              if (streamSessionId) {
                try {
                  const screenshot = await page.screenshot({ encoding: 'base64' });
                  sendFrame(streamSessionId, screenshot.toString('base64'), { 
                    step: 'submitted',
                    action: 'clicked_submit'
                  });
                } catch (e) {
                  // Ignore screenshot errors
                }
              }
              
              // Verify submission by checking for confirmation indicators
              const currentUrl = page.url();
              const pageText = await page.textContent('body').catch(() => '') || '';
              const pageContent = await page.content();
              
              // Check for confirmation text
              const confirmationIndicators = [
                'thank you',
                'application received',
                'application submitted',
                'successfully applied',
                'confirmation',
                'your application has been',
                'we have received your application'
              ];
              
              const hasConfirmationText = confirmationIndicators.some(indicator => 
                pageText.toLowerCase().includes(indicator)
              );
              
              // Check if URL changed (often indicates successful submission)
              const urlChanged = currentUrl !== urlBeforeSubmit && 
                                 !currentUrl.includes('indeed.com') &&
                                 !currentUrl.includes('monster.com');
              
              // Check if we're on a job listing page (bad sign - means we didn't get to application form)
              const isJobListingPage = currentUrl.includes('indeed.com') ||
                                       pageText.includes('Filter results') ||
                                       pageText.includes('Jobs in') ||
                                       pageContent.includes('job-listing') ||
                                       pageContent.includes('job-card');
              
              // Only mark as submitted if we have clear evidence
              if (hasConfirmationText || (urlChanged && !isJobListingPage)) {
                submitted = true;
                console.log('✅ Form submitted successfully - confirmation detected');
              } else if (isJobListingPage) {
                console.log('⚠️ Still on job listing page - form may not have been submitted');
                submitted = false;
              } else {
                // URL changed but no clear confirmation - be conservative
                console.log('⚠️ Page changed but no clear confirmation - marking as uncertain');
                submitted = false;
              }
              
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
              
              // Wait for navigation
              try {
                await Promise.race([
                  page.waitForNavigation({ waitUntil: 'domcontentloaded', timeout: 5000 }),
                  page.waitForTimeout(5000)
                ]);
              } catch (navError) {
                // Navigation timeout is okay
              }
              
              await page.waitForTimeout(2000);
              
              // Verify submission
              const currentUrl = page.url();
              const pageText = await page.textContent('body').catch(() => '') || '';
              const confirmationIndicators = [
                'thank you', 'application received', 'application submitted',
                'successfully applied', 'confirmation'
              ];
              
              const hasConfirmationText = confirmationIndicators.some(indicator => 
                pageText.toLowerCase().includes(indicator)
              );
              
              const urlChanged = currentUrl !== urlBeforeSubmit;
              const isJobListingPage = currentUrl.includes('indeed.com');
              
              if (hasConfirmationText || (urlChanged && !isJobListingPage)) {
                submitted = true;
                console.log('✅ Form submitted via form.submit() - confirmation detected');
              } else {
                console.log('⚠️ Form.submit() called but no confirmation detected');
                submitted = false;
              }
            }
          } catch (e) {
            console.log('⚠️ Could not submit form automatically');
          }
        }
      } else {
        console.log('⚠️ No fields filled - skipping form submission');
      }
    } catch (error) {
      console.log('⚠️ Form submission error:', error.message);
    }
    
    // Wait a bit more before taking screenshot to ensure page is stable
    await page.waitForTimeout(1000);
    
    // Check if we're on an OAuth/login page (shouldn't be after form filling)
    const finalUrl = page.url();
    const isOnOAuthPage = finalUrl.includes('linkedin.com') && 
                         (finalUrl.includes('oauth') || finalUrl.includes('auth') || finalUrl.includes('User Agreement') || finalUrl.includes('user-agreement'));
    
    if (isOnOAuthPage && atsSystem === 'lever') {
      console.log('⚠️ Still on OAuth/login page - Lever form may require manual authentication');
      console.log('⚠️ Form was filled before redirect, but submission cannot be completed automatically');
      
      // Try to navigate back one more time
      try {
        await page.goBack({ waitUntil: 'domcontentloaded', timeout: 10000 }).catch(() => {});
        await page.waitForTimeout(2000);
      } catch (e) {
        // Ignore errors
      }
    }
    
    // Take screenshot
    const screenshot = await page.screenshot({ encoding: 'base64' });
    
    // Check if OAuth was required (for Lever with LinkedIn)
    const requiresOAuth = isOnOAuthPage && atsSystem === 'lever';
    
    // Send final frame and completion event if streaming
    if (streamSessionId) {
      sendFrame(streamSessionId, screenshot.toString('base64'), { 
        step: 'completed',
        submitted,
        filledFields: filledFields + (resumeUploaded ? 1 : 0)
      });
      sendEvent(streamSessionId, 'completed', {
        success: true,
        filledFields: filledFields + (resumeUploaded ? 1 : 0),
        submitted,
        requiresOAuth
      });
      
      // Close the stream
      const streamRes = activeStreams.get(streamSessionId);
      if (streamRes && !streamRes.destroyed) {
        streamRes.end();
        activeStreams.delete(streamSessionId);
      }
    }
    
    console.log(`✅ Automation completed - Filled: ${filledFields + (resumeUploaded ? 1 : 0)} fields, Submitted: ${submitted}`);
    if (requiresOAuth) {
      console.log('⚠️ OAuth authentication required - form filled but cannot submit automatically');
    }
    
    res.json({
      success: true,
      filledFields: filledFields + (resumeUploaded ? 1 : 0),
      atsSystem,
      screenshot: screenshot.toString('base64'),
      questions: [],
      needsUserInput: false,
      submitted: submitted,
      requiresOAuth: requiresOAuth || undefined,
      error: requiresOAuth ? 'This application requires LinkedIn authentication. The form was filled, but you need to manually authenticate and submit on the company website.' : undefined,
      streamSessionId: streamSessionId || undefined
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
      
      // Human-like typing (like sorce.jobs) - type character by character with random delays
      await page.focus(selector);
      await page.waitForTimeout(100 + Math.random() * 200); // Random delay before typing
      
      // Type character by character with realistic delays
      for (let i = 0; i < value.length; i++) {
        await page.type(selector, value[i], { delay: 50 + Math.random() * 100 }); // 50-150ms per character
      }
      
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
async function fillApplicationForm(page, data, streamSessionId = null) {
  let filledCount = 0;
  
  // Helper to send frame during form filling
  const sendFrameIfStreaming = async (step) => {
    if (streamSessionId) {
      try {
        const screenshot = await page.screenshot({ encoding: 'base64' });
        sendFrame(streamSessionId, screenshot.toString('base64'), { step });
      } catch (e) {
        // Ignore screenshot errors during streaming
      }
    }
  };
  
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
    await sendFrameIfStreaming('filled_email');
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
    const jobs = await page.evaluate(({ keywords, location }) => {
      const jobList = [];
      
      // Try multiple selectors for job titles (expanded list for Workday)
      const jobSelectors = [
        '[data-automation-id="jobTitle"]',
        '[data-automation-id="jobPosting"]',
        '[data-automation-id="jobPostingTitle"]',
        'a[data-automation-id="jobTitle"]',
        'a[href*="/jobs/"]',
        'a[href*="/job/"]',
        'a[href*="/careers/"]',
        '[data-testid="job-title"]',
        '[data-testid="job-posting"]',
        '.job-title',
        '.job-posting',
        '.job-card',
        '[class*="job"]',
        '[class*="Job"]',
        '[class*="posting"]',
        '[class*="Posting"]',
        'li[data-automation-id*="job"]',
        'div[data-automation-id*="job"]'
      ];
      
      let jobElements = [];
      let foundSelector = null;
      for (const selector of jobSelectors) {
        try {
          const elements = document.querySelectorAll(selector);
          if (elements.length > 0) {
            jobElements = Array.from(elements);
            foundSelector = selector;
            console.log(`Found ${elements.length} elements with selector: ${selector}`);
            break;
          }
        } catch (e) {
          // Invalid selector, continue
          continue;
        }
      }
      
      // If no jobs found, log what's on the page for debugging
      if (jobElements.length === 0) {
        console.log('No job elements found. Page structure:');
        console.log('Title:', document.title);
        console.log('URL:', window.location.href);
        // Try to find any links that might be jobs
        const allLinks = document.querySelectorAll('a[href*="job"], a[href*="career"], a[href*="position"]');
        console.log(`Found ${allLinks.length} potential job links`);
        if (allLinks.length > 0) {
          console.log('Sample links:', Array.from(allLinks).slice(0, 5).map(l => ({ text: l.textContent?.trim(), href: l.href })));
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
          
          // Keyword filtering (very lenient - only filter if we have many jobs)
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
            
            // Very lenient: only filter if we have 20+ jobs (was 10)
            // This ensures we get jobs even if keywords don't match exactly
            if (!matchesKeyword && jobList.length >= 20) {
              shouldInclude = false;
            }
          }
          
          if (shouldInclude && title) {
            jobList.push({
              title: title,
              company: window.location.hostname.split('.')[0] || 'Unknown',
              location: jobLocation,
              description: description || null, // Full description - no truncation
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
    }, { keywords: keywords || '', location: location || '' });
    
    if (jobs.length > 0) {
      console.log(`✅ Scraped ${jobs.length} jobs from ${companyUrl}`);
    } else {
      console.log(`⚠️ Scraped 0 jobs from ${companyUrl} - check browser console logs for details`);
    }
    
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


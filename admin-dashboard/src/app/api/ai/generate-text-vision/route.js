import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_VISION_MODEL = 'google/gemma-3-27b-it:free';

// ── Get vision model from app_settings ──
async function getVisionModel() {
  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data } = await supabase.from('app_settings').select('value').eq('key', 'vision_model').single();
    return data?.value || DEFAULT_VISION_MODEL;
  } catch {
    return DEFAULT_VISION_MODEL;
  }
}

// ── Build vision prompt for literature ──
function buildVisionPrompt(type, poseName, category, nameHindi, nameSanskrit, userInstruction) {
  const catHindi = category === 'yoga' ? 'योग' : category === 'pranayama' ? 'प्राणायाम' : 'ध्यान';
  const lang = type === 'literature_hi' ? 'Hindi' : 'English';
  const langInstruction = type === 'literature_hi'
    ? 'हिंदी में लिखें। पूरा content हिंदी में होना चाहिए।'
    : 'Write in English.';

  return `You are a scholarly Ayurvedic author writing premium book-style content for the "Dincharya" wellness app.

CONTEXT:
- Pose/Technique: "${poseName}"${nameHindi ? ` (${nameHindi})` : ''}${nameSanskrit ? ` — Sanskrit: ${nameSanskrit}` : ''}
- Category: ${category} (${catHindi})
- Language: ${lang}

TASK:
The user has uploaded reference images from a book about this ${category} technique. 
You must:
1. READ every image carefully — extract ALL text, meanings, and context from the book pages
2. REPRODUCE the content faithfully in ${lang} — same to same, nothing should be missed
3. ADD your own knowledge to enrich it — make it MORE detailed, interesting, and readable
4. NEVER remove or skip any content from the book — only ADD to it
5. Think about WHERE images should go in the content and mark those places

${langInstruction}

FORMATTING RULES (MANDATORY — the app parses these):
- Use "## Heading Text" for section headings (with ## prefix)
- Use **bold** for emphasis and key terms
- Use *italic* for Sanskrit terms or special phrases
- Use "{{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}}" for left-floated image (text wraps right). Place text IMMEDIATELY after the marker.
- Use "{{IMG:POSE_IMAGE_PLACEHOLDER}}" for centered full-width image
- Separate pages with "---PAGE---" on its own line
- Each page should have 1-2 images and 1-2 headings
- Write in flowing paragraphs, NOT bullet lists
- Content should feel like a premium illustrated book — engaging, authoritative, readable

STRUCTURE (3-5 pages):
Page 1: Origin & History — ancient texts, cultural significance
Page 2: Detailed Technique — body mechanics, alignment, breathing
Page 3: Spiritual Significance — chakras, prana, deeper meaning
Page 4: Variations & Practice Integration (if applicable)

Each page ~200-350 words. Be thorough and scholarly.

${userInstruction ? `\nADDITIONAL INSTRUCTION FROM ADMIN:\n${userInstruction}` : ''}

CRITICAL: Output ONLY the literature text with ---PAGE--- separators. No JSON, no code blocks, no meta-commentary.`;
}

// ── Fetch with timeout ──
async function fetchWithTimeout(url, options, timeoutMs = 120000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(url, { ...options, signal: controller.signal });
    clearTimeout(timer);
    return response;
  } catch (err) {
    clearTimeout(timer);
    if (err.name === 'AbortError') throw new Error('Vision AI timed out. Book pages may be too large. Try fewer images.');
    throw err;
  }
}

export async function POST(request) {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return NextResponse.json({ error: 'OPENROUTER_API_KEY not configured' }, { status: 500 });
  }

  try {
    const body = await request.json();
    const { type, poseName, category, nameHindi, nameSanskrit, userInstruction, images } = body;

    if (!poseName) {
      return NextResponse.json({ error: 'Missing required field: poseName' }, { status: 400 });
    }

    if (!images || !Array.isArray(images) || images.length === 0) {
      return NextResponse.json({ error: 'No images provided. Use the standard text route for non-image requests.' }, { status: 400 });
    }

    if (images.length > 10) {
      return NextResponse.json({ error: 'Maximum 10 images allowed per request' }, { status: 400 });
    }

    // Get configured vision model
    const visionModel = await getVisionModel();
    console.log(`🔵 Vision model: ${visionModel}, Images: ${images.length}, Type: ${type}`);

    // Build the prompt
    const prompt = buildVisionPrompt(type || 'literature_en', poseName, category || 'yoga', nameHindi, nameSanskrit, userInstruction);

    // Build message content with images (OpenAI-compatible multimodal format)
    const contentParts = [];

    // Add each image
    for (let i = 0; i < images.length; i++) {
      let imageData = images[i];

      // Ensure proper data URI format
      if (!imageData.startsWith('data:')) {
        imageData = `data:image/jpeg;base64,${imageData}`;
      }

      contentParts.push({
        type: 'image_url',
        image_url: { url: imageData },
      });
    }

    // Add the text prompt
    contentParts.push({
      type: 'text',
      text: prompt,
    });

    const response = await fetchWithTimeout(OPENROUTER_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'HTTP-Referer': 'https://dincharya.app',
        'X-Title': 'Dincharya Admin - AI Vision Literature',
      },
      body: JSON.stringify({
        model: visionModel,
        messages: [
          {
            role: 'user',
            content: contentParts,
          },
        ],
        temperature: 0.7,
        max_tokens: 6000,
      }),
    }, 120000); // 2 minute timeout for vision

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Vision API error:', response.status, errorText);
      return NextResponse.json({ error: `Vision API error: ${response.status} — ${errorText.substring(0, 200)}` }, { status: 502 });
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content || '';

    if (!content) {
      return NextResponse.json({ error: 'Empty response from Vision AI' }, { status: 502 });
    }

    console.log(`✅ Vision response: ${content.length} chars for ${poseName}`);

    return NextResponse.json({ result: content.trim(), type: type || 'literature_en' });
  } catch (error) {
    console.error('Vision generation error:', error);
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 });
  }
}

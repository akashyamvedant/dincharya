import { NextResponse } from 'next/server';

const SARVAM_API_URL = 'https://api.sarvam.ai/v1/chat/completions';
const SARVAM_MODEL = 'sarvam-105b';

// ── System prompts for each content type ──
function buildSystemPrompt(type, poseName, category, nameHindi, nameSanskrit, existingContent) {
  const catHindi = category === 'yoga' ? 'योग' : category === 'pranayama' ? 'प्राणायाम' : 'ध्यान';
  const catTechnique = category === 'yoga' ? 'asana/pose' : category === 'pranayama' ? 'breathing technique' : 'meditation technique';

  const poseContext = `Pose/Technique: "${poseName}"${nameHindi ? ` (${nameHindi})` : ''}${nameSanskrit ? ` — Sanskrit: ${nameSanskrit}` : ''}\nCategory: ${category}\n`;

  const existingContext = existingContent
    ? `\n--- EXISTING CONTENT (for reference, user may ask to improve/change/regenerate) ---\n${existingContent}\n--- END EXISTING CONTENT ---\n`
    : '';

  const prompts = {
    description: `You are an expert Ayurvedic ${category} instructor and content writer for the "Dincharya" wellness app.

${poseContext}${existingContext}
Your task: Generate or improve the Description, Benefits, and Precautions for this ${catTechnique}.

Return a JSON object with EXACTLY these keys:
- "description": A detailed 2-3 sentence description explaining what this ${catTechnique} is and its purpose.
- "benefits": An array of 6-8 specific health/wellness benefits (each 1 sentence).
- "precautions": An array of 4-5 precautions/contraindications (each 1 sentence).

CRITICAL: Output ONLY valid JSON. No markdown, no code blocks, no explanation text. Just the raw JSON object.`,

    literature_en: `You are a scholarly Ayurvedic author writing for the "Dincharya" wellness app's Theory section. You write like a premium illustrated book — not plain text.

${poseContext}${existingContext}
Write detailed literature content for this ${catTechnique} in English.

Structure as 3-4 pages separated by the exact string "---PAGE---" on its own line.

FORMATTING RULES (you MUST follow these — the app parses them):
- Use "## Heading Text" for section headings (with ## prefix)
- Use **bold** for emphasis and key terms
- Use *italic* for Sanskrit terms or special phrases
- Use "{{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}}" to place a left-floated image with text wrapping around it. Place text lines IMMEDIATELY after the image marker (no blank line between). The text will flow to the right of the image.
- Use "{{IMG:POSE_IMAGE_PLACEHOLDER}}" for a centered full-width image
- IMPORTANT: Use POSE_IMAGE_PLACEHOLDER as the image URL — the admin will replace it with actual images later
- Each page should have at least 1 image marker and 1-2 headings
- Write in flowing paragraphs, not bullet lists

PAGE STRUCTURE:
Page 1: ## उत्पत्ति एवं इतिहास (Origin & History)
  - Start with {{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}} followed by introductory text
  - Reference ancient texts (Hatha Yoga Pradipika, Yoga Sutras, etc.)
  - Historical context and cultural significance

Page 2: ## तकनीक एवं अभ्यास विधि (Technique & Practice)
  - Include {{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}} showing alignment
  - Detailed technique description, body mechanics, alignment cues
  - Common mistakes and corrections

Page 3: ## आध्यात्मिक एवं ऊर्जा महत्व (Spiritual Significance)
  - Include {{IMG:POSE_IMAGE_PLACEHOLDER}} centered illustration
  - Chakra connections, prana flow, deeper meaning
  - Mantras and meditative aspects

${category === 'yoga' ? 'Page 4: ## विविधताएँ एवं संशोधन (Variations & Modifications)\n  - Beginner/advanced variations, props, accessibility' :
  category === 'pranayama' ? 'Page 4: ## अभ्यास एकीकरण (Practice Integration)\n  - When to practice, duration, combining techniques' :
  'Page 4: ## गहन अभ्यास (Deepening Practice)\n  - Advanced stages, experiences, troubleshooting'}

Each page ~150-250 words. Write authoritatively but accessibly.

CRITICAL: Output ONLY the literature text with ---PAGE--- separators. No JSON, no code blocks. Use the exact formatting markers described above.`,

    literature_hi: `You are a scholarly Ayurvedic author writing in Hindi for the "Dincharya" wellness app. You write like a premium illustrated book.

${poseContext}${existingContext}
"${poseName}"${nameHindi ? ` (${nameHindi})` : ''} (श्रेणी: ${catHindi}) के लिए विस्तृत साहित्य लिखें।

हिंदी में लिखें। 3-4 पृष्ठों में विभाजित करें, प्रत्येक पृष्ठ "---PAGE---" से अलग करें।

फॉर्मेटिंग नियम (अनिवार्य — ऐप इन्हें पार्स करता है):
- "## शीर्षक" शीर्षकों के लिए (## प्रीफिक्स के साथ)
- **बोल्ड** महत्वपूर्ण शब्दों के लिए
- *इटैलिक* संस्कृत शब्दों के लिए
- "{{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}}" बाईं ओर छवि के लिए — इसके ठीक बाद की पंक्तियाँ छवि के दाईं ओर दिखेंगी
- "{{IMG:POSE_IMAGE_PLACEHOLDER}}" केंद्रित पूर्ण-चौड़ाई छवि के लिए
- POSE_IMAGE_PLACEHOLDER ही URL के रूप में उपयोग करें — एडमिन बाद में वास्तविक छवियाँ जोड़ेगा
- प्रत्येक पृष्ठ में कम से कम 1 छवि मार्कर और 1-2 शीर्षक हों

पृष्ठ 1: ## उत्पत्ति और इतिहास
  - {{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}} से शुरू करें
  - प्राचीन ग्रंथों का संदर्भ

पृष्ठ 2: ## विस्तृत तकनीक
  - {{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}} संरेखण दिखाते हुए
  - चरण-दर-चरण तकनीक, शारीरिक संरेखण

पृष्ठ 3: ## आध्यात्मिक महत्व
  - {{IMG:POSE_IMAGE_PLACEHOLDER}} केंद्रित चित्रण
  - चक्र संबंध, प्राण प्रवाह

पृष्ठ 4: ## अभ्यास एकीकरण — कब करें, कैसे करें

प्रत्येक पृष्ठ ~150-200 शब्दों का हो। अधिकारपूर्ण लेकिन सुलभ शैली में लिखें।

CRITICAL: केवल साहित्य पाठ ---PAGE--- विभाजकों के साथ दें। कोई JSON नहीं। ऊपर बताए गए formatting markers का सटीक उपयोग करें।`,

    steps: `You are an expert ${category} instructor creating a step-by-step guided practice for the "Dincharya" wellness app.

${poseContext}${existingContext}
Create detailed steps for this ${catTechnique}.

Return a JSON array of step objects. Each step must have EXACTLY these fields:
- "step_number": integer (starting from 1)
- "name": English name for this step (e.g., "Starting Position", "Inhale & Raise Arms")
- "name_hindi": Hindi name (e.g., "प्रारंभिक स्थिति", "श्वास लें और भुजाएँ ऊपर उठाएँ")
- "instruction": Detailed instruction in English (2-3 sentences, include body alignment cues)
- "instruction_hindi": Same instruction in Hindi
- "breathing": one of "inhale", "exhale", "hold", or "normal"
- "mantra": Sanskrit mantra if applicable (e.g., "ॐ मित्राय नमः"), or empty string ""
- "duration_seconds": realistic integer (5-30 seconds per step)
- "tips": array of 1-2 practical tips as strings

Guidelines:
${category === 'yoga' ? '- For yoga asanas: 4-12 steps depending on complexity. Include preparation, main pose, and release.' :
  category === 'pranayama' ? '- For pranayama: 3-8 steps covering preparation, technique cycles, and completion. Include breath ratios.' :
  '- For meditation: 4-6 phases covering settling, main technique, deepening, and closing.'}
- Be specific about body positioning, hand placement, gaze direction.
- Include realistic durations.
- Keep response concise — do not add extra text outside the JSON array.

CRITICAL: Output ONLY a valid JSON array. No markdown, no code blocks, no explanation. Just the raw JSON array.`
  };

  return prompts[type] || '';
}

// ── Attempt to repair truncated JSON ──
function repairJSON(raw) {
  let str = raw.trim();

  // Remove markdown code block wrappers if present
  const codeBlockMatch = str.match(/```(?:json)?\s*([\s\S]*?)```/);
  if (codeBlockMatch) str = codeBlockMatch[1].trim();

  // Try direct parse first
  try { return JSON.parse(str); } catch {}

  // Extract JSON structure
  const bracketMatch = str.match(/[\[{][\s\S]*/);
  if (!bracketMatch) return null;
  str = bracketMatch[0];

  // Try direct parse of extracted
  try { return JSON.parse(str); } catch {}

  // Attempt repair: close unclosed brackets/braces
  // Count open vs close brackets
  let opens = 0, closesNeeded = [];
  for (const ch of str) {
    if (ch === '[') { opens++; closesNeeded.push(']'); }
    else if (ch === '{') { opens++; closesNeeded.push('}'); }
    else if (ch === ']' || ch === '}') { opens--; closesNeeded.pop(); }
  }

  // If we have unclosed structures, try to truncate to last complete item and close
  if (closesNeeded.length > 0) {
    // For arrays: find the last complete object (ends with }) and truncate there
    const lastCompleteObj = str.lastIndexOf('}');
    if (lastCompleteObj > 0) {
      let repaired = str.substring(0, lastCompleteObj + 1);
      // Remove trailing comma if any
      repaired = repaired.replace(/,\s*$/, '');
      // Close all remaining open brackets
      const remaining = [];
      let o2 = 0;
      for (const ch of repaired) {
        if (ch === '[') { o2++; remaining.push(']'); }
        else if (ch === '{') { o2++; remaining.push('}'); }
        else if (ch === ']' || ch === '}') { o2--; remaining.pop(); }
      }
      repaired += remaining.reverse().join('');
      try { return JSON.parse(repaired); } catch {}
    }
  }

  return null;
}

// ── Fetch with timeout and retry ──
async function fetchWithRetry(url, options, { timeoutMs = 90000, retries = 1 } = {}) {
  for (let attempt = 0; attempt <= retries; attempt++) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);

    try {
      const response = await fetch(url, { ...options, signal: controller.signal });
      clearTimeout(timer);
      return response;
    } catch (err) {
      clearTimeout(timer);
      const isTimeout = err.name === 'AbortError';
      const isConnReset = err.cause?.code === 'ECONNRESET' || err.message?.includes('ECONNRESET');

      if (attempt < retries && (isTimeout || isConnReset)) {
        console.warn(`Sarvam API attempt ${attempt + 1} failed (${isTimeout ? 'timeout' : 'ECONNRESET'}), retrying...`);
        await new Promise(r => setTimeout(r, 2000)); // wait 2s before retry
        continue;
      }

      if (isTimeout) throw new Error('AI server timed out. Please try again.');
      if (isConnReset) throw new Error('Connection to AI server was reset. Please try again.');
      throw err;
    }
  }
}

export async function POST(request) {
  const apiKey = process.env.SARVAM_API_KEY;
  if (!apiKey) {
    return NextResponse.json({ error: 'SARVAM_API_KEY not configured' }, { status: 500 });
  }

  try {
    const body = await request.json();
    const { type, poseName, category, nameHindi, nameSanskrit, userInstruction, existingContent } = body;

    if (!type || !poseName) {
      return NextResponse.json({ error: 'Missing required fields: type, poseName' }, { status: 400 });
    }

    const validTypes = ['description', 'literature_en', 'literature_hi', 'steps'];
    if (!validTypes.includes(type)) {
      return NextResponse.json({ error: `Invalid type: ${type}. Use: ${validTypes.join(', ')}` }, { status: 400 });
    }

    const systemPrompt = buildSystemPrompt(type, poseName, category || 'yoga', nameHindi, nameSanskrit, existingContent);

    // Build messages array — system prompt + user instruction
    const messages = [
      { role: 'system', content: systemPrompt },
    ];

    if (userInstruction && userInstruction.trim()) {
      messages.push({ role: 'user', content: userInstruction.trim() });
    } else {
      const defaults = {
        description: `Generate a complete description, benefits list, and precautions list for "${poseName}".`,
        literature_en: `Write complete English literature content for "${poseName}" with multiple pages.`,
        literature_hi: `"${poseName}" के लिए पूर्ण हिंदी साहित्य सामग्री लिखें, कई पृष्ठों में।`,
        steps: `Create a complete step-by-step guide for "${poseName}" with all required fields.`,
      };
      messages.push({ role: 'user', content: defaults[type] });
    }

    // Use higher max_tokens for steps (complex JSON) vs literature/description
    const maxTokens = type === 'steps' ? 4500 : 3000;

    const response = await fetchWithRetry(SARVAM_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'api-subscription-key': apiKey,
      },
      body: JSON.stringify({
        model: SARVAM_MODEL,
        messages,
        stream: false,
        temperature: 0.7,
        max_tokens: maxTokens,
      }),
    }, { timeoutMs: 90000, retries: 1 });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('Sarvam API error:', response.status, errorText);
      return NextResponse.json({ error: `Sarvam API error: ${response.status}` }, { status: 502 });
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content || '';

    if (!content) {
      return NextResponse.json({ error: 'Empty response from AI' }, { status: 502 });
    }

    // Parse based on type
    if (type === 'description' || type === 'steps') {
      // These should be JSON — try to extract and repair if needed
      let parsed = repairJSON(content);

      if (!parsed) {
        return NextResponse.json({
          error: 'Could not parse AI response as JSON. Try again with a simpler instruction.',
          raw: content.substring(0, 500),
        }, { status: 422 });
      }

      // For steps — if we got a partial array, note it
      if (type === 'steps' && Array.isArray(parsed)) {
        console.log(`Steps generated: ${parsed.length} steps for ${poseName}`);
      }

      return NextResponse.json({ result: parsed, type });
    } else {
      // Literature — return as plain text
      return NextResponse.json({ result: content.trim(), type });
    }
  } catch (error) {
    console.error('AI text generation error:', error);
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 });
  }
}

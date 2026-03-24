import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const OPENROUTER_API_URL = 'https://openrouter.ai/api/v1/chat/completions';
const DEFAULT_IMAGE_MODEL = 'black-forest-labs/flux.2-flex';

// ── Get image model from app_settings ──
async function getImageModel() {
  try {
    const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
    const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
    const supabase = createClient(supabaseUrl, supabaseKey);
    const { data } = await supabase.from('app_settings').select('value').eq('key', 'image_gen_model').single();
    return data?.value || DEFAULT_IMAGE_MODEL;
  } catch {
    return DEFAULT_IMAGE_MODEL;
  }
}

// ── Build contextual image prompts ──
function buildImagePrompt(poseName, category, purpose, stepName) {
  const base = {
    cover: `Professional ${category} illustration: ${poseName}. Indian practitioner performing the ${category === 'yoga' ? 'asana' : category === 'pranayama' ? 'breathing technique' : 'meditation'} in traditional attire. Warm golden hour lighting, serene natural backdrop with soft Himalayan mountains or peaceful ashram garden. Clean composition, high detail, spiritual aesthetic, soft color palette with amber and sage tones. No text overlay, no watermarks.`,
    literature: `Artistic illustration for ${poseName} in ancient Indian manuscript style. Beautiful botanical border, warm parchment tones, traditional Indian art aesthetic with delicate line work. Depicts the essence of ${poseName} through symbolic imagery — lotus, sun rays, flowing energy lines. No text, decorative, ornamental, meditation art style.`,
    step: `Step-by-step ${category} instruction illustration: "${stepName || 'step'}" of ${poseName}. Clear body positioning showing the exact pose/position, clean minimal white background, instructional style with warm skin tones and soft shadows. Professional fitness illustration, anatomically correct, no text labels.`,
  };
  return base[purpose] || base.cover;
}

// ── Extract image URL from various OpenRouter response formats ──
function extractImageUrl(json) {
  // Method 1: Top-level data array
  const dataList = json.data;
  if (Array.isArray(dataList) && dataList.length > 0) {
    for (const item of dataList) {
      if (item?.url) return item.url;
      if (item?.b64_json) return `data:image/png;base64,${item.b64_json}`;
    }
  }

  // Method 2: choices[].message
  const choices = json.choices;
  if (Array.isArray(choices) && choices.length > 0) {
    const message = choices[0]?.message;
    if (message) {
      // FLUX.2 specific: message.images[]
      const images = message.images;
      if (Array.isArray(images) && images.length > 0) {
        for (const img of images) {
          if (typeof img === 'object') {
            const imageUrl = img?.image_url?.url;
            if (imageUrl) return imageUrl;
            if (img?.url) return img.url;
          }
          if (typeof img === 'string' && img.length > 0) return img;
        }
      }

      const content = message.content;

      // String content
      if (typeof content === 'string' && content.length > 0) {
        if (content.startsWith('http')) return content.trim();
        const urlMatch = content.match(/https?:\/\/[^\s)"\\>]+/);
        if (urlMatch) return urlMatch[0];
        if (content.includes('data:image')) {
          const dataMatch = content.match(/data:image\/[^;]+;base64,[A-Za-z0-9+/=]+/);
          if (dataMatch) return dataMatch[0];
        }
      }

      // Array content (multimodal)
      if (Array.isArray(content)) {
        for (const part of content) {
          if (part?.type === 'image_url') {
            const url = part?.image_url?.url;
            if (url) return url;
          }
          if (part?.type === 'text') {
            const urlMatch = (part.text || '').match(/https?:\/\/[^\s)"\\>]+/);
            if (urlMatch) return urlMatch[0];
          }
        }
      }
    }
  }

  // Method 3: Search entire response for any image URL
  const jsonStr = JSON.stringify(json);
  const anyUrlMatch = jsonStr.match(/https?:\/\/[^\s)"\\>\\]+\.(png|jpg|jpeg|webp|gif)[^\s)"\\>\\]*/);
  if (anyUrlMatch) return anyUrlMatch[0];

  return null;
}

export async function POST(request) {
  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) {
    return NextResponse.json({ error: 'OPENROUTER_API_KEY not configured' }, { status: 500 });
  }

  try {
    const body = await request.json();
    const { poseName, category, purpose, stepName } = body;

    if (!poseName || !purpose) {
      return NextResponse.json({ error: 'Missing required fields: poseName, purpose' }, { status: 400 });
    }

    const prompt = buildImagePrompt(poseName, category || 'yoga', purpose, stepName);

    const imageModel = await getImageModel();

    const response = await fetch(OPENROUTER_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`,
        'HTTP-Referer': 'https://dincharya.app',
        'X-Title': 'Dincharya Admin - AI Content Generator',
      },
      body: JSON.stringify({
        model: imageModel,
        modalities: ['image'],
        messages: [
          { role: 'user', content: prompt },
        ],
      }),
    });

    if (!response.ok) {
      const errorText = await response.text();
      console.error('OpenRouter API error:', response.status, errorText);
      return NextResponse.json({ error: `OpenRouter API error: ${response.status}` }, { status: 502 });
    }

    const data = await response.json();
    const imageUrl = extractImageUrl(data);

    if (!imageUrl) {
      console.error('No image URL found in response:', JSON.stringify(data).substring(0, 500));
      return NextResponse.json({ error: 'No image URL found in AI response' }, { status: 422 });
    }

    return NextResponse.json({ imageUrl, purpose });
  } catch (error) {
    console.error('AI image generation error:', error);
    return NextResponse.json({ error: error.message || 'Internal server error' }, { status: 500 });
  }
}

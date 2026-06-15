import { NextResponse } from 'next/server';

const SYSTEM_PROMPT = `You are an expert social media manager for "DinCharya" — a yoga, meditation & daily routine wellness app from India.

Your job is to generate highly engaging social media captions that drive organic reach.

RULES:
1. Always write in the requested language (Hindi, English, or Hinglish mix)
2. Start with a strong hook (first line must stop the scroll)
3. Use relevant emojis naturally (don't overdo)
4. Include a clear CTA directing to DinCharya app
5. Generate 15-20 relevant hashtags (mix of high-volume and niche)
6. Keep Instagram captions under 2200 chars, Facebook can be longer
7. For YouTube, focus on SEO-friendly descriptions

RESPOND IN THIS EXACT JSON FORMAT (no markdown, no code blocks):
{
  "caption": "The full caption text here",
  "hashtags": ["#hashtag1", "#hashtag2", "..."],
  "cta": "A clear call to action",
  "hook": "The opening hook line",
  "image_prompt": "A detailed prompt to generate an AI image for this post"
}`;

async function callAI(prompt, systemPrompt) {
  const baseUrl = process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : 'http://localhost:3000';

  const res = await fetch(`${baseUrl}/api/social/ai/generate`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ prompt, systemPrompt }),
  });

  if (!res.ok) throw new Error(`AI generate failed: ${res.status}`);
  return res.json();
}

export async function POST(request) {
  try {
    const { topic, platform = 'instagram', tone = 'motivational', language = 'hinglish' } = await request.json();

    if (!topic) {
      return NextResponse.json({ error: 'topic is required' }, { status: 400 });
    }

    const prompt = `Generate a ${platform} post about: "${topic}"
Tone: ${tone}
Language: ${language}
Platform: ${platform}

Remember: Respond ONLY with valid JSON matching the format specified.`;

    const aiResult = await callAI(prompt, SYSTEM_PROMPT);

    // Parse AI response — handle both clean JSON and wrapped JSON
    let parsed;
    try {
      let text = aiResult.text.trim();
      // Strip markdown code blocks if present
      if (text.startsWith('```')) {
        text = text.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
      }
      parsed = JSON.parse(text);
    } catch {
      // If JSON parse fails, return raw text as caption
      parsed = {
        caption: aiResult.text,
        hashtags: [],
        cta: 'Download DinCharya app today! 🧘',
        hook: '',
        image_prompt: `Beautiful ${topic} related yoga wellness poster, dark luxury style, golden accents`,
      };
    }

    // Generate image URL from Pollinations
    const imagePrompt = parsed.image_prompt ||
      `Professional social media post about ${topic}, dark luxury aesthetic, golden mandala, DinCharya brand, yoga wellness, 1080x1080`;
    const imageUrl = `https://image.pollinations.ai/prompt/${encodeURIComponent(imagePrompt)}?width=1080&height=1080&seed=${Date.now()}&nologo=true`;

    return NextResponse.json({
      caption: parsed.caption || '',
      hashtags: parsed.hashtags || [],
      cta: parsed.cta || '',
      hook: parsed.hook || '',
      image_url: imageUrl,
      image_prompt: imagePrompt,
      ai_provider: aiResult.provider,
      ai_model: aiResult.model,
    });
  } catch (err) {
    console.error('[Social AI Caption]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

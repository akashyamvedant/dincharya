import { NextResponse } from 'next/server';

// Provider configs with fallback chain
const PROVIDERS = [
  {
    name: 'groq',
    url: 'https://api.groq.com/openai/v1/chat/completions',
    model: 'meta-llama/llama-4-scout-17b-16e-instruct',
    keyEnv: 'GROQ_API_KEY',
    format: 'openai',
  },
  {
    name: 'openrouter',
    url: 'https://openrouter.ai/api/v1/chat/completions',
    model: 'qwen/qwen3-30b-a3b:free',
    keyEnv: 'OPENROUTER_API_KEY',
    format: 'openai',
  },
  {
    name: 'gemini',
    url: null, // built dynamically
    model: 'gemini-2.5-flash',
    keyEnv: 'GEMINI_API_KEY',
    format: 'gemini',
  },
];

async function callOpenAIFormat(provider, messages) {
  const key = process.env[provider.keyEnv];
  if (!key) throw new Error(`Missing ${provider.keyEnv}`);

  const res = await fetch(provider.url, {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${key}`,
      'Content-Type': 'application/json',
      ...(provider.name === 'openrouter' ? { 'HTTP-Referer': 'https://dincharya-admin.vercel.app' } : {}),
    },
    body: JSON.stringify({
      model: provider.model,
      messages,
      temperature: 0.8,
      max_tokens: 2048,
    }),
  });

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`${provider.name} error ${res.status}: ${err}`);
  }

  const data = await res.json();
  return data.choices?.[0]?.message?.content || '';
}

async function callGemini(messages) {
  const key = process.env.GEMINI_API_KEY;
  if (!key) throw new Error('Missing GEMINI_API_KEY');

  // Convert OpenAI messages to Gemini format
  const systemText = messages.find(m => m.role === 'system')?.content || '';
  const userMessages = messages.filter(m => m.role !== 'system');

  const contents = userMessages.map(m => ({
    role: m.role === 'assistant' ? 'model' : 'user',
    parts: [{ text: m.content }],
  }));

  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${key}`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: systemText ? { parts: [{ text: systemText }] } : undefined,
        contents,
        generationConfig: { temperature: 0.8, maxOutputTokens: 2048 },
      }),
    }
  );

  if (!res.ok) {
    const err = await res.text();
    throw new Error(`gemini error ${res.status}: ${err}`);
  }

  const data = await res.json();
  return data.candidates?.[0]?.content?.parts?.[0]?.text || '';
}

export async function POST(request) {
  try {
    const { prompt, systemPrompt, preferredProvider } = await request.json();

    if (!prompt) {
      return NextResponse.json({ error: 'prompt is required' }, { status: 400 });
    }

    const messages = [
      ...(systemPrompt ? [{ role: 'system', content: systemPrompt }] : []),
      { role: 'user', content: prompt },
    ];

    // Reorder providers if preferred one specified
    let providers = [...PROVIDERS];
    if (preferredProvider) {
      const idx = providers.findIndex(p => p.name === preferredProvider);
      if (idx > 0) {
        const [pref] = providers.splice(idx, 1);
        providers.unshift(pref);
      }
    }

    // Try each provider with fallback
    const errors = [];
    for (const provider of providers) {
      try {
        let text;
        if (provider.format === 'gemini') {
          text = await callGemini(messages);
        } else {
          text = await callOpenAIFormat(provider, messages);
        }

        if (text) {
          return NextResponse.json({
            text,
            model: provider.model,
            provider: provider.name,
          });
        }
      } catch (err) {
        errors.push({ provider: provider.name, error: err.message });
        console.error(`[Social AI] ${provider.name} failed:`, err.message);
        continue;
      }
    }

    return NextResponse.json(
      { error: 'All AI providers failed', details: errors },
      { status: 502 }
    );
  } catch (err) {
    console.error('[Social AI Generate]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

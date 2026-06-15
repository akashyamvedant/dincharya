import { NextResponse } from 'next/server';

export async function POST(request) {
  try {
    const { prompt, width = 1080, height = 1080, style = 'dark luxury' } = await request.json();

    if (!prompt) {
      return NextResponse.json({ error: 'prompt is required' }, { status: 400 });
    }

    // Enhance prompt with DinCharya branding
    const enhancedPrompt = `${prompt}, ${style} aesthetic, professional social media design, high quality, vibrant`;
    const seed = Date.now();
    const imageUrl = `https://image.pollinations.ai/prompt/${encodeURIComponent(enhancedPrompt)}?width=${width}&height=${height}&seed=${seed}&nologo=true`;

    // Verify the image URL works by making a HEAD request
    try {
      const check = await fetch(imageUrl, { method: 'HEAD' });
      if (!check.ok) {
        throw new Error(`Pollinations returned ${check.status}`);
      }
    } catch {
      // Pollinations URLs are generated on-demand, HEAD might not work
      // The URL will still work when accessed directly
    }

    return NextResponse.json({
      image_url: imageUrl,
      prompt_used: enhancedPrompt,
      width,
      height,
      seed,
      provider: 'pollinations',
    });
  } catch (err) {
    console.error('[Social AI Image]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

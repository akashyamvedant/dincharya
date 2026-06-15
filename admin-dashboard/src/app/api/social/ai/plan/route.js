import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

export async function POST(request) {
  try {
    const { date, platforms = ['instagram', 'facebook', 'youtube'] } = await request.json().catch(() => ({}));

    const targetDate = date || new Date().toISOString().split('T')[0];
    const baseUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'http://localhost:3000';

    // Fetch settings to get configured posting frequency, tone, and language
    const { data: settings } = await supabase
      .from('social_settings')
      .select('*')
      .eq('id', 'default')
      .single();

    const frequency = settings?.posting_frequency || { instagram: 3, facebook: 2, youtube: 1 };
    const defaultTone = settings?.default_tone || 'motivational';
    const defaultLanguage = settings?.default_language || 'hinglish';

    // Step 1: Run research
    let research = null;
    try {
      const researchRes = await fetch(`${baseUrl}/api/social/ai/research`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
      if (researchRes.ok) research = await researchRes.json();
    } catch (err) {
      console.error('[Plan] Research failed:', err.message);
    }

    // Step 2: Generate plan using AI
    const systemPrompt = `You are a social media content planner for DinCharya, a yoga & wellness app.
Create a daily posting schedule optimized for maximum organic reach.

RULES:
- Instagram: ${frequency.instagram} posts/day — focus on visual appeal (reel, static, carousel)
- Facebook: ${frequency.facebook} posts/day — focus on longer educational or community text
- YouTube: ${frequency.youtube} posts/day — focus on short tips/tutorials
- Preferred Tone: ${defaultTone}
- Preferred Language: ${defaultLanguage}
- Times in IST (e.g., "07:00", "12:00", "18:00") spaced throughout the day
- Vary content types: reel, static_post, carousel, story, short, community_post
- Each post should have a unique angle on the topic

RESPOND IN THIS EXACT JSON FORMAT (no markdown):
{
  "date": "${targetDate}",
  "theme_of_day": "Today's overarching theme",
  "posts": [
    {
      "time": "07:00",
      "platform": "instagram",
      "content_type": "reel",
      "topic": "Post topic",
      "brief": "2-3 line brief for content creation",
      "priority": "high"
    }
  ]
}`;

    const prompt = `Create a content plan for ${targetDate} (${new Date(targetDate).toLocaleDateString('en', { weekday: 'long' })}).
Platforms: ${platforms.join(', ')}

Research Data:
${research ? `
- Season: ${research.seasonal?.season || 'N/A'}
- Seasonal Themes: ${research.seasonal?.themes?.join(', ') || 'N/A'}
- Upcoming Events: ${research.upcoming_events?.map(e => e.event).join(', ') || 'None'}
- Google Trends: ${research.google_trends?.slice(0, 5).join(', ') || 'N/A'}
- AI Suggestions: ${research.ai_analysis?.content_suggestions?.map(s => s.topic).join(', ') || 'N/A'}
` : 'No research data available — use general wellness/yoga topics'}

Generate the daily content plan.`;

    const aiRes = await fetch(`${baseUrl}/api/social/ai/generate`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ prompt, systemPrompt }),
    });

    if (!aiRes.ok) {
      throw new Error(`AI generate failed: ${aiRes.status}`);
    }

    const aiData = await aiRes.json();

    let plan;
    try {
      let text = aiData.text.trim();
      if (text.startsWith('```')) text = text.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
      plan = JSON.parse(text);
    } catch {
      // Fallback plan if AI doesn't return valid JSON
      plan = {
        date: targetDate,
        theme_of_day: 'Wellness & Mindfulness',
        posts: [
          { time: '07:00', platform: 'instagram', content_type: 'reel', topic: 'Morning Meditation Guide', brief: 'Quick 5-min meditation tutorial reel', priority: 'high' },
          { time: '09:00', platform: 'facebook', content_type: 'post', topic: 'Benefits of Daily Yoga', brief: 'Educational post about yoga benefits', priority: 'medium' },
          { time: '12:00', platform: 'instagram', content_type: 'carousel', topic: 'Top 5 Pranayama Techniques', brief: 'Carousel with one technique per slide', priority: 'high' },
          { time: '14:00', platform: 'youtube', content_type: 'short', topic: 'Quick Desk Yoga Stretches', brief: '60s tutorial for office workers', priority: 'medium' },
          { time: '17:00', platform: 'facebook', content_type: 'post', topic: 'Evening Relaxation Routine', brief: 'Community post asking followers their wind-down routine', priority: 'low' },
          { time: '18:00', platform: 'instagram', content_type: 'post', topic: 'Gratitude Quote', brief: 'Beautiful quote card about gratitude and inner peace', priority: 'medium' },
        ],
      };
    }

    return NextResponse.json({
      ...plan,
      research_summary: research ? {
        trends_found: research.google_trends?.length || 0,
        events: research.upcoming_events?.length || 0,
        season: research.seasonal?.season,
      } : null,
      ai_provider: aiData.provider,
    });
  } catch (err) {
    console.error('[Social AI Plan]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

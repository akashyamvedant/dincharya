import { NextResponse } from 'next/server';

// Indian festivals & wellness events calendar
const EVENTS_CALENDAR = {
  '01-01': 'New Year - Fresh Start Routines',
  '01-12': 'National Youth Day (Swami Vivekananda Jayanti)',
  '01-14': 'Makar Sankranti - Sun Salutation Special',
  '01-26': 'Republic Day - Disciplined Routine',
  '02-14': 'Valentine Day - Self-Love Meditation',
  '03-08': 'International Women Day',
  '03-20': 'Spring Equinox - New Beginnings',
  '04-07': 'World Health Day',
  '04-14': 'Baisakhi - Harvest Energy',
  '05-01': 'May Day - Work-Life Balance',
  '05-21': 'World Meditation Day',
  '06-21': 'International Yoga Day 🧘',
  '07-01': 'National Doctor Day - Health Awareness',
  '08-15': 'Independence Day - Mental Freedom',
  '08-19': 'World Humanitarian Day',
  '09-05': 'Teacher Day - Guru Tradition in Yoga',
  '10-02': 'Gandhi Jayanti - Ahimsa & Peace',
  '10-10': 'World Mental Health Day',
  '11-14': 'Children Day - Kids Yoga',
  '12-11': 'International Mountain Day - Nature Meditation',
};

function getUpcomingEvents(daysAhead = 7) {
  const events = [];
  const now = new Date();

  for (let i = 0; i <= daysAhead; i++) {
    const d = new Date(now);
    d.setDate(d.getDate() + i);
    const key = `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`;
    if (EVENTS_CALENDAR[key]) {
      events.push({
        date: d.toISOString().split('T')[0],
        event: EVENTS_CALENDAR[key],
        daysAway: i,
      });
    }
  }
  return events;
}

function getSeasonalTheme() {
  const month = new Date().getMonth() + 1;
  if (month >= 3 && month <= 5) return { season: 'Spring/Summer', themes: ['Morning Yoga Outdoors', 'Sun Salutation', 'Energy Boosting Pranayama', 'Summer Cooling Breathing'] };
  if (month >= 6 && month <= 8) return { season: 'Monsoon', themes: ['Indoor Meditation', 'Rainy Day Yoga', 'Monsoon Wellness Tips', 'Joint Care Yoga'] };
  if (month >= 9 && month <= 11) return { season: 'Autumn/Festival', themes: ['Festive Wellness', 'Navratri Fasting Yoga', 'Diwali Detox', 'Gratitude Meditation'] };
  return { season: 'Winter', themes: ['Surya Namaskar Challenge', 'Warm-Up Yoga', 'Immunity Pranayama', 'New Year Resolutions'] };
}

async function fetchTrends() {
  try {
    const res = await fetch('https://trends.google.com/trends/trendingsearches/daily/rss?geo=IN', {
      headers: { 'User-Agent': 'DinCharya-SocialManager/1.0' },
    });

    if (!res.ok) return [];

    const text = await res.text();
    // Simple XML parsing for trend titles
    const titles = [];
    const regex = /<title><!\[CDATA\[(.*?)\]\]><\/title>/g;
    let match;
    while ((match = regex.exec(text)) !== null) {
      if (match[1] !== 'Daily Search Trends') {
        titles.push(match[1]);
      }
    }
    return titles.slice(0, 15);
  } catch (err) {
    console.error('[Trends fetch error]', err.message);
    return [];
  }
}

export async function POST(request) {
  try {
    const { niche = 'yoga wellness meditation' } = await request.json().catch(() => ({}));

    // Gather all research data
    const [trends, events, seasonal] = await Promise.all([
      fetchTrends(),
      Promise.resolve(getUpcomingEvents(7)),
      Promise.resolve(getSeasonalTheme()),
    ]);

    // Use AI to analyze trends and suggest content
    const baseUrl = process.env.VERCEL_URL
      ? `https://${process.env.VERCEL_URL}`
      : 'http://localhost:3000';

    const systemPrompt = `You are a social media research analyst for DinCharya, a yoga/wellness app.
Analyze trending topics and suggest content ideas that can ride trending waves while staying relevant to yoga, meditation, wellness, and daily routines.

RESPOND IN THIS EXACT JSON FORMAT (no markdown):
{
  "relevant_trends": ["trend1 and how to connect to wellness", "trend2"],
  "content_suggestions": [
    {"topic": "topic title", "platform": "instagram", "type": "reel", "reasoning": "why this will work", "urgency": "high/medium/low"},
    {"topic": "topic title", "platform": "youtube", "type": "short", "reasoning": "why", "urgency": "medium"}
  ],
  "weekly_theme": "A theme suggestion for this week"
}`;

    const prompt = `Today: ${new Date().toLocaleDateString('en-IN', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
Season: ${seasonal.season}
Seasonal Themes: ${seasonal.themes.join(', ')}
Upcoming Events: ${events.length > 0 ? events.map(e => `${e.event} (${e.daysAway === 0 ? 'TODAY!' : `in ${e.daysAway} days`})`).join(', ') : 'None this week'}
Google Trends India (today): ${trends.length > 0 ? trends.join(', ') : 'Unable to fetch'}
Niche: ${niche}

Analyze and suggest 5-7 content ideas for today.`;

    let aiAnalysis = null;
    try {
      const aiRes = await fetch(`${baseUrl}/api/social/ai/generate`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ prompt, systemPrompt }),
      });

      if (aiRes.ok) {
        const aiData = await aiRes.json();
        try {
          let text = aiData.text.trim();
          if (text.startsWith('```')) text = text.replace(/^```(?:json)?\n?/, '').replace(/\n?```$/, '');
          aiAnalysis = JSON.parse(text);
        } catch {
          aiAnalysis = { raw_analysis: aiData.text };
        }
      }
    } catch (err) {
      console.error('[Research AI analysis failed]', err.message);
    }

    return NextResponse.json({
      date: new Date().toISOString(),
      google_trends: trends,
      upcoming_events: events,
      seasonal: seasonal,
      ai_analysis: aiAnalysis,
      day_of_week: new Date().toLocaleDateString('en', { weekday: 'long' }),
    });
  } catch (err) {
    console.error('[Social AI Research]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

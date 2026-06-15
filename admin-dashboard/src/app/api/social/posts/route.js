import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

export async function GET(request) {
  try {
    const { searchParams } = new URL(request.url);
    const date = searchParams.get('date') || new Date().toISOString().split('T')[0];
    const status = searchParams.get('status');
    const platform = searchParams.get('platform');
    const limit = parseInt(searchParams.get('limit') || '50');

    let query = supabase
      .from('social_media_posts')
      .select('*')
      .order('scheduled_time', { ascending: true })
      .limit(limit);

    // Filter by date — posts scheduled for today
    if (date) {
      const dayStart = `${date}T00:00:00+05:30`;
      const dayEnd = `${date}T23:59:59+05:30`;
      query = query.gte('scheduled_time', dayStart).lte('scheduled_time', dayEnd);
    }

    if (status) query = query.eq('status', status);
    if (platform) query = query.eq('platform', platform);

    const { data: posts, error } = await query;

    if (error) throw error;

    // Get today's plan
    const { data: plan } = await supabase
      .from('social_content_plans')
      .select('*')
      .eq('plan_date', date)
      .maybeSingle();

    // Get recent agent logs
    const { data: logs } = await supabase
      .from('social_agent_logs')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(20);

    // Stats
    const { count: totalToday } = await supabase
      .from('social_media_posts')
      .select('id', { count: 'exact', head: true })
      .gte('created_at', `${date}T00:00:00`)
      .lte('created_at', `${date}T23:59:59`);

    const { count: publishedToday } = await supabase
      .from('social_media_posts')
      .select('id', { count: 'exact', head: true })
      .eq('status', 'published')
      .gte('created_at', `${date}T00:00:00`);

    return NextResponse.json({
      posts: posts || [],
      plan: plan || null,
      logs: logs || [],
      stats: {
        total_today: totalToday || 0,
        published_today: publishedToday || 0,
        generated_today: posts?.filter(p => p.status === 'generated').length || 0,
        scheduled_today: posts?.filter(p => p.status === 'scheduled').length || 0,
      },
    });
  } catch (err) {
    console.error('[Social Posts GET]', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

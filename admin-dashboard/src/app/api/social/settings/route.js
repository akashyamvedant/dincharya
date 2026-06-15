import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

// GET — Load settings
export async function GET() {
  try {
    const { data, error } = await supabase
      .from('social_settings')
      .select('*')
      .eq('id', 'default')
      .single();

    if (error) throw error;

    // Mask tokens for security
    const masked = { ...data };
    if (masked.facebook_page_token) masked.facebook_page_token = '••••' + masked.facebook_page_token.slice(-6);
    if (masked.youtube_refresh_token) masked.youtube_refresh_token = '••••' + masked.youtube_refresh_token.slice(-6);
    masked.has_facebook = !!data.facebook_page_token && !!data.facebook_page_id;
    masked.has_instagram = !!data.instagram_account_id && !!data.facebook_page_token;
    masked.has_youtube = !!data.youtube_refresh_token;

    return NextResponse.json(masked);
  } catch (err) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

// POST — Update settings
export async function POST(request) {
  try {
    const body = await request.json();

    // Only allow specific fields
    const allowed = [
      'facebook_page_token', 'facebook_page_id', 'instagram_account_id',
      'youtube_refresh_token', 'youtube_client_id', 'youtube_client_secret',
      'auto_publish', 'posting_frequency', 'default_tone', 'default_language', 'cron_enabled',
    ];

    const update = { updated_at: new Date().toISOString() };
    for (const key of allowed) {
      if (body[key] !== undefined) {
        update[key] = body[key];
      }
    }

    const { data, error } = await supabase
      .from('social_settings')
      .update(update)
      .eq('id', 'default')
      .select()
      .single();

    if (error) throw error;

    return NextResponse.json({ success: true, updated: Object.keys(update).filter(k => k !== 'updated_at') });
  } catch (err) {
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

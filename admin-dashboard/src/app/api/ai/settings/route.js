import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabaseUrl = process.env.NEXT_PUBLIC_SUPABASE_URL;
const supabaseServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY || process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;

// Default AI model settings
const DEFAULTS = {
  vision_model: 'google/gemma-3-27b-it:free',
  image_gen_model: 'black-forest-labs/flux.2-flex',
  text_model: 'sarvam-105b',
  text_provider: 'sarvam',
};

function getSupabase() {
  return createClient(supabaseUrl, supabaseServiceKey);
}

// GET: Retrieve current AI model settings
export async function GET() {
  try {
    const supabase = getSupabase();
    const { data, error } = await supabase
      .from('app_settings')
      .select('key, value')
      .in('key', Object.keys(DEFAULTS));

    if (error) {
      // Table may not exist yet — return defaults
      console.warn('app_settings read error (may not exist):', error.message);
      return NextResponse.json({ settings: { ...DEFAULTS } });
    }

    // Merge DB values with defaults
    const settings = { ...DEFAULTS };
    (data || []).forEach(row => {
      settings[row.key] = row.value;
    });

    return NextResponse.json({ settings });
  } catch (err) {
    console.error('Settings GET error:', err);
    return NextResponse.json({ settings: { ...DEFAULTS } });
  }
}

// POST: Update AI model settings
export async function POST(request) {
  try {
    const body = await request.json();
    const { settings } = body;

    if (!settings || typeof settings !== 'object') {
      return NextResponse.json({ error: 'Invalid settings payload' }, { status: 400 });
    }

    const supabase = getSupabase();
    const now = new Date().toISOString();

    // Upsert each setting
    const upserts = Object.entries(settings)
      .filter(([key]) => Object.keys(DEFAULTS).includes(key))
      .map(([key, value]) => ({
        key,
        value: String(value),
        updated_at: now,
      }));

    if (upserts.length === 0) {
      return NextResponse.json({ error: 'No valid settings to update' }, { status: 400 });
    }

    const { error } = await supabase
      .from('app_settings')
      .upsert(upserts, { onConflict: 'key' });

    if (error) {
      console.error('Settings save error:', error);
      return NextResponse.json({ error: `Failed to save: ${error.message}` }, { status: 500 });
    }

    return NextResponse.json({ success: true, updated: upserts.length });
  } catch (err) {
    console.error('Settings POST error:', err);
    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

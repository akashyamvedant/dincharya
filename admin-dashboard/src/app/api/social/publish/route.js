import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

// ═══ FACEBOOK PUBLISHING ═══
async function publishToFacebook(post, settings) {
  const { facebook_page_token, facebook_page_id } = settings;
  if (!facebook_page_token || !facebook_page_id) {
    throw new Error('Facebook Page Token or Page ID not configured');
  }

  // If post has an image, publish as photo post
  if (post.image_url) {
    const res = await fetch(
      `https://graph.facebook.com/v22.0/${facebook_page_id}/photos`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          url: post.image_url,
          message: `${post.caption}\n\n${(post.hashtags || []).join(' ')}`,
          access_token: facebook_page_token,
        }),
      }
    );
    const data = await res.json();
    if (data.error) throw new Error(data.error.message);
    return { post_id: data.id || data.post_id, platform: 'facebook', type: 'photo' };
  }

  // Text-only post
  const res = await fetch(
    `https://graph.facebook.com/v22.0/${facebook_page_id}/feed`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        message: `${post.caption}\n\n${(post.hashtags || []).join(' ')}`,
        access_token: facebook_page_token,
      }),
    }
  );
  const data = await res.json();
  if (data.error) throw new Error(data.error.message);
  return { post_id: data.id, platform: 'facebook', type: 'text' };
}

// ═══ INSTAGRAM PUBLISHING ═══
async function publishToInstagram(post, settings) {
  const { facebook_page_token, instagram_account_id } = settings;
  if (!facebook_page_token || !instagram_account_id) {
    throw new Error('Instagram Account ID or Facebook Token not configured');
  }

  const caption = `${post.caption}\n\n${(post.hashtags || []).join(' ')}`;

  // Step 1: Create media container
  const containerRes = await fetch(
    `https://graph.facebook.com/v22.0/${instagram_account_id}/media`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        image_url: post.image_url,
        caption,
        access_token: facebook_page_token,
      }),
    }
  );
  const container = await containerRes.json();
  if (container.error) throw new Error(container.error.message);

  // Step 2: Wait for processing (poll status)
  let ready = false;
  for (let i = 0; i < 10; i++) {
    const statusRes = await fetch(
      `https://graph.facebook.com/v22.0/${container.id}?fields=status_code&access_token=${facebook_page_token}`
    );
    const status = await statusRes.json();
    if (status.status_code === 'FINISHED') { ready = true; break; }
    if (status.status_code === 'ERROR') throw new Error('Instagram media processing failed');
    await new Promise(r => setTimeout(r, 3000));
  }
  if (!ready) throw new Error('Instagram media processing timeout');

  // Step 3: Publish
  const publishRes = await fetch(
    `https://graph.facebook.com/v22.0/${instagram_account_id}/media_publish`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        creation_id: container.id,
        access_token: facebook_page_token,
      }),
    }
  );
  const published = await publishRes.json();
  if (published.error) throw new Error(published.error.message);
  return { post_id: published.id, platform: 'instagram', type: 'image' };
}

// ═══ YOUTUBE SHORTS PUBLISHING ═══
async function publishToYouTube(post, settings) {
  const { youtube_refresh_token, youtube_client_id, youtube_client_secret } = settings;
  if (!youtube_refresh_token || !youtube_client_id || !youtube_client_secret) {
    throw new Error('YouTube OAuth credentials not configured');
  }

  // Step 1: Get access token from refresh token
  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      client_id: youtube_client_id,
      client_secret: youtube_client_secret,
      refresh_token: youtube_refresh_token,
      grant_type: 'refresh_token',
    }),
  });
  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) throw new Error('YouTube token refresh failed');

  // YouTube requires a video file — if we only have an image, skip
  if (!post.video_url) {
    throw new Error('YouTube Shorts require a video URL. Video generation coming soon.');
  }

  // Step 2: Upload video via resumable upload
  const title = `${post.topic} | DinCharya #Shorts`;
  const description = `${post.caption}\n\n${(post.hashtags || []).join(' ')}\n\nDownload DinCharya App for daily yoga & wellness routines!`;

  const initRes = await fetch(
    'https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status',
    {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${tokenData.access_token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        snippet: { title, description, tags: post.hashtags || [], categoryId: '22' },
        status: { privacyStatus: 'public', selfDeclaredMadeForKids: false },
      }),
    }
  );

  if (!initRes.ok) throw new Error(`YouTube upload init failed: ${initRes.status}`);

  // For now return the setup — full video upload needs video file download
  return { platform: 'youtube', type: 'short', status: 'setup_ready', title };
}

// ═══ MAIN PUBLISH ENDPOINT ═══
export async function POST(request) {
  try {
    const { post_id, platform } = await request.json();

    if (!post_id) {
      return NextResponse.json({ error: 'post_id is required' }, { status: 400 });
    }

    // Get post from DB
    const { data: post, error: postErr } = await supabase
      .from('social_media_posts')
      .select('*')
      .eq('id', post_id)
      .single();

    if (postErr || !post) {
      return NextResponse.json({ error: 'Post not found' }, { status: 404 });
    }

    // Get settings
    const { data: settings } = await supabase
      .from('social_settings')
      .select('*')
      .eq('id', 'default')
      .single();

    if (!settings) {
      return NextResponse.json({ error: 'Social settings not configured' }, { status: 400 });
    }

    const targetPlatform = platform || post.platform;
    let result;

    switch (targetPlatform) {
      case 'facebook':
        result = await publishToFacebook(post, settings);
        break;
      case 'instagram':
        result = await publishToInstagram(post, settings);
        break;
      case 'youtube':
        result = await publishToYouTube(post, settings);
        break;
      default:
        return NextResponse.json({ error: `Unknown platform: ${targetPlatform}` }, { status: 400 });
    }

    // Update post status in DB
    await supabase.from('social_media_posts')
      .update({
        status: 'published',
        published_at: new Date().toISOString(),
        engagement_data: { ...post.engagement_data, platform_post_id: result.post_id },
      })
      .eq('id', post_id);

    // Log agent activity
    await supabase.from('social_agent_logs').insert({
      agent_name: 'publisher',
      action: 'publish',
      status: 'success',
      details: { platform: targetPlatform, post_id: post.id, result },
    });

    return NextResponse.json({ success: true, ...result });
  } catch (err) {
    console.error('[Publish Error]', err);

    // Log failure
    await supabase.from('social_agent_logs').insert({
      agent_name: 'publisher',
      action: 'publish',
      status: 'error',
      error_message: err.message,
    });

    return NextResponse.json({ error: err.message }, { status: 500 });
  }
}

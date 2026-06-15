import { NextResponse } from 'next/server';
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  process.env.NEXT_PUBLIC_SUPABASE_URL,
  process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY
);

async function logAgent(agent, action, status, details = {}, error = null, duration = 0) {
  await supabase.from('social_agent_logs').insert({
    agent_name: agent, action, status,
    details, error_message: error, duration_ms: duration,
  });
}

export async function POST(request) {
  const startTime = Date.now();

  // Verify cron secret (for Vercel Cron security)
  const authHeader = request.headers.get('authorization');
  const cronSecret = process.env.CRON_SECRET;
  // Allow if no secret set (dev mode) or if secret matches, or if manual trigger
  const { manual } = await request.json().catch(() => ({}));

  if (cronSecret && !manual && authHeader !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const baseUrl = process.env.VERCEL_URL
    ? `https://${process.env.VERCEL_URL}`
    : 'http://localhost:3000';

  const today = new Date().toISOString().split('T')[0];
  const results = { research: null, plan: null, posts_created: 0, posts_skipped: 0, errors: [] };

  try {
    // ═══ DUPLICATE PREVENTION: Delete old generated (unpublished) posts for today ═══
    const { data: existingPosts } = await supabase
      .from('social_media_posts')
      .select('id, status')
      .gte('scheduled_time', `${today}T00:00:00+05:30`)
      .lte('scheduled_time', `${today}T23:59:59+05:30`);

    if (existingPosts?.length > 0) {
      // Only delete 'draft' and 'generated' posts, keep 'published' ones
      const toDelete = existingPosts.filter(p => p.status !== 'published').map(p => p.id);
      if (toDelete.length > 0) {
        await supabase.from('social_media_posts').delete().in('id', toDelete);
        results.posts_skipped = toDelete.length;
        console.log(`[CRON] Cleaned ${toDelete.length} old generated posts for today`);
      }
    }
    // ═══ STEP 1: Research Agent ═══
    console.log('[CRON] Step 1: Running Research Agent...');
    await logAgent('research', 'start', 'running');

    let research = null;
    try {
      const researchRes = await fetch(`${baseUrl}/api/social/ai/research`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({}),
      });
      if (researchRes.ok) {
        research = await researchRes.json();
        results.research = {
          trends: research.google_trends?.length || 0,
          events: research.upcoming_events?.length || 0,
          season: research.seasonal?.season,
        };
        await logAgent('research', 'complete', 'success', results.research, null, Date.now() - startTime);
      }
    } catch (err) {
      results.errors.push({ agent: 'research', error: err.message });
      await logAgent('research', 'complete', 'error', {}, err.message, Date.now() - startTime);
    }

    // ═══ STEP 2: Planner Agent ═══
    console.log('[CRON] Step 2: Running Planner Agent...');
    await logAgent('planner', 'start', 'running');

    let plan = null;
    const planStart = Date.now();
    try {
      const planRes = await fetch(`${baseUrl}/api/social/ai/plan`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ platforms: ['instagram', 'facebook', 'youtube'] }),
      });
      if (planRes.ok) {
        plan = await planRes.json();
        results.plan = {
          theme: plan.theme_of_day,
          posts_planned: plan.posts?.length || 0,
        };

        // Save plan to Supabase
        await supabase.from('social_content_plans').upsert({
          plan_date: today,
          theme_of_day: plan.theme_of_day,
          posts: plan.posts || [],
          research_data: research || {},
          ai_provider: plan.ai_provider,
          status: 'generated',
        }, { onConflict: 'plan_date' });

        await logAgent('planner', 'complete', 'success', results.plan, null, Date.now() - planStart);
      }
    } catch (err) {
      results.errors.push({ agent: 'planner', error: err.message });
      await logAgent('planner', 'complete', 'error', {}, err.message, Date.now() - planStart);
    }

    // ═══ STEP 3: Creator Agent — Generate content for each planned post ═══
    if (plan?.posts?.length > 0) {
      console.log(`[CRON] Step 3: Creating ${plan.posts.length} posts...`);
      await logAgent('creator', 'start', 'running', { total_posts: plan.posts.length });

      const creatorStart = Date.now();
      for (const post of plan.posts) {
        try {
          // Generate caption
          const captionRes = await fetch(`${baseUrl}/api/social/ai/caption`, {
            method: 'POST', headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              topic: post.topic || post.brief,
              platform: post.platform,
              tone: post.tone || 'motivational',
              language: 'hinglish',
            }),
          });

          if (captionRes.ok) {
            const captionData = await captionRes.json();

            // Calculate scheduled time with proper IST offset
            const timeStr = (post.time || '12:00').replace(/[^0-9:]/g, '');
            const [hours, minutes] = timeStr.split(':').map(Number);
            const scheduledTime = new Date(`${today}T${String(hours||12).padStart(2,'0')}:${String(minutes||0).padStart(2,'0')}:00+05:30`);

            // Save to Supabase
            const { error: insertError } = await supabase.from('social_media_posts').insert({
              platform: post.platform,
              content_type: post.content_type || 'post',
              topic: post.topic,
              caption: captionData.caption,
              hashtags: captionData.hashtags,
              cta: captionData.cta,
              image_url: captionData.image_url,
              image_prompt: captionData.image_prompt,
              status: 'generated',
              scheduled_time: scheduledTime.toISOString(),
              ai_provider: captionData.ai_provider,
              ai_model: captionData.ai_model,
              tone: post.tone || 'motivational',
              language: 'hinglish',
              research_context: { plan_theme: plan.theme_of_day, brief: post.brief },
            });

            if (!insertError) {
              results.posts_created++;
            } else {
              results.errors.push({ post: post.topic, error: insertError.message });
            }
          }

          // Small delay between AI calls to respect rate limits
          await new Promise(r => setTimeout(r, 2000));
        } catch (err) {
          results.errors.push({ post: post.topic, error: err.message });
        }
      }

      await logAgent('creator', 'complete', 'success', {
        posts_created: results.posts_created,
        total_planned: plan.posts.length,
      }, null, Date.now() - creatorStart);
    }

    // ═══ STEP 4: Publisher Agent — Auto-publish if enabled ═══
    const { data: settings } = await supabase
      .from('social_settings')
      .select('auto_publish')
      .eq('id', 'default')
      .single();

    results.posts_published = 0;
    if (settings?.auto_publish && results.posts_created > 0) {
      console.log('[CRON] Step 4: Auto-publishing posts...');
      await logAgent('publisher', 'start', 'running');
      const publishStart = Date.now();

      // Get all generated posts for today that should have been posted by now
      const now = new Date();
      const { data: readyPosts } = await supabase
        .from('social_media_posts')
        .select('id, platform, scheduled_time')
        .eq('status', 'generated')
        .gte('scheduled_time', `${today}T00:00:00+05:30`)
        .lte('scheduled_time', now.toISOString())
        .order('scheduled_time', { ascending: true });

      if (readyPosts?.length > 0) {
        for (const rp of readyPosts) {
          try {
            const pubRes = await fetch(`${baseUrl}/api/social/publish`, {
              method: 'POST',
              headers: { 'Content-Type': 'application/json' },
              body: JSON.stringify({ post_id: rp.id }),
            });
            if (pubRes.ok) results.posts_published++;
            await new Promise(r => setTimeout(r, 5000)); // Rate limit safety
          } catch (err) {
            results.errors.push({ publish: rp.id, error: err.message });
          }
        }
      }

      await logAgent('publisher', 'complete', 'success', {
        published: results.posts_published,
        ready: readyPosts?.length || 0,
      }, null, Date.now() - publishStart);
    }

    // Update plan status
    if (plan) {
      await supabase.from('social_content_plans')
        .update({ status: results.posts_created > 0 ? 'completed' : 'failed' })
        .eq('plan_date', today);
    }

    const totalDuration = Date.now() - startTime;
    console.log(`[CRON] Pipeline complete in ${totalDuration}ms. Created: ${results.posts_created}, Published: ${results.posts_published}`);

    return NextResponse.json({
      success: true,
      date: today,
      duration_ms: totalDuration,
      ...results,
    });
  } catch (err) {
    console.error('[CRON Pipeline Error]', err);
    await logAgent('pipeline', 'crash', 'error', {}, err.message, Date.now() - startTime);
    return NextResponse.json({ error: err.message, results }, { status: 500 });
  }
}

// Also support GET for Vercel Cron
export async function GET(request) {
  return POST(request);
}

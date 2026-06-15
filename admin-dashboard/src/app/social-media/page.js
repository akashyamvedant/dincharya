'use client';
import { useState, useCallback, useEffect } from 'react';

const PLATFORMS = [
  { id: 'instagram', label: 'Instagram', icon: '📸', color: '#E1306C' },
  { id: 'facebook', label: 'Facebook', icon: '📘', color: '#1877F2' },
  { id: 'youtube', label: 'YouTube', icon: '📺', color: '#FF0000' },
];

const CONTENT_TYPES = ['Post', 'Reel', 'Story', 'Short', 'Carousel'];
const TONES = ['Motivational', 'Educational', 'Entertaining', 'Trending'];
const LANGUAGES = ['Hindi', 'English', 'Hinglish'];

const TABS = [
  { id: 'control', label: 'Mission Control', icon: '🎯' },
  { id: 'studio', label: 'AI Content Studio', icon: '✍️' },
  { id: 'calendar', label: 'Content Calendar', icon: '📅' },
  { id: 'settings', label: 'Settings', icon: '⚙️' },
];

const AGENTS = [
  { id: 'research', name: 'Research Agent', desc: 'Trends & competitor analysis', icon: '🔍' },
  { id: 'planner', name: 'Planner Agent', desc: 'Daily content scheduling', icon: '📋' },
  { id: 'creator', name: 'Creator Agent', desc: 'Caption, image & video gen', icon: '✍️' },
  { id: 'publisher', name: 'Publisher Agent', desc: 'Auto-post to platforms', icon: '📤' },
  { id: 'engagement', name: 'Engagement Agent', desc: 'Comment replies', icon: '💬' },
];

// ——— Styles ———
const s = {
  page: { maxWidth: 1400, margin: '0 auto' },
  subtitle: { fontSize: 14, color: 'var(--text-muted)', marginTop: 2 },
  tabs: { display: 'flex', gap: 4, background: 'var(--bg-surface)', borderRadius: 12, padding: 4, marginBottom: 24 },
  tab: (active) => ({
    flex: 1, padding: '12px 16px', borderRadius: 10, border: 'none', cursor: 'pointer',
    fontSize: 13, fontWeight: active ? 700 : 500, display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8,
    background: active ? 'var(--accent-gradient)' : 'transparent',
    color: active ? '#000' : 'var(--text-secondary)',
    transition: 'all 0.2s', fontFamily: 'Inter, sans-serif',
  }),
  grid2: { display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 },
  grid3: { display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 12 },
  card: {
    background: 'var(--glass)', backdropFilter: 'blur(12px)', border: '1px solid var(--glass-border)',
    borderRadius: 14, padding: 22, transition: 'all 0.2s',
  },
  cardTitle: { fontSize: 15, fontWeight: 700, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 8 },
  agentRow: (status) => ({
    display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 10,
    background: 'var(--bg-surface)', marginBottom: 8, transition: 'all 0.2s',
    borderLeft: `3px solid ${status === 'active' ? 'var(--success)' : status === 'idle' ? 'var(--warning)' : 'var(--text-muted)'}`,
  }),
  dot: (color) => ({
    width: 8, height: 8, borderRadius: '50%', background: color, flexShrink: 0,
    boxShadow: color === 'var(--success)' ? '0 0 8px rgba(74,222,128,0.5)' : 'none',
    animation: color === 'var(--success)' ? 'pulse 2s ease-in-out infinite' : 'none',
  }),
  queueRow: {
    display: 'grid', gridTemplateColumns: '60px 40px 1fr 100px 80px 80px 70px', alignItems: 'center',
    gap: 8, padding: '10px 14px', borderBottom: '1px solid var(--border-subtle)', fontSize: 13,
  },
  queueHeader: {
    display: 'grid', gridTemplateColumns: '60px 40px 1fr 100px 80px 80px 70px',
    gap: 8, padding: '10px 14px', borderBottom: '1px solid var(--border)',
    fontSize: 11, fontWeight: 600, color: 'var(--text-muted)', textTransform: 'uppercase', letterSpacing: 0.5,
  },
  formGroup: { marginBottom: 16 },
  label: { display: 'block', fontSize: 12, fontWeight: 600, color: 'var(--text-muted)', marginBottom: 6, textTransform: 'uppercase', letterSpacing: 0.3 },
  select: {
    width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid var(--border)',
    background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: 13, fontFamily: 'Inter',
    outline: 'none', cursor: 'pointer', appearance: 'none',
  },
  input: {
    width: '100%', padding: '10px 14px', borderRadius: 8, border: '1px solid var(--border)',
    background: 'var(--bg-primary)', color: 'var(--text-primary)', fontSize: 13, fontFamily: 'Inter', outline: 'none',
  },
  preview: {
    background: 'var(--bg-surface)', borderRadius: 12, padding: 20, minHeight: 200,
    border: '1px dashed var(--border)', display: 'flex', flexDirection: 'column', gap: 16,
  },
  copyBtn: {
    padding: '4px 10px', borderRadius: 6, border: '1px solid var(--border)', background: 'var(--bg-card)',
    color: 'var(--text-secondary)', fontSize: 11, cursor: 'pointer', fontFamily: 'Inter',
  },
  calDay: {
    background: 'var(--bg-surface)', borderRadius: 10, padding: 12, minHeight: 120,
    border: '1px solid var(--border-subtle)',
  },
  calDayLabel: { fontSize: 11, fontWeight: 700, color: 'var(--text-muted)', marginBottom: 8, textTransform: 'uppercase' },
  calPost: (color) => ({
    fontSize: 11, padding: '6px 8px', borderRadius: 6, marginBottom: 4,
    background: `${color}15`, borderLeft: `3px solid ${color}`, color: 'var(--text-secondary)',
  }),
  killBtn: {
    width: '100%', padding: '16px 24px', borderRadius: 12, border: '2px solid var(--error)',
    background: 'rgba(248,113,113,0.1)', color: 'var(--error)', fontSize: 16, fontWeight: 800,
    cursor: 'pointer', fontFamily: 'Inter', transition: 'all 0.2s', textTransform: 'uppercase', letterSpacing: 1,
  },
  statusDot: (ok) => ({
    width: 10, height: 10, borderRadius: '50%', display: 'inline-block',
    background: ok ? 'var(--success)' : 'var(--error)',
    boxShadow: ok ? '0 0 8px rgba(74,222,128,0.4)' : '0 0 8px rgba(248,113,113,0.4)',
  }),
  skeleton: {
    background: 'linear-gradient(90deg, var(--bg-surface) 25%, var(--bg-hover) 50%, var(--bg-surface) 75%)',
    backgroundSize: '200% 100%', animation: 'shimmer 1.5s infinite', borderRadius: 8, height: 16, marginBottom: 8,
  },
};

// ——— Component ———
export default function SocialMediaPage() {
  const [activeTab, setActiveTab] = useState('control');
  const [generating, setGenerating] = useState(false);
  const [planLoading, setPlanLoading] = useState(false);
  const [generatedContent, setGeneratedContent] = useState(null);
  const [contentPlan, setContentPlan] = useState(null);
  const [dbPosts, setDbPosts] = useState([]);
  const [dbStats, setDbStats] = useState({ total_today: 0, published_today: 0, generated_today: 0 });
  const [agentLogs, setAgentLogs] = useState([]);
  const [pipelineResult, setPipelineResult] = useState(null);
  const [agentStatuses, setAgentStatuses] = useState({
    research: 'idle', planner: 'idle', creator: 'idle', publisher: 'offline', engagement: 'offline',
  });

  // Studio form state
  const [form, setForm] = useState({
    platform: 'instagram', topic: '', contentType: 'Post', tone: 'Motivational', language: 'Hinglish',
  });

  // Settings state
  const [settings, setSettings] = useState({
    autoPublish: false, postsPerDay: { instagram: 3, facebook: 2, youtube: 1 },
    defaultTone: 'Motivational', defaultLanguage: 'Hinglish',
  });

  // ——— Load data from Supabase on mount ———
  const loadDashboardData = useCallback(async () => {
    try {
      const res = await fetch('/api/social/posts');
      if (res.ok) {
        const data = await res.json();
        setDbPosts(data.posts || []);
        setDbStats(data.stats || {});
        setAgentLogs(data.logs || []);
        if (data.plan) {
          setContentPlan(data.plan);
        }
      }
    } catch (err) {
      console.error('Failed to load dashboard data:', err);
    }
  }, []);

  useEffect(() => {
    loadDashboardData();
  }, [loadDashboardData]);

  const [copied, setCopied] = useState('');
  const [publishing, setPublishing] = useState(null);

  const handlePublish = async (postId, platform) => {
    setPublishing(postId);
    try {
      const res = await fetch('/api/social/publish', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ post_id: postId, platform }),
      });
      const d = await res.json();
      if (d.success) {
        await loadDashboardData();
      } else {
        alert('Publish failed: ' + (d.error || 'Unknown error'));
      }
    } catch (e) { alert('Publish error: ' + e.message); }
    setPublishing(null);
  };

  const copyToClipboard = useCallback((text, key) => {
    navigator.clipboard.writeText(text);
    setCopied(key);
    setTimeout(() => setCopied(''), 2000);
  }, []);

  // ——— Generate Caption ———
  const handleGenerate = async () => {
    if (!form.topic.trim()) return;
    setGenerating(true);
    setGeneratedContent(null);

    try {
      const res = await fetch('/api/social/ai/caption', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          topic: form.topic, platform: form.platform,
          tone: form.tone.toLowerCase(), language: form.language.toLowerCase(),
        }),
      });

      if (!res.ok) throw new Error(`API error ${res.status}`);
      const data = await res.json();
      setGeneratedContent(data);
    } catch (err) {
      console.error('Generate failed:', err);
      setGeneratedContent({ error: err.message });
    } finally {
      setGenerating(false);
    }
  };

  // ——— Run Full AI Pipeline (Research → Plan → Generate → Save to DB) ———
  const handleGeneratePlan = async () => {
    setPlanLoading(true);
    setPipelineResult(null);
    setAgentStatuses(prev => ({ ...prev, research: 'active', planner: 'active', creator: 'active' }));

    try {
      const res = await fetch('/api/social/cron/run-pipeline', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ manual: true }),
      });

      if (!res.ok) throw new Error(`Pipeline error ${res.status}`);
      const data = await res.json();
      setPipelineResult(data);
      setAgentStatuses(prev => ({ ...prev, research: 'idle', planner: 'idle', creator: 'idle' }));

      // Reload dashboard data to show new posts from DB
      await loadDashboardData();
    } catch (err) {
      console.error('Pipeline failed:', err);
      setAgentStatuses(prev => ({ ...prev, research: 'idle', planner: 'idle', creator: 'idle' }));
    } finally {
      setPlanLoading(false);
    }
  };

  // ——— Render Tabs ———
  const renderMissionControl = () => (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {/* Stats Bar */}
      <div className="stats-grid">
        {[
          { label: 'Posts Today', value: dbStats.total_today || dbPosts.length || 0, sub: 'In database', color: 'var(--info)' },
          { label: 'Generated', value: dbStats.generated_today || 0, sub: 'Ready to publish', color: 'var(--success)' },
          { label: 'Published', value: dbStats.published_today || 0, sub: 'Live', color: 'var(--warning)' },
          { label: 'Pipeline', value: planLoading ? '⏳' : pipelineResult ? `${pipelineResult.posts_created}` : '—', sub: pipelineResult ? `${(pipelineResult.duration_ms/1000).toFixed(1)}s` : 'Click Run', color: 'var(--accent)' },
        ].map((st, i) => (
          <div className="stat-card animate-in" key={i}>
            <div className="stat-value" style={{ fontSize: 28, background: `linear-gradient(135deg, ${st.color}, ${st.color}aa)`, WebkitBackgroundClip: 'text', backgroundClip: 'text', WebkitTextFillColor: 'transparent' }}>{st.value}</div>
            <div className="stat-label">{st.label}</div>
            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>{st.sub}</div>
          </div>
        ))}
      </div>

      <div style={s.grid2}>
        {/* Agent Status */}
        <div style={s.card}>
          <div style={s.cardTitle}>🤖 AI Agents</div>
          {AGENTS.map(agent => (
            <div key={agent.id} style={s.agentRow(agentStatuses[agent.id])}>
              <div style={s.dot(
                agentStatuses[agent.id] === 'active' ? 'var(--success)' :
                agentStatuses[agent.id] === 'idle' ? 'var(--warning)' : 'var(--text-muted)'
              )} />
              <span style={{ fontSize: 18 }}>{agent.icon}</span>
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13, fontWeight: 600 }}>{agent.name}</div>
                <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{agent.desc}</div>
              </div>
              <span className={`badge ${agentStatuses[agent.id] === 'active' ? 'badge-success' : agentStatuses[agent.id] === 'idle' ? 'badge-warning' : ''}`}>
                {agentStatuses[agent.id]}
              </span>
            </div>
          ))}
          <button onClick={handleGeneratePlan} className="btn btn-primary" disabled={planLoading}
            style={{ width: '100%', marginTop: 12, justifyContent: 'center' }}>
            {planLoading ? '⏳ AI Working...' : '🚀 Run AI Pipeline'}
          </button>
        </div>

        {/* Content Queue — from Supabase DB */}
        <div style={s.card}>
          <div style={s.cardTitle}>📋 Today's Content Queue <span style={{fontSize:11, color:'var(--text-muted)', fontWeight:400, marginLeft:8}}>({dbPosts.length} posts in DB)</span></div>
          {dbPosts.length > 0 ? (
            <div>
              <div style={s.queueHeader}>
                <span>TIME</span><span></span><span>TOPIC</span><span>TYPE</span><span>PLAT</span><span>STATUS</span><span>ACTION</span>
              </div>
              {dbPosts.map((post, i) => {
                const plat = PLATFORMS.find(p => p.id === post.platform) || PLATFORMS[0];
                const time = post.scheduled_time ? new Date(post.scheduled_time).toLocaleTimeString('en-IN', {hour:'2-digit', minute:'2-digit', hour12:false}) : '—';
                const statusBadge = post.status === 'generated' ? 'badge-success' : post.status === 'published' ? 'badge-info' : 'badge-warning';
                return (
                  <div key={post.id || i} style={{ ...s.queueRow, animation: `fadeIn 0.3s ease ${i * 0.05}s both` }}>
                    <span style={{ fontWeight: 600, color: 'var(--accent)' }}>{time}</span>
                    <span style={{ fontSize: 18 }}>{plat.icon}</span>
                    <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{post.topic}</span>
                    <span className="badge" style={{ fontSize: 10 }}>{post.content_type}</span>
                    <span style={{ fontSize: 11, color: plat.color }}>{plat.label}</span>
                    <span className={`badge ${statusBadge}`} style={{ fontSize: 10 }}>{post.status}</span>
                    <span>{post.status === 'generated' ? (
                      <button onClick={() => handlePublish(post.id, post.platform)} disabled={publishing === post.id}
                        style={{ padding: '3px 8px', borderRadius: 6, border: '1px solid var(--success)', background: 'rgba(74,222,128,0.1)', color: 'var(--success)', fontSize: 10, cursor: 'pointer', fontFamily: 'Inter', fontWeight: 600 }}>
                        {publishing === post.id ? '⏳' : '📤 Post'}
                      </button>
                    ) : post.status === 'published' ? '✅' : '—'}</span>
                  </div>
                );
              })}
            </div>
          ) : contentPlan?.posts?.length > 0 ? (
            <div>
              <div style={s.queueHeader}>
                <span>TIME</span><span></span><span>TOPIC</span><span>TYPE</span><span>PLAT</span><span>STATUS</span><span>ACTION</span>
              </div>
              {contentPlan.posts.map((post, i) => {
                const plat = PLATFORMS.find(p => p.id === post.platform) || PLATFORMS[0];
                return (
                  <div key={i} style={{ ...s.queueRow, animation: `fadeIn 0.3s ease ${i * 0.05}s both` }}>
                    <span style={{ fontWeight: 600, color: 'var(--accent)' }}>{post.time}</span>
                    <span style={{ fontSize: 18 }}>{plat.icon}</span>
                    <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{post.topic}</span>
                    <span className="badge" style={{ fontSize: 10 }}>{post.content_type}</span>
                    <span style={{ fontSize: 11, color: plat.color }}>{plat.label}</span>
                    <span className="badge badge-info" style={{ fontSize: 10 }}>Planned</span>
                    <span>—</span>
                  </div>
                );
              })}
            </div>
          ) : (
            <div style={{ textAlign: 'center', padding: '40px 20px', color: 'var(--text-muted)' }}>
              <div style={{ fontSize: 40, marginBottom: 12 }}>📋</div>
              <div style={{ fontSize: 14, fontWeight: 500 }}>No content planned yet</div>
              <div style={{ fontSize: 12, marginTop: 4 }}>Click "Run AI Pipeline" to generate today's plan</div>
            </div>
          )}
        </div>
      </div>

      {/* Theme of day */}
      {contentPlan?.theme_of_day && (
        <div style={{ ...s.card, background: 'linear-gradient(135deg, rgba(212,165,116,0.08), rgba(232,200,158,0.04))', borderColor: 'rgba(212,165,116,0.2)' }}>
          <div style={{ fontSize: 13, fontWeight: 600, color: 'var(--accent)', marginBottom: 4 }}>🎯 Today's Theme</div>
          <div style={{ fontSize: 16, fontWeight: 700 }}>{contentPlan.theme_of_day}</div>
          {contentPlan.research_summary && (
            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 8, display: 'flex', gap: 16 }}>
              <span>📊 Trends: {contentPlan.research_summary.trends_found}</span>
              <span>📅 Events: {contentPlan.research_summary.events}</span>
              <span>🌤 Season: {contentPlan.research_summary.season}</span>
              <span>🤖 AI: {contentPlan.ai_provider}</span>
            </div>
          )}
        </div>
      )}
    </div>
  );

  const renderStudio = () => (
    <div style={s.grid2}>
      {/* Form */}
      <div style={s.card}>
        <div style={s.cardTitle}>✍️ Generate Content</div>
        <div style={s.formGroup}>
          <label style={s.label}>Platform</label>
          <div style={{ display: 'flex', gap: 8 }}>
            {PLATFORMS.map(p => (
              <button key={p.id} onClick={() => setForm(f => ({ ...f, platform: p.id }))}
                style={{
                  flex: 1, padding: '10px', borderRadius: 8, border: `2px solid ${form.platform === p.id ? p.color : 'var(--border)'}`,
                  background: form.platform === p.id ? `${p.color}15` : 'var(--bg-surface)',
                  color: form.platform === p.id ? p.color : 'var(--text-secondary)',
                  cursor: 'pointer', fontSize: 13, fontWeight: 600, fontFamily: 'Inter',
                  display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 6, transition: 'all 0.2s',
                }}>
                <span style={{ fontSize: 18 }}>{p.icon}</span> {p.label}
              </button>
            ))}
          </div>
        </div>
        <div style={s.formGroup}>
          <label style={s.label}>Topic / Subject</label>
          <input style={s.input} value={form.topic} onChange={e => setForm(f => ({ ...f, topic: e.target.value }))}
            placeholder="e.g., Morning Meditation Benefits, Surya Namaskar for Beginners..." />
        </div>
        <div style={{ ...s.grid3, ...s.formGroup }}>
          <div>
            <label style={s.label}>Content Type</label>
            <select style={s.select} value={form.contentType} onChange={e => setForm(f => ({ ...f, contentType: e.target.value }))}>
              {CONTENT_TYPES.map(t => <option key={t} value={t}>{t}</option>)}
            </select>
          </div>
          <div>
            <label style={s.label}>Tone</label>
            <select style={s.select} value={form.tone} onChange={e => setForm(f => ({ ...f, tone: e.target.value }))}>
              {TONES.map(t => <option key={t} value={t}>{t}</option>)}
            </select>
          </div>
          <div>
            <label style={s.label}>Language</label>
            <select style={s.select} value={form.language} onChange={e => setForm(f => ({ ...f, language: e.target.value }))}>
              {LANGUAGES.map(l => <option key={l} value={l}>{l}</option>)}
            </select>
          </div>
        </div>
        <button onClick={handleGenerate} className="btn btn-primary" disabled={generating || !form.topic.trim()}
          style={{ width: '100%', justifyContent: 'center', padding: '12px 24px', fontSize: 14 }}>
          {generating ? '⏳ AI Generating...' : '🤖 Generate Content'}
        </button>
      </div>

      {/* Preview */}
      <div style={s.card}>
        <div style={s.cardTitle}>👁️ Preview</div>
        {generating ? (
          <div style={s.preview}>
            {[100, 80, 60, 90, 40].map((w, i) => <div key={i} style={{ ...s.skeleton, width: `${w}%` }} />)}
            <div style={{ textAlign: 'center', color: 'var(--text-muted)', fontSize: 13, marginTop: 20 }}>🤖 AI is creating your content...</div>
          </div>
        ) : generatedContent?.error ? (
          <div style={{ ...s.preview, borderColor: 'var(--error)' }}>
            <div style={{ color: 'var(--error)', fontSize: 13 }}>❌ {generatedContent.error}</div>
          </div>
        ) : generatedContent ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
            {/* AI Image */}
            {generatedContent.image_url && (
              <div style={{ borderRadius: 12, overflow: 'hidden', border: '1px solid var(--border)', position: 'relative' }}>
                <img src={generatedContent.image_url} alt="AI Generated"
                  style={{ width: '100%', height: 260, objectFit: 'cover', display: 'block' }}
                  onError={e => { e.target.style.display = 'none'; }} />
                <div style={{ position: 'absolute', top: 8, right: 8, background: 'rgba(0,0,0,0.6)', padding: '3px 8px', borderRadius: 6, fontSize: 10, color: '#fff' }}>
                  🖼️ AI Generated
                </div>
              </div>
            )}
            {/* Caption */}
            <div style={{ background: 'var(--bg-surface)', borderRadius: 10, padding: 14 }}>
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-muted)' }}>CAPTION</span>
                <button style={s.copyBtn} onClick={() => copyToClipboard(generatedContent.caption, 'caption')}>
                  {copied === 'caption' ? '✅ Copied!' : '📋 Copy'}
                </button>
              </div>
              <div style={{ fontSize: 13, lineHeight: 1.6, whiteSpace: 'pre-wrap' }}>{generatedContent.caption}</div>
            </div>
            {/* Hashtags */}
            {generatedContent.hashtags?.length > 0 && (
              <div style={{ background: 'var(--bg-surface)', borderRadius: 10, padding: 14 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-muted)' }}>HASHTAGS</span>
                  <button style={s.copyBtn} onClick={() => copyToClipboard(generatedContent.hashtags.join(' '), 'hashtags')}>
                    {copied === 'hashtags' ? '✅ Copied!' : '📋 Copy All'}
                  </button>
                </div>
                <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                  {generatedContent.hashtags.map((h, i) => (
                    <span key={i} style={{ fontSize: 11, padding: '3px 8px', borderRadius: 6, background: 'rgba(96,165,250,0.1)', color: 'var(--info)' }}>{h}</span>
                  ))}
                </div>
              </div>
            )}
            {/* Meta */}
            <div style={{ fontSize: 11, color: 'var(--text-muted)', display: 'flex', gap: 12 }}>
              <span>🤖 {generatedContent.ai_model}</span>
              <span>⚡ {generatedContent.ai_provider}</span>
            </div>
          </div>
        ) : (
          <div style={s.preview}>
            <div style={{ textAlign: 'center', margin: 'auto', color: 'var(--text-muted)' }}>
              <div style={{ fontSize: 48, marginBottom: 12 }}>✍️</div>
              <div style={{ fontSize: 14, fontWeight: 500 }}>Enter a topic and generate</div>
              <div style={{ fontSize: 12, marginTop: 4 }}>AI will create caption, hashtags & image</div>
            </div>
          </div>
        )}
      </div>
    </div>
  );

  const renderCalendar = () => {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const today = new Date().getDay(); // 0=Sun
    const todayIdx = today === 0 ? 6 : today - 1;

    return (
      <div>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
          <div>
            <div style={{ fontSize: 15, fontWeight: 700 }}>📅 This Week</div>
            <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
              {contentPlan ? `${contentPlan.posts?.length || 0} posts planned` : 'No plan generated yet'}
            </div>
          </div>
          <button onClick={handleGeneratePlan} className="btn btn-primary btn-sm" disabled={planLoading}>
            {planLoading ? '⏳ Planning...' : '🤖 Generate Weekly Plan'}
          </button>
        </div>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(7, 1fr)', gap: 10 }}>
          {days.map((day, i) => (
            <div key={day} style={{ ...s.calDay, borderColor: i === todayIdx ? 'var(--accent)' : 'var(--border-subtle)' }}>
              <div style={{ ...s.calDayLabel, color: i === todayIdx ? 'var(--accent)' : 'var(--text-muted)' }}>
                {day} {i === todayIdx && '• Today'}
              </div>
              {i === todayIdx && contentPlan?.posts ? (
                contentPlan.posts.map((post, j) => {
                  const plat = PLATFORMS.find(p => p.id === post.platform) || PLATFORMS[0];
                  return (
                    <div key={j} style={s.calPost(plat.color)}>
                      <span style={{ fontWeight: 600 }}>{post.time}</span> {plat.icon}
                      <div style={{ marginTop: 2, fontSize: 10, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {post.topic}
                      </div>
                    </div>
                  );
                })
              ) : (
                <div style={{ fontSize: 11, color: 'var(--text-muted)', textAlign: 'center', padding: '16px 0' }}>
                  {i === todayIdx ? 'Run pipeline' : '—'}
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
    );
  };

  const [platformSettings, setPlatformSettings] = useState(null);
  const [settingsSaving, setSettingsSaving] = useState(false);
  const [settingsMsg, setSettingsMsg] = useState('');
  const [tokenInputs, setTokenInputs] = useState({
    facebook_page_token: '', facebook_page_id: '', instagram_account_id: '',
    youtube_refresh_token: '', youtube_client_id: '', youtube_client_secret: '',
  });

  useEffect(() => {
    fetch('/api/social/settings').then(r => r.json()).then(d => {
      if (!d.error) {
        setPlatformSettings(d);
        if (d.default_tone) {
          setForm(f => ({ ...f, tone: d.default_tone.charAt(0).toUpperCase() + d.default_tone.slice(1) }));
        }
        if (d.default_language) {
          setForm(f => ({ ...f, language: d.default_language.charAt(0).toUpperCase() + d.default_language.slice(1) }));
        }
      }
    }).catch(() => {});
  }, []);

  const saveSettings = async (updates) => {
    setSettingsSaving(true);
    setSettingsMsg('');
    try {
      const res = await fetch('/api/social/settings', {
        method: 'POST', headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(updates),
      });
      const d = await res.json();
      if (d.success) {
        setSettingsMsg('✅ Saved!');
        const r2 = await fetch('/api/social/settings');
        const d2 = await r2.json();
        if (!d2.error) setPlatformSettings(d2);
      } else { setSettingsMsg('❌ ' + (d.error || 'Failed')); }
    } catch { setSettingsMsg('❌ Network error'); }
    setSettingsSaving(false);
    setTimeout(() => setSettingsMsg(''), 3000);
  };

  const handleKillSwitch = async () => {
    if (!confirm('🛑 Stop ALL automation? Disables cron + auto-publish.')) return;
    await saveSettings({ auto_publish: false, cron_enabled: false });
    setAgentStatuses({ research: 'offline', planner: 'offline', creator: 'offline', publisher: 'offline', engagement: 'offline' });
  };

  const renderSettings = () => (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
      {settingsMsg && (
        <div style={{ padding: '10px 16px', borderRadius: 8, background: settingsMsg.includes('✅') ? 'rgba(74,222,128,0.1)' : 'rgba(248,113,113,0.1)', fontSize: 13, fontWeight: 600, color: settingsMsg.includes('✅') ? 'var(--success)' : 'var(--error)' }}>
          {settingsMsg}
        </div>
      )}
      <div style={s.grid2}>
        {/* AI Models */}
        <div style={s.card}>
          <div style={s.cardTitle}>🧠 AI Models</div>
          {[
            { name: 'Groq (Llama 4 Scout)', desc: 'Primary Brain' },
            { name: 'OpenRouter (Qwen3 Free)', desc: 'Backup #1' },
            { name: 'Gemini Flash', desc: 'Backup #2' },
            { name: 'Pollinations.ai', desc: 'Image Generation' },
          ].map((api, i) => (
            <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 14px', borderRadius: 10, background: 'var(--bg-surface)', marginBottom: 6 }}>
              <div style={s.statusDot(true)} />
              <div style={{ flex: 1 }}>
                <div style={{ fontSize: 13, fontWeight: 600 }}>{api.name}</div>
                <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{api.desc}</div>
              </div>
              <span className="badge badge-success" style={{ fontSize: 10 }}>Active</span>
            </div>
          ))}
        </div>
        {/* Platform Connections */}
        <div style={s.card}>
          <div style={s.cardTitle}>📱 Platform Connections</div>
          {[
            { name: 'Facebook Page', icon: '📘', connected: platformSettings?.has_facebook, fields: ['facebook_page_id', 'facebook_page_token'] },
            { name: 'Instagram', icon: '📸', connected: platformSettings?.has_instagram, fields: ['instagram_account_id'] },
            { name: 'YouTube', icon: '📺', connected: platformSettings?.has_youtube, fields: ['youtube_client_id', 'youtube_client_secret', 'youtube_refresh_token'] },
          ].map((p, i) => (
            <div key={i} style={{ padding: '10px 14px', borderRadius: 10, background: 'var(--bg-surface)', marginBottom: 6 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <div style={s.statusDot(p.connected)} />
                <span style={{ fontSize: 16 }}>{p.icon}</span>
                <span style={{ flex: 1, fontSize: 13, fontWeight: 600 }}>{p.name}</span>
                <span className={`badge ${p.connected ? 'badge-success' : 'badge-warning'}`} style={{ fontSize: 10 }}>
                  {p.connected ? 'Connected' : 'Setup Required'}
                </span>
              </div>
              {!p.connected && (
                <div style={{ marginTop: 8 }}>
                  {p.fields.map(f => (
                    <input key={f} style={{ ...s.input, marginBottom: 6, fontSize: 12 }}
                      placeholder={f.replace(/_/g, ' ').toUpperCase()}
                      value={tokenInputs[f]}
                      onChange={e => setTokenInputs(prev => ({ ...prev, [f]: e.target.value }))} />
                  ))}
                  <button className="btn btn-sm btn-primary" style={{ width: '100%', justifyContent: 'center', marginTop: 4 }}
                    disabled={settingsSaving}
                    onClick={() => {
                      const updates = {};
                      p.fields.forEach(f => { if (tokenInputs[f]) updates[f] = tokenInputs[f]; });
                      if (Object.keys(updates).length > 0) saveSettings(updates);
                    }}>
                    {settingsSaving ? '⏳...' : '🔗 Connect'}
                  </button>
                </div>
              )}
            </div>
          ))}
        </div>
      </div>
      <div style={s.grid2}>
        {/* Automation */}
        <div style={s.card}>
          <div style={s.cardTitle}>⚡ Automation</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 14px', borderRadius: 10, background: 'var(--bg-surface)', marginBottom: 12 }}>
            <span style={{ flex: 1 }}>
              <div style={{ fontSize: 13, fontWeight: 600 }}>Auto-Publish</div>
              <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>Auto-post to connected platforms</div>
            </span>
            <button onClick={() => saveSettings({ auto_publish: !platformSettings?.auto_publish })}
              style={{
                width: 48, height: 26, borderRadius: 13, border: 'none', cursor: 'pointer',
                background: platformSettings?.auto_publish ? 'var(--success)' : 'var(--border)',
                position: 'relative', transition: 'background 0.2s',
              }}>
              <div style={{
                width: 20, height: 20, borderRadius: '50%', background: '#fff', position: 'absolute', top: 3,
                left: platformSettings?.auto_publish ? 25 : 3, transition: 'left 0.2s',
              }} />
            </button>
          </div>
          <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 10 }}>📊 Posts Per Day</div>
          {PLATFORMS.map(p => (
            <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 10 }}>
              <span style={{ fontSize: 18 }}>{p.icon}</span>
              <span style={{ flex: 1, fontSize: 13, fontWeight: 500 }}>{p.label}</span>
              <select style={{ ...s.select, width: 90 }} value={platformSettings?.posting_frequency?.[p.id] || 1}
                onChange={e => {
                  const newFreq = { ...platformSettings?.posting_frequency, [p.id]: +e.target.value };
                  saveSettings({ posting_frequency: newFreq });
                }}>
                {[1, 2, 3, 4, 5].map(n => <option key={n} value={n}>{n}/day</option>)}
              </select>
            </div>
          ))}

          <div style={{ height: 1, background: 'var(--border-subtle)', margin: '14px 0' }} />

          <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 10 }}>🎭 Default Content Tone</div>
          <select style={{ ...s.select, marginBottom: 12 }} value={platformSettings?.default_tone || 'motivational'}
            onChange={e => saveSettings({ default_tone: e.target.value })}>
            {TONES.map(t => <option key={t} value={t.toLowerCase()}>{t}</option>)}
          </select>

          <div style={{ fontSize: 13, fontWeight: 600, marginBottom: 10 }}>🌐 Default Content Language</div>
          <select style={s.select} value={platformSettings?.default_language || 'hinglish'}
            onChange={e => saveSettings({ default_language: e.target.value })}>
            {LANGUAGES.map(l => <option key={l} value={l.toLowerCase()}>{l}</option>)}
          </select>
        </div>
        {/* Cron + Kill */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div style={s.card}>
            <div style={s.cardTitle}>⏰ Cron Schedule</div>
            <div style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 6 }}>Daily pipeline at <b style={{ color: 'var(--accent)' }}>7:00 AM IST</b></div>
            <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>Research → Plan → Generate → {platformSettings?.auto_publish ? 'Auto-Publish ✅' : 'Manual Review'}</div>
          </div>
          <div style={s.card}>
            <div style={s.cardTitle}>🚨 Kill Switch</div>
            <p style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 12 }}>Emergency stop ALL automation.</p>
            <button style={s.killBtn} onClick={handleKillSwitch}
              onMouseEnter={e => { e.target.style.background = 'rgba(248,113,113,0.2)'; e.target.style.transform = 'scale(1.02)'; }}
              onMouseLeave={e => { e.target.style.background = 'rgba(248,113,113,0.1)'; e.target.style.transform = 'scale(1)'; }}>
              🛑 KILL ALL AUTOMATION
            </button>
          </div>
        </div>
      </div>
    </div>
  );

  return (
    <div style={s.page}>
      <style>{`
        @keyframes shimmer { 0% { background-position: -200% 0; } 100% { background-position: 200% 0; } }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.5; } }
        @keyframes fadeIn { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
      `}</style>

      <div className="page-header">
        <div>
          <h1>🤖 Social Media Manager</h1>
          <p style={s.subtitle}>AI-powered autonomous content engine for YouTube, Instagram & Facebook</p>
        </div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          <div style={s.dot('var(--success)')} />
          <span style={{ fontSize: 12, color: 'var(--success)', fontWeight: 600 }}>System Active</span>
        </div>
      </div>

      {/* Tabs */}
      <div style={s.tabs}>
        {TABS.map(tab => (
          <button key={tab.id} style={s.tab(activeTab === tab.id)} onClick={() => setActiveTab(tab.id)}>
            <span>{tab.icon}</span> {tab.label}
          </button>
        ))}
      </div>

      {/* Tab Content */}
      {activeTab === 'control' && renderMissionControl()}
      {activeTab === 'studio' && renderStudio()}
      {activeTab === 'calendar' && renderCalendar()}
      {activeTab === 'settings' && renderSettings()}
    </div>
  );
}

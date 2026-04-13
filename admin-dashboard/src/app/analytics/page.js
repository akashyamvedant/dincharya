'use client';
import { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase';

export default function AnalyticsPage() {
    const supabase = createClient();
    const [loading, setLoading] = useState(true);
    const [period, setPeriod] = useState('30');
    const [tab, setTab] = useState('overview');

    // GA4 date picker state
    const [ga4Preset, setGa4Preset] = useState('30'); // today, yesterday, 7, 14, 30, 90, custom
    const [customStart, setCustomStart] = useState('');
    const [customEnd, setCustomEnd] = useState('');
    const [showCustomPicker, setShowCustomPicker] = useState(false);

    // Supabase data states
    const [activeStats, setActiveStats] = useState({ dau: 0, wau: 0, mau: 0, total_users: 0 });
    const [dauChart, setDauChart] = useState([]);
    const [activityFeed, setActivityFeed] = useState([]);
    const [userSummary, setUserSummary] = useState([]);
    const [metrics, setMetrics] = useState({ userGrowth: [], categoryBreakdown: [], moodTrend: [], engagementByDay: [], topSessions: [] });

    // GA4 data states
    const [ga4Loading, setGa4Loading] = useState(false);
    const [ga4Error, setGa4Error] = useState(null);
    const [ga4Overview, setGa4Overview] = useState(null);
    const [ga4Realtime, setGa4Realtime] = useState(null);
    const [ga4DailyUsers, setGa4DailyUsers] = useState([]);
    const [ga4Demographics, setGa4Demographics] = useState(null);
    const [ga4Devices, setGa4Devices] = useState(null);
    const [ga4TopScreens, setGa4TopScreens] = useState([]);
    const [ga4Events, setGa4Events] = useState([]);
    const [ga4Retention, setGa4Retention] = useState(null);
    const [ga4Traffic, setGa4Traffic] = useState([]);
    const [ga4Hourly, setGa4Hourly] = useState([]);
    const [ga4AppVersions, setGa4AppVersions] = useState([]);
    const [ga4LastRefresh, setGa4LastRefresh] = useState(null);

    // GA4 sub-tabs
    const [ga4SubTab, setGa4SubTab] = useState('overview');

    useEffect(() => { fetchAll(); }, [period]);

    // Auto-refresh realtime every 30s when on ga4 tab
    useEffect(() => {
        if (tab !== 'ga4') return;
        const interval = setInterval(() => fetchGA4('realtime', setGa4Realtime), 30000);
        return () => clearInterval(interval);
    }, [tab]);

    // Load GA4 data when switching to ga4 tab
    useEffect(() => {
        if (tab === 'ga4' && !ga4Overview) fetchAllGA4();
    }, [tab]);

    // Build GA4 query params
    const ga4Params = useCallback(() => {
        if (ga4Preset === 'today') return 'preset=today';
        if (ga4Preset === 'yesterday') return 'preset=yesterday';
        if (ga4Preset === 'custom' && customStart && customEnd) return `preset=custom&startDate=${customStart}&endDate=${customEnd}`;
        return `days=${ga4Preset}`;
    }, [ga4Preset, customStart, customEnd]);

    const fetchGA4 = async (type, setter) => {
        try {
            const res = await fetch(`/api/analytics/ga?type=${type}&${ga4Params()}`);
            const data = await res.json();
            if (res.ok) setter(data);
            else throw new Error(data.error);
        } catch (e) { console.error(`GA4 ${type} error:`, e); }
    };

    const fetchAllGA4 = async () => {
        setGa4Loading(true);
        setGa4Error(null);
        try {
            await Promise.all([
                fetchGA4('overview', setGa4Overview),
                fetchGA4('realtime', setGa4Realtime),
                fetchGA4('daily_users', setGa4DailyUsers),
                fetchGA4('demographics', setGa4Demographics),
                fetchGA4('devices', setGa4Devices),
                fetchGA4('top_screens', setGa4TopScreens),
                fetchGA4('events', setGa4Events),
                fetchGA4('retention', setGa4Retention),
                fetchGA4('traffic_sources', setGa4Traffic),
                fetchGA4('hourly', setGa4Hourly),
                fetchGA4('app_versions', setGa4AppVersions),
            ]);
            setGa4LastRefresh(new Date());
        } catch (e) { setGa4Error(e.message); }
        setGa4Loading(false);
    };

    // Refetch GA4 when preset changes (only if on ga4 tab)
    useEffect(() => {
        if (tab === 'ga4' && ga4Overview) fetchAllGA4();
    }, [ga4Preset, customStart, customEnd]);

    const fetchAll = async () => {
        setLoading(true);
        await Promise.all([fetchActiveStats(), fetchDauChart(), fetchActivityFeed(), fetchUserSummary(), fetchExistingMetrics()]);
        setLoading(false);
        if (tab === 'ga4') fetchAllGA4();
    };

    const fetchActiveStats = async () => {
        const { data, error } = await supabase.rpc('get_active_user_stats');
        if (!error && data) setActiveStats(data);
    };
    const fetchDauChart = async () => {
        const { data, error } = await supabase.rpc('get_dau_chart', { days_back: parseInt(period) });
        if (!error && data) setDauChart(data);
    };
    const fetchActivityFeed = async () => {
        const { data, error } = await supabase.rpc('get_user_activity_feed', { limit_count: 50 });
        if (!error && data) setActivityFeed(data);
    };
    const fetchUserSummary = async () => {
        const { data, error } = await supabase.rpc('get_user_activity_summary');
        if (!error && data) setUserSummary(data);
    };
    const fetchExistingMetrics = async () => {
        const days = parseInt(period);
        const since = new Date(); since.setDate(since.getDate() - days);
        const userGrowth = [];
        for (let i = Math.min(days, 14) - 1; i >= 0; i--) {
            const d = new Date(); d.setDate(d.getDate() - i);
            const start = new Date(d); start.setHours(0, 0, 0, 0);
            const end = new Date(d); end.setHours(23, 59, 59, 999);
            const { count } = await supabase.from('user_profiles').select('id', { count: 'exact', head: true })
                .gte('created_at', start.toISOString()).lte('created_at', end.toISOString());
            userGrowth.push({ label: d.toLocaleDateString('en', { month: 'short', day: 'numeric' }), value: count || 0 });
        }
        const { data: sessData } = await supabase.from('sessions').select('category');
        const catMap = {};
        (sessData || []).forEach(s => { catMap[s.category] = (catMap[s.category] || 0) + 1; });
        const categoryBreakdown = Object.entries(catMap).sort(([, a], [, b]) => b - a).map(([name, count]) => ({ name, count }));
        const { data: moodData } = await supabase.from('journal_entries').select('mood_rating, created_at')
            .gte('created_at', since.toISOString()).order('created_at').limit(200);
        const moodByDay = {};
        (moodData || []).forEach(m => {
            const day = new Date(m.created_at).toLocaleDateString('en', { month: 'short', day: 'numeric' });
            if (!moodByDay[day]) moodByDay[day] = { sum: 0, count: 0 };
            moodByDay[day].sum += (m.mood_rating || 0); moodByDay[day].count += 1;
        });
        const moodTrend = Object.entries(moodByDay).map(([label, { sum, count }]) => ({ label, value: Math.round((sum / count) * 10) / 10 }));
        const { data: topData } = await supabase.from('sessions').select('title, category, view_count').order('view_count', { ascending: false }).limit(10);
        const { data: practiceData } = await supabase.from('practice_sessions').select('created_at')
            .gte('created_at', since.toISOString()).limit(500);
        const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const dayCounts = new Array(7).fill(0);
        (practiceData || []).forEach(p => { dayCounts[new Date(p.created_at).getDay()] += 1; });
        const engagementByDay = dayNames.map((name, i) => ({ name, count: dayCounts[i] }));
        setMetrics({ userGrowth, categoryBreakdown, moodTrend, engagementByDay, topSessions: topData || [] });
    };

    // ─── Helpers ─────────────────────────────────────────
    const maxVal = (arr) => Math.max(1, ...arr.map(d => d.value || d.count || d.active_users || d.activeUsers || d.views || d.users || d.sessions || 0));
    const activityIcon = (type) => { switch (type) { case 'routine': return '🏃'; case 'practice': return '🧘'; case 'journal': return '📝'; default: return '📌'; } };
    const relativeTime = (ts) => {
        if (!ts) return '—';
        const diff = Date.now() - new Date(ts).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 1) return 'Just now'; if (mins < 60) return `${mins}m ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return `${hrs}h ago`; return `${Math.floor(hrs / 24)}d ago`;
    };
    const dauRetentionRate = () => {
        if (!activeStats.total_users || activeStats.total_users === 0) return 0;
        return Math.round((activeStats.dau / activeStats.total_users) * 100);
    };
    const fmtDuration = (s) => { if (!s || s === 0) return '0s'; if (s < 60) return `${s}s`; return `${Math.floor(s / 60)}m ${s % 60}s`; };
    const changeArrow = (v) => v > 0 ? `↑${v}%` : v < 0 ? `↓${Math.abs(v)}%` : '—';
    const changeColor = (v) => v > 0 ? '#4ade80' : v < 0 ? '#f87171' : 'var(--text-muted)';
    const deviceIcon = (d) => { const dl = (d || '').toLowerCase(); if (dl.includes('mobile') || dl.includes('phone')) return '📱'; if (dl.includes('desktop')) return '💻'; if (dl.includes('tablet')) return '📟'; return '🖥️'; };
    const eventIcon = (e) => ({ 'session_start': '🚀', 'first_visit': '👋', 'first_open': '📲', 'screen_view': '👁️', 'user_engagement': '💡', 'task_completed': '✅', 'yoga_session_start': '🧘', 'yoga_session_complete': '🏆', 'daily_progress': '📊', 'subscription_event': '💎', 'ad_impression': '📢', 'ad_click': '👆', 'app_update': '🔄', 'app_remove': '🗑️', 'os_update': '⬆️', 'dynamic_link_app_open': '🔗' })[e] || '⚡';

    const presetLabel = () => {
        if (ga4Preset === 'today') return 'Today';
        if (ga4Preset === 'yesterday') return 'Yesterday';
        if (ga4Preset === 'custom') return `${customStart} → ${customEnd}`;
        return `Last ${ga4Preset} days`;
    };

    const ga4SubTabs = [
        { id: 'overview', icon: '📊', label: 'Overview' },
        { id: 'engagement', icon: '💡', label: 'Engagement' },
        { id: 'audience', icon: '🌍', label: 'Audience' },
        { id: 'events', icon: '⚡', label: 'Events' },
        { id: 'tech', icon: '📱', label: 'Tech' },
    ];

    const tabs = [
        { id: 'overview', label: '📊 Overview' },
        { id: 'ga4', label: '🔥 Google Analytics' },
        { id: 'activity', label: '🔴 Live Activity' },
        { id: 'users', label: '👥 User Breakdown' },
        { id: 'content', label: '📈 Content & Mood' },
    ];

    // ─── Card Component ──────────────────────────────────
    const MetricCard = ({ label, value, icon, change, color, sub }) => (
        <div className="card" style={{ textAlign: 'center', background: `linear-gradient(135deg, ${color}15, transparent)`, border: `1px solid ${color}30`, position: 'relative', overflow: 'hidden' }}>
            <div style={{ position: 'absolute', top: -10, right: -10, fontSize: 48, opacity: 0.06 }}>{icon}</div>
            <div style={{ fontSize: 30, fontWeight: 900, color, lineHeight: 1.1 }}>{typeof value === 'number' ? value.toLocaleString() : value}</div>
            <div style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-secondary)', marginTop: 4 }}>{icon} {label}</div>
            {change !== undefined && <div style={{ fontSize: 11, fontWeight: 700, color: changeColor(change), marginTop: 6, padding: '2px 8px', background: `${changeColor(change)}15`, borderRadius: 20, display: 'inline-block' }}>{changeArrow(change)} vs prev</div>}
            {sub && <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 4 }}>{sub}</div>}
        </div>
    );

    // ─── Bar Chart Component ─────────────────────────────
    const BarChart = ({ data, valueKey, labelKey, height = 180, color = 'rgba(99,102,241,0.5)', todayKey, showLabels = true }) => (
        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 1, height, paddingBottom: showLabels ? 28 : 0 }}>
            {data.map((d, i) => {
                const val = d[valueKey] || 0;
                const max = Math.max(1, ...data.map(x => x[valueKey] || 0));
                const isToday = todayKey && d[todayKey] === new Date().toISOString().split('T')[0];
                return (
                    <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative' }} title={`${d[labelKey]}: ${val}`}>
                        {val > 0 && data.length <= 31 && <div style={{ fontSize: 8, fontWeight: 700, color: isToday ? '#818cf8' : 'var(--text-muted)', marginBottom: 1 }}>{val}</div>}
                        <div style={{ width: '100%', maxWidth: 18, minHeight: 2, height: `${Math.max(2, (val / max) * (height - 40))}px`, background: isToday ? 'linear-gradient(180deg, #818cf8, #6366f1)' : color, borderRadius: '3px 3px 0 0', transition: 'height 0.4s ease' }} />
                        {showLabels && (i % Math.max(1, Math.ceil(data.length / 8)) === 0 || isToday) && (
                            <div style={{ fontSize: 7, color: isToday ? '#818cf8' : 'var(--text-muted)', position: 'absolute', bottom: -22, whiteSpace: 'nowrap', fontWeight: isToday ? 700 : 400, transform: 'rotate(-40deg)' }}>
                                {typeof d[labelKey] === 'string' && d[labelKey].includes('-') ? new Date(d[labelKey]).toLocaleDateString('en', { month: 'short', day: 'numeric' }) : d[labelKey]}
                            </div>
                        )}
                    </div>
                );
            })}
        </div>
    );

    return (
        <div>
            <div className="page-header">
                <div><h1>Analytics</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>Active users, engagement & activity insights</p></div>
                <select className="search-input" value={period} onChange={e => setPeriod(e.target.value)} style={{ width: 150 }}>
                    <option value="7">Last 7 days</option>
                    <option value="14">Last 14 days</option>
                    <option value="30">Last 30 days</option>
                </select>
            </div>

            {/* Tabs */}
            <div style={{ display: 'flex', gap: 4, marginBottom: 24, background: 'var(--bg-surface)', borderRadius: 10, padding: 4, border: '1px solid var(--border-subtle)' }}>
                {tabs.map(t => (
                    <button key={t.id} onClick={() => setTab(t.id)} style={{
                        flex: 1, padding: '10px 16px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 600,
                        background: tab === t.id ? 'var(--accent-gradient)' : 'transparent',
                        color: tab === t.id ? '#fff' : 'var(--text-secondary)', transition: 'all 0.2s',
                    }}>{t.label}</button>
                ))}
            </div>

            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading analytics...</p> : (
                <>
                    {/* ═══════════ OVERVIEW TAB ═══════════ */}
                    {tab === 'overview' && (
                        <div>
                            <div className="stats-grid" style={{ marginBottom: 24 }}>
                                <div className="card" style={{ textAlign: 'center', background: 'linear-gradient(135deg, rgba(99,102,241,0.1), rgba(168,85,247,0.1))', border: '1px solid rgba(99,102,241,0.3)' }}>
                                    <div style={{ fontSize: 36, fontWeight: 900, color: '#818cf8' }}>{activeStats.dau}</div>
                                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)', marginTop: 2 }}>Daily Active</div>
                                    <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Today</div>
                                </div>
                                <div className="card" style={{ textAlign: 'center', background: 'linear-gradient(135deg, rgba(59,130,246,0.1), rgba(37,99,235,0.1))', border: '1px solid rgba(59,130,246,0.3)' }}>
                                    <div style={{ fontSize: 36, fontWeight: 900, color: '#60a5fa' }}>{activeStats.wau}</div>
                                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)', marginTop: 2 }}>Weekly Active</div>
                                    <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Last 7 days</div>
                                </div>
                                <div className="card" style={{ textAlign: 'center', background: 'linear-gradient(135deg, rgba(16,185,129,0.1), rgba(5,150,105,0.1))', border: '1px solid rgba(16,185,129,0.3)' }}>
                                    <div style={{ fontSize: 36, fontWeight: 900, color: '#34d399' }}>{activeStats.mau}</div>
                                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)', marginTop: 2 }}>Monthly Active</div>
                                    <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 4 }}>Last 30 days</div>
                                </div>
                                <div className="card" style={{ textAlign: 'center' }}>
                                    <div style={{ fontSize: 36, fontWeight: 900 }}>{activeStats.total_users}</div>
                                    <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)', marginTop: 2 }}>Total Users</div>
                                    <div style={{ fontSize: 11, color: dauRetentionRate() > 10 ? '#4ade80' : '#f97316', marginTop: 4, fontWeight: 600 }}>{dauRetentionRate()}% DAU Rate</div>
                                </div>
                            </div>
                            <div className="card" style={{ marginBottom: 24 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>📈 Daily Active Users (Last {period} days)</h3>
                                <BarChart data={dauChart} valueKey="active_users" labelKey="day" todayKey="day" height={180} />
                            </div>
                            <div className="card" style={{ marginBottom: 24 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>👤 New Signups (Last {Math.min(parseInt(period), 14)} days)</h3>
                                <BarChart data={metrics.userGrowth} valueKey="value" labelKey="label" height={140} color="rgba(168,85,247,0.4)" />
                            </div>
                        </div>
                    )}

                    {/* ═══════════ GOOGLE ANALYTICS TAB ═══════════ */}
                    {tab === 'ga4' && (
                        <div>
                            {/* Date Picker Toolbar */}
                            <div className="card" style={{ marginBottom: 16, padding: '12px 18px', display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                                <span style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-secondary)', marginRight: 4 }}>📅 Date Range:</span>
                                {[
                                    { v: 'today', l: 'Today' }, { v: 'yesterday', l: 'Yesterday' },
                                    { v: '7', l: '7D' }, { v: '14', l: '14D' }, { v: '30', l: '30D' }, { v: '90', l: '90D' },
                                ].map(p => (
                                    <button key={p.v} onClick={() => { setGa4Preset(p.v); setShowCustomPicker(false); }} style={{
                                        padding: '5px 12px', borderRadius: 6, border: 'none', cursor: 'pointer', fontSize: 11, fontWeight: 700,
                                        background: ga4Preset === p.v ? 'var(--accent-gradient)' : 'var(--bg-hover)',
                                        color: ga4Preset === p.v ? '#fff' : 'var(--text-secondary)', transition: 'all 0.2s',
                                    }}>{p.l}</button>
                                ))}
                                <button onClick={() => { setGa4Preset('custom'); setShowCustomPicker(true); }} style={{
                                    padding: '5px 12px', borderRadius: 6, border: 'none', cursor: 'pointer', fontSize: 11, fontWeight: 700,
                                    background: ga4Preset === 'custom' ? 'var(--accent-gradient)' : 'var(--bg-hover)',
                                    color: ga4Preset === 'custom' ? '#fff' : 'var(--text-secondary)',
                                }}>📆 Custom</button>
                                {showCustomPicker && (
                                    <div style={{ display: 'flex', gap: 6, alignItems: 'center' }}>
                                        <input type="date" value={customStart} onChange={e => setCustomStart(e.target.value)} style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid var(--border-subtle)', background: 'var(--bg-surface)', color: 'var(--text-primary)', fontSize: 11 }} />
                                        <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>→</span>
                                        <input type="date" value={customEnd} onChange={e => setCustomEnd(e.target.value)} style={{ padding: '4px 8px', borderRadius: 6, border: '1px solid var(--border-subtle)', background: 'var(--bg-surface)', color: 'var(--text-primary)', fontSize: 11 }} />
                                    </div>
                                )}
                                <div style={{ marginLeft: 'auto', display: 'flex', alignItems: 'center', gap: 8 }}>
                                    {ga4LastRefresh && <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>Updated {relativeTime(ga4LastRefresh)}</span>}
                                    <button onClick={fetchAllGA4} disabled={ga4Loading} style={{ padding: '5px 12px', borderRadius: 6, border: 'none', cursor: 'pointer', fontSize: 11, fontWeight: 700, background: 'rgba(99,102,241,0.15)', color: '#818cf8' }}>
                                        {ga4Loading ? '⏳' : '🔄'} Refresh
                                    </button>
                                </div>
                            </div>

                            {ga4Error && <div className="card" style={{ background: 'rgba(248,113,113,0.08)', border: '1px solid rgba(248,113,113,0.25)', color: '#f87171', marginBottom: 16, fontSize: 13 }}>⚠️ {ga4Error}</div>}

                            {ga4Loading && !ga4Overview && <div style={{ textAlign: 'center', padding: 60 }}><div style={{ fontSize: 32, marginBottom: 12 }}>⏳</div><p style={{ color: 'var(--text-muted)' }}>Loading Google Analytics data...</p></div>}

                            {ga4Overview && (<>
                            {/* Realtime Banner */}
                            {ga4Realtime && (
                                <div style={{ marginBottom: 16, padding: '14px 20px', borderRadius: 12, background: 'linear-gradient(135deg, rgba(239,68,68,0.08), rgba(220,38,38,0.04))', border: '1px solid rgba(239,68,68,0.2)', display: 'flex', alignItems: 'center', gap: 14, flexWrap: 'wrap' }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                        <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#ef4444', animation: 'pulse 1.5s infinite', boxShadow: '0 0 8px rgba(239,68,68,0.5)' }} />
                                        <span style={{ fontSize: 11, fontWeight: 800, color: '#ef4444', letterSpacing: 1 }}>LIVE</span>
                                        <span style={{ fontSize: 32, fontWeight: 900, color: '#fff', lineHeight: 1 }}>{ga4Realtime.activeUsers}</span>
                                        <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>active now</span>
                                    </div>
                                    <div style={{ marginLeft: 'auto', display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                                        {(ga4Realtime.byDevice || []).map(d => (
                                            <span key={d.device} style={{ fontSize: 11, color: 'var(--text-secondary)', background: 'rgba(255,255,255,0.05)', padding: '3px 10px', borderRadius: 20 }}>
                                                {deviceIcon(d.device)} {d.users}
                                            </span>
                                        ))}
                                        {(ga4Realtime.byCountry || []).slice(0, 4).map(c => (
                                            <span key={c.country} style={{ fontSize: 10, color: 'var(--text-muted)', background: 'rgba(255,255,255,0.03)', padding: '3px 8px', borderRadius: 12 }}>🌍 {c.country}: {c.users}</span>
                                        ))}
                                    </div>
                                    {(ga4Realtime.byScreen || []).length > 0 && (
                                        <div style={{ width: '100%', display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 2 }}>
                                            <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>Active screens:</span>
                                            {ga4Realtime.byScreen.slice(0, 5).map(s => (
                                                <span key={s.screen} style={{ fontSize: 10, color: '#818cf8', background: 'rgba(99,102,241,0.1)', padding: '2px 8px', borderRadius: 8 }}>{s.screen} ({s.users})</span>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* GA4 Sub-tabs */}
                            <div style={{ display: 'flex', gap: 3, marginBottom: 16 }}>
                                {ga4SubTabs.map(t => (
                                    <button key={t.id} onClick={() => setGa4SubTab(t.id)} style={{
                                        padding: '7px 14px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 11, fontWeight: 700,
                                        background: ga4SubTab === t.id ? 'rgba(99,102,241,0.15)' : 'transparent',
                                        color: ga4SubTab === t.id ? '#818cf8' : 'var(--text-muted)', transition: 'all 0.15s',
                                        borderBottom: ga4SubTab === t.id ? '2px solid #818cf8' : '2px solid transparent',
                                    }}>{t.icon} {t.label}</button>
                                ))}
                                <span style={{ marginLeft: 'auto', fontSize: 10, color: 'var(--text-muted)', alignSelf: 'center' }}>📅 {presetLabel()}</span>
                            </div>

                            {/* ── Overview Sub-tab ── */}
                            {ga4SubTab === 'overview' && (<>
                                <div className="stats-grid" style={{ marginBottom: 16 }}>
                                    <MetricCard label="Active Users" value={ga4Overview.activeUsers} icon="👥" change={ga4Overview.changes?.activeUsers} color="#818cf8" />
                                    <MetricCard label="New Users" value={ga4Overview.newUsers} icon="🆕" change={ga4Overview.changes?.newUsers} color="#34d399" />
                                    <MetricCard label="Sessions" value={ga4Overview.sessions} icon="📊" change={ga4Overview.changes?.sessions} color="#60a5fa" />
                                    <MetricCard label="Screen Views" value={ga4Overview.screenPageViews} icon="👁️" change={ga4Overview.changes?.screenPageViews} color="#a855f7" />
                                </div>
                                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 10, marginBottom: 16 }}>
                                    {[
                                        { l: 'Engagement Rate', v: `${ga4Overview.engagementRate}%`, c: ga4Overview.engagementRate > 50 ? '#4ade80' : '#fbbf24' },
                                        { l: 'Avg Session', v: fmtDuration(ga4Overview.avgSessionDuration), c: '#60a5fa' },
                                        { l: 'Sessions/User', v: ga4Overview.sessionsPerUser, c: '#a855f7' },
                                        { l: 'Total Users', v: ga4Overview?.totalUsers?.toLocaleString(), c: '#818cf8' },
                                    ].map(m => (
                                        <div key={m.l} className="card" style={{ textAlign: 'center', padding: '12px 8px' }}>
                                            <div style={{ fontSize: 20, fontWeight: 900, color: m.c }}>{m.v}</div>
                                            <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 2 }}>{m.l}</div>
                                        </div>
                                    ))}
                                </div>
                                {ga4DailyUsers.length > 0 && (
                                    <div className="card" style={{ marginBottom: 16 }}>
                                        <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 14 }}>📈 Daily Active Users — {presetLabel()}</h3>
                                        <BarChart data={ga4DailyUsers} valueKey="activeUsers" labelKey="date" todayKey="date" height={170} />
                                    </div>
                                )}
                                {/* Retention */}
                                {ga4Retention && (
                                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
                                        {['new', 'returning'].map(type => {
                                            const d = ga4Retention[type];
                                            if (!d) return null;
                                            return (
                                                <div key={type} className="card" style={{ display: 'flex', alignItems: 'center', gap: 16 }}>
                                                    <div style={{ width: 56, height: 56, borderRadius: '50%', background: type === 'new' ? 'rgba(52,211,153,0.1)' : 'rgba(96,165,250,0.1)', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 24, flexShrink: 0 }}>
                                                        {type === 'new' ? '🆕' : '🔁'}
                                                    </div>
                                                    <div>
                                                        <div style={{ fontSize: 11, fontWeight: 700, color: type === 'new' ? '#34d399' : '#60a5fa', textTransform: 'capitalize' }}>{type} Users</div>
                                                        <div style={{ fontSize: 26, fontWeight: 900 }}>{d.users}</div>
                                                        <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{d.sessions} sessions · {d.engagementRate}% engaged · {fmtDuration(d.avgDuration)} avg</div>
                                                    </div>
                                                </div>
                                            );
                                        })}
                                    </div>
                                )}
                            </>)}

                            {/* ── Engagement Sub-tab ── */}
                            {ga4SubTab === 'engagement' && (<>
                                {/* Hourly breakdown */}
                                {ga4Hourly.length > 0 && (
                                    <div className="card" style={{ marginBottom: 16 }}>
                                        <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 14 }}>🕐 Hourly Activity Pattern</h3>
                                        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 140 }}>
                                            {ga4Hourly.map((h, i) => {
                                                const max = Math.max(1, ...ga4Hourly.map(x => x.users));
                                                const now = new Date().getHours();
                                                return (
                                                    <div key={i} style={{ flex: 1, textAlign: 'center' }} title={`${h.hour}:00 — ${h.users} users, ${h.sessions} sessions`}>
                                                        <div style={{ fontSize: 7, color: 'var(--text-muted)', marginBottom: 2 }}>{h.users > 0 ? h.users : ''}</div>
                                                        <div style={{ height: `${Math.max(2, (h.users / max) * 100)}px`, background: h.hour === now ? 'linear-gradient(180deg, #818cf8, #6366f1)' : h.users > 0 ? 'rgba(99,102,241,0.3)' : 'var(--bg-hover)', borderRadius: '3px 3px 0 0', transition: 'height 0.3s', border: h.hour === now ? '1px solid #818cf8' : 'none' }} />
                                                        <div style={{ fontSize: 8, color: h.hour === now ? '#818cf8' : 'var(--text-muted)', marginTop: 3, fontWeight: h.hour === now ? 700 : 400 }}>{h.hour}</div>
                                                    </div>
                                                );
                                            })}
                                        </div>
                                        <div style={{ textAlign: 'center', fontSize: 10, color: 'var(--text-muted)', marginTop: 8 }}>Hour of day (0-23) · Peak: {ga4Hourly.reduce((a, b) => a.users > b.users ? a : b, { users: 0 }).hour}:00</div>
                                    </div>
                                )}
                                {/* Top Screens */}
                                {ga4TopScreens.length > 0 && (
                                    <div className="card" style={{ padding: 0, marginBottom: 16 }}>
                                        <h3 style={{ fontSize: 14, fontWeight: 700, padding: '16px 20px 10px' }}>📄 Top Screens</h3>
                                        <table className="data-table">
                                            <thead><tr><th>#</th><th>Screen</th><th>Views</th><th>Users</th><th>Avg Time</th></tr></thead>
                                            <tbody>
                                                {ga4TopScreens.slice(0, 15).map((s, i) => (
                                                    <tr key={i}>
                                                        <td style={{ fontWeight: 700, color: i < 3 ? '#818cf8' : 'var(--text-muted)' }}>{i + 1}</td>
                                                        <td style={{ fontSize: 12, fontWeight: 600, maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.screen}</td>
                                                        <td style={{ fontWeight: 700, fontFamily: 'monospace' }}>{s.views}</td>
                                                        <td style={{ fontFamily: 'monospace' }}>{s.users}</td>
                                                        <td style={{ fontSize: 11, color: 'var(--text-muted)' }}>{fmtDuration(s.avgDuration)}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                                {/* Traffic Sources */}
                                {ga4Traffic.length > 0 && (
                                    <div className="card" style={{ marginBottom: 16 }}>
                                        <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 12 }}>🔗 Traffic Sources</h3>
                                        {ga4Traffic.slice(0, 10).map((t, i) => (
                                            <div key={i} style={{ display: 'flex', alignItems: 'center', fontSize: 12, padding: '6px 0', borderBottom: '1px solid var(--border-subtle)', gap: 8 }}>
                                                <span style={{ fontWeight: 700, minWidth: 20, color: 'var(--text-muted)' }}>{i + 1}</span>
                                                <span style={{ flex: 1 }}><b>{t.source}</b> / <span style={{ color: 'var(--text-muted)' }}>{t.medium}</span></span>
                                                <span style={{ fontFamily: 'monospace', fontWeight: 600 }}>{t.sessions} sess</span>
                                                <span style={{ fontFamily: 'monospace', color: 'var(--text-muted)' }}>{t.users} users</span>
                                                <span style={{ fontSize: 10, padding: '2px 6px', borderRadius: 4, background: t.engagementRate > 50 ? 'rgba(74,222,128,0.1)' : 'rgba(251,191,36,0.1)', color: t.engagementRate > 50 ? '#4ade80' : '#fbbf24' }}>{t.engagementRate}%</span>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </>)}

                            {/* ── Audience Sub-tab ── */}
                            {ga4SubTab === 'audience' && (<>
                                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 16 }}>
                                    {ga4Demographics && (<>
                                        <div className="card">
                                            <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 12 }}>🌍 Countries</h3>
                                            {ga4Demographics.countries.slice(0, 10).map((c, i) => {
                                                const max = ga4Demographics.countries[0]?.users || 1;
                                                return (
                                                    <div key={c.country} style={{ marginBottom: 6 }}>
                                                        <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 2 }}>
                                                            <span style={{ fontWeight: i < 3 ? 700 : 400 }}>{i + 1}. {c.country}</span>
                                                            <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>{c.users} users · {c.sessions} sess</span>
                                                        </div>
                                                        <div style={{ height: 4, background: 'var(--bg-hover)', borderRadius: 2 }}>
                                                            <div style={{ height: '100%', width: `${(c.users / max) * 100}%`, background: 'linear-gradient(90deg, #818cf8, #6366f1)', borderRadius: 2 }} />
                                                        </div>
                                                    </div>
                                                );
                                            })}
                                        </div>
                                        <div className="card">
                                            <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 12 }}>🏙️ Cities</h3>
                                            {ga4Demographics.cities.slice(0, 12).map((c, i) => (
                                                <div key={c.city} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '5px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                                                    <span style={{ fontWeight: i < 3 ? 700 : 400 }}>{i + 1}. {c.city}</span>
                                                    <span style={{ fontWeight: 700 }}>{c.users}</span>
                                                </div>
                                            ))}
                                            {ga4Demographics.languages.length > 0 && (<>
                                                <h4 style={{ fontSize: 13, fontWeight: 700, marginTop: 14, marginBottom: 8, color: 'var(--text-secondary)' }}>🗣️ Languages</h4>
                                                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                                                    {ga4Demographics.languages.slice(0, 8).map(l => (
                                                        <span key={l.language} style={{ fontSize: 11, padding: '4px 10px', borderRadius: 20, background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)' }}>{l.language}: <b>{l.users}</b></span>
                                                    ))}
                                                </div>
                                            </>)}
                                        </div>
                                    </>)}
                                </div>
                            </>)}

                            {/* ── Events Sub-tab ── */}
                            {ga4SubTab === 'events' && (<>
                                {ga4Events.length > 0 && (
                                    <div className="card" style={{ padding: 0, marginBottom: 16 }}>
                                        <h3 style={{ fontSize: 14, fontWeight: 700, padding: '16px 20px 10px' }}>⚡ All Events — {presetLabel()}</h3>
                                        <table className="data-table">
                                            <thead><tr><th></th><th>Event Name</th><th>Count</th><th>Users</th><th>Per User</th></tr></thead>
                                            <tbody>
                                                {ga4Events.map((e, i) => (
                                                    <tr key={i}>
                                                        <td style={{ fontSize: 16 }}>{eventIcon(e.event)}</td>
                                                        <td style={{ fontSize: 12, fontWeight: 600 }}>{e.event}</td>
                                                        <td style={{ fontWeight: 700, fontFamily: 'monospace' }}>{e.count.toLocaleString()}</td>
                                                        <td style={{ fontFamily: 'monospace' }}>{e.users}</td>
                                                        <td style={{ fontFamily: 'monospace', fontSize: 11, color: 'var(--text-muted)' }}>{e.perUser || '—'}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                            </>)}

                            {/* ── Tech Sub-tab ── */}
                            {ga4SubTab === 'tech' && (<>
                                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14, marginBottom: 16 }}>
                                    {ga4Devices && (<>
                                        <div className="card">
                                            <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 12 }}>📱 Device Categories</h3>
                                            <div style={{ display: 'flex', gap: 10, marginBottom: 14 }}>
                                                {ga4Devices.categories.map(d => {
                                                    const total = ga4Devices.categories.reduce((s, x) => s + x.users, 0) || 1;
                                                    return (
                                                        <div key={d.device} style={{ flex: 1, textAlign: 'center', padding: 14, background: 'var(--bg-surface)', borderRadius: 10 }}>
                                                            <div style={{ fontSize: 28 }}>{deviceIcon(d.device)}</div>
                                                            <div style={{ fontSize: 22, fontWeight: 900, marginTop: 4 }}>{Math.round((d.users / total) * 100)}%</div>
                                                            <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'capitalize' }}>{d.device}</div>
                                                            <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{d.users} users</div>
                                                        </div>
                                                    );
                                                })}
                                            </div>
                                            <h4 style={{ fontSize: 12, fontWeight: 700, marginBottom: 8, color: 'var(--text-secondary)' }}>💿 Operating Systems</h4>
                                            {ga4Devices.operatingSystems.slice(0, 5).map(o => (
                                                <div key={o.os} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '4px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                                                    <span>{o.os}</span><span style={{ fontWeight: 700 }}>{o.users}</span>
                                                </div>
                                            ))}
                                        </div>
                                        <div className="card">
                                            <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 12 }}>📏 Device Details</h3>
                                            {(ga4Devices.brands || []).length > 0 && (<>
                                                <h4 style={{ fontSize: 12, fontWeight: 700, marginBottom: 6, color: 'var(--text-secondary)' }}>🏷️ Brands</h4>
                                                {ga4Devices.brands.slice(0, 6).map(b => (
                                                    <div key={b.brand} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '4px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                                                        <span>{b.brand}</span><span style={{ fontWeight: 700 }}>{b.users}</span>
                                                    </div>
                                                ))}
                                            </>)}
                                            {(ga4Devices.models || []).length > 0 && (<>
                                                <h4 style={{ fontSize: 12, fontWeight: 700, marginTop: 12, marginBottom: 6, color: 'var(--text-secondary)' }}>📱 Models</h4>
                                                {ga4Devices.models.slice(0, 6).map(m => (
                                                    <div key={m.model} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '4px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                                                        <span>{m.model}</span><span style={{ fontWeight: 700 }}>{m.users}</span>
                                                    </div>
                                                ))}
                                            </>)}
                                            {(ga4Devices.resolutions || []).length > 0 && (<>
                                                <h4 style={{ fontSize: 12, fontWeight: 700, marginTop: 12, marginBottom: 6, color: 'var(--text-secondary)' }}>🖥️ Resolutions</h4>
                                                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                                                    {ga4Devices.resolutions.slice(0, 6).map(r => (
                                                        <span key={r.resolution} style={{ fontSize: 10, padding: '4px 10px', borderRadius: 20, background: 'var(--bg-surface)', border: '1px solid var(--border-subtle)' }}>{r.resolution}: <b>{r.users}</b></span>
                                                    ))}
                                                </div>
                                            </>)}
                                        </div>
                                    </>)}
                                </div>
                                {/* App Versions */}
                                {ga4AppVersions.length > 0 && (
                                    <div className="card" style={{ padding: 0, marginBottom: 16 }}>
                                        <h3 style={{ fontSize: 14, fontWeight: 700, padding: '16px 20px 10px' }}>📦 App Versions</h3>
                                        <table className="data-table">
                                            <thead><tr><th>Version</th><th>Users</th><th>Sessions</th></tr></thead>
                                            <tbody>
                                                {ga4AppVersions.map((v, i) => (
                                                    <tr key={i}>
                                                        <td style={{ fontWeight: 700 }}>{v.version || '(not set)'}</td>
                                                        <td style={{ fontFamily: 'monospace' }}>{v.users}</td>
                                                        <td style={{ fontFamily: 'monospace' }}>{v.sessions}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                            </>)}

                            <div style={{ textAlign: 'center', marginTop: 4 }}>
                                <p style={{ fontSize: 10, color: 'var(--text-muted)' }}>⚠️ Standard GA4 reports have 24-48h processing delay · Realtime refreshes every 30s</p>
                            </div>
                            </>)}
                        </div>
                    )}

                    {/* ═══════════ LIVE ACTIVITY TAB ═══════════ */}
                    {tab === 'activity' && (
                        <div>
                            <div className="card" style={{ marginBottom: 16 }}>
                                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 16 }}>
                                    <div style={{ width: 8, height: 8, borderRadius: '50%', background: '#4ade80', animation: 'pulse 2s infinite' }} />
                                    <h3 style={{ fontSize: 15, fontWeight: 700 }}>Recent User Activity (Last 7 days)</h3>
                                    <span className="badge" style={{ marginLeft: 'auto' }}>{activityFeed.length} activities</span>
                                </div>
                                <div style={{ maxHeight: 600, overflowY: 'auto' }}>
                                    {activityFeed.map((a, i) => (
                                        <div key={i} style={{ display: 'flex', alignItems: 'flex-start', gap: 12, padding: '12px 0', borderBottom: i < activityFeed.length - 1 ? '1px solid var(--border-subtle)' : 'none' }}>
                                            <div style={{ fontSize: 20 }}>{activityIcon(a.activity_type)}</div>
                                            <div style={{ flex: 1 }}>
                                                <div style={{ fontWeight: 600, fontSize: 13 }}>{a.full_name || a.email || 'Unknown User'}</div>
                                                <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>{a.activity_description}</div>
                                            </div>
                                            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
                                                <span className={`badge badge-${a.activity_type === 'routine' ? 'success' : a.activity_type === 'practice' ? 'info' : 'warning'}`} style={{ fontSize: 10 }}>{a.activity_type}</span>
                                                <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>{relativeTime(a.activity_time)}</span>
                                            </div>
                                        </div>
                                    ))}
                                    {activityFeed.length === 0 && <p style={{ color: 'var(--text-muted)', padding: 30, textAlign: 'center' }}>No recent activity in the last 7 days</p>}
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ═══════════ USER BREAKDOWN TAB ═══════════ */}
                    {tab === 'users' && (
                        <div>
                            <div className="card" style={{ padding: 0 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, padding: '18px 22px 12px' }}>👥 Per-User Activity (Last 30 days active users)</h3>
                                <table className="data-table">
                                    <thead><tr><th>User</th><th>Last Active</th><th>🏃 Routines (7d)</th><th>✅ Completed</th><th>🧘 Practices (7d)</th><th>📝 Journals (7d)</th><th>Engagement</th></tr></thead>
                                    <tbody>
                                        {userSummary.map((u, i) => {
                                            const totalActivity = (u.routines_7d || 0) + (u.practices_7d || 0) + (u.journals_7d || 0);
                                            const completionRate = u.routines_7d > 0 ? Math.round((u.routines_completed_7d / u.routines_7d) * 100) : 0;
                                            return (
                                                <tr key={u.user_id || i}>
                                                    <td><div style={{ fontWeight: 600, fontSize: 13 }}>{u.full_name || 'No Name'}</div><div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{u.email || '—'}</div></td>
                                                    <td style={{ fontSize: 12, color: 'var(--text-muted)' }}>{relativeTime(u.last_active)}</td>
                                                    <td style={{ fontFamily: 'monospace', fontWeight: 700 }}>{u.routines_7d || 0}</td>
                                                    <td>{u.routines_7d > 0 ? <span style={{ fontWeight: 700, color: completionRate >= 70 ? '#4ade80' : completionRate >= 40 ? '#fbbf24' : '#f87171' }}>{u.routines_completed_7d}/{u.routines_7d} ({completionRate}%)</span> : <span style={{ color: 'var(--text-muted)' }}>—</span>}</td>
                                                    <td style={{ fontFamily: 'monospace', fontWeight: 700 }}>{u.practices_7d || 0}</td>
                                                    <td style={{ fontFamily: 'monospace', fontWeight: 700 }}>{u.journals_7d || 0}</td>
                                                    <td>
                                                        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 4, padding: '4px 10px', borderRadius: 20, fontSize: 11, fontWeight: 700,
                                                            background: totalActivity >= 20 ? 'rgba(74,222,128,0.15)' : totalActivity >= 5 ? 'rgba(251,191,36,0.15)' : 'rgba(248,113,113,0.15)',
                                                            color: totalActivity >= 20 ? '#4ade80' : totalActivity >= 5 ? '#fbbf24' : '#f87171',
                                                        }}>{totalActivity >= 20 ? '🔥 High' : totalActivity >= 5 ? '⚡ Medium' : '❄️ Low'}</div>
                                                    </td>
                                                </tr>
                                            );
                                        })}
                                        {userSummary.length === 0 && <tr><td colSpan={7} style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)' }}>No active users in the last 30 days</td></tr>}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}

                    {/* ═══════════ CONTENT & MOOD TAB ═══════════ */}
                    {tab === 'content' && (
                        <div className="bento-grid">
                            <div className="bento-md card">
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>🏷 Session Categories</h3>
                                {metrics.categoryBreakdown.length > 0 ? metrics.categoryBreakdown.map((c) => {
                                    const total = metrics.categoryBreakdown.reduce((s, x) => s + x.count, 0);
                                    return (
                                        <div key={c.name} style={{ marginBottom: 10 }}>
                                            <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
                                                <span style={{ fontWeight: 600 }}>{c.name}</span>
                                                <span style={{ color: 'var(--text-muted)' }}>{c.count} ({Math.round((c.count / total) * 100)}%)</span>
                                            </div>
                                            <div style={{ height: 6, background: 'var(--bg-hover)', borderRadius: 3 }}>
                                                <div style={{ height: '100%', width: `${(c.count / total) * 100}%`, background: 'var(--accent-gradient)', borderRadius: 3, transition: 'width 0.5s' }} />
                                            </div>
                                        </div>
                                    );
                                }) : <p style={{ color: 'var(--text-muted)', fontSize: 13 }}>No session data</p>}
                            </div>
                            <div className="bento-lg card">
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>🗓 Practice by Day of Week</h3>
                                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 12, height: 140 }}>
                                    {metrics.engagementByDay.map((d, i) => (
                                        <div key={d.name} style={{ flex: 1, textAlign: 'center' }}>
                                            <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--accent)', marginBottom: 4 }}>{d.count || ''}</div>
                                            <div style={{ height: `${Math.max(4, (d.count / maxVal(metrics.engagementByDay)) * 100)}px`, background: i === new Date().getDay() ? 'var(--accent-gradient)' : 'var(--bg-hover)', borderRadius: 4, transition: 'height 0.5s', border: i === new Date().getDay() ? 'none' : '1px solid var(--border-subtle)' }} />
                                            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 6 }}>{d.name}</div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                            <div className="bento-lg card">
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>😊 Mood Trend</h3>
                                {metrics.moodTrend.length > 0 ? (
                                    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 120 }}>
                                        {metrics.moodTrend.map((d, i) => (
                                            <div key={i} style={{ flex: 1, textAlign: 'center' }}>
                                                <div style={{ fontSize: 10, fontWeight: 600, color: d.value >= 4 ? 'var(--success)' : d.value >= 3 ? 'var(--warning)' : 'var(--error)', marginBottom: 2 }}>{d.value}</div>
                                                <div style={{ height: `${Math.max(8, (d.value / 5) * 100)}px`, background: d.value >= 4 ? 'rgba(74,222,128,0.3)' : d.value >= 3 ? 'rgba(251,191,36,0.3)' : 'rgba(248,113,113,0.3)', borderRadius: 3, transition: 'height 0.5s' }} />
                                                <div style={{ fontSize: 9, color: 'var(--text-muted)', marginTop: 4 }}>{d.label}</div>
                                            </div>
                                        ))}
                                    </div>
                                ) : <p style={{ color: 'var(--text-muted)', fontSize: 13 }}>No mood data in this period</p>}
                            </div>
                            <div className="bento-full card" style={{ padding: 0 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, padding: '18px 22px 12px' }}>🏆 Top Sessions by Views</h3>
                                <table className="data-table">
                                    <thead><tr><th>#</th><th>Session</th><th>Category</th><th>Views</th></tr></thead>
                                    <tbody>
                                        {metrics.topSessions.map((s, i) => (
                                            <tr key={i}>
                                                <td style={{ fontWeight: 700, color: i < 3 ? 'var(--accent)' : 'var(--text-muted)' }}>{i + 1}</td>
                                                <td style={{ fontWeight: 600 }}>{s.title}</td>
                                                <td><span className="badge">{s.category}</span></td>
                                                <td style={{ fontWeight: 700 }}>{s.view_count || 0}</td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}
                </>
            )}
        </div>
    );
}

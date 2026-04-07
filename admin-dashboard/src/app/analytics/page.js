'use client';
import { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase';

export default function AnalyticsPage() {
    const supabase = createClient();
    const [loading, setLoading] = useState(true);
    const [period, setPeriod] = useState('30');
    const [tab, setTab] = useState('overview');

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

    const fetchGA4 = async (type, setter) => {
        try {
            const res = await fetch(`/api/analytics/ga?type=${type}&days=${period}`);
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
            ]);
        } catch (e) { setGa4Error(e.message); }
        setGa4Loading(false);
    };

    const fetchAll = async () => {
        setLoading(true);
        await Promise.all([
            fetchActiveStats(), fetchDauChart(), fetchActivityFeed(),
            fetchUserSummary(), fetchExistingMetrics(),
        ]);
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

    const maxVal = (arr) => Math.max(1, ...arr.map(d => d.value || d.count || d.active_users || d.activeUsers || d.views || 0));

    const activityIcon = (type) => {
        switch (type) { case 'routine': return '🏃'; case 'practice': return '🧘'; case 'journal': return '📝'; default: return '📌'; }
    };

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

    const fmtDuration = (s) => { if (s < 60) return `${s}s`; return `${Math.floor(s / 60)}m ${s % 60}s`; };
    const changeArrow = (v) => v > 0 ? `↑${v}%` : v < 0 ? `↓${Math.abs(v)}%` : '—';
    const changeColor = (v) => v > 0 ? '#4ade80' : v < 0 ? '#f87171' : 'var(--text-muted)';

    const deviceIcon = (d) => {
        const dl = (d || '').toLowerCase();
        if (dl.includes('mobile') || dl.includes('phone')) return '📱';
        if (dl.includes('desktop')) return '💻';
        if (dl.includes('tablet')) return '📟';
        return '🖥️';
    };

    const eventIcon = (e) => {
        const m = { 'session_start': '🚀', 'first_visit': '👋', 'first_open': '📲', 'screen_view': '👁️', 'user_engagement': '💡', 'task_completed': '✅', 'yoga_session_start': '🧘', 'yoga_session_complete': '🏆', 'daily_progress': '📊', 'subscription_event': '💎', 'ad_impression': '📢', 'ad_click': '👆', 'app_update': '🔄' };
        return m[e] || '⚡';
    };

    const tabs = [
        { id: 'overview', label: '📊 Overview' },
        { id: 'ga4', label: '🔥 Google Analytics' },
        { id: 'activity', label: '🔴 Live Activity' },
        { id: 'users', label: '👥 User Breakdown' },
        { id: 'content', label: '📈 Content & Mood' },
    ];

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
                        color: tab === t.id ? '#fff' : 'var(--text-secondary)',
                        transition: 'all 0.2s',
                    }}>{t.label}</button>
                ))}
            </div>

            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading analytics...</p> : (
                <>
                    {/* ═══════════ OVERVIEW TAB ═══════════ */}
                    {tab === 'overview' && (
                        <div>
                            {/* DAU / MAU Hero Cards */}
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
                                    <div style={{ fontSize: 11, color: dauRetentionRate() > 10 ? '#4ade80' : '#f97316', marginTop: 4, fontWeight: 600 }}>
                                        {dauRetentionRate()}% DAU Rate
                                    </div>
                                </div>
                            </div>

                            {/* DAU Chart */}
                            <div className="card" style={{ marginBottom: 24 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>📈 Daily Active Users (Last {period} days)</h3>
                                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 180, paddingBottom: 30 }}>
                                    {dauChart.map((d, i) => {
                                        const max = maxVal(dauChart);
                                        const isToday = d.day === new Date().toISOString().split('T')[0];
                                        return (
                                            <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative' }}>
                                                {d.active_users > 0 && <div style={{ fontSize: 9, fontWeight: 700, color: 'var(--accent)', marginBottom: 2 }}>{d.active_users}</div>}
                                                <div style={{
                                                    width: '100%', maxWidth: 24, minHeight: 3,
                                                    height: `${Math.max(3, (d.active_users / max) * 140)}px`,
                                                    background: isToday ? 'var(--accent-gradient)' : d.active_users > 0 ? 'rgba(99,102,241,0.4)' : 'var(--bg-hover)',
                                                    borderRadius: '3px 3px 0 0',
                                                    transition: 'height 0.5s',
                                                    border: isToday ? '2px solid rgba(99,102,241,0.8)' : 'none',
                                                }} />
                                                {(i % Math.ceil(dauChart.length / 10) === 0 || isToday) && (
                                                    <div style={{
                                                        fontSize: 8, color: isToday ? 'var(--accent)' : 'var(--text-muted)', marginTop: 4,
                                                        position: 'absolute', bottom: -22, whiteSpace: 'nowrap', fontWeight: isToday ? 700 : 400,
                                                        transform: 'rotate(-45deg)', transformOrigin: 'top center',
                                                    }}>{new Date(d.day).toLocaleDateString('en', { month: 'short', day: 'numeric' })}</div>
                                                )}
                                            </div>
                                        );
                                    })}
                                </div>
                            </div>

                            {/* User Sign-ups Chart */}
                            <div className="card" style={{ marginBottom: 24 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>👤 New Signups (Last {Math.min(parseInt(period), 14)} days)</h3>
                                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 140 }}>
                                    {metrics.userGrowth.map((d, i) => (
                                        <div key={i} style={{ flex: 1, textAlign: 'center' }}>
                                            {d.value > 0 && <div style={{ fontSize: 10, fontWeight: 700, color: 'var(--accent)', marginBottom: 2 }}>{d.value}</div>}
                                            <div style={{
                                                height: `${Math.max(4, (d.value / maxVal(metrics.userGrowth)) * 120)}px`,
                                                background: d.value > 0 ? 'var(--accent-gradient)' : 'var(--bg-hover)', borderRadius: '3px 3px 0 0', transition: 'height 0.5s',
                                            }} />
                                            <div style={{ fontSize: 9, color: 'var(--text-muted)', marginTop: 4, transform: 'rotate(-45deg)', transformOrigin: 'center', whiteSpace: 'nowrap' }}>{d.label}</div>
                                        </div>
                                    ))}
                                </div>
                            </div>
                        </div>
                    )}

                    {/* ═══════════ GOOGLE ANALYTICS TAB ═══════════ */}
                    {tab === 'ga4' && (
                        <div>
                            {ga4Loading && <p style={{ color: 'var(--text-muted)', textAlign: 'center', padding: 30 }}>Loading Google Analytics data...</p>}
                            {ga4Error && <div className="card" style={{ background: 'rgba(248,113,113,0.1)', border: '1px solid rgba(248,113,113,0.3)', color: '#f87171', marginBottom: 16 }}>⚠️ {ga4Error}</div>}

                            {!ga4Loading && ga4Overview && (<>
                            {/* Realtime Banner */}
                            {ga4Realtime && (
                                <div className="card" style={{ background: 'linear-gradient(135deg, rgba(239,68,68,0.1), rgba(220,38,38,0.1))', border: '1px solid rgba(239,68,68,0.3)', marginBottom: 20, display: 'flex', alignItems: 'center', gap: 16, flexWrap: 'wrap' }}>
                                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                                        <div style={{ width: 10, height: 10, borderRadius: '50%', background: '#ef4444', animation: 'pulse 1.5s infinite' }} />
                                        <span style={{ fontSize: 13, fontWeight: 700, color: '#f87171' }}>LIVE NOW</span>
                                        <span style={{ fontSize: 36, fontWeight: 900, color: '#fff' }}>{ga4Realtime.activeUsers}</span>
                                        <span style={{ fontSize: 13, color: 'var(--text-secondary)' }}>active users</span>
                                    </div>
                                    <div style={{ marginLeft: 'auto', display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                                        {(ga4Realtime.byDevice || []).map(d => (
                                            <span key={d.device} style={{ fontSize: 12, color: 'var(--text-secondary)', background: 'var(--bg-surface)', padding: '4px 10px', borderRadius: 20 }}>
                                                {deviceIcon(d.device)} {d.device}: <b style={{ color: '#fff' }}>{d.users}</b>
                                            </span>
                                        ))}
                                    </div>
                                    {(ga4Realtime.byCountry || []).length > 0 && (
                                        <div style={{ width: '100%', display: 'flex', gap: 8, flexWrap: 'wrap', marginTop: 4 }}>
                                            {ga4Realtime.byCountry.slice(0, 6).map(c => (
                                                <span key={c.country} style={{ fontSize: 11, color: 'var(--text-muted)', background: 'rgba(255,255,255,0.05)', padding: '3px 8px', borderRadius: 12 }}>
                                                    {c.country}: {c.users}
                                                </span>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}

                            {/* GA4 Hero Cards */}
                            <div className="stats-grid" style={{ marginBottom: 20 }}>
                                {[
                                    { label: 'Active Users', value: ga4Overview.activeUsers, icon: '👥', change: ga4Overview.changes?.activeUsers, gradient: 'rgba(99,102,241,0.1)', border: 'rgba(99,102,241,0.3)', color: '#818cf8' },
                                    { label: 'New Users', value: ga4Overview.newUsers, icon: '🆕', change: ga4Overview.changes?.newUsers, gradient: 'rgba(16,185,129,0.1)', border: 'rgba(16,185,129,0.3)', color: '#34d399' },
                                    { label: 'Sessions', value: ga4Overview.sessions, icon: '📊', change: ga4Overview.changes?.sessions, gradient: 'rgba(59,130,246,0.1)', border: 'rgba(59,130,246,0.3)', color: '#60a5fa' },
                                    { label: 'Screen Views', value: ga4Overview.screenPageViews, icon: '👁️', change: ga4Overview.changes?.screenPageViews, gradient: 'rgba(168,85,247,0.1)', border: 'rgba(168,85,247,0.3)', color: '#a855f7' },
                                ].map(c => (
                                    <div key={c.label} className="card" style={{ textAlign: 'center', background: `linear-gradient(135deg, ${c.gradient}, transparent)`, border: `1px solid ${c.border}` }}>
                                        <div style={{ fontSize: 32, fontWeight: 900, color: c.color }}>{c.value?.toLocaleString()}</div>
                                        <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text-secondary)', marginTop: 2 }}>{c.icon} {c.label}</div>
                                        {c.change !== undefined && <div style={{ fontSize: 11, fontWeight: 700, color: changeColor(c.change), marginTop: 4 }}>{changeArrow(c.change)} vs prev</div>}
                                    </div>
                                ))}
                            </div>

                            {/* Secondary metrics */}
                            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12, marginBottom: 20 }}>
                                {[
                                    { label: 'Engagement Rate', value: `${ga4Overview.engagementRate}%`, color: ga4Overview.engagementRate > 50 ? '#4ade80' : '#fbbf24' },
                                    { label: 'Avg Session', value: fmtDuration(ga4Overview.avgSessionDuration), color: '#60a5fa' },
                                    { label: 'Sessions/User', value: ga4Overview.sessionsPerUser, color: '#a855f7' },
                                    { label: 'Total Users', value: ga4Overview.totalUsers?.toLocaleString(), color: '#818cf8' },
                                ].map(m => (
                                    <div key={m.label} className="card" style={{ textAlign: 'center', padding: '14px 10px' }}>
                                        <div style={{ fontSize: 22, fontWeight: 900, color: m.color }}>{m.value}</div>
                                        <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 2 }}>{m.label}</div>
                                    </div>
                                ))}
                            </div>

                            {/* Daily Users Chart */}
                            {ga4DailyUsers.length > 0 && (
                                <div className="card" style={{ marginBottom: 20 }}>
                                    <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>📈 Daily Active Users (GA4 — Last {period} days)</h3>
                                    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 2, height: 180, paddingBottom: 30 }}>
                                        {ga4DailyUsers.map((d, i) => {
                                            const max = maxVal(ga4DailyUsers);
                                            const isToday = d.date === new Date().toISOString().split('T')[0];
                                            return (
                                                <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', position: 'relative' }}>
                                                    {d.activeUsers > 0 && <div style={{ fontSize: 9, fontWeight: 700, color: 'var(--accent)', marginBottom: 2 }}>{d.activeUsers}</div>}
                                                    <div style={{ width: '100%', maxWidth: 20, minHeight: 3, height: `${Math.max(3, (d.activeUsers / max) * 140)}px`, background: isToday ? 'var(--accent-gradient)' : 'rgba(99,102,241,0.4)', borderRadius: '3px 3px 0 0', transition: 'height 0.5s', border: isToday ? '2px solid rgba(99,102,241,0.8)' : 'none' }} />
                                                    {(i % Math.ceil(ga4DailyUsers.length / 8) === 0 || isToday) && (
                                                        <div style={{ fontSize: 8, color: isToday ? 'var(--accent)' : 'var(--text-muted)', marginTop: 4, position: 'absolute', bottom: -22, whiteSpace: 'nowrap', fontWeight: isToday ? 700 : 400, transform: 'rotate(-45deg)' }}>
                                                            {new Date(d.date).toLocaleDateString('en', { month: 'short', day: 'numeric' })}
                                                        </div>
                                                    )}
                                                </div>
                                            );
                                        })}
                                    </div>
                                </div>
                            )}

                            {/* Two-column: Demographics + Devices */}
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 20 }}>
                                {/* Demographics */}
                                {ga4Demographics && (
                                    <div className="card">
                                        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 14 }}>🌍 Top Countries</h3>
                                        {ga4Demographics.countries.slice(0, 8).map((c, i) => {
                                            const max = ga4Demographics.countries[0]?.users || 1;
                                            return (
                                                <div key={c.country} style={{ marginBottom: 8 }}>
                                                    <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 3 }}>
                                                        <span style={{ fontWeight: i < 3 ? 700 : 400 }}>{i + 1}. {c.country}</span>
                                                        <span style={{ color: 'var(--text-muted)' }}>{c.users} users · {c.sessions} sessions</span>
                                                    </div>
                                                    <div style={{ height: 5, background: 'var(--bg-hover)', borderRadius: 3 }}>
                                                        <div style={{ height: '100%', width: `${(c.users / max) * 100}%`, background: 'var(--accent-gradient)', borderRadius: 3 }} />
                                                    </div>
                                                </div>
                                            );
                                        })}
                                        {ga4Demographics.cities.length > 0 && (
                                            <>
                                                <h4 style={{ fontSize: 13, fontWeight: 700, marginTop: 16, marginBottom: 10, color: 'var(--text-secondary)' }}>🏙️ Top Cities</h4>
                                                {ga4Demographics.cities.slice(0, 6).map(c => (
                                                    <div key={c.city} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '4px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                                                        <span>{c.city}</span><span style={{ fontWeight: 700 }}>{c.users}</span>
                                                    </div>
                                                ))}
                                            </>
                                        )}
                                    </div>
                                )}

                                {/* Devices */}
                                {ga4Devices && (
                                    <div className="card">
                                        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 14 }}>📱 Devices</h3>
                                        <div style={{ display: 'flex', gap: 12, marginBottom: 16 }}>
                                            {ga4Devices.categories.map(d => {
                                                const total = ga4Devices.categories.reduce((s, x) => s + x.users, 0) || 1;
                                                const pct = Math.round((d.users / total) * 100);
                                                return (
                                                    <div key={d.device} style={{ flex: 1, textAlign: 'center', padding: 12, background: 'var(--bg-surface)', borderRadius: 10 }}>
                                                        <div style={{ fontSize: 28 }}>{deviceIcon(d.device)}</div>
                                                        <div style={{ fontSize: 20, fontWeight: 900, marginTop: 4 }}>{pct}%</div>
                                                        <div style={{ fontSize: 11, color: 'var(--text-muted)', textTransform: 'capitalize' }}>{d.device}</div>
                                                        <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{d.users} users</div>
                                                    </div>
                                                );
                                            })}
                                        </div>
                                        <h4 style={{ fontSize: 13, fontWeight: 700, marginBottom: 10, color: 'var(--text-secondary)' }}>💿 Operating Systems</h4>
                                        {ga4Devices.operatingSystems.slice(0, 5).map(o => (
                                            <div key={o.os} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, padding: '4px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                                                <span>{o.os}</span><span style={{ fontWeight: 700 }}>{o.users}</span>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            {/* Two-column: Top Screens + Events */}
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 20 }}>
                                {/* Top Screens */}
                                {ga4TopScreens.length > 0 && (
                                    <div className="card" style={{ padding: 0 }}>
                                        <h3 style={{ fontSize: 15, fontWeight: 700, padding: '18px 22px 12px' }}>📄 Top Screens</h3>
                                        <table className="data-table">
                                            <thead><tr><th>#</th><th>Screen</th><th>Views</th><th>Users</th></tr></thead>
                                            <tbody>
                                                {ga4TopScreens.slice(0, 12).map((s, i) => (
                                                    <tr key={i}>
                                                        <td style={{ fontWeight: 700, color: i < 3 ? 'var(--accent)' : 'var(--text-muted)' }}>{i + 1}</td>
                                                        <td style={{ fontSize: 12, fontWeight: 600, maxWidth: 200, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{s.screen}</td>
                                                        <td style={{ fontWeight: 700, fontFamily: 'monospace' }}>{s.views}</td>
                                                        <td style={{ fontFamily: 'monospace' }}>{s.users}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}

                                {/* Events */}
                                {ga4Events.length > 0 && (
                                    <div className="card" style={{ padding: 0 }}>
                                        <h3 style={{ fontSize: 15, fontWeight: 700, padding: '18px 22px 12px' }}>⚡ Events</h3>
                                        <table className="data-table">
                                            <thead><tr><th></th><th>Event</th><th>Count</th><th>Users</th></tr></thead>
                                            <tbody>
                                                {ga4Events.slice(0, 15).map((e, i) => (
                                                    <tr key={i}>
                                                        <td style={{ fontSize: 16 }}>{eventIcon(e.event)}</td>
                                                        <td style={{ fontSize: 12, fontWeight: 600 }}>{e.event}</td>
                                                        <td style={{ fontWeight: 700, fontFamily: 'monospace' }}>{e.count.toLocaleString()}</td>
                                                        <td style={{ fontFamily: 'monospace' }}>{e.users}</td>
                                                    </tr>
                                                ))}
                                            </tbody>
                                        </table>
                                    </div>
                                )}
                            </div>

                            {/* Retention + Traffic */}
                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16, marginBottom: 20 }}>
                                {ga4Retention && (
                                    <div className="card">
                                        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 14 }}>🔄 New vs Returning</h3>
                                        <div style={{ display: 'flex', gap: 16 }}>
                                            {['new', 'returning'].map(type => {
                                                const d = ga4Retention[type];
                                                if (!d) return null;
                                                return (
                                                    <div key={type} style={{ flex: 1, textAlign: 'center', padding: 16, background: 'var(--bg-surface)', borderRadius: 10 }}>
                                                        <div style={{ fontSize: 14, fontWeight: 700, color: type === 'new' ? '#34d399' : '#60a5fa', textTransform: 'capitalize', marginBottom: 8 }}>
                                                            {type === 'new' ? '🆕' : '🔁'} {type}
                                                        </div>
                                                        <div style={{ fontSize: 28, fontWeight: 900 }}>{d.users}</div>
                                                        <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{d.sessions} sessions</div>
                                                        <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{d.engagementRate}% engaged</div>
                                                    </div>
                                                );
                                            })}
                                        </div>
                                    </div>
                                )}
                                {ga4Traffic.length > 0 && (
                                    <div className="card">
                                        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 14 }}>🔗 Traffic Sources</h3>
                                        {ga4Traffic.slice(0, 8).map((t, i) => (
                                            <div key={i} style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: 12, padding: '6px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                                                <span><b>{t.source}</b> / {t.medium}</span>
                                                <span style={{ color: 'var(--text-muted)' }}>{t.sessions} sess · {t.users} users</span>
                                            </div>
                                        ))}
                                    </div>
                                )}
                            </div>

                            {/* Refresh button */}
                            <div style={{ textAlign: 'center', marginTop: 8 }}>
                                <button onClick={fetchAllGA4} className="btn" style={{ fontSize: 12 }}>🔄 Refresh GA4 Data</button>
                                <p style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 6 }}>Data may have 24-48h processing delay (except Realtime)</p>
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
                                        <div key={i} style={{
                                            display: 'flex', alignItems: 'flex-start', gap: 12, padding: '12px 0',
                                            borderBottom: i < activityFeed.length - 1 ? '1px solid var(--border-subtle)' : 'none',
                                        }}>
                                            <div style={{ fontSize: 20 }}>{activityIcon(a.activity_type)}</div>
                                            <div style={{ flex: 1 }}>
                                                <div style={{ fontWeight: 600, fontSize: 13 }}>{a.full_name || a.email || 'Unknown User'}</div>
                                                <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginTop: 2 }}>{a.activity_description}</div>
                                            </div>
                                            <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end', gap: 4 }}>
                                                <span className={`badge badge-${a.activity_type === 'routine' ? 'success' : a.activity_type === 'practice' ? 'info' : 'warning'}`} style={{ fontSize: 10 }}>
                                                    {a.activity_type}
                                                </span>
                                                <span style={{ fontSize: 10, color: 'var(--text-muted)' }}>{relativeTime(a.activity_time)}</span>
                                            </div>
                                        </div>
                                    ))}
                                    {activityFeed.length === 0 && (
                                        <p style={{ color: 'var(--text-muted)', padding: 30, textAlign: 'center' }}>No recent activity in the last 7 days</p>
                                    )}
                                </div>
                            </div>

                            <style jsx>{`
                                @keyframes pulse {
                                    0%, 100% { opacity: 1; }
                                    50% { opacity: 0.3; }
                                }
                            `}</style>
                        </div>
                    )}

                    {/* ═══════════ USER BREAKDOWN TAB ═══════════ */}
                    {tab === 'users' && (
                        <div>
                            <div className="card" style={{ padding: 0 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, padding: '18px 22px 12px' }}>👥 Per-User Activity (Last 30 days active users)</h3>
                                <table className="data-table">
                                    <thead>
                                        <tr>
                                            <th>User</th>
                                            <th>Last Active</th>
                                            <th>🏃 Routines (7d)</th>
                                            <th>✅ Completed</th>
                                            <th>🧘 Practices (7d)</th>
                                            <th>📝 Journals (7d)</th>
                                            <th>Engagement</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {userSummary.map((u, i) => {
                                            const totalActivity = (u.routines_7d || 0) + (u.practices_7d || 0) + (u.journals_7d || 0);
                                            const completionRate = u.routines_7d > 0 ? Math.round((u.routines_completed_7d / u.routines_7d) * 100) : 0;
                                            return (
                                                <tr key={u.user_id || i}>
                                                    <td>
                                                        <div style={{ fontWeight: 600, fontSize: 13 }}>{u.full_name || 'No Name'}</div>
                                                        <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{u.email || '—'}</div>
                                                    </td>
                                                    <td style={{ fontSize: 12, color: 'var(--text-muted)' }}>{relativeTime(u.last_active)}</td>
                                                    <td style={{ fontFamily: 'monospace', fontWeight: 700 }}>{u.routines_7d || 0}</td>
                                                    <td>
                                                        {u.routines_7d > 0 ? (
                                                            <span style={{ fontWeight: 700, color: completionRate >= 70 ? '#4ade80' : completionRate >= 40 ? '#fbbf24' : '#f87171' }}>
                                                                {u.routines_completed_7d}/{u.routines_7d} ({completionRate}%)
                                                            </span>
                                                        ) : <span style={{ color: 'var(--text-muted)' }}>—</span>}
                                                    </td>
                                                    <td style={{ fontFamily: 'monospace', fontWeight: 700 }}>{u.practices_7d || 0}</td>
                                                    <td style={{ fontFamily: 'monospace', fontWeight: 700 }}>{u.journals_7d || 0}</td>
                                                    <td>
                                                        <div style={{
                                                            display: 'inline-flex', alignItems: 'center', gap: 4, padding: '4px 10px',
                                                            borderRadius: 20, fontSize: 11, fontWeight: 700,
                                                            background: totalActivity >= 20 ? 'rgba(74,222,128,0.15)' : totalActivity >= 5 ? 'rgba(251,191,36,0.15)' : 'rgba(248,113,113,0.15)',
                                                            color: totalActivity >= 20 ? '#4ade80' : totalActivity >= 5 ? '#fbbf24' : '#f87171',
                                                        }}>
                                                            {totalActivity >= 20 ? '🔥 High' : totalActivity >= 5 ? '⚡ Medium' : '❄️ Low'}
                                                        </div>
                                                    </td>
                                                </tr>
                                            );
                                        })}
                                        {userSummary.length === 0 && (
                                            <tr><td colSpan={7} style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)' }}>No active users in the last 30 days</td></tr>
                                        )}
                                    </tbody>
                                </table>
                            </div>
                        </div>
                    )}

                    {/* ═══════════ CONTENT & MOOD TAB ═══════════ */}
                    {tab === 'content' && (
                        <div className="bento-grid">
                            {/* Category Breakdown */}
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

                            {/* Engagement by Day */}
                            <div className="bento-lg card">
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>🗓 Practice by Day of Week</h3>
                                <div style={{ display: 'flex', alignItems: 'flex-end', gap: 12, height: 140 }}>
                                    {metrics.engagementByDay.map((d, i) => (
                                        <div key={d.name} style={{ flex: 1, textAlign: 'center' }}>
                                            <div style={{ fontSize: 11, fontWeight: 700, color: 'var(--accent)', marginBottom: 4 }}>{d.count || ''}</div>
                                            <div style={{
                                                height: `${Math.max(4, (d.count / maxVal(metrics.engagementByDay)) * 100)}px`,
                                                background: i === new Date().getDay() ? 'var(--accent-gradient)' : 'var(--bg-hover)', borderRadius: 4,
                                                transition: 'height 0.5s', border: i === new Date().getDay() ? 'none' : '1px solid var(--border-subtle)',
                                            }} />
                                            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 6 }}>{d.name}</div>
                                        </div>
                                    ))}
                                </div>
                            </div>

                            {/* Mood Trend */}
                            <div className="bento-lg card">
                                <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>😊 Mood Trend</h3>
                                {metrics.moodTrend.length > 0 ? (
                                    <div style={{ display: 'flex', alignItems: 'flex-end', gap: 6, height: 120 }}>
                                        {metrics.moodTrend.map((d, i) => (
                                            <div key={i} style={{ flex: 1, textAlign: 'center' }}>
                                                <div style={{ fontSize: 10, fontWeight: 600, color: d.value >= 4 ? 'var(--success)' : d.value >= 3 ? 'var(--warning)' : 'var(--error)', marginBottom: 2 }}>{d.value}</div>
                                                <div style={{
                                                    height: `${Math.max(8, (d.value / 5) * 100)}px`,
                                                    background: d.value >= 4 ? 'rgba(74,222,128,0.3)' : d.value >= 3 ? 'rgba(251,191,36,0.3)' : 'rgba(248,113,113,0.3)',
                                                    borderRadius: 3, transition: 'height 0.5s',
                                                }} />
                                                <div style={{ fontSize: 9, color: 'var(--text-muted)', marginTop: 4 }}>{d.label}</div>
                                            </div>
                                        ))}
                                    </div>
                                ) : <p style={{ color: 'var(--text-muted)', fontSize: 13 }}>No mood data in this period</p>}
                            </div>

                            {/* Top Sessions */}
                            <div className="bento-full card" style={{ padding: 0 }}>
                                <h3 style={{ fontSize: 15, fontWeight: 700, padding: '18px 22px 12px' }}>🏆 Top Sessions by Views</h3>
                                <table className="data-table">
                                    <thead><tr><th>#</th><th>Session</th><th>Category</th><th>Views</th></tr></thead>
                                    <tbody>
                                        {metrics.topSessions.map((s, i) => (
                                            <tr key={i}><td style={{ fontWeight: 700, color: i < 3 ? 'var(--accent)' : 'var(--text-muted)' }}>{i + 1}</td>
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

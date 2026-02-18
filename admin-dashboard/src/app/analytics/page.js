'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function AnalyticsPage() {
    const supabase = createClient();
    const [loading, setLoading] = useState(true);
    const [period, setPeriod] = useState('30');
    const [tab, setTab] = useState('overview');

    // Data states
    const [activeStats, setActiveStats] = useState({ dau: 0, wau: 0, mau: 0, total_users: 0 });
    const [dauChart, setDauChart] = useState([]);
    const [activityFeed, setActivityFeed] = useState([]);
    const [userSummary, setUserSummary] = useState([]);
    const [metrics, setMetrics] = useState({ userGrowth: [], categoryBreakdown: [], moodTrend: [], engagementByDay: [], topSessions: [] });

    useEffect(() => { fetchAll(); }, [period]);

    const fetchAll = async () => {
        setLoading(true);
        await Promise.all([
            fetchActiveStats(),
            fetchDauChart(),
            fetchActivityFeed(),
            fetchUserSummary(),
            fetchExistingMetrics(),
        ]);
        setLoading(false);
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

        // User growth per day
        const userGrowth = [];
        for (let i = Math.min(days, 14) - 1; i >= 0; i--) {
            const d = new Date(); d.setDate(d.getDate() - i);
            const start = new Date(d); start.setHours(0, 0, 0, 0);
            const end = new Date(d); end.setHours(23, 59, 59, 999);
            const { count } = await supabase.from('user_profiles').select('id', { count: 'exact', head: true })
                .gte('created_at', start.toISOString()).lte('created_at', end.toISOString());
            userGrowth.push({ label: d.toLocaleDateString('en', { month: 'short', day: 'numeric' }), value: count || 0 });
        }

        // Category breakdown
        const { data: sessData } = await supabase.from('sessions').select('category');
        const catMap = {};
        (sessData || []).forEach(s => { catMap[s.category] = (catMap[s.category] || 0) + 1; });
        const categoryBreakdown = Object.entries(catMap).sort(([, a], [, b]) => b - a).map(([name, count]) => ({ name, count }));

        // Mood trend from journals (fixed column name)
        const { data: moodData } = await supabase.from('journal_entries').select('mood_rating, created_at')
            .gte('created_at', since.toISOString()).order('created_at').limit(200);
        const moodByDay = {};
        (moodData || []).forEach(m => {
            const day = new Date(m.created_at).toLocaleDateString('en', { month: 'short', day: 'numeric' });
            if (!moodByDay[day]) moodByDay[day] = { sum: 0, count: 0 };
            moodByDay[day].sum += (m.mood_rating || 0);
            moodByDay[day].count += 1;
        });
        const moodTrend = Object.entries(moodByDay).map(([label, { sum, count }]) => ({ label, value: Math.round((sum / count) * 10) / 10 }));

        // Top sessions by view count
        const { data: topData } = await supabase.from('sessions').select('title, category, view_count').order('view_count', { ascending: false }).limit(10);
        const topSessions = topData || [];

        // Practice engagement by day of week
        const { data: practiceData } = await supabase.from('practice_sessions').select('created_at')
            .gte('created_at', since.toISOString()).limit(500);
        const dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
        const dayCounts = new Array(7).fill(0);
        (practiceData || []).forEach(p => { dayCounts[new Date(p.created_at).getDay()] += 1; });
        const engagementByDay = dayNames.map((name, i) => ({ name, count: dayCounts[i] }));

        setMetrics({ userGrowth, categoryBreakdown, moodTrend, engagementByDay, topSessions });
    };

    const maxVal = (arr) => Math.max(1, ...arr.map(d => d.value || d.count || d.active_users || 0));

    const activityIcon = (type) => {
        switch (type) {
            case 'routine': return '🏃';
            case 'practice': return '🧘';
            case 'journal': return '📝';
            default: return '📌';
        }
    };

    const relativeTime = (ts) => {
        if (!ts) return '—';
        const diff = Date.now() - new Date(ts).getTime();
        const mins = Math.floor(diff / 60000);
        if (mins < 1) return 'Just now';
        if (mins < 60) return `${mins}m ago`;
        const hrs = Math.floor(mins / 60);
        if (hrs < 24) return `${hrs}h ago`;
        const days = Math.floor(hrs / 24);
        return `${days}d ago`;
    };

    const dauRetentionRate = () => {
        if (!activeStats.total_users || activeStats.total_users === 0) return 0;
        return Math.round((activeStats.dau / activeStats.total_users) * 100);
    };

    const tabs = [
        { id: 'overview', label: '📊 Overview' },
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

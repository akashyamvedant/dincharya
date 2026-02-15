'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function AnalyticsPage() {
    const supabase = createClient();
    const [loading, setLoading] = useState(true);
    const [metrics, setMetrics] = useState({ userGrowth: [], categoryBreakdown: [], moodTrend: [], engagementByDay: [], topSessions: [] });
    const [period, setPeriod] = useState('7');

    useEffect(() => { fetchAnalytics(); }, [period]);

    const fetchAnalytics = async () => {
        setLoading(true);
        const days = parseInt(period);
        const since = new Date(); since.setDate(since.getDate() - days);

        // User growth per day
        const userGrowth = [];
        for (let i = days - 1; i >= 0; i--) {
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

        // Mood trend from journals
        const { data: moodData } = await supabase.from('journal_entries').select('mood_score, created_at')
            .gte('created_at', since.toISOString()).order('created_at').limit(200);
        const moodByDay = {};
        (moodData || []).forEach(m => {
            const day = new Date(m.created_at).toLocaleDateString('en', { month: 'short', day: 'numeric' });
            if (!moodByDay[day]) moodByDay[day] = { sum: 0, count: 0 };
            moodByDay[day].sum += (m.mood_score || 0);
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
        setLoading(false);
    };

    const maxVal = (arr) => Math.max(1, ...arr.map(d => d.value || d.count || 0));

    return (
        <div>
            <div className="page-header">
                <div><h1>Analytics</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>Insights & engagement metrics</p></div>
                <select className="search-input" value={period} onChange={e => setPeriod(e.target.value)} style={{ width: 150 }}>
                    <option value="7">Last 7 days</option>
                    <option value="14">Last 14 days</option>
                    <option value="30">Last 30 days</option>
                </select>
            </div>

            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading analytics...</p> : (
                <div className="bento-grid">
                    {/* User Growth */}
                    <div className="bento-xl card">
                        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>📈 User Signups</h3>
                        <div style={{ display: 'flex', alignItems: 'flex-end', gap: 4, height: 160 }}>
                            {metrics.userGrowth.map((d, i) => (
                                <div key={i} style={{ flex: 1, textAlign: 'center' }}>
                                    <div style={{
                                        height: `${Math.max(4, (d.value / maxVal(metrics.userGrowth)) * 140)}px`,
                                        background: 'var(--accent-gradient)', borderRadius: '3px 3px 0 0', transition: 'height 0.5s',
                                    }} />
                                    <div style={{ fontSize: 9, color: 'var(--text-muted)', marginTop: 4, transform: 'rotate(-45deg)', transformOrigin: 'center', whiteSpace: 'nowrap' }}>{d.label}</div>
                                </div>
                            ))}
                        </div>
                    </div>

                    {/* Category Breakdown */}
                    <div className="bento-md card">
                        <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>🏷 Session Categories</h3>
                        {metrics.categoryBreakdown.map((c, i) => {
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
                        })}
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
        </div>
    );
}

'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function RoutinesPage() {
    const supabase = createClient();
    const [tracking, setTracking] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [filter, setFilter] = useState('all');
    const [showDetail, setShowDetail] = useState(null);
    const [stats, setStats] = useState({ total: 0, completed: 0, rate: 0, todayCount: 0 });

    useEffect(() => { fetchTracking(); }, [search, filter]);

    const fetchTracking = async () => {
        setLoading(true);
        try {
            let q = supabase.from('routine_tracking').select('*').order('tracking_date', { ascending: false }).limit(200);
            if (search) q = q.ilike('activity_name', `%${search}%`);
            if (filter === 'completed') q = q.eq('completed', true);
            if (filter === 'skipped') q = q.eq('completed', false);
            const { data, error } = await q;
            if (error) { console.error('Tracking fetch error:', error); setTracking([]); setLoading(false); return; }

            const items = data || [];

            // Enrich with user profiles
            const userIds = [...new Set(items.map(t => t.user_id).filter(Boolean))];
            let profileMap = {};
            if (userIds.length > 0) {
                const { data: profiles } = await supabase.from('user_profiles')
                    .select('id, full_name, email')
                    .in('id', userIds);
                (profiles || []).forEach(p => { profileMap[p.id] = p; });
            }
            items.forEach(t => { t._profile = profileMap[t.user_id] || null; });

            setTracking(items);

            // Stats
            const total = items.length;
            const completed = items.filter(t => t.completed).length;
            const today = new Date().toISOString().split('T')[0];
            const todayCount = items.filter(t => t.tracking_date === today).length;
            setStats({
                total,
                completed,
                rate: total > 0 ? Math.round((completed / total) * 100) : 0,
                todayCount,
            });
        } catch (err) {
            console.error('Error fetching routines:', err);
            setTracking([]);
        }
        setLoading(false);
    };

    const groupByDate = () => {
        const groups = {};
        tracking.forEach(t => {
            const date = t.tracking_date || 'Unknown';
            if (!groups[date]) groups[date] = [];
            groups[date].push(t);
        });
        return groups;
    };

    const dateGroups = groupByDate();

    return (
        <div>
            <div className="page-header">
                <div><h1>Routines</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>{tracking.length} activity logs</p></div>
            </div>

            <div className="stats-grid" style={{ marginBottom: 24 }}>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800 }}>{stats.total}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Total Logs</div>
                </div>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800, color: '#4ade80' }}>{stats.completed}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Completed</div>
                </div>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800, color: 'var(--accent)' }}>{stats.rate}%</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Completion Rate</div>
                </div>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800, color: '#60a5fa' }}>{stats.todayCount}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Today</div>
                </div>
            </div>

            <div style={{ display: 'flex', gap: 12, marginBottom: 24 }}>
                <input className="search-input" placeholder="Search activities..." value={search} onChange={e => setSearch(e.target.value)}
                    style={{ flex: 1, maxWidth: 400 }} />
                <select className="search-input" value={filter} onChange={e => setFilter(e.target.value)} style={{ width: 150 }}>
                    <option value="all">All</option>
                    <option value="completed">✅ Completed</option>
                    <option value="skipped">❌ Skipped</option>
                </select>
            </div>

            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading...</p> : (
                <div className="card" style={{ padding: 0 }}>
                    <table className="data-table">
                        <thead><tr><th>Date</th><th>Activity</th><th>User</th><th>Status</th><th>XP</th><th>Quality</th><th>Duration</th><th></th></tr></thead>
                        <tbody>
                            {tracking.map(t => (
                                <tr key={t.id}>
                                    <td style={{ fontSize: 12, color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>{t.tracking_date || '—'}</td>
                                    <td style={{ fontWeight: 600 }}>{t.activity_name || '—'}</td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: 12 }}>{t._profile?.full_name || t._profile?.email || '—'}</td>
                                    <td>
                                        {t.completed ?
                                            <span className="badge badge-success">✅ Done</span> :
                                            <span className="badge badge-error">❌ Skipped</span>
                                        }
                                    </td>
                                    <td style={{ fontFamily: 'monospace', color: t.xp_earned ? '#4ade80' : 'var(--text-muted)' }}>
                                        {t.xp_earned ? `+${t.xp_earned}` : '—'}
                                    </td>
                                    <td>{t.quality_rating ? `${t.quality_rating}/5` : '—'}</td>
                                    <td>{t.actual_duration_minutes ? `${t.actual_duration_minutes}m` : '—'}</td>
                                    <td><button className="btn btn-sm" onClick={() => setShowDetail(t)}>View</button></td>
                                </tr>
                            ))}
                            {tracking.length === 0 && <tr><td colSpan={8} style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)' }}>No routine tracking data found</td></tr>}
                        </tbody>
                    </table>
                </div>
            )}

            {showDetail && (
                <div className="modal-overlay" onClick={() => setShowDetail(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 500 }}>
                        <h2>{showDetail.activity_name || 'Activity Detail'}</h2>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>User</span><br />{showDetail._profile?.full_name || '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Date</span><br />{showDetail.tracking_date || '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Scheduled</span><br />{showDetail.scheduled_time || '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Status</span><br />{showDetail.completed ? '✅ Completed' : '❌ Skipped'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Duration</span><br />{showDetail.actual_duration_minutes ? `${showDetail.actual_duration_minutes} min` : '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>XP Earned</span><br />{showDetail.xp_earned || 0}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Quality</span><br />{showDetail.quality_rating ? `${showDetail.quality_rating}/5` : '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Difficulty</span><br />{showDetail.difficulty_rating ? `${showDetail.difficulty_rating}/5` : '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Completion</span><br />{showDetail.completion_percent != null ? `${showDetail.completion_percent}%` : '—'}</div>
                            {showDetail.completed_at && <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Completed At</span><br />{new Date(showDetail.completed_at).toLocaleString('en-IN')}</div>}
                        </div>
                        {showDetail.notes && (
                            <div style={{ marginBottom: 12 }}>
                                <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 4 }}>Notes</div>
                                <div style={{ background: 'var(--bg-surface)', padding: 12, borderRadius: 8, fontSize: 13 }}>{showDetail.notes}</div>
                            </div>
                        )}
                        {showDetail.reason && (
                            <div style={{ marginBottom: 12 }}>
                                <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 4 }}>Skip Reason</div>
                                <div style={{ background: 'var(--bg-surface)', padding: 12, borderRadius: 8, fontSize: 13, color: '#f97316' }}>{showDetail.reason}</div>
                            </div>
                        )}
                        {showDetail.skip_reason && !showDetail.reason && (
                            <div style={{ marginBottom: 12 }}>
                                <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 4 }}>Skip Reason</div>
                                <div style={{ background: 'var(--bg-surface)', padding: 12, borderRadius: 8, fontSize: 13, color: '#f97316' }}>{showDetail.skip_reason}</div>
                            </div>
                        )}
                        <div style={{ marginTop: 16, textAlign: 'right' }}><button className="btn" onClick={() => setShowDetail(null)}>Close</button></div>
                    </div>
                </div>
            )}
        </div>
    );
}

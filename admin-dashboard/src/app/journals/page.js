'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function JournalsPage() {
    const supabase = createClient();
    const [entries, setEntries] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [moodFilter, setMoodFilter] = useState('all');
    const [selected, setSelected] = useState(null);
    const [stats, setStats] = useState({ total: 0, avgMood: 0, thisWeek: 0 });

    useEffect(() => { fetchEntries(); }, [search, moodFilter]);

    const fetchEntries = async () => {
        setLoading(true);
        let q = supabase.from('journal_entries').select('*, user_profiles:user_id(full_name, email)').order('created_at', { ascending: false }).limit(100);
        if (search) q = q.ilike('content', `%${search}%`);
        if (moodFilter !== 'all') {
            const range = { happy: [4, 5], neutral: [3, 3], sad: [1, 2] }[moodFilter];
            if (range) q = q.gte('mood_score', range[0]).lte('mood_score', range[1]);
        }
        const { data } = await q;
        setEntries(data || []);

        // Stats
        const { count } = await supabase.from('journal_entries').select('id', { count: 'exact', head: true });
        const weekAgo = new Date(); weekAgo.setDate(weekAgo.getDate() - 7);
        const { count: weekCount } = await supabase.from('journal_entries').select('id', { count: 'exact', head: true }).gte('created_at', weekAgo.toISOString());
        const avg = data && data.length > 0 ? data.reduce((s, e) => s + (e.mood_score || 0), 0) / data.length : 0;
        setStats({ total: count || 0, avgMood: Math.round(avg * 10) / 10, thisWeek: weekCount || 0 });
        setLoading(false);
    };

    const moodEmoji = (s) => {
        if (!s) return '—';
        if (s >= 4.5) return '😄';
        if (s >= 3.5) return '🙂';
        if (s >= 2.5) return '😐';
        if (s >= 1.5) return '😔';
        return '😢';
    };

    const deleteEntry = async (id) => {
        if (!confirm('Delete this journal entry?')) return;
        await supabase.from('journal_entries').delete().eq('id', id);
        fetchEntries();
        setSelected(null);
    };

    return (
        <div>
            <div className="page-header">
                <div><h1>Journals</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>{stats.total} entries total</p></div>
            </div>

            <div className="stats-grid" style={{ marginBottom: 24 }}>
                <div className="card" style={{ textAlign: 'center' }}><div style={{ fontSize: 28, fontWeight: 800 }}>{stats.total}</div><div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Total Entries</div></div>
                <div className="card" style={{ textAlign: 'center' }}><div style={{ fontSize: 28, fontWeight: 800 }}>{moodEmoji(stats.avgMood)} {stats.avgMood}</div><div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Avg Mood</div></div>
                <div className="card" style={{ textAlign: 'center' }}><div style={{ fontSize: 28, fontWeight: 800 }}>{stats.thisWeek}</div><div style={{ color: 'var(--text-muted)', fontSize: 13 }}>This Week</div></div>
            </div>

            <div style={{ display: 'flex', gap: 12, marginBottom: 24 }}>
                <input className="search-input" placeholder="Search journal content..." value={search} onChange={e => setSearch(e.target.value)} style={{ flex: 1 }} />
                <select className="search-input" value={moodFilter} onChange={e => setMoodFilter(e.target.value)} style={{ width: 140 }}>
                    <option value="all">All Moods</option>
                    <option value="happy">😄 Happy (4-5)</option>
                    <option value="neutral">😐 Neutral (3)</option>
                    <option value="sad">😢 Sad (1-2)</option>
                </select>
            </div>

            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading...</p> : (
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(320px, 1fr))', gap: 16 }}>
                    {entries.map(e => (
                        <div key={e.id} className="card" style={{ cursor: 'pointer' }} onClick={() => setSelected(e)}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 8 }}>
                                <span style={{ fontSize: 20 }}>{moodEmoji(e.mood_score)}</span>
                                <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{new Date(e.created_at).toLocaleDateString('en-IN')}</span>
                            </div>
                            <div style={{ fontSize: 12, fontWeight: 600, marginBottom: 4 }}>{e.user_profiles?.full_name || e.user_profiles?.email || 'Unknown'}</div>
                            <p style={{ fontSize: 13, color: 'var(--text-secondary)', lineHeight: 1.5, overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical' }}>
                                {e.content || e.text || 'No content'}
                            </p>
                            {e.gratitude && <div style={{ marginTop: 8, fontSize: 11, color: 'var(--accent)' }}>🙏 {e.gratitude}</div>}
                            <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
                                {e.mood_score && <span className="badge">Mood: {e.mood_score}/5</span>}
                                {e.energy_level && <span className="badge">Energy: {e.energy_level}</span>}
                            </div>
                        </div>
                    ))}
                    {entries.length === 0 && <p style={{ color: 'var(--text-muted)', padding: 30 }}>No journal entries found</p>}
                </div>
            )}

            {selected && (
                <div className="modal-overlay" onClick={() => setSelected(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 16 }}>
                            <h2>{moodEmoji(selected.mood_score)} Journal Entry</h2>
                            <button className="btn btn-sm" onClick={() => setSelected(null)}>✕</button>
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>User</span><br />{selected.user_profiles?.full_name || '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Date</span><br />{new Date(selected.created_at).toLocaleString('en-IN')}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Mood Score</span><br />{selected.mood_score || '—'}/5</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Energy</span><br />{selected.energy_level || '—'}</div>
                        </div>
                        <div style={{ marginBottom: 16 }}>
                            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 4 }}>Content</div>
                            <div style={{ background: 'var(--bg-surface)', padding: 16, borderRadius: 8, fontSize: 13, lineHeight: 1.7 }}>{selected.content || selected.text || '—'}</div>
                        </div>
                        {selected.gratitude && (
                            <div style={{ marginBottom: 16 }}>
                                <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 4 }}>Gratitude</div>
                                <div style={{ background: 'var(--bg-surface)', padding: 12, borderRadius: 8, fontSize: 13, color: 'var(--accent)' }}>🙏 {selected.gratitude}</div>
                            </div>
                        )}
                        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                            <button className="btn btn-danger" onClick={() => deleteEntry(selected.id)}>Delete Entry</button>
                            <button className="btn" onClick={() => setSelected(null)}>Close</button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

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
        try {
            let q = supabase.from('journal_entries').select('*').order('created_at', { ascending: false }).limit(100);
            if (search) q = q.ilike('content', `%${search}%`);
            if (moodFilter !== 'all') {
                const range = { happy: [4, 5], neutral: [3, 3], sad: [1, 2] }[moodFilter];
                if (range) q = q.gte('mood_rating', range[0]).lte('mood_rating', range[1]);
            }
            const { data, error } = await q;
            if (error) { console.error('Journal fetch error:', error); setEntries([]); setLoading(false); return; }

            const items = data || [];

            // Enrich with user profiles (no FK exists)
            const userIds = [...new Set(items.map(e => e.user_id).filter(Boolean))];
            let profileMap = {};
            if (userIds.length > 0) {
                const { data: profiles } = await supabase.from('user_profiles')
                    .select('id, full_name, email')
                    .in('id', userIds);
                (profiles || []).forEach(p => { profileMap[p.id] = p; });
            }
            items.forEach(e => { e._profile = profileMap[e.user_id] || null; });

            setEntries(items);

            // Stats
            const { count } = await supabase.from('journal_entries').select('id', { count: 'exact', head: true });
            const weekAgo = new Date(); weekAgo.setDate(weekAgo.getDate() - 7);
            const { count: weekCount } = await supabase.from('journal_entries').select('id', { count: 'exact', head: true }).gte('created_at', weekAgo.toISOString());
            const avg = items.length > 0 ? items.reduce((s, e) => s + (e.mood_rating || 0), 0) / items.length : 0;
            setStats({ total: count || 0, avgMood: Math.round(avg * 10) / 10, thisWeek: weekCount || 0 });
        } catch (err) {
            console.error('Error fetching journals:', err);
            setEntries([]);
        }
        setLoading(false);
    };

    const moodEmoji = (s) => {
        if (!s) return '—';
        if (s >= 5) return '😄';
        if (s >= 4) return '🙂';
        if (s >= 3) return '😐';
        if (s >= 2) return '😔';
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
                                <span style={{ fontSize: 20 }}>{moodEmoji(e.mood_rating)}</span>
                                <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{new Date(e.created_at).toLocaleDateString('en-IN')}</span>
                            </div>
                            <div style={{ fontSize: 13, fontWeight: 700, marginBottom: 4 }}>{e.title || 'Untitled'}</div>
                            <div style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 6 }}>{e._profile?.full_name || e._profile?.email || 'Unknown User'}</div>
                            <p style={{ fontSize: 13, color: 'var(--text-secondary)', lineHeight: 1.5, overflow: 'hidden', display: '-webkit-box', WebkitLineClamp: 3, WebkitBoxOrient: 'vertical' }}>
                                {e.content || 'No content'}
                            </p>
                            <div style={{ display: 'flex', gap: 6, marginTop: 8, flexWrap: 'wrap' }}>
                                {e.mood_rating && <span className="badge">Mood: {e.mood_rating}/5</span>}
                                {e.word_count > 0 && <span className="badge">{e.word_count} words</span>}
                                {e.has_photo && <span className="badge">📷 Photo</span>}
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
                            <h2>{moodEmoji(selected.mood_rating)} {selected.title || 'Journal Entry'}</h2>
                            <button className="btn btn-sm" onClick={() => setSelected(null)}>✕</button>
                        </div>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>User</span><br />{selected._profile?.full_name || '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Date</span><br />{selected.date || new Date(selected.created_at).toLocaleDateString('en-IN')}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Mood Rating</span><br />{selected.mood_rating || '—'}/5</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Word Count</span><br />{selected.word_count || '—'}</div>
                            {selected.writing_time > 0 && <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Writing Time</span><br />{selected.writing_time} min</div>}
                        </div>
                        <div style={{ marginBottom: 16 }}>
                            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 4 }}>Content</div>
                            <div style={{ background: 'var(--bg-surface)', padding: 16, borderRadius: 8, fontSize: 13, lineHeight: 1.7 }}>{selected.content || '—'}</div>
                        </div>
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

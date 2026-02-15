'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function RoutinesPage() {
    const supabase = createClient();
    const [routines, setRoutines] = useState([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [showDetail, setShowDetail] = useState(null);
    const [routineItems, setRoutineItems] = useState([]);

    useEffect(() => { fetchRoutines(); }, [search]);

    const fetchRoutines = async () => {
        setLoading(true);
        let q = supabase.from('routines').select('*, user_profiles:user_id(full_name, email)').order('created_at', { ascending: false });
        if (search) q = q.or(`title.ilike.%${search}%`);
        const { data } = await q;
        setRoutines(data || []);
        setLoading(false);
    };

    const openDetail = async (routine) => {
        setShowDetail(routine);
        const { data } = await supabase.from('routine_items').select('*').eq('routine_id', routine.id).order('time_of_day');
        setRoutineItems(data || []);
    };

    const deleteRoutine = async (id) => {
        if (!confirm('Delete this routine?')) return;
        await supabase.from('routines').delete().eq('id', id);
        fetchRoutines();
        setShowDetail(null);
    };

    return (
        <div>
            <div className="page-header">
                <div><h1>Routines</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>{routines.length} routines</p></div>
            </div>
            <input className="search-input" placeholder="Search routines..." value={search} onChange={e => setSearch(e.target.value)}
                style={{ width: '100%', maxWidth: 400, marginBottom: 24 }} />

            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading...</p> : (
                <div className="card" style={{ padding: 0 }}>
                    <table className="data-table">
                        <thead><tr><th>Title</th><th>User</th><th>Dosha</th><th>Items</th><th>Active</th><th>Created</th><th></th></tr></thead>
                        <tbody>
                            {routines.map(r => (
                                <tr key={r.id}>
                                    <td style={{ fontWeight: 600, cursor: 'pointer' }} onClick={() => openDetail(r)}>{r.title || 'Untitled'}</td>
                                    <td style={{ color: 'var(--text-secondary)' }}>{r.user_profiles?.full_name || r.user_profiles?.email || '—'}</td>
                                    <td><span className="badge">{r.dosha_type || '—'}</span></td>
                                    <td>{r.item_count || '—'}</td>
                                    <td>{r.is_active ? <span className="badge badge-success">Active</span> : <span className="badge badge-error">Inactive</span>}</td>
                                    <td style={{ color: 'var(--text-muted)', fontSize: 12 }}>{new Date(r.created_at).toLocaleDateString('en-IN')}</td>
                                    <td>
                                        <button className="btn btn-sm" onClick={() => openDetail(r)}>View</button>
                                        <button className="btn btn-sm btn-danger" style={{ marginLeft: 6 }} onClick={() => deleteRoutine(r.id)}>Delete</button>
                                    </td>
                                </tr>
                            ))}
                            {routines.length === 0 && <tr><td colSpan={7} style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)' }}>No routines found</td></tr>}
                        </tbody>
                    </table>
                </div>
            )}

            {showDetail && (
                <div className="modal-overlay" onClick={() => setShowDetail(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 600 }}>
                        <h2>{showDetail.title || 'Routine Detail'}</h2>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12, marginBottom: 16 }}>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>User</span><br />{showDetail.user_profiles?.full_name || '—'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Dosha</span><br /><span className="badge">{showDetail.dosha_type || '—'}</span></div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Status</span><br />{showDetail.is_active ? '✅ Active' : '❌ Inactive'}</div>
                            <div><span style={{ fontSize: 11, color: 'var(--text-muted)' }}>Created</span><br />{new Date(showDetail.created_at).toLocaleString('en-IN')}</div>
                        </div>
                        {showDetail.description && <p style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 16 }}>{showDetail.description}</p>}
                        <h4 style={{ fontSize: 13, fontWeight: 700, marginBottom: 8 }}>Items ({routineItems.length})</h4>
                        {routineItems.length > 0 ? (
                            <table className="data-table"><thead><tr><th>Time</th><th>Activity</th><th>Duration</th><th>Category</th></tr></thead>
                                <tbody>{routineItems.map(it => (
                                    <tr key={it.id}>
                                        <td style={{ fontWeight: 600 }}>{it.time_of_day || '—'}</td>
                                        <td>{it.title || it.activity_name || '—'}</td>
                                        <td>{it.duration_minutes ? `${it.duration_minutes}m` : '—'}</td>
                                        <td><span className="badge">{it.category || '—'}</span></td>
                                    </tr>
                                ))}</tbody></table>
                        ) : <p style={{ color: 'var(--text-muted)', fontSize: 12 }}>No items in this routine</p>}
                        <div style={{ marginTop: 16, textAlign: 'right' }}><button className="btn" onClick={() => setShowDetail(null)}>Close</button></div>
                    </div>
                </div>
            )}
        </div>
    );
}

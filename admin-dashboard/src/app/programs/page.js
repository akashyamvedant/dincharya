'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function ProgramsPage() {
    const supabase = createClient();
    const [programs, setPrograms] = useState([]);
    const [sessions, setSessions] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showModal, setShowModal] = useState(false);
    const [editing, setEditing] = useState(null);
    const [showMapping, setShowMapping] = useState(null);
    const [programSessions, setProgramSessions] = useState([]);
    const [form, setForm] = useState({
        title: '', title_hindi: '', description: '', category: '',
        difficulty: 3, total_sessions: 0, duration_days: 7,
        dosha_affinity: '', thumbnail_url: '', is_active: true,
    });

    useEffect(() => { fetchAll(); }, []);
    const fetchAll = async () => {
        setLoading(true);
        const [p, s] = await Promise.all([
            supabase.from('programs').select('*, program_sessions(id), user_program_enrollments(id)').order('created_at', { ascending: false }),
            supabase.from('sessions').select('id, title, category, duration').order('title'),
        ]);
        setPrograms((p.data || []).map(prog => ({
            ...prog,
            _sessionCount: prog.program_sessions?.length || 0,
            _enrollCount: prog.user_program_enrollments?.length || 0,
        })));
        setSessions(s.data || []);
        setLoading(false);
    };

    const openCreate = () => { setEditing(null); setForm({ title: '', title_hindi: '', description: '', category: '', difficulty: 3, total_sessions: 0, duration_days: 7, dosha_affinity: '', thumbnail_url: '', is_active: true }); setShowModal(true); };
    const openEdit = (p) => { setEditing(p); setForm({ title: p.title, title_hindi: p.title_hindi || '', description: p.description || '', category: p.category || '', difficulty: p.difficulty || 3, total_sessions: p.total_sessions || 0, duration_days: p.duration_days || 7, dosha_affinity: Array.isArray(p.dosha_affinity) ? p.dosha_affinity.join(', ') : '', thumbnail_url: p.thumbnail_url || '', is_active: p.is_active !== false }); setShowModal(true); };

    const handleSave = async () => {
        const payload = { ...form, difficulty: parseInt(form.difficulty) || 3, total_sessions: parseInt(form.total_sessions) || 0, duration_days: parseInt(form.duration_days) || 7, dosha_affinity: form.dosha_affinity ? form.dosha_affinity.split(',').map(d => d.trim()).filter(Boolean) : [] };
        if (editing) { await supabase.from('programs').update(payload).eq('id', editing.id); }
        else { await supabase.from('programs').insert(payload); }
        setShowModal(false); fetchAll();
    };

    const handleDelete = async (id) => { if (!confirm('Delete program?')) return; await supabase.from('programs').delete().eq('id', id); fetchAll(); };

    const openMapping = async (prog) => {
        setShowMapping(prog);
        const { data } = await supabase.from('program_sessions').select('*, sessions:session_id(title, category, duration)').eq('program_id', prog.id).order('sequence_order');
        setProgramSessions(data || []);
    };

    const addSessionMapping = async (sessionId) => {
        const nextOrder = programSessions.length;
        await supabase.from('program_sessions').insert({ program_id: showMapping.id, session_id: sessionId, sequence_order: nextOrder, day_number: nextOrder + 1 });
        openMapping(showMapping);
    };

    const removeMapping = async (id) => { await supabase.from('program_sessions').delete().eq('id', id); openMapping(showMapping); };

    const difficultyLabel = (d) => ({ 1: 'Beginner', 2: 'Easy', 3: 'Medium', 4: 'Hard', 5: 'Expert' }[d] || `${d}`);

    return (
        <div>
            <div className="page-header">
                <div><h1>Programs</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>{programs.length} programs</p></div>
                <button className="btn btn-primary" onClick={openCreate}>+ New Program</button>
            </div>
            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading...</p> : (
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(340px, 1fr))', gap: 16 }}>
                    {programs.map(p => (
                        <div key={p.id} className="card">
                            <div style={{ display: 'flex', gap: 12, marginBottom: 12 }}>
                                {p.thumbnail_url && <img src={p.thumbnail_url} alt="" style={{ width: 60, height: 60, borderRadius: 8, objectFit: 'cover' }} />}
                                <div style={{ flex: 1 }}>
                                    <h3 style={{ fontSize: 16, fontWeight: 700, marginBottom: 2 }}>{p.title}</h3>
                                    {p.title_hindi && <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>{p.title_hindi}</div>}
                                    <div style={{ display: 'flex', gap: 6, marginTop: 4, flexWrap: 'wrap' }}>
                                        <span className="badge">{p.category}</span>
                                        <span className={`badge ${p.is_active ? 'badge-success' : 'badge-error'}`}>{p.is_active ? 'Active' : 'Inactive'}</span>
                                    </div>
                                </div>
                            </div>
                            {p.description && <p style={{ fontSize: 13, color: 'var(--text-secondary)', marginBottom: 12 }}>{p.description}</p>}
                            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 12 }}>
                                <div style={{ textAlign: 'center' }}><div style={{ fontWeight: 700, fontSize: 16 }}>{p.duration_days || 7}</div><div style={{ fontSize: 10, color: 'var(--text-muted)' }}>Days</div></div>
                                <div style={{ textAlign: 'center' }}><div style={{ fontWeight: 700, fontSize: 16 }}>{p._sessionCount}</div><div style={{ fontSize: 10, color: 'var(--text-muted)' }}>Sessions</div></div>
                                <div style={{ textAlign: 'center' }}><div style={{ fontWeight: 700, fontSize: 16 }}>{p._enrollCount}</div><div style={{ fontSize: 10, color: 'var(--text-muted)' }}>Enrolled</div></div>
                                <div style={{ textAlign: 'center' }}><div style={{ fontWeight: 700, fontSize: 16 }}>{difficultyLabel(p.difficulty)}</div><div style={{ fontSize: 10, color: 'var(--text-muted)' }}>Level</div></div>
                            </div>
                            {Array.isArray(p.dosha_affinity) && p.dosha_affinity.length > 0 && (
                                <div style={{ marginBottom: 12 }}>{p.dosha_affinity.map(d => <span key={d} className="badge" style={{ marginRight: 4 }}>{d}</span>)}</div>
                            )}
                            <div style={{ display: 'flex', gap: 8 }}>
                                <button className="btn btn-sm" onClick={() => openMapping(p)}>Sessions Map</button>
                                <button className="btn btn-sm" onClick={() => openEdit(p)}>Edit</button>
                                <button className="btn btn-sm btn-danger" onClick={() => handleDelete(p.id)}>Delete</button>
                            </div>
                        </div>
                    ))}
                </div>
            )}
            {showModal && (
                <div className="modal-overlay" onClick={() => setShowModal(false)}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
                        <h2>{editing ? 'Edit Program' : 'New Program'}</h2>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                            <div className="form-group"><label>Title</label><input className="form-input" value={form.title} onChange={e => setForm({ ...form, title: e.target.value })} /></div>
                            <div className="form-group"><label>Title Hindi</label><input className="form-input" value={form.title_hindi} onChange={e => setForm({ ...form, title_hindi: e.target.value })} /></div>
                            <div className="form-group"><label>Category</label><input className="form-input" value={form.category} onChange={e => setForm({ ...form, category: e.target.value })} /></div>
                            <div className="form-group"><label>Difficulty (1-5)</label><input className="form-input" type="number" min="1" max="5" value={form.difficulty} onChange={e => setForm({ ...form, difficulty: e.target.value })} /></div>
                            <div className="form-group"><label>Duration (days)</label><input className="form-input" type="number" value={form.duration_days} onChange={e => setForm({ ...form, duration_days: e.target.value })} /></div>
                            <div className="form-group"><label>Total Sessions</label><input className="form-input" type="number" value={form.total_sessions} onChange={e => setForm({ ...form, total_sessions: e.target.value })} /></div>
                            <div className="form-group"><label>Dosha Affinity (comma sep)</label><input className="form-input" value={form.dosha_affinity} onChange={e => setForm({ ...form, dosha_affinity: e.target.value })} placeholder="vata, pitta, kapha" /></div>
                            <div className="form-group"><label>Thumbnail URL</label><input className="form-input" value={form.thumbnail_url} onChange={e => setForm({ ...form, thumbnail_url: e.target.value })} /></div>
                            <div className="form-group" style={{ gridColumn: '1/-1' }}><label>Description</label><textarea className="form-input" rows={3} value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} /></div>
                            <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}><input type="checkbox" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} /> Active</label>
                        </div>
                        <div style={{ display: 'flex', gap: 12, marginTop: 20, justifyContent: 'flex-end' }}><button className="btn" onClick={() => setShowModal(false)}>Cancel</button><button className="btn btn-primary" onClick={handleSave}>{editing ? 'Save' : 'Create'}</button></div>
                    </div>
                </div>
            )}
            {showMapping && (
                <div className="modal-overlay" onClick={() => setShowMapping(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 700 }}>
                        <h2>Sessions in: {showMapping.title}</h2>
                        {programSessions.length > 0 ? (
                            <table className="data-table"><thead><tr><th>#</th><th>Day</th><th>Session</th><th>Category</th><th></th></tr></thead>
                                <tbody>{programSessions.map((ps, i) => (
                                    <tr key={ps.id}><td>{ps.sequence_order}</td><td>Day {ps.day_number}</td><td style={{ fontWeight: 600 }}>{ps.sessions?.title || '—'}</td><td><span className="badge">{ps.sessions?.category}</span></td><td><button className="btn btn-sm btn-danger" onClick={() => removeMapping(ps.id)}>✕</button></td></tr>
                                ))}</tbody></table>
                        ) : <p style={{ color: 'var(--text-muted)', marginBottom: 16 }}>No sessions mapped yet</p>}
                        <div style={{ marginTop: 16 }}>
                            <label style={{ fontWeight: 600, marginBottom: 8, display: 'block' }}>Add Session:</label>
                            <select className="form-input" onChange={e => { if (e.target.value) { addSessionMapping(e.target.value); e.target.value = ''; } }}>
                                <option value="">Select session to add...</option>
                                {sessions.filter(s => !programSessions.find(ps => ps.session_id === s.id)).map(s => <option key={s.id} value={s.id}>{s.title} ({s.category})</option>)}
                            </select>
                        </div>
                        <div style={{ marginTop: 16, textAlign: 'right' }}><button className="btn" onClick={() => setShowMapping(null)}>Close</button></div>
                    </div>
                </div>
            )}
        </div>
    );
}

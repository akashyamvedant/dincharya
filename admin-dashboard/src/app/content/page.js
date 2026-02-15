'use client';
import { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase';

export default function ContentPage() {
    const supabase = createClient();
    const [content, setContent] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('all');
    const [search, setSearch] = useState('');
    const [showModal, setShowModal] = useState(false);
    const [editing, setEditing] = useState(null);
    const [types, setTypes] = useState([]);
    const [form, setForm] = useState({ type: '', category: '', title: '', content: '', author: '', language: 'en', is_active: true });

    const fetchContent = useCallback(async () => {
        setLoading(true);
        let q = supabase.from('app_content').select('*').order('created_at', { ascending: false });
        if (filter !== 'all') q = q.eq('type', filter);
        if (search) q = q.or(`title.ilike.%${search}%,content.ilike.%${search}%,author.ilike.%${search}%`);
        const { data } = await q;
        setContent(data || []);
        setLoading(false);
    }, [filter, search]);

    useEffect(() => { fetchContent(); }, [fetchContent]);
    useEffect(() => {
        (async () => {
            const { data } = await supabase.from('app_content').select('type');
            setTypes([...new Set((data || []).map(d => d.type).filter(Boolean))]);
        })();
    }, []);

    const openCreate = () => { setEditing(null); setForm({ type: types[0] || '', category: '', title: '', content: '', author: '', language: 'en', is_active: true }); setShowModal(true); };
    const openEdit = (c) => { setEditing(c); setForm({ type: c.type || '', category: c.category || '', title: c.title || '', content: c.content || '', author: c.author || '', language: c.language || 'en', is_active: c.is_active !== false }); setShowModal(true); };
    const handleSave = async () => { if (editing) { await supabase.from('app_content').update(form).eq('id', editing.id); } else { await supabase.from('app_content').insert(form); } setShowModal(false); fetchContent(); };
    const handleDelete = async (id) => { if (!confirm('Delete?')) return; await supabase.from('app_content').delete().eq('id', id); fetchContent(); };
    const toggleActive = async (c) => { await supabase.from('app_content').update({ is_active: !c.is_active }).eq('id', c.id); fetchContent(); };

    return (
        <div>
            <div className="page-header">
                <div><h1>Content Management</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>{content.length} items</p></div>
                <button className="btn btn-primary" onClick={openCreate}>+ Add Content</button>
            </div>
            <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
                <input className="search-input" placeholder="Search title, content, author..." value={search} onChange={e => setSearch(e.target.value)} style={{ flex: 1, minWidth: 200 }} />
                <select className="search-input" value={filter} onChange={e => setFilter(e.target.value)} style={{ width: 180 }}>
                    <option value="all">All Types</option>
                    {types.map(t => <option key={t} value={t}>{t}</option>)}
                </select>
            </div>
            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading...</p> : (
                <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
                    <table className="data-table"><thead><tr><th>Title</th><th>Type</th><th>Category</th><th>Author</th><th>Lang</th><th>Status</th><th>Created</th><th>Actions</th></tr></thead>
                        <tbody>{content.map(c => (
                            <tr key={c.id}>
                                <td><div style={{ fontWeight: 600 }}>{c.title || '(No title)'}</div><div style={{ fontSize: 11, color: 'var(--text-muted)', maxWidth: 300, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{c.content?.substring(0, 80)}</div></td>
                                <td><span className="badge">{c.type}</span></td>
                                <td style={{ color: 'var(--text-secondary)' }}>{c.category || '—'}</td>
                                <td style={{ color: 'var(--text-secondary)' }}>{c.author || '—'}</td>
                                <td style={{ textTransform: 'uppercase', fontSize: 11, fontWeight: 600 }}>{c.language || 'en'}</td>
                                <td><span className={`badge ${c.is_active ? 'badge-success' : 'badge-error'}`} style={{ cursor: 'pointer' }} onClick={() => toggleActive(c)}>{c.is_active ? '● Active' : '○ Inactive'}</span></td>
                                <td style={{ fontSize: 12, color: 'var(--text-muted)' }}>{new Date(c.created_at).toLocaleDateString('en-IN')}</td>
                                <td><div style={{ display: 'flex', gap: 6 }}><button className="btn btn-sm" onClick={() => openEdit(c)}>Edit</button><button className="btn btn-sm btn-danger" onClick={() => handleDelete(c.id)}>✕</button></div></td>
                            </tr>
                        ))}</tbody></table>
                    {content.length === 0 && <p style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>No content found</p>}
                </div>
            )}
            {showModal && (
                <div className="modal-overlay" onClick={() => setShowModal(false)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 650 }}>
                        <h2>{editing ? 'Edit Content' : 'Add Content'}</h2>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                            <div className="form-group" style={{ gridColumn: '1/-1' }}><label>Title</label><input className="form-input" value={form.title} onChange={e => setForm({ ...form, title: e.target.value })} /></div>
                            <div className="form-group"><label>Type</label><select className="form-input" value={form.type} onChange={e => setForm({ ...form, type: e.target.value })}><option value="">Select...</option>{types.map(t => <option key={t} value={t}>{t}</option>)}<option value="quote">Quote</option><option value="tip">Tip</option><option value="article">Article</option><option value="mantra">Mantra</option></select></div>
                            <div className="form-group"><label>Category</label><input className="form-input" value={form.category} onChange={e => setForm({ ...form, category: e.target.value })} /></div>
                            <div className="form-group"><label>Author</label><input className="form-input" value={form.author} onChange={e => setForm({ ...form, author: e.target.value })} /></div>
                            <div className="form-group"><label>Language</label><select className="form-input" value={form.language} onChange={e => setForm({ ...form, language: e.target.value })}><option value="en">English</option><option value="hi">Hindi</option><option value="sa">Sanskrit</option></select></div>
                            <div className="form-group" style={{ gridColumn: '1/-1' }}><label>Content</label><textarea className="form-input" rows={6} value={form.content} onChange={e => setForm({ ...form, content: e.target.value })} /></div>
                            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}><input type="checkbox" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} /> Active</label>
                        </div>
                        <div style={{ display: 'flex', gap: 12, marginTop: 20, justifyContent: 'flex-end' }}><button className="btn" onClick={() => setShowModal(false)}>Cancel</button><button className="btn btn-primary" onClick={handleSave}>{editing ? 'Save' : 'Create'}</button></div>
                    </div>
                </div>
            )}
        </div>
    );
}

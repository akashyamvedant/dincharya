'use client';

import { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase';
import Link from 'next/link';
import MediaUploader from '@/components/MediaUploader';

export default function SessionsPage() {
  const supabase = createClient();
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [filter, setFilter] = useState('all');
  const [premiumFilter, setPremiumFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [categories, setCategories] = useState([]);
  const [linkedPoses, setLinkedPoses] = useState({});
  const [form, setForm] = useState({
    title: '', title_hindi: '', description: '', category: '',
    media_type: 'audio', media_url: '', thumbnail_url: '',
    duration: 600, difficulty: 3, is_premium: false, is_active: true,
    youtube_url: '', video_url: '', audio_url: '',
    display_order: 0, instructor_name: '', instructor_avatar_url: '', tags: '',
  });

  const fetchSessions = useCallback(async () => {
    setLoading(true);
    let query = supabase.from('sessions').select('*').order('display_order', { ascending: true }).order('created_at', { ascending: false });
    if (filter !== 'all') query = query.eq('category', filter);
    if (premiumFilter === 'premium') query = query.eq('is_premium', true);
    if (premiumFilter === 'free') query = query.eq('is_premium', false);
    if (search) query = query.or(`title.ilike.%${search}%,description.ilike.%${search}%,instructor_name.ilike.%${search}%`);
    const { data } = await query;
    setSessions(data || []);
    setLoading(false);
  }, [filter, premiumFilter, search]);

  useEffect(() => { fetchSessions(); fetchLinkedPoses(); }, [fetchSessions]);

  const fetchLinkedPoses = async () => {
    const { data } = await supabase.from('yoga_poses').select('id, name, linked_session_id, total_steps, is_active');
    const map = {};
    (data || []).forEach(p => { if (p.linked_session_id) map[p.linked_session_id] = p; });
    setLinkedPoses(map);
  };

  useEffect(() => {
    async function loadCategories() {
      const { data } = await supabase.from('sessions').select('category');
      const unique = [...new Set((data || []).map(d => d.category).filter(Boolean))];
      setCategories(unique);
    }
    loadCategories();
  }, []);

  const openCreate = () => {
    setEditing(null);
    setForm({
      title: '', title_hindi: '', description: '', category: categories[0] || '',
      media_type: 'audio', media_url: '', thumbnail_url: '',
      duration: 600, difficulty: 3, is_premium: false, is_active: true,
      youtube_url: '', video_url: '', audio_url: '',
      display_order: 0, instructor_name: '', instructor_avatar_url: '', tags: '',
    });
    setShowModal(true);
  };

  const openEdit = (s) => {
    setEditing(s);
    setForm({
      title: s.title || '', title_hindi: s.title_hindi || '',
      description: s.description || '', category: s.category || '',
      media_type: s.media_type || 'audio', media_url: s.media_url || '',
      thumbnail_url: s.thumbnail_url || '', duration: s.duration || 600,
      difficulty: s.difficulty || 3, is_premium: s.is_premium || false,
      is_active: s.is_active !== false, youtube_url: s.youtube_url || '',
      video_url: s.video_url || '', audio_url: s.audio_url || '',
      display_order: s.display_order || 0, instructor_name: s.instructor_name || '',
      instructor_avatar_url: s.instructor_avatar_url || '',
      tags: Array.isArray(s.tags) ? s.tags.join(', ') : '',
    });
    setShowModal(true);
  };

  const handleSave = async () => {
    const payload = {
      ...form,
      duration: parseInt(form.duration) || 600,
      difficulty: parseInt(form.difficulty) || 3,
      display_order: parseInt(form.display_order) || 0,
      tags: form.tags ? form.tags.split(',').map(t => t.trim()).filter(Boolean) : [],
    };
    if (editing) {
      await supabase.from('sessions').update(payload).eq('id', editing.id);
    } else {
      await supabase.from('sessions').insert(payload);
    }
    setShowModal(false);
    fetchSessions();
  };

  const handleDelete = async (id) => {
    if (!confirm('Delete this session permanently?')) return;
    await supabase.from('sessions').delete().eq('id', id);
    fetchSessions();
  };

  const toggleActive = async (s) => {
    await supabase.from('sessions').update({ is_active: !s.is_active }).eq('id', s.id);
    fetchSessions();
  };

  const togglePremium = async (s) => {
    await supabase.from('sessions').update({ is_premium: !s.is_premium }).eq('id', s.id);
    fetchSessions();
  };

  const formatDuration = (seconds) => {
    if (!seconds) return '—';
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return secs > 0 ? `${mins}m ${secs}s` : `${mins} min`;
  };

  const difficultyLabel = (d) => {
    const labels = { 1: 'Beginner', 2: 'Easy', 3: 'Medium', 4: 'Hard', 5: 'Expert' };
    return labels[d] || `Level ${d}`;
  };

  const difficultyColor = (d) => {
    const colors = { 1: '#4ade80', 2: '#86efac', 3: '#fbbf24', 4: '#f97316', 5: '#ef4444' };
    return colors[d] || '#888';
  };

  const mediaIcon = (type) => {
    const icons = { audio: '🎵', video: '🎬', text: '📝', image: '🖼️', youtube: '▶️' };
    return icons[type] || '📄';
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Sessions Management</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 4 }}>
            {sessions.length} sessions • {sessions.filter(s => s.is_active).length} active • {sessions.filter(s => s.is_premium).length} premium
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Link href="/sessions/yoga-poses"><button className="btn">🪷 Manage Poses</button></Link>
          <button className="btn btn-primary" onClick={openCreate}>+ New Session</button>
        </div>
      </div>

      {/* Filters */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
        <input
          className="search-input" placeholder="Search sessions, instructors..."
          value={search} onChange={e => setSearch(e.target.value)}
          style={{ flex: 1, minWidth: 200 }}
        />
        <select className="search-input" value={filter} onChange={e => setFilter(e.target.value)} style={{ width: 180 }}>
          <option value="all">All Categories</option>
          {categories.map(c => <option key={c} value={c}>{c}</option>)}
        </select>
        <select className="search-input" value={premiumFilter} onChange={e => setPremiumFilter(e.target.value)} style={{ width: 140 }}>
          <option value="all">All Tiers</option>
          <option value="premium">Premium Only</option>
          <option value="free">Free Only</option>
        </select>
      </div>

      {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading sessions...</p> : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table">
            <thead>
              <tr>
                <th>Order</th>
                <th>Session</th>
                <th>Category</th>
                <th>Yoga Pose</th>
                <th>Media</th>
                <th>Duration</th>
                <th>Difficulty</th>
                <th>Views</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {sessions.map(s => (
                <tr key={s.id}>
                  <td style={{ fontFamily: 'monospace', color: 'var(--text-muted)' }}>{s.display_order || 0}</td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                      {s.thumbnail_url && (
                        <img src={s.thumbnail_url} alt="" style={{ width: 40, height: 40, borderRadius: 6, objectFit: 'cover' }} />
                      )}
                      <div>
                        <div style={{ fontWeight: 600 }}>{s.title}</div>
                        {s.title_hindi && <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{s.title_hindi}</div>}
                        {s.instructor_name && <div style={{ fontSize: 11, color: 'var(--accent)' }}>by {s.instructor_name}</div>}
                      </div>
                    </div>
                  </td>
                  <td><span className="badge">{s.category}</span></td>
                  <td>
                    {linkedPoses[s.id] ? (
                      <Link href={`/sessions/yoga-poses/${linkedPoses[s.id].id}/steps`}
                        style={{ textDecoration: 'none', fontSize: 11 }}>
                        <span className="badge badge-success" style={{ cursor: 'pointer' }}>
                          🧘 {linkedPoses[s.id].total_steps || 0} steps
                        </span>
                      </Link>
                    ) : (
                      <span style={{ color: 'var(--text-muted)', fontSize: 11 }}>—</span>
                    )}
                  </td>
                  <td title={s.media_type}>{mediaIcon(s.media_type)}</td>
                  <td>{formatDuration(s.duration)}</td>
                  <td>
                    <span style={{ color: difficultyColor(s.difficulty), fontWeight: 600 }}>
                      {'★'.repeat(s.difficulty || 0)}{'☆'.repeat(5 - (s.difficulty || 0))}
                    </span>
                    <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{difficultyLabel(s.difficulty)}</div>
                  </td>
                  <td style={{ fontFamily: 'monospace' }}>{s.view_count || 0}</td>
                  <td>
                    <div style={{ display: 'flex', gap: 6, flexDirection: 'column', alignItems: 'flex-start' }}>
                      <span className={`badge ${s.is_active ? 'badge-success' : 'badge-error'}`}
                        style={{ cursor: 'pointer' }} onClick={() => toggleActive(s)}>
                        {s.is_active ? '● Active' : '○ Inactive'}
                      </span>
                      <span className={`badge ${s.is_premium ? 'badge-warning' : ''}`}
                        style={{ cursor: 'pointer', fontSize: 10 }} onClick={() => togglePremium(s)}>
                        {s.is_premium ? '👑 Premium' : 'Free'}
                      </span>
                    </div>
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-sm" onClick={() => openEdit(s)}>Edit</button>
                      <button className="btn btn-sm btn-danger" onClick={() => handleDelete(s.id)}>✕</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {sessions.length === 0 && <p style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>No sessions found</p>}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 700, maxHeight: '90vh', overflow: 'auto' }}>
            <h2>{editing ? 'Edit Session' : 'Create Session'}</h2>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Title (English)</label>
                <input className="form-input" value={form.title} onChange={e => setForm({ ...form, title: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Title (Hindi)</label>
                <input className="form-input" value={form.title_hindi} onChange={e => setForm({ ...form, title_hindi: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Instructor</label>
                <input className="form-input" value={form.instructor_name} onChange={e => setForm({ ...form, instructor_name: e.target.value })} />
              </div>
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Description</label>
                <textarea className="form-input" rows={3} value={form.description} onChange={e => setForm({ ...form, description: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Category</label>
                <select className="form-input" value={form.category} onChange={e => setForm({ ...form, category: e.target.value })}>
                  <option value="">Select...</option>
                  {categories.map(c => <option key={c} value={c}>{c}</option>)}
                  <option value="__new__">+ New Category</option>
                </select>
                {form.category === '__new__' && (
                  <input className="form-input" placeholder="Enter new category" style={{ marginTop: 8 }}
                    onChange={e => setForm({ ...form, category: e.target.value })} />
                )}
              </div>
              <div className="form-group">
                <label>Media Type</label>
                <select className="form-input" value={form.media_type} onChange={e => setForm({ ...form, media_type: e.target.value })}>
                  <option value="audio">🎵 Audio</option>
                  <option value="video">🎬 Video</option>
                  <option value="youtube">▶️ YouTube</option>
                  <option value="text">📝 Text</option>
                  <option value="image">🖼️ Image</option>
                </select>
              </div>
              <div className="form-group">
                <label>Media URL</label>
                <MediaUploader
                  bucket="session-media"
                  folder="sessions"
                  accept={form.media_type === 'audio' ? 'audio/*' : form.media_type === 'video' ? 'video/*' : form.media_type === 'image' ? 'image/*' : '*/*'}
                  value={form.media_url}
                  onChange={(url) => setForm({ ...form, media_url: url })}
                  maxSizeMB={100}
                />
              </div>
              <div className="form-group">
                <label>🎵 Audio</label>
                <MediaUploader
                  bucket="session-media"
                  folder="audio"
                  accept="audio/*"
                  value={form.audio_url}
                  onChange={(url) => setForm({ ...form, audio_url: url })}
                  maxSizeMB={100}
                />
              </div>
              <div className="form-group">
                <label>🎬 Video</label>
                <MediaUploader
                  bucket="session-media"
                  folder="video"
                  accept="video/*"
                  value={form.video_url}
                  onChange={(url) => setForm({ ...form, video_url: url })}
                  maxSizeMB={200}
                />
              </div>
              <div className="form-group">
                <label>▶️ YouTube URL</label>
                <input className="form-input" value={form.youtube_url} onChange={e => setForm({ ...form, youtube_url: e.target.value })} placeholder="https://youtube.com/watch?v=..." />
              </div>
              <div className="form-group">
                <label>🖼️ Thumbnail</label>
                <MediaUploader
                  bucket="session-media"
                  folder="thumbnails"
                  accept="image/*"
                  value={form.thumbnail_url}
                  onChange={(url) => setForm({ ...form, thumbnail_url: url })}
                />
              </div>
              <div className="form-group">
                <label>👤 Instructor Avatar</label>
                <MediaUploader
                  bucket="session-media"
                  folder="avatars"
                  accept="image/*"
                  value={form.instructor_avatar_url}
                  onChange={(url) => setForm({ ...form, instructor_avatar_url: url })}
                />
              </div>
              <div className="form-group">
                <label>Duration (seconds)</label>
                <input className="form-input" type="number" value={form.duration} onChange={e => setForm({ ...form, duration: e.target.value })} />
                <small style={{ color: 'var(--text-muted)' }}>{formatDuration(parseInt(form.duration) || 0)}</small>
              </div>
              <div className="form-group">
                <label>Difficulty (1-5)</label>
                <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
                  {[1,2,3,4,5].map(d => (
                    <button key={d} type="button" onClick={() => setForm({ ...form, difficulty: d })}
                      style={{
                        width: 36, height: 36, borderRadius: 8, border: 'none', cursor: 'pointer',
                        background: form.difficulty >= d ? difficultyColor(d) : 'var(--bg-hover)',
                        color: form.difficulty >= d ? '#000' : 'var(--text-muted)', fontWeight: 700, fontSize: 14,
                      }}>
                      {d}
                    </button>
                  ))}
                </div>
                <small style={{ color: 'var(--text-muted)' }}>{difficultyLabel(form.difficulty)}</small>
              </div>
              <div className="form-group">
                <label>Display Order</label>
                <input className="form-input" type="number" value={form.display_order} onChange={e => setForm({ ...form, display_order: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Tags (comma separated)</label>
                <input className="form-input" value={form.tags} onChange={e => setForm({ ...form, tags: e.target.value })} placeholder="meditation, beginner, morning" />
              </div>
              <div className="form-group" style={{ display: 'flex', gap: 20, alignItems: 'center' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                  <input type="checkbox" checked={form.is_premium} onChange={e => setForm({ ...form, is_premium: e.target.checked })} />
                  👑 Premium Only
                </label>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                  <input type="checkbox" checked={form.is_active} onChange={e => setForm({ ...form, is_active: e.target.checked })} />
                  ✅ Active
                </label>
              </div>
            </div>

            <div style={{ display: 'flex', gap: 12, marginTop: 20, justifyContent: 'flex-end' }}>
              <button className="btn" onClick={() => setShowModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave}>
                {editing ? 'Save Changes' : 'Create Session'}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

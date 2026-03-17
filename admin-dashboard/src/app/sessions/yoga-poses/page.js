'use client';

import { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase';
import Link from 'next/link';
import AppPreview from '@/components/AppPreview';
import MediaUploader from '@/components/MediaUploader';

export default function YogaPosesPage() {
  const supabase = createClient();
  const [poses, setPoses] = useState([]);
  const [sessions, setSessions] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [filter, setFilter] = useState('all');
  const [search, setSearch] = useState('');
  const [previewPose, setPreviewPose] = useState(null);
  const [previewSteps, setPreviewSteps] = useState([]);

  const defaultForm = {
    name: '', name_hindi: '', name_sanskrit: '', category: 'yoga',
    description: '', benefits: '', precautions: '',
    literature_content: '', literature_content_hindi: '',
    cover_image_url: '', literature_image_url: '',
    difficulty: 3, total_steps: 0, duration_seconds: 600,
    linked_session_id: '', is_premium: false, is_active: true, display_order: 0,
  };
  const [form, setForm] = useState(defaultForm);

  const fetchPoses = useCallback(async () => {
    setLoading(true);
    let query = supabase.from('yoga_poses').select('*, sessions!yoga_poses_linked_session_id_fkey(id, title, title_hindi, category)').order('display_order', { ascending: true });
    if (filter !== 'all') query = query.eq('category', filter);
    if (search) query = query.or(`name.ilike.%${search}%,name_hindi.ilike.%${search}%,name_sanskrit.ilike.%${search}%`);
    const { data, error } = await query;
    if (error) console.error('Error fetching poses:', error);
    setPoses(data || []);
    setLoading(false);
  }, [filter, search]);

  const fetchSessions = useCallback(async () => {
    const { data } = await supabase.from('sessions').select('id, title, title_hindi, category').eq('is_active', true).order('title');
    setSessions(data || []);
  }, []);

  useEffect(() => { fetchPoses(); }, [fetchPoses]);
  useEffect(() => { fetchSessions(); }, [fetchSessions]);

  // Find unlinked sessions (sessions without a yoga_pose)
  const linkedSessionIds = poses.map(p => p.linked_session_id).filter(Boolean);
  const unlinkedSessions = sessions.filter(s => !linkedSessionIds.includes(s.id));

  const openCreate = () => {
    setEditing(null);
    setForm(defaultForm);
    setShowModal(true);
  };

  const openEdit = (pose) => {
    setEditing(pose);
    setForm({
      name: pose.name || '', name_hindi: pose.name_hindi || '',
      name_sanskrit: pose.name_sanskrit || '', category: pose.category || 'yoga',
      description: pose.description || '',
      benefits: Array.isArray(pose.benefits) ? pose.benefits.join('\n') : '',
      precautions: Array.isArray(pose.precautions) ? pose.precautions.join('\n') : '',
      literature_content: pose.literature_content || '',
      literature_content_hindi: pose.literature_content_hindi || '',
      cover_image_url: pose.cover_image_url || '',
      literature_image_url: pose.literature_image_url || '',
      difficulty: pose.difficulty || 3, total_steps: pose.total_steps || 0,
      duration_seconds: pose.duration_seconds || 600,
      linked_session_id: pose.linked_session_id || '',
      is_premium: pose.is_premium || false, is_active: pose.is_active !== false,
      display_order: pose.display_order || 0,
    });
    setShowModal(true);
  };

  const handleSave = async () => {
    const payload = {
      name: form.name,
      name_hindi: form.name_hindi || null,
      name_sanskrit: form.name_sanskrit || null,
      category: form.category,
      description: form.description || null,
      benefits: form.benefits ? form.benefits.split('\n').map(b => b.trim()).filter(Boolean) : [],
      precautions: form.precautions ? form.precautions.split('\n').map(p => p.trim()).filter(Boolean) : [],
      literature_content: form.literature_content || null,
      literature_content_hindi: form.literature_content_hindi || null,
      cover_image_url: form.cover_image_url || null,
      literature_image_url: form.literature_image_url || null,
      difficulty: parseInt(form.difficulty) || 3,
      total_steps: parseInt(form.total_steps) || 0,
      duration_seconds: parseInt(form.duration_seconds) || 600,
      linked_session_id: form.linked_session_id || null,
      is_premium: form.is_premium,
      is_active: form.is_active,
      display_order: parseInt(form.display_order) || 0,
    };

    if (editing) {
      const { error } = await supabase.from('yoga_poses').update(payload).eq('id', editing.id);
      if (error) { alert('Error: ' + error.message); return; }
    } else {
      const { error } = await supabase.from('yoga_poses').insert(payload);
      if (error) { alert('Error: ' + error.message); return; }
    }
    setShowModal(false);
    fetchPoses();
  };

  const handleDelete = async (id, name) => {
    if (!confirm(`Delete "${name}"?\n\nThis will also delete ALL pose steps linked to this pose. This cannot be undone.`)) return;
    // Delete steps first (cascade)
    await supabase.from('pose_steps').delete().eq('pose_id', id);
    await supabase.from('yoga_poses').delete().eq('id', id);
    fetchPoses();
  };

  const toggleActive = async (pose) => {
    await supabase.from('yoga_poses').update({ is_active: !pose.is_active }).eq('id', pose.id);
    fetchPoses();
  };

  const difficultyLabel = (d) => {
    const labels = { 1: 'Beginner', 2: 'Easy', 3: 'Medium', 4: 'Hard', 5: 'Expert' };
    return labels[d] || `Level ${d}`;
  };

  const difficultyColor = (d) => {
    const colors = { 1: '#4ade80', 2: '#86efac', 3: '#fbbf24', 4: '#f97316', 5: '#ef4444' };
    return colors[d] || '#888';
  };

  const categoryIcon = (cat) => {
    const icons = { yoga: '🧘', pranayama: '🌬️', meditation: '🧠' };
    return icons[cat] || '🧘';
  };

  const openPreview = async (pose) => {
    const { data } = await supabase.from('pose_steps').select('*').eq('pose_id', pose.id).order('step_number', { ascending: true });
    setPreviewSteps(data || []);
    setPreviewPose(pose);
  };

  return (
    <div>
      <div className="page-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <Link href="/sessions" style={{ color: 'var(--text-muted)', textDecoration: 'none', fontSize: 13 }}>← Sessions</Link>
          </div>
          <h1>🧘 Yoga Poses & Guided Practice</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 4 }}>
            {poses.length} poses • {poses.filter(p => p.is_active).length} active • {unlinkedSessions.length} sessions without poses
          </p>
        </div>
        <button className="btn btn-primary" onClick={openCreate}>+ New Pose</button>
      </div>

      {/* Filters */}
      <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
        <input
          className="search-input" placeholder="Search poses..."
          value={search} onChange={e => setSearch(e.target.value)}
          style={{ flex: 1, minWidth: 200 }}
        />
        <select className="search-input" value={filter} onChange={e => setFilter(e.target.value)} style={{ width: 180 }}>
          <option value="all">All Categories</option>
          <option value="yoga">🧘 Yoga</option>
          <option value="pranayama">🌬️ Pranayama</option>
          <option value="meditation">🧠 Meditation</option>
        </select>
      </div>

      {/* Unlinked sessions banner */}
      {unlinkedSessions.length > 0 && (
        <div style={{
          background: 'linear-gradient(135deg, #fff7ed, #fef3c7)', border: '1px solid #f59e0b33',
          borderRadius: 12, padding: '16px 20px', marginBottom: 20, display: 'flex', alignItems: 'center', gap: 12,
        }}>
          <span style={{ fontSize: 24 }}>⚠️</span>
          <div>
            <div style={{ fontWeight: 600, fontSize: 14, color: '#92400e' }}>
              {unlinkedSessions.length} sessions don't have guided practice data
            </div>
            <div style={{ fontSize: 12, color: '#a16207', marginTop: 2 }}>
              These sessions show only video player. Add a pose to enable Theory + Practice tabs.
            </div>
          </div>
        </div>
      )}

      {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading poses...</p> : (
        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
          <table className="data-table">
            <thead>
              <tr>
                <th>Pose</th>
                <th>Category</th>
                <th>Linked Session</th>
                <th>Steps</th>
                <th>Difficulty</th>
                <th>Duration</th>
                <th>Status</th>
                <th>Actions</th>
              </tr>
            </thead>
            <tbody>
              {poses.map(pose => (
                <tr key={pose.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>{pose.name}</div>
                    {pose.name_hindi && <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{pose.name_hindi}</div>}
                    {pose.name_sanskrit && <div style={{ fontSize: 10, color: 'var(--accent)', fontStyle: 'italic' }}>{pose.name_sanskrit}</div>}
                  </td>
                  <td><span className="badge">{categoryIcon(pose.category)} {pose.category}</span></td>
                  <td>
                    {pose.sessions ? (
                      <div>
                        <div style={{ fontSize: 12, fontWeight: 500 }}>{pose.sessions.title}</div>
                        {pose.sessions.title_hindi && <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{pose.sessions.title_hindi}</div>}
                      </div>
                    ) : (
                      <span style={{ color: '#ef4444', fontSize: 12 }}>❌ Not linked</span>
                    )}
                  </td>
                  <td>
                    <Link href={`/sessions/yoga-poses/${pose.id}/steps`}
                      style={{ color: 'var(--accent)', fontWeight: 600, textDecoration: 'none', display: 'flex', alignItems: 'center', gap: 4 }}>
                      {pose.total_steps || 0} steps →
                    </Link>
                  </td>
                  <td>
                    <span style={{ color: difficultyColor(pose.difficulty), fontWeight: 600 }}>
                      {'★'.repeat(pose.difficulty || 0)}{'☆'.repeat(5 - (pose.difficulty || 0))}
                    </span>
                    <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>{difficultyLabel(pose.difficulty)}</div>
                  </td>
                  <td>{Math.floor((pose.duration_seconds || 600) / 60)} min</td>
                  <td>
                    <span className={`badge ${pose.is_active ? 'badge-success' : 'badge-error'}`}
                      style={{ cursor: 'pointer' }} onClick={() => toggleActive(pose)}>
                      {pose.is_active ? '● Active' : '○ Inactive'}
                    </span>
                    {pose.is_premium && <div><span className="badge badge-warning" style={{ fontSize: 10, marginTop: 4 }}>👑 Premium</span></div>}
                  </td>
                  <td>
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-sm" onClick={() => openEdit(pose)}>Edit</button>
                      <button className="btn btn-sm" onClick={() => openPreview(pose)} style={{ background: '#7c3aed', color: '#fff' }}>📱 Preview</button>
                      <Link href={`/sessions/yoga-poses/${pose.id}/steps`}>
                        <button className="btn btn-sm" style={{ background: 'var(--accent)', color: '#fff' }}>Steps</button>
                      </Link>
                      <button className="btn btn-sm btn-danger" onClick={() => handleDelete(pose.id, pose.name)}>✕</button>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
          {poses.length === 0 && <p style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>No poses found. Create your first pose!</p>}
        </div>
      )}

      {/* Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 800, maxHeight: '90vh', overflow: 'auto' }}>
            <h2>{editing ? `Edit: ${editing.name}` : 'Create New Pose'}</h2>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              {/* Names */}
              <div className="form-group">
                <label>Name (English) *</label>
                <input className="form-input" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="e.g. Surya Namaskar" />
              </div>
              <div className="form-group">
                <label>Name (Hindi)</label>
                <input className="form-input" value={form.name_hindi} onChange={e => setForm({ ...form, name_hindi: e.target.value })} placeholder="e.g. सूर्य नमस्कार" />
              </div>
              <div className="form-group">
                <label>Name (Sanskrit)</label>
                <input className="form-input" value={form.name_sanskrit} onChange={e => setForm({ ...form, name_sanskrit: e.target.value })} placeholder="e.g. सूर्यनमस्कारः" />
              </div>
              <div className="form-group">
                <label>Category *</label>
                <select className="form-input" value={form.category} onChange={e => setForm({ ...form, category: e.target.value })}>
                  <option value="yoga">🧘 Yoga</option>
                  <option value="pranayama">🌬️ Pranayama</option>
                  <option value="meditation">🧠 Meditation</option>
                </select>
              </div>

              {/* Link to Session — CRITICAL */}
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label style={{ color: '#ea580c', fontWeight: 700 }}>🔗 Link to Session (CRITICAL)</label>
                <select className="form-input" value={form.linked_session_id} onChange={e => setForm({ ...form, linked_session_id: e.target.value })}
                  style={{ borderColor: form.linked_session_id ? '#4ade80' : '#f97316' }}>
                  <option value="">— Select a session to link —</option>
                  <optgroup label="⚠️ Unlinked Sessions (no pose yet)">
                    {unlinkedSessions.map(s => (
                      <option key={s.id} value={s.id}>[{s.category}] {s.title} {s.title_hindi ? `(${s.title_hindi})` : ''}</option>
                    ))}
                  </optgroup>
                  <optgroup label="All Sessions">
                    {sessions.map(s => (
                      <option key={s.id} value={s.id}>[{s.category}] {s.title}</option>
                    ))}
                  </optgroup>
                </select>
                <small style={{ color: 'var(--text-muted)' }}>
                  This links the pose to a session. When users open that session, they'll see Theory + Practice tabs.
                </small>
              </div>

              {/* Description */}
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Description</label>
                <textarea className="form-input" rows={3} value={form.description} onChange={e => setForm({ ...form, description: e.target.value })}
                  placeholder="Brief description of this pose/practice..." />
              </div>

              {/* Benefits & Precautions */}
              <div className="form-group">
                <label>Benefits (one per line)</label>
                <textarea className="form-input" rows={4} value={form.benefits} onChange={e => setForm({ ...form, benefits: e.target.value })}
                  placeholder={"Improves flexibility\nStrengthens muscles\nReduces stress"} />
              </div>
              <div className="form-group">
                <label>Precautions (one per line)</label>
                <textarea className="form-input" rows={4} value={form.precautions} onChange={e => setForm({ ...form, precautions: e.target.value })}
                  placeholder={"Avoid if knee injury\nNot for pregnant women\nConsult doctor first"} />
              </div>

              {/* Literature */}
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Literature (English)</label>
                <textarea className="form-input" rows={5} value={form.literature_content} onChange={e => setForm({ ...form, literature_content: e.target.value })}
                  placeholder={"Page 1 content here - introduction...\n---PAGE---\nPage 2 content here - technique...\n---PAGE---\nPage 3 content here - spiritual significance..."} />
                <small style={{ color: 'var(--text-muted)' }}>Use <code>---PAGE---</code> to split into book-style pages in the app.</small>
              </div>
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Literature (Hindi)</label>
                <textarea className="form-input" rows={5} value={form.literature_content_hindi} onChange={e => setForm({ ...form, literature_content_hindi: e.target.value })}
                  placeholder={"हिंदी में परिचय और इतिहास...\n---PAGE---\nविस्तृत तकनीक और संरेखण...\n---PAGE---\nआध्यात्मिक महत्व और मंत्र..."} />
              </div>

              {/* Images */}
              <div className="form-group">
                <label>🖼️ Pose Cover Image</label>
                <MediaUploader
                  bucket="session-media"
                  folder="poses/covers"
                  accept="image/*"
                  value={form.cover_image_url}
                  onChange={(url) => setForm({ ...form, cover_image_url: url })}
                />
                <small style={{ color: 'var(--text-muted)' }}>Main pose illustration shown in overview</small>
              </div>
              <div className="form-group">
                <label>📖 Literature Book Image</label>
                <MediaUploader
                  bucket="session-media"
                  folder="poses/literature"
                  accept="image/*"
                  value={form.literature_image_url}
                  onChange={(url) => setForm({ ...form, literature_image_url: url })}
                />
                <small style={{ color: 'var(--text-muted)' }}>Artistic illustration for the Theory/Book section</small>
              </div>

              {/* Settings */}
              <div className="form-group">
                <label>Difficulty (1-5)</label>
                <div style={{ display: 'flex', gap: 4, marginTop: 4 }}>
                  {[1, 2, 3, 4, 5].map(d => (
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
                <label>Total Steps</label>
                <input className="form-input" type="number" value={form.total_steps} onChange={e => setForm({ ...form, total_steps: e.target.value })} />
                <small style={{ color: 'var(--text-muted)' }}>Auto-updates when you add steps</small>
              </div>
              <div className="form-group">
                <label>Duration (seconds)</label>
                <input className="form-input" type="number" value={form.duration_seconds} onChange={e => setForm({ ...form, duration_seconds: e.target.value })} />
                <small style={{ color: 'var(--text-muted)' }}>{Math.floor((parseInt(form.duration_seconds) || 0) / 60)} min</small>
              </div>
              <div className="form-group">
                <label>Display Order</label>
                <input className="form-input" type="number" value={form.display_order} onChange={e => setForm({ ...form, display_order: e.target.value })} />
              </div>
              <div className="form-group" style={{ display: 'flex', gap: 20, alignItems: 'center', gridColumn: '1/-1' }}>
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
              <button className="btn btn-primary" onClick={handleSave} disabled={!form.name}>
                {editing ? 'Save Changes' : 'Create Pose'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* App Preview */}
      {previewPose && (
        <AppPreview
          pose={previewPose}
          steps={previewSteps}
          linkedSession={previewPose.sessions}
          onClose={() => { setPreviewPose(null); setPreviewSteps([]); }}
        />
      )}
    </div>
  );
}

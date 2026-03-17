'use client';

import { useState, useEffect, useCallback } from 'react';
import { createClient } from '@/lib/supabase';
import { useParams } from 'next/navigation';
import Link from 'next/link';
import AppPreview from '@/components/AppPreview';
import MediaUploader from '@/components/MediaUploader';

export default function PoseStepsPage() {
  const { poseId } = useParams();
  const supabase = createClient();
  const [pose, setPose] = useState(null);
  const [steps, setSteps] = useState([]);
  const [loading, setLoading] = useState(true);
  const [showModal, setShowModal] = useState(false);
  const [showBulkModal, setShowBulkModal] = useState(false);
  const [editing, setEditing] = useState(null);
  const [bulkJson, setBulkJson] = useState('');
  const [showPreview, setShowPreview] = useState(false);

  const defaultForm = {
    step_number: 1, name: '', name_hindi: '',
    instruction: '', instruction_hindi: '',
    breathing: 'normal', mantra: '', duration_seconds: 10,
    image_url: '', animation_url: '', tips: '',
  };
  const [form, setForm] = useState(defaultForm);

  const fetchPose = useCallback(async () => {
    const { data } = await supabase.from('yoga_poses')
      .select('*, sessions!yoga_poses_linked_session_id_fkey(title, title_hindi)')
      .eq('id', poseId).single();
    setPose(data);
  }, [poseId]);

  const fetchSteps = useCallback(async () => {
    setLoading(true);
    const { data } = await supabase.from('pose_steps')
      .select('*').eq('pose_id', poseId)
      .order('step_number', { ascending: true });
    setSteps(data || []);
    setLoading(false);
  }, [poseId]);

  useEffect(() => { fetchPose(); fetchSteps(); }, [fetchPose, fetchSteps]);

  const openCreate = () => {
    setEditing(null);
    setForm({ ...defaultForm, step_number: steps.length + 1 });
    setShowModal(true);
  };

  const openEdit = (step) => {
    setEditing(step);
    setForm({
      step_number: step.step_number || 1, name: step.name || '',
      name_hindi: step.name_hindi || '',
      instruction: step.instruction || '', instruction_hindi: step.instruction_hindi || '',
      breathing: step.breathing || 'normal', mantra: step.mantra || '',
      duration_seconds: step.duration_seconds || 10,
      image_url: step.image_url || '', animation_url: step.animation_url || '',
      tips: Array.isArray(step.tips) ? step.tips.join('\n') : '',
    });
    setShowModal(true);
  };

  const handleSave = async () => {
    const payload = {
      pose_id: poseId,
      step_number: parseInt(form.step_number) || 1,
      name: form.name,
      name_hindi: form.name_hindi || null,
      instruction: form.instruction || null,
      instruction_hindi: form.instruction_hindi || null,
      breathing: form.breathing || 'normal',
      mantra: form.mantra || null,
      duration_seconds: parseInt(form.duration_seconds) || 10,
      image_url: form.image_url || null,
      animation_url: form.animation_url || null,
      tips: form.tips ? form.tips.split('\n').map(t => t.trim()).filter(Boolean) : [],
      display_order: parseInt(form.step_number) || 0,
    };

    if (editing) {
      const { error } = await supabase.from('pose_steps').update(payload).eq('id', editing.id);
      if (error) { alert('Error: ' + error.message); return; }
    } else {
      const { error } = await supabase.from('pose_steps').insert(payload);
      if (error) { alert('Error: ' + error.message); return; }
    }
    setShowModal(false);
    fetchSteps();
    // Update total_steps in yoga_poses
    const { data: updatedSteps } = await supabase.from('pose_steps').select('id').eq('pose_id', poseId);
    await supabase.from('yoga_poses').update({ total_steps: (updatedSteps || []).length }).eq('id', poseId);
    fetchPose();
  };

  const handleDelete = async (id, name) => {
    if (!confirm(`Delete step "${name}"?`)) return;
    await supabase.from('pose_steps').delete().eq('id', id);
    fetchSteps();
    // Update total_steps
    const { data: updatedSteps } = await supabase.from('pose_steps').select('id').eq('pose_id', poseId);
    await supabase.from('yoga_poses').update({ total_steps: (updatedSteps || []).length }).eq('id', poseId);
    fetchPose();
  };

  const handleBulkImport = async () => {
    try {
      const stepsData = JSON.parse(bulkJson);
      if (!Array.isArray(stepsData)) { alert('JSON must be an array of step objects'); return; }

      const payloads = stepsData.map((s, i) => ({
        pose_id: poseId,
        step_number: s.step_number || i + 1,
        name: s.name || `Step ${i + 1}`,
        name_hindi: s.name_hindi || null,
        instruction: s.instruction || null,
        instruction_hindi: s.instruction_hindi || null,
        breathing: s.breathing || 'normal',
        mantra: s.mantra || null,
        duration_seconds: s.duration_seconds || 10,
        image_url: s.image_url || null,
        animation_url: s.animation_url || null,
        tips: Array.isArray(s.tips) ? s.tips : [],
        display_order: s.step_number || i + 1,
      }));

      const { error } = await supabase.from('pose_steps').insert(payloads);
      if (error) { alert('Error: ' + error.message); return; }

      // Update total_steps
      const { data: allSteps } = await supabase.from('pose_steps').select('id').eq('pose_id', poseId);
      await supabase.from('yoga_poses').update({ total_steps: (allSteps || []).length }).eq('id', poseId);

      setShowBulkModal(false);
      setBulkJson('');
      fetchSteps();
      fetchPose();
    } catch (e) {
      alert('Invalid JSON: ' + e.message);
    }
  };

  const moveStep = async (step, direction) => {
    const idx = steps.findIndex(s => s.id === step.id);
    const targetIdx = idx + direction;
    if (targetIdx < 0 || targetIdx >= steps.length) return;

    const target = steps[targetIdx];
    // Swap step_numbers
    await supabase.from('pose_steps').update({ step_number: target.step_number, display_order: target.step_number }).eq('id', step.id);
    await supabase.from('pose_steps').update({ step_number: step.step_number, display_order: step.step_number }).eq('id', target.id);
    fetchSteps();
  };

  const breathingStyle = (b) => {
    const styles = {
      inhale: { bg: '#dbeafe', color: '#1d4ed8', icon: '💨↑', label: 'Inhale' },
      exhale: { bg: '#fce7f3', color: '#be185d', icon: '💨↓', label: 'Exhale' },
      hold: { bg: '#fef3c7', color: '#92400e', icon: '⏸️', label: 'Hold' },
      normal: { bg: '#f0fdf4', color: '#166534', icon: '🌿', label: 'Normal' },
    };
    return styles[b] || styles.normal;
  };

  const totalDuration = steps.reduce((sum, s) => sum + (s.duration_seconds || 10), 0);

  return (
    <div>
      <div className="page-header">
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <Link href="/sessions/yoga-poses" style={{ color: 'var(--text-muted)', textDecoration: 'none', fontSize: 13 }}>← Yoga Poses</Link>
          </div>
          <h1 style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
            📋 Steps: {pose?.name || 'Loading...'}
            {pose?.name_hindi && <span style={{ fontSize: 16, color: 'var(--text-muted)', fontWeight: 400 }}>({pose.name_hindi})</span>}
          </h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 4 }}>
            {steps.length} steps • Total: {Math.floor(totalDuration / 60)}m {totalDuration % 60}s
            {pose?.sessions && <> • Linked to: <strong>{pose.sessions.title}</strong></>}
          </p>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <button className="btn" onClick={() => setShowPreview(true)} style={{ background: '#7c3aed', color: '#fff' }}>📱 Preview in App</button>
          <button className="btn" onClick={() => setShowBulkModal(true)}>📥 Bulk Import</button>
          <button className="btn btn-primary" onClick={openCreate}>+ Add Step</button>
        </div>
      </div>

      {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading steps...</p> : (
        <>
          {steps.length === 0 ? (
            <div className="card" style={{ textAlign: 'center', padding: 60 }}>
              <div style={{ fontSize: 48, marginBottom: 16 }}>📋</div>
              <h3 style={{ color: 'var(--text-muted)', marginBottom: 8 }}>No steps yet</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: 13, marginBottom: 20 }}>
                Add steps to create a guided practice sequence. Each step will show in the Practice tab with timer, breathing animation, and TTS.
              </p>
              <div style={{ display: 'flex', gap: 12, justifyContent: 'center' }}>
                <button className="btn btn-primary" onClick={openCreate}>+ Add First Step</button>
                <button className="btn" onClick={() => setShowBulkModal(true)}>📥 Bulk Import JSON</button>
              </div>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {steps.map((step, idx) => {
                const bs = breathingStyle(step.breathing);
                return (
                  <div key={step.id} className="card" style={{ padding: 16, display: 'flex', gap: 16, alignItems: 'flex-start' }}>
                    {/* Step number & reorder */}
                    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 4, minWidth: 40 }}>
                      <button onClick={() => moveStep(step, -1)} disabled={idx === 0}
                        style={{ background: 'none', border: 'none', cursor: idx === 0 ? 'default' : 'pointer', opacity: idx === 0 ? 0.3 : 1, fontSize: 16 }}>▲</button>
                      <div style={{
                        width: 36, height: 36, borderRadius: '50%', display: 'flex', alignItems: 'center', justifyContent: 'center',
                        background: 'var(--accent)', color: '#fff', fontWeight: 700, fontSize: 14
                      }}>
                        {step.step_number}
                      </div>
                      <button onClick={() => moveStep(step, 1)} disabled={idx === steps.length - 1}
                        style={{ background: 'none', border: 'none', cursor: idx === steps.length - 1 ? 'default' : 'pointer', opacity: idx === steps.length - 1 ? 0.3 : 1, fontSize: 16 }}>▼</button>
                    </div>

                    {/* Content */}
                    <div style={{ flex: 1 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginBottom: 6 }}>
                        <span style={{ fontWeight: 700, fontSize: 15 }}>{step.name}</span>
                        {step.name_hindi && <span style={{ color: 'var(--text-muted)', fontSize: 13 }}>({step.name_hindi})</span>}
                        {/* Breathing badge */}
                        <span style={{
                          background: bs.bg, color: bs.color, padding: '2px 10px',
                          borderRadius: 12, fontSize: 11, fontWeight: 600,
                        }}>
                          {bs.icon} {bs.label}
                        </span>
                        {/* Duration */}
                        <span style={{ fontSize: 12, color: 'var(--text-muted)', fontWeight: 500 }}>⏱️ {step.duration_seconds}s</span>
                      </div>

                      {step.instruction && (
                        <p style={{ fontSize: 13, color: 'var(--text-secondary)', margin: '4px 0', lineHeight: 1.5 }}>
                          {step.instruction}
                        </p>
                      )}
                      {step.instruction_hindi && (
                        <p style={{ fontSize: 12, color: 'var(--text-muted)', margin: '2px 0', fontStyle: 'italic' }}>
                          {step.instruction_hindi}
                        </p>
                      )}

                      {/* Extra info row */}
                      <div style={{ display: 'flex', gap: 12, marginTop: 6, flexWrap: 'wrap' }}>
                        {step.mantra && (
                          <span style={{ fontSize: 12, color: '#7c3aed', background: '#ede9fe', padding: '2px 8px', borderRadius: 6 }}>
                            🕉️ {step.mantra}
                          </span>
                        )}
                        {step.tips && step.tips.length > 0 && (
                          <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                            💡 {step.tips.length} tip{step.tips.length > 1 ? 's' : ''}
                          </span>
                        )}
                        {step.image_url && <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>🖼️ Image</span>}
                        {step.animation_url && <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>🎬 Animation</span>}
                      </div>
                    </div>

                    {/* Actions */}
                    <div style={{ display: 'flex', gap: 6 }}>
                      <button className="btn btn-sm" onClick={() => openEdit(step)}>Edit</button>
                      <button className="btn btn-sm btn-danger" onClick={() => handleDelete(step.id, step.name)}>✕</button>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </>
      )}

      {/* Create/Edit Modal */}
      {showModal && (
        <div className="modal-overlay" onClick={() => setShowModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 700, maxHeight: '90vh', overflow: 'auto' }}>
            <h2>{editing ? `Edit Step #${editing.step_number}` : `Add Step #${form.step_number}`}</h2>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
              <div className="form-group">
                <label>Step Number *</label>
                <input className="form-input" type="number" value={form.step_number} onChange={e => setForm({ ...form, step_number: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Duration (seconds) *</label>
                <input className="form-input" type="number" value={form.duration_seconds} onChange={e => setForm({ ...form, duration_seconds: e.target.value })} />
              </div>
              <div className="form-group">
                <label>Name (English) *</label>
                <input className="form-input" value={form.name} onChange={e => setForm({ ...form, name: e.target.value })} placeholder="e.g. Pranamasana" />
              </div>
              <div className="form-group">
                <label>Name (Hindi)</label>
                <input className="form-input" value={form.name_hindi} onChange={e => setForm({ ...form, name_hindi: e.target.value })} placeholder="e.g. प्रणामासन" />
              </div>
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Instruction (English)</label>
                <textarea className="form-input" rows={3} value={form.instruction} onChange={e => setForm({ ...form, instruction: e.target.value })}
                  placeholder="Stand straight, join palms in front of chest..." />
              </div>
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Instruction (Hindi)</label>
                <textarea className="form-input" rows={3} value={form.instruction_hindi} onChange={e => setForm({ ...form, instruction_hindi: e.target.value })}
                  placeholder="सीधे खड़े हों, हाथों को छाती के सामने जोड़ें..." />
              </div>
              <div className="form-group">
                <label>Breathing *</label>
                <div style={{ display: 'flex', gap: 6, marginTop: 4 }}>
                  {['inhale', 'exhale', 'hold', 'normal'].map(b => {
                    const bs = breathingStyle(b);
                    const isSelected = form.breathing === b;
                    return (
                      <button key={b} type="button" onClick={() => setForm({ ...form, breathing: b })}
                        style={{
                          padding: '8px 14px', borderRadius: 8, border: isSelected ? `2px solid ${bs.color}` : '1px solid var(--border)',
                          background: isSelected ? bs.bg : 'transparent', color: bs.color, fontWeight: 600,
                          fontSize: 12, cursor: 'pointer', transition: 'all 0.2s',
                        }}>
                        {bs.icon} {bs.label}
                      </button>
                    );
                  })}
                </div>
              </div>
              <div className="form-group">
                <label>Mantra</label>
                <input className="form-input" value={form.mantra} onChange={e => setForm({ ...form, mantra: e.target.value })} placeholder="e.g. ॐ मित्राय नमः" />
              </div>
              <div className="form-group">
                <label>Image</label>
                <MediaUploader
                  bucket="session-media"
                  folder="poses"
                  accept="image/*"
                  label="Pose Image"
                  value={form.image_url}
                  onChange={(url) => setForm({ ...form, image_url: url })}
                />
              </div>
              <div className="form-group">
                <label>Animation (Lottie)</label>
                <MediaUploader
                  bucket="session-media"
                  folder="animations"
                  accept=".json,.lottie,application/json"
                  label="Lottie Animation"
                  value={form.animation_url}
                  onChange={(url) => setForm({ ...form, animation_url: url })}
                  showPreview={false}
                />
              </div>
              <div className="form-group" style={{ gridColumn: '1/-1' }}>
                <label>Tips (one per line)</label>
                <textarea className="form-input" rows={3} value={form.tips} onChange={e => setForm({ ...form, tips: e.target.value })}
                  placeholder={"Keep spine erect\nRelax shoulders\nBreathe deeply"} />
              </div>
            </div>

            <div style={{ display: 'flex', gap: 12, marginTop: 20, justifyContent: 'flex-end' }}>
              <button className="btn" onClick={() => setShowModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleSave} disabled={!form.name}>
                {editing ? 'Save Changes' : 'Add Step'}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Bulk Import Modal */}
      {showBulkModal && (
        <div className="modal-overlay" onClick={() => setShowBulkModal(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 700, maxHeight: '90vh', overflow: 'auto' }}>
            <h2>📥 Bulk Import Steps</h2>
            <p style={{ color: 'var(--text-muted)', fontSize: 13, marginBottom: 12 }}>
              Paste a JSON array of step objects. Each step should have at minimum: <code>name</code> and <code>step_number</code>.
            </p>

            <div className="form-group">
              <label>JSON Data</label>
              <textarea className="form-input" rows={15} value={bulkJson} onChange={e => setBulkJson(e.target.value)}
                style={{ fontFamily: 'monospace', fontSize: 12 }}
                placeholder={`[\n  {\n    "step_number": 1,\n    "name": "Pranamasana",\n    "name_hindi": "प्रणामासन",\n    "instruction": "Stand straight, join palms...",\n    "instruction_hindi": "सीधे खड़े हों...",\n    "breathing": "exhale",\n    "mantra": "ॐ मित्राय नमः",\n    "duration_seconds": 10,\n    "tips": ["Keep spine erect", "Relax shoulders"]\n  },\n  {\n    "step_number": 2,\n    "name": "Hasta Uttanasana",\n    "breathing": "inhale",\n    "duration_seconds": 10\n  }\n]`} />
            </div>

            <div style={{ display: 'flex', gap: 12, marginTop: 16, justifyContent: 'flex-end' }}>
              <button className="btn" onClick={() => setShowBulkModal(false)}>Cancel</button>
              <button className="btn btn-primary" onClick={handleBulkImport} disabled={!bulkJson.trim()}>
                Import Steps
              </button>
            </div>
          </div>
        </div>
      )}

      {/* App Preview */}
      {showPreview && pose && (
        <AppPreview
          pose={pose}
          steps={steps}
          linkedSession={pose.sessions}
          onClose={() => setShowPreview(false)}
        />
      )}
    </div>
  );
}

'use client';

import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function SettingsPage() {
    const [admins, setAdmins] = useState([]);
    const [loading, setLoading] = useState(true);
    const [currentUser, setCurrentUser] = useState(null);

    // AI Model Settings
    const [aiSettings, setAiSettings] = useState({
        vision_model: 'google/gemma-3-27b-it:free',
        image_gen_model: 'black-forest-labs/flux.2-flex',
        text_model: 'sarvam-105b',
        text_provider: 'sarvam',
    });
    const [aiSaving, setAiSaving] = useState(false);
    const [aiMsg, setAiMsg] = useState('');

    useEffect(() => { fetchData(); fetchAiSettings(); }, []);

    async function fetchData() {
        const supabase = createClient();
        const { data: { user } } = await supabase.auth.getUser();
        setCurrentUser(user);

        const { data } = await supabase
            .from('user_profiles')
            .select('id, full_name, email, is_admin, created_at')
            .eq('is_admin', true)
            .order('created_at', { ascending: true });
        setAdmins(data || []);
        setLoading(false);
    }

    async function fetchAiSettings() {
        try {
            const res = await fetch('/api/ai/settings');
            const data = await res.json();
            if (data.settings) setAiSettings(prev => ({ ...prev, ...data.settings }));
        } catch (err) {
            console.error('Failed to load AI settings:', err);
        }
    }

    async function saveAiSettings() {
        setAiSaving(true);
        setAiMsg('');
        try {
            const res = await fetch('/api/ai/settings', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ settings: aiSettings }),
            });
            const data = await res.json();
            if (data.success) {
                setAiMsg('✅ AI models updated successfully!');
            } else {
                setAiMsg(`❌ ${data.error || 'Failed to save'}`);
            }
        } catch (err) {
            setAiMsg(`❌ ${err.message}`);
        }
        setAiSaving(false);
        setTimeout(() => setAiMsg(''), 4000);
    }

    async function removeAdmin(userId) {
        if (userId === currentUser?.id) {
            alert('You cannot remove your own admin access!');
            return;
        }
        if (!confirm('Remove admin access for this user?')) return;
        const supabase = createClient();
        await supabase.from('user_profiles').update({ is_admin: false }).eq('id', userId);
        fetchData();
    }

    if (loading) return <div className="loading"><div className="spinner" /></div>;

    return (
        <div>
            <div className="page-header">
                <h1>Settings</h1>
                <p>Manage admin access and app configuration</p>
            </div>

            {/* ═══════ AI Model Configuration ═══════ */}
            <div className="card" style={{ borderColor: 'rgba(99,102,241,0.25)' }}>
                <div className="card-header">
                    <h3 style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span style={{ fontSize: 20 }}>🤖</span> AI Model Configuration
                    </h3>
                    <button
                        className="btn btn-primary btn-sm"
                        onClick={saveAiSettings}
                        disabled={aiSaving}
                        style={{ minWidth: 120 }}
                    >
                        {aiSaving ? '⏳ Saving...' : '💾 Save Models'}
                    </button>
                </div>

                {aiMsg && (
                    <div style={{
                        padding: '10px 16px', borderRadius: 10, marginBottom: 16, fontSize: 13, fontWeight: 600,
                        background: aiMsg.startsWith('✅') ? 'rgba(34,197,94,0.1)' : 'rgba(239,68,68,0.1)',
                        color: aiMsg.startsWith('✅') ? '#22c55e' : '#ef4444',
                        border: `1px solid ${aiMsg.startsWith('✅') ? 'rgba(34,197,94,0.25)' : 'rgba(239,68,68,0.25)'}`,
                    }}>
                        {aiMsg}
                    </div>
                )}

                <p style={{ fontSize: 12, color: 'var(--text-muted)', marginBottom: 20, lineHeight: 1.6 }}>
                    Configure AI models used by the content generator. OpenRouter updates free models regularly — 
                    update model IDs here when new versions are available on{' '}
                    <a href="https://openrouter.ai/models?q=free" target="_blank" rel="noopener noreferrer"
                        style={{ color: '#818cf8', textDecoration: 'underline' }}>openrouter.ai/models</a>.
                </p>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                    {/* Vision Model */}
                    <ModelField
                        label="📖 Vision Model (Literature from Images)"
                        description="Reads book page images → generates literature. Must support image input."
                        value={aiSettings.vision_model}
                        onChange={v => setAiSettings(s => ({ ...s, vision_model: v }))}
                        placeholder="e.g. google/gemma-3-27b-it:free"
                        tag="OpenRouter"
                        tagColor="#818cf8"
                    />

                    {/* Image Generation Model */}
                    <ModelField
                        label="🎨 Image Generation Model"
                        description="Generates illustrations for poses. Must support image output."
                        value={aiSettings.image_gen_model}
                        onChange={v => setAiSettings(s => ({ ...s, image_gen_model: v }))}
                        placeholder="e.g. black-forest-labs/flux.2-flex"
                        tag="OpenRouter"
                        tagColor="#818cf8"
                    />

                    {/* Text Model */}
                    <ModelField
                        label="✍️ Text Model (Descriptions, Steps)"
                        description="Generates text content without images. Used for descriptions, benefits, steps."
                        value={aiSettings.text_model}
                        onChange={v => setAiSettings(s => ({ ...s, text_model: v }))}
                        placeholder="e.g. sarvam-105b"
                        tag="Sarvam AI"
                        tagColor="#f59e0b"
                    />

                    {/* Text Provider */}
                    <ModelField
                        label="🔌 Text Model Provider"
                        description="API provider for text model. 'sarvam' or 'openrouter'."
                        value={aiSettings.text_provider}
                        onChange={v => setAiSettings(s => ({ ...s, text_provider: v }))}
                        placeholder="sarvam or openrouter"
                        tag="Provider"
                        tagColor="#6b7280"
                    />
                </div>
            </div>

            {/* Admin Users */}
            <div className="card">
                <div className="card-header">
                    <h3>👑 Admin Users</h3>
                    <span className="badge badge-warning">{admins.length} admins</span>
                </div>
                <div className="data-table-container">
                    <table className="data-table">
                        <thead>
                            <tr><th>Name</th><th>Email</th><th>Since</th><th>Actions</th></tr>
                        </thead>
                        <tbody>
                            {admins.map((admin) => (
                                <tr key={admin.id}>
                                    <td style={{ fontWeight: 500 }}>
                                        {admin.full_name || 'Unnamed'}
                                        {admin.id === currentUser?.id && (
                                            <span style={{ fontSize: '11px', color: 'var(--accent)', marginLeft: '8px' }}>(You)</span>
                                        )}
                                    </td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>{admin.email || '—'}</td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>{admin.created_at ? new Date(admin.created_at).toLocaleDateString() : '—'}</td>
                                    <td>
                                        {admin.id !== currentUser?.id && (
                                            <button className="btn btn-sm btn-danger" onClick={() => removeAdmin(admin.id)}>
                                                Remove Admin
                                            </button>
                                        )}
                                    </td>
                                </tr>
                            ))}
                            {admins.length === 0 && (
                                <tr><td colSpan={4} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>No admins configured</td></tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* App Info */}
            <div className="card">
                <div className="card-header">
                    <h3>ℹ️ App Information</h3>
                </div>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px' }}>
                    <InfoBox label="App Name" value="DinCharya" />
                    <InfoBox label="Platform" value="Flutter + Supabase" />
                    <InfoBox label="Supabase Project" value="djaevixaqvwtuizbadds" />
                    <InfoBox label="Dashboard Version" value="1.0.0" />
                </div>
            </div>

            {/* Danger Zone */}
            <div className="card" style={{ borderColor: 'rgba(239, 68, 68, 0.2)' }}>
                <div className="card-header">
                    <h3 style={{ color: 'var(--error)' }}>⚠️ Danger Zone</h3>
                </div>
                <p style={{ fontSize: '13px', color: 'var(--text-secondary)', marginBottom: '16px' }}>
                    These actions are destructive and cannot be undone. Proceed with caution.
                </p>
                <div style={{ display: 'flex', gap: '12px' }}>
                    <button className="btn btn-danger" onClick={() => alert('This feature is not implemented yet for safety.')}>
                        🗑️ Clear All Tracking Data
                    </button>
                    <button className="btn btn-danger" onClick={() => alert('This feature is not implemented yet for safety.')}>
                        🗑️ Clear All Journal Entries
                    </button>
                </div>
            </div>
        </div>
    );
}

function ModelField({ label, description, value, onChange, placeholder, tag, tagColor }) {
    const [localValue, setLocalValue] = useState(value);

    // Sync from parent only when external value changes (e.g. initial load)
    useEffect(() => {
        setLocalValue(value);
    }, [value]);

    return (
        <div style={{
            padding: 16, borderRadius: 12, border: '1px solid var(--border)',
            background: 'var(--bg-surface)', transition: 'border-color 0.2s',
        }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
                <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--text)' }}>{label}</div>
                <span style={{
                    fontSize: 10, fontWeight: 700, padding: '2px 8px', borderRadius: 6,
                    background: `${tagColor}22`, color: tagColor, textTransform: 'uppercase', letterSpacing: '0.03em',
                }}>{tag}</span>
            </div>
            <div style={{ fontSize: 11, color: 'var(--text-muted)', marginBottom: 10, lineHeight: 1.5 }}>{description}</div>
            <input
                type="text"
                value={localValue}
                onChange={e => setLocalValue(e.target.value)}
                onBlur={() => onChange(localValue)}
                placeholder={placeholder}
                style={{
                    width: '100%', padding: '9px 12px', borderRadius: 8, fontSize: 13,
                    border: '1px solid var(--border)', background: 'var(--bg)',
                    color: 'var(--text)', fontFamily: 'monospace', outline: 'none',
                }}
            />
        </div>
    );
}

function InfoBox({ label, value }) {
    return (
        <div style={{ padding: '14px', background: 'var(--bg-surface)', borderRadius: '8px' }}>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{label}</div>
            <div style={{ fontSize: '14px', fontWeight: 500 }}>{value}</div>
        </div>
    );
}

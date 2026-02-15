'use client';

import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function SettingsPage() {
    const [admins, setAdmins] = useState([]);
    const [loading, setLoading] = useState(true);
    const [currentUser, setCurrentUser] = useState(null);

    useEffect(() => { fetchData(); }, []);

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

function InfoBox({ label, value }) {
    return (
        <div style={{ padding: '14px', background: 'var(--bg-surface)', borderRadius: '8px' }}>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{label}</div>
            <div style={{ fontSize: '14px', fontWeight: 500 }}>{value}</div>
        </div>
    );
}

'use client';

import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function UsersPage() {
    const [users, setUsers] = useState([]);
    const [filtered, setFiltered] = useState([]);
    const [search, setSearch] = useState('');
    const [loading, setLoading] = useState(true);
    const [selectedUser, setSelectedUser] = useState(null);
    const [userDetails, setUserDetails] = useState(null);

    useEffect(() => {
        fetchUsers();
    }, []);

    useEffect(() => {
        if (search.trim() === '') {
            setFiltered(users);
        } else {
            const q = search.toLowerCase();
            setFiltered(
                users.filter(
                    (u) =>
                        (u.full_name || '').toLowerCase().includes(q) ||
                        (u.email || '').toLowerCase().includes(q)
                )
            );
        }
    }, [search, users]);

    async function fetchUsers() {
        const supabase = createClient();
        const { data } = await supabase
            .from('user_profiles')
            .select('*')
            .order('created_at', { ascending: false });
        setUsers(data || []);
        setFiltered(data || []);
        setLoading(false);
    }

    async function toggleAdmin(userId, currentStatus) {
        const supabase = createClient();
        await supabase
            .from('user_profiles')
            .update({ is_admin: !currentStatus })
            .eq('id', userId);
        fetchUsers();
    }

    async function viewUserDetails(user) {
        setSelectedUser(user);
        const supabase = createClient();

        const [
            { count: taskCount },
            { count: journalCount },
            { count: routineCount },
            { data: enrollments },
        ] = await Promise.all([
            supabase.from('local_tasks').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
            supabase.from('journal_entries').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
            supabase.from('routine_tracking').select('*', { count: 'exact', head: true }).eq('user_id', user.id),
            supabase.from('user_program_enrollments').select('*, programs(title)').eq('user_id', user.id),
        ]);

        setUserDetails({
            tasks: taskCount || 0,
            journals: journalCount || 0,
            routines: routineCount || 0,
            enrollments: enrollments || [],
        });
    }

    if (loading) {
        return <div className="loading"><div className="spinner" /></div>;
    }

    return (
        <div>
            <div className="page-header">
                <h1>User Management</h1>
                <p>{users.length} total users</p>
            </div>

            <div className="search-bar">
                <span className="search-icon">🔍</span>
                <input
                    type="text"
                    placeholder="Search by name or email..."
                    value={search}
                    onChange={(e) => setSearch(e.target.value)}
                />
            </div>

            <div className="card">
                <div className="data-table-container">
                    <table className="data-table">
                        <thead>
                            <tr>
                                <th>Name</th>
                                <th>Email</th>
                                <th>Role</th>
                                <th>Joined</th>
                                <th>Actions</th>
                            </tr>
                        </thead>
                        <tbody>
                            {filtered.map((user) => (
                                <tr key={user.id}>
                                    <td style={{ fontWeight: 500 }}>
                                        {user.full_name || 'Unnamed'}
                                    </td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
                                        {user.email || '—'}
                                    </td>
                                    <td>
                                        <span className={`badge ${user.is_admin ? 'badge-warning' : 'badge-default'}`}>
                                            {user.is_admin ? 'Admin' : 'User'}
                                        </span>
                                    </td>
                                    <td style={{ color: 'var(--text-secondary)', fontSize: '13px' }}>
                                        {user.created_at ? new Date(user.created_at).toLocaleDateString() : '—'}
                                    </td>
                                    <td>
                                        <div className="actions-cell">
                                            <button
                                                className="action-btn"
                                                title="View Details"
                                                onClick={() => viewUserDetails(user)}
                                            >
                                                👁️
                                            </button>
                                            <button
                                                className="action-btn"
                                                title={user.is_admin ? 'Remove Admin' : 'Make Admin'}
                                                onClick={() => toggleAdmin(user.id, user.is_admin)}
                                            >
                                                {user.is_admin ? '🔓' : '🔐'}
                                            </button>
                                        </div>
                                    </td>
                                </tr>
                            ))}
                            {filtered.length === 0 && (
                                <tr>
                                    <td colSpan={5} style={{ textAlign: 'center', padding: '32px', color: 'var(--text-muted)' }}>
                                        No users found
                                    </td>
                                </tr>
                            )}
                        </tbody>
                    </table>
                </div>
            </div>

            {/* User Detail Modal */}
            {selectedUser && (
                <div className="modal-overlay" onClick={() => { setSelectedUser(null); setUserDetails(null); }}>
                    <div className="modal" onClick={(e) => e.stopPropagation()}>
                        <div className="modal-header">
                            <h2>User Details</h2>
                            <button className="modal-close" onClick={() => { setSelectedUser(null); setUserDetails(null); }}>✕</button>
                        </div>
                        <div className="modal-body">
                            <div style={{ marginBottom: '20px' }}>
                                <h3 style={{ fontSize: '20px', marginBottom: '4px' }}>{selectedUser.full_name || 'Unnamed'}</h3>
                                <p style={{ color: 'var(--text-secondary)', fontSize: '14px' }}>{selectedUser.email || 'No email'}</p>
                            </div>

                            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '12px', marginBottom: '20px' }}>
                                <InfoItem label="User ID" value={selectedUser.id?.substring(0, 8) + '...'} />
                                <InfoItem label="Role" value={selectedUser.is_admin ? 'Admin' : 'User'} />
                                <InfoItem label="Joined" value={selectedUser.created_at ? new Date(selectedUser.created_at).toLocaleDateString() : '—'} />
                                <InfoItem label="Updated" value={selectedUser.updated_at ? new Date(selectedUser.updated_at).toLocaleDateString() : '—'} />
                            </div>

                            {userDetails ? (
                                <>
                                    <h4 style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '12px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Activity</h4>
                                    <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr 1fr', gap: '12px', marginBottom: '20px' }}>
                                        <MiniStat label="Tasks" value={userDetails.tasks} />
                                        <MiniStat label="Journals" value={userDetails.journals} />
                                        <MiniStat label="Routines" value={userDetails.routines} />
                                    </div>

                                    {userDetails.enrollments.length > 0 && (
                                        <>
                                            <h4 style={{ fontSize: '14px', color: 'var(--text-secondary)', marginBottom: '8px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Programs Enrolled</h4>
                                            {userDetails.enrollments.map((e, i) => (
                                                <div key={i} style={{ padding: '8px 12px', background: 'var(--bg-surface)', borderRadius: '6px', marginBottom: '6px', fontSize: '13px' }}>
                                                    {e.programs?.title || 'Unknown Program'}
                                                </div>
                                            ))}
                                        </>
                                    )}
                                </>
                            ) : (
                                <div className="loading" style={{ height: '100px' }}><div className="spinner" /></div>
                            )}
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

function InfoItem({ label, value }) {
    return (
        <div style={{ padding: '10px 12px', background: 'var(--bg-surface)', borderRadius: '8px' }}>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginBottom: '4px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>{label}</div>
            <div style={{ fontSize: '14px', fontWeight: 500 }}>{value}</div>
        </div>
    );
}

function MiniStat({ label, value }) {
    return (
        <div style={{ padding: '12px', background: 'var(--bg-surface)', borderRadius: '8px', textAlign: 'center' }}>
            <div style={{ fontSize: '24px', fontWeight: 700 }}>{value}</div>
            <div style={{ fontSize: '11px', color: 'var(--text-muted)', marginTop: '4px' }}>{label}</div>
        </div>
    );
}

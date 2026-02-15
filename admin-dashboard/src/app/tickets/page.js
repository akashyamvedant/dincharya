'use client';
import { useState, useEffect, useRef } from 'react';
import { createClient } from '@/lib/supabase';

export default function TicketsPage() {
    const supabase = createClient();
    const [tickets, setTickets] = useState([]);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('all');
    const [search, setSearch] = useState('');
    const [selected, setSelected] = useState(null);
    const [replies, setReplies] = useState([]);
    const [replyText, setReplyText] = useState('');
    const [sending, setSending] = useState(false);
    const chatEndRef = useRef(null);
    const pollRef = useRef(null);

    useEffect(() => { fetchTickets(); }, [filter, search]);

    // Real-time polling for replies when a ticket is selected
    useEffect(() => {
        if (selected) {
            pollRef.current = setInterval(() => { loadReplies(selected.id, true); }, 5000);
            return () => clearInterval(pollRef.current);
        }
        return () => clearInterval(pollRef.current);
    }, [selected?.id]);

    const fetchTickets = async () => {
        setLoading(true);
        try {
            let q = supabase.from('support_tickets')
                .select('*')
                .order('created_at', { ascending: false });
            if (filter !== 'all') q = q.eq('status', filter);
            if (search) q = q.or(`subject.ilike.%${search}%,email.ilike.%${search}%,message.ilike.%${search}%`);
            const { data, error } = await q;
            if (error) { console.error('Tickets fetch error:', error); setTickets([]); setLoading(false); return; }

            // Enrich with user profile names (no FK exists, so we fetch separately)
            const ticketsWithProfiles = data || [];
            const userIds = [...new Set(ticketsWithProfiles.map(t => t.user_id).filter(Boolean))];
            if (userIds.length > 0) {
                const { data: profiles } = await supabase.from('user_profiles')
                    .select('id, full_name, email, avatar_url')
                    .in('id', userIds);
                const profileMap = {};
                (profiles || []).forEach(p => { profileMap[p.id] = p; });
                ticketsWithProfiles.forEach(t => { t._profile = profileMap[t.user_id] || null; });
            }

            setTickets(ticketsWithProfiles);
        } catch (err) {
            console.error('Error fetching tickets:', err);
            setTickets([]);
        }
        setLoading(false);
    };

    const loadReplies = async (ticketId, silent = false) => {
        const { data } = await supabase
            .from('ticket_replies')
            .select('*')
            .eq('ticket_id', ticketId)
            .order('created_at', { ascending: true });
        setReplies(data || []);
        if (!silent) setTimeout(() => chatEndRef.current?.scrollIntoView({ behavior: 'smooth' }), 100);
    };

    const openTicket = async (ticket) => {
        setSelected(ticket);
        setReplyText('');
        await loadReplies(ticket.id);
    };

    const sendReply = async () => {
        if (!replyText.trim() || !selected) return;
        setSending(true);
        try {
            const { data: { user } } = await supabase.auth.getUser();
            // Insert reply as admin
            await supabase.from('ticket_replies').insert({
                ticket_id: selected.id,
                sender_type: 'admin',
                sender_id: user?.id,
                message: replyText.trim(),
            });

            // If ticket was 'open', move to 'in_progress'
            if (selected.status === 'open') {
                await supabase.from('support_tickets').update({
                    status: 'in_progress',
                    updated_at: new Date().toISOString(),
                }).eq('id', selected.id);
                setSelected({ ...selected, status: 'in_progress' });
            } else {
                // Always update updated_at
                await supabase.from('support_tickets').update({
                    updated_at: new Date().toISOString(),
                }).eq('id', selected.id);
            }

            setReplyText('');
            await loadReplies(selected.id);
            fetchTickets();
        } catch (err) {
            console.error('Error sending reply:', err);
        } finally {
            setSending(false);
        }
    };

    const updateStatus = async (ticketId, status) => {
        const update = { status, updated_at: new Date().toISOString() };
        if (status === 'resolved') update.resolved_at = new Date().toISOString();
        if (status === 'open') update.resolved_at = null;
        await supabase.from('support_tickets').update(update).eq('id', ticketId);
        if (selected?.id === ticketId) setSelected({ ...selected, status });
        fetchTickets();
    };

    const updatePriority = async (ticketId, priority) => {
        await supabase.from('support_tickets').update({
            priority, updated_at: new Date().toISOString(),
        }).eq('id', ticketId);
        if (selected?.id === ticketId) setSelected({ ...selected, priority });
        fetchTickets();
    };

    const stats = {
        total: tickets.length,
        open: tickets.filter(t => t.status === 'open').length,
        inProgress: tickets.filter(t => t.status === 'in_progress').length,
        resolved: tickets.filter(t => t.status === 'resolved').length,
        closed: tickets.filter(t => t.status === 'closed').length,
    };

    // Match Flutter app's category/status/priority configs
    const categoryConfig = {
        Bug: { emoji: '🐛', color: '#ef4444' },
        Feature: { emoji: '✨', color: '#f59e0b' },
        Account: { emoji: '👤', color: '#a855f7' },
        Subscription: { emoji: '💳', color: '#22c55e' },
        Other: { emoji: '📝', color: '#6b7280' },
        General: { emoji: '❓', color: '#3b82f6' },
    };

    const statusConfig = {
        open: { label: 'Open', color: '#f97316', icon: '🟠' },
        in_progress: { label: 'In Progress', color: '#3b82f6', icon: '🔵' },
        resolved: { label: 'Resolved', color: '#22c55e', icon: '✅' },
        closed: { label: 'Closed', color: '#6b7280', icon: '⬛' },
    };

    const priorityConfig = {
        low: { label: 'Low', color: '#22c55e' },
        medium: { label: 'Medium', color: '#f97316' },
        high: { label: 'High', color: '#ef4444' },
        urgent: { label: 'Urgent', color: '#991b1b' },
    };

    const timeAgo = (d) => {
        const diff = (Date.now() - new Date(d)) / 1000;
        if (diff < 60) return 'just now';
        if (diff < 3600) return `${Math.floor(diff / 60)}m ago`;
        if (diff < 86400) return `${Math.floor(diff / 3600)}h ago`;
        return `${Math.floor(diff / 86400)}d ago`;
    };
    const fullDate = (d) => new Date(d).toLocaleString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>Support Tickets</h1>
                    <p style={{ color: 'var(--text-muted)', marginTop: 4 }}>
                        {stats.open} open • {stats.inProgress} in progress • {stats.resolved} resolved
                    </p>
                </div>
            </div>

            {/* Stats */}
            <div className="stats-grid" style={{ marginBottom: 24 }}>
                {[
                    { label: 'Total', value: stats.total, color: 'var(--text-primary)' },
                    { label: 'Open', value: stats.open, color: '#f97316' },
                    { label: 'In Progress', value: stats.inProgress, color: '#3b82f6' },
                    { label: 'Resolved', value: stats.resolved, color: '#22c55e' },
                    { label: 'Closed', value: stats.closed, color: '#6b7280' },
                ].map(s => (
                    <div key={s.label} className="stat-card animate-in" style={{ textAlign: 'center' }}>
                        <div style={{ fontSize: 28, fontWeight: 800, color: s.color }}>{s.value}</div>
                        <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>{s.label}</div>
                    </div>
                ))}
            </div>

            {/* Filters */}
            <div style={{ display: 'flex', gap: 12, marginBottom: 24, flexWrap: 'wrap' }}>
                <input className="search-input" placeholder="Search subject, email, message..."
                    value={search} onChange={e => setSearch(e.target.value)} style={{ flex: 1, minWidth: 200 }} />
                <select className="form-input" value={filter} onChange={e => setFilter(e.target.value)} style={{ width: 160 }}>
                    <option value="all">All Status</option>
                    <option value="open">🟠 Open</option>
                    <option value="in_progress">🔵 In Progress</option>
                    <option value="resolved">✅ Resolved</option>
                    <option value="closed">⬛ Closed</option>
                </select>
            </div>

            {/* Main content */}
            <div style={{ display: 'grid', gridTemplateColumns: selected ? '380px 1fr' : '1fr', gap: 16 }}>
                {/* Ticket List */}
                <div className="card" style={{ padding: 0, overflow: 'hidden', maxHeight: selected ? '72vh' : 'none', overflowY: 'auto' }}>
                    {loading ? (
                        <p style={{ padding: 24, color: 'var(--text-muted)' }}>Loading tickets...</p>
                    ) : tickets.length === 0 ? (
                        <div style={{ textAlign: 'center', padding: '50px 20px', color: 'var(--text-muted)' }}>
                            <div style={{ fontSize: 40, marginBottom: 12 }}>🎫</div>
                            <p>No tickets found</p>
                        </div>
                    ) : (
                        tickets.map(t => {
                            const cat = categoryConfig[t.category] || categoryConfig.General;
                            const st = statusConfig[t.status] || statusConfig.open;
                            const pri = priorityConfig[t.priority] || priorityConfig.medium;
                            return (
                                <div key={t.id} onClick={() => openTicket(t)} style={{
                                    padding: '14px 18px', borderBottom: '1px solid var(--border-subtle)', cursor: 'pointer',
                                    background: selected?.id === t.id ? 'var(--bg-hover)' : 'transparent',
                                    transition: 'background 0.15s',
                                }}
                                    onMouseOver={e => { if (selected?.id !== t.id) e.currentTarget.style.background = 'var(--bg-surface)'; }}
                                    onMouseOut={e => { if (selected?.id !== t.id) e.currentTarget.style.background = 'transparent'; }}>
                                    {/* Row 1: Category icon + Subject + Time */}
                                    <div style={{ display: 'flex', alignItems: 'flex-start', gap: 10, marginBottom: 6 }}>
                                        <span style={{ fontSize: 18 }}>{cat.emoji}</span>
                                        <div style={{ flex: 1 }}>
                                            <div style={{ fontWeight: 600, fontSize: 13.5, marginBottom: 2 }}>{t.subject}</div>
                                            <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>
                                                {t._profile?.full_name || t.email}
                                            </div>
                                        </div>
                                        <span style={{ fontSize: 10, color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>{timeAgo(t.created_at)}</span>
                                    </div>
                                    {/* Row 2: Status + Category + Priority */}
                                    <div style={{ display: 'flex', gap: 6, alignItems: 'center', marginBottom: 4, paddingLeft: 28 }}>
                                        <span className={`badge ${t.status === 'open' ? 'badge-warning' : t.status === 'in_progress' ? 'badge-info' : t.status === 'resolved' ? 'badge-success' : ''}`}
                                            style={{ fontSize: 10 }}>{st.icon} {st.label}</span>
                                        <span className="badge" style={{ fontSize: 10 }}>{t.category}</span>
                                        <span style={{
                                            width: 8, height: 8, borderRadius: '50%', background: pri.color,
                                            marginLeft: 'auto', flexShrink: 0,
                                        }} title={`${pri.label} priority`} />
                                    </div>
                                    {/* Row 3: Message preview */}
                                    <p style={{ fontSize: 12, color: 'var(--text-muted)', margin: 0, paddingLeft: 28, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                                        {t.message?.substring(0, 100)}
                                    </p>
                                </div>
                            );
                        })
                    )}
                </div>

                {/* Conversation Panel */}
                {selected && (
                    <div className="card" style={{ display: 'flex', flexDirection: 'column', maxHeight: '72vh', padding: 0 }}>
                        {/* Header */}
                        <div style={{ padding: '16px 20px', borderBottom: '1px solid var(--border)', background: 'var(--bg-surface)' }}>
                            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 10 }}>
                                <div style={{ flex: 1 }}>
                                    <h3 style={{ fontSize: 15, fontWeight: 700, margin: 0, marginBottom: 4 }}>
                                        {(categoryConfig[selected.category] || categoryConfig.General).emoji} {selected.subject}
                                    </h3>
                                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                                        {selected._profile?.full_name || selected.email} • {fullDate(selected.created_at)}
                                    </div>
                                </div>
                                <button className="btn btn-sm btn-ghost" onClick={() => setSelected(null)} style={{ padding: '2px 8px' }}>✕</button>
                            </div>
                            {/* Controls: Status + Priority + Category */}
                            <div style={{ display: 'flex', gap: 8, alignItems: 'center', flexWrap: 'wrap' }}>
                                <div>
                                    <label style={{ fontSize: 9, color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Status</label>
                                    <select value={selected.status} onChange={e => updateStatus(selected.id, e.target.value)} style={{
                                        display: 'block', fontSize: 11, padding: '4px 8px', background: 'var(--bg-primary)',
                                        color: (statusConfig[selected.status] || statusConfig.open).color,
                                        border: `1px solid ${(statusConfig[selected.status] || statusConfig.open).color}33`,
                                        borderRadius: 6, cursor: 'pointer', fontWeight: 600, marginTop: 2,
                                    }}>
                                        <option value="open">🟠 Open</option>
                                        <option value="in_progress">🔵 In Progress</option>
                                        <option value="resolved">✅ Resolved</option>
                                        <option value="closed">⬛ Closed</option>
                                    </select>
                                </div>
                                <div>
                                    <label style={{ fontSize: 9, color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Priority</label>
                                    <select value={selected.priority || 'medium'} onChange={e => updatePriority(selected.id, e.target.value)} style={{
                                        display: 'block', fontSize: 11, padding: '4px 8px', background: 'var(--bg-primary)',
                                        color: (priorityConfig[selected.priority] || priorityConfig.medium).color,
                                        border: `1px solid ${(priorityConfig[selected.priority] || priorityConfig.medium).color}33`,
                                        borderRadius: 6, cursor: 'pointer', fontWeight: 600, marginTop: 2,
                                    }}>
                                        <option value="low">🟢 Low</option>
                                        <option value="medium">🟠 Medium</option>
                                        <option value="high">🔴 High</option>
                                        <option value="urgent">🔴🔴 Urgent</option>
                                    </select>
                                </div>
                                <div>
                                    <label style={{ fontSize: 9, color: 'var(--text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Category</label>
                                    <div style={{
                                        fontSize: 11, padding: '4px 8px', background: 'var(--bg-primary)',
                                        border: '1px solid var(--border)', borderRadius: 6, marginTop: 2,
                                        color: (categoryConfig[selected.category] || categoryConfig.General).color,
                                        fontWeight: 600,
                                    }}>
                                        {(categoryConfig[selected.category] || categoryConfig.General).emoji} {selected.category}
                                    </div>
                                </div>
                                {selected.updated_at && (
                                    <div style={{ marginLeft: 'auto', fontSize: 10, color: 'var(--text-muted)' }}>
                                        Updated: {timeAgo(selected.updated_at)}
                                    </div>
                                )}
                            </div>
                        </div>

                        {/* Chat Messages */}
                        <div style={{ flex: 1, overflowY: 'auto', padding: 20 }}>
                            {/* Original Message */}
                            <div style={{ marginBottom: 20 }}>
                                <div style={{ display: 'flex', gap: 10 }}>
                                    <div style={{
                                        width: 34, height: 34, borderRadius: '50%', flexShrink: 0,
                                        background: 'linear-gradient(135deg, #d4a574, #e8c89e)',
                                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                                        fontSize: 14, fontWeight: 700, color: '#000',
                                    }}>
                                        {(selected._profile?.full_name || selected.email || 'U')[0].toUpperCase()}
                                    </div>
                                    <div style={{ flex: 1 }}>
                                        <div style={{ fontSize: 12, fontWeight: 600 }}>
                                            {selected._profile?.full_name || selected.email}
                                            <span style={{ fontWeight: 400, color: 'var(--text-muted)', marginLeft: 8 }}>
                                                {fullDate(selected.created_at)}
                                            </span>
                                        </div>
                                        <div style={{
                                            marginTop: 6, padding: '12px 16px',
                                            background: 'var(--bg-surface)', borderRadius: '4px 14px 14px 14px',
                                            fontSize: 13, lineHeight: 1.7, border: '1px solid var(--border-subtle)',
                                        }}>
                                            {selected.message}
                                        </div>
                                    </div>
                                </div>
                            </div>

                            {/* Conversation divider */}
                            {replies.length > 0 && (
                                <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
                                    <div style={{ flex: 1, height: 1, background: 'var(--border-subtle)' }} />
                                    <span style={{ fontSize: 11, fontWeight: 600, color: 'var(--text-muted)' }}>
                                        Conversation ({replies.length})
                                    </span>
                                    <div style={{ flex: 1, height: 1, background: 'var(--border-subtle)' }} />
                                </div>
                            )}

                            {/* Replies */}
                            {replies.map(r => {
                                const isAdmin = r.sender_type === 'admin';
                                return (
                                    <div key={r.id} style={{ marginBottom: 16 }}>
                                        <div style={{ display: 'flex', gap: 10, flexDirection: isAdmin ? 'row-reverse' : 'row' }}>
                                            <div style={{
                                                width: 30, height: 30, borderRadius: '50%', flexShrink: 0,
                                                background: isAdmin ? 'linear-gradient(135deg, #22c55e, #16a34a)' : 'linear-gradient(135deg, #d4a574, #e8c89e)',
                                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                                fontSize: 12, fontWeight: 700, color: '#fff',
                                            }}>
                                                {isAdmin ? '🛡' : '👤'}
                                            </div>
                                            <div style={{ flex: 1, maxWidth: '75%' }}>
                                                <div style={{ fontSize: 11, fontWeight: 600, textAlign: isAdmin ? 'right' : 'left', marginBottom: 4 }}>
                                                    {isAdmin ? 'Support Team' : (selected._profile?.full_name || 'User')}
                                                    <span style={{ fontWeight: 400, color: 'var(--text-muted)', marginLeft: 8 }}>
                                                        {timeAgo(r.created_at)}
                                                    </span>
                                                </div>
                                                <div style={{
                                                    padding: '10px 14px', fontSize: 13, lineHeight: 1.6,
                                                    background: isAdmin ? 'rgba(34,197,94,0.1)' : 'var(--bg-surface)',
                                                    borderRadius: isAdmin ? '14px 4px 14px 14px' : '4px 14px 14px 14px',
                                                    border: isAdmin ? '1px solid rgba(34,197,94,0.2)' : '1px solid var(--border-subtle)',
                                                }}>
                                                    {r.message}
                                                </div>
                                            </div>
                                        </div>
                                    </div>
                                );
                            })}

                            {/* Waiting state — matches Flutter app */}
                            {replies.length === 0 && selected.status === 'open' && (
                                <div style={{
                                    textAlign: 'center', padding: '30px 20px', marginTop: 20,
                                    background: 'rgba(59,130,246,0.05)', borderRadius: 14,
                                    border: '1px solid rgba(59,130,246,0.1)',
                                }}>
                                    <div style={{ fontSize: 36, marginBottom: 8 }}>⏳</div>
                                    <div style={{ fontSize: 14, fontWeight: 700, marginBottom: 4 }}>Awaiting Response</div>
                                    <div style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                                        Reply below to start the conversation with the user
                                    </div>
                                </div>
                            )}

                            <div ref={chatEndRef} />
                        </div>

                        {/* Reply Input — only show if not closed/resolved, matching Flutter */}
                        {selected.status !== 'closed' && selected.status !== 'resolved' ? (
                            <div style={{ padding: '12px 20px', borderTop: '1px solid var(--border)', background: 'var(--bg-surface)' }}>
                                <div style={{ display: 'flex', gap: 8 }}>
                                    <textarea
                                        value={replyText}
                                        onChange={e => setReplyText(e.target.value)}
                                        placeholder="Reply as Support Team..."
                                        rows={2}
                                        onKeyDown={e => { if (e.key === 'Enter' && (e.metaKey || e.ctrlKey)) sendReply(); }}
                                        style={{
                                            flex: 1, padding: '10px 14px', background: 'var(--bg-primary)',
                                            border: '1px solid var(--border)', borderRadius: 10,
                                            color: 'var(--text-primary)', fontSize: 13, resize: 'vertical',
                                            outline: 'none', fontFamily: 'Inter, sans-serif',
                                        }}
                                    />
                                    <button
                                        className="btn btn-primary"
                                        onClick={sendReply}
                                        disabled={!replyText.trim() || sending}
                                        style={{ alignSelf: 'flex-end', padding: '10px 20px' }}
                                    >
                                        {sending ? '⏳' : '↗ Send'}
                                    </button>
                                </div>
                                <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 4 }}>
                                    Ctrl+Enter to send • User sees replies as "Support Team" • First reply auto-sets status to "In Progress"
                                </div>
                            </div>
                        ) : (
                            <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border)', background: 'var(--bg-surface)', textAlign: 'center' }}>
                                <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>
                                    Ticket is {selected.status === 'resolved' ? '✅ resolved' : '⬛ closed'} —
                                    <button onClick={() => updateStatus(selected.id, 'in_progress')}
                                        style={{ background: 'none', border: 'none', color: 'var(--accent)', cursor: 'pointer', fontWeight: 600, fontSize: 12, padding: '0 4px' }}>
                                        reopen
                                    </button>
                                    to reply
                                </span>
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
}

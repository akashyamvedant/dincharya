'use client';

import { useState, useEffect, useMemo } from 'react';
import { createClient } from '@/lib/supabase';

export default function SubscriptionsPage() {
    const supabase = createClient();
    const [tab, setTab] = useState('subscriptions');
    const [plans, setPlans] = useState([]);
    const [subs, setSubs] = useState([]);
    const [auditLog, setAuditLog] = useState([]);
    const [loading, setLoading] = useState(true);
    const [showPlanModal, setShowPlanModal] = useState(false);
    const [editingPlan, setEditingPlan] = useState(null);
    const [subDetail, setSubDetail] = useState(null);
    const [searchQuery, setSearchQuery] = useState('');
    const [statusFilter, setStatusFilter] = useState('all');
    const [typeFilter, setTypeFilter] = useState('all');
    const [planForm, setPlanForm] = useState({
        name: '', display_name: '', description: '', price_monthly: 0, price_yearly: 0,
        features: '', razorpay_plan_id_monthly: '', razorpay_plan_id_yearly: '', is_active: true,
    });

    useEffect(() => {
        fetchAll();
    }, []);

    const fetchAll = async () => {
        setLoading(true);
        try {
            const [plansRes, subsRes, auditRes] = await Promise.all([
                supabase.from('subscription_plans').select('*').order('price_monthly', { ascending: true }),
                supabase.from('subscriptions').select('*').order('created_at', { ascending: false }),
                supabase.from('payment_audit_log').select('*').order('created_at', { ascending: false }).limit(50),
            ]);
            if (plansRes.error) console.error('Plans fetch error:', plansRes.error);
            if (subsRes.error) console.error('Subs fetch error:', subsRes.error);
            if (auditRes.error) console.error('Audit fetch error:', auditRes.error);

            const allSubs = subsRes.data || [];
            const allAudit = auditRes.data || [];

            const allUserIds = [...new Set([
                ...allSubs.map(s => s.user_id),
                ...allAudit.map(a => a.user_id),
            ].filter(Boolean))];

            let profileMap = {};
            if (allUserIds.length > 0) {
                const { data: profiles } = await supabase.from('user_profiles')
                    .select('id, full_name, email, avatar_url')
                    .in('id', allUserIds);
                (profiles || []).forEach(p => { profileMap[p.id] = p; });
            }

            allSubs.forEach(s => { s._profile = profileMap[s.user_id] || null; });
            allAudit.forEach(a => { a._profile = profileMap[a.user_id] || null; });

            setPlans(plansRes.data || []);
            setSubs(allSubs);
            setAuditLog(allAudit);
        } catch (err) {
            console.error('Error fetching subscription data:', err);
        }
        setLoading(false);
    };

    // ── Compute the REAL status of a subscription ──
    const computeRealStatus = (sub) => {
        const now = new Date();
        if (sub.cancelled_at) return 'cancelled';
        if (sub.expires_at && new Date(sub.expires_at) < now) return 'expired';
        if (sub.expires_at) {
            const daysLeft = Math.ceil((new Date(sub.expires_at) - now) / 86400000);
            if (daysLeft <= 7 && daysLeft > 0) return 'expiring_soon';
        }
        if (sub.status === 'active') return 'active';
        return sub.status || 'unknown';
    };

    const getDaysLeft = (sub) => {
        if (!sub.expires_at) return null;
        return Math.ceil((new Date(sub.expires_at) - new Date()) / 86400000);
    };

    // ── Enriched subs with computed status ──
    const enrichedSubs = useMemo(() => {
        return subs.map(s => ({
            ...s,
            _realStatus: computeRealStatus(s),
            _daysLeft: getDaysLeft(s),
            _type: s.is_trial ? 'trial' : (s.amount > 0 ? 'paid' : 'free'),
        }));
    }, [subs]);

    // ── Filtered subscriptions ──
    const filteredSubs = useMemo(() => {
        let result = enrichedSubs;

        // Status filter
        if (statusFilter !== 'all') {
            result = result.filter(s => s._realStatus === statusFilter);
        }

        // Type filter
        if (typeFilter !== 'all') {
            result = result.filter(s => s._type === typeFilter);
        }

        // Search
        if (searchQuery.trim()) {
            const q = searchQuery.toLowerCase();
            result = result.filter(s =>
                (s._profile?.full_name || '').toLowerCase().includes(q) ||
                (s._profile?.email || '').toLowerCase().includes(q) ||
                (s.plan_name || '').toLowerCase().includes(q)
            );
        }

        return result;
    }, [enrichedSubs, statusFilter, typeFilter, searchQuery]);

    // ── Stats ──
    const stats = useMemo(() => {
        const now = new Date();
        const active = enrichedSubs.filter(s => s._realStatus === 'active');
        const expired = enrichedSubs.filter(s => s._realStatus === 'expired');
        const expiringSoon = enrichedSubs.filter(s => s._realStatus === 'expiring_soon');
        const trials = enrichedSubs.filter(s => s.is_trial);
        const activeTrials = trials.filter(s => s._realStatus === 'active' || s._realStatus === 'expiring_soon');
        const expiredTrials = trials.filter(s => s._realStatus === 'expired');
        const paid = enrichedSubs.filter(s => s._type === 'paid');
        const activePaid = paid.filter(s => s._realStatus === 'active' || s._realStatus === 'expiring_soon');
        const totalRevenue = paid.reduce((sum, s) => sum + (s.amount || 0), 0);
        const monthlyRevenue = activePaid.reduce((sum, s) => sum + (s.amount || 0), 0);
        const churnRate = enrichedSubs.length > 0 ? ((expired.length / enrichedSubs.length) * 100).toFixed(1) : '0';
        const trialConversion = trials.length > 0
            ? ((trials.filter(t => paid.some(p => p.user_id === t.user_id)).length / trials.length) * 100).toFixed(0)
            : '0';

        return {
            totalRevenue, monthlyRevenue,
            totalSubs: enrichedSubs.length,
            activeSubs: active.length + expiringSoon.length,
            expiredSubs: expired.length,
            expiringSoon: expiringSoon.length,
            totalTrials: trials.length,
            activeTrials: activeTrials.length,
            expiredTrials: expiredTrials.length,
            totalPaid: paid.length,
            activePaid: activePaid.length,
            churnRate, trialConversion,
        };
    }, [enrichedSubs]);

    // ── Status filter counts ──
    const filterCounts = useMemo(() => ({
        all: enrichedSubs.length,
        active: enrichedSubs.filter(s => s._realStatus === 'active').length,
        expiring_soon: enrichedSubs.filter(s => s._realStatus === 'expiring_soon').length,
        expired: enrichedSubs.filter(s => s._realStatus === 'expired').length,
        cancelled: enrichedSubs.filter(s => s._realStatus === 'cancelled').length,
    }), [enrichedSubs]);

    const typeCounts = useMemo(() => ({
        all: enrichedSubs.length,
        paid: enrichedSubs.filter(s => s._type === 'paid').length,
        trial: enrichedSubs.filter(s => s._type === 'trial').length,
        free: enrichedSubs.filter(s => s._type === 'free').length,
    }), [enrichedSubs]);

    // ── Plan CRUD ──
    const openPlanCreate = () => {
        setEditingPlan(null);
        setPlanForm({
            name: '', display_name: '', description: '', price_monthly: 0, price_yearly: 0,
            features: '', razorpay_plan_id_monthly: '', razorpay_plan_id_yearly: '', is_active: true,
        });
        setShowPlanModal(true);
    };

    const openPlanEdit = (p) => {
        setEditingPlan(p);
        setPlanForm({
            name: p.name || '', display_name: p.display_name || '', description: p.description || '',
            price_monthly: p.price_monthly || 0, price_yearly: p.price_yearly || 0,
            features: Array.isArray(p.features) ? p.features.join('\n') : '',
            razorpay_plan_id_monthly: p.razorpay_plan_id_monthly || '',
            razorpay_plan_id_yearly: p.razorpay_plan_id_yearly || '',
            is_active: p.is_active !== false,
        });
        setShowPlanModal(true);
    };

    const handlePlanSave = async () => {
        const payload = {
            ...planForm,
            price_monthly: parseInt(planForm.price_monthly) || 0,
            price_yearly: parseInt(planForm.price_yearly) || 0,
            features: planForm.features ? planForm.features.split('\n').map(f => f.trim()).filter(Boolean) : [],
        };
        if (editingPlan) {
            await supabase.from('subscription_plans').update(payload).eq('id', editingPlan.id);
        } else {
            await supabase.from('subscription_plans').insert(payload);
        }
        setShowPlanModal(false);
        fetchAll();
    };

    const formatPrice = (amount) => {
        if (!amount) return '₹0';
        return `₹${(amount / 100).toLocaleString('en-IN')}`;
    };

    const statusConfig = {
        active: { label: 'Active', color: '#22c55e', bg: 'rgba(34,197,94,0.12)', icon: '●' },
        expiring_soon: { label: 'Expiring Soon', color: '#f59e0b', bg: 'rgba(245,158,11,0.12)', icon: '◐' },
        expired: { label: 'Expired', color: '#ef4444', bg: 'rgba(239,68,68,0.12)', icon: '○' },
        cancelled: { label: 'Cancelled', color: '#94a3b8', bg: 'rgba(148,163,184,0.12)', icon: '✕' },
        unknown: { label: 'Unknown', color: '#64748b', bg: 'rgba(100,116,139,0.12)', icon: '?' },
    };

    const typeConfig = {
        paid: { label: 'Paid', color: '#a78bfa', bg: 'rgba(167,139,250,0.12)', icon: '💳' },
        trial: { label: 'Trial', color: '#60a5fa', bg: 'rgba(96,165,250,0.12)', icon: '🧪' },
        free: { label: 'Free', color: '#94a3b8', bg: 'rgba(148,163,184,0.12)', icon: '🎁' },
    };

    const StatusBadge = ({ status }) => {
        const cfg = statusConfig[status] || statusConfig.unknown;
        return (
            <span style={{
                display: 'inline-flex', alignItems: 'center', gap: 5,
                padding: '4px 10px', borderRadius: 20, fontSize: 12, fontWeight: 600,
                color: cfg.color, background: cfg.bg, border: `1px solid ${cfg.color}22`,
                letterSpacing: '0.02em',
            }}>
                <span style={{ fontSize: 8 }}>{cfg.icon}</span> {cfg.label}
            </span>
        );
    };

    const TypeBadge = ({ type }) => {
        const cfg = typeConfig[type] || typeConfig.free;
        return (
            <span style={{
                display: 'inline-flex', alignItems: 'center', gap: 4,
                padding: '4px 10px', borderRadius: 20, fontSize: 12, fontWeight: 600,
                color: cfg.color, background: cfg.bg,
            }}>
                {cfg.icon} {cfg.label}
            </span>
        );
    };

    // ── Filter Chip ──
    const FilterChip = ({ label, count, isActive, onClick, color }) => (
        <button onClick={onClick} style={{
            display: 'inline-flex', alignItems: 'center', gap: 6,
            padding: '7px 14px', borderRadius: 20, fontSize: 13, fontWeight: 600,
            border: isActive ? `2px solid ${color || 'var(--accent)'}` : '2px solid var(--border)',
            background: isActive ? `${color || 'var(--accent)'}15` : 'transparent',
            color: isActive ? (color || 'var(--accent)') : 'var(--text-muted)',
            cursor: 'pointer', transition: 'all 0.2s ease',
        }}>
            {label}
            {count > 0 && (
                <span style={{
                    background: isActive ? (color || 'var(--accent)') : 'var(--border)',
                    color: isActive ? '#fff' : 'var(--text-muted)',
                    padding: '1px 7px', borderRadius: 10, fontSize: 11, fontWeight: 700,
                    minWidth: 20, textAlign: 'center',
                }}>{count}</span>
            )}
        </button>
    );

    // ── Stat Card ──
    const StatCard = ({ icon, label, value, subtext, color, trend }) => (
        <div style={{
            background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 16,
            padding: '20px 18px', display: 'flex', flexDirection: 'column', gap: 4,
            position: 'relative', overflow: 'hidden', minWidth: 0,
        }}>
            <div style={{
                position: 'absolute', top: -20, right: -20, width: 80, height: 80,
                borderRadius: '50%', background: `${color}08`,
            }} />
            <div style={{ fontSize: 22, lineHeight: 1 }}>{icon}</div>
            <div style={{ fontSize: 28, fontWeight: 800, color: color || 'var(--text)', letterSpacing: '-0.02em', marginTop: 4 }}>
                {value}
            </div>
            <div style={{ fontSize: 12, color: 'var(--text-muted)', fontWeight: 500 }}>{label}</div>
            {subtext && <div style={{ fontSize: 11, color: color || 'var(--text-muted)', fontWeight: 600, marginTop: 2 }}>{subtext}</div>}
        </div>
    );

    return (
        <div>
            {/* ── Header ── */}
            <div className="page-header" style={{ marginBottom: 20 }}>
                <div>
                    <h1 style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <span style={{ fontSize: 28 }}>💎</span> Subscriptions & Revenue
                    </h1>
                    <p style={{ color: 'var(--text-muted)', marginTop: 4, fontSize: 14 }}>
                        {stats.totalSubs} total • {stats.activeSubs} active • {stats.expiredSubs} expired • {stats.totalTrials} trials
                    </p>
                </div>
            </div>

            {/* ── Top Stats Grid ── */}
            <div style={{
                display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(175px, 1fr))',
                gap: 14, marginBottom: 24,
            }}>
                <StatCard icon="💰" label="Total Revenue" value={formatPrice(stats.totalRevenue)} color="#22c55e"
                    subtext={`${formatPrice(stats.monthlyRevenue)} active MRR`} />
                <StatCard icon="🟢" label="Active Subs" value={stats.activeSubs} color="#22c55e"
                    subtext={`${stats.activePaid} paid + ${stats.activeTrials} trial`} />
                <StatCard icon="🔴" label="Expired" value={stats.expiredSubs} color="#ef4444"
                    subtext={`${stats.churnRate}% churn rate`} />
                <StatCard icon="⏳" label="Expiring Soon" value={stats.expiringSoon} color="#f59e0b"
                    subtext={stats.expiringSoon > 0 ? 'Within next 7 days' : 'All clear!'} />
                <StatCard icon="🧪" label="Trial Users" value={stats.totalTrials} color="#60a5fa"
                    subtext={`${stats.trialConversion}% converted to paid`} />
                <StatCard icon="💳" label="Paid Users" value={stats.totalPaid} color="#a78bfa"
                    subtext={`${stats.activePaid} currently active`} />
            </div>

            {/* ── Tabs ── */}
            <div style={{ display: 'flex', gap: 0, marginBottom: 20, borderBottom: '1px solid var(--border)' }}>
                {[
                    { key: 'subscriptions', label: `Subscriptions`, count: subs.length, icon: '📋' },
                    { key: 'plans', label: `Plans`, count: plans.length, icon: '📦' },
                    { key: 'audit', label: `Payment Audit`, count: auditLog.length, icon: '🔍' },
                ].map(t => (
                    <button key={t.key} onClick={() => setTab(t.key)} style={{
                        padding: '12px 20px', border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 14,
                        background: 'transparent',
                        borderBottom: tab === t.key ? '2px solid var(--accent)' : '2px solid transparent',
                        color: tab === t.key ? 'var(--accent)' : 'var(--text-muted)',
                        display: 'flex', alignItems: 'center', gap: 6, transition: 'all 0.2s',
                    }}>
                        <span style={{ fontSize: 15 }}>{t.icon}</span>
                        {t.label}
                        <span style={{
                            background: tab === t.key ? 'var(--accent)' : 'var(--border)',
                            color: tab === t.key ? '#fff' : 'var(--text-muted)',
                            padding: '1px 8px', borderRadius: 10, fontSize: 11, fontWeight: 700,
                        }}>{t.count}</span>
                    </button>
                ))}
            </div>

            {loading ? (
                <div style={{ textAlign: 'center', padding: 60 }}>
                    <div style={{ fontSize: 32, marginBottom: 12, animation: 'pulse 1.5s infinite' }}>⏳</div>
                    <p style={{ color: 'var(--text-muted)' }}>Loading subscriptions...</p>
                </div>
            ) : (
                <>
                    {/* ════════════════════════════ Subscriptions Tab ════════════════════════════ */}
                    {tab === 'subscriptions' && (
                        <div>
                            {/* ── Search + Filters Bar ── */}
                            <div style={{
                                background: 'var(--card)', border: '1px solid var(--border)', borderRadius: 14,
                                padding: '16px 20px', marginBottom: 16, display: 'flex', flexDirection: 'column', gap: 14,
                            }}>
                                {/* Search */}
                                <div style={{ position: 'relative' }}>
                                    <span style={{
                                        position: 'absolute', left: 12, top: '50%', transform: 'translateY(-50%)',
                                        fontSize: 16, opacity: 0.5,
                                    }}>🔍</span>
                                    <input
                                        type="text"
                                        placeholder="Search by name, email, or plan..."
                                        value={searchQuery}
                                        onChange={e => setSearchQuery(e.target.value)}
                                        style={{
                                            width: '100%', padding: '10px 14px 10px 38px', borderRadius: 10,
                                            border: '1px solid var(--border)', background: 'var(--bg)',
                                            color: 'var(--text)', fontSize: 14, outline: 'none',
                                        }}
                                    />
                                </div>

                                {/* Status Filters */}
                                <div>
                                    <div style={{ fontSize: 11, color: 'var(--text-muted)', fontWeight: 600, marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Status</div>
                                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                                        <FilterChip label="All" count={filterCounts.all} isActive={statusFilter === 'all'} onClick={() => setStatusFilter('all')} />
                                        <FilterChip label="Active" count={filterCounts.active} isActive={statusFilter === 'active'} onClick={() => setStatusFilter('active')} color="#22c55e" />
                                        <FilterChip label="Expiring Soon" count={filterCounts.expiring_soon} isActive={statusFilter === 'expiring_soon'} onClick={() => setStatusFilter('expiring_soon')} color="#f59e0b" />
                                        <FilterChip label="Expired" count={filterCounts.expired} isActive={statusFilter === 'expired'} onClick={() => setStatusFilter('expired')} color="#ef4444" />
                                        <FilterChip label="Cancelled" count={filterCounts.cancelled} isActive={statusFilter === 'cancelled'} onClick={() => setStatusFilter('cancelled')} color="#94a3b8" />
                                    </div>
                                </div>

                                {/* Type Filters */}
                                <div>
                                    <div style={{ fontSize: 11, color: 'var(--text-muted)', fontWeight: 600, marginBottom: 8, textTransform: 'uppercase', letterSpacing: '0.05em' }}>Type</div>
                                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                                        <FilterChip label="All Types" count={typeCounts.all} isActive={typeFilter === 'all'} onClick={() => setTypeFilter('all')} />
                                        <FilterChip label="💳 Paid" count={typeCounts.paid} isActive={typeFilter === 'paid'} onClick={() => setTypeFilter('paid')} color="#a78bfa" />
                                        <FilterChip label="🧪 Trial" count={typeCounts.trial} isActive={typeFilter === 'trial'} onClick={() => setTypeFilter('trial')} color="#60a5fa" />
                                        <FilterChip label="🎁 Free" count={typeCounts.free} isActive={typeFilter === 'free'} onClick={() => setTypeFilter('free')} color="#94a3b8" />
                                    </div>
                                </div>
                            </div>

                            {/* ── Results count ── */}
                            <div style={{ fontSize: 13, color: 'var(--text-muted)', marginBottom: 10, fontWeight: 500 }}>
                                Showing {filteredSubs.length} of {enrichedSubs.length} subscriptions
                            </div>

                            {/* ── Subscriptions Table ── */}
                            <div className="card" style={{ padding: 0, overflow: 'hidden', borderRadius: 14 }}>
                                <table className="data-table">
                                    <thead>
                                        <tr>
                                            <th>User</th>
                                            <th>Plan</th>
                                            <th>Amount</th>
                                            <th>Status</th>
                                            <th>Type</th>
                                            <th>Started</th>
                                            <th>Expires</th>
                                            <th>Actions</th>
                                        </tr>
                                    </thead>
                                    <tbody>
                                        {filteredSubs.map(s => (
                                            <tr key={s.id} style={{
                                                opacity: s._realStatus === 'expired' ? 0.65 : 1,
                                                transition: 'opacity 0.2s',
                                            }}>
                                                <td>
                                                    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                                                        <div style={{
                                                            width: 34, height: 34, borderRadius: '50%',
                                                            background: s._profile?.avatar_url ? 'transparent'
                                                                : `linear-gradient(135deg, ${s._type === 'paid' ? '#a78bfa' : '#60a5fa'}, ${s._type === 'paid' ? '#7c3aed' : '#3b82f6'})`,
                                                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                                                            color: '#fff', fontWeight: 700, fontSize: 14,
                                                            overflow: 'hidden', flexShrink: 0,
                                                        }}>
                                                            {s._profile?.avatar_url ? (
                                                                <img src={s._profile.avatar_url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                                            ) : (
                                                                (s._profile?.full_name || 'U').charAt(0).toUpperCase()
                                                            )}
                                                        </div>
                                                        <div style={{ minWidth: 0 }}>
                                                            <div style={{ fontWeight: 600, fontSize: 13, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                                                {s._profile?.full_name || 'Unknown User'}
                                                            </div>
                                                            <div style={{ fontSize: 11, color: 'var(--text-muted)', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                                                                {s._profile?.email || '—'}
                                                            </div>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td>
                                                    <div style={{ fontWeight: 600, fontSize: 13 }}>{s.plan_name}</div>
                                                </td>
                                                <td>
                                                    <span style={{
                                                        fontFamily: 'monospace', fontWeight: 700,
                                                        color: s.amount > 0 ? '#22c55e' : 'var(--text-muted)',
                                                    }}>
                                                        {formatPrice(s.amount)}
                                                    </span>
                                                </td>
                                                <td><StatusBadge status={s._realStatus} /></td>
                                                <td><TypeBadge type={s._type} /></td>
                                                <td style={{ fontSize: 12, color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                                                    {s.started_at ? new Date(s.started_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—'}
                                                </td>
                                                <td>
                                                    <div>
                                                        <div style={{ fontSize: 12, whiteSpace: 'nowrap' }}>
                                                            {s.expires_at ? new Date(s.expires_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' }) : '—'}
                                                        </div>
                                                        {s._daysLeft !== null && (
                                                            <div style={{
                                                                fontSize: 10, fontWeight: 700, marginTop: 2,
                                                                color: s._daysLeft <= 0 ? '#ef4444'
                                                                    : s._daysLeft <= 3 ? '#f97316'
                                                                    : s._daysLeft <= 7 ? '#f59e0b'
                                                                    : '#22c55e',
                                                            }}>
                                                                {s._daysLeft <= 0 ? `Expired ${Math.abs(s._daysLeft)}d ago` : `${s._daysLeft}d remaining`}
                                                            </div>
                                                        )}
                                                    </div>
                                                </td>
                                                <td>
                                                    <button className="btn btn-sm" onClick={() => setSubDetail(s)}
                                                        style={{ fontWeight: 600, fontSize: 12 }}>
                                                        View
                                                    </button>
                                                </td>
                                            </tr>
                                        ))}
                                    </tbody>
                                </table>
                                {filteredSubs.length === 0 && (
                                    <div style={{ textAlign: 'center', padding: '50px 20px' }}>
                                        <div style={{ fontSize: 40, marginBottom: 12 }}>🔎</div>
                                        <p style={{ color: 'var(--text-muted)', fontSize: 14, fontWeight: 500 }}>
                                            No subscriptions match your filters
                                        </p>
                                        <button onClick={() => { setStatusFilter('all'); setTypeFilter('all'); setSearchQuery(''); }}
                                            style={{
                                                marginTop: 12, padding: '8px 16px', borderRadius: 8, border: '1px solid var(--border)',
                                                background: 'transparent', color: 'var(--accent)', cursor: 'pointer', fontSize: 13, fontWeight: 600,
                                            }}>
                                            Clear all filters
                                        </button>
                                    </div>
                                )}
                            </div>
                        </div>
                    )}

                    {/* ════════════════════════════ Plans Tab ════════════════════════════ */}
                    {tab === 'plans' && (
                        <div>
                            <div style={{ marginBottom: 16, textAlign: 'right' }}>
                                <button className="btn btn-primary" onClick={openPlanCreate}>+ New Plan</button>
                            </div>
                            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 16 }}>
                                {plans.map(p => (
                                    <div key={p.id} className="card" style={{ position: 'relative', borderRadius: 16 }}>
                                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', marginBottom: 12 }}>
                                            <div>
                                                <h3 style={{ fontSize: 18, fontWeight: 700 }}>{p.display_name}</h3>
                                                <div style={{ fontSize: 12, color: 'var(--text-muted)', fontFamily: 'monospace' }}>{p.name}</div>
                                            </div>
                                            <span className={`badge ${p.is_active ? 'badge-success' : 'badge-error'}`}>
                                                {p.is_active ? 'Active' : 'Inactive'}
                                            </span>
                                        </div>
                                        {p.description && <p style={{ color: 'var(--text-secondary)', fontSize: 13, marginBottom: 12 }}>{p.description}</p>}
                                        <div style={{ display: 'flex', gap: 16, marginBottom: 12 }}>
                                            <div>
                                                <div style={{ fontSize: 24, fontWeight: 800 }}>{formatPrice(p.price_monthly)}</div>
                                                <div style={{ color: 'var(--text-muted)', fontSize: 11 }}>/ month</div>
                                            </div>
                                            {p.price_yearly > 0 && (
                                                <div>
                                                    <div style={{ fontSize: 24, fontWeight: 800, color: 'var(--accent)' }}>{formatPrice(p.price_yearly)}</div>
                                                    <div style={{ color: 'var(--text-muted)', fontSize: 11 }}>/ year</div>
                                                </div>
                                            )}
                                        </div>
                                        {Array.isArray(p.features) && p.features.length > 0 && (
                                            <ul style={{ paddingLeft: 18, margin: 0, marginBottom: 12 }}>
                                                {p.features.map((f, i) => (
                                                    <li key={i} style={{ color: 'var(--text-secondary)', fontSize: 13, marginBottom: 4 }}>✦ {f}</li>
                                                ))}
                                            </ul>
                                        )}
                                        <div style={{ display: 'flex', gap: 8 }}>
                                            {p.razorpay_plan_id_monthly && <span className="badge" style={{ fontSize: 10 }}>Razorpay Monthly</span>}
                                            {p.razorpay_plan_id_yearly && <span className="badge" style={{ fontSize: 10 }}>Razorpay Yearly</span>}
                                        </div>
                                        <div style={{ marginTop: 12, display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                                            <button className="btn btn-sm" onClick={() => openPlanEdit(p)}>Edit</button>
                                        </div>
                                    </div>
                                ))}
                            </div>
                        </div>
                    )}

                    {/* ════════════════════════════ Audit Tab ════════════════════════════ */}
                    {tab === 'audit' && (
                        <div className="card" style={{ padding: 0, overflow: 'hidden', borderRadius: 14 }}>
                            <table className="data-table">
                                <thead>
                                    <tr>
                                        <th>Time</th>
                                        <th>User</th>
                                        <th>Event</th>
                                        <th>Amount</th>
                                        <th>Status</th>
                                        <th>Payment ID</th>
                                        <th>Order ID</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    {auditLog.map(a => (
                                        <tr key={a.id}>
                                            <td style={{ fontSize: 12, color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                                                {new Date(a.created_at).toLocaleString('en-IN', { dateStyle: 'short', timeStyle: 'short' })}
                                            </td>
                                            <td>
                                                <div style={{ fontWeight: 600, fontSize: 13 }}>{a._profile?.full_name || '—'}</div>
                                                <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{a._profile?.email || ''}</div>
                                            </td>
                                            <td><span className="badge">{a.event_type}</span></td>
                                            <td style={{ fontFamily: 'monospace' }}>{a.amount ? formatPrice(a.amount) : '—'}</td>
                                            <td><span className={`badge ${a.status === 'success' ? 'badge-success' : a.status === 'failed' ? 'badge-error' : ''}`}>{a.status || '—'}</span></td>
                                            <td style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--text-muted)' }}>{a.razorpay_payment_id || '—'}</td>
                                            <td style={{ fontSize: 11, fontFamily: 'monospace', color: 'var(--text-muted)' }}>{a.razorpay_order_id || '—'}</td>
                                        </tr>
                                    ))}
                                </tbody>
                            </table>
                            {auditLog.length === 0 && <p style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>No payment events yet</p>}
                        </div>
                    )}
                </>
            )}

            {/* ════════════════════════════ Subscription Detail Modal ════════════════════════════ */}
            {subDetail && (
                <div className="modal-overlay" onClick={() => setSubDetail(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 600, borderRadius: 18 }}>
                        {/* Modal Header */}
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 20 }}>
                            <h2 style={{ display: 'flex', alignItems: 'center', gap: 10, margin: 0 }}>
                                <span style={{ fontSize: 24 }}>📄</span> Subscription Detail
                            </h2>
                            <button onClick={() => setSubDetail(null)} style={{
                                background: 'var(--border)', border: 'none', borderRadius: 8,
                                width: 32, height: 32, cursor: 'pointer', fontSize: 16, color: 'var(--text-muted)',
                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                            }}>✕</button>
                        </div>

                        {/* User Card */}
                        <div style={{
                            background: 'var(--bg)', border: '1px solid var(--border)', borderRadius: 14,
                            padding: 16, marginBottom: 16, display: 'flex', alignItems: 'center', gap: 14,
                        }}>
                            <div style={{
                                width: 48, height: 48, borderRadius: '50%',
                                background: subDetail._profile?.avatar_url ? 'transparent'
                                    : 'linear-gradient(135deg, #a78bfa, #7c3aed)',
                                display: 'flex', alignItems: 'center', justifyContent: 'center',
                                color: '#fff', fontWeight: 700, fontSize: 20,
                                overflow: 'hidden', flexShrink: 0,
                            }}>
                                {subDetail._profile?.avatar_url ? (
                                    <img src={subDetail._profile.avatar_url} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                                ) : (
                                    (subDetail._profile?.full_name || 'U').charAt(0).toUpperCase()
                                )}
                            </div>
                            <div>
                                <div style={{ fontWeight: 700, fontSize: 16 }}>{subDetail._profile?.full_name || 'Unknown'}</div>
                                <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>{subDetail._profile?.email || '—'}</div>
                            </div>
                        </div>

                        {/* Detail Grid */}
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
                            <DetailItem label="Plan" value={subDetail.plan_name} />
                            <DetailItem label="Amount" value={`${formatPrice(subDetail.amount)} ${subDetail.currency || ''}`} />
                            <DetailItem label="Real Status">
                                <StatusBadge status={computeRealStatus(subDetail)} />
                            </DetailItem>
                            <DetailItem label="Type">
                                <TypeBadge type={subDetail.is_trial ? 'trial' : (subDetail.amount > 0 ? 'paid' : 'free')} />
                            </DetailItem>
                            <DetailItem label="Started" value={subDetail.started_at ? new Date(subDetail.started_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—'} />
                            <DetailItem label="Expires" value={subDetail.expires_at ? new Date(subDetail.expires_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—'}
                                subtext={(() => {
                                    const d = getDaysLeft(subDetail);
                                    if (d === null) return null;
                                    return d <= 0 ? `Expired ${Math.abs(d)} days ago` : `${d} days remaining`;
                                })()}
                                subtextColor={(() => {
                                    const d = getDaysLeft(subDetail);
                                    return d <= 0 ? '#ef4444' : d <= 7 ? '#f59e0b' : '#22c55e';
                                })()}
                            />
                            {subDetail.is_trial && subDetail.trial_started_at && (
                                <>
                                    <DetailItem label="Trial Started" value={new Date(subDetail.trial_started_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })} />
                                    <DetailItem label="Trial Expires" value={subDetail.trial_expires_at ? new Date(subDetail.trial_expires_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' }) : '—'} />
                                </>
                            )}
                            {subDetail.razorpay_payment_id && (
                                <div style={{ gridColumn: '1/-1' }}>
                                    <DetailItem label="Razorpay Payment ID" value={subDetail.razorpay_payment_id} mono />
                                    {subDetail.razorpay_order_id && <DetailItem label="Razorpay Order ID" value={subDetail.razorpay_order_id} mono />}
                                </div>
                            )}
                            {subDetail.cancelled_at && (
                                <DetailItem label="Cancelled At" value={new Date(subDetail.cancelled_at).toLocaleString('en-IN', { dateStyle: 'medium', timeStyle: 'short' })} />
                            )}
                            <DetailItem label="DB Status (raw)" value={subDetail.status} mono />
                        </div>
                    </div>
                </div>
            )}

            {/* ════════════════════════════ Plan Modal ════════════════════════════ */}
            {showPlanModal && (
                <div className="modal-overlay" onClick={() => setShowPlanModal(false)}>
                    <div className="modal" onClick={e => e.stopPropagation()} style={{ borderRadius: 18 }}>
                        <h2>{editingPlan ? 'Edit Plan' : 'Create Plan'}</h2>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                            <div className="form-group">
                                <label>Plan Name (internal)</label>
                                <input className="form-input" value={planForm.name} onChange={e => setPlanForm({ ...planForm, name: e.target.value })} placeholder="e.g. premium_monthly" />
                            </div>
                            <div className="form-group">
                                <label>Display Name</label>
                                <input className="form-input" value={planForm.display_name} onChange={e => setPlanForm({ ...planForm, display_name: e.target.value })} placeholder="e.g. Premium Plan" />
                            </div>
                            <div className="form-group" style={{ gridColumn: '1/-1' }}>
                                <label>Description</label>
                                <textarea className="form-input" rows={2} value={planForm.description} onChange={e => setPlanForm({ ...planForm, description: e.target.value })} />
                            </div>
                            <div className="form-group">
                                <label>Monthly Price (paise)</label>
                                <input className="form-input" type="number" value={planForm.price_monthly} onChange={e => setPlanForm({ ...planForm, price_monthly: e.target.value })} />
                                <small style={{ color: 'var(--text-muted)' }}>{formatPrice(planForm.price_monthly)}</small>
                            </div>
                            <div className="form-group">
                                <label>Yearly Price (paise)</label>
                                <input className="form-input" type="number" value={planForm.price_yearly} onChange={e => setPlanForm({ ...planForm, price_yearly: e.target.value })} />
                                <small style={{ color: 'var(--text-muted)' }}>{formatPrice(planForm.price_yearly)}</small>
                            </div>
                            <div className="form-group">
                                <label>Razorpay Monthly Plan ID</label>
                                <input className="form-input" value={planForm.razorpay_plan_id_monthly} onChange={e => setPlanForm({ ...planForm, razorpay_plan_id_monthly: e.target.value })} />
                            </div>
                            <div className="form-group">
                                <label>Razorpay Yearly Plan ID</label>
                                <input className="form-input" value={planForm.razorpay_plan_id_yearly} onChange={e => setPlanForm({ ...planForm, razorpay_plan_id_yearly: e.target.value })} />
                            </div>
                            <div className="form-group" style={{ gridColumn: '1/-1' }}>
                                <label>Features (one per line)</label>
                                <textarea className="form-input" rows={4} value={planForm.features} onChange={e => setPlanForm({ ...planForm, features: e.target.value })} placeholder="Ad-free experience&#10;Unlimited AI guide&#10;Premium sessions" />
                            </div>
                            <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' }}>
                                <input type="checkbox" checked={planForm.is_active} onChange={e => setPlanForm({ ...planForm, is_active: e.target.checked })} />
                                Active Plan
                            </label>
                        </div>
                        <div style={{ display: 'flex', gap: 12, marginTop: 20, justifyContent: 'flex-end' }}>
                            <button className="btn" onClick={() => setShowPlanModal(false)}>Cancel</button>
                            <button className="btn btn-primary" onClick={handlePlanSave}>
                                {editingPlan ? 'Save Changes' : 'Create Plan'}
                            </button>
                        </div>
                    </div>
                </div>
            )}
        </div>
    );
}

// ── Helper Component ──
function DetailItem({ label, value, children, mono, subtext, subtextColor }) {
    return (
        <div style={{ marginBottom: 4 }}>
            <div style={{ fontSize: 11, color: 'var(--text-muted)', fontWeight: 600, textTransform: 'uppercase', letterSpacing: '0.04em', marginBottom: 4 }}>
                {label}
            </div>
            {children || (
                <div style={{
                    fontSize: 14, fontWeight: 500,
                    fontFamily: mono ? 'monospace' : 'inherit',
                    wordBreak: 'break-all',
                }}>
                    {value}
                </div>
            )}
            {subtext && (
                <div style={{ fontSize: 11, color: subtextColor || 'var(--text-muted)', fontWeight: 600, marginTop: 2 }}>
                    {subtext}
                </div>
            )}
        </div>
    );
}

'use client';

import { useState, useEffect } from 'react';
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

            // Enrich with user profiles (no FK exists, fetch separately)
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

    // Plan CRUD
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

    const statusColor = (status) => {
        const map = { active: 'badge-success', cancelled: 'badge-error', expired: 'badge-error', paused: 'badge-warning' };
        return map[status] || '';
    };

    const stats = {
        totalRevenue: subs.reduce((s, sub) => s + (sub.amount || 0), 0),
        activeSubs: subs.filter(s => s.status === 'active').length,
        trials: subs.filter(s => s.is_trial).length,
        expiringSoon: subs.filter(s => {
            if (s.status !== 'active' || !s.expires_at) return false;
            const days = Math.ceil((new Date(s.expires_at) - new Date()) / 86400000);
            return days <= 7 && days > 0;
        }).length,
    };

    return (
        <div>
            <div className="page-header">
                <div>
                    <h1>Subscriptions & Revenue</h1>
                    <p style={{ color: 'var(--text-muted)', marginTop: 4 }}>
                        {subs.length} total subscriptions • {stats.activeSubs} active • {stats.trials} trials
                    </p>
                </div>
            </div>

            {/* Stats */}
            <div className="stats-grid" style={{ marginBottom: 24 }}>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800, color: 'var(--accent)' }}>{formatPrice(stats.totalRevenue)}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Total Revenue</div>
                </div>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800, color: '#4ade80' }}>{stats.activeSubs}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Active Subs</div>
                </div>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800, color: '#60a5fa' }}>{stats.trials}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Active Trials</div>
                </div>
                <div className="card" style={{ textAlign: 'center' }}>
                    <div style={{ fontSize: 28, fontWeight: 800, color: stats.expiringSoon > 0 ? '#f97316' : 'var(--text-muted)' }}>{stats.expiringSoon}</div>
                    <div style={{ color: 'var(--text-muted)', fontSize: 13 }}>Expiring Soon</div>
                </div>
            </div>

            {/* Tabs */}
            <div style={{ display: 'flex', gap: 0, marginBottom: 24, borderBottom: '1px solid var(--border)' }}>
                {[
                    { key: 'subscriptions', label: `Subscriptions (${subs.length})` },
                    { key: 'plans', label: `Plans (${plans.length})` },
                    { key: 'audit', label: `Payment Audit (${auditLog.length})` },
                ].map(t => (
                    <button key={t.key} onClick={() => setTab(t.key)} style={{
                        padding: '12px 24px', border: 'none', cursor: 'pointer', fontWeight: 600, fontSize: 14,
                        background: 'transparent', borderBottom: tab === t.key ? '2px solid var(--accent)' : '2px solid transparent',
                        color: tab === t.key ? 'var(--accent)' : 'var(--text-muted)',
                    }}>{t.label}</button>
                ))}
            </div>

            {loading ? <p style={{ color: 'var(--text-muted)' }}>Loading...</p> : (
                <>
                    {/* Subscriptions Tab */}
                    {tab === 'subscriptions' && (
                        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
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
                                    {subs.map(s => {
                                        const daysLeft = s.expires_at ? Math.ceil((new Date(s.expires_at) - new Date()) / 86400000) : null;
                                        return (
                                            <tr key={s.id}>
                                                <td>
                                                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                                                        {s._profile?.avatar_url && (
                                                            <img src={s._profile.avatar_url} alt="" style={{ width: 28, height: 28, borderRadius: '50%' }} />
                                                        )}
                                                        <div>
                                                            <div style={{ fontWeight: 600, fontSize: 13 }}>{s._profile?.full_name || 'Unknown'}</div>
                                                            <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{s._profile?.email || ''}</div>
                                                        </div>
                                                    </div>
                                                </td>
                                                <td style={{ fontWeight: 600 }}>{s.plan_name}</td>
                                                <td style={{ fontFamily: 'monospace' }}>{formatPrice(s.amount)}</td>
                                                <td><span className={`badge ${statusColor(s.status)}`}>{s.status}</span></td>
                                                <td>
                                                    {s.is_trial ? (
                                                        <span className="badge" style={{ background: 'rgba(96,165,250,0.15)', color: '#60a5fa' }}>🧪 Trial</span>
                                                    ) : (
                                                        <span className="badge">Paid</span>
                                                    )}
                                                </td>
                                                <td style={{ fontSize: 12, color: 'var(--text-muted)' }}>{s.started_at ? new Date(s.started_at).toLocaleDateString('en-IN') : '—'}</td>
                                                <td>
                                                    <div style={{ fontSize: 12 }}>
                                                        {s.expires_at ? new Date(s.expires_at).toLocaleDateString('en-IN') : '—'}
                                                        {daysLeft !== null && daysLeft > 0 && (
                                                            <div style={{ fontSize: 10, color: daysLeft <= 7 ? '#f97316' : 'var(--text-muted)' }}>
                                                                {daysLeft}d left
                                                            </div>
                                                        )}
                                                        {daysLeft !== null && daysLeft <= 0 && (
                                                            <div style={{ fontSize: 10, color: '#ef4444' }}>Expired</div>
                                                        )}
                                                    </div>
                                                </td>
                                                <td>
                                                    <button className="btn btn-sm" onClick={() => setSubDetail(s)}>View</button>
                                                </td>
                                            </tr>
                                        );
                                    })}
                                </tbody>
                            </table>
                            {subs.length === 0 && <p style={{ textAlign: 'center', padding: 40, color: 'var(--text-muted)' }}>No subscriptions yet</p>}
                        </div>
                    )}

                    {/* Plans Tab */}
                    {tab === 'plans' && (
                        <div>
                            <div style={{ marginBottom: 16, textAlign: 'right' }}>
                                <button className="btn btn-primary" onClick={openPlanCreate}>+ New Plan</button>
                            </div>
                            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(300px, 1fr))', gap: 16 }}>
                                {plans.map(p => (
                                    <div key={p.id} className="card" style={{ position: 'relative' }}>
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

                    {/* Audit Tab */}
                    {tab === 'audit' && (
                        <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
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

            {/* Subscription Detail Modal */}
            {subDetail && (
                <div className="modal-overlay" onClick={() => setSubDetail(null)}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
                        <h2>Subscription Detail</h2>
                        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 16 }}>
                            <div><strong style={{ color: 'var(--text-muted)' }}>User</strong><br />{subDetail._profile?.full_name || 'Unknown'}</div>
                            <div><strong style={{ color: 'var(--text-muted)' }}>Email</strong><br />{subDetail._profile?.email || '—'}</div>
                            <div><strong style={{ color: 'var(--text-muted)' }}>Plan</strong><br />{subDetail.plan_name} ({subDetail.plan_id})</div>
                            <div><strong style={{ color: 'var(--text-muted)' }}>Amount</strong><br />{formatPrice(subDetail.amount)} {subDetail.currency}</div>
                            <div><strong style={{ color: 'var(--text-muted)' }}>Status</strong><br /><span className={`badge ${statusColor(subDetail.status)}`}>{subDetail.status}</span></div>
                            <div><strong style={{ color: 'var(--text-muted)' }}>Type</strong><br />{subDetail.is_trial ? '🧪 Free Trial' : '💳 Paid'}</div>
                            <div><strong style={{ color: 'var(--text-muted)' }}>Started</strong><br />{subDetail.started_at ? new Date(subDetail.started_at).toLocaleString('en-IN') : '—'}</div>
                            <div><strong style={{ color: 'var(--text-muted)' }}>Expires</strong><br />{subDetail.expires_at ? new Date(subDetail.expires_at).toLocaleString('en-IN') : '—'}</div>
                            {subDetail.is_trial && subDetail.trial_started_at && (
                                <>
                                    <div><strong style={{ color: 'var(--text-muted)' }}>Trial Started</strong><br />{new Date(subDetail.trial_started_at).toLocaleString('en-IN')}</div>
                                    <div><strong style={{ color: 'var(--text-muted)' }}>Trial Expires</strong><br />{subDetail.trial_expires_at ? new Date(subDetail.trial_expires_at).toLocaleString('en-IN') : '—'}</div>
                                </>
                            )}
                            {subDetail.razorpay_payment_id && (
                                <div style={{ gridColumn: '1/-1' }}>
                                    <strong style={{ color: 'var(--text-muted)' }}>Razorpay IDs</strong><br />
                                    <span style={{ fontFamily: 'monospace', fontSize: 12 }}>
                                        Payment: {subDetail.razorpay_payment_id} | Order: {subDetail.razorpay_order_id || '—'}
                                    </span>
                                </div>
                            )}
                            {subDetail.cancelled_at && (
                                <div><strong style={{ color: 'var(--text-muted)' }}>Cancelled At</strong><br />{new Date(subDetail.cancelled_at).toLocaleString('en-IN')}</div>
                            )}
                        </div>
                        <div style={{ marginTop: 20, textAlign: 'right' }}>
                            <button className="btn" onClick={() => setSubDetail(null)}>Close</button>
                        </div>
                    </div>
                </div>
            )}

            {/* Plan Modal */}
            {showPlanModal && (
                <div className="modal-overlay" onClick={() => setShowPlanModal(false)}>
                    <div className="modal" onClick={e => e.stopPropagation()}>
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
                                <textarea className="form-input" rows={4} value={planForm.features} onChange={e => setPlanForm({ ...planForm, features: e.target.value })} placeholder="Ad-free experience\nUnlimited AI guide\nPremium sessions" />
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

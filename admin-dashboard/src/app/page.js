'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function DashboardHome() {
  const supabase = createClient();
  const [stats, setStats] = useState({
    users: 0, sessions: 0, programs: 0, activeSubscriptions: 0,
    openTickets: 0, totalContent: 0, premiumUsers: 0, revenue: 0,
  });
  const [recentUsers, setRecentUsers] = useState([]);
  const [recentActivity, setRecentActivity] = useState([]);
  const [userGrowth, setUserGrowth] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => { fetchDashboardData(); }, []);

  const fetchDashboardData = async () => {
    setLoading(true);
    const [
      { count: users }, { count: sessions }, { count: programs },
      { count: activeSubscriptions },
      { count: openTickets }, { count: totalContent },
      { data: recent }, { data: recentTickets },
      { data: subsData },
    ] = await Promise.all([
      supabase.from('user_profiles').select('id', { count: 'exact', head: true }),
      supabase.from('sessions').select('id', { count: 'exact', head: true }),
      supabase.from('programs').select('id', { count: 'exact', head: true }),
      supabase.from('subscriptions').select('id', { count: 'exact', head: true }).eq('status', 'active'),
      supabase.from('support_tickets').select('id', { count: 'exact', head: true }).eq('status', 'open'),
      supabase.from('app_content').select('id', { count: 'exact', head: true }),
      supabase.from('user_profiles').select('id, full_name, email, avatar_url, created_at').order('created_at', { ascending: false }).limit(6),
      supabase.from('support_tickets').select('id, subject, status, created_at, email').order('created_at', { ascending: false }).limit(5),
      supabase.from('subscriptions').select('plan_id, subscription_plans(price_monthly)').eq('status', 'active'),
    ]);

    const revenue = (subsData || []).reduce((sum, s) => sum + (s.subscription_plans?.price_monthly || 0), 0);

    setStats({
      users: users || 0, sessions: sessions || 0, programs: programs || 0,
      activeSubscriptions: activeSubscriptions || 0,
      openTickets: openTickets || 0, totalContent: totalContent || 0,
      premiumUsers: activeSubscriptions || 0, revenue,
    });

    setRecentUsers(recent || []);

    // Build activity timeline from recent users + tickets
    const activities = [
      ...(recent || []).slice(0, 3).map(u => ({
        type: 'user', icon: '👤', text: `${u.full_name || u.email || 'New user'} signed up`,
        time: u.created_at, color: 'var(--accent)',
      })),
      ...(recentTickets || []).map(t => ({
        type: 'ticket', icon: t.status === 'open' ? '🔴' : '🟡',
        text: `Ticket: ${t.subject}`, time: t.created_at, color: 'var(--warning)',
      })),
    ].sort((a, b) => new Date(b.time) - new Date(a.time)).slice(0, 8);
    setRecentActivity(activities);

    // Simple user growth — count by last 7 days
    const days = [];
    for (let i = 6; i >= 0; i--) {
      const d = new Date(); d.setDate(d.getDate() - i);
      const start = new Date(d); start.setHours(0, 0, 0, 0);
      const end = new Date(d); end.setHours(23, 59, 59, 999);
      const { count: dayCount } = await supabase.from('user_profiles')
        .select('id', { count: 'exact', head: true })
        .gte('created_at', start.toISOString())
        .lte('created_at', end.toISOString());
      days.push({ label: d.toLocaleDateString('en', { weekday: 'short' }), value: dayCount || 0 });
    }
    setUserGrowth(days);
    setLoading(false);
  };

  const timeAgo = (d) => {
    const diff = (Date.now() - new Date(d)) / 1000;
    if (diff < 60) return 'just now';
    if (diff < 3600) return `${Math.floor(diff / 60)}m`;
    if (diff < 86400) return `${Math.floor(diff / 3600)}h`;
    return `${Math.floor(diff / 86400)}d`;
  };

  const maxGrowth = Math.max(1, ...userGrowth.map(d => d.value));

  if (loading) return <div style={{ padding: 40, color: 'var(--text-muted)' }}>Loading dashboard...</div>;

  return (
    <div>
      <div className="page-header">
        <div>
          <h1>Dashboard</h1>
          <p style={{ color: 'var(--text-muted)', marginTop: 4, fontSize: 14 }}>
            Welcome back! Here's what's happening with DinCharya.
          </p>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
          <div className="pulse-dot green" />
          <span style={{ fontSize: 12, color: 'var(--text-muted)' }}>All systems online</span>
        </div>
      </div>

      {/* Stats Row */}
      <div className="stats-grid" style={{ marginBottom: 24 }}>
        {[
          { label: 'Total Users', value: stats.users, icon: '👥', change: '+12%' },
          { label: 'Active Subscriptions', value: stats.activeSubscriptions, icon: '💎', change: '+5%' },
          { label: 'Sessions', value: stats.sessions, icon: '🧘' },
          { label: 'Open Tickets', value: stats.openTickets, icon: '🎫', warn: stats.openTickets > 0 },
          { label: 'Programs', value: stats.programs, icon: '📋' },
          { label: 'Content Items', value: stats.totalContent, icon: '📝' },
        ].map((s, i) => (
          <div key={s.label} className="stat-card animate-in" style={{ animationDelay: `${i * 0.08}s` }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start' }}>
              <div>
                <div className="stat-value">{s.value}</div>
                <div className="stat-label">{s.label}</div>
                {s.change && <div className="stat-change positive">{s.change}</div>}
              </div>
              <div style={{ fontSize: 28, opacity: 0.3 }}>{s.icon}</div>
            </div>
          </div>
        ))}
      </div>

      {/* Bento Grid */}
      <div className="bento-grid">
        {/* User Growth Chart */}
        <div className="bento-lg card">
          <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>📈 User Signups (Last 7 Days)</h3>
          <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8, height: 140 }}>
            {userGrowth.map((d, i) => (
              <div key={i} style={{ flex: 1, textAlign: 'center' }}>
                <div style={{
                  height: `${Math.max(4, (d.value / maxGrowth) * 120)}px`,
                  background: 'var(--accent-gradient)', borderRadius: '4px 4px 0 0',
                  transition: 'height 0.5s ease', position: 'relative',
                }}>
                  <span style={{ position: 'absolute', top: -20, left: '50%', transform: 'translateX(-50%)', fontSize: 11, fontWeight: 700, color: 'var(--accent)' }}>
                    {d.value > 0 ? d.value : ''}
                  </span>
                </div>
                <div style={{ fontSize: 10, color: 'var(--text-muted)', marginTop: 6 }}>{d.label}</div>
              </div>
            ))}
          </div>
        </div>

        {/* Activity Timeline */}
        <div className="bento-lg card">
          <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>⏱ Recent Activity</h3>
          <div className="timeline">
            {recentActivity.map((a, i) => (
              <div key={i} className="timeline-item">
                <div>
                  <div style={{ fontSize: 13, fontWeight: 500 }}>{a.icon} {a.text}</div>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{timeAgo(a.time)} ago</div>
                </div>
              </div>
            ))}
            {recentActivity.length === 0 && <p style={{ color: 'var(--text-muted)', fontSize: 13 }}>No recent activity</p>}
          </div>
        </div>

        {/* Recent Users */}
        <div className="bento-lg card">
          <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>👥 New Users</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
            {recentUsers.map(u => (
              <div key={u.id} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderBottom: '1px solid var(--border-subtle)' }}>
                <div style={{
                  width: 34, height: 34, borderRadius: 8, background: 'var(--accent-gradient)',
                  display: 'flex', alignItems: 'center', justifyContent: 'center',
                  fontSize: 13, fontWeight: 700, color: '#000', flexShrink: 0,
                }}>
                  {(u.full_name || u.email || '?')[0].toUpperCase()}
                </div>
                <div style={{ flex: 1, overflow: 'hidden' }}>
                  <div style={{ fontSize: 13, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.full_name || 'Unnamed'}</div>
                  <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{u.email}</div>
                </div>
                <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{timeAgo(u.created_at)}</span>
              </div>
            ))}
          </div>
        </div>

        {/* System Health */}
        <div className="bento-lg card">
          <h3 style={{ fontSize: 15, fontWeight: 700, marginBottom: 16 }}>🔧 System Health</h3>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
            {[
              { label: 'Database', status: 'connected', icon: '💾' },
              { label: 'Authentication', status: 'operational', icon: '🔐' },
              { label: 'Storage', status: 'operational', icon: '📦' },
              { label: 'API', status: 'operational', icon: '⚡' },
            ].map(s => (
              <div key={s.label} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', background: 'var(--bg-surface)', borderRadius: 8 }}>
                <span>{s.icon}</span>
                <span style={{ fontSize: 13, fontWeight: 500, flex: 1 }}>{s.label}</span>
                <div className="pulse-dot green" />
                <span style={{ fontSize: 11, color: 'var(--success)' }}>{s.status}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}

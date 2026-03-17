'use client';
import { usePathname } from 'next/navigation';
import Link from 'next/link';
import { createClient } from '@/lib/supabase';
import { useRouter } from 'next/navigation';
import { useState, useEffect } from 'react';

const navItems = [
    { href: '/', label: 'Dashboard', icon: '📊' },
    { href: '/users', label: 'Users', icon: '👥' },
    { href: '/sessions', label: 'Sessions', icon: '🧘' },
    { href: '/sessions/yoga-poses', label: 'Yoga Poses', icon: '🪷' },
    { href: '/programs', label: 'Programs', icon: '📋' },
    { href: '/subscriptions', label: 'Subscriptions', icon: '💎' },
    { href: '/content', label: 'Content', icon: '📝' },
    { href: '/tickets', label: 'Tickets', icon: '🎫', badgeKey: 'openTickets' },
    { href: '/analytics', label: 'Analytics', icon: '📈' },
    { href: '/routines', label: 'Routines', icon: '⏰' },
    { href: '/journals', label: 'Journals', icon: '📓' },
    { href: '/emails', label: 'Emails', icon: '📧' },
    { href: '/settings', label: 'Settings', icon: '⚙️' },
];

export default function Sidebar({ onSearchOpen }) {
    const pathname = usePathname();
    const router = useRouter();
    const supabase = createClient();
    const [collapsed, setCollapsed] = useState(false);
    const [badges, setBadges] = useState({});
    const [user, setUser] = useState(null);

    useEffect(() => {
        (async () => {
            const { data: { user: u } } = await supabase.auth.getUser();
            setUser(u);
            const { count } = await supabase.from('support_tickets').select('id', { count: 'exact', head: true }).eq('status', 'open');
            setBadges({ openTickets: count || 0 });
        })();
    }, [pathname]);

    const handleSignOut = async () => {
        await supabase.auth.signOut();
        router.push('/login');
    };

    return (
        <aside className={`sidebar ${collapsed ? 'collapsed' : ''}`}>
            <div className="sidebar-header">
                <div className="sidebar-logo">D</div>
                <span className="sidebar-logo-text">DinCharya</span>
                <button onClick={() => setCollapsed(!collapsed)} className="btn-ghost" style={{ marginLeft: 'auto', padding: '4px 8px', fontSize: 14, border: 'none', cursor: 'pointer', background: 'transparent', color: 'var(--text-muted)' }}>
                    {collapsed ? '→' : '←'}
                </button>
            </div>

            {/* Search trigger */}
            <div style={{ padding: '10px 10px 0' }}>
                <button onClick={onSearchOpen} style={{
                    width: '100%', padding: collapsed ? '10px' : '8px 14px', borderRadius: 8, border: '1px solid var(--border)',
                    background: 'var(--bg-surface)', color: 'var(--text-muted)', cursor: 'pointer',
                    display: 'flex', alignItems: 'center', gap: 8, fontSize: 13, transition: 'all 0.2s',
                }}>
                    <span>🔍</span>
                    {!collapsed && <><span>Search...</span><span style={{ marginLeft: 'auto', fontSize: 10, padding: '1px 6px', border: '1px solid var(--border)', borderRadius: 4 }}>⌘K</span></>}
                </button>
            </div>

            <nav className="sidebar-nav">
                {navItems.map(item => (
                    <Link key={item.href} href={item.href} className={
                        (item.href === '/' ? pathname === '/' : pathname === item.href || (item.href !== '/sessions' && pathname.startsWith(item.href + '/')))
                        ? 'active' : ''
                    }>
                        <span className="nav-icon">{item.icon}</span>
                        <span className="sidebar-label">{item.label}</span>
                        {item.badgeKey && badges[item.badgeKey] > 0 && (
                            <span className="nav-badge">{badges[item.badgeKey]}</span>
                        )}
                    </Link>
                ))}
            </nav>

            <div className="sidebar-footer">
                <div className="sidebar-user-avatar">
                    {user?.email?.[0]?.toUpperCase() || '?'}
                </div>
                <div className="sidebar-user-info" style={{ flex: 1, overflow: 'hidden' }}>
                    <div style={{ fontSize: 12, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                        {user?.email || 'Admin'}
                    </div>
                    <div style={{ fontSize: 10, color: 'var(--text-muted)' }}>Administrator</div>
                </div>
                <button onClick={handleSignOut} className="btn-ghost" style={{ padding: '6px 8px', fontSize: 14, border: 'none', cursor: 'pointer', background: 'transparent', color: 'var(--text-muted)', borderRadius: 6 }}
                    title="Sign Out">🚪</button>
            </div>
        </aside>
    );
}

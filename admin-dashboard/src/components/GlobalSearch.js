'use client';
import { useState, useEffect, useRef, useCallback } from 'react';
import { useRouter } from 'next/navigation';
import { createClient } from '@/lib/supabase';

const pages = [
    { name: 'Dashboard', path: '/', icon: '📊' },
    { name: 'Users', path: '/users', icon: '👥' },
    { name: 'Sessions', path: '/sessions', icon: '🧘' },
    { name: 'Programs', path: '/programs', icon: '📋' },
    { name: 'Subscriptions', path: '/subscriptions', icon: '💎' },
    { name: 'Content', path: '/content', icon: '📝' },
    { name: 'Tickets', path: '/tickets', icon: '🎫' },
    { name: 'Analytics', path: '/analytics', icon: '📈' },
    { name: 'Routines', path: '/routines', icon: '⏰' },
    { name: 'Journals', path: '/journals', icon: '📓' },
    { name: 'Settings', path: '/settings', icon: '⚙️' },
];

export default function GlobalSearch({ isOpen, onClose }) {
    const router = useRouter();
    const supabase = createClient();
    const inputRef = useRef(null);
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [focused, setFocused] = useState(0);

    useEffect(() => {
        if (isOpen) { setQuery(''); setResults([]); setFocused(0); setTimeout(() => inputRef.current?.focus(), 50); }
    }, [isOpen]);

    useEffect(() => {
        const handler = (e) => { if ((e.metaKey || e.ctrlKey) && e.key === 'k') { e.preventDefault(); onClose?.('toggle'); } };
        window.addEventListener('keydown', handler);
        return () => window.removeEventListener('keydown', handler);
    }, [onClose]);

    const search = useCallback(async (q) => {
        if (!q.trim()) { setResults(pages.map(p => ({ ...p, type: 'page' }))); return; }
        const term = q.toLowerCase();
        const pageResults = pages.filter(p => p.name.toLowerCase().includes(term)).map(p => ({ ...p, type: 'page' }));

        const [users, sessions, tickets] = await Promise.all([
            supabase.from('user_profiles').select('id, full_name, email').or(`full_name.ilike.%${q}%,email.ilike.%${q}%`).limit(4),
            supabase.from('sessions').select('id, title, category').ilike('title', `%${q}%`).limit(4),
            supabase.from('support_tickets').select('id, subject, status').or(`subject.ilike.%${q}%,email.ilike.%${q}%`).limit(4),
        ]);

        const all = [
            ...pageResults,
            ...(users.data || []).map(u => ({ name: u.full_name || u.email, path: '/users', icon: '👤', type: 'user', meta: u.email })),
            ...(sessions.data || []).map(s => ({ name: s.title, path: '/sessions', icon: '🧘', type: 'session', meta: s.category })),
            ...(tickets.data || []).map(t => ({ name: t.subject, path: '/tickets', icon: '🎫', type: 'ticket', meta: t.status })),
        ];
        setResults(all);
        setFocused(0);
    }, []);

    useEffect(() => { const t = setTimeout(() => search(query), 200); return () => clearTimeout(t); }, [query, search]);

    const handleSelect = (item) => { router.push(item.path); onClose?.(); };
    const handleKeyDown = (e) => {
        if (e.key === 'ArrowDown') { e.preventDefault(); setFocused(f => Math.min(f + 1, results.length - 1)); }
        if (e.key === 'ArrowUp') { e.preventDefault(); setFocused(f => Math.max(f - 1, 0)); }
        if (e.key === 'Enter' && results[focused]) { handleSelect(results[focused]); }
        if (e.key === 'Escape') onClose?.();
    };

    if (!isOpen) return null;
    return (
        <div className="search-overlay" onClick={onClose}>
            <div className="search-dialog" onClick={e => e.stopPropagation()}>
                <input ref={inputRef} value={query} onChange={e => setQuery(e.target.value)} onKeyDown={handleKeyDown}
                    placeholder="Search pages, users, sessions, tickets..." />
                <div className="search-results">
                    {results.map((r, i) => (
                        <div key={`${r.type}-${r.name}-${i}`} className={`search-result-item ${i === focused ? 'focused' : ''}`}
                            onClick={() => handleSelect(r)} onMouseEnter={() => setFocused(i)}>
                            <span className="result-icon">{r.icon}</span>
                            <span className="result-label">{r.name}</span>
                            {r.meta && <span className="result-meta">{r.meta}</span>}
                            <span className="result-meta" style={{ opacity: 0.5 }}>{r.type}</span>
                        </div>
                    ))}
                    {results.length === 0 && query && <div style={{ padding: 20, textAlign: 'center', color: 'var(--text-muted)', fontSize: 13 }}>No results found</div>}
                </div>
            </div>
        </div>
    );
}

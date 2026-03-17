'use client';
import { useState, useEffect } from 'react';
import { createClient } from '@/lib/supabase';

export default function EmailsPage() {
  const supabase = createClient();
  const [tab, setTab] = useState('compose');
  const [loading, setLoading] = useState(false);
  const [users, setUsers] = useState([]);
  const [history, setHistory] = useState([]);
  const [historyLoading, setHistoryLoading] = useState(true);

  // Compose state
  const [subject, setSubject] = useState('');
  const [body, setBody] = useState('');
  const [ctaText, setCtaText] = useState('');
  const [ctaUrl, setCtaUrl] = useState('');
  const [selectMode, setSelectMode] = useState('all');
  const [selectedUsers, setSelectedUsers] = useState([]);
  const [sending, setSending] = useState(false);
  const [result, setResult] = useState(null);
  const [showPreview, setShowPreview] = useState(false);

  useEffect(() => { fetchUsers(); fetchHistory(); }, []);

  const fetchUsers = async () => {
    const { data } = await supabase.from('user_profiles').select('id, full_name, email').order('created_at', { ascending: false });
    setUsers(data || []);
  };

  const fetchHistory = async () => {
    setHistoryLoading(true);
    const { data } = await supabase.from('email_broadcasts').select('*').order('created_at', { ascending: false }).limit(50);
    setHistory(data || []);
    setHistoryLoading(false);
  };

  const getRecipients = () => {
    if (selectMode === 'all') return users.map(u => ({ email: u.email, name: u.full_name || '' }));
    return selectedUsers.map(uid => {
      const u = users.find(x => x.id === uid);
      return u ? { email: u.email, name: u.full_name || '' } : null;
    }).filter(Boolean);
  };

  const toggleUser = (uid) => {
    setSelectedUsers(prev => prev.includes(uid) ? prev.filter(x => x !== uid) : [...prev, uid]);
  };

  const handleSend = async () => {
    const recipients = getRecipients();
    if (!subject.trim()) return alert('Subject is required');
    if (!body.trim()) return alert('Message body is required');
    if (recipients.length === 0) return alert('No recipients selected');
    if (!confirm(`Send email to ${recipients.length} user(s)?`)) return;

    setSending(true);
    setResult(null);
    try {
      const { data: { session } } = await supabase.auth.getSession();
      const res = await fetch(`${process.env.NEXT_PUBLIC_SUPABASE_URL}/functions/v1/send-email`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${session?.access_token}`,
        },
        body: JSON.stringify({ subject, body, recipients, ctaText: ctaText || undefined, ctaUrl: ctaUrl || undefined }),
      });
      const data = await res.json();
      if (data.success) {
        const msg = `✅ ${data.sent} email(s) sent successfully${data.failed > 0 ? ` · ${data.failed} failed` : ''}`;
        setResult({ type: 'success', message: msg });
        setSubject(''); setBody(''); setCtaText(''); setCtaUrl('');
        setSelectedUsers([]);
        fetchHistory();
      } else {
        // Show detailed error from Resend API
        const errorMsg = data.firstError || data.error || 'Unknown error';
        const failedEmails = data.details?.filter(d => !d.success)?.map(d => d.email).join(', ') || '';
        setResult({
          type: 'error',
          message: `❌ Sending failed (${data.failed || 0} failed, ${data.sent || 0} sent)\n\nError: ${errorMsg}${failedEmails ? `\n\nFailed emails: ${failedEmails}` : ''}`,
        });
      }
    } catch (err) {
      setResult({ type: 'error', message: `❌ Network error: ${err.message}` });
    }
    setSending(false);
  };

  const LOGO_URL = `${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/email-assets/dincharya-logo.png`;

  const previewHtml = () => {
    const fullName = selectMode === 'all' ? 'User' : (users.find(u => u.id === selectedUsers[0])?.full_name || 'User');
    const firstName = fullName.split(' ')[0] || 'Friend';
    const messageBody = (body || 'Your message will appear here...').replace(/\n/g, '<br style="display:block; margin:12px 0;">');
    return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="color-scheme" content="light dark">
  <style>
    @media (prefers-color-scheme: dark) {
      .email-bg { background-color: #1a1a2e !important; }
      .email-card { background-color: #16213e !important; }
      .email-text { color: #e8e8e8 !important; }
      .email-text-secondary { color: #b0b0b0 !important; }
    }
  </style>
</head>
<body style="margin:0; padding:0;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" class="email-bg" style="background-color:#f0ebe3; padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="max-width:600px; width:100%;">

          <!-- LOGO BANNER -->
          <tr>
            <td align="center" style="padding:0 0 0;">
              <table role="presentation" class="email-card" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#ffffff; border-radius:20px 20px 0 0; overflow:hidden; box-shadow:0 8px 40px rgba(0,0,0,0.06);">
                <tr>
                  <td style="background:linear-gradient(145deg, #1a1a2e 0%, #16213e 40%, #0f3460 100%); padding:36px 40px; text-align:center;">
                    <img src="${LOGO_URL}" alt="DinCharya" width="72" height="72" style="display:block; margin:0 auto 16px; border-radius:16px; border:2px solid rgba(212,175,55,0.3);" />
                    <h1 style="margin:0; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; color:#d4af37; font-size:26px; font-weight:800; letter-spacing:0.5px;">DinCharya</h1>
                    <p style="margin:6px 0 0; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; color:rgba(255,255,255,0.7); font-size:13px; letter-spacing:1px; text-transform:uppercase;">Your Daily Wellness Companion</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- MAIN CONTENT -->
          <tr>
            <td>
              <table role="presentation" class="email-card" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#ffffff; border-radius:0 0 20px 20px; box-shadow:0 8px 40px rgba(0,0,0,0.06);">
                <tr>
                  <td style="padding:40px;">
                    <p class="email-text" style="margin:0 0 24px; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; font-size:18px; color:#1a1a2e; font-weight:600; line-height:1.4;">
                      Namaste ${firstName} 🙏
                    </p>
                    <div class="email-text" style="font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; font-size:15px; color:#374151; line-height:1.85; margin:0 0 32px;">
                      ${messageBody}
                    </div>
                    ${ctaText && ctaUrl ? `
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:8px 0 32px;">
                      <tr>
                        <td align="center">
                          <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                            <tr>
                              <td align="center" style="background:linear-gradient(135deg,#d4af37 0%,#f5d668 50%,#d4af37 100%); border-radius:14px; box-shadow:0 4px 16px rgba(212,175,55,0.35);">
                                <a href="${ctaUrl}" style="display:inline-block; padding:16px 48px; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; font-size:15px; font-weight:800; color:#1a1a2e; text-decoration:none; letter-spacing:0.5px; text-transform:uppercase;">${ctaText}</a>
                              </td>
                            </tr>
                          </table>
                        </td>
                      </tr>
                    </table>` : ''}
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                      <tr>
                        <td style="border-top:1px solid #e5e7eb; padding-top:24px;">
                          <p style="margin:0; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; font-size:14px; color:#6b7280; line-height:1.6;">
                            With gratitude & wellness,<br/>
                            <strong style="color:#d4af37;">Team DinCharya</strong> 💛
                          </p>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- FOOTER -->
          <tr>
            <td style="padding:24px 20px 8px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                <tr>
                  <td align="center">
                    <p style="margin:0 0 8px; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; font-size:12px; color:#9ca3af; line-height:1.5;">
                      You received this because you're a valued member of DinCharya 🧘
                    </p>
                    <p style="margin:0; font-family:'Segoe UI',Roboto,Helvetica,Arial,sans-serif; font-size:11px; color:#b0b0b0;">
                      © ${new Date().getFullYear()} DinCharya · Your mindful daily routine
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

        </table>
      </td>
    </tr>
  </table>
</body>
</html>`;
  };

  return (
    <div>
      <div className="page-header">
        <div><h1>Email Broadcast</h1><p style={{ color: 'var(--text-muted)', marginTop: 4 }}>Send professional emails to your users</p></div>
      </div>

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 4, marginBottom: 24, background: 'var(--bg-surface)', borderRadius: 10, padding: 4, border: '1px solid var(--border-subtle)' }}>
        {[{ id: 'compose', label: '✏️ Compose' }, { id: 'history', label: '📋 History' }].map(t => (
          <button key={t.id} onClick={() => setTab(t.id)} style={{
            flex: 1, padding: '10px 16px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 13, fontWeight: 600,
            background: tab === t.id ? 'var(--accent-gradient)' : 'transparent',
            color: tab === t.id ? '#fff' : 'var(--text-secondary)',
            transition: 'all 0.2s',
          }}>{t.label}</button>
        ))}
      </div>

      {/* ═══ COMPOSE TAB ═══ */}
      {tab === 'compose' && (
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 340px', gap: 20 }}>
          {/* Left: Compose Form */}
          <div>
            {result && (
              <div style={{
                padding: '14px 18px', borderRadius: 10, marginBottom: 16, fontSize: 14, fontWeight: 600,
                background: result.type === 'success' ? 'rgba(74,222,128,0.12)' : 'rgba(248,113,113,0.12)',
                color: result.type === 'success' ? '#4ade80' : '#f87171',
                border: `1px solid ${result.type === 'success' ? 'rgba(74,222,128,0.3)' : 'rgba(248,113,113,0.3)'}`,
              }}>{result.message}</div>
            )}

            <div className="card" style={{ marginBottom: 16 }}>
              <label style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-muted)', marginBottom: 6, display: 'block' }}>Subject *</label>
              <input className="search-input" placeholder="e.g. New Feature Alert! 🎉"
                value={subject} onChange={e => setSubject(e.target.value)}
                style={{ width: '100%', fontSize: 15, padding: '12px 16px', fontWeight: 600 }} />
            </div>

            <div className="card" style={{ marginBottom: 16 }}>
              <label style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-muted)', marginBottom: 6, display: 'block' }}>Message Body *</label>
              <textarea className="search-input" placeholder="Write your message here... Supports line breaks."
                value={body} onChange={e => setBody(e.target.value)}
                rows={8} style={{ width: '100%', resize: 'vertical', fontSize: 14, lineHeight: 1.7, padding: '14px 16px', fontFamily: 'inherit' }} />
              <div style={{ fontSize: 11, color: 'var(--text-muted)', marginTop: 6 }}>
                Tip: Each user will receive a personalized email with their name. Use line breaks for paragraphs.
              </div>
            </div>

            <div className="card" style={{ marginBottom: 16 }}>
              <label style={{ fontSize: 12, fontWeight: 700, color: 'var(--text-muted)', marginBottom: 6, display: 'block' }}>Call-to-Action Button (Optional)</label>
              <div style={{ display: 'flex', gap: 12 }}>
                <input className="search-input" placeholder="Button text, e.g. Open App"
                  value={ctaText} onChange={e => setCtaText(e.target.value)} style={{ flex: 1, padding: '10px 14px' }} />
                <input className="search-input" placeholder="Button URL, e.g. https://..."
                  value={ctaUrl} onChange={e => setCtaUrl(e.target.value)} style={{ flex: 2, padding: '10px 14px' }} />
              </div>
            </div>

            <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
              <button className="btn" onClick={() => setShowPreview(true)}
                style={{ background: 'var(--bg-surface)', color: 'var(--text-secondary)', border: '1px solid var(--border)' }}>
                👁️ Preview Email
              </button>
              <button className="btn" onClick={handleSend} disabled={sending}
                style={{
                  background: 'var(--accent-gradient)', color: '#fff', border: 'none', padding: '12px 32px',
                  fontWeight: 700, fontSize: 14, opacity: sending ? 0.6 : 1, cursor: sending ? 'wait' : 'pointer',
                }}>
                {sending ? '⏳ Sending...' : `📧 Send to ${getRecipients().length} user(s)`}
              </button>
            </div>
          </div>

          {/* Right: Recipient Selection */}
          <div>
            <div className="card">
              <h3 style={{ fontSize: 14, fontWeight: 700, marginBottom: 12 }}>📬 Recipients</h3>

              <div style={{ display: 'flex', gap: 4, marginBottom: 16 }}>
                {[{ id: 'all', label: 'All Users' }, { id: 'select', label: 'Select' }].map(m => (
                  <button key={m.id} onClick={() => { setSelectMode(m.id); setSelectedUsers([]); }} style={{
                    flex: 1, padding: '8px 12px', borderRadius: 6, border: 'none', cursor: 'pointer', fontSize: 12, fontWeight: 600,
                    background: selectMode === m.id ? 'var(--accent)' : 'var(--bg-hover)',
                    color: selectMode === m.id ? '#fff' : 'var(--text-secondary)',
                    transition: 'all 0.2s',
                  }}>{m.label}</button>
                ))}
              </div>

              <div style={{
                padding: '10px 14px', borderRadius: 8, marginBottom: 12, fontSize: 13, fontWeight: 600,
                background: 'rgba(99,102,241,0.08)', color: '#818cf8', border: '1px solid rgba(99,102,241,0.2)',
              }}>
                {selectMode === 'all' ? `📨 All ${users.length} users selected` : `📨 ${selectedUsers.length} of ${users.length} selected`}
              </div>

              {selectMode === 'select' && (
                <div style={{ maxHeight: 400, overflowY: 'auto' }}>
                  {users.map(u => (
                    <div key={u.id} onClick={() => toggleUser(u.id)} style={{
                      display: 'flex', alignItems: 'center', gap: 10, padding: '10px 12px', cursor: 'pointer',
                      borderRadius: 8, marginBottom: 4, transition: 'all 0.15s',
                      background: selectedUsers.includes(u.id) ? 'rgba(99,102,241,0.08)' : 'transparent',
                      border: selectedUsers.includes(u.id) ? '1px solid rgba(99,102,241,0.2)' : '1px solid transparent',
                    }}>
                      <div style={{
                        width: 18, height: 18, borderRadius: 4, display: 'flex', alignItems: 'center', justifyContent: 'center',
                        background: selectedUsers.includes(u.id) ? 'var(--accent)' : 'var(--bg-hover)',
                        border: selectedUsers.includes(u.id) ? 'none' : '1px solid var(--border)',
                        color: '#fff', fontSize: 11, fontWeight: 700,
                      }}>{selectedUsers.includes(u.id) ? '✓' : ''}</div>
                      <div style={{ flex: 1, overflow: 'hidden' }}>
                        <div style={{ fontSize: 12, fontWeight: 600, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.full_name || 'No Name'}</div>
                        <div style={{ fontSize: 10, color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{u.email}</div>
                      </div>
                    </div>
                  ))}
                </div>
              )}
            </div>
          </div>
        </div>
      )}

      {/* ═══ HISTORY TAB ═══ */}
      {tab === 'history' && (
        <div className="card" style={{ padding: 0 }}>
          <h3 style={{ fontSize: 15, fontWeight: 700, padding: '18px 22px 12px' }}>📋 Email Send History</h3>
          {historyLoading ? <p style={{ padding: 20, color: 'var(--text-muted)' }}>Loading...</p> : (
            <table className="data-table">
              <thead><tr><th>Date</th><th>Subject</th><th>Recipients</th><th>Status</th></tr></thead>
              <tbody>
                {history.map(h => (
                  <tr key={h.id}>
                    <td style={{ fontSize: 12, color: 'var(--text-muted)', whiteSpace: 'nowrap' }}>
                      {new Date(h.created_at).toLocaleDateString('en-IN')} {new Date(h.created_at).toLocaleTimeString('en-IN', { hour: '2-digit', minute: '2-digit' })}
                    </td>
                    <td style={{ fontWeight: 600, fontSize: 13 }}>{h.subject}</td>
                    <td>
                      <span className="badge">{h.recipient_count} sent</span>
                    </td>
                    <td>
                      <span className={`badge badge-${h.status === 'sent' ? 'success' : h.status === 'failed' ? 'error' : 'warning'}`}>
                        {h.status === 'sent' ? '✅' : h.status === 'failed' ? '❌' : '⏳'} {h.status}
                      </span>
                    </td>
                  </tr>
                ))}
                {history.length === 0 && (
                  <tr><td colSpan={4} style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)' }}>No emails sent yet</td></tr>
                )}
              </tbody>
            </table>
          )}
        </div>
      )}

      {/* ═══ PREVIEW MODAL ═══ */}
      {showPreview && (
        <div className="modal-overlay" onClick={() => setShowPreview(false)}>
          <div className="modal" onClick={e => e.stopPropagation()} style={{ maxWidth: 700, padding: 0, overflow: 'hidden' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '16px 20px', borderBottom: '1px solid var(--border-subtle)' }}>
              <h3 style={{ margin: 0, fontSize: 15, fontWeight: 700 }}>📧 Email Preview</h3>
              <button className="btn btn-sm" onClick={() => setShowPreview(false)}>✕</button>
            </div>
            <div style={{ padding: 0, background: '#f4f1eb' }}>
              <iframe srcDoc={previewHtml()} style={{ width: '100%', height: 500, border: 'none' }} title="Email Preview" />
            </div>
            <div style={{ padding: '14px 20px', borderTop: '1px solid var(--border-subtle)', display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button className="btn" onClick={() => setShowPreview(false)}>Close</button>
              <button className="btn" onClick={() => { setShowPreview(false); handleSend(); }}
                style={{ background: 'var(--accent-gradient)', color: '#fff', border: 'none', fontWeight: 700 }}>
                📧 Send Now
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

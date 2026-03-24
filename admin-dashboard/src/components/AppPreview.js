'use client';

import { useState } from 'react';

/**
 * Phone-frame preview matching the EXACT Dincharya Flutter app design.
 * Based on real app screenshots showing Theory/Practical tabs with
 * warm brown/cream theme, Hindi+English bilingual, pose grid, breathing badges, etc.
 */
export default function AppPreview({ pose, steps = [], linkedSession = null, onClose, inline = false }) {
  const [activeTab, setActiveTab] = useState('practical');
  const [currentStep, setCurrentStep] = useState(0);
  const [practicalView, setPracticalView] = useState('overview'); // 'overview' or 'active'
  const [lang, setLang] = useState('hi');
  const [voiceOn, setVoiceOn] = useState(true);
  const [expandBenefits, setExpandBenefits] = useState(false);
  const [expandPrecautions, setExpandPrecautions] = useState(false);
  const [currentPage, setCurrentPage] = useState(0);

  if (!pose) return null;

  const totalDuration = steps.reduce((sum, s) => sum + (s.duration_seconds || 10), 0);
  const pages = (pose.literature_content || '').split('---PAGE---').map(p => p.trim()).filter(Boolean);
  const pagesHindi = (pose.literature_content_hindi || '').split('---PAGE---').map(p => p.trim()).filter(Boolean);
  const benefits = Array.isArray(pose.benefits) ? pose.benefits : [];
  const precautions = Array.isArray(pose.precautions) ? pose.precautions : [];

  const breathingLabel = (b) => {
    if (lang === 'hi') {
      const labels = { inhale: 'श्वास लें', exhale: 'श्वास छोड़ें', hold: 'श्वास रोकें', normal: 'सामान्य' };
      return labels[b] || 'सामान्य';
    }
    const labels = { inhale: 'INHALE', exhale: 'EXHALE', hold: 'HOLD', normal: 'NORMAL' };
    return labels[b] || 'NORMAL';
  };

  const breathingColor = (b) => {
    const colors = { inhale: '#2196F3', exhale: '#E65100', hold: '#F9A825', normal: '#4CAF50' };
    return colors[b] || '#4CAF50';
  };

  const breathingIcon = (b) => {
    const icons = { inhale: '↑', exhale: '↓', hold: '⏸', normal: '~' };
    return icons[b] || '~';
  };

  // Colors matching the actual app
  const brown = '#8B4513';
  const brownLight = '#A0522D';
  const cream = '#FDF8F3';
  const creamDark = '#F5EDE4';
  const textBrown = '#2C1810';
  const textMuted = '#8B7355';
  const cardBg = '#FFFBF5';
  const orange = '#E8733A';

  const formatDuration = (sec) => {
    const m = Math.floor(sec / 60);
    const s = sec % 60;
    return s > 0 ? `${m}m ${s}s` : `${m}m`;
  };

  // Parse literature text: {{IMG_LEFT:url}}, {{IMG:url}}, ## heading, **bold**, *italic*
  function parseLiterature(text) {
    if (!text) return null;
    const normalized = text.replace(/\\n/g, '\n');
    const lines = normalized.split('\n');
    const elements = [];
    let i = 0;
    while (i < lines.length) {
      const line = lines[i];
      const trimmed = line.trim();
      if (trimmed.startsWith('{{IMG_LEFT:') && trimmed.endsWith('}}')) {
        const url = trimmed.substring(11, trimmed.length - 2);
        const textLines = [];
        i++;
        while (i < lines.length) {
          const next = lines[i].trim();
          if (next === '' || next.startsWith('{{')) break;
          textLines.push(lines[i]);
          i++;
        }
        elements.push(
          <div key={`img_left_${i}`} style={{ display: 'flex', gap: 10, margin: '8px 0', alignItems: 'flex-start' }}>
            <img src={url} alt="" style={{ width: '38%', borderRadius: 8, border: '1px solid #d4c0a0', boxShadow: '2px 2px 6px rgba(139,75,20,0.12)', objectFit: 'contain', flexShrink: 0 }}
              onError={e => { e.target.style.display = 'none'; }} />
            <div style={{ flex: 1, fontSize: 12, lineHeight: 1.6 }}>
              {textLines.map((tl, ti) => <div key={ti}>{parseInlineMarkdown(tl)}</div>)}
            </div>
          </div>
        );
        continue;
      } else if (trimmed.startsWith('{{IMG:') && trimmed.endsWith('}}')) {
        const url = trimmed.substring(6, trimmed.length - 2);
        elements.push(
          <div key={`img_${i}`} style={{ textAlign: 'center', margin: '10px 0' }}>
            <img src={url} alt="" style={{ maxWidth: '70%', borderRadius: 10, border: '1px solid #d4c0a0', boxShadow: '2px 3px 8px rgba(139,75,20,0.15)' }}
              onError={e => { e.target.style.display = 'none'; }} />
          </div>
        );
      } else if (trimmed === '') {
        elements.push(<div key={`br_${i}`} style={{ height: 6 }} />);
      } else if (line.startsWith('## ')) {
        elements.push(
          <div key={`h_${i}`} style={{ fontSize: 15, fontWeight: 800, color: '#3E2723', margin: '10px 0 4px', letterSpacing: 0.5 }}>
            {line.substring(3)}
            <div style={{ width: 36, height: 2, background: 'rgba(139,105,20,0.5)', borderRadius: 1, marginTop: 3 }} />
          </div>
        );
      } else if (line.startsWith('- ')) {
        elements.push(
          <div key={`li_${i}`} style={{ display: 'flex', gap: 6, padding: '2px 0 2px 8px', fontSize: 12, lineHeight: 1.6 }}>
            <span style={{ color: 'rgba(139,105,20,0.7)', marginTop: 2 }}>●</span>
            <span>{parseInlineMarkdown(line.substring(2))}</span>
          </div>
        );
      } else {
        elements.push(
          <div key={`p_${i}`} style={{ fontSize: 12, lineHeight: 1.7, margin: '2px 0' }}>
            {parseInlineMarkdown(line)}
          </div>
        );
      }
      i++;
    }
    return elements;
  }

  // Parse **bold** and *italic*
  function parseInlineMarkdown(text) {
    const parts = [];
    const regex = /\*\*(.+?)\*\*|\*(.+?)\*/g;
    let lastEnd = 0;
    let match;
    let key = 0;
    while ((match = regex.exec(text)) !== null) {
      if (match.index > lastEnd) parts.push(<span key={key++}>{text.substring(lastEnd, match.index)}</span>);
      if (match[1]) parts.push(<strong key={key++} style={{ fontWeight: 700, color: '#5D4037' }}>{match[1]}</strong>);
      else if (match[2]) parts.push(<em key={key++}>{match[2]}</em>);
      lastEnd = match.index + match[0].length;
    }
    if (lastEnd < text.length) parts.push(<span key={key++}>{text.substring(lastEnd)}</span>);
    return parts.length > 0 ? parts : text;
  }

  // ── Inline mode: render without overlay ──
  if (inline) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, height: '100%', justifyContent: 'center' }}>
        {/* Compact Controls */}
        <div style={{ display: 'flex', gap: 6, alignItems: 'center', flexWrap: 'wrap', justifyContent: 'center' }}>
          <button onClick={() => setLang('hi')} style={{ padding: '4px 10px', borderRadius: 6, border: 'none', cursor: 'pointer', background: lang === 'hi' ? brown : '#27272a', color: lang === 'hi' ? '#fff' : '#a1a1aa', fontSize: 11, fontWeight: 600 }}>हिंदी</button>
          <button onClick={() => setLang('en')} style={{ padding: '4px 10px', borderRadius: 6, border: 'none', cursor: 'pointer', background: lang === 'en' ? brown : '#27272a', color: lang === 'en' ? '#fff' : '#a1a1aa', fontSize: 11, fontWeight: 600 }}>EN</button>
          <span style={{ width: 1, height: 16, background: '#333' }} />
          {activeTab === 'practical' && (<>
            <button onClick={() => setPracticalView('overview')} style={{ padding: '4px 10px', borderRadius: 6, border: 'none', cursor: 'pointer', fontSize: 10, background: practicalView === 'overview' ? brown : '#27272a', color: practicalView === 'overview' ? '#fff' : '#a1a1aa', fontWeight: 600 }}>Grid</button>
            <button onClick={() => setPracticalView('active')} style={{ padding: '4px 10px', borderRadius: 6, border: 'none', cursor: 'pointer', fontSize: 10, background: practicalView === 'active' ? brown : '#27272a', color: practicalView === 'active' ? '#fff' : '#a1a1aa', fontWeight: 600 }}>Step</button>
          </>)}
          <span style={{ fontSize: 10, color: '#636370' }}>{steps.length} steps • {formatDuration(totalDuration)}</span>
        </div>
        {/* Scaled Phone Frame */}
        <div style={{ transform: 'scale(0.82)', transformOrigin: 'top center', flexShrink: 0 }}>
        <div style={{
          width: 380, height: 780, borderRadius: 44,
          background: '#1a1a1a', padding: 10,
          boxShadow: '0 25px 80px rgba(0,0,0,0.5), inset 0 0 0 2px #333',
          position: 'relative',
        }}>
          <div style={{ position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)', width: 130, height: 30, background: '#1a1a1a', borderRadius: '0 0 18px 18px', zIndex: 10 }}>
            <div style={{ width: 60, height: 5, background: '#333', borderRadius: 3, margin: '16px auto 0' }} />
          </div>
          {renderScreen()}
        </div>
        </div>
        <div style={{ fontSize: 9, color: '#636370', fontWeight: 600, textTransform: 'uppercase', letterSpacing: 1 }}>📱 Live Preview</div>
      </div>
    );
  }

  // ── Fullscreen overlay mode (default) ──
  return (
    <div style={{
      position: 'fixed', top: 0, left: 0, right: 0, bottom: 0,
      background: 'rgba(0,0,0,0.7)', zIndex: 9999,
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      backdropFilter: 'blur(6px)',
    }} onClick={onClose}>
      <div onClick={e => e.stopPropagation()} style={{ display: 'flex', gap: 24, alignItems: 'flex-start' }}>

        {/* Control Panel */}
        <div style={{
          background: '#fff', borderRadius: 16, padding: 20, width: 220,
          boxShadow: '0 20px 60px rgba(0,0,0,0.3)',
        }}>
          <h3 style={{ margin: '0 0 16px', fontSize: 14, color: '#333' }}>📱 App Preview</h3>
          <p style={{ fontSize: 12, color: '#666', margin: '0 0 16px', lineHeight: 1.4 }}>
            This shows exactly how <b>{pose.name}</b> will appear in the Dincharya app.
          </p>

          <div style={{ fontSize: 12, color: '#666', marginBottom: 6 }}>Language / भाषा:</div>
          <div style={{ display: 'flex', gap: 4, marginBottom: 16 }}>
            <button onClick={() => setLang('hi')} style={{
              padding: '6px 14px', borderRadius: 8, border: 'none', cursor: 'pointer',
              background: lang === 'hi' ? brown : '#f0f0f0', color: lang === 'hi' ? '#fff' : '#333',
              fontSize: 12, fontWeight: 600,
            }}>हिंदी</button>
            <button onClick={() => setLang('en')} style={{
              padding: '6px 14px', borderRadius: 8, border: 'none', cursor: 'pointer',
              background: lang === 'en' ? brown : '#f0f0f0', color: lang === 'en' ? '#fff' : '#333',
              fontSize: 12, fontWeight: 600,
            }}>English</button>
          </div>

          {activeTab === 'practical' && (
            <>
              <div style={{ fontSize: 12, color: '#666', marginBottom: 6 }}>View:</div>
              <div style={{ display: 'flex', gap: 4, marginBottom: 16 }}>
                <button onClick={() => setPracticalView('overview')} style={{
                  padding: '6px 12px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 11,
                  background: practicalView === 'overview' ? brown : '#f0f0f0',
                  color: practicalView === 'overview' ? '#fff' : '#333', fontWeight: 600,
                }}>Grid</button>
                <button onClick={() => setPracticalView('active')} style={{
                  padding: '6px 12px', borderRadius: 8, border: 'none', cursor: 'pointer', fontSize: 11,
                  background: practicalView === 'active' ? brown : '#f0f0f0',
                  color: practicalView === 'active' ? '#fff' : '#333', fontWeight: 600,
                }}>Step View</button>
              </div>
            </>
          )}

          <div style={{ borderTop: '1px solid #eee', paddingTop: 12, marginTop: 8 }}>
            <div style={{ fontSize: 11, color: '#999', lineHeight: 1.5 }}>
              ✅ {steps.length} steps loaded<br/>
              ⏱️ Total: {formatDuration(totalDuration)}<br/>
              📖 {pages.length} literature pages<br/>
              ✨ {benefits.length} benefits<br/>
              ⚠️ {precautions.length} precautions
            </div>
          </div>

          <button onClick={onClose} style={{
            marginTop: 16, width: '100%', padding: '10px 0', borderRadius: 10,
            border: '1px solid #ddd', background: '#fff', cursor: 'pointer',
            fontSize: 13, fontWeight: 600, color: '#666',
          }}>✕ Close Preview</button>
        </div>

        {/* Phone Frame */}
        <div style={{
          width: 380, height: 780, borderRadius: 44,
          background: '#1a1a1a', padding: 10,
          boxShadow: '0 25px 80px rgba(0,0,0,0.5), inset 0 0 0 2px #333',
          position: 'relative',
        }}>
          {/* Notch */}
          <div style={{
            position: 'absolute', top: 10, left: '50%', transform: 'translateX(-50%)',
            width: 130, height: 30, background: '#1a1a1a', borderRadius: '0 0 18px 18px', zIndex: 10,
          }}>
            <div style={{ width: 60, height: 5, background: '#333', borderRadius: 3, margin: '16px auto 0' }} />
          </div>

          {renderScreen()}
        </div>
      </div>
    </div>
  );

  // ── Shared screen content ──
  function renderScreen() {
    return (
          <div style={{
            width: '100%', height: '100%', borderRadius: 34,
            background: cream, overflow: 'hidden',
            display: 'flex', flexDirection: 'column',
          }}>
            {/* Status Bar */}
            <div style={{
              height: 36, display: 'flex', alignItems: 'center', justifyContent: 'space-between',
              padding: '0 20px', fontSize: 12, fontWeight: 600, color: textBrown,
              background: cream,
            }}>
              <span>9:06</span>
              <span style={{ fontSize: 9, letterSpacing: 1 }}>📶 4G ▐▐▐ 80</span>
            </div>

            {/* App Bar — Brown header */}
            <div style={{
              background: brown, padding: '12px 16px',
              display: 'flex', alignItems: 'center', gap: 12,
            }}>
              <span style={{ color: '#fff', fontSize: 20, cursor: 'pointer' }}>‹</span>
              <span style={{ color: '#fff', fontWeight: 700, fontSize: 17 }}>
                {lang === 'hi' ? (linkedSession?.title_hindi || linkedSession?.title || pose.name) : (linkedSession?.title || pose.name)}
              </span>
            </div>

            {/* Tab Bar — Matching app exactly */}
            <div style={{
              display: 'flex', background: creamDark, padding: '6px 12px',
              gap: 0,
            }}>
              <button onClick={() => setActiveTab('theory')} style={{
                flex: 1, padding: '10px 0', border: 'none', cursor: 'pointer',
                background: activeTab === 'theory' ? brown : 'transparent',
                color: activeTab === 'theory' ? '#fff' : textBrown,
                fontWeight: 600, fontSize: 13, borderRadius: 10,
                transition: 'all 0.2s',
              }}>
                {lang === 'hi' ? 'विद्या / Theory' : 'Theory'}
              </button>
              <button onClick={() => setActiveTab('practical')} style={{
                flex: 1, padding: '10px 0', border: 'none', cursor: 'pointer',
                background: activeTab === 'practical' ? brown : 'transparent',
                color: activeTab === 'practical' ? '#fff' : textBrown,
                fontWeight: 600, fontSize: 13, borderRadius: 10,
                transition: 'all 0.2s',
              }}>
                {lang === 'hi' ? 'अभ्यास / Practical' : 'Practical'}
              </button>
            </div>

            {/* Content Area */}
            <div style={{ flex: 1, overflow: 'auto' }}>

              {activeTab === 'theory' ? (
                /* ═══════ THEORY TAB ═══════ */
                <div style={{ padding: 0 }}>

                  {/* Video Player Placeholder */}
                  <div style={{
                    background: '#000', height: 180, display: 'flex',
                    alignItems: 'center', justifyContent: 'center', position: 'relative',
                  }}>
                    <div style={{ textAlign: 'center' }}>
                      <div style={{
                        width: 50, height: 50, borderRadius: '50%', background: 'rgba(255,255,255,0.9)',
                        display: 'flex', alignItems: 'center', justifyContent: 'center', margin: '0 auto 8px',
                      }}>
                        <span style={{ fontSize: 24, marginLeft: 4 }}>▶</span>
                      </div>
                      <div style={{ color: '#fff', fontSize: 11 }}>YouTube Video</div>
                    </div>
                    {/* Progress bar */}
                    <div style={{
                      position: 'absolute', bottom: 0, left: 0, right: 0, height: 3,
                      background: '#333',
                    }}>
                      <div style={{ width: '0%', height: '100%', background: '#e53935' }} />
                    </div>
                  </div>

                  <div style={{ padding: '0 14px 14px' }}>
                    {/* Literature Section */}
                    {pages.length > 0 && (
                      <div style={{
                        background: cardBg, borderRadius: 14, margin: '12px 0',
                        border: '1px solid #e8dfd4', overflow: 'hidden',
                      }}>
                        {/* Literature Header */}
                        <div style={{
                          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                          padding: '10px 14px', background: '#F5EDE4',
                        }}>
                          <span style={{ fontWeight: 700, fontSize: 14, color: textBrown }}>
                            📖 {lang === 'hi' ? 'साहित्य' : 'Literature'}
                          </span>
                          <button onClick={() => setLang(lang === 'hi' ? 'en' : 'hi')} style={{
                            padding: '3px 10px', borderRadius: 6, border: '1px solid #ccc',
                            background: '#fff', fontSize: 11, cursor: 'pointer', fontWeight: 600,
                          }}>
                            {lang === 'hi' ? '🈁 EN' : '🈁 हिं'}
                          </button>
                        </div>
                        {/* Page Content */}
                        <div style={{ padding: '14px', minHeight: 100 }}>
                          <div style={{
                            fontSize: 13, color: textBrown, lineHeight: 1.8,
                          }}>
                            {parseLiterature(lang === 'hi' ? (pagesHindi[currentPage] || pages[currentPage] || '') : (pages[currentPage] || ''))}
                          </div>
                        </div>
                        {/* Page dots */}
                        {pages.length > 1 && (
                          <div style={{
                            display: 'flex', justifyContent: 'center', gap: 5,
                            padding: '8px 0 12px',
                          }}>
                            {pages.map((_, i) => (
                              <div key={i} onClick={() => setCurrentPage(i)} style={{
                                width: i === currentPage ? 18 : 7, height: 7, borderRadius: 4,
                                background: i === currentPage ? brown : '#d4c5b3', cursor: 'pointer',
                                transition: 'all 0.2s',
                              }} />
                            ))}
                          </div>
                        )}
                        <div style={{ textAlign: 'center', fontSize: 11, color: textMuted, paddingBottom: 10 }}>
                          {lang === 'hi' ? `पृष्ठ ${currentPage + 1} / ${pages.length}` : `Page ${currentPage + 1} / ${pages.length}`}
                        </div>
                      </div>
                    )}

                    {/* Benefits Section */}
                    {benefits.length > 0 && (
                      <div style={{
                        background: cardBg, borderRadius: 14, margin: '10px 0',
                        border: '1px solid #e8dfd4', overflow: 'hidden',
                      }}>
                        <div onClick={() => setExpandBenefits(!expandBenefits)} style={{
                          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                          padding: '12px 14px', cursor: 'pointer',
                        }}>
                          <span style={{ fontWeight: 700, fontSize: 14, color: textBrown }}>
                            ✅ Benefits / लाभ ({benefits.length})
                          </span>
                          <span style={{ color: brown, fontSize: 18 }}>{expandBenefits ? '∧' : '∨'}</span>
                        </div>
                        {/* First 2 always visible */}
                        <div style={{ padding: '0 14px' }}>
                          {benefits.slice(0, expandBenefits ? benefits.length : 2).map((b, i) => (
                            <div key={i} style={{
                              display: 'flex', gap: 8, padding: '6px 0', fontSize: 13, color: textBrown,
                              alignItems: 'flex-start',
                            }}>
                              <span style={{ color: '#4CAF50', fontSize: 14, marginTop: 1 }}>✓</span>
                              <span>{b}</span>
                            </div>
                          ))}
                        </div>
                        {benefits.length > 2 && !expandBenefits && (
                          <div onClick={() => setExpandBenefits(true)} style={{
                            textAlign: 'center', padding: '8px 14px 12px', cursor: 'pointer',
                          }}>
                            <span style={{
                              background: `${brown}15`, color: brown, padding: '6px 16px',
                              borderRadius: 20, fontSize: 12, fontWeight: 600,
                            }}>
                              {lang === 'hi' ? `सभी ${benefits.length} लाभ देखें ∨` : `View all ${benefits.length} benefits ∨`}
                            </span>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Precautions Section */}
                    {precautions.length > 0 && (
                      <div style={{
                        background: cardBg, borderRadius: 14, margin: '10px 0',
                        border: '1px solid #e8dfd4', overflow: 'hidden',
                      }}>
                        <div onClick={() => setExpandPrecautions(!expandPrecautions)} style={{
                          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                          padding: '12px 14px', cursor: 'pointer',
                        }}>
                          <span style={{ fontWeight: 700, fontSize: 14, color: textBrown }}>
                            ⚠️ Precautions / सावधानियाँ ({precautions.length})
                          </span>
                          <span style={{ color: brown, fontSize: 18 }}>{expandPrecautions ? '∧' : '∨'}</span>
                        </div>
                        <div style={{ padding: '0 14px' }}>
                          {precautions.slice(0, expandPrecautions ? precautions.length : 2).map((p, i) => (
                            <div key={i} style={{
                              display: 'flex', gap: 8, padding: '6px 0', fontSize: 13, color: textBrown,
                              alignItems: 'flex-start',
                            }}>
                              <span style={{ color: '#E65100', fontSize: 13, marginTop: 1 }}>ⓘ</span>
                              <span>{p}</span>
                            </div>
                          ))}
                        </div>
                        {precautions.length > 2 && !expandPrecautions && (
                          <div onClick={() => setExpandPrecautions(true)} style={{
                            textAlign: 'center', padding: '8px 14px 12px', cursor: 'pointer',
                          }}>
                            <span style={{
                              background: '#E6510015', color: '#E65100', padding: '6px 16px',
                              borderRadius: 20, fontSize: 12, fontWeight: 600,
                            }}>
                              {lang === 'hi' ? `सभी ${precautions.length} सावधानियाँ देखें ∨` : `View all ${precautions.length} precautions ∨`}
                            </span>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Steps Overview Section */}
                    {steps.length > 0 && (
                      <div style={{
                        background: cardBg, borderRadius: 14, margin: '10px 0',
                        border: '1px solid #e8dfd4', overflow: 'hidden',
                      }}>
                        <div style={{
                          display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                          padding: '12px 14px',
                        }}>
                          <span style={{ fontWeight: 700, fontSize: 14, color: textBrown }}>
                            📋 Steps Overview ({steps.length})
                          </span>
                          <span style={{ color: brown, fontSize: 18 }}>∨</span>
                        </div>
                        <div style={{ padding: '0 14px 14px' }}>
                          {steps.slice(0, 4).map((s, i) => (
                            <div key={i} style={{
                              display: 'flex', gap: 10, padding: '8px 0',
                              borderBottom: i < 3 ? '1px solid #f0e8de' : 'none',
                              alignItems: 'flex-start',
                            }}>
                              <div style={{
                                width: 24, height: 24, borderRadius: '50%', background: brown,
                                color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
                                fontSize: 11, fontWeight: 700, flexShrink: 0, marginTop: 2,
                              }}>{s.step_number}</div>
                              <div style={{ flex: 1 }}>
                                <div style={{ fontWeight: 600, fontSize: 13, color: textBrown }}>
                                  {s.name}
                                </div>
                                {s.name_hindi && (
                                  <div style={{ fontSize: 11, color: textMuted }}>{s.name_hindi}</div>
                                )}
                                <div style={{ display: 'flex', gap: 8, marginTop: 3 }}>
                                  <span style={{
                                    fontSize: 10, fontWeight: 700, color: breathingColor(s.breathing),
                                  }}>
                                    {breathingIcon(s.breathing)} {breathingLabel(s.breathing)}
                                  </span>
                                  <span style={{ fontSize: 10, color: textMuted }}>⏱ {s.duration_seconds}s</span>
                                </div>
                                {s.mantra && (
                                  <div style={{ fontSize: 10, color: '#7c3aed', fontStyle: 'italic', marginTop: 2 }}>
                                    🕉️ {s.mantra}
                                  </div>
                                )}
                              </div>
                            </div>
                          ))}
                          {steps.length > 4 && (
                            <div style={{ textAlign: 'center', paddingTop: 8, fontSize: 12, color: textMuted }}>
                              +{steps.length - 4} more steps...
                            </div>
                          )}
                        </div>
                      </div>
                    )}
                  </div>
                </div>

              ) : practicalView === 'overview' ? (
                /* ═══════ PRACTICAL TAB — OVERVIEW ═══════ */
                <div style={{ padding: '16px 14px' }}>
                  {/* Pose Header Card */}
                  <div style={{
                    background: cardBg, borderRadius: 16, padding: '20px 16px',
                    border: '1px solid #e8dfd4', textAlign: 'center', marginBottom: 16,
                  }}>
                    <div style={{ fontSize: 32, marginBottom: 8 }}>🧘</div>
                    <div style={{ fontSize: 22, fontWeight: 700, color: textBrown }}>
                      {lang === 'hi' ? (pose.name_hindi || pose.name) : pose.name}
                    </div>
                    <div style={{ fontSize: 13, color: textMuted, marginTop: 2 }}>
                      {lang === 'hi' ? pose.name : (pose.name_hindi || pose.name_sanskrit || '')}
                    </div>
                    <div style={{ display: 'flex', justifyContent: 'center', gap: 14, marginTop: 12 }}>
                      <span style={{
                        background: creamDark, padding: '5px 14px', borderRadius: 20,
                        fontSize: 12, fontWeight: 600, color: textBrown,
                      }}>≡ {steps.length} Steps</span>
                      <span style={{
                        background: creamDark, padding: '5px 14px', borderRadius: 20,
                        fontSize: 12, fontWeight: 600, color: textBrown,
                      }}>⏱ {formatDuration(totalDuration)}</span>
                    </div>
                  </div>

                  {/* Pose Sequence Grid */}
                  <div style={{
                    background: cardBg, borderRadius: 16, padding: 16,
                    border: '1px solid #e8dfd4',
                  }}>
                    <div style={{ fontWeight: 700, fontSize: 14, color: textBrown, marginBottom: 12 }}>
                      ▦ Pose Sequence
                    </div>
                    <div style={{
                      display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)',
                      gap: 8,
                    }}>
                      {steps.map((s, i) => (
                        <div key={i} onClick={() => { setCurrentStep(i); setPracticalView('active'); }}
                          style={{ textAlign: 'center', cursor: 'pointer' }}>
                          <div style={{
                            width: '100%', aspectRatio: '1', borderRadius: 10,
                            background: `linear-gradient(135deg, ${creamDark}, #efe4d5)`,
                            border: '1px solid #e0d4c4',
                            display: 'flex', alignItems: 'center', justifyContent: 'center',
                            fontSize: 11, color: textBrown, fontWeight: 500,
                            transition: 'transform 0.2s',
                          }}>
                            {s.image_url ? (
                              <img src={s.image_url} alt={s.name} style={{
                                width: '100%', height: '100%', objectFit: 'cover', borderRadius: 10,
                              }} />
                            ) : (
                              <span style={{ fontSize: 9, padding: 4, textAlign: 'center', lineHeight: 1.2 }}>
                                {s.name?.substring(0, 12)}
                              </span>
                            )}
                          </div>
                          <div style={{ fontSize: 11, color: textMuted, marginTop: 4, fontWeight: 600 }}>{i + 1}</div>
                        </div>
                      ))}
                    </div>
                  </div>

                  {/* Bottom Controls */}
                  <div style={{
                    display: 'flex', gap: 10, marginTop: 16,
                  }}>
                    <button onClick={() => setLang(lang === 'hi' ? 'en' : 'hi')} style={{
                      flex: 1, padding: '10px 0', borderRadius: 12,
                      border: '1px solid #d4c5b3', background: '#fff', cursor: 'pointer',
                      fontSize: 13, fontWeight: 600, color: textBrown,
                    }}>
                      🈁 {lang === 'hi' ? 'हिंदी' : 'English'}
                    </button>
                    <button onClick={() => setVoiceOn(!voiceOn)} style={{
                      flex: 1, padding: '10px 0', borderRadius: 12,
                      border: '1px solid #d4c5b3', background: '#fff', cursor: 'pointer',
                      fontSize: 13, fontWeight: 600, color: textBrown,
                    }}>
                      🔊 Voice {voiceOn ? 'ON' : 'OFF'}
                    </button>
                  </div>
                </div>

              ) : (
                /* ═══════ PRACTICAL TAB — ACTIVE STEP ═══════ */
                <div>
                  {/* Progress bar */}
                  <div style={{ height: 4, background: '#e8dfd4' }}>
                    <div style={{
                      width: `${((currentStep + 1) / steps.length) * 100}%`,
                      height: '100%', background: '#e53935', transition: 'width 0.3s',
                      borderRadius: '0 2px 2px 0',
                    }} />
                  </div>

                  <div style={{ padding: '10px 14px' }}>
                    {/* Step Header Row */}
                    <div style={{
                      display: 'flex', justifyContent: 'space-between', alignItems: 'center',
                      marginBottom: 10,
                    }}>
                      <span style={{
                        background: '#fff', border: `1.5px solid ${orange}`, color: orange,
                        padding: '4px 12px', borderRadius: 16, fontSize: 12, fontWeight: 700,
                      }}>
                        Step {currentStep + 1}/{steps.length}
                      </span>
                      <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                        <span style={{ fontSize: 18, color: textMuted }}>🔊</span>
                        <span style={{
                          background: orange, color: '#fff', padding: '4px 10px',
                          borderRadius: 14, fontSize: 13, fontWeight: 700,
                        }}>
                          {steps[currentStep]?.duration_seconds || 10}s
                        </span>
                      </div>
                    </div>

                    {/* Pose Card */}
                    {steps[currentStep] && (
                      <div style={{
                        background: cardBg, borderRadius: 16, padding: 16,
                        border: '1px solid #e8dfd4', marginBottom: 12,
                      }}>
                        {/* Breathing Badge */}
                        <span style={{
                          display: 'inline-block',
                          background: `${breathingColor(steps[currentStep].breathing)}18`,
                          color: breathingColor(steps[currentStep].breathing),
                          border: `1px solid ${breathingColor(steps[currentStep].breathing)}40`,
                          padding: '4px 12px', borderRadius: 14,
                          fontSize: 11, fontWeight: 700, marginBottom: 10,
                        }}>
                          🫁 {breathingLabel(steps[currentStep].breathing)}
                        </span>

                        {/* Pose Image Area */}
                        <div style={{
                          width: '100%', height: 200, borderRadius: 12, marginBottom: 12,
                          background: `linear-gradient(135deg, ${creamDark}, #efe4d5)`,
                          border: '1px solid #e0d4c4',
                          display: 'flex', alignItems: 'center', justifyContent: 'center',
                        }}>
                          {steps[currentStep].image_url ? (
                            <img src={steps[currentStep].image_url} alt="" style={{
                              width: '100%', height: '100%', objectFit: 'contain', borderRadius: 12,
                            }} />
                          ) : (
                            <div style={{ textAlign: 'center', color: textMuted }}>
                              <div style={{ fontSize: 32, marginBottom: 4 }}>🧘</div>
                              <div style={{ fontSize: 11 }}>Pose Image</div>
                            </div>
                          )}
                        </div>

                        {/* Pose Name */}
                        <div style={{ textAlign: 'center', marginBottom: 6 }}>
                          <div style={{ fontSize: 17, fontWeight: 700, color: textBrown }}>
                            {lang === 'hi' ? (steps[currentStep].name_hindi || steps[currentStep].name) : steps[currentStep].name}
                          </div>
                          {lang === 'hi' && steps[currentStep].name && steps[currentStep].name_hindi && (
                            <div style={{ fontSize: 12, color: textMuted }}>({steps[currentStep].name})</div>
                          )}
                        </div>

                        {/* Mantra */}
                        {steps[currentStep].mantra && (
                          <div style={{
                            textAlign: 'center', margin: '8px 0',
                            padding: '6px 16px', borderRadius: 10,
                            background: '#F5EDE4', border: '1px solid #e0d4c4',
                            display: 'inline-block', width: '100%',
                          }}>
                            <span style={{ fontSize: 13, color: brown, fontWeight: 600 }}>
                              🕉️ {steps[currentStep].mantra}
                            </span>
                          </div>
                        )}
                      </div>
                    )}

                    {/* Instruction Section */}
                    {steps[currentStep]?.instruction && (
                      <div style={{
                        background: cardBg, borderRadius: 14, padding: 14,
                        border: '1px solid #e8dfd4', marginBottom: 12,
                      }}>
                        <div style={{ fontWeight: 700, fontSize: 13, color: textBrown, marginBottom: 6 }}>
                          ① {lang === 'hi' ? 'निर्देश' : 'Instructions'}
                        </div>
                        <div style={{ fontSize: 13, color: textBrown, lineHeight: 1.7 }}>
                          {lang === 'hi'
                            ? (steps[currentStep].instruction_hindi || steps[currentStep].instruction)
                            : steps[currentStep].instruction}
                        </div>
                        {/* Tips */}
                        {steps[currentStep].tips && steps[currentStep].tips.length > 0 && (
                          <div style={{ marginTop: 10, paddingTop: 8, borderTop: '1px solid #f0e8de' }}>
                            {steps[currentStep].tips.map((t, i) => (
                              <div key={i} style={{
                                display: 'flex', gap: 6, padding: '3px 0',
                                fontSize: 12, color: '#4CAF50',
                              }}>
                                <span>🌱</span> <span style={{ color: textBrown }}>{t}</span>
                              </div>
                            ))}
                          </div>
                        )}
                      </div>
                    )}
                  </div>

                  {/* Bottom Player Controls */}
                  <div style={{
                    padding: '12px 24px', display: 'flex',
                    justifyContent: 'center', alignItems: 'center', gap: 20,
                    borderTop: '1px solid #f0e8de',
                  }}>
                    <button onClick={() => setCurrentStep(Math.max(0, currentStep - 1))}
                      style={{
                        width: 40, height: 40, borderRadius: '50%', border: '1px solid #d4c5b3',
                        background: '#fff', cursor: 'pointer', fontSize: 16, color: textBrown,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>⏮</button>
                    <button style={{
                      width: 56, height: 56, borderRadius: '50%', border: 'none',
                      background: orange, cursor: 'pointer', fontSize: 22, color: '#fff',
                      display: 'flex', alignItems: 'center', justifyContent: 'center',
                      boxShadow: `0 4px 14px ${orange}66`,
                    }}>▶</button>
                    <button onClick={() => setCurrentStep(Math.min(steps.length - 1, currentStep + 1))}
                      style={{
                        width: 40, height: 40, borderRadius: '50%', border: '1px solid #d4c5b3',
                        background: '#fff', cursor: 'pointer', fontSize: 16, color: textBrown,
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>⏭</button>
                    <button onClick={() => setPracticalView('overview')}
                      style={{
                        width: 40, height: 40, borderRadius: '50%', border: '1px solid #d4c5b3',
                        background: '#fff', cursor: 'pointer', fontSize: 16, color: '#e53935',
                        display: 'flex', alignItems: 'center', justifyContent: 'center',
                      }}>⏹</button>
                  </div>
                </div>
              )}
            </div>

            {/* Home Indicator */}
            <div style={{ height: 20, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
              <div style={{ width: 120, height: 4, background: '#d4c5b3', borderRadius: 2 }} />
            </div>
          </div>
    );
  }
}

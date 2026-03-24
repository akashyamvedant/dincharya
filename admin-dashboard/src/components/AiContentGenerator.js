'use client';

import { useState, useMemo, useRef, useEffect } from 'react';
import AppPreview from '@/components/AppPreview';

// ═══════════════════════════════════════════════════════════════
// AI Content Generator — Chat-based per-section AI generation
// Uses: Sarvam AI (text) + OpenRouter FLUX.2-flex (images)
// ═══════════════════════════════════════════════════════════════

export default function AiContentGenerator({ pose, steps: existingSteps, onClose, onSaved, supabase }) {
  // ── Generated content state (local until saved) ──
  const [genDescription, setGenDescription] = useState('');
  const [genBenefits, setGenBenefits] = useState([]);
  const [genPrecautions, setGenPrecautions] = useState([]);
  const [genLiteratureEn, setGenLiteratureEn] = useState('');
  const [genLiteratureHi, setGenLiteratureHi] = useState('');
  const [genSteps, setGenSteps] = useState([]);
  const [genCoverImage, setGenCoverImage] = useState('');
  const [genLiteratureImage, setGenLiteratureImage] = useState('');
  const [genStepImages, setGenStepImages] = useState({});

  // ── Chat state per tab ──
  const [chatMessages, setChatMessages] = useState({
    description: [],
    literature: [],
    steps: [],
  });
  const [userInstruction, setUserInstruction] = useState('');

  // ── Image upload for vision-based literature ──
  const [uploadedImages, setUploadedImages] = useState([]);
  const imageInputRef = useRef(null);

  // ── Loading states ──
  const [loadingTab, setLoadingTab] = useState(''); // which tab is currently generating
  const [loadingCover, setLoadingCover] = useState(false);
  const [loadingLitImg, setLoadingLitImg] = useState(false);
  const [loadingStepImg, setLoadingStepImg] = useState({});
  const [saving, setSaving] = useState(false);
  const [saveMsg, setSaveMsg] = useState('');

  // ── Active tab & preview ──
  const [tab, setTab] = useState('overview');
  const [showPreview, setShowPreview] = useState(false);

  // ── Refs ──
  const chatEndRef = useRef(null);

  // ── Image upload handlers ──
  const handleImageUpload = (e) => {
    const files = Array.from(e.target.files || []);
    if (files.length === 0) return;
    const totalImages = uploadedImages.length + files.length;
    if (totalImages > 10) {
      alert('Maximum 10 images allowed');
      return;
    }
    files.forEach(file => {
      const reader = new FileReader();
      reader.onload = (ev) => {
        setUploadedImages(prev => [...prev, {
          id: Date.now() + Math.random(),
          name: file.name,
          dataUrl: ev.target.result,
          size: file.size,
        }]);
      };
      reader.readAsDataURL(file);
    });
    if (imageInputRef.current) imageInputRef.current.value = '';
  };

  const removeUploadedImage = (id) => {
    setUploadedImages(prev => prev.filter(img => img.id !== id));
  };

  // Auto-scroll chat to bottom
  useEffect(() => {
    if (chatEndRef.current) {
      chatEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [chatMessages, loadingTab]);

  // ── Extract literature images from content ──
  const literatureImages = useMemo(() => {
    const imgs = [];
    const content = genLiteratureEn || pose.literature_content || '';
    const contentHi = genLiteratureHi || pose.literature_content_hindi || '';
    const regex = /\{\{IMG(?:_LEFT)?:(.+?)\}\}/g;
    let m;
    const seen = new Set();
    for (const text of [content, contentHi]) {
      while ((m = regex.exec(text)) !== null) {
        if (!seen.has(m[1])) { seen.add(m[1]); imgs.push(m[1]); }
      }
    }
    return imgs;
  }, [pose.literature_content, pose.literature_content_hindi, genLiteratureEn, genLiteratureHi]);

  // ── Count step images ──
  const allSteps = genSteps.length > 0 ? genSteps : (existingSteps || []);
  const stepsWithImages = allSteps.filter(s => s.image_url || genStepImages[s.name]).length;

  // ── Content completeness score (REAL data) ──
  const contentScore = useMemo(() => {
    let filled = 0, total = 7;
    if (pose.description || genDescription) filled++;
    if ((pose.benefits?.length > 0) || genBenefits.length > 0) filled++;
    if ((pose.precautions?.length > 0) || genPrecautions.length > 0) filled++;
    if (pose.literature_content || genLiteratureEn) filled++;
    if (pose.literature_content_hindi || genLiteratureHi) filled++;
    if ((existingSteps?.length > 0) || genSteps.length > 0) filled++;
    if (allSteps.length > 0 && stepsWithImages >= Math.ceil(allSteps.length / 2)) filled++;
    return Math.round((filled / total) * 100);
  }, [pose, genDescription, genBenefits, genPrecautions, genLiteratureEn, genLiteratureHi, genSteps, genCoverImage, genLiteratureImage, existingSteps, allSteps, stepsWithImages]);

  // ── Merged pose data for live preview ──
  const mergedPose = useMemo(() => ({
    ...pose,
    description: genDescription || pose.description,
    benefits: genBenefits.length > 0 ? genBenefits : (pose.benefits || []),
    precautions: genPrecautions.length > 0 ? genPrecautions : (pose.precautions || []),
    literature_content: genLiteratureEn || pose.literature_content,
    literature_content_hindi: genLiteratureHi || pose.literature_content_hindi,
    cover_image_url: genCoverImage || pose.cover_image_url,
    literature_image_url: genLiteratureImage || pose.literature_image_url,
  }), [pose, genDescription, genBenefits, genPrecautions, genLiteratureEn, genLiteratureHi, genCoverImage, genLiteratureImage]);

  const mergedSteps = useMemo(() => {
    if (genSteps.length > 0) {
      return genSteps.map((s, i) => ({
        ...s,
        id: s.id || `gen-${i}`,
        step_number: s.step_number || i + 1,
        image_url: genStepImages[s.name] || s.image_url || null,
      }));
    }
    return existingSteps || [];
  }, [genSteps, genStepImages, existingSteps]);

  // ── Build existing content string for AI context ──
  const getExistingContent = (type) => {
    const parts = [];
    if (type === 'description') {
      if (pose.description) parts.push(`Current Description: ${pose.description}`);
      if (pose.benefits?.length > 0) parts.push(`Current Benefits (${pose.benefits.length}): ${pose.benefits.join('; ')}`);
      if (pose.precautions?.length > 0) parts.push(`Current Precautions (${pose.precautions.length}): ${pose.precautions.join('; ')}`);
    } else if (type === 'literature_en') {
      if (pose.literature_content) parts.push(`Current English Literature:\n${pose.literature_content.substring(0, 500)}...`);
    } else if (type === 'literature_hi') {
      if (pose.literature_content_hindi) parts.push(`Current Hindi Literature:\n${pose.literature_content_hindi.substring(0, 500)}...`);
    } else if (type === 'steps') {
      if (existingSteps?.length > 0) {
        parts.push(`Current Steps (${existingSteps.length}):\n${existingSteps.map(s => `${s.step_number}. ${s.name} (${s.breathing}) — ${s.instruction?.substring(0, 60)}...`).join('\n')}`);
      }
    }
    return parts.length > 0 ? parts.join('\n\n') : '';
  };

  // ═══════════════════════════ CHAT-BASED GENERATION ═══════════════════════════

  const generateWithChat = async (type, instruction) => {
    const chatKey = type === 'literature_en' || type === 'literature_hi' ? 'literature' : type;
    const isLiterature = type === 'literature_en' || type === 'literature_hi';
    const hasImages = isLiterature && uploadedImages.length > 0;

    // Add user message to chat (with image count if applicable)
    const msgContent = (instruction || getDefaultInstruction(type)) + (hasImages ? ` [📷 ${uploadedImages.length} image${uploadedImages.length > 1 ? 's' : ''} attached]` : '');
    const userMsg = { role: 'user', content: msgContent, timestamp: Date.now(), imageCount: hasImages ? uploadedImages.length : 0 };
    setChatMessages(prev => ({
      ...prev,
      [chatKey]: [...prev[chatKey], userMsg],
    }));
    setUserInstruction('');
    setLoadingTab(type);

    try {
      let res;

      if (hasImages) {
        // ── Vision route: send images to Gemma 3 27B ──
        const imageDataUrls = uploadedImages.map(img => img.dataUrl);
        setUploadedImages([]); // Clear after capturing

        res = await fetch('/api/ai/generate-text-vision', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            type,
            poseName: pose.name,
            category: pose.category,
            nameHindi: pose.name_hindi,
            nameSanskrit: pose.name_sanskrit,
            userInstruction: instruction || getDefaultInstruction(type),
            images: imageDataUrls,
          }),
        });
      } else {
        // ── Standard text route: Sarvam 105B ──
        res = await fetch('/api/ai/generate-text', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            type,
            poseName: pose.name,
            category: pose.category,
            nameHindi: pose.name_hindi,
            nameSanskrit: pose.name_sanskrit,
            userInstruction: instruction || getDefaultInstruction(type),
            existingContent: getExistingContent(type),
          }),
        });
      }
      const data = await res.json();
      if (data.error) throw new Error(data.error);

      // Process result and add AI response
      let aiContent = '';
      if (type === 'description') {
        const result = data.result;
        setGenDescription(result.description || '');
        setGenBenefits(result.benefits || []);
        setGenPrecautions(result.precautions || []);
        aiContent = `✅ Generated:\n• Description: ${(result.description || '').substring(0, 80)}...\n• ${(result.benefits || []).length} benefits\n• ${(result.precautions || []).length} precautions`;
      } else if (type === 'literature_en') {
        setGenLiteratureEn(data.result || '');
        const pageCount = ((data.result || '').match(/---PAGE---/g) || []).length + 1;
        aiContent = `✅ Generated English literature — ${pageCount} pages`;
      } else if (type === 'literature_hi') {
        setGenLiteratureHi(data.result || '');
        const pageCount = ((data.result || '').match(/---PAGE---/g) || []).length + 1;
        aiContent = `✅ Hindi साहित्य — ${pageCount} पृष्ठ generated`;
      } else if (type === 'steps') {
        const steps = Array.isArray(data.result) ? data.result : [];
        setGenSteps(steps);
        aiContent = `✅ Generated ${steps.length} steps`;
      }

      setChatMessages(prev => ({
        ...prev,
        [chatKey]: [...prev[chatKey], { role: 'ai', content: aiContent, timestamp: Date.now() }],
      }));
    } catch (err) {
      setChatMessages(prev => ({
        ...prev,
        [chatKey]: [...prev[chatKey], { role: 'ai', content: `❌ Error: ${err.message}`, timestamp: Date.now(), isError: true }],
      }));
    }
    setLoadingTab('');
  };

  const getDefaultInstruction = (type) => {
    const map = {
      description: `Generate complete description, benefits, and precautions for "${pose.name}".`,
      literature_en: `Write complete English literature for "${pose.name}" with multiple pages.`,
      literature_hi: `"${pose.name}" के लिए पूर्ण हिंदी साहित्य लिखें।`,
      steps: `Create complete step-by-step guide for "${pose.name}".`,
    };
    return map[type] || '';
  };

  // ═══════════════════════════ IMAGE GENERATION ═══════════════════════════

  const generateImage = async (purpose, stepName) => {
    if (purpose === 'cover') setLoadingCover(true);
    else if (purpose === 'literature') setLoadingLitImg(true);
    else setLoadingStepImg(prev => ({ ...prev, [stepName]: true }));

    try {
      const res = await fetch('/api/ai/generate-image', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ poseName: pose.name, category: pose.category, purpose, stepName }),
      });
      const data = await res.json();
      if (data.error) throw new Error(data.error);

      if (purpose === 'cover') setGenCoverImage(data.imageUrl);
      else if (purpose === 'literature') setGenLiteratureImage(data.imageUrl);
      else setGenStepImages(prev => ({ ...prev, [stepName]: data.imageUrl }));
    } catch (err) {
      alert(`Error generating ${purpose} image: ` + err.message);
    }

    if (purpose === 'cover') setLoadingCover(false);
    else if (purpose === 'literature') setLoadingLitImg(false);
    else setLoadingStepImg(prev => ({ ...prev, [stepName]: false }));
  };

  // ═══════════════════════════ SAVE TO DB ═══════════════════════════

  const saveToDatabase = async () => {
    setSaving(true);
    setSaveMsg('');
    try {
      const updates = {};
      if (genDescription) updates.description = genDescription;
      if (genBenefits.length > 0) updates.benefits = genBenefits;
      if (genPrecautions.length > 0) updates.precautions = genPrecautions;
      if (genLiteratureEn) updates.literature_content = genLiteratureEn;
      if (genLiteratureHi) updates.literature_content_hindi = genLiteratureHi;
      if (genCoverImage) updates.cover_image_url = genCoverImage;
      if (genLiteratureImage) updates.literature_image_url = genLiteratureImage;

      if (Object.keys(updates).length > 0) {
        const { error } = await supabase.from('yoga_poses').update(updates).eq('id', pose.id);
        if (error) throw new Error('Pose update failed: ' + error.message);
      }

      if (genSteps.length > 0) {
        if (existingSteps?.length > 0) {
          await supabase.from('pose_steps').delete().eq('pose_id', pose.id);
        }
        const stepPayloads = genSteps.map((s, i) => ({
          pose_id: pose.id,
          step_number: s.step_number || i + 1,
          name: s.name || `Step ${i + 1}`,
          name_hindi: s.name_hindi || null,
          instruction: s.instruction || null,
          instruction_hindi: s.instruction_hindi || null,
          breathing: s.breathing || 'normal',
          mantra: s.mantra || null,
          duration_seconds: s.duration_seconds || 10,
          image_url: genStepImages[s.name] || null,
          tips: s.tips || [],
          display_order: s.step_number || i + 1,
        }));
        const { error } = await supabase.from('pose_steps').insert(stepPayloads);
        if (error) throw new Error('Steps insert failed: ' + error.message);
        await supabase.from('yoga_poses').update({ total_steps: stepPayloads.length }).eq('id', pose.id);
      }

      setSaveMsg('✅ All content saved successfully!');
      setTimeout(() => { if (onSaved) onSaved(); }, 1500);
    } catch (err) {
      setSaveMsg('❌ Error: ' + err.message);
    }
    setSaving(false);
  };

  // ── Helpers ──
  const hasContent = (existingVal, genVal) => {
    if (Array.isArray(existingVal)) return existingVal.length > 0 || (Array.isArray(genVal) && genVal.length > 0);
    return !!(existingVal || genVal);
  };

  const statusDot = (has) => (
    <span style={{
      display: 'inline-block', width: 8, height: 8, borderRadius: '50%',
      background: has ? '#22c55e' : '#ef4444', marginRight: 6, flexShrink: 0,
    }} />
  );

  // ═══════════════════════════ CONTEXT CARD ═══════════════════════════

  const renderContextCard = (type) => {
    const lines = [];
    if (type === 'description') {
      lines.push({ label: 'Description', value: pose.description ? `✅ ${pose.description.length} chars` : '❌ Missing' });
      lines.push({ label: 'Benefits', value: (pose.benefits?.length > 0) ? `✅ ${pose.benefits.length} items` : '❌ None' });
      lines.push({ label: 'Precautions', value: (pose.precautions?.length > 0) ? `✅ ${pose.precautions.length} items` : '❌ None' });
    } else if (type === 'literature') {
      const enPages = pose.literature_content ? (pose.literature_content.match(/---PAGE---/g) || []).length + 1 : 0;
      const hiPages = pose.literature_content_hindi ? (pose.literature_content_hindi.match(/---PAGE---/g) || []).length + 1 : 0;
      lines.push({ label: 'English', value: enPages > 0 ? `✅ ${enPages} pages` : '❌ Missing' });
      lines.push({ label: 'Hindi', value: hiPages > 0 ? `✅ ${hiPages} पृष्ठ` : '❌ Missing' });
      lines.push({ label: 'Images', value: literatureImages.length > 0 ? `✅ ${literatureImages.length} images` : '⚪ None' });
    } else if (type === 'steps') {
      lines.push({ label: 'Current Steps', value: (existingSteps?.length > 0) ? `✅ ${existingSteps.length} steps` : '❌ None' });
      lines.push({ label: 'Step Images', value: stepsWithImages > 0 ? `✅ ${stepsWithImages}/${allSteps.length}` : '❌ None' });
    }

    return (
      <div style={{
        background: 'linear-gradient(135deg, rgba(168,85,247,0.08), rgba(59,130,246,0.04))',
        border: '1px solid rgba(168,85,247,0.2)', borderRadius: 12, padding: '12px 16px', marginBottom: 16,
      }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
          <span style={{ fontSize: 16 }}>🎯</span>
          <div>
            <div style={{ fontWeight: 700, fontSize: 13 }}>{pose.name} {pose.name_hindi ? `• ${pose.name_hindi}` : ''}</div>
            <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{pose.category} {pose.name_sanskrit ? `• ${pose.name_sanskrit}` : ''} {existingSteps?.length > 0 ? `• ${existingSteps.length} steps` : ''}</div>
          </div>
        </div>
        <div style={{ display: 'flex', gap: 16, flexWrap: 'wrap' }}>
          {lines.map((l, i) => (
            <div key={i} style={{ fontSize: 11, color: 'var(--text-muted)' }}>
              <span style={{ fontWeight: 600 }}>{l.label}:</span> {l.value}
            </div>
          ))}
        </div>
      </div>
    );
  };

  // ═══════════════════════════ CHAT UI ═══════════════════════════

  const renderChatInterface = (chatKey, apiType, suggestions) => {
    const messages = chatMessages[chatKey] || [];
    const isLoading = loadingTab === apiType || (chatKey === 'literature' && (loadingTab === 'literature_en' || loadingTab === 'literature_hi'));

    return (
      <div style={{ display: 'flex', flexDirection: 'column', height: '100%' }}>
        {/* Context Card */}
        {renderContextCard(chatKey)}

        {/* Chat Messages */}
        <div style={{
          flex: 1, overflow: 'auto', marginBottom: 12, minHeight: 80,
          border: '1px solid var(--border)', borderRadius: 12, padding: 12,
          background: '#09090b',
        }}>
          {messages.length === 0 && (
            <div style={{ textAlign: 'center', padding: '20px 0', color: 'var(--text-muted)' }}>
              <div style={{ fontSize: 28, marginBottom: 6 }}>🤖</div>
              <div style={{ fontSize: 12 }}>Ready to generate. Type your instruction below<br />or click a suggestion to start.</div>
            </div>
          )}

          {messages.map((msg, i) => (
            <div key={i} style={{
              display: 'flex', gap: 8, marginBottom: 10,
              flexDirection: msg.role === 'user' ? 'row-reverse' : 'row',
            }}>
              <div style={{
                width: 28, height: 28, borderRadius: '50%', flexShrink: 0,
                background: msg.role === 'user' ? '#3b82f6' : msg.isError ? '#ef4444' : '#a855f7',
                display: 'flex', alignItems: 'center', justifyContent: 'center',
                fontSize: 13,
              }}>
                {msg.role === 'user' ? '👤' : '🤖'}
              </div>
              <div style={{
                maxWidth: '85%', padding: '8px 12px', borderRadius: 12,
                background: msg.role === 'user' ? '#1e3a5f' : msg.isError ? 'rgba(239,68,68,0.1)' : '#1a1a2e',
                border: `1px solid ${msg.role === 'user' ? '#2563eb33' : msg.isError ? '#ef444433' : '#a855f722'}`,
                fontSize: 12, lineHeight: 1.6, whiteSpace: 'pre-wrap',
              }}>
                {msg.content}
              </div>
            </div>
          ))}

          {isLoading && (
            <div style={{ display: 'flex', gap: 8, marginBottom: 10 }}>
              <div style={{
                width: 28, height: 28, borderRadius: '50%', flexShrink: 0,
                background: '#a855f7', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13,
              }}>🤖</div>
              <div style={{
                padding: '8px 12px', borderRadius: 12, background: '#1a1a2e',
                border: '1px solid #a855f722', fontSize: 12,
              }}>
                <span className="ai-pulse">⏳ Generating...</span>
              </div>
            </div>
          )}

          <div ref={chatEndRef} />
        </div>

        {/* Quick Suggestions */}
        {suggestions && (
          <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8 }}>
            {suggestions.map((s, i) => (
              <button key={i} className="ai-btn" onClick={() => {
                setUserInstruction(s.instruction);
              }} style={{ fontSize: 10, padding: '4px 10px' }}>
                {s.label}
              </button>
            ))}
          </div>
        )}

        {/* Image Upload Preview */}
        {uploadedImages.length > 0 && (
          <div style={{
            display: 'flex', gap: 6, flexWrap: 'wrap', marginBottom: 8,
            padding: 8, borderRadius: 10, background: 'rgba(99,102,241,0.08)',
            border: '1px solid rgba(99,102,241,0.2)',
          }}>
            {uploadedImages.map(img => (
              <div key={img.id} style={{ position: 'relative', width: 56, height: 56, borderRadius: 8, overflow: 'hidden', border: '1px solid rgba(255,255,255,0.1)' }}>
                <img src={img.dataUrl} alt={img.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                <button
                  onClick={() => removeUploadedImage(img.id)}
                  style={{
                    position: 'absolute', top: 1, right: 1, width: 18, height: 18,
                    borderRadius: '50%', border: 'none', background: 'rgba(0,0,0,0.7)',
                    color: '#fff', fontSize: 10, cursor: 'pointer', display: 'flex',
                    alignItems: 'center', justifyContent: 'center', lineHeight: 1,
                  }}
                >✕</button>
              </div>
            ))}
            <div style={{ display: 'flex', alignItems: 'center', fontSize: 11, color: '#818cf8', fontWeight: 600, paddingLeft: 6 }}>
              📷 {uploadedImages.length} page{uploadedImages.length > 1 ? 's' : ''} — will use Vision AI
            </div>
          </div>
        )}

        {/* Hidden file input */}
        <input
          ref={imageInputRef}
          type="file"
          accept="image/*"
          multiple
          onChange={handleImageUpload}
          style={{ display: 'none' }}
        />

        {/* Instruction Input */}
        <div style={{ display: 'flex', gap: 8 }}>
          {/* Image upload button — only for literature tabs */}
          {(chatKey === 'literature') && (
            <button
              className="ai-btn"
              onClick={() => imageInputRef.current?.click()}
              title="Upload book page images for AI to read"
              style={{
                alignSelf: 'flex-end', padding: '8px 10px', fontSize: 14,
                background: uploadedImages.length > 0 ? 'rgba(99,102,241,0.15)' : 'transparent',
                borderColor: uploadedImages.length > 0 ? '#818cf8' : undefined,
                position: 'relative',
              }}
            >
              📷
              {uploadedImages.length > 0 && (
                <span style={{
                  position: 'absolute', top: -4, right: -4, width: 16, height: 16,
                  borderRadius: '50%', background: '#818cf8', color: '#fff',
                  fontSize: 9, fontWeight: 700, display: 'flex',
                  alignItems: 'center', justifyContent: 'center',
                }}>{uploadedImages.length}</span>
              )}
            </button>
          )}
          <textarea
            className="ai-textarea"
            rows={2}
            value={userInstruction}
            onChange={e => setUserInstruction(e.target.value)}
            placeholder={chatKey === 'literature' && uploadedImages.length > 0
              ? 'Describe what to extract from these book pages...'
              : "Type your instruction... (e.g., 'Focus on health benefits', 'Make it more detailed')"}
            onKeyDown={e => {
              if (e.key === 'Enter' && !e.shiftKey) {
                e.preventDefault();
                if (!isLoading) generateWithChat(apiType, userInstruction);
              }
            }}
            style={{ flex: 1, fontSize: 12 }}
          />
          <button
            className="ai-btn ai-btn-primary"
            onClick={() => generateWithChat(apiType, userInstruction)}
            disabled={isLoading}
            style={{ background: '#a855f7', borderColor: '#a855f7', alignSelf: 'flex-end', padding: '8px 16px' }}
          >
            {isLoading ? '⏳' : '▶'} {uploadedImages.length > 0 ? '📖 Read & Generate' : 'Generate'}
          </button>
        </div>
      </div>
    );
  };

  // ═══════════════════════════ RENDER ═══════════════════════════

  return (
    <>
    {/* Backdrop — semi-transparent, click to close */}
    <div onClick={onClose} style={{
      position: 'fixed', top: 0, left: 0, bottom: 0, right: 0,
      background: 'rgba(0,0,0,0.5)', backdropFilter: 'blur(3px)', zIndex: 999,
    }} />

    {/* Right Panel — full-height chat interface */}
    <div style={{
      position: 'fixed', top: 0, right: 0, bottom: 0,
      width: 560, zIndex: 1001, display: 'flex', flexDirection: 'row',
      animation: 'aiSlideIn 0.3s cubic-bezier(0.16, 1, 0.3, 1)',
    }}>

    <style>{`
      @keyframes aiSlideIn { from { transform: translateX(100%); } to { transform: translateX(0); } }
      @keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.5; } }
      .ai-pulse { animation: pulse 1.5s infinite; }
      .ai-btn { padding: 8px 14px; border-radius: 8px; border: 1px solid var(--border); background: #0f0f12; color: var(--text-primary); cursor: pointer; font-size: 12px; font-weight: 600; transition: all 0.2s; display: inline-flex; align-items: center; gap: 6px; }
      .ai-btn:hover { border-color: var(--accent); color: var(--accent); background: #1e1e23; }
      .ai-btn:disabled { opacity: 0.5; cursor: wait; }
      .ai-btn-primary { background: var(--accent); color: #fff; border-color: var(--accent); }
      .ai-btn-primary:hover { opacity: 0.9; }
      .ai-tab { padding: 10px 16px; border: none; background: transparent; cursor: pointer; font-weight: 600; font-size: 13px; color: var(--text-muted); border-bottom: 2px solid transparent; transition: all 0.2s; white-space: nowrap; }
      .ai-tab:hover { color: var(--text-primary); }
      .ai-tab.active { color: var(--accent); border-bottom-color: var(--accent); }
      .ai-textarea { width: 100%; padding: 10px; border-radius: 8px; border: 1px solid var(--border); background: #09090b; color: var(--text-primary); font-size: 13px; font-family: inherit; resize: vertical; }
      .ai-textarea:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px rgba(212,165,116,0.12); }
      .gen-badge { display: inline-flex; align-items: center; gap: 3px; padding: 2px 8px; border-radius: 10px; font-size: 10px; font-weight: 700; background: rgba(168,85,247,0.15); color: #a855f7; }
    `}</style>

    {/* ── Narrow Controls Strip (left edge) ── */}
    <div style={{
      width: 56, flexShrink: 0, background: '#111114', borderRight: '1px solid var(--border)',
      display: 'flex', flexDirection: 'column', alignItems: 'center', padding: '12px 0', gap: 8,
    }}>
      {/* Score Ring */}
      <div style={{
        width: 40, height: 40, borderRadius: '50%', display: 'flex',
        alignItems: 'center', justifyContent: 'center', fontWeight: 800, fontSize: 11,
        background: `conic-gradient(${contentScore >= 75 ? '#22c55e' : contentScore >= 50 ? '#f59e0b' : '#ef4444'} ${contentScore * 3.6}deg, #333 0deg)`,
      }}>
        <span style={{
          width: 32, height: 32, borderRadius: '50%', background: '#111114',
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: contentScore >= 75 ? '#22c55e' : contentScore >= 50 ? '#f59e0b' : '#ef4444',
        }}>{contentScore}%</span>
      </div>

      <div style={{ width: 32, height: 1, background: 'var(--border)' }} />

      {/* Status Dots */}
      {[
        { has: hasContent(pose.description, genDescription), label: 'D' },
        { has: hasContent(pose.benefits, genBenefits), label: 'B' },
        { has: hasContent(pose.literature_content, genLiteratureEn), label: 'L' },
        { has: hasContent(existingSteps?.length > 0, genSteps.length > 0), label: 'S' },
      ].map((d, i) => (
        <div key={i} title={['Description','Benefits','Literature','Steps'][i]} style={{
          width: 28, height: 28, borderRadius: 6, display: 'flex', alignItems: 'center', justifyContent: 'center',
          fontSize: 10, fontWeight: 700, background: d.has ? 'rgba(34,197,94,0.15)' : 'rgba(239,68,68,0.1)',
          color: d.has ? '#22c55e' : '#ef4444', cursor: 'default',
        }}>{d.label}</div>
      ))}

      <div style={{ flex: 1 }} />

      {/* Preview Toggle */}
      <button onClick={() => setShowPreview(!showPreview)} title="Toggle Preview" style={{
        width: 36, height: 36, borderRadius: 8, border: 'none', cursor: 'pointer',
        background: showPreview ? '#7c3aed' : '#27272a',
        color: showPreview ? '#fff' : '#a1a1aa', fontSize: 16,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>📱</button>

      {/* Save */}
      <button onClick={saveToDatabase} disabled={saving} title="Save to Database" style={{
        width: 36, height: 36, borderRadius: 8, border: 'none', cursor: 'pointer',
        background: '#a855f7', color: '#fff', fontSize: 14,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        opacity: saving ? 0.5 : 1,
      }}>{saving ? '⏳' : '💾'}</button>

      {/* Close */}
      <button onClick={onClose} title="Close" style={{
        width: 36, height: 36, borderRadius: 8, border: 'none', cursor: 'pointer',
        background: '#27272a', color: '#a1a1aa', fontSize: 14,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
      }}>✕</button>
    </div>

    {/* ── Main Content Panel ── */}
    <div style={{
      flex: 1, background: '#18181b', display: 'flex', flexDirection: 'column',
      boxShadow: '-8px 0 40px rgba(0,0,0,0.6)',
    }}>
      {/* ── Header ── */}
      <div style={{
        padding: '16px 20px', borderBottom: '1px solid var(--border)',
        display: 'flex', justifyContent: 'space-between', alignItems: 'center',
        background: 'linear-gradient(135deg, #1a1525, #151520)',
      }}>
        <div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
            <span style={{ fontSize: 20 }}>🤖</span>
            <h2 style={{ margin: 0, fontSize: 18 }}>Disha AI</h2>
            <span style={{ width: 8, height: 8, borderRadius: '50%', background: '#22c55e' }} />
          </div>
          <div style={{ fontSize: 12, color: 'var(--text-muted)', marginTop: 4 }}>
            {pose.name} {pose.name_hindi ? `• ${pose.name_hindi}` : ''} • <span className="badge">{pose.category}</span>
          </div>
        </div>
        {saveMsg && (
          <div style={{
            fontSize: 11, padding: '4px 10px', borderRadius: 8,
            background: saveMsg.startsWith('✅') ? 'rgba(34,197,94,0.15)' : 'rgba(239,68,68,0.15)',
            color: saveMsg.startsWith('✅') ? '#22c55e' : '#ef4444',
          }}>{saveMsg}</div>
        )}
      </div>

      {/* ── Tabs ── */}
      <div style={{ display: 'flex', borderBottom: '1px solid var(--border)', overflowX: 'auto' }}>
        {[
          { key: 'overview', label: 'Overview' },
          { key: 'description', label: 'Description', badge: genDescription ? '✨' : null },
          { key: 'literature', label: 'Literature', badge: (genLiteratureEn || genLiteratureHi) ? '✨' : null },
          { key: 'steps', label: `Steps`, badge: genSteps.length > 0 ? '✨' : null },
          { key: 'images', label: 'Images' },
        ].map(t => (
          <button key={t.key} onClick={() => setTab(t.key)} className={`ai-tab ${tab === t.key ? 'active' : ''}`}>
            {t.label} {t.badge && <span className="gen-badge">{t.badge} AI</span>}
          </button>
        ))}
      </div>

      {/* ── Content Area (full-height scrollable) ── */}
      <div style={{ flex: 1, overflow: 'auto', padding: 20, display: 'flex', flexDirection: 'column' }}>

        {/* ──── OVERVIEW TAB ──── */}
        {tab === 'overview' && (
          <div>
            <div style={{
              background: 'linear-gradient(135deg, rgba(168,85,247,0.06), rgba(59,130,246,0.04))',
              border: '1px solid var(--border)', borderRadius: 14, padding: 20, marginBottom: 16, textAlign: 'center',
            }}>
              <div style={{ fontSize: 40, marginBottom: 8 }}>🤖</div>
              <h3 style={{ margin: '0 0 8px' }}>AI Content Generator</h3>
              <p style={{ color: 'var(--text-muted)', fontSize: 13, margin: 0 }}>
                Generate professional content for <strong>{pose.name}</strong> using AI.<br />
                Each section has a <strong>chat interface</strong> — give instructions and AI will generate content.
              </p>
            </div>

            <div style={{ fontSize: 13, color: 'var(--text-muted)' }}>
              <h4 style={{ color: 'var(--text)', marginBottom: 8 }}>How it works:</h4>
              <ol style={{ paddingLeft: 20, lineHeight: 2 }}>
                <li>Go to <strong>Description</strong>, <strong>Literature</strong>, or <strong>Steps</strong> tab</li>
                <li>See the <strong>context card</strong> showing current data status</li>
                <li>Type your <strong>instruction</strong> or click a suggestion</li>
                <li>Click <strong>Generate</strong> — AI generates with full context</li>
                <li><strong>Edit</strong> the generated content below</li>
                <li>Click <strong>"💾 Save All to Database"</strong> when satisfied</li>
              </ol>
              <p style={{ marginTop: 12, padding: '8px 12px', borderRadius: 8, background: 'rgba(245,158,11,0.1)', borderLeft: '3px solid #f59e0b' }}>
                ⚠️ <strong>Note:</strong> Saving steps will <strong>replace</strong> all existing steps for this pose.
                Existing steps: <strong>{existingSteps?.length || 0}</strong>
              </p>
            </div>

            {/* Quick Launch Buttons */}
            <div style={{ marginTop: 20 }}>
              <h4 style={{ marginBottom: 10, color: 'var(--text)' }}>Quick Start:</h4>
              <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                <button className="ai-btn" onClick={() => setTab('description')} style={{ padding: '10px 16px' }}>
                  📝 Description + Benefits
                </button>
                <button className="ai-btn" onClick={() => setTab('literature')} style={{ padding: '10px 16px' }}>
                  📖 Literature
                </button>
                <button className="ai-btn" onClick={() => setTab('steps')} style={{ padding: '10px 16px' }}>
                  🪜 Steps
                </button>
                <button className="ai-btn" onClick={() => setTab('images')} style={{ padding: '10px 16px' }}>
                  🖼️ Images
                </button>
              </div>
            </div>
          </div>
        )}

        {/* ──── DESCRIPTION TAB ──── */}
        {tab === 'description' && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
            {renderChatInterface('description', 'description', [
                { label: '🔄 Generate fresh', instruction: `Generate a complete fresh description, benefits, and precautions for "${pose.name}".` },
                { label: '✏️ Improve existing', instruction: `Improve and enhance the existing description. Make it more detailed and professional.` },
                { label: '➕ Add more benefits', instruction: `Keep the existing description but add 3-4 more specific health benefits.` },
                { label: '⚠️ Add precautions', instruction: `Focus on generating more detailed precautions and contraindications.` },
              ])}

            {/* Editable Content Below Chat */}
            {(genDescription || pose.description) && (
              <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
                <h4 style={{ marginTop: 0, marginBottom: 8, display: 'flex', alignItems: 'center', gap: 8, fontSize: 13 }}>
                  📝 Description {genDescription && <span className="gen-badge">✨ AI</span>}
                </h4>
                <textarea className="ai-textarea" rows={3}
                  value={genDescription || pose.description || ''}
                  onChange={e => setGenDescription(e.target.value)}
                  placeholder="Description..."
                />

                <h4 style={{ marginTop: 14, marginBottom: 6, fontSize: 13, display: 'flex', alignItems: 'center', gap: 8 }}>
                  ✅ Benefits {genBenefits.length > 0 && <span className="gen-badge">✨ {genBenefits.length}</span>}
                </h4>
                <textarea className="ai-textarea" rows={4}
                  value={(genBenefits.length > 0 ? genBenefits : (pose.benefits || [])).join('\n')}
                  onChange={e => setGenBenefits(e.target.value.split('\n').filter(Boolean))}
                  placeholder="One benefit per line..."
                  style={{ fontSize: 12 }}
                />

                <h4 style={{ marginTop: 14, marginBottom: 6, fontSize: 13, display: 'flex', alignItems: 'center', gap: 8 }}>
                  ⚠️ Precautions {genPrecautions.length > 0 && <span className="gen-badge">✨ {genPrecautions.length}</span>}
                </h4>
                <textarea className="ai-textarea" rows={3}
                  value={(genPrecautions.length > 0 ? genPrecautions : (pose.precautions || [])).join('\n')}
                  onChange={e => setGenPrecautions(e.target.value.split('\n').filter(Boolean))}
                  placeholder="One precaution per line..."
                  style={{ fontSize: 12 }}
                />
              </div>
            )}
          </div>
        )}

        {/* ──── LITERATURE TAB ──── */}
        {tab === 'literature' && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>

            {/* Existing Content — Collapsible panels for comparison */}
            {(pose.literature_content || pose.literature_content_hindi) && (
              <div style={{ marginBottom: 16 }}>
                <div style={{
                  fontSize: 11, fontWeight: 700, color: '#f59e0b', textTransform: 'uppercase',
                  marginBottom: 8, display: 'flex', alignItems: 'center', gap: 6,
                }}>
                  📋 Existing Content (Database) — for comparison
                </div>

                {/* English existing */}
                {pose.literature_content && (
                  <details style={{ marginBottom: 8 }}>
                    <summary style={{
                      cursor: 'pointer', fontSize: 12, fontWeight: 600, color: 'var(--text-muted)',
                      padding: '6px 10px', background: '#0f0f12', borderRadius: 8,
                      border: '1px solid var(--border)', userSelect: 'none',
                    }}>
                      🇬🇧 English — {(pose.literature_content.match(/---PAGE---/g) || []).length + 1} pages
                      • {pose.literature_content.length} chars
                      • {(pose.literature_content.match(/\{\{IMG/g) || []).length} images
                    </summary>
                    <div style={{
                      padding: 10, background: '#09090b', borderRadius: '0 0 8px 8px',
                      border: '1px solid var(--border)', borderTop: 'none',
                      fontSize: 11, color: 'var(--text-muted)', whiteSpace: 'pre-wrap',
                      maxHeight: 200, overflow: 'auto', lineHeight: 1.5,
                    }}>
                      {pose.literature_content}
                    </div>
                  </details>
                )}

                {/* Hindi existing */}
                {pose.literature_content_hindi && (
                  <details style={{ marginBottom: 8 }}>
                    <summary style={{
                      cursor: 'pointer', fontSize: 12, fontWeight: 600, color: 'var(--text-muted)',
                      padding: '6px 10px', background: '#0f0f12', borderRadius: 8,
                      border: '1px solid var(--border)', userSelect: 'none',
                    }}>
                      🇮🇳 Hindi — {(pose.literature_content_hindi.match(/---PAGE---/g) || []).length + 1} पृष्ठ
                      • {pose.literature_content_hindi.length} chars
                      • {(pose.literature_content_hindi.match(/\{\{IMG/g) || []).length} images
                    </summary>
                    <div style={{
                      padding: 10, background: '#09090b', borderRadius: '0 0 8px 8px',
                      border: '1px solid var(--border)', borderTop: 'none',
                      fontSize: 11, color: 'var(--text-muted)', whiteSpace: 'pre-wrap',
                      maxHeight: 200, overflow: 'auto', lineHeight: 1.5,
                    }}>
                      {pose.literature_content_hindi}
                    </div>
                  </details>
                )}
              </div>
            )}

            {/* Language generate buttons */}
            <div style={{ display: 'flex', gap: 8, marginBottom: 12 }}>
              <button className={`ai-btn ${loadingTab === 'literature_en' ? 'ai-btn-primary' : ''}`}
                onClick={() => generateWithChat('literature_en', userInstruction || getDefaultInstruction('literature_en'))}
                disabled={!!loadingTab}
                style={{ flex: 1 }}
              >
                {loadingTab === 'literature_en' ? '⏳ Generating...' : '🇬🇧 Generate English'}
              </button>
              <button className={`ai-btn ${loadingTab === 'literature_hi' ? 'ai-btn-primary' : ''}`}
                onClick={() => generateWithChat('literature_hi', userInstruction || getDefaultInstruction('literature_hi'))}
                disabled={!!loadingTab}
                style={{ flex: 1 }}
              >
                {loadingTab === 'literature_hi' ? '⏳ Generating...' : '🇮🇳 Generate Hindi'}
              </button>
            </div>

            {renderChatInterface('literature', 'literature_en', [
                { label: '🇬🇧 Fresh English', instruction: `Write complete English literature for "${pose.name}" with 4 pages. Include image markers {{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}} and headings. Write like a premium illustrated book.` },
                { label: '🇮🇳 Fresh Hindi', instruction: `"${pose.name}" के लिए पूर्ण हिंदी साहित्य लिखें — {{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}} मार्कर और ## शीर्षक के साथ। एक प्रीमियम पुस्तक जैसा लिखें।` },
                { label: '📖 More pages', instruction: `Expand the literature with 2 more pages covering advanced variations and common mistakes. Include {{IMG_LEFT:POSE_IMAGE_PLACEHOLDER}} markers.` },
                { label: '🕉️ Add Sanskrit', instruction: `Include more Sanskrit shlokas and their meanings in the literature. Use **bold** for shloka text and *italic* for translations.` },
              ])}

            {/* AI Generated Content — Editable */}
            {genLiteratureEn && (
              <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
                <h4 style={{ marginTop: 0, marginBottom: 8, fontSize: 13, display: 'flex', alignItems: 'center', gap: 8 }}>
                  📖 English Literature <span className="gen-badge">✨ AI Generated</span>
                  <span style={{ fontSize: 10, color: 'var(--text-muted)', fontWeight: 400 }}>
                    ({(genLiteratureEn.match(/---PAGE---/g) || []).length + 1} pages
                    • {(genLiteratureEn.match(/\{\{IMG/g) || []).length} image markers)
                  </span>
                </h4>
                <textarea className="ai-textarea" rows={10}
                  value={genLiteratureEn}
                  onChange={e => setGenLiteratureEn(e.target.value)}
                  placeholder="English literature... Pages separated by ---PAGE---"
                  style={{ fontSize: 12 }}
                />
              </div>
            )}
            {genLiteratureHi && (
              <div style={{ marginTop: 14 }}>
                <h4 style={{ marginTop: 0, marginBottom: 8, fontSize: 13, display: 'flex', alignItems: 'center', gap: 8 }}>
                  📖 Hindi साहित्य <span className="gen-badge">✨ AI Generated</span>
                  <span style={{ fontSize: 10, color: 'var(--text-muted)', fontWeight: 400 }}>
                    ({(genLiteratureHi.match(/---PAGE---/g) || []).length + 1} पृष्ठ
                    • {(genLiteratureHi.match(/\{\{IMG/g) || []).length} image markers)
                  </span>
                </h4>
                <textarea className="ai-textarea" rows={10}
                  value={genLiteratureHi}
                  onChange={e => setGenLiteratureHi(e.target.value)}
                  placeholder="Hindi literature... ---PAGE--- से पृष्ठ अलग करें"
                  style={{ fontSize: 12 }}
                />
              </div>
            )}

            {/* Note about saving */}
            {(genLiteratureEn || genLiteratureHi) && (
              <div style={{
                marginTop: 12, padding: '8px 12px', borderRadius: 8,
                background: 'rgba(168,85,247,0.08)', border: '1px solid rgba(168,85,247,0.2)',
                fontSize: 11, color: '#a855f7',
              }}>
                💡 AI generated content will <strong>replace</strong> existing content only when you click "Save All to Database".
                You can compare with existing content above before saving.
              </div>
            )}
          </div>
        )}

        {/* ──── STEPS TAB ──── */}
        {tab === 'steps' && (
          <div style={{ flex: 1, display: 'flex', flexDirection: 'column' }}>
            {renderChatInterface('steps', 'steps', [
                { label: '🔄 Generate fresh', instruction: `Create a complete step-by-step guide for "${pose.name}" with all fields including Hindi, breathing, mantras, and tips.` },
                { label: '➕ More steps', instruction: `Create more detailed steps with additional transition poses and preparation steps.` },
                { label: '🕉️ Add mantras', instruction: `Regenerate steps with proper Sanskrit mantras for each step.` },
                { label: '⏱️ Adjust timings', instruction: `Regenerate with more realistic durations — longer holds for main poses, shorter for transitions.` },
              ])}

            {/* Step Cards */}
            {(genSteps.length > 0 || existingSteps?.length > 0) && (
              <div style={{ marginTop: 16, borderTop: '1px solid var(--border)', paddingTop: 16 }}>
                <h4 style={{ marginTop: 0, marginBottom: 8, fontSize: 13, display: 'flex', alignItems: 'center', gap: 8 }}>
                  🪜 Steps ({genSteps.length > 0 ? genSteps.length : existingSteps?.length || 0})
                  {genSteps.length > 0 && <span className="gen-badge">✨ AI Generated</span>}
                  {genSteps.length === 0 && existingSteps?.length > 0 && (
                    <span style={{ fontSize: 10, color: 'var(--text-muted)', fontWeight: 400 }}>Existing — generate new to replace</span>
                  )}
                </h4>

                {(genSteps.length > 0 ? genSteps : existingSteps || []).map((s, i) => (
                  <StepCard key={s.id || i} step={s} index={i}
                    readOnly={genSteps.length === 0}
                    onUpdate={genSteps.length > 0 ? (field, value) => {
                      const updated = [...genSteps];
                      updated[i] = { ...updated[i], [field]: value };
                      setGenSteps(updated);
                    } : undefined}
                    imageUrl={genStepImages[s.name] || s.image_url}
                    imageLoading={loadingStepImg[s.name]}
                    onGenerateImage={genSteps.length > 0 ? () => generateImage('step', s.name) : undefined}
                  />
                ))}
              </div>
            )}
          </div>
        )}

        {/* ──── IMAGES TAB ──── */}
        {tab === 'images' && (
          <div>
            {/* Step Images Grid */}
            <h4 style={{ marginTop: 0, marginBottom: 4, display: 'flex', alignItems: 'center', gap: 8 }}>
              🧘 Step / Pose Images
              <span style={{ fontSize: 11, fontWeight: 400, color: 'var(--text-muted)' }}>
                ({stepsWithImages}/{allSteps.length} steps have images)
              </span>
            </h4>
            <p style={{ fontSize: 11, color: 'var(--text-muted)', margin: '0 0 12px' }}>Images used in pose steps — shown in the practical/step view</p>
            {allSteps.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 8, marginBottom: 24 }}>
                {allSteps.map((s, i) => {
                  const imgUrl = genStepImages[s.name] || s.image_url;
                  return (
                    <div key={s.id || i} style={{
                      borderRadius: 10, border: '1px solid var(--border)', overflow: 'hidden', background: '#0f0f12',
                    }}>
                      <div style={{
                        width: '100%', aspectRatio: '1', display: 'flex',
                        alignItems: 'center', justifyContent: 'center', overflow: 'hidden',
                        background: imgUrl ? 'transparent' : '#1a1a1f',
                      }}>
                        {imgUrl ? (
                          <img src={imgUrl} alt={s.name} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                        ) : (
                          <div style={{ textAlign: 'center', padding: 8 }}>
                            <div style={{ fontSize: 20, marginBottom: 2 }}>🖼️</div>
                            <div style={{ fontSize: 9, color: 'var(--text-muted)' }}>No image</div>
                          </div>
                        )}
                      </div>
                      <div style={{ padding: '6px 8px', borderTop: '1px solid var(--border)' }}>
                        <div style={{ fontSize: 10, fontWeight: 600, color: 'var(--text)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {s.step_number || i + 1}. {s.name}
                        </div>
                        {s.name_hindi && <div style={{ fontSize: 9, color: 'var(--text-muted)' }}>{s.name_hindi}</div>}
                        <div style={{ fontSize: 9, color: imgUrl ? '#22c55e' : '#ef4444', marginTop: 2, fontWeight: 600 }}>
                          {imgUrl ? '✓ Has image' : '✗ Missing'}
                        </div>
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)', border: '1px dashed var(--border)', borderRadius: 12, marginBottom: 24 }}>
                <div style={{ fontSize: 28, marginBottom: 6 }}>🪜</div>
                <p style={{ margin: 0, fontSize: 12 }}>No steps yet. Generate steps first to see step images.</p>
              </div>
            )}

            {/* Literature Embedded Images */}
            <h4 style={{ marginBottom: 4, display: 'flex', alignItems: 'center', gap: 8 }}>
              📖 Literature Images
              <span style={{ fontSize: 11, fontWeight: 400, color: 'var(--text-muted)' }}>({literatureImages.length} found)</span>
            </h4>
            <p style={{ fontSize: 11, color: 'var(--text-muted)', margin: '0 0 12px' }}>Images embedded in literature content via {'{{IMG_LEFT:url}}'} / {'{{IMG:url}}'} markers</p>
            {literatureImages.length > 0 ? (
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 10 }}>
                {literatureImages.map((url, i) => {
                  const usedInStep = allSteps.some(s => (s.image_url || '') === url);
                  return (
                    <div key={i} style={{
                      borderRadius: 10, border: '1px solid var(--border)', overflow: 'hidden',
                      background: '#0f0f12', position: 'relative',
                    }}>
                      <img src={url} alt={`Literature ${i + 1}`} style={{ width: '100%', height: 140, objectFit: 'contain', background: '#1a1a1f' }} />
                      <div style={{ padding: '6px 8px', borderTop: '1px solid var(--border)' }}>
                        <div style={{ fontSize: 9, color: 'var(--text-muted)', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {url.split('/').pop()}
                        </div>
                        {usedInStep && (
                          <div style={{ fontSize: 9, color: '#a855f7', marginTop: 2, fontWeight: 600 }}>🔗 Also used in steps</div>
                        )}
                      </div>
                    </div>
                  );
                })}
              </div>
            ) : (
              <div style={{ textAlign: 'center', padding: 30, color: 'var(--text-muted)', border: '1px dashed var(--border)', borderRadius: 12 }}>
                <div style={{ fontSize: 28, marginBottom: 6 }}>📖</div>
                <p style={{ margin: 0, fontSize: 12 }}>No images found in literature content.</p>
              </div>
            )}
          </div>
        )}
      </div>
    </div>{/* /main panel */}
    </div>{/* /right panel */}

    {/* Live Phone Preview — separate floating overlay on the left */}
    {showPreview && (
      <div onClick={e => e.stopPropagation()} style={{
        position: 'fixed', top: 0, left: 0, bottom: 0,
        width: 'calc(100% - 560px)', zIndex: 1000,
        display: 'flex', alignItems: 'center', justifyContent: 'center',
        background: 'transparent',
        pointerEvents: 'none',
      }}>
        <div style={{ pointerEvents: 'auto' }}>
          <AppPreview pose={mergedPose} steps={mergedSteps} linkedSession={pose.sessions} inline={true} />
        </div>
      </div>
    )}

    </>
  );
}

// ═══════════════════════════ SUB-COMPONENTS ═══════════════════════════

function StepCard({ step, index, readOnly, onUpdate, imageUrl, imageLoading, onGenerateImage }) {
  const breathColors = { inhale: '#22c55e', exhale: '#60a5fa', hold: '#f59e0b', normal: '#94a3b8' };

  return (
    <div style={{
      border: '1px solid var(--border)', borderRadius: 12, padding: 14, marginBottom: 10,
      background: readOnly ? '#0f0f12' : '#151518',
    }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{
            width: 26, height: 26, borderRadius: '50%', background: 'var(--accent)',
            color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center',
            fontSize: 12, fontWeight: 700,
          }}>{step.step_number || index + 1}</span>
          <div>
            {readOnly ? (
              <div style={{ fontWeight: 600, fontSize: 13 }}>{step.name}</div>
            ) : (
              <input value={step.name || ''} onChange={e => onUpdate?.('name', e.target.value)}
                style={{
                  fontWeight: 600, fontSize: 13, background: 'transparent', border: 'none',
                  borderBottom: '1px dashed var(--border)', color: 'var(--text)', padding: '2px 0', width: 200,
                }}
              />
            )}
            {step.name_hindi && <div style={{ fontSize: 11, color: 'var(--text-muted)' }}>{step.name_hindi}</div>}
          </div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <span style={{
            padding: '2px 8px', borderRadius: 10, fontSize: 10, fontWeight: 700,
            background: `${breathColors[step.breathing] || breathColors.normal}22`,
            color: breathColors[step.breathing] || breathColors.normal,
          }}>
            {step.breathing || 'normal'}
          </span>
          <span style={{ fontSize: 11, color: 'var(--text-muted)' }}>{step.duration_seconds}s</span>
        </div>
      </div>

      <div style={{ fontSize: 12, color: 'var(--text-secondary)', marginBottom: 4, lineHeight: 1.5 }}>
        {readOnly ? step.instruction : (
          <textarea className="ai-textarea" rows={2} value={step.instruction || ''}
            onChange={e => onUpdate?.('instruction', e.target.value)}
            style={{ fontSize: 12 }}
          />
        )}
      </div>

      {step.mantra && (
        <div style={{ fontSize: 11, color: '#a855f7', fontStyle: 'italic', marginTop: 4 }}>🕉️ {step.mantra}</div>
      )}

      {step.tips?.length > 0 && (
        <div style={{ marginTop: 6 }}>
          {step.tips.map((t, i) => (
            <div key={i} style={{ fontSize: 11, color: '#f59e0b', marginTop: 2 }}>💡 {t}</div>
          ))}
        </div>
      )}

      {/* Step image */}
      {!readOnly && (
        <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 8 }}>
          {imageUrl && <img src={imageUrl} alt="" style={{ width: 48, height: 48, borderRadius: 8, objectFit: 'cover' }} />}
          <button className="ai-btn" onClick={onGenerateImage} disabled={imageLoading}
            style={{ fontSize: 11, padding: '4px 10px' }}>
            {imageLoading ? '⏳' : '🖼️'} {imageLoading ? 'Generating...' : (imageUrl ? 'Regenerate' : 'Gen Image')}
          </button>
        </div>
      )}
    </div>
  );
}

'use client';

import { useState, useRef } from 'react';
import { createClient } from '@/lib/supabase';

/**
 * Reusable media uploader component for the admin dashboard.
 * Uploads files to Supabase Storage and returns the public URL.
 * 
 * Usage:
 *   <MediaUploader
 *     bucket="session-media"
 *     folder="poses"
 *     accept="image/*"
 *     label="Pose Image"
 *     value={form.image_url}
 *     onChange={(url) => setForm({ ...form, image_url: url })}
 *   />
 */
export default function MediaUploader({
  bucket = 'session-media',
  folder = '',
  accept = 'image/*',
  label = 'Upload File',
  value = '',
  onChange,
  maxSizeMB = 50,
  showPreview = true,
}) {
  const supabase = createClient();
  const fileRef = useRef(null);
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState(0);
  const [error, setError] = useState('');
  const [dragOver, setDragOver] = useState(false);

  const isImage = accept.includes('image');
  const isVideo = accept.includes('video');
  const isAudio = accept.includes('audio');

  const getFileType = () => {
    if (isImage) return 'image';
    if (isVideo) return 'video';
    if (isAudio) return 'audio';
    return 'file';
  };

  const generateFileName = (file) => {
    const ext = file.name.split('.').pop().toLowerCase();
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 8);
    const prefix = folder ? `${folder}/` : '';
    return `${prefix}${timestamp}_${random}.${ext}`;
  };

  const uploadFile = async (file) => {
    if (!file) return;

    // Validate size
    const sizeMB = file.size / (1024 * 1024);
    if (sizeMB > maxSizeMB) {
      setError(`File too large: ${sizeMB.toFixed(1)}MB (max ${maxSizeMB}MB)`);
      return;
    }

    setUploading(true);
    setError('');
    setProgress(10);

    try {
      const filePath = generateFileName(file);
      setProgress(30);

      const { data, error: uploadError } = await supabase.storage
        .from(bucket)
        .upload(filePath, file, {
          cacheControl: '3600',
          upsert: false,
        });

      if (uploadError) {
        // If bucket doesn't exist, try creating it
        if (uploadError.message?.includes('not found') || uploadError.statusCode === 404) {
          setError(`Storage bucket "${bucket}" not found. Please create it in Supabase Dashboard → Storage.`);
        } else {
          setError(uploadError.message);
        }
        setUploading(false);
        setProgress(0);
        return;
      }

      setProgress(80);

      // Get public URL
      const { data: urlData } = supabase.storage
        .from(bucket)
        .getPublicUrl(data.path);

      setProgress(100);
      onChange(urlData.publicUrl);

      setTimeout(() => {
        setUploading(false);
        setProgress(0);
      }, 500);
    } catch (err) {
      setError(err.message || 'Upload failed');
      setUploading(false);
      setProgress(0);
    }
  };

  const handleFileSelect = (e) => {
    const file = e.target.files?.[0];
    if (file) uploadFile(file);
  };

  const handleDrop = (e) => {
    e.preventDefault();
    setDragOver(false);
    const file = e.dataTransfer.files?.[0];
    if (file) uploadFile(file);
  };

  const handleRemove = async () => {
    if (!value) return;
    if (!confirm('Remove this file?')) return;

    // Try to delete from storage
    try {
      const url = new URL(value);
      const pathParts = url.pathname.split(`/storage/v1/object/public/${bucket}/`);
      if (pathParts[1]) {
        await supabase.storage.from(bucket).remove([pathParts[1]]);
      }
    } catch (e) {
      // URL parsing or deletion may fail for external URLs — that's ok
    }

    onChange('');
  };

  const formatSize = (bytes) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  return (
    <div style={{ marginBottom: 4 }}>
      {/* Current value display */}
      {value && showPreview && (
        <div style={{
          borderRadius: 10, border: '1px solid #e0e0e0', overflow: 'hidden',
          marginBottom: 8, position: 'relative',
        }}>
          {isImage && (
            <img src={value} alt="" style={{
              width: '100%', maxHeight: 160, objectFit: 'cover',
              display: 'block',
            }} onError={(e) => { e.target.style.display = 'none'; }} />
          )}
          {isVideo && (
            <video src={value} controls style={{ width: '100%', maxHeight: 160 }} />
          )}
          {isAudio && (
            <audio src={value} controls style={{ width: '100%', padding: 12 }} />
          )}

          {/* Remove button */}
          <button onClick={handleRemove} style={{
            position: 'absolute', top: 6, right: 6,
            width: 28, height: 28, borderRadius: '50%',
            background: 'rgba(239,68,68,0.9)', color: '#fff', border: 'none',
            cursor: 'pointer', fontSize: 14, display: 'flex',
            alignItems: 'center', justifyContent: 'center',
          }}>✕</button>
        </div>
      )}

      {/* URL input + upload */}
      <div style={{ display: 'flex', gap: 6, alignItems: 'stretch' }}>
        <input
          className="form-input"
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={`Enter URL or upload ${getFileType()}...`}
          style={{ flex: 1, fontSize: 12 }}
        />
        <button
          type="button"
          onClick={() => fileRef.current?.click()}
          disabled={uploading}
          style={{
            padding: '0 14px', borderRadius: 8, border: '1px solid var(--border)',
            background: uploading ? '#f5f5f5' : '#7c3aed',
            color: uploading ? '#999' : '#fff',
            cursor: uploading ? 'not-allowed' : 'pointer',
            fontSize: 12, fontWeight: 600, whiteSpace: 'nowrap',
            display: 'flex', alignItems: 'center', gap: 4,
          }}
        >
          {uploading ? '⏳ Uploading...' : '⬆ Upload'}
        </button>
      </div>

      {/* Hidden file input */}
      <input
        ref={fileRef}
        type="file"
        accept={accept}
        onChange={handleFileSelect}
        style={{ display: 'none' }}
      />

      {/* Drag & drop zone (show when no file and not uploading) */}
      {!value && !uploading && (
        <div
          onDragOver={(e) => { e.preventDefault(); setDragOver(true); }}
          onDragLeave={() => setDragOver(false)}
          onDrop={handleDrop}
          onClick={() => fileRef.current?.click()}
          style={{
            marginTop: 6, padding: '16px 12px', borderRadius: 10,
            border: `2px dashed ${dragOver ? '#7c3aed' : '#d4d4d4'}`,
            background: dragOver ? '#7c3aed08' : '#fafafa',
            textAlign: 'center', cursor: 'pointer',
            transition: 'all 0.2s',
          }}
        >
          <div style={{ fontSize: 22, marginBottom: 4 }}>
            {isImage ? '🖼️' : isVideo ? '🎬' : isAudio ? '🎵' : '📎'}
          </div>
          <div style={{ fontSize: 12, color: '#666', fontWeight: 500 }}>
            Drop {getFileType()} here or click to browse
          </div>
          <div style={{ fontSize: 10, color: '#999', marginTop: 2 }}>
            Max {maxSizeMB}MB • {accept.replace(/\*/g, 'all')}
          </div>
        </div>
      )}

      {/* Progress bar */}
      {uploading && (
        <div style={{ marginTop: 6 }}>
          <div style={{
            height: 4, background: '#eee', borderRadius: 2, overflow: 'hidden',
          }}>
            <div style={{
              width: `${progress}%`, height: '100%',
              background: 'linear-gradient(90deg, #7c3aed, #a855f7)',
              borderRadius: 2, transition: 'width 0.3s',
            }} />
          </div>
          <div style={{ fontSize: 10, color: '#7c3aed', marginTop: 2, textAlign: 'right' }}>
            {progress}%
          </div>
        </div>
      )}

      {/* Error */}
      {error && (
        <div style={{
          marginTop: 4, padding: '6px 10px', borderRadius: 6,
          background: '#fef2f2', border: '1px solid #fecaca',
          fontSize: 11, color: '#dc2626',
        }}>
          ❌ {error}
        </div>
      )}
    </div>
  );
}

// lib/services/tts_audio_service.dart
// Smart 3-layer TTS audio service for yoga guidance
// Layer 1: Device cache (offline, instant playback)
// Layer 2: Supabase Storage (online, fast CDN)
// Layer 3: Sarvam AI generation (first time only)

import 'dart:convert';
import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import './supabase_service.dart';

class TtsAudioService {
  static final TtsAudioService _instance = TtsAudioService._();
  factory TtsAudioService() => _instance;
  TtsAudioService._();

  // ── Sarvam AI Config ──
  static const String _sarvamTtsUrl = 'https://api.sarvam.ai/text-to-speech';
  static const String _speaker = 'shubh';      // Male, calm voice
  static const String _model = 'bulbul:v3';     // Latest, best quality
  static const double _pace = 0.95;             // Slightly slower, yoga teacher pace
  static const double _temperature = 0.5;       // Stable, consistent output
  static const String _metadataKey = 'tts_audio_cache_meta';

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 30),
  ));
  final AudioPlayer _audioPlayer = AudioPlayer();
  final SupabaseService _supabase = SupabaseService();
  
  String get _apiKey => dotenv.env['SARVAM_API_KEY'] ?? '';

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;
  int _cancelToken = 0; // Incremented on stop() to abort in-flight playback

  // ═══════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════

  /// Get audio for a pose step and play it. Returns true when playback completes.
  /// This is the main entry point — handles all 3 layers automatically.
  /// 
  /// Flow:
  /// 1. Check device cache → play instantly (offline capable)
  /// 2. Check Supabase DB for existing audio URL → stream + cache locally
  /// 3. Generate fresh via Sarvam AI → upload to Supabase → cache locally
  Future<bool> speakStepGuidance({
    required String poseId,
    required int stepNumber,
    required String language, // 'hi' or 'en'
    required String guidanceText,
  }) async {
    if (_apiKey.isEmpty || guidanceText.trim().isEmpty) {
      debugPrint('🔊 TTS: API key empty or no text, skipping');
      return false;
    }

    try {
      final textHash = _computeHash(guidanceText);
      final cacheKey = _buildCacheKey(poseId, stepNumber, language);
      
      // ── Layer 1: Device cache ──
      final cachedPath = await _getDeviceCachePath(cacheKey, textHash);
      if (cachedPath != null) {
        debugPrint('🔊 TTS: Playing from device cache (offline) ✅');
        return await _playAudioFile(cachedPath);
      }

      // ── Layer 2: Supabase DB lookup ──
      final dbAudio = await _lookupSupabaseAudio(poseId, stepNumber, language, textHash);
      if (dbAudio != null) {
        debugPrint('🔊 TTS: Playing from Supabase Storage ✅');
        final audioUrl = dbAudio['audio_url'] as String;
        // Play from URL and cache locally in background
        final played = await _playAudioUrl(audioUrl);
        // Cache to device in background
        _cacheToDevice(audioUrl, cacheKey, textHash);
        return played;
      }

      // ── Layer 3: Generate fresh via Sarvam AI ──
      debugPrint('🔊 TTS: Generating fresh audio via Sarvam AI...');
      final audioPath = await _generateAndStore(
        poseId: poseId,
        stepNumber: stepNumber,
        language: language,
        guidanceText: guidanceText,
        textHash: textHash,
        cacheKey: cacheKey,
      );
      
      if (audioPath != null) {
        return await _playAudioFile(audioPath);
      }

      return false;
    } catch (e) {
      debugPrint('🔊 TTS Error: $e');
      return false;
    }
  }

  /// Stop any currently playing audio
  Future<void> stop() async {
    _cancelToken++; // Signal in-flight playback to abort
    try {
      await _audioPlayer.stop();
      _isPlaying = false;
    } catch (e) {
      debugPrint('🔊 TTS stop error: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    _audioPlayer.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // LAYER 1: DEVICE CACHE
  // ═══════════════════════════════════════════════════════════════

  Future<Directory> get _cacheDir async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/tts_cache');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _buildCacheKey(String poseId, int stepNumber, String language) {
    return 'tts_${poseId}_${stepNumber}_$language';
  }

  String _computeHash(String text) {
    return md5.convert(utf8.encode(text.trim().toLowerCase())).toString();
  }

  /// Check if we have a locally cached audio file with matching hash
  Future<String?> _getDeviceCachePath(String cacheKey, String textHash) async {
    try {
      final meta = await _loadCacheMetadata();
      final entry = meta[cacheKey];
      if (entry == null) return null;

      // Check hash matches (guidance text hasn't changed)
      if (entry['hash'] != textHash) {
        debugPrint('🔊 TTS: Cache hash mismatch — text changed, regenerating');
        // Delete old cached file
        await _deleteDeviceCache(cacheKey);
        return null;
      }

      final filePath = entry['path'] as String?;
      if (filePath == null) return null;

      final file = File(filePath);
      if (await file.exists()) return filePath;

      // File missing, clean metadata
      await _deleteDeviceCache(cacheKey);
      return null;
    } catch (e) {
      debugPrint('🔊 TTS: Device cache lookup error: $e');
      return null;
    }
  }

  /// Save audio file to device cache
  Future<String?> _saveToDeviceCache(String cacheKey, String textHash, Uint8List audioBytes) async {
    try {
      final dir = await _cacheDir;
      final filePath = '${dir.path}/$cacheKey.wav';
      final file = File(filePath);
      await file.writeAsBytes(audioBytes);

      // Save metadata
      final meta = await _loadCacheMetadata();
      meta[cacheKey] = {
        'path': filePath,
        'hash': textHash,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await _saveCacheMetadata(meta);

      debugPrint('🔊 TTS: Saved to device cache: $cacheKey');
      return filePath;
    } catch (e) {
      debugPrint('🔊 TTS: Save to device cache error: $e');
      return null;
    }
  }

  /// Download from URL and cache to device (background)
  void _cacheToDevice(String url, String cacheKey, String textHash) {
    _downloadAndCache(url, cacheKey, textHash).catchError((e) {
      debugPrint('🔊 TTS: Background cache error: $e');
    });
  }

  Future<void> _downloadAndCache(String url, String cacheKey, String textHash) async {
    try {
      final response = await _dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200) {
        await _saveToDeviceCache(cacheKey, textHash, Uint8List.fromList(response.data));
      }
    } catch (e) {
      debugPrint('🔊 TTS: Download cache error: $e');
    }
  }

  Future<void> _deleteDeviceCache(String cacheKey) async {
    try {
      final meta = await _loadCacheMetadata();
      final entry = meta[cacheKey];
      if (entry != null) {
        final filePath = entry['path'] as String?;
        if (filePath != null) {
          final file = File(filePath);
          if (await file.exists()) await file.delete();
        }
        meta.remove(cacheKey);
        await _saveCacheMetadata(meta);
      }
    } catch (e) {
      debugPrint('🔊 TTS: Delete cache error: $e');
    }
  }

  Future<Map<String, dynamic>> _loadCacheMetadata() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_metadataKey);
      if (jsonStr != null) {
        final decoded = json.decode(jsonStr);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      }
    } catch (e) {
      debugPrint('🔊 TTS: Load cache meta error: $e');
    }
    return {};
  }

  Future<void> _saveCacheMetadata(Map<String, dynamic> meta) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_metadataKey, json.encode(meta));
    } catch (e) {
      debugPrint('🔊 TTS: Save cache meta error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LAYER 2: SUPABASE DB LOOKUP
  // ═══════════════════════════════════════════════════════════════

  /// Check if audio already exists in Supabase for this step
  Future<Map<String, dynamic>?> _lookupSupabaseAudio(
    String poseId, int stepNumber, String language, String textHash,
  ) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final response = await client
          .from('pose_step_audio')
          .select('id, audio_url, text_hash')
          .eq('pose_id', poseId)
          .eq('step_number', stepNumber)
          .eq('language', language)
          .maybeSingle();

      if (response == null) return null;

      // Check if hash matches (text hasn't changed)
      final dbHash = response['text_hash'] as String?;
      if (dbHash == textHash) {
        return Map<String, dynamic>.from(response);
      }

      // Hash mismatch — guidance text changed, need to regenerate
      debugPrint('🔊 TTS: Supabase hash mismatch — will regenerate');
      // Delete old audio from storage
      final oldUrl = response['audio_url'] as String?;
      if (oldUrl != null) {
        _deleteFromStorage(oldUrl);
      }
      // Delete DB row (will be recreated after generation)
      await client.from('pose_step_audio').delete().eq('id', response['id']);
      return null;
    } catch (e) {
      debugPrint('🔊 TTS: Supabase lookup error: $e');
      return null;
    }
  }

  /// Save audio metadata to Supabase DB
  Future<void> _saveToSupabaseDb({
    required String poseId,
    required int stepNumber,
    required String language,
    required String audioUrl,
    required String textHash,
    int? fileSizeBytes,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      await client.from('pose_step_audio').upsert({
        'pose_id': poseId,
        'step_number': stepNumber,
        'language': language,
        'audio_url': audioUrl,
        'text_hash': textHash,
        'speaker': _speaker,
        'file_size_bytes': fileSizeBytes,
        'generated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'pose_id,step_number,language');

      debugPrint('🔊 TTS: Saved audio metadata to Supabase DB ✅');
    } catch (e) {
      debugPrint('🔊 TTS: Save to Supabase DB error: $e');
    }
  }

  /// Delete old audio from Supabase Storage (background)
  void _deleteFromStorage(String audioUrl) {
    Future(() async {
      try {
        final client = await _supabase.client;
        if (client == null) return;
        // Extract path from URL
        final uri = Uri.parse(audioUrl);
        final pathSegments = uri.pathSegments;
        // URL format: .../storage/v1/object/public/tts-audio/path/file.wav
        final bucketIndex = pathSegments.indexOf('tts-audio');
        if (bucketIndex >= 0 && bucketIndex < pathSegments.length - 1) {
          final storagePath = pathSegments.sublist(bucketIndex + 1).join('/');
          await client.storage.from('tts-audio').remove([storagePath]);
          debugPrint('🔊 TTS: Deleted old audio from storage: $storagePath');
        }
      } catch (e) {
        debugPrint('🔊 TTS: Delete from storage error: $e');
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // LAYER 3: SARVAM AI GENERATION + UPLOAD
  // ═══════════════════════════════════════════════════════════════

  /// Generate audio via Sarvam AI, upload to Supabase Storage, save to DB + device
  Future<String?> _generateAndStore({
    required String poseId,
    required int stepNumber,
    required String language,
    required String guidanceText,
    required String textHash,
    required String cacheKey,
  }) async {
    try {
      // ── Step 1: Call Sarvam AI TTS API ──
      final langCode = language == 'hi' ? 'hi-IN' : 'en-IN';
      
      // Truncate to 2500 chars (Bulbul v3 limit)
      final text = guidanceText.length > 2500 
          ? guidanceText.substring(0, 2500) 
          : guidanceText;

      final response = await _dio.post(
        _sarvamTtsUrl,
        options: Options(
          headers: {
            'api-subscription-key': _apiKey,
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'inputs': [text],
          'target_language_code': langCode,
          'speaker': _speaker,
          'model': _model,
          'pace': _pace,
          'temperature': _temperature,
        },
      );

      if (response.statusCode != 200 || response.data == null) {
        debugPrint('🔊 TTS: Sarvam API returned ${response.statusCode}');
        return null;
      }

      final audiosArr = response.data['audios'] as List?;
      if (audiosArr == null || audiosArr.isEmpty) {
        debugPrint('🔊 TTS: No audio in Sarvam response');
        return null;
      }

      final base64Audio = audiosArr[0] as String;
      final audioBytes = base64Decode(base64Audio);
      debugPrint('🔊 TTS: Generated ${audioBytes.length} bytes from Sarvam AI ✅');

      // ── Step 2: Save to device cache immediately ──
      final localPath = await _saveToDeviceCache(cacheKey, textHash, Uint8List.fromList(audioBytes));

      // ── Step 3: Upload to Supabase Storage (background) ──
      _uploadToSupabase(
        poseId: poseId,
        stepNumber: stepNumber,
        language: language,
        audioBytes: Uint8List.fromList(audioBytes),
        textHash: textHash,
      );

      return localPath;
    } on DioException catch (e) {
      debugPrint('🔊 TTS: Sarvam API error: ${e.response?.statusCode} - ${e.message}');
      if (e.response?.data != null) {
        debugPrint('🔊 TTS: Error body: ${e.response?.data}');
      }
      return null;
    } catch (e) {
      debugPrint('🔊 TTS: Generation error: $e');
      return null;
    }
  }

  /// Upload audio to Supabase Storage and save metadata to DB (background)
  Future<void> _uploadToSupabase({
    required String poseId,
    required int stepNumber,
    required String language,
    required Uint8List audioBytes,
    required String textHash,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      final storagePath = '$poseId/${stepNumber}_$language.wav';

      // Upload to storage
      await client.storage.from('tts-audio').uploadBinary(
        storagePath,
        audioBytes,
        fileOptions: const FileOptions(
          contentType: 'audio/wav',
          upsert: true,
        ),
      );

      // Get public URL
      final audioUrl = client.storage.from('tts-audio').getPublicUrl(storagePath);

      // Save metadata to DB
      await _saveToSupabaseDb(
        poseId: poseId,
        stepNumber: stepNumber,
        language: language,
        audioUrl: audioUrl,
        textHash: textHash,
        fileSizeBytes: audioBytes.length,
      );

      debugPrint('🔊 TTS: Uploaded to Supabase Storage ✅');
    } catch (e) {
      debugPrint('🔊 TTS: Upload to Supabase error: $e');
      // Not critical — device cache still works
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // AUDIO PLAYBACK
  // ═══════════════════════════════════════════════════════════════

  /// Play audio from local file path. Returns true when playback completes.
  Future<bool> _playAudioFile(String filePath) async {
    final token = _cancelToken;
    try {
      _isPlaying = true;
      await _audioPlayer.play(DeviceFileSource(filePath));
      
      // Wait for playback to complete OR cancellation
      await _audioPlayer.onPlayerComplete.first;
      if (_cancelToken != token) {
        _isPlaying = false;
        return false; // Was cancelled
      }
      _isPlaying = false;
      return true;
    } catch (e) {
      debugPrint('🔊 TTS: Play file error: $e');
      _isPlaying = false;
      return false;
    }
  }

  /// Play audio from URL. Returns true when playback completes.
  Future<bool> _playAudioUrl(String url) async {
    final token = _cancelToken;
    try {
      _isPlaying = true;
      await _audioPlayer.play(UrlSource(url));
      
      // Wait for playback to complete OR cancellation
      await _audioPlayer.onPlayerComplete.first;
      if (_cancelToken != token) {
        _isPlaying = false;
        return false; // Was cancelled
      }
      _isPlaying = false;
      return true;
    } catch (e) {
      debugPrint('🔊 TTS: Play URL error: $e');
      _isPlaying = false;
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // UTILITIES
  // ═══════════════════════════════════════════════════════════════

  /// Clear all cached TTS audio (for settings/debug)
  Future<void> clearAllCache() async {
    try {
      final dir = await _cacheDir;
      if (await dir.exists()) {
        await dir.delete(recursive: true);
        await dir.create();
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_metadataKey);
      debugPrint('🔊 TTS: All cache cleared');
    } catch (e) {
      debugPrint('🔊 TTS: Clear cache error: $e');
    }
  }

  /// Get cache stats
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      final meta = await _loadCacheMetadata();
      int totalSize = 0;
      for (final entry in meta.values) {
        if (entry is Map) {
          final path = entry['path'] as String?;
          if (path != null) {
            final file = File(path);
            if (await file.exists()) {
              totalSize += await file.length();
            }
          }
        }
      }
      return {
        'cachedFiles': meta.length,
        'totalSizeBytes': totalSize,
        'totalSizeMB': (totalSize / (1024 * 1024)).toStringAsFixed(1),
      };
    } catch (e) {
      return {'cachedFiles': 0, 'totalSizeBytes': 0, 'totalSizeMB': '0.0'};
    }
  }
}

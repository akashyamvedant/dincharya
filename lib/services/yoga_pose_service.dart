// lib/services/yoga_pose_service.dart
// Service for fetching yoga poses &  their steps from Supabase.
// Uses SWR (Stale-While-Revalidate) disk caching to minimize egress.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import './supabase_service.dart';

class YogaPoseService {
  final SupabaseService _supabase = SupabaseService();

  // Singleton
  static final YogaPoseService _instance = YogaPoseService._internal();
  factory YogaPoseService() => _instance;
  YogaPoseService._internal();

  // ── In-memory cache ──
  List<Map<String, dynamic>>? _cachedPoses;
  final Map<String, List<Map<String, dynamic>>> _cachedSteps = {};

  // ── SWR cache keys ──
  static const String _posesCacheKey = 'swr_yoga_poses_cache';
  static const String _posesCacheTimeKey = 'swr_yoga_poses_time';
  static const String _stepsCachePrefix = 'swr_pose_steps_';
  static const int _cacheHours = 24; // Poses rarely change

  // ── Columns we actually need (avoid SELECT *) ──
  static const String _poseCols =
      'id, name, name_hindi, sanskrit_name, category, difficulty, '
      'description, description_hindi, benefits, image_urls, '
      'is_active, display_order, linked_session_id, total_steps, '
      'literature, literature_hindi, tags, dosha_affinity';

  static const String _stepCols =
      'id, pose_id, step_number, title, title_hindi, '
      'instruction, instruction_hindi, duration_seconds, '
      'image_url, guidance_audio_hi, guidance_audio_en';

  /// Fetch all active yoga poses for a given category.
  Future<List<Map<String, dynamic>>> getPoses({String? category}) async {
    try {
      // ── Step 1: Return in-memory cache if available ──
      if (_cachedPoses != null) {
        if (category != null) {
          return _cachedPoses!.where((p) => p['category'] == category).toList();
        }
        return _cachedPoses!;
      }

      // ── Step 2: Load from disk cache ──
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString(_posesCacheKey);
      if (cachedJson != null) {
        _cachedPoses = List<Map<String, dynamic>>.from(
          (json.decode(cachedJson) as List).map((e) => Map<String, dynamic>.from(e)),
        );
        debugPrint('📦 YogaPoses: Loaded ${_cachedPoses!.length} from disk cache');

        // ── Step 3: Check freshness ──
        final lastSync = prefs.getInt(_posesCacheTimeKey) ?? 0;
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastSync;
        if (elapsed < _cacheHours * 60 * 60 * 1000) {
          // Cache is fresh
          if (category != null) {
            return _cachedPoses!.where((p) => p['category'] == category).toList();
          }
          return _cachedPoses!;
        }
      }

      // ── Step 4: Fetch from Supabase ──
      final client = await _supabase.client;
      if (client == null) return _cachedPoses ?? [];

      final response = await client
          .from('yoga_poses')
          .select(_poseCols)
          .eq('is_active', true)
          .order('display_order', ascending: true);

      _cachedPoses = List<Map<String, dynamic>>.from(response);

      // ── Step 5: Save to disk ──
      await prefs.setString(_posesCacheKey, json.encode(_cachedPoses));
      await prefs.setInt(_posesCacheTimeKey, DateTime.now().millisecondsSinceEpoch);
      debugPrint('✅ YogaPoses: Fetched ${_cachedPoses!.length} from Supabase, cached');

      if (category != null) {
        return _cachedPoses!.where((p) => p['category'] == category).toList();
      }
      return _cachedPoses!;
    } catch (e) {
      debugPrint('YogaPoseService.getPoses error: $e');
      return _cachedPoses ?? [];
    }
  }

  /// Fetch a single yoga pose by ID.
  Future<Map<String, dynamic>?> getPoseById(String poseId) async {
    try {
      // Check in-memory cache first
      if (_cachedPoses != null) {
        final cached = _cachedPoses!.where((p) => p['id'] == poseId).toList();
        if (cached.isNotEmpty) return cached.first;
      }

      final client = await _supabase.client;
      if (client == null) return null;

      final response = await client
          .from('yoga_poses')
          .select(_poseCols)
          .eq('id', poseId)
          .single();

      return Map<String, dynamic>.from(response);
    } catch (e) {
      debugPrint('YogaPoseService.getPoseById error: $e');
      return null;
    }
  }

  /// Fetch all steps for a given pose, ordered by step_number.
  Future<List<Map<String, dynamic>>> getPoseSteps(String poseId) async {
    // Return in-memory cache if available
    if (_cachedSteps.containsKey(poseId)) {
      return _cachedSteps[poseId]!;
    }

    try {
      // Check disk cache
      final prefs = await SharedPreferences.getInstance();
      final cachedJson = prefs.getString('$_stepsCachePrefix$poseId');
      if (cachedJson != null) {
        final steps = List<Map<String, dynamic>>.from(
          (json.decode(cachedJson) as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _cachedSteps[poseId] = steps;
        debugPrint('📦 PoseSteps[$poseId]: Loaded ${steps.length} from disk cache');
        return steps;
      }

      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('pose_steps')
          .select(_stepCols)
          .eq('pose_id', poseId)
          .order('step_number', ascending: true);

      final steps = List<Map<String, dynamic>>.from(response);
      _cachedSteps[poseId] = steps;

      // Save to disk
      await prefs.setString('$_stepsCachePrefix$poseId', json.encode(steps));
      debugPrint('✅ PoseSteps[$poseId]: Fetched ${steps.length} from Supabase, cached');
      return steps;
    } catch (e) {
      debugPrint('YogaPoseService.getPoseSteps error: $e');
      return [];
    }
  }

  /// Reverse lookup: find a yoga_pose linked to a given session ID.
  Future<Map<String, dynamic>?> getPoseBySessionId(String sessionId) async {
    try {
      // Check in-memory cache first
      if (_cachedPoses != null) {
        final cached = _cachedPoses!.where(
          (p) => p['linked_session_id'] == sessionId && p['is_active'] == true,
        ).toList();
        if (cached.isNotEmpty) return cached.first;
      }

      final client = await _supabase.client;
      if (client == null) return null;

      final response = await client
          .from('yoga_poses')
          .select(_poseCols)
          .eq('linked_session_id', sessionId)
          .eq('is_active', true)
          .limit(1)
          .maybeSingle();

      return response != null ? Map<String, dynamic>.from(response) : null;
    } catch (e) {
      debugPrint('YogaPoseService.getPoseBySessionId error: $e');
      return null;
    }
  }

  /// Clear cache (useful on pull-to-refresh).
  void clearCache() {
    _cachedPoses = null;
    _cachedSteps.clear();
    // Also clear disk cache
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_posesCacheKey);
      prefs.remove(_posesCacheTimeKey);
      // Note: individual step caches will expire naturally
    });
  }
}

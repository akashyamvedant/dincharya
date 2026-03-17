// lib/services/yoga_pose_service.dart
// Service for fetching yoga poses &  their steps from Supabase.

import 'package:flutter/foundation.dart';
import './supabase_service.dart';

class YogaPoseService {
  final SupabaseService _supabase = SupabaseService();

  // Singleton
  static final YogaPoseService _instance = YogaPoseService._internal();
  factory YogaPoseService() => _instance;
  YogaPoseService._internal();

  // Cache
  List<Map<String, dynamic>>? _cachedPoses;
  final Map<String, List<Map<String, dynamic>>> _cachedSteps = {};

  /// Fetch all active yoga poses for a given category.
  Future<List<Map<String, dynamic>>> getPoses({String? category}) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      var query = client
          .from('yoga_poses')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      if (category != null) {
        query = client
            .from('yoga_poses')
            .select()
            .eq('is_active', true)
            .eq('category', category)
            .order('display_order', ascending: true);
      }

      final response = await query;
      _cachedPoses = List<Map<String, dynamic>>.from(response);
      return _cachedPoses!;
    } catch (e) {
      debugPrint('YogaPoseService.getPoses error: $e');
      return _cachedPoses ?? [];
    }
  }

  /// Fetch a single yoga pose by ID.
  Future<Map<String, dynamic>?> getPoseById(String poseId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final response = await client
          .from('yoga_poses')
          .select()
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
    // Return cache if available
    if (_cachedSteps.containsKey(poseId)) {
      return _cachedSteps[poseId]!;
    }

    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('pose_steps')
          .select()
          .eq('pose_id', poseId)
          .order('step_number', ascending: true);

      final steps = List<Map<String, dynamic>>.from(response);
      _cachedSteps[poseId] = steps;
      return steps;
    } catch (e) {
      debugPrint('YogaPoseService.getPoseSteps error: $e');
      return [];
    }
  }

  /// Reverse lookup: find a yoga_pose linked to a given session ID.
  Future<Map<String, dynamic>?> getPoseBySessionId(String sessionId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final response = await client
          .from('yoga_poses')
          .select()
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
  }
}

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import './supabase_service.dart';
import './tapasya_service.dart';

/// Service for managing guided sessions: favorites, tracking, and recommendations
class GuidedSessionService {
  final SupabaseService _supabase = SupabaseService();

  // Singleton
  static final GuidedSessionService _instance = GuidedSessionService._internal();
  factory GuidedSessionService() => _instance;
  GuidedSessionService._internal();

  // Cache
  List<String> _favoriteSessionIds = [];
  bool _favoritesLoaded = false;
  String? _cachedDosha;
  List<String> _cachedGoals = [];
  bool _profileLoaded = false;

  // ─────────────────────────────────────────
  // USER PROFILE (DOSHA + GOALS)
  // ─────────────────────────────────────────

  /// Load user's dosha and goals from profile
  Future<void> loadUserProfile() async {
    if (_profileLoaded) return;
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;
      final client = await _supabase.client;
      if (client == null) return;

      final profile = await client
          .from('user_profiles')
          .select('dominant_dosha, primary_goals')
          .eq('id', userId)
          .maybeSingle();

      _cachedDosha = profile?['dominant_dosha'] as String?;
      final goals = profile?['primary_goals'];
      if (goals is List) {
        _cachedGoals = List<String>.from(goals);
      }
      _profileLoaded = true;
      debugPrint('👤 Profile loaded — dosha: $_cachedDosha, goals: $_cachedGoals');
    } catch (e) {
      debugPrint('⚠️ Error loading user profile: $e');
    }
  }

  /// Get user's dominant dosha (cached)
  String? get userDosha => _cachedDosha;

  /// Get user's primary goals (cached)
  List<String> get userGoals => _cachedGoals;

  /// Update user's dosha
  Future<void> updateDosha(String dosha) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;
      final client = await _supabase.client;
      if (client == null) return;

      await client.from('user_profiles').update({
        'dominant_dosha': dosha,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      _cachedDosha = dosha;
      debugPrint('✅ Dosha updated to: $dosha');
    } catch (e) {
      debugPrint('❌ Error updating dosha: $e');
    }
  }

  /// Update user's goals
  Future<void> updateGoals(List<String> goals) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;
      final client = await _supabase.client;
      if (client == null) return;

      await client.from('user_profiles').update({
        'primary_goals': goals,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      _cachedGoals = goals;
      debugPrint('✅ Goals updated: $goals');
    } catch (e) {
      debugPrint('❌ Error updating goals: $e');
    }
  }

  // ─────────────────────────────────────────
  // FAVORITES
  // ─────────────────────────────────────────

  /// Load user's favorite session IDs
  Future<List<String>> loadFavorites() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return [];

      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('user_favorites')
          .select('session_id')
          .eq('user_id', userId);

      _favoriteSessionIds = List<String>.from(
        response.map((r) => r['session_id'].toString()),
      );
      _favoritesLoaded = true;
      return _favoriteSessionIds;
    } catch (e) {
      debugPrint('❌ Error loading favorites: $e');
      return [];
    }
  }

  /// Check if a session is favorited
  bool isFavorite(String sessionId) {
    return _favoriteSessionIds.contains(sessionId);
  }

  /// Toggle favorite status
  Future<bool> toggleFavorite(String sessionId) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return false;

      final client = await _supabase.client;
      if (client == null) return false;

      if (isFavorite(sessionId)) {
        await client
            .from('user_favorites')
            .delete()
            .eq('user_id', userId)
            .eq('session_id', sessionId);
        _favoriteSessionIds.remove(sessionId);
        debugPrint('💔 Removed favorite: $sessionId');
        return false;
      } else {
        await client.from('user_favorites').insert({
          'user_id': userId,
          'session_id': sessionId,
        });
        _favoriteSessionIds.add(sessionId);
        debugPrint('❤️ Added favorite: $sessionId');
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
      return isFavorite(sessionId);
    }
  }

  /// Get all favorited sessions
  Future<List<Map<String, dynamic>>> getFavoriteSessions() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return [];

      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('user_favorites')
          .select('session_id, sessions(id, title, title_hindi, description, category, difficulty, duration, '
              'media_type, media_url, youtube_url, video_url, audio_url, '
              'thumbnail_url, instructor_name, is_premium, tags, view_count)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(
        response.map((r) => r['sessions'] as Map<String, dynamic>),
      );
    } catch (e) {
      debugPrint('❌ Error getting favorite sessions: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────
  // SESSION TRACKING
  // ─────────────────────────────────────────

  /// Record a completed practice session
  Future<void> recordSession({
    required String practiceType,
    required String technique,
    required int durationSeconds,
    String? moodBefore,
    String? moodAfter,
    int? energyBefore,
    int? energyAfter,
    String? notes,
    String? sessionId,
  }) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      await client.from('practice_sessions').insert({
        'user_id': userId,
        'practice_type': practiceType,
        'technique': technique,
        'session_id': sessionId,
        'duration_seconds': durationSeconds,
        'mood_before': moodBefore,
        'mood_after': moodAfter,
        'energy_before': energyBefore,
        'energy_after': energyAfter,
        'notes': notes,
        'completed_at': DateTime.now().toIso8601String(),
      });

      await _updateDailyProgress(practiceType, durationSeconds);
      await _updateGuidedStreak();
      debugPrint('✅ Session recorded: $technique ($durationSeconds sec)');

      // ── Tapasya auto-tracking: sync challenge progress ──
      TapasyaService().syncChallengeProgress(
        userId: userId,
        category: practiceType,
        sessionId: sessionId,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      debugPrint('❌ Error recording session: $e');
    }
  }

  /// Auto-record a session with minimal data (no mood/energy).
  /// Used when PracticeTab completes or user skips post-session check-in.
  /// Requires at least 30 seconds to avoid accidental recordings.
  Future<void> recordSessionAuto({
    required String practiceType,
    required String technique,
    required int durationSeconds,
    String? sessionId,
  }) async {
    if (durationSeconds < 30) {
      debugPrint('⏭️ Session too short (<30s), not recording: $technique');
      return;
    }
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      await client.from('practice_sessions').insert({
        'user_id': userId,
        'practice_type': practiceType,
        'technique': technique,
        'session_id': sessionId,
        'duration_seconds': durationSeconds,
        'is_completed': true,
        'completed_at': DateTime.now().toIso8601String(),
      });

      await _updateDailyProgress(practiceType, durationSeconds);
      await _updateGuidedStreak();
      debugPrint('✅ Auto-recorded session: $technique ($durationSeconds sec)');

      // ── Tapasya auto-tracking: sync challenge progress ──
      TapasyaService().syncChallengeProgress(
        userId: userId,
        category: practiceType,
        sessionId: sessionId,
        durationSeconds: durationSeconds,
      );
    } catch (e) {
      debugPrint('❌ Error auto-recording session: $e');
    }
  }

  /// Update daily progress aggregation
  Future<void> _updateDailyProgress(String practiceType, int durationSeconds) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final minutes = (durationSeconds / 60).round();

      final existing = await client
          .from('user_progress')
          .select('id, total_minutes, meditation_minutes, pranayama_minutes, yoga_minutes')
          .eq('user_id', userId)
          .eq('date', today)
          .maybeSingle();

      if (existing != null) {
        final updates = <String, dynamic>{
          'total_minutes': (existing['total_minutes'] ?? 0) + minutes,
        };
        if (practiceType == 'meditation') {
          updates['meditation_minutes'] = (existing['meditation_minutes'] ?? 0) + minutes;
        } else if (practiceType == 'pranayama') {
          updates['pranayama_minutes'] = (existing['pranayama_minutes'] ?? 0) + minutes;
        } else if (practiceType == 'yoga') {
          updates['yoga_minutes'] = (existing['yoga_minutes'] ?? 0) + minutes;
        }
        await client
            .from('user_progress')
            .update(updates)
            .eq('id', existing['id']);
      } else {
        final row = <String, dynamic>{
          'user_id': userId,
          'date': today,
          'total_minutes': minutes,
          'meditation_minutes': practiceType == 'meditation' ? minutes : 0,
          'pranayama_minutes': practiceType == 'pranayama' ? minutes : 0,
          'yoga_minutes': practiceType == 'yoga' ? minutes : 0,
        };
        await client.from('user_progress').insert(row);
      }
    } catch (e) {
      debugPrint('❌ Error updating daily progress: $e');
    }
  }

  // ─────────────────────────────────────────
  // PRACTICE STATS
  // ─────────────────────────────────────────

  Future<Map<String, dynamic>> getWeeklyPracticeStats() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return _emptyStats();

      final client = await _supabase.client;
      if (client == null) return _emptyStats();

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final mondayStr = DateFormat('yyyy-MM-dd').format(monday);

      final progress = await client
          .from('user_progress')
          .select('id, total_minutes, meditation_minutes, pranayama_minutes, yoga_minutes, date')
          .eq('user_id', userId)
          .gte('date', mondayStr)
          .order('date');

      final sessions = await client
          .from('practice_sessions')
          .select('id, completed_at')
          .eq('user_id', userId)
          .gte('completed_at', monday.toIso8601String());

      int totalMinutes = 0;
      for (final day in progress) {
        totalMinutes += (day['total_minutes'] as int?) ?? 0;
      }

      // Calculate guided streak independently from practice_sessions dates
      final streak = await _calculateGuidedStreak();

      return {
        'totalMinutes': totalMinutes,
        'sessionsCount': sessions.length,
        'streak': streak,
        'dailyProgress': List<Map<String, dynamic>>.from(progress),
      };
    } catch (e) {
      debugPrint('❌ Error getting weekly stats: $e');
      return _emptyStats();
    }
  }

  Map<String, dynamic> _emptyStats() => {
    'totalMinutes': 0,
    'sessionsCount': 0,
    'streak': 0,
    'dailyProgress': <Map<String, dynamic>>[],
  };

  // ─────────────────────────────────────────
  // TODAY'S SESSION — DOSHA-AWARE
  // ─────────────────────────────────────────

  /// Get today's recommended session with dosha + goals scoring
  Future<Map<String, dynamic>?> getTodaysSession() async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      // Ensure profile is loaded for personalization
      await loadUserProfile();

      final hour = DateTime.now().hour;

      // Time-based category (Vedic prahar)
      String recommendedCategory;
      String reason;
      if (hour >= 4 && hour < 7) {
        recommendedCategory = 'meditation';
        reason = 'Brahma Muhurta — ideal for meditation 🌅';
      } else if (hour >= 7 && hour < 10) {
        recommendedCategory = 'yoga';
        reason = 'Morning energy — perfect for yoga 🧘';
      } else if (hour >= 10 && hour < 17) {
        recommendedCategory = 'pranayama';
        reason = 'Midday reset — calm your mind with breathwork 🌬️';
      } else if (hour >= 17 && hour < 20) {
        recommendedCategory = 'yoga';
        reason = 'Evening wind-down — gentle yoga flow 🌇';
      } else {
        recommendedCategory = 'meditation';
        reason = 'Night peace — relax before sleep 🌙';
      }

      // Personalize reason with dosha if available
      if (_cachedDosha != null) {
        final doshaName = _cachedDosha![0].toUpperCase() + _cachedDosha!.substring(1);
        reason = '$reason\nPicked for your $doshaName constitution';
      }

      // Fetch sessions from recommended category (specific columns to save bandwidth)
      const sessionCols = 'id, title, title_hindi, description, category, difficulty, duration, '
          'media_type, media_url, youtube_url, video_url, audio_url, '
          'thumbnail_url, instructor_name, is_premium, tags, view_count';
      final sessions = await client
          .from('sessions')
          .select(sessionCols)
          .eq('category', recommendedCategory)
          .eq('is_active', true)
          .order('view_count', ascending: false)
          .limit(10);

      if (sessions.isEmpty) {
        final fallback = await client
            .from('sessions')
            .select(sessionCols)
            .eq('is_active', true)
            .limit(1);
        if (fallback.isEmpty) return null;
        return {
          ...Map<String, dynamic>.from(fallback.first),
          'recommendation_reason': 'Start your practice today ✨',
        };
      }

      // Fetch recently played session titles to avoid repeats
      final recentlyPlayed = await getRecentSessionIds(days: 3);

      // Score sessions by dosha affinity + goal match + freshness + randomness
      final scored = sessions.map((s) {
        double score = 0;
        // Base score from view count (popularity)
        score += ((s['view_count'] as int?) ?? 0) * 0.1;

        // Dosha affinity scoring
        if (_cachedDosha != null) {
          final tags = s['tags'];
          if (tags is List && tags.any((t) => t.toString().toLowerCase().contains(_cachedDosha!))) {
            score += 20;
          }
          // Difficulty matching based on dosha
          final diff = (s['difficulty'] as int?) ?? 3;
          if (_cachedDosha == 'vata' && diff <= 3) score += 5; // Vata: gentler
          if (_cachedDosha == 'pitta' && diff >= 2 && diff <= 4) score += 5; // Pitta: balanced
          if (_cachedDosha == 'kapha' && diff >= 3) score += 5; // Kapha: energizing
        }

        // Goal matching
        final desc = (s['description'] as String? ?? '').toLowerCase();
        final title = (s['title'] as String? ?? '').toLowerCase();
        for (final goal in _cachedGoals) {
          if (desc.contains(goal.replaceAll('_', ' ')) || title.contains(goal.replaceAll('_', ' '))) {
            score += 10;
          }
        }

        // Penalize recently played sessions for variety
        final sessionTitle = s['title']?.toString() ?? '';
        if (recentlyPlayed.contains(sessionTitle)) {
          score -= 15;
        }

        // Add randomness for variety
        score += (DateTime.now().microsecond % 10).toDouble();

        return {'session': s, 'score': score};
      }).toList();

      scored.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));

      final selected = scored.first['session'] as Map<String, dynamic>;
      return {
        ...Map<String, dynamic>.from(selected),
        'recommendation_reason': reason,
      };
    } catch (e) {
      debugPrint('❌ Error getting today\'s session: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────
  // PROGRAMS & COURSES
  // ─────────────────────────────────────────

  /// Get all available programs, optionally filtered by dosha
  Future<List<Map<String, dynamic>>> getPrograms({bool filterByDosha = false}) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('programs')
          .select('id, title, description, category, dosha_affinity, total_sessions, thumbnail_url, is_active, created_at')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> programs = List<Map<String, dynamic>>.from(response);

      // Filter by dosha affinity if requested and dosha is set
      if (filterByDosha && _cachedDosha != null) {
        programs = programs.where((p) {
          final affinity = p['dosha_affinity'];
          if (affinity is List) {
            return affinity.contains(_cachedDosha);
          }
          return true;
        }).toList();
      }

      return programs;
    } catch (e) {
      debugPrint('❌ Error getting programs: $e');
      return [];
    }
  }

  /// Get user's enrolled programs with progress
  Future<List<Map<String, dynamic>>> getEnrolledPrograms() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return [];

      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('user_program_enrollments')
          .select('id, user_id, program_id, current_session_index, completed, enrolled_at, '
              'programs(id, title, description, category, difficulty, total_sessions, '
              'thumbnail_url, instructor_name, is_premium)')
          .eq('user_id', userId)
          .eq('completed', false)
          .order('enrolled_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting enrolled programs: $e');
      return [];
    }
  }

  /// Enroll in a program
  Future<bool> enrollInProgram(String programId) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return false;

      final client = await _supabase.client;
      if (client == null) return false;

      await client.from('user_program_enrollments').upsert({
        'user_id': userId,
        'program_id': programId,
        'current_session_index': 0,
        'completed': false,
        'enrolled_at': DateTime.now().toIso8601String(),
      });

      debugPrint('📚 Enrolled in program: $programId');
      return true;
    } catch (e) {
      debugPrint('❌ Error enrolling in program: $e');
      return false;
    }
  }

  /// Advance to next session in a program
  Future<void> advanceProgramProgress(String programId) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      // Get current enrollment
      final enrollment = await client
          .from('user_program_enrollments')
          .select('*, programs(total_sessions)')
          .eq('user_id', userId)
          .eq('program_id', programId)
          .maybeSingle();

      if (enrollment == null) return;

      final currentIndex = (enrollment['current_session_index'] as int?) ?? 0;
      final totalSessions = enrollment['programs']?['total_sessions'] as int? ?? 0;

      if (currentIndex + 1 >= totalSessions) {
        // Program completed
        await client.from('user_program_enrollments')
            .update({
              'completed': true,
              'completed_at': DateTime.now().toIso8601String(),
              'current_session_index': currentIndex + 1,
            })
            .eq('user_id', userId)
            .eq('program_id', programId);
        debugPrint('🎉 Program completed: $programId');
      } else {
        await client.from('user_program_enrollments')
            .update({'current_session_index': currentIndex + 1})
            .eq('user_id', userId)
            .eq('program_id', programId);
      }
    } catch (e) {
      debugPrint('❌ Error advancing program: $e');
    }
  }

  /// Get sessions for a specific program in order
  Future<List<Map<String, dynamic>>> getProgramSessions(String programId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('program_sessions')
          .select('id, program_id, session_id, sequence_order, '
              'sessions(id, title, title_hindi, description, category, difficulty, duration, '
              'media_type, media_url, youtube_url, video_url, audio_url, '
              'thumbnail_url, instructor_name, is_premium, tags, view_count)')
          .eq('program_id', programId)
          .order('sequence_order');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error getting program sessions: $e');
      return [];
    }
  }

  // ─────────────────────────────────────────
  // SESSION HISTORY (for dedup + continue)
  // ─────────────────────────────────────────

  /// Get recently completed session IDs (last N days)
  Future<List<String>> getRecentSessionIds({int days = 7}) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return [];

      final client = await _supabase.client;
      if (client == null) return [];

      final since = DateTime.now().subtract(Duration(days: days));
      final response = await client
          .from('practice_sessions')
          .select('technique')
          .eq('user_id', userId)
          .gte('completed_at', since.toIso8601String());

      return List<String>.from(
        response.map((r) => r['technique']?.toString() ?? ''),
      );
    } catch (e) {
      debugPrint('❌ Error getting session history: $e');
      return [];
    }
  }

  /// Increment view count for a session
  Future<void> incrementViewCount(String sessionId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      await client.rpc('increment_view_count', params: {
        'session_id_param': sessionId,
      }).catchError((_) {
        return client
            .from('sessions')
            .update({'view_count': 1})
            .eq('id', sessionId);
      });
    } catch (_) {
      // Non-critical
    }
  }

  // ─────────────────────────────────────────
  // SESSION RESUME
  // ─────────────────────────────────────────

  /// Save the current playback position for a session so it can be resumed later.
  /// If an incomplete practice_session exists for this session, it updates it.
  /// Otherwise, creates a new record.
  Future<void> saveSessionProgress({
    required String sessionId,
    required String sessionTitle,
    required String category,
    required int positionSeconds,
    required int totalDuration,
  }) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      final isCompleted = positionSeconds >= (totalDuration - 10); // within 10s of end = completed

      // Check for existing incomplete record for this session
      final existing = await client
          .from('practice_sessions')
          .select('id')
          .eq('user_id', userId)
          .eq('session_id', sessionId)
          .eq('is_completed', false)
          .order('completed_at', ascending: false)
          .limit(1);

      if (existing.isNotEmpty) {
        // Update existing record
        await client
            .from('practice_sessions')
            .update({
              'last_position_seconds': positionSeconds,
              'is_completed': isCompleted,
              'duration_seconds': positionSeconds,
              'completed_at': DateTime.now().toIso8601String(),
            })
            .eq('id', existing.first['id']);
      } else {
        // Create new record
        await client.from('practice_sessions').insert({
          'user_id': userId,
          'practice_type': category,
          'technique': sessionTitle,
          'session_id': sessionId,
          'duration_seconds': positionSeconds,
          'last_position_seconds': positionSeconds,
          'is_completed': isCompleted,
          'completed_at': DateTime.now().toIso8601String(),
        });
      }

      debugPrint('💾 Session progress saved: ${positionSeconds}s / ${totalDuration}s (completed: $isCompleted)');

      // When session is completed, update daily stats and streak
      // This ensures non-Guided-Hub paths (Routine link, deep link) still count
      if (isCompleted) {
        await _updateDailyProgress(category, positionSeconds);
        await _updateGuidedStreak();
      }
    } catch (e) {
      debugPrint('❌ Error saving session progress: $e');
    }
  }

  /// Get the last played incomplete session so the user can resume.
  /// Returns null if there's no session to resume.
  /// Returns a map with session details + last_position_seconds.
  Future<Map<String, dynamic>?> getLastPlayedSession() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return null;

      final client = await _supabase.client;
      if (client == null) return null;

      // Find the most recent incomplete practice session that has a session_id
      final records = await client
          .from('practice_sessions')
          .select('session_id, last_position_seconds, completed_at')
          .eq('user_id', userId)
          .eq('is_completed', false)
          .not('session_id', 'is', null)
          .gt('last_position_seconds', 0) // Only if they actually started watching
          .order('completed_at', ascending: false)
          .limit(1);

      if (records.isEmpty) return null;

      final record = records.first;
      final sessionId = record['session_id'] as String?;
      if (sessionId == null) return null;

      // Fetch the actual session details (only needed columns)
      final sessionData = await client
          .from('sessions')
          .select('id, title, title_hindi, description, category, difficulty, duration, '
              'media_type, media_url, youtube_url, video_url, audio_url, '
              'thumbnail_url, instructor_name, is_premium, tags, view_count')
          .eq('id', sessionId)
          .eq('is_active', true)
          .limit(1);

      if (sessionData.isEmpty) return null;

      return {
        ...Map<String, dynamic>.from(sessionData.first),
        'last_position_seconds': record['last_position_seconds'] ?? 0,
        'last_played_at': record['completed_at'],
      };
    } catch (e) {
      debugPrint('❌ Error getting last played session: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────
  // WEEKLY CHALLENGE
  // ─────────────────────────────────────────

  /// Count how many distinct days this week the user has practiced.
  Future<int> getWeeklyChallengeProgress() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return 0;

      final client = await _supabase.client;
      if (client == null) return 0;

      // Get start of current week (Monday)
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);

      final records = await client
          .from('practice_sessions')
          .select('completed_at')
          .eq('user_id', userId)
          .gte('completed_at', weekStart.toIso8601String())
          .order('completed_at');

      // Count distinct days
      final days = <String>{};
      for (final r in records) {
        final date = r['completed_at']?.toString().substring(0, 10);
        if (date != null) days.add(date);
      }
      return days.length;
    } catch (e) {
      debugPrint('❌ Error getting challenge progress: $e');
      return 0;
    }
  }

  /// Count total distinct users who practiced this week (community count).
  Future<int> getWeeklyChallengeParticipants() async {
    try {
      final client = await _supabase.client;
      if (client == null) return 0;

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final weekStart = DateTime(monday.year, monday.month, monday.day);

      final records = await client
          .from('practice_sessions')
          .select('user_id')
          .gte('completed_at', weekStart.toIso8601String());

      final uniqueUsers = <String>{};
      for (final r in records) {
        final uid = r['user_id']?.toString();
        if (uid != null) uniqueUsers.add(uid);
      }
      return uniqueUsers.length;
    } catch (e) {
      debugPrint('❌ Error getting participants: $e');
      return 0;
    }
  }

  // ─────────────────────────────────────────
  // GUIDED SESSION STREAK (independent)
  // ─────────────────────────────────────────

  /// Calculate guided session streak from practice_sessions dates.
  /// This is independent of the routine streak in user_profiles.current_streak.
  Future<int> _calculateGuidedStreak() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return 0;

      final client = await _supabase.client;
      if (client == null) return 0;

      // Fetch last 90 days of completed sessions (enough for streak calc)
      final since = DateTime.now().subtract(const Duration(days: 90));
      final records = await client
          .from('practice_sessions')
          .select('completed_at')
          .eq('user_id', userId)
          .gte('completed_at', since.toIso8601String())
          .order('completed_at', ascending: false);

      if (records.isEmpty) return 0;

      // Collect unique dates
      final practiceDays = <String>{};
      for (final r in records) {
        final dateStr = r['completed_at']?.toString();
        if (dateStr != null && dateStr.length >= 10) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            practiceDays.add(DateFormat('yyyy-MM-dd').format(date));
          }
        }
      }

      // Walk backwards from today counting consecutive days
      int streak = 0;
      DateTime day = DateTime.now();
      final todayKey = DateFormat('yyyy-MM-dd').format(day);

      // If today has no session, check if yesterday had one (streak still alive)
      if (!practiceDays.contains(todayKey)) {
        day = day.subtract(const Duration(days: 1));
      }

      while (true) {
        final key = DateFormat('yyyy-MM-dd').format(day);
        if (practiceDays.contains(key)) {
          streak++;
          day = day.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }

      return streak;
    } catch (e) {
      debugPrint('❌ Error calculating guided streak: $e');
      return 0;
    }
  }

  /// Update the guided session streak in user_profiles after recording a session.
  Future<void> _updateGuidedStreak() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      final streak = await _calculateGuidedStreak();

      // Store guided streak separately (won't overwrite routine streak)
      await client.from('user_profiles').update({
        'guided_streak': streak,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('🔥 Guided streak updated: $streak days');
    } catch (e) {
      // Non-critical — streak display is best-effort
      debugPrint('⚠️ Error updating guided streak: $e');
    }
  }
}

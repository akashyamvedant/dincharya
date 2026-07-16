// lib/services/tapasya_service.dart
//
// Service for Tapasya (तपस्या) — Challenges & Group Practice
// Handles challenge CRUD, progress sync, badges, and activity feed.

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import './supabase_service.dart';

class TapasyaService {
  static final TapasyaService _instance = TapasyaService._internal();
  factory TapasyaService() => _instance;
  TapasyaService._internal();

  final SupabaseService _supabase = SupabaseService();
  final Uuid _uuid = const Uuid();

  // ══════════════════════════════════════════
  // CHALLENGES
  // ══════════════════════════════════════════

  /// Create a new challenge.
  /// Returns the created challenge map, or null on failure.
  Future<Map<String, dynamic>?> createChallenge({
    required String title,
    String? description,
    required String challengeType, // '1v1', 'group', 'community'
    required String category, // 'yoga', 'pranayama', 'meditation', 'any'
    String? specificSessionId,
    List<String>? specificSessionIds,
    required String goalType, // 'total_minutes', 'session_count', 'streak_days'
    required int goalValue,
    required int durationDays,
    bool isPublic = false,
    int maxParticipants = 20,
    String? circleId,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final now = DateTime.now().toUtc();
      final endsAt = now.add(Duration(days: durationDays));

      final challengeData = {
        'title': title,
        'description': description ?? '',
        'creator_id': userId,
        'challenge_type': challengeType,
        'category': category,
        'specific_session_id': specificSessionId,
        'specific_session_ids': specificSessionIds ?? [],
        'goal_type': goalType,
        'goal_value': goalValue,
        'duration_days': durationDays,
        'starts_at': now.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'status': 'active',
        'is_public': isPublic,
        'max_participants': challengeType == '1v1' ? 2 : maxParticipants,
        'circle_id': circleId,
      };

      final response = await client
          .from('tapasya_challenges')
          .insert(challengeData)
          .select()
          .single();

      final challenge = Map<String, dynamic>.from(response);

      // Auto-add creator as participant
      await client.from('tapasya_challenge_participants').insert({
        'challenge_id': challenge['id'],
        'user_id': userId,
        'status': 'accepted',
      });

      // Log activity
      await _logActivity(
        userId: userId,
        actionType: 'challenge_created',
        metadata: {
          'challenge_id': challenge['id'],
          'title': title,
          'type': challengeType,
          'category': category,
        },
      );

      debugPrint('✅ Challenge created: $title (${challenge['id']})');
      return challenge;
    } catch (e) {
      debugPrint('❌ Error creating challenge: $e');
      return null;
    }
  }

  /// Join a challenge by ID or invite code.
  Future<bool> joinChallenge({String? challengeId, String? inviteCode}) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      // Find challenge
      Map<String, dynamic>? challenge;
      if (challengeId != null) {
        final resp = await client
            .from('tapasya_challenges')
            .select()
            .eq('id', challengeId)
            .eq('status', 'active')
            .maybeSingle();
        if (resp != null) challenge = Map<String, dynamic>.from(resp);
      } else if (inviteCode != null) {
        final resp = await client
            .from('tapasya_challenges')
            .select()
            .eq('invite_code', inviteCode)
            .eq('status', 'active')
            .maybeSingle();
        if (resp != null) challenge = Map<String, dynamic>.from(resp);
      }

      if (challenge == null) {
        debugPrint('⚠️ Challenge not found');
        return false;
      }

      // Security: If challenge is circle-scoped, user must be a member of that circle to join
      final circleId = challenge['circle_id'];
      if (circleId != null) {
        final isMember = await client
            .from('tapasya_circle_members')
            .select('id')
            .eq('circle_id', circleId)
            .eq('user_id', userId)
            .maybeSingle();
        if (isMember == null) {
          debugPrint('⚠️ Security constraint: User is not a member of the circle hosting this challenge.');
          return false;
        }
      }

      // Check if already joined
      final existing = await client
          .from('tapasya_challenge_participants')
          .select('id')
          .eq('challenge_id', challenge['id'])
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('⚠️ Already joined this challenge');
        return true; // Already in
      }

      // Check participant limit
      final countResp = await client
          .from('tapasya_challenge_participants')
          .select('id')
          .eq('challenge_id', challenge['id']);
      
      if ((countResp as List).length >= (challenge['max_participants'] ?? 20)) {
        debugPrint('⚠️ Challenge is full');
        return false;
      }

      // Join
      await client.from('tapasya_challenge_participants').insert({
        'challenge_id': challenge['id'],
        'user_id': userId,
        'status': 'accepted',
      });

      // Log activity
      await _logActivity(
        userId: userId,
        actionType: 'challenge_joined',
        metadata: {
          'challenge_id': challenge['id'],
          'title': challenge['title'],
        },
      );

      debugPrint('✅ Joined challenge: ${challenge['title']}');
      return true;
    } catch (e) {
      debugPrint('❌ Error joining challenge: $e');
      return false;
    }
  }

  /// Get all challenges the current user is part of.
  /// [status] filter: 'active', 'completed', 'all'
  Future<List<Map<String, dynamic>>> getMyChallenges({String status = 'active'}) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      // Get challenge IDs user is participating in
      final participations = await client
          .from('tapasya_challenge_participants')
          .select('challenge_id, current_progress, rank')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      if ((participations as List).isEmpty) return [];

      final challengeIds = participations.map((p) => p['challenge_id']).toList();

      // Fetch challenge details
      var builder = client
          .from('tapasya_challenges')
          .select('*')
          .inFilter('id', challengeIds);

      if (status != 'all') {
        builder = builder.eq('status', status);
      }

      final challenges = List<Map<String, dynamic>>.from(
          await builder.order('created_at', ascending: false));

      // Attach user's progress to each challenge
      for (var challenge in challenges) {
        final participation = participations.firstWhere(
          (p) => p['challenge_id'] == challenge['id'],
          orElse: () => {},
        );
        challenge['my_progress'] = participation['current_progress'] ?? 0;
        challenge['my_rank'] = participation['rank'];

        // Get participant count
        final pCount = await client
            .from('tapasya_challenge_participants')
            .select('id')
            .eq('challenge_id', challenge['id'])
            .eq('status', 'accepted');
        challenge['participant_count'] = (pCount as List).length;
      }

      return challenges;
    } catch (e) {
      debugPrint('❌ Error getting challenges: $e');
      return [];
    }
  }

  /// Get community/public challenges (not yet joined).
  Future<List<Map<String, dynamic>>> getCommunityChallenge() async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final userId = client.auth.currentUser?.id;

      final challenges = await client
          .from('tapasya_challenges')
          .select('*')
          .eq('status', 'active')
          .neq('challenge_type', '1v1')
          .or('is_public.eq.true,challenge_type.eq.community')
          .order('created_at', ascending: false)
          .limit(20);

      final result = List<Map<String, dynamic>>.from(challenges);

      // Get participant count for each
      for (var challenge in result) {
        final pCount = await client
            .from('tapasya_challenge_participants')
            .select('id')
            .eq('challenge_id', challenge['id'])
            .eq('status', 'accepted');
        challenge['participant_count'] = (pCount as List).length;

        // Check if current user already joined
        if (userId != null) {
          final joined = await client
              .from('tapasya_challenge_participants')
              .select('id')
              .eq('challenge_id', challenge['id'])
              .eq('user_id', userId)
              .maybeSingle();
          challenge['is_joined'] = joined != null;
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error getting community challenges: $e');
      return [];
    }
  }

  /// Get detailed challenge info with full leaderboard.
  Future<Map<String, dynamic>?> getChallengeDetail(String challengeId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final userId = client.auth.currentUser?.id;

      // Get challenge
      final resp = await client
          .from('tapasya_challenges')
          .select('*')
          .eq('id', challengeId)
          .maybeSingle();

      if (resp == null) return null;
      final challenge = Map<String, dynamic>.from(resp);

      // Fetch titles for specific_session_ids if present
      final sessionIds = challenge['specific_session_ids'] as List<dynamic>?;
      if (sessionIds != null && sessionIds.isNotEmpty) {
        try {
          final sessionsResp = await client
              .from('sessions')
              .select('id, title, title_hindi')
              .inFilter('id', sessionIds);
          challenge['specific_sessions_list'] = List<Map<String, dynamic>>.from(sessionsResp);
        } catch (e) {
          debugPrint('⚠️ Error fetching specific sessions: $e');
        }
      }

      // Get leaderboard (all participants with progress)
      final participants = await client
          .from('tapasya_challenge_participants')
          .select('*, user:user_id(id, full_name, avatar_url)')
          .eq('challenge_id', challengeId)
          .eq('status', 'accepted')
          .order('current_progress', ascending: false);

      final leaderboard = List<Map<String, dynamic>>.from(participants);

      // Assign ranks
      for (int i = 0; i < leaderboard.length; i++) {
        leaderboard[i]['rank'] = i + 1;
        // Extract display name from user profile
        final userData = leaderboard[i]['user'];
        if (userData != null) {
          leaderboard[i]['display_name'] = userData['full_name'] ?? 'User';
          leaderboard[i]['avatar_url'] = userData['avatar_url'];
        } else {
          leaderboard[i]['display_name'] = 'User';
        }
        leaderboard[i]['is_me'] = leaderboard[i]['user_id'] == userId;
      }

      challenge['leaderboard'] = leaderboard;
      challenge['participant_count'] = leaderboard.length;

      return challenge;
    } catch (e) {
      debugPrint('❌ Error getting challenge detail: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════
  // PROGRESS SYNC (Auto-tracking)
  // ══════════════════════════════════════════

  /// Called after each practice session. Auto-updates all active challenges.
  /// This is the KEY integration point — users practice normally,
  /// challenges track automatically.
  Future<void> syncChallengeProgress({
    required String userId,
    required String category,
    String? sessionId,
    required int durationSeconds,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      final durationMinutes = (durationSeconds / 60).round();
      if (durationMinutes < 1) return; // Ignore very short sessions

      // Find all active challenges this user is participating in
      final participations = await client
          .from('tapasya_challenge_participants')
          .select('id, challenge_id, current_progress')
          .eq('user_id', userId)
          .eq('status', 'accepted');

      if ((participations as List).isEmpty) return;

      final challengeIds = participations.map((p) => p['challenge_id']).toList();

      // Get active challenges that match this session's category
      final activeChallenges = await client
          .from('tapasya_challenges')
          .select('id, category, goal_type, specific_session_id, specific_session_ids')
          .inFilter('id', challengeIds)
          .eq('status', 'active');

      for (final challenge in (activeChallenges as List)) {
        final challengeCategory = challenge['category'] as String;
        final specificSession = challenge['specific_session_id'] as String?;
        final specificSessionIds = challenge['specific_session_ids'] as List<dynamic>?;

        // Check category match
        if (challengeCategory != 'any' && challengeCategory != category) continue;

        // Check specific session match (multiple or single)
        if (specificSessionIds != null && specificSessionIds.isNotEmpty) {
          if (sessionId == null || !specificSessionIds.contains(sessionId)) continue;
        } else if (specificSession != null && specificSession != sessionId) {
          continue;
        }

        // Find participation record
        final participation = participations.firstWhere(
          (p) => p['challenge_id'] == challenge['id'],
        );

        final goalType = challenge['goal_type'] as String;
        int incrementValue;

        switch (goalType) {
          case 'total_minutes':
            incrementValue = durationMinutes;
            break;
          case 'session_count':
            incrementValue = 1;
            break;
          case 'streak_days':
            incrementValue = 1; // Will be deduplicated by UNIQUE(participant_id, date)
            break;
          default:
            continue;
        }

        // Update daily progress (upsert — accumulate within the day)
        final today = DateTime.now().toIso8601String().substring(0, 10);

        // First, read existing daily value if any
        final existingDaily = await client
            .from('tapasya_challenge_progress')
            .select('value')
            .eq('participant_id', participation['id'])
            .eq('date', today)
            .maybeSingle();

        final existingValue = (existingDaily != null) ? (existingDaily['value'] as int? ?? 0) : 0;
        final newDailyValue = goalType == 'streak_days' ? 1 : existingValue + incrementValue;

        await client.from('tapasya_challenge_progress').upsert(
          {
            'participant_id': participation['id'],
            'date': today,
            'value': newDailyValue,
          },
          onConflict: 'participant_id,date',
        );

        // Recalculate total progress for this participant
        final progressRows = await client
            .from('tapasya_challenge_progress')
            .select('value')
            .eq('participant_id', participation['id']);

        int totalProgress = 0;
        for (final row in (progressRows as List)) {
          totalProgress += (row['value'] as int? ?? 0);
        }

        // Update participant's total progress
        await client
            .from('tapasya_challenge_participants')
            .update({'current_progress': totalProgress})
            .eq('id', participation['id']);

        debugPrint('📊 Tapasya: Updated progress for challenge ${challenge['id']} → $totalProgress');
      }

      // Recalculate rankings for affected challenges
      for (final challengeId in challengeIds) {
        await _recalculateRankings(challengeId);
      }

      // Check for badge awards
      await checkAndAwardBadges(userId);
    } catch (e) {
      debugPrint('❌ Error syncing challenge progress: $e');
    }
  }

  /// Recalculate leaderboard rankings for a challenge.
  Future<void> _recalculateRankings(String challengeId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      final participants = await client
          .from('tapasya_challenge_participants')
          .select('id, current_progress')
          .eq('challenge_id', challengeId)
          .eq('status', 'accepted')
          .order('current_progress', ascending: false);

      for (int i = 0; i < (participants as List).length; i++) {
        await client
            .from('tapasya_challenge_participants')
            .update({'rank': i + 1})
            .eq('id', participants[i]['id']);
      }
    } catch (e) {
      debugPrint('⚠️ Error recalculating rankings: $e');
    }
  }

  // ══════════════════════════════════════════
  // BADGES
  // ══════════════════════════════════════════

  /// Get all badges (with earned status for current user).
  Future<List<Map<String, dynamic>>> getAllBadges() async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final userId = client.auth.currentUser?.id;

      final badges = await client
          .from('tapasya_badges')
          .select('*')
          .order('category');

      final result = List<Map<String, dynamic>>.from(badges);

      if (userId != null) {
        final earned = await client
            .from('tapasya_user_badges')
            .select('badge_id, earned_at')
            .eq('user_id', userId);

        final earnedMap = {
          for (var e in (earned as List)) e['badge_id']: e['earned_at']
        };

        for (var badge in result) {
          badge['is_earned'] = earnedMap.containsKey(badge['id']);
          badge['earned_at'] = earnedMap[badge['id']];
        }
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error getting badges: $e');
      return [];
    }
  }

  /// Get only earned badges for current user.
  Future<List<Map<String, dynamic>>> getMyBadges() async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      final earned = await client
          .from('tapasya_user_badges')
          .select('*, badge:badge_id(*)')
          .eq('user_id', userId)
          .order('earned_at', ascending: false);

      return List<Map<String, dynamic>>.from(earned);
    } catch (e) {
      debugPrint('❌ Error getting my badges: $e');
      return [];
    }
  }

  /// Check and award any new badges after a practice session.
  Future<void> checkAndAwardBadges(String userId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      // Get all badge definitions
      final badges = await client.from('tapasya_badges').select('*');

      // Get already earned badges
      final earned = await client
          .from('tapasya_user_badges')
          .select('badge_id')
          .eq('user_id', userId);
      final earnedIds = (earned as List).map((e) => e['badge_id']).toSet();

      for (final badge in (badges as List)) {
        if (earnedIds.contains(badge['id'])) continue; // Already earned

        final conditionType = badge['condition_type'] as String;
        final conditionValue = badge['condition_value'] as int;
        bool shouldAward = false;

        switch (conditionType) {
          case 'challenge_wins':
            // Count completed challenges where user is rank 1
            // Join with challenges to filter only completed ones
            final allParticipations = await client
                .from('tapasya_challenge_participants')
                .select('id, challenge_id, rank')
                .eq('user_id', userId)
                .eq('rank', 1);

            int winCount = 0;
            for (final p in (allParticipations as List)) {
              final ch = await client
                  .from('tapasya_challenges')
                  .select('status')
                  .eq('id', p['challenge_id'])
                  .maybeSingle();
              if (ch != null && ch['status'] == 'completed') {
                winCount++;
              }
            }
            shouldAward = winCount >= conditionValue;
            break;

          case 'challenges_created':
            final created = await client
                .from('tapasya_challenges')
                .select('id')
                .eq('creator_id', userId);
            shouldAward = (created as List).length >= conditionValue;
            break;

          case 'challenges_joined':
            final joined = await client
                .from('tapasya_challenge_participants')
                .select('id')
                .eq('user_id', userId)
                .eq('status', 'accepted');
            shouldAward = (joined as List).length >= conditionValue;
            break;

          case 'total_sessions':
            final sessions = await client
                .from('practice_sessions')
                .select('id')
                .eq('user_id', userId);
            shouldAward = (sessions as List).length >= conditionValue;
            break;

          case 'total_minutes':
            final sessions = await client
                .from('practice_sessions')
                .select('duration_seconds')
                .eq('user_id', userId);
            int totalMinutes = 0;
            for (final s in (sessions as List)) {
              totalMinutes += ((s['duration_seconds'] as int? ?? 0) / 60).round();
            }
            shouldAward = totalMinutes >= conditionValue;
            break;
        }

        if (shouldAward) {
          await client.from('tapasya_user_badges').insert({
            'user_id': userId,
            'badge_id': badge['id'],
          });

          await _logActivity(
            userId: userId,
            actionType: 'badge_earned',
            metadata: {
              'badge_id': badge['id'],
              'badge_title': badge['title'],
              'badge_icon': badge['icon'],
            },
          );

          debugPrint('🏅 Badge awarded: ${badge['title_en']} to $userId');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error checking badges: $e');
    }
  }

  // ══════════════════════════════════════════
  // ACTIVITY FEED
  // ══════════════════════════════════════════

  /// Get global activity feed (latest activities across all).
  Future<List<Map<String, dynamic>>> getActivityFeed({int limit = 20, int offset = 0}) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final feed = await client
          .from('tapasya_activity_feed')
          .select('*, user:user_id(id, full_name, avatar_url)')
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final result = List<Map<String, dynamic>>.from(feed);

      // Extract display names
      for (var activity in result) {
        final userData = activity['user'];
        if (userData != null) {
          activity['display_name'] = userData['full_name'] ?? 'User';
          activity['avatar_url'] = userData['avatar_url'];
        } else {
          activity['display_name'] = 'User';
        }

        // Get reaction counts
        final reactions = await client
            .from('tapasya_reactions')
            .select('emoji')
            .eq('activity_id', activity['id']);
        
        final emojiCounts = <String, int>{};
        for (final r in (reactions as List)) {
          final emoji = r['emoji'] as String;
          emojiCounts[emoji] = (emojiCounts[emoji] ?? 0) + 1;
        }
        activity['reactions'] = emojiCounts;
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error getting activity feed: $e');
      return [];
    }
  }

  /// Add a reaction to an activity.
  Future<bool> addReaction(String activityId, String emoji) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      await client.from('tapasya_reactions').upsert(
        {
          'activity_id': activityId,
          'user_id': userId,
          'emoji': emoji,
        },
        onConflict: 'activity_id,user_id',
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error adding reaction: $e');
      return false;
    }
  }

  // ══════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════

  /// Generate a shareable challenge invite link.
  static String generateChallengeLink(String challengeId) {
    return 'https://dincharya.app/challenge/$challengeId';
  }

  /// Generate invite text for sharing via WhatsApp/Telegram.
  static String generateChallengeShareText(Map<String, dynamic> challenge) {
    final title = challenge['title'] ?? 'Challenge';
    final category = challenge['category'] ?? 'any';
    final goalType = challenge['goal_type'] ?? 'total_minutes';
    final goalValue = challenge['goal_value'] ?? 0;
    final durationDays = challenge['duration_days'] ?? 7;
    final link = generateChallengeLink(challenge['id']);

    String goalText;
    switch (goalType) {
      case 'total_minutes':
        goalText = '$goalValue minutes';
        break;
      case 'session_count':
        goalText = '$goalValue sessions';
        break;
      case 'streak_days':
        goalText = '$goalValue day streak';
        break;
      default:
        goalText = '$goalValue';
    }

    final emoji = category == 'yoga' ? '🧘' : category == 'pranayama' ? '🌬️' : '🧘‍♂️';

    return '$emoji $title\n'
        'Goal: $goalText in $durationDays days\n\n'
        'Can you beat me? Join the challenge:\n'
        '$link\n\n'
        '— via Dincharya 🕉️';
  }

  /// Log an activity to the feed.
  // ══════════════════════════════════════════
  // CIRCLES (Phase 2)
  // ══════════════════════════════════════════

  /// Create a new circle/group.
  Future<Map<String, dynamic>?> createCircle({
    required String name,
    String? description,
    String? avatarUrl,
    bool isPublic = false,
    int maxMembers = 50,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final circleData = {
        'name': name,
        'description': description ?? '',
        'avatar_url': avatarUrl,
        'creator_id': userId,
        'is_public': isPublic,
        'max_members': maxMembers,
      };

      final response = await client
          .from('tapasya_circles')
          .insert(circleData)
          .select()
          .single();

      final circle = Map<String, dynamic>.from(response);

      // Auto-add creator as admin member
      await client.from('tapasya_circle_members').insert({
        'circle_id': circle['id'],
        'user_id': userId,
        'role': 'admin',
      });

      // Log activity
      await _logActivity(
        userId: userId,
        actionType: 'circle_created',
        circleId: circle['id'],
        metadata: {
          'circle_id': circle['id'],
          'name': name,
        },
      );

      debugPrint('👥 Circle created: $name (${circle['id']})');
      return circle;
    } catch (e) {
      debugPrint('❌ Error creating circle: $e');
      return null;
    }
  }

  /// Join a circle by ID or invite code.
  Future<bool> joinCircle({String? circleId, String? inviteCode}) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      // Find circle
      Map<String, dynamic>? circle;
      if (circleId != null) {
        final resp = await client
            .from('tapasya_circles')
            .select()
            .eq('id', circleId)
            .maybeSingle();
        if (resp != null) circle = Map<String, dynamic>.from(resp);
      } else if (inviteCode != null) {
        final resp = await client
            .from('tapasya_circles')
            .select()
            .eq('invite_code', inviteCode)
            .maybeSingle();
        if (resp != null) circle = Map<String, dynamic>.from(resp);
      }

      if (circle == null) {
        debugPrint('⚠️ Circle not found');
        return false;
      }

      // Check if already a member
      final existing = await client
          .from('tapasya_circle_members')
          .select('id')
          .eq('circle_id', circle['id'])
          .eq('user_id', userId)
          .maybeSingle();

      if (existing != null) {
        debugPrint('⚠️ Already a member of this circle');
        return true;
      }

      // Check member limit
      final countResp = await client
          .from('tapasya_circle_members')
          .select('id')
          .eq('circle_id', circle['id']);
      
      if ((countResp as List).length >= (circle['max_members'] ?? 50)) {
        debugPrint('⚠️ Circle is full');
        return false;
      }

      // Join
      await client.from('tapasya_circle_members').insert({
        'circle_id': circle['id'],
        'user_id': userId,
        'role': 'member',
      });

      // Log activity
      await _logActivity(
        userId: userId,
        actionType: 'circle_joined',
        circleId: circle['id'],
        metadata: {
          'circle_id': circle['id'],
          'name': circle['name'],
        },
      );

      debugPrint('👥 Joined circle: ${circle['name']}');
      return true;
    } catch (e) {
      debugPrint('❌ Error joining circle: $e');
      return false;
    }
  }

  /// Leave a circle.
  Future<bool> leaveCircle(String circleId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      await client
          .from('tapasya_circle_members')
          .delete()
          .eq('circle_id', circleId)
          .eq('user_id', userId);

      debugPrint('👥 Left circle: $circleId');
      return true;
    } catch (e) {
      debugPrint('❌ Error leaving circle: $e');
      return false;
    }
  }

  /// Get all circles the current user is part of.
  Future<List<Map<String, dynamic>>> getMyCircles() async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final userId = client.auth.currentUser?.id;
      if (userId == null) return [];

      // Get circle IDs user is member of
      final memberships = await client
          .from('tapasya_circle_members')
          .select('circle_id, role')
          .eq('user_id', userId);

      if ((memberships as List).isEmpty) return [];

      final circleIds = memberships.map((m) => m['circle_id']).toList();

      // Fetch circle details
      final circles = await client
          .from('tapasya_circles')
          .select('*')
          .inFilter('id', circleIds)
          .order('created_at', ascending: false);

      final result = List<Map<String, dynamic>>.from(circles);

      // Attach member counts and user role
      for (var circle in result) {
        final membership = memberships.firstWhere(
          (m) => m['circle_id'] == circle['id'],
          orElse: () => {},
        );
        circle['my_role'] = membership['role'] ?? 'member';

        final mCount = await client
            .from('tapasya_circle_members')
            .select('id')
            .eq('circle_id', circle['id']);
        circle['member_count'] = (mCount as List).length;
      }

      return result;
    } catch (e) {
      debugPrint('❌ Error getting my circles: $e');
      return [];
    }
  }

  /// Get detailed circle info with members list.
  Future<Map<String, dynamic>?> getCircleDetail(String circleId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final userId = client.auth.currentUser?.id;

      // Get circle info
      final resp = await client
          .from('tapasya_circles')
          .select('*')
          .eq('id', circleId)
          .maybeSingle();

      if (resp == null) return null;
      final circle = Map<String, dynamic>.from(resp);

      // Get members list
      final members = await client
          .from('tapasya_circle_members')
          .select('*, user:user_id(id, full_name, avatar_url)')
          .eq('circle_id', circleId)
          .order('joined_at');

      final membersList = List<Map<String, dynamic>>.from(members);

      // Extract display names
      for (var m in membersList) {
        final userData = m['user'];
        if (userData != null) {
          m['display_name'] = userData['full_name'] ?? 'User';
          m['avatar_url'] = userData['avatar_url'];
        } else {
          m['display_name'] = 'User';
        }
        m['is_me'] = m['user_id'] == userId;
      }

      circle['members'] = membersList;
      circle['member_count'] = membersList.length;

      // Get active challenges inside this circle
      final challenges = await client
          .from('tapasya_challenges')
          .select('*')
          .eq('circle_id', circleId)
          .eq('status', 'active');
      circle['challenges'] = List<Map<String, dynamic>>.from(challenges);

      return circle;
    } catch (e) {
      debugPrint('❌ Error getting circle detail: $e');
      return null;
    }
  }

  /// Generate a shareable circle invite link.
  static String generateCircleLink(String inviteCode) {
    return 'https://dincharya.app/circle/$inviteCode';
  }

  /// Generate invite text for sharing a circle.
  static String generateCircleShareText(Map<String, dynamic> circle) {
    final name = circle['name'] ?? 'Circle';
    final code = circle['invite_code'] ?? '';
    final link = generateCircleLink(code);

    return '👥 Join my practice circle "$name" on Dincharya!\n'
        'Let\'s practice yoga and meditation together.\n\n'
        'Click this link to join:\n'
        '$link\n\n'
        'Or use invite code: $code\n\n'
        '— via Dincharya 🕉️';
  }

  // ══════════════════════════════════════════
  // ACTIVITY FEED (Internal/Helpers)
  // ══════════════════════════════════════════

  Future<void> _logActivity({
    required String userId,
    required String actionType,
    Map<String, dynamic>? metadata,
    String? circleId,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      await client.from('tapasya_activity_feed').insert({
        'user_id': userId,
        'circle_id': circleId,
        'action_type': actionType,
        'metadata': metadata ?? {},
      });
    } catch (e) {
      debugPrint('⚠️ Error logging activity: $e');
    }
  }

  // ══════════════════════════════════════════
  // LIVE ROOMS (Phase 3)
  // ══════════════════════════════════════════

  /// Start a new live group practice room.
  Future<Map<String, dynamic>?> startLiveRoom({
    required String circleId,
    required String title,
    required String category,
    int durationSeconds = 600,
    String? sessionId,
  }) async {
    try {
      final client = await _supabase.client;
      if (client == null) return null;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return null;

      final roomData = {
        'circle_id': circleId,
        'host_id': userId,
        'title': title,
        'category': category,
        'duration_seconds': durationSeconds,
        'session_id': sessionId,
        'status': 'active',
        'started_at': DateTime.now().toUtc().toIso8601String(),
      };

      final response = await client
          .from('tapasya_live_rooms')
          .insert(roomData)
          .select()
          .single();

      final room = Map<String, dynamic>.from(response);

      // Auto-join host as participant
      await joinLiveRoom(room['id']);

      debugPrint('🔴 Live Room started: $title (${room['id']})');
      return room;
    } catch (e) {
      debugPrint('❌ Error starting live room: $e');
      return null;
    }
  }

  /// Join a live practice room.
  Future<bool> joinLiveRoom(String roomId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      final nowString = DateTime.now().toUtc().toIso8601String();

      await client.from('tapasya_live_participants').upsert({
        'room_id': roomId,
        'user_id': userId,
        'joined_at': nowString,
        'last_ping': nowString,
      });

      return true;
    } catch (e) {
      debugPrint('❌ Error joining live room: $e');
      return false;
    }
  }

  /// Leave a live practice room.
  Future<bool> leaveLiveRoom(String roomId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      await client
          .from('tapasya_live_participants')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);

      return true;
    } catch (e) {
      debugPrint('❌ Error leaving live room: $e');
      return false;
    }
  }

  /// Send a ping to indicate user is still active in the live room.
  Future<void> updatePing(String roomId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      await client
          .from('tapasya_live_participants')
          .update({'last_ping': DateTime.now().toUtc().toIso8601String()})
          .eq('room_id', roomId)
          .eq('user_id', userId);
    } catch (e) {
      debugPrint('❌ Error pinging in live room: $e');
    }
  }

  /// Get active participants (pinged in the last 20 seconds).
  Future<List<Map<String, dynamic>>> getActiveParticipants(String roomId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      // Calculate cutoff time (20 seconds ago)
      final cutoff = DateTime.now().toUtc().subtract(const Duration(seconds: 20)).toIso8601String();

      final response = await client
          .from('tapasya_live_participants')
          .select('*, user:user_id(id, full_name, avatar_url)')
          .eq('room_id', roomId)
          .gte('last_ping', cutoff);

      final list = List<Map<String, dynamic>>.from(response);

      // Extract display names
      for (var m in list) {
        final userData = m['user'];
        if (userData != null) {
          m['display_name'] = userData['full_name'] ?? 'User';
          m['avatar_url'] = userData['avatar_url'];
        } else {
          m['display_name'] = 'User';
        }
      }

      return list;
    } catch (e) {
      debugPrint('❌ Error getting active live participants: $e');
      return [];
    }
  }

  /// End a live practice room.
  Future<bool> endLiveRoom(String roomId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      // Update room status
      await client
          .from('tapasya_live_rooms')
          .update({'status': 'completed'})
          .eq('id', roomId);

      // Clean up participants
      await client
          .from('tapasya_live_participants')
          .delete()
          .eq('room_id', roomId);

      debugPrint('🔴 Live Room ended: $roomId');
      return true;
    } catch (e) {
      debugPrint('❌ Error ending live room: $e');
      return false;
    }
  }

  /// Get active live rooms for a circle.
  Future<List<Map<String, dynamic>>> getActiveLiveRooms(String circleId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final response = await client
          .from('tapasya_live_rooms')
          .select('*')
          .eq('circle_id', circleId)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      final rooms = List<Map<String, dynamic>>.from(response);

      // Filter out rooms that are logically expired based on started_at + duration
      final activeRooms = <Map<String, dynamic>>[];
      for (final room in rooms) {
        final startedAt = DateTime.tryParse(room['started_at'] ?? '');
        final durationSec = room['duration_seconds'] ?? 600;

        if (startedAt != null) {
          final timeElapsed = DateTime.now().toUtc().difference(startedAt);
          if (timeElapsed.inSeconds < durationSec) {
            // Room is still running
            // Get live participant count
            final pCount = await client
                .from('tapasya_live_participants')
                .select('id')
                .eq('room_id', room['id']);
            room['participant_count'] = (pCount as List).length;
            activeRooms.add(room);
          } else {
            // Clean up old room status in background
            endLiveRoom(room['id']);
          }
        }
      }

      return activeRooms;
    } catch (e) {
      debugPrint('❌ Error getting active live rooms: $e');
      return [];
    }
  }

  /// Send predefined reaction/encouragement message inside a live room.
  Future<bool> sendLiveRoomMessage(String roomId, String messageText, String circleId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      await _logActivity(
        userId: userId,
        actionType: 'live_room_message',
        circleId: circleId,
        metadata: {
          'room_id': roomId,
          'message': messageText,
        },
      );

      return true;
    } catch (e) {
      debugPrint('❌ Error sending live room message: $e');
      return false;
    }
  }

  /// Get recent chat messages/reactions sent inside the room.
  Future<List<Map<String, dynamic>>> getLiveRoomMessages(String roomId, String circleId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      // Query from tapasya_activity_feed
      final response = await client
          .from('tapasya_activity_feed')
          .select('*, user:user_id(id, full_name, avatar_url)')
          .eq('circle_id', circleId)
          .eq('action_type', 'live_room_message')
          .order('created_at', ascending: false)
          .limit(15);

      final list = List<Map<String, dynamic>>.from(response);

      // Filter messages specifically for this room_id in metadata
      final roomMessages = <Map<String, dynamic>>[];
      for (var m in list) {
        final metadata = m['metadata'] as Map<String, dynamic>? ?? {};
        if (metadata['room_id'] == roomId) {
          final userData = m['user'];
          if (userData != null) {
            m['display_name'] = userData['full_name'] ?? 'User';
          } else {
            m['display_name'] = 'User';
          }
          m['message'] = metadata['message'] ?? '';
          roomMessages.add(m);
        }
      }

      return roomMessages;
    } catch (e) {
      debugPrint('❌ Error getting live room messages: $e');
      return [];
    }
  }

  /// Fetch active guided sessions by category.
  Future<List<Map<String, dynamic>>> getSessionsByCategory(String category) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      var builder = client.from('sessions').select('id, title, title_hindi, category, thumbnail_url, media_url').eq('is_active', true);
      if (category != 'any') {
        builder = builder.eq('category', category);
      }

      final response = await builder.order('title');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching sessions by category: $e');
      return [];
    }
  }

  /// Cancel a challenge (creator only).
  Future<bool> cancelChallenge(String challengeId) async {
    try {
      final client = await _supabase.client;
      if (client == null) return false;

      final userId = client.auth.currentUser?.id;
      if (userId == null) return false;

      // Verify user is the creator
      final challenge = await client
          .from('tapasya_challenges')
          .select('creator_id')
          .eq('id', challengeId)
          .maybeSingle();

      if (challenge == null || challenge['creator_id'] != userId) {
        debugPrint('⚠️ Only the creator can cancel this challenge');
        return false;
      }

      await client
          .from('tapasya_challenges')
          .update({'status': 'cancelled'})
          .eq('id', challengeId);

      debugPrint('🚫 Challenge cancelled: $challengeId');
      return true;
    } catch (e) {
      debugPrint('❌ Error cancelling challenge: $e');
      return false;
    }
  }

  /// Check and complete expired challenges.
  /// Should be called periodically (e.g., on app start).
  Future<void> checkExpiredChallenges() async {
    try {
      final client = await _supabase.client;
      if (client == null) return;

      // Find active challenges that have passed their end date
      final expired = await client
          .from('tapasya_challenges')
          .select('id')
          .eq('status', 'active')
          .lte('ends_at', DateTime.now().toUtc().toIso8601String());

      for (final challenge in (expired as List)) {
        await client
            .from('tapasya_challenges')
            .update({'status': 'completed'})
            .eq('id', challenge['id']);

        debugPrint('🏁 Challenge completed (expired): ${challenge['id']}');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking expired challenges: $e');
    }
  }
}

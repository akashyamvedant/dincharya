// lib/presentation/routine_dashboard/mind_games/mind_games_service.dart
// Scores, streaks, brain age — Supabase-backed persistence.

import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/supabase_service.dart';

class MindGamesService {
  MindGamesService._();
  static final MindGamesService _instance = MindGamesService._();
  factory MindGamesService() => _instance;

  // ── SharedPreferences keys ──
  static const String _prefGameStreak = 'mind_games_streak';
  static const String _prefLastGameDate = 'mind_games_last_date';
  static const String _prefLongestStreak = 'mind_games_longest_streak';
  static const String _prefXp = 'mind_games_xp';
  static const String _prefBestPrefix = 'mind_games_best_'; // + gameType

  // ── XP & Levels ──
  // Level curve: level n needs n*100 XP → total for level L = 100*L*(L+1)/2

  Future<int> getXp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefXp) ?? 0;
  }

  Future<int> addXp(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final xp = (prefs.getInt(_prefXp) ?? 0) + amount;
    await prefs.setInt(_prefXp, xp);
    return xp;
  }

  /// Level for a given XP total (level 1 at 0 XP).
  static int levelForXp(int xp) {
    int level = 1, need = 100, total = 0;
    while (xp >= total + need) {
      total += need;
      level++;
      need = level * 100;
    }
    return level;
  }

  /// Progress 0.0-1.0 inside current level.
  static double levelProgress(int xp) {
    int level = 1, need = 100, total = 0;
    while (xp >= total + need) {
      total += need;
      level++;
      need = level * 100;
    }
    return ((xp - total) / need).clamp(0.0, 1.0);
  }

  /// XP still needed to reach the next level.
  static int xpToNextLevel(int xp) {
    int level = 1, need = 100, total = 0;
    while (xp >= total + need) {
      total += need;
      level++;
      need = level * 100;
    }
    return (total + need) - xp;
  }

  // ── Local best scores (instant, offline-first) ──

  /// Returns true if [score] is a new local best for [gameType].
  /// [lowerIsBetter] for time-based games (reaction, number search).
  Future<bool> submitLocalBest(String gameType, double score,
      {bool lowerIsBetter = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_prefBestPrefix$gameType';
    final prev = prefs.getDouble(key);
    final isBest = prev == null ||
        (lowerIsBetter ? score < prev : score > prev);
    if (isBest) await prefs.setDouble(key, score);
    return isBest;
  }

  Future<double?> getLocalBest(String gameType) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('$_prefBestPrefix$gameType');
  }

  // ── Daily challenge rotation ──

  /// Deterministic index for today's challenge, given [gameCount].
  static int dailyChallengeIndex(int gameCount) {
    final now = DateTime.now();
    final dayOfYear = now.difference(DateTime(now.year, 1, 1)).inDays;
    return dayOfYear % gameCount;
  }

  // ── Game streak ──

  Future<int> getStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefGameStreak) ?? 0;
  }

  Future<bool> markGamePlayed() async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final lastStr = prefs.getString(_prefLastGameDate);
    DateTime? last;

    if (lastStr != null) {
      last = DateTime.parse(lastStr);
      final lastDay = DateTime(last.year, last.month, last.day);

      if (today.difference(lastDay).inDays == 1) {
        // Consecutive day — streak continues
        final streak = (prefs.getInt(_prefGameStreak) ?? 0) + 1;
        await prefs.setInt(_prefGameStreak, streak);

        final longest = prefs.getInt(_prefLongestStreak) ?? 0;
        if (streak > longest) {
          await prefs.setInt(_prefLongestStreak, streak);
        }
      } else if (today.difference(lastDay).inDays > 1) {
        // Streak broken — reset
        await prefs.setInt(_prefGameStreak, 1);
      }
      // Same day — no change
    } else {
      // First time ever
      await prefs.setInt(_prefGameStreak, 1);
      await prefs.setInt(_prefLongestStreak, 1);
    }

    await prefs.setString(_prefLastGameDate, today.toIso8601String());
    return true;
  }

  Future<int> getLongestStreak() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_prefLongestStreak) ?? 0;
  }

  // ── Score persistence ──

  Future<bool> saveScore({
    required String gameType,
    required double score,
    double accuracy = 1.0,
    int reactionTimeMs = 0,
    int roundsCompleted = 1,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final supabase = await SupabaseService().client;
      if (supabase == null) return false;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return false;

      await supabase.from('mind_game_scores').insert({
        'user_id': userId,
        'game_type': gameType,
        'score': score,
        'accuracy': accuracy,
        'reaction_time_ms': reactionTimeMs,
        'rounds_completed': roundsCompleted,
        'metadata': metadata ?? {},
      });

      await markGamePlayed();
      debugPrint('🧠 Score saved: $gameType = $score');
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to save score: $e');
      return false;
    }
  }

  // ── Brain Age calculation ──

  Future<int> calculateBrainAge() async {
    try {
      final supabase = await SupabaseService().client;
      if (supabase == null) return 30;
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return 30; // Default

      // Get average scores across all game types
      final data = await supabase
          .from('mind_game_scores')
          .select('game_type, score, accuracy, reaction_time_ms')
          .eq('user_id', userId);

      if (data == null || data.isEmpty) return 30;

      double compositeScore = 0;
      int count = 0;

      for (final row in data) {
        final score = (row['score'] as num?)?.toDouble() ?? 0;
        final accuracy = (row['accuracy'] as num?)?.toDouble() ?? 1.0;
        final rt = (row['reaction_time_ms'] as num?)?.toInt() ?? 0;

        // Normalize different game types into a common scale
        double normalized = 0;
        switch (row['game_type']) {
          case 'reaction_time':
            normalized = max(0, 100 - (rt / 5.0)); // 500ms = 0, 0ms = 100
            break;
          case 'speed_match':
            normalized = score * accuracy * 100;
            break;
          case 'stroop':
            normalized = score * accuracy;
            break;
          case 'number_search':
            normalized = max(0, 100 - score); // Lower time = better
            break;
          case 'breath_counting':
            normalized = score; // Rounds completed
            break;
          case 'recall_day':
            normalized = score * accuracy * 10;
            break;
          case 'game_2048':
            normalized = max(0, (score / 10).clamp(0.0, 100.0));
            break;
          case 'memory_matrix':
          case 'visual_search':
          case 'number_sequence':
          case 'word_scramble':
          case 'daily_trivia':
            normalized = score / 10; // Score is 0-1000 range
            break;
          case 'digit_span':
            normalized = score / 6; // score ~0-1080
            break;
          case 'tile_match':
            normalized = score / 8;
            break;
          case 'mantra_recall':
          case 'mudra_speed':
          case 'trataka':
          case 'guna_balance':
          case 'asana_sequence':
          case 'shloka':
          case 'mandala_mirror':
          case 'aum_vibration':
            normalized = score / 10;
            break;
          case 'thought_watch':
          case 'mantra_japa':
            normalized = score / 8;
            break;
          case 'non_dominant_hand':
          case 'fist_clench':
          case 'circle_triangle':
          case 'new_thing_daily':
            normalized = score / 6;
            break;
          case 'five_senses':
          case 'stop_tech':
          case 'self_control':
            normalized = score / 8;
            break;
            break;
          case 'sudoku':
          case 'flow_free':
          case 'dual_nback':
            normalized = score / 10; // Score is 0-1000 range
            break;
          case 'wordle':
            normalized = score / 5; // Score up to 1000
            break;
          case 'block_puzzle':
            normalized = score; // Score is already 0-100 range
            break;
          case 'memory_match':
          case 'simon_says':
          case 'odd_one_out':
          case 'quick_math':
          case 'hand_gesture':
          case 'blind_fold':
            normalized = score * accuracy;
            break;
          default:
            normalized = score * accuracy * 50;
        }
        compositeScore += normalized;
        count++;
      }

      final avgScore = count > 0 ? compositeScore / count : 0;

      // Map to "brain age" (lower = better)
      // Raw brain age: 25 + (100 - avgScore) * 0.25
      // Perfect score (100) = brain age 25
      // Average (50) = brain age 37
      // Poor (0) = brain age 50
      final rawAge = 25 + ((100 - avgScore.clamp(0.0, 100.0)) * 0.25);
      return rawAge.round();
    } catch (e) {
      debugPrint('⚠️ Brain age calc failed: $e');
      return 30;
    }
  }

  // ── Best scores per game ──

  Future<Map<String, Map<String, dynamic>>> getBestScores() async {
    try {
      final supabase = await SupabaseService().client;
      if (supabase == null) return {};
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return {};

      final gameTypes = [
        'stroop', 'number_search', 'breath_counting', 'recall_day',
        'speed_match', 'reaction_time', 'memory_match', 'simon_says',
        'odd_one_out', 'quick_math', 'hand_gesture', 'blind_fold',
        'game_2048', 'sudoku', 'wordle', 'block_puzzle', 'flow_free', 'dual_nback',
        'memory_matrix', 'visual_search', 'number_sequence', 'word_scramble',
        'digit_span', 'tile_match', 'daily_trivia',
        'mantra_recall', 'asana_sequence', 'mudra_speed', 'thought_watch',
        'mantra_japa', 'trataka', 'guna_balance', 'mandala_mirror',
        'shloka', 'aum_vibration',
        'non_dominant_hand', 'five_senses', 'fist_clench', 'circle_triangle',
        'new_thing_daily', 'stop_tech', 'self_control',
      ];

      final result = <String, Map<String, dynamic>>{};
      for (final gt in gameTypes) {
        final data = await supabase
            .from('mind_game_scores')
            .select('score, accuracy, reaction_time_ms')
            .eq('user_id', userId)
            .eq('game_type', gt)
            .order('score', ascending: gt == 'reaction_time' || gt == 'number_search')
            .limit(1);

        if (data != null && data.isNotEmpty) {
          result[gt] = Map<String, dynamic>.from(data[0]);
        }
      }

      return result;
    } catch (e) {
      debugPrint('⚠️ Best scores failed: $e');
      return {};
    }
  }

  // ── Supabase migration SQL (run manually or via Antigravity) ──

  static const String migrationSQL = '''
CREATE TABLE IF NOT EXISTS mind_game_scores (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  game_type VARCHAR(50) NOT NULL,
  score NUMERIC NOT NULL DEFAULT 0,
  accuracy NUMERIC DEFAULT 1.0,
  reaction_time_ms INTEGER DEFAULT 0,
  rounds_completed INTEGER DEFAULT 1,
  metadata JSONB DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_mind_game_scores_user
  ON mind_game_scores(user_id, game_type);

CREATE INDEX IF NOT EXISTS idx_mind_game_scores_date
  ON mind_game_scores(created_at DESC);
''';
}

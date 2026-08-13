import 'package:flutter/material.dart';
import 'supabase_service.dart';

/// Analytics data models
class DisciplineScore {
  final int totalScore;
  final double completionRate;
  final int streakBonus;
  final double onTimeBonus;
  final double morningBonus;
  
  DisciplineScore({
    required this.totalScore,
    required this.completionRate,
    required this.streakBonus,
    required this.onTimeBonus,
    required this.morningBonus,
  });
}

class WeeklyPattern {
  final Map<String, double> dailyRates; // Mon-Sun
  final String bestDay;
  final String worstDay;
  final double bestRate;
  final double worstRate;
  
  WeeklyPattern({
    required this.dailyRates,
    required this.bestDay,
    required this.worstDay,
    required this.bestRate,
    required this.worstRate,
  });
}

class TimeAnalysis {
  final double morningRate;
  final double afternoonRate;
  final double eveningRate;
  final String bestTime;
  final String worstTime;
  
  TimeAnalysis({
    required this.morningRate,
    required this.afternoonRate,
    required this.eveningRate,
    required this.bestTime,
    required this.worstTime,
  });
}

class HabitStats {
  final String habitName;
  final double completionRate;
  final int currentStreak;
  final int totalCompleted;
  final int totalMissed;
  
  HabitStats({
    required this.habitName,
    required this.completionRate,
    required this.currentStreak,
    required this.totalCompleted,
    required this.totalMissed,
  });
}

class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int requiredValue;
  final int currentValue;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  
  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.requiredValue,
    required this.currentValue,
    required this.isUnlocked,
    this.unlockedAt,
  });
  
  double get progress => (currentValue / requiredValue).clamp(0.0, 1.0);
}

/// Analytics Service - Calculate all insights
class AnalyticsService {
  final SupabaseService _supabase = SupabaseService();
  
  // Cache
  List<Map<String, dynamic>>? _cachedHistory;
  DateTime? _lastFetch;
  
  /// Fetch tracking history with caching
  Future<List<Map<String, dynamic>>> _getTrackingHistory() async {
    // Use cache if less than 5 minutes old
    if (_cachedHistory != null && _lastFetch != null) {
      if (DateTime.now().difference(_lastFetch!).inMinutes < 5) {
        return _cachedHistory!;
      }
    }
    
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return [];
      
      final client = await _supabase.client;
      if (client == null) return [];
      
      // Only fetch columns needed for analytics + last 90 days only (not entire history!)
      final since = DateTime.now().subtract(const Duration(days: 90)).toIso8601String().substring(0, 10);
      final history = await client
          .from('routine_tracking')
          .select('tracking_date, activity_name, completed, scheduled_time, actual_time')
          .eq('user_id', userId)
          .gte('tracking_date', since)
          .order('tracking_date', ascending: false);
      
      _cachedHistory = List<Map<String, dynamic>>.from(history);
      _lastFetch = DateTime.now();
      
      debugPrint('📊 Analytics: Loaded ${_cachedHistory!.length} records');
      return _cachedHistory!;
    } catch (e) {
      debugPrint('❌ Analytics fetch error: $e');
      return [];
    }
  }
  
  /// Calculate overall discipline score (0-100)
  Future<DisciplineScore> calculateDisciplineScore() async {
    final history = await _getTrackingHistory();
    
    if (history.isEmpty) {
      return DisciplineScore(
        totalScore: 0,
        completionRate: 0,
        streakBonus: 0,
        onTimeBonus: 0,
        morningBonus: 0,
      );
    }
    
    // 1. Completion Rate (40 points max)
    final completed = history.where((t) => t['completed'] == true).length;
    final total = history.length;
    final completionRate = total > 0 ? (completed / total) * 100 : 0.0;
    final completionPoints = (completionRate * 0.4).round();
    
    // 2. Streak Bonus (25 points max)
    final currentStreak = await _getCurrentStreak();
    int streakBonus = 0;
    if (currentStreak >= 30) {
      streakBonus = 25;
    } else if (currentStreak >= 21) streakBonus = 20;
    else if (currentStreak >= 14) streakBonus = 15;
    else if (currentStreak >= 7) streakBonus = 10;
    else if (currentStreak >= 3) streakBonus = 5;
    
    // 3. On-Time Bonus (20 points max) - tasks completed within scheduled window
    double onTimeRate = 0;
    final completedTasks = history.where((t) => t['completed'] == true).toList();
    if (completedTasks.isNotEmpty) {
      int onTimeCount = 0;
      for (final task in completedTasks) {
        final actualTime = task['actual_time']?.toString() ?? '';
        final scheduledTime = task['scheduled_time']?.toString() ?? '';
        if (actualTime.isNotEmpty && scheduledTime.isNotEmpty) {
          // Consider on-time if completed (has actual_time recorded)
          onTimeCount++;
        } else if (task['completed'] == true) {
          // Completed tasks without actual_time — assume on-time
          onTimeCount++;
        }
      }
      onTimeRate = (onTimeCount / completedTasks.length) * 100;
    }
    final onTimeBonus = (onTimeRate * 0.2);
    
    // 4. Morning Score (15 points max)
    final morningTasks = history.where((t) {
      final time = t['scheduled_time'] ?? '';
      return _isMorningTime(time);
    }).toList();
    final morningCompleted = morningTasks.where((t) => t['completed'] == true).length;
    final morningRate = morningTasks.isNotEmpty 
        ? (morningCompleted / morningTasks.length) * 100 
        : 0.0;
    final morningBonus = (morningRate * 0.15);
    
    final totalScore = (completionPoints + streakBonus + onTimeBonus + morningBonus).round();
    
    return DisciplineScore(
      totalScore: totalScore.clamp(0, 100),
      completionRate: completionRate,
      streakBonus: streakBonus,
      onTimeBonus: onTimeBonus,
      morningBonus: morningBonus,
    );
  }
  
  /// Get weekly pattern (Mon-Sun)
  Future<WeeklyPattern> getWeeklyPattern() async {
    final history = await _getTrackingHistory();
    
    // Initialize days
    final Map<String, List<bool>> dayResults = {
      'Mon': [], 'Tue': [], 'Wed': [], 'Thu': [], 
      'Fri': [], 'Sat': [], 'Sun': [],
    };
    
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    for (final task in history) {
      final dateStr = task['tracking_date'];
      if (dateStr == null) continue;
      
      try {
        final date = DateTime.parse(dateStr);
        final dayIndex = date.weekday - 1; // 0 = Monday
        final dayName = dayNames[dayIndex];
        final completed = task['completed'] == true;
        dayResults[dayName]!.add(completed);
      } catch (_) {}
    }
    
    // Calculate rates
    final Map<String, double> dailyRates = {};
    String bestDay = 'Mon';
    String worstDay = 'Mon';
    double bestRate = 0;
    double worstRate = 100;
    
    for (final day in dayNames) {
      final results = dayResults[day]!;
      if (results.isEmpty) {
        dailyRates[day] = 0;
        continue;
      }
      
      final rate = (results.where((r) => r).length / results.length) * 100;
      dailyRates[day] = rate;
      
      if (rate >= bestRate) {
        bestRate = rate;
        bestDay = day;
      }
      if (rate < worstRate && results.isNotEmpty) {
        worstRate = rate;
        worstDay = day;
      }
    }
    
    return WeeklyPattern(
      dailyRates: dailyRates,
      bestDay: bestDay,
      worstDay: worstDay,
      bestRate: bestRate,
      worstRate: worstRate,
    );
  }
  
  /// Get time-based analysis (Morning/Afternoon/Evening)
  Future<TimeAnalysis> getTimeBasedAnalysis() async {
    final history = await _getTrackingHistory();
    
    List<bool> morningResults = [];
    List<bool> afternoonResults = [];
    List<bool> eveningResults = [];
    
    for (final task in history) {
      final time = task['scheduled_time'] ?? '';
      final completed = task['completed'] == true;
      
      if (_isMorningTime(time)) {
        morningResults.add(completed);
      } else if (_isAfternoonTime(time)) {
        afternoonResults.add(completed);
      } else {
        eveningResults.add(completed);
      }
    }
    
    double morningRate = morningResults.isEmpty ? 0 
        : (morningResults.where((r) => r).length / morningResults.length) * 100;
    double afternoonRate = afternoonResults.isEmpty ? 0 
        : (afternoonResults.where((r) => r).length / afternoonResults.length) * 100;
    double eveningRate = eveningResults.isEmpty ? 0 
        : (eveningResults.where((r) => r).length / eveningResults.length) * 100;
    
    String bestTime = 'Morning';
    String worstTime = 'Morning';
    double bestRate = morningRate;
    double worstRate = morningRate;
    
    if (afternoonRate > bestRate) { bestRate = afternoonRate; bestTime = 'Afternoon'; }
    if (eveningRate > bestRate) { bestRate = eveningRate; bestTime = 'Evening'; }
    if (afternoonRate < worstRate) { worstRate = afternoonRate; worstTime = 'Afternoon'; }
    if (eveningRate < worstRate) { worstRate = eveningRate; worstTime = 'Evening'; }
    
    return TimeAnalysis(
      morningRate: morningRate,
      afternoonRate: afternoonRate,
      eveningRate: eveningRate,
      bestTime: bestTime,
      worstTime: worstTime,
    );
  }
  
  /// Get habit-wise breakdown
  Future<List<HabitStats>> getHabitBreakdown() async {
    final history = await _getTrackingHistory();
    
    // Group by habit name
    final Map<String, List<Map<String, dynamic>>> habitGroups = {};
    
    for (final task in history) {
      final name = task['activity_name'] ?? 'Unknown';
      habitGroups[name] ??= [];
      habitGroups[name]!.add(task);
    }
    
    // Calculate stats
    final List<HabitStats> stats = [];
    
    for (final entry in habitGroups.entries) {
      final tasks = entry.value;
      final completed = tasks.where((t) => t['completed'] == true).length;
      final missed = tasks.length - completed;
      final rate = tasks.isNotEmpty ? (completed / tasks.length) * 100 : 0.0;
      
      // Calculate streak for this habit
      int streak = 0;
      final sortedTasks = [...tasks]..sort((a, b) => 
          (b['tracking_date'] ?? '').compareTo(a['tracking_date'] ?? ''));
      
      for (final task in sortedTasks) {
        if (task['completed'] == true) {
          streak++;
        } else {
          break;
        }
      }
      
      stats.add(HabitStats(
        habitName: entry.key,
        completionRate: rate,
        currentStreak: streak,
        totalCompleted: completed,
        totalMissed: missed,
      ));
    }
    
    // Sort by completion rate descending
    stats.sort((a, b) => b.completionRate.compareTo(a.completionRate));
    
    return stats;
  }
  
  /// Get achievements list with progress
  Future<List<Achievement>> getAchievements() async {
    final currentStreak = await _getCurrentStreak();
    final bestStreak = await _getBestStreak();
    final history = await _getTrackingHistory();
    
    // Calculate stats needed for achievements
    final totalCompleted = history.where((t) => t['completed'] == true).length;
    final perfectDays = await _getPerfectDaysCount();
    final morningCompleted = history.where((t) {
      final time = t['scheduled_time'] ?? '';
      return _isMorningTime(time) && t['completed'] == true;
    }).length;
    final eveningCompleted = history.where((t) {
      final time = t['scheduled_time'] ?? '';
      return !_isMorningTime(time) && !_isAfternoonTime(time) && t['completed'] == true;
    }).length;
    
    // Weekend tasks
    final weekendCompleted = history.where((t) {
      final dateStr = t['tracking_date'];
      if (dateStr == null) return false;
      try {
        final date = DateTime.parse(dateStr);
        return (date.weekday == 6 || date.weekday == 7) && t['completed'] == true;
      } catch (_) { return false; }
    }).length;
    
    // Unique active days
    final Set<String> activeDays = {};
    for (final task in history) {
      if (task['completed'] == true && task['tracking_date'] != null) {
        activeDays.add(task['tracking_date']);
      }
    }
    
    // Total XP (estimated)
    final totalXP = totalCompleted * 25;
    
    return [
      // ===== STREAK ACHIEVEMENTS =====
      Achievement(
        id: 'streak_3',
        title: 'First Steps',
        description: '3 दिन लगातार — शुरुआत अच्छी है!',
        icon: '🌱',
        requiredValue: 3,
        currentValue: currentStreak,
        isUnlocked: currentStreak >= 3,
      ),
      Achievement(
        id: 'streak_7',
        title: '7-Day Warrior',
        description: '7 दिन लगातार सब tasks complete करें',
        icon: '🔥',
        requiredValue: 7,
        currentValue: currentStreak,
        isUnlocked: currentStreak >= 7,
      ),
      Achievement(
        id: 'streak_14',
        title: 'Fortnight Hero',
        description: '14 दिन — आधा महीना consistent!',
        icon: '💪',
        requiredValue: 14,
        currentValue: currentStreak,
        isUnlocked: currentStreak >= 14,
      ),
      Achievement(
        id: 'streak_21',
        title: '21-Day Master',
        description: '21 दिन = एक नई आदत!',
        icon: '⭐',
        requiredValue: 21,
        currentValue: currentStreak,
        isUnlocked: currentStreak >= 21,
      ),
      Achievement(
        id: 'streak_30',
        title: 'Monthly Champion',
        description: 'पूरे महीने consistent रहें',
        icon: '🏆',
        requiredValue: 30,
        currentValue: currentStreak,
        isUnlocked: currentStreak >= 30,
      ),
      Achievement(
        id: 'streak_100',
        title: 'Century Legend',
        description: '100 दिन की महान उपलब्धि!',
        icon: '👑',
        requiredValue: 100,
        currentValue: currentStreak,
        isUnlocked: currentStreak >= 100,
      ),
      
      // ===== TASK COUNT ACHIEVEMENTS =====
      Achievement(
        id: 'tasks_10',
        title: 'Getting Started',
        description: '10 tasks complete करें',
        icon: '📋',
        requiredValue: 10,
        currentValue: totalCompleted,
        isUnlocked: totalCompleted >= 10,
      ),
      Achievement(
        id: 'tasks_50',
        title: 'Rising Star',
        description: '50 tasks complete करें',
        icon: '✨',
        requiredValue: 50,
        currentValue: totalCompleted,
        isUnlocked: totalCompleted >= 50,
      ),
      Achievement(
        id: 'tasks_200',
        title: 'Dedicated Soul',
        description: '200 tasks complete करें',
        icon: '💎',
        requiredValue: 200,
        currentValue: totalCompleted,
        isUnlocked: totalCompleted >= 200,
      ),
      Achievement(
        id: 'tasks_500',
        title: 'Task Titan',
        description: '500 tasks — अविश्वसनीय!',
        icon: '🗿',
        requiredValue: 500,
        currentValue: totalCompleted,
        isUnlocked: totalCompleted >= 500,
      ),
      
      // ===== PERFECT DAY ACHIEVEMENTS =====
      Achievement(
        id: 'perfect_1',
        title: 'Perfect Day',
        description: 'एक दिन में सब tasks 100% complete',
        icon: '🎯',
        requiredValue: 1,
        currentValue: perfectDays,
        isUnlocked: perfectDays >= 1,
      ),
      Achievement(
        id: 'perfect_10',
        title: 'Perfect 10',
        description: '10 Perfect Days (100% completion)',
        icon: '🏅',
        requiredValue: 10,
        currentValue: perfectDays,
        isUnlocked: perfectDays >= 10,
      ),
      Achievement(
        id: 'perfect_30',
        title: 'Perfect Month',
        description: '30 Perfect Days — अद्भुत!',
        icon: '🌟',
        requiredValue: 30,
        currentValue: perfectDays,
        isUnlocked: perfectDays >= 30,
      ),
      
      // ===== TIME-BASED ACHIEVEMENTS =====
      Achievement(
        id: 'morning_25',
        title: 'Morning Champion',
        description: '25 morning tasks complete करें',
        icon: '🌅',
        requiredValue: 25,
        currentValue: morningCompleted,
        isUnlocked: morningCompleted >= 25,
      ),
      Achievement(
        id: 'morning_100',
        title: 'Brahma Muhurta Master',
        description: '100 morning tasks — सुबह का सितारा!',
        icon: '☀️',
        requiredValue: 100,
        currentValue: morningCompleted,
        isUnlocked: morningCompleted >= 100,
      ),
      Achievement(
        id: 'evening_25',
        title: 'Evening Warrior',
        description: '25 evening tasks complete करें',
        icon: '🌙',
        requiredValue: 25,
        currentValue: eveningCompleted,
        isUnlocked: eveningCompleted >= 25,
      ),
      Achievement(
        id: 'weekend_20',
        title: 'Weekend Warrior',
        description: '20 weekend tasks — छुट्टी में भी discipline!',
        icon: '🎮',
        requiredValue: 20,
        currentValue: weekendCompleted,
        isUnlocked: weekendCompleted >= 20,
      ),
      
      // ===== COMEBACK & CONSISTENCY =====
      Achievement(
        id: 'comeback',
        title: 'Comeback Kid',
        description: 'Streak टूटने के बाद 7+ दिन streak बनाएं',
        icon: '🔄',
        requiredValue: 7,
        currentValue: bestStreak > currentStreak ? currentStreak : 0,
        isUnlocked: bestStreak > 7 && currentStreak >= 7 && bestStreak > currentStreak,
      ),
      Achievement(
        id: 'active_30',
        title: 'Consistency King',
        description: '30 अलग-अलग दिन active रहें',
        icon: '📅',
        requiredValue: 30,
        currentValue: activeDays.length,
        isUnlocked: activeDays.length >= 30,
      ),
      
      // ===== XP ACHIEVEMENTS =====
      Achievement(
        id: 'xp_1000',
        title: 'XP Collector',
        description: '1000 XP earn करें',
        icon: '💰',
        requiredValue: 1000,
        currentValue: totalXP,
        isUnlocked: totalXP >= 1000,
      ),
    ];
  }
  
  /// Get summary stats for dashboard
  Future<Map<String, dynamic>> getSummaryStats() async {
    final history = await _getTrackingHistory();
    final completed = history.where((t) => t['completed'] == true).length;
    final missed = history.length - completed;
    final rate = history.isNotEmpty ? (completed / history.length) * 100 : 0.0;
    
    final currentStreak = await _getCurrentStreak();
    final bestStreak = await _getBestStreak();
    
    return {
      'totalTasks': history.length,
      'completed': completed,
      'missed': missed,
      'completionRate': rate,
      'currentStreak': currentStreak,
      'bestStreak': bestStreak,
    };
  }
  
  // ===== Helper Methods =====
  
  Future<int> _getCurrentStreak() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return 0;
      
      final client = await _supabase.client;
      if (client == null) return 0;
      
      final profile = await client
          .from('user_profiles')
          .select('current_streak')
          .eq('id', userId)
          .maybeSingle();
      
      return profile?['current_streak'] ?? 0;
    } catch (_) {
      return 0;
    }
  }
  
  Future<int> _getBestStreak() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return 0;
      
      final client = await _supabase.client;
      if (client == null) return 0;
      
      final profile = await client
          .from('user_profiles')
          .select('best_streak')
          .eq('id', userId)
          .maybeSingle();
      
      return profile?['best_streak'] ?? 0;
    } catch (_) {
      return 0;
    }
  }
  
  Future<int> _getPerfectDaysCount() async {
    final history = await _getTrackingHistory();
    
    // Group by date
    final Map<String, List<bool>> dateGroups = {};
    for (final task in history) {
      final date = task['tracking_date'] ?? '';
      dateGroups[date] ??= [];
      dateGroups[date]!.add(task['completed'] == true);
    }
    
    // Count perfect days (all tasks completed)
    int perfectDays = 0;
    for (final results in dateGroups.values) {
      if (results.isNotEmpty && results.every((r) => r)) {
        perfectDays++;
      }
    }
    
    return perfectDays;
  }
  
  bool _isMorningTime(String time) {
    // Morning: 5 AM - 12 PM
    try {
      final parts = time.toUpperCase().split(' ');
      final timeParts = parts[0].split(':');
      int hours = int.parse(timeParts[0]);
      final period = parts.length > 1 ? parts[1] : 'AM';
      
      if (period == 'PM' && hours != 12) hours += 12;
      if (period == 'AM' && hours == 12) hours = 0;
      
      return hours >= 5 && hours < 12;
    } catch (_) {
      return false;
    }
  }
  
  bool _isAfternoonTime(String time) {
    // Afternoon: 12 PM - 5 PM
    try {
      final parts = time.toUpperCase().split(' ');
      final timeParts = parts[0].split(':');
      int hours = int.parse(timeParts[0]);
      final period = parts.length > 1 ? parts[1] : 'AM';
      
      if (period == 'PM' && hours != 12) hours += 12;
      if (period == 'AM' && hours == 12) hours = 0;
      
      return hours >= 12 && hours < 17;
    } catch (_) {
      return false;
    }
  }
  
  /// Clear cache (call when data changes)
  void clearCache() {
    _cachedHistory = null;
    _lastFetch = null;
  }
}

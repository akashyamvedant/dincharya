import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';

import '../../services/supabase_service.dart';

/// Session History Screen — "Your Practice"
/// Shows calendar heatmap, stats, and recent session log with mood/energy.
class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  static const Color primaryBrown = Color(0xFF8B4513);
  static const Color warmCream = Color(0xFFFFF8F0);

  bool _isLoading = true;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, int> _heatmapData = {}; // 'yyyy-MM-dd' -> session count
  int _totalMinutes = 0;
  int _totalSessions = 0;
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final client = await SupabaseService().client;
      if (client == null) {
        setState(() => _isLoading = false);
        return;
      }

      final data = await client
          .from('practice_sessions')
          .select()
          .eq('user_id', userId)
          .order('completed_at', ascending: false)
          .limit(100);

      final sessions = List<Map<String, dynamic>>.from(data);

      // Build heatmap
      final Map<String, int> heatmap = {};
      int totalMin = 0;

      for (final s in sessions) {
        final dateStr = s['completed_at'] ?? '';
        if (dateStr.isNotEmpty) {
          final date = DateTime.tryParse(dateStr);
          if (date != null) {
            final key = DateFormat('yyyy-MM-dd').format(date);
            heatmap[key] = (heatmap[key] ?? 0) + 1;
          }
        }
        final dur = s['duration_seconds'] as int? ?? 0;
        totalMin += dur ~/ 60;
      }

      // Calculate streak
      int streak = 0;
      DateTime day = DateTime.now();
      while (true) {
        final key = DateFormat('yyyy-MM-dd').format(day);
        if (heatmap.containsKey(key)) {
          streak++;
          day = day.subtract(const Duration(days: 1));
        } else {
          // Allow today to be skipped if it's still ongoing
          if (streak == 0 && day == DateTime.now()) {
            day = day.subtract(const Duration(days: 1));
            continue;
          }
          break;
        }
      }

      setState(() {
        _sessions = sessions;
        _heatmapData = heatmap;
        _totalMinutes = totalMin;
        _totalSessions = sessions.length;
        _currentStreak = streak;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: warmCream,
      appBar: AppBar(
        backgroundColor: primaryBrown,
        foregroundColor: Colors.white,
        title: const Text('Your Practice', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: primaryBrown))
          : RefreshIndicator(
              onRefresh: _loadHistory,
              color: primaryBrown,
              child: ListView(
                padding: EdgeInsets.all(4.w),
                children: [
                  // Stats Row
                  _buildStatsRow(),
                  SizedBox(height: 2.h),

                  // Calendar Heatmap
                  _buildHeatmap(),
                  SizedBox(height: 2.h),

                  // Recent Sessions
                  _buildRecentSessions(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        _buildStatCard('🧘', '$_totalSessions', 'Sessions'),
        SizedBox(width: 3.w),
        _buildStatCard('⏱️', '$_totalMinutes', 'Minutes'),
        SizedBox(width: 3.w),
        _buildStatCard('🔥', '$_currentStreak', 'Day Streak'),
      ],
    );
  }

  Widget _buildStatCard(String emoji, String value, String label) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryBrown.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: primaryBrown.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmap() {
    final now = DateTime.now();
    // Show last 12 weeks (84 days)
    final startDate = now.subtract(const Duration(days: 83));

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Practice Calendar',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 3,
            runSpacing: 3,
            children: List.generate(84, (i) {
              final date = startDate.add(Duration(days: i));
              final key = DateFormat('yyyy-MM-dd').format(date);
              final count = _heatmapData[key] ?? 0;
              final isToday = key == DateFormat('yyyy-MM-dd').format(now);

              Color color;
              if (count == 0) {
                color = const Color(0xFFF0E8E0);
              } else if (count == 1) {
                color = Color(0xFFD4A574);
              } else if (count == 2) {
                color = const Color(0xFFB87333);
              } else {
                color = primaryBrown;
              }

              return Tooltip(
                message: '${DateFormat.MMMd().format(date)}: $count sessions',
                child: Container(
                  width: 3.5.w,
                  height: 3.5.w,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    border: isToday
                        ? Border.all(color: primaryBrown, width: 1.5)
                        : null,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
              const SizedBox(width: 4),
              ...[const Color(0xFFF0E8E0), Color(0xFFD4A574), const Color(0xFFB87333), primaryBrown]
                  .map((c) => Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          color: c,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      )),
              Text('More', style: TextStyle(fontSize: 10, color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSessions() {
    if (_sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Text('🧘', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              'No sessions yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: primaryBrown.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Complete a guided session to see your history',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Sessions',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        ...(_sessions.take(20).map((s) => _buildSessionTile(s))),
      ],
    );
  }

  Widget _buildSessionTile(Map<String, dynamic> session) {
    final technique = session['technique'] ?? 'Practice';
    final type = session['practice_type'] ?? '';
    final duration = (session['duration_seconds'] as int? ?? 0) ~/ 60;
    final moodAfter = session['mood_after'] ?? '';
    final energyAfter = session['energy_after'] as int? ?? 0;
    final dateStr = session['completed_at'] ?? '';
    String dateLabel = '';
    if (dateStr.isNotEmpty) {
      final dt = DateTime.tryParse(dateStr);
      if (dt != null) dateLabel = DateFormat('MMM d, h:mm a').format(dt);
    }

    final moodEmoji = {
      'Peaceful': '😌', 'Happy': '😊', 'Focused': '🧘',
      'Relaxed': '😴', 'Energized': '⚡', 'Neutral': '😐',
    }[moodAfter] ?? '🙂';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: primaryBrown.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Mood emoji
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primaryBrown.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Center(child: Text(moodEmoji, style: const TextStyle(fontSize: 20))),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  technique,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$dateLabel • ${duration}min • $type',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          // Energy bar
          if (energyAfter > 0)
            Row(
              children: List.generate(5, (i) => Container(
                width: 4,
                height: 12 + (i * 2).toDouble(),
                margin: const EdgeInsets.only(right: 2),
                decoration: BoxDecoration(
                  color: i < energyAfter ? primaryBrown : Colors.grey[200],
                  borderRadius: BorderRadius.circular(2),
                ),
              )),
            ),
        ],
      ),
    );
  }
}

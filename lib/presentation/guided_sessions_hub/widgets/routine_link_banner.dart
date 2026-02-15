import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/supabase_service.dart';

/// Shows the user's next meditation/yoga routine task with a quick-launch button.
/// Bridges the Routine tab and the Guided Tab for seamless integration.
class RoutineLinkBanner extends StatefulWidget {
  const RoutineLinkBanner({super.key});

  @override
  State<RoutineLinkBanner> createState() => _RoutineLinkBannerState();
}

class _RoutineLinkBannerState extends State<RoutineLinkBanner> {
  Map<String, dynamic>? _nextTask;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _findNextMeditationTask();
  }

  Future<void> _findNextMeditationTask() async {
    try {
      final userId = SupabaseService().currentUser?.id;
      if (userId == null) {
        setState(() => _loaded = true);
        return;
      }

      final tasks = await SupabaseService().getLocalTasks(userId);

      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      // Only show adhyatmik (spiritual) or sharirik (physical) tasks that are NOT completed
      final meditationTasks = tasks.where((t) {
        final category = (t['category'] ?? '').toString().toLowerCase();
        final status = (t['status'] ?? '').toString().toLowerCase();
        final isRelevant = category == 'adhyatmik' || category == 'sharirik';
        final isIncomplete = status != 'completed' && status != 'done';
        return isRelevant && isIncomplete;
      }).toList();

      if (meditationTasks.isEmpty) {
        setState(() => _loaded = true);
        return;
      }

      // Find the next upcoming task by time
      Map<String, dynamic>? best;
      int bestDiff = 99999;

      for (final task in meditationTasks) {
        final timeStr = task['time'] ?? '';
        final taskMinutes = _parseTime(timeStr);
        final diff = taskMinutes - currentMinutes;

        // Prefer upcoming tasks (diff >= -30 means within 30 mins past is ok)
        if (diff >= -30 && diff < bestDiff) {
          bestDiff = diff;
          best = task;
        }
      }

      setState(() {
        _nextTask = best;
        _loaded = true;
      });
    } catch (e) {
      setState(() => _loaded = true);
    }
  }

  int _parseTime(String timeStr) {
    try {
      // Handle formats: "HH:MM", "HH:MM AM/PM", ISO 8601
      if (timeStr.contains('T')) {
        final dt = DateTime.parse(timeStr);
        return dt.hour * 60 + dt.minute;
      }
      final parts = timeStr.trim().split(RegExp(r'[\s:]'));
      int hours = int.parse(parts[0]);
      final minutes = int.parse(parts[1]);
      if (parts.length > 2) {
        final ampm = parts[2].toUpperCase();
        if (ampm == 'PM' && hours != 12) hours += 12;
        if (ampm == 'AM' && hours == 12) hours = 0;
      }
      return hours * 60 + minutes;
    } catch (_) {
      return 720; // noon fallback
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _nextTask == null) return const SizedBox.shrink();

    final task = _nextTask!;
    final name = task['title'] ?? task['activity'] ?? 'Practice';
    final time = task['time'] ?? '';
    final category = (task['category'] ?? '').toString().toLowerCase();
    final isSpiritual = category == 'adhyatmik';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F0EB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0D5C8)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSpiritual
                    ? const Color(0xFF8B4513).withOpacity(0.12)
                    : const Color(0xFFFF7043).withOpacity(0.12),
              ),
              child: Center(
                child: Text(
                  isSpiritual ? '🧘' : '💪',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Task info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'From your routine',
                    style: TextStyle(
                      color: const Color(0xFF8B4513).withOpacity(0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.toString(),
                    style: const TextStyle(
                      color: Color(0xFF2C1810),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (time.isNotEmpty)
                    Text(
                      time,
                      style: TextStyle(
                        color: const Color(0xFF8B4513).withOpacity(0.5),
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            // Quick action
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                // Try to find a matching session from the DB
                try {
                  final client = await SupabaseService().client;
                  if (client != null) {
                    final matchCategory = isSpiritual ? 'meditation' : 'yoga';
                    final sessions = await client
                        .from('sessions')
                        .select()
                        .eq('category', matchCategory)
                        .eq('is_active', true)
                        .order('view_count', ascending: false)
                        .limit(3);

                    if (sessions.isNotEmpty && context.mounted) {
                      // Navigate to the top matching session's media player
                      Navigator.pushNamed(context, '/media-player',
                          arguments: Map<String, dynamic>.from(sessions.first));
                      return;
                    }
                  }
                } catch (_) {}

                // Fallback to generic tools
                if (context.mounted) {
                  if (isSpiritual) {
                    Navigator.pushNamed(context, '/meditation-timer');
                  } else {
                    Navigator.pushNamed(context, '/breathing-exercise');
                  }
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSpiritual
                      ? const Color(0xFF8B4513)
                      : const Color(0xFFFF7043),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: (isSpiritual
                              ? const Color(0xFF8B4513)
                              : const Color(0xFFFF7043))
                          .withOpacity(0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.play_arrow_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Start',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

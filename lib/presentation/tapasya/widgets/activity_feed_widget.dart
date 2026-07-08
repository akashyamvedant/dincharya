// lib/presentation/tapasya/widgets/activity_feed_widget.dart

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class ActivityFeedWidget extends StatelessWidget {
  final Map<String, dynamic> activity;
  final Function(String emoji)? onReact;

  const ActivityFeedWidget({
    super.key,
    required this.activity,
    this.onReact,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = activity['display_name'] ?? 'User';
    final actionType = activity['action_type'] ?? '';
    final metadata = activity['metadata'] as Map<String, dynamic>? ?? {};
    final createdAt = DateTime.tryParse(activity['created_at'] ?? '');
    final reactions = activity['reactions'] as Map<String, dynamic>? ?? {};

    final actionInfo = _getActionInfo(actionType, metadata, displayName);

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 16,
                backgroundColor: actionInfo.color.withOpacity(0.2),
                child: Text(
                  actionInfo.emoji,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: theme.colorScheme.onSurface,
                    ),
                    children: [
                      TextSpan(
                        text: displayName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: ' ${actionInfo.text}'),
                    ],
                  ),
                ),
              ),
              if (createdAt != null)
                Text(
                  _timeAgo(createdAt),
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),

          // Reactions
          if (reactions.isNotEmpty || onReact != null) ...[
            SizedBox(height: 1.h),
            Wrap(
              spacing: 2.w,
              children: [
                ...reactions.entries.map((e) {
                  return GestureDetector(
                    onTap: () => onReact?.call(e.key),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${e.key} ${e.value}',
                        style: TextStyle(fontSize: 12.sp),
                      ),
                    ),
                  );
                }),
                // Add reaction button
                GestureDetector(
                  onTap: () => _showReactionPicker(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.3.h),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    child: Text('+', style: TextStyle(fontSize: 13.sp)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Container(
        padding: EdgeInsets.all(5.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: ['🙏', '👏', '🔥', '💪', '⭐'].map((emoji) {
            return GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                onReact?.call(emoji);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Text(emoji, style: const TextStyle(fontSize: 28)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  _ActionInfo _getActionInfo(String actionType, Map<String, dynamic> metadata, String name) {
    switch (actionType) {
      case 'practice_completed':
        final sessionTitle = metadata['session_title'] ?? 'a session';
        final duration = metadata['duration_minutes'] ?? 0;
        return _ActionInfo(
          emoji: '🧘',
          text: 'completed ${duration}min of $sessionTitle',
          color: const Color(0xFF2E7D32),
        );
      case 'challenge_created':
        return _ActionInfo(
          emoji: '📣',
          text: 'created "${metadata['title'] ?? 'a challenge'}"',
          color: const Color(0xFFE65100),
        );
      case 'challenge_joined':
        return _ActionInfo(
          emoji: '🤝',
          text: 'joined "${metadata['title'] ?? 'a challenge'}"',
          color: const Color(0xFF1565C0),
        );
      case 'challenge_won':
        return _ActionInfo(
          emoji: '🏆',
          text: 'won "${metadata['title'] ?? 'a challenge'}"!',
          color: const Color(0xFFFF6F00),
        );
      case 'badge_earned':
        return _ActionInfo(
          emoji: metadata['badge_icon'] ?? '🏅',
          text: 'earned "${metadata['badge_title'] ?? 'a badge'}" badge',
          color: const Color(0xFFF9A825),
        );
      case 'streak_milestone':
        return _ActionInfo(
          emoji: '🔥',
          text: 'reached a ${metadata['streak_days'] ?? ''}-day streak!',
          color: const Color(0xFFE65100),
        );
      default:
        return _ActionInfo(
          emoji: '✨',
          text: 'did something awesome',
          color: const Color(0xFF6A1B9A),
        );
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).round()}w';
  }
}

class _ActionInfo {
  final String emoji;
  final String text;
  final Color color;

  _ActionInfo({required this.emoji, required this.text, required this.color});
}

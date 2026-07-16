// lib/presentation/tapasya/widgets/challenge_card_widget.dart
//
// Active challenge card — shown in horizontal scroll on Tapasya Hub.
// Uses app theme (Serene Earth Palette) for consistent look.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class ChallengeCardWidget extends StatelessWidget {
  final Map<String, dynamic> challenge;
  final VoidCallback? onTap;

  const ChallengeCardWidget({
    super.key,
    required this.challenge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final title = challenge['title'] ?? 'Challenge';
    final category = challenge['category'] ?? 'any';
    final goalType = challenge['goal_type'] ?? 'total_minutes';
    final goalValue = challenge['goal_value'] ?? 0;
    final myProgress = challenge['my_progress'] ?? 0;
    final myRank = challenge['my_rank'] ?? '-';
    final participantCount = challenge['participant_count'] ?? 0;
    final endsAt = DateTime.tryParse(challenge['ends_at'] ?? '');
    final daysLeft = endsAt != null ? endsAt.difference(DateTime.now()).inDays : 0;

    final progressPercent = goalValue > 0 ? (myProgress / goalValue).clamp(0.0, 1.0) : 0.0;

    final categoryEmoji = _getCategoryEmoji(category);
    final accentColor = _getCategoryAccent(category, theme);

    String goalLabel;
    switch (goalType) {
      case 'total_minutes':
        goalLabel = '$myProgress / $goalValue min';
        break;
      case 'session_count':
        goalLabel = '$myProgress / $goalValue sessions';
        break;
      case 'streak_days':
        goalLabel = '$myProgress / $goalValue days';
        break;
      default:
        goalLabel = '$myProgress / $goalValue';
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72.w,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top accent strip with category ──
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: isDark ? 0.12 : 0.06),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  Text(categoryEmoji, style: TextStyle(fontSize: 13.sp)),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),

            // ── Body content ──
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats chips
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 0.5.h,
                      children: [
                        _buildStatChip('📅 ${daysLeft}d left', theme),
                        _buildStatChip('👥 $participantCount', theme),
                        _buildStatChip('🏅 #$myRank', theme),
                      ],
                    ),

                    const Spacer(),

                    // Progress
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          goalLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${(progressPercent * 100).toInt()}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.8.h),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progressPercent,
                        minHeight: 6,
                        backgroundColor: accentColor.withValues(alpha: isDark ? 0.15 : 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(accentColor),
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

  Widget _buildStatChip(String text, ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.4.h),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// Muted category accent colors that blend with the earth palette
  Color _getCategoryAccent(String category, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    switch (category) {
      case 'yoga':
        return isDark ? const Color(0xFF81C784) : const Color(0xFF4A7C59);
      case 'pranayama':
        return isDark ? const Color(0xFF80CBC4) : const Color(0xFF00796B);
      case 'meditation':
        return isDark ? const Color(0xFFCE93D8) : const Color(0xFF7B1FA2);
      default:
        return theme.colorScheme.tertiary;
    }
  }

  String _getCategoryEmoji(String category) {
    switch (category) {
      case 'yoga':
        return '🧘';
      case 'pranayama':
        return '🌬️';
      case 'meditation':
        return '🕉️';
      default:
        return '🏆';
    }
  }
}

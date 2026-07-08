// lib/presentation/tapasya/widgets/challenge_card_widget.dart

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

    // Category styling
    final categoryColor = _getCategoryColor(category);
    final categoryEmoji = _getCategoryEmoji(category);
    final bgImageUrl = _getCategoryBgImage(category);

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
        width: 76.w,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: categoryColor.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: categoryColor.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(
            children: [
              // Background Image with opacity overlay
              Positioned.fill(
                child: Image.network(
                  bgImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(color: Colors.black),
                ),
              ),
              // Beautiful Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withOpacity(0.85),
                        Colors.black.withOpacity(0.4),
                        categoryColor.withOpacity(0.15),
                      ],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(4.5.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title row
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(1.5.w),
                          decoration: BoxDecoration(
                            color: categoryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Text(categoryEmoji, style: TextStyle(fontSize: 14.sp)),
                        ),
                        SizedBox(width: 2.5.w),
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: const [
                                Shadow(
                                  blurRadius: 6.0,
                                  color: Colors.black87,
                                  offset: Offset(1.0, 1.0),
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    SizedBox(height: 1.5.h),

                    // Stats row with capsule design
                    Row(
                      children: [
                        _buildStatCard('📅', '${daysLeft}d left', theme),
                        SizedBox(width: 2.w),
                        _buildStatCard('👥', '$participantCount active', theme),
                        SizedBox(width: 2.w),
                        _buildStatCard('🏅', 'Rank #$myRank', theme),
                      ],
                    ),

                    const Spacer(),

                    // Progress info
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          goalLabel,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          '${(progressPercent * 100).toInt()}%',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: categoryColor,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 0.8.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        height: 7,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          boxShadow: [
                            BoxShadow(
                              color: categoryColor.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: FractionallySizedBox(
                          widthFactor: progressPercent,
                          alignment: Alignment.centerLeft,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [categoryColor, categoryColor.withOpacity(0.7)],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String emoji, String value, ThemeData theme) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: TextStyle(fontSize: 10.sp)),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 9.5.sp,
              color: Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'yoga':
        return const Color(0xFF4CAF50); // Lively Emerald Green
      case 'pranayama':
        return const Color(0xFF03A9F4); // Ocean Blue
      case 'meditation':
        return const Color(0xFF9C27B0); // Royal Purple
      default:
        return const Color(0xFFFF5722); // Fire Orange
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

  String _getCategoryBgImage(String category) {
    switch (category) {
      case 'yoga':
        return 'https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?q=80&w=400';
      case 'pranayama':
        return 'https://images.unsplash.com/photo-1518241353330-0f7941c2d9b5?q=80&w=400';
      case 'meditation':
        return 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?q=80&w=400';
      default:
        return 'https://images.unsplash.com/photo-1517838277536-f5f99be501cd?q=80&w=400';
    }
  }
}

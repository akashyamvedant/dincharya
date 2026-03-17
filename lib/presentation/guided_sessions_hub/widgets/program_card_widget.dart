import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Card widget for displaying a structured program/course
class ProgramCardWidget extends StatelessWidget {
  final Map<String, dynamic> program;
  final Map<String, dynamic>? enrollment; // null = not enrolled
  final VoidCallback onTap;

  const ProgramCardWidget({
    super.key,
    required this.program,
    this.enrollment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = program['title'] ?? 'Program';
    final titleHindi = program['title_hindi'] ?? '';
    final description = program['description'] ?? '';
    final category = program['category'] ?? 'mixed';
    final difficulty = program['difficulty'] ?? 3;
    final totalSessions = program['total_sessions'] ?? 0;
    final durationDays = program['duration_days'] ?? 7;
    final doshaAffinity = program['dosha_affinity'] as List? ?? [];

    final isEnrolled = enrollment != null;
    final currentIndex = isEnrolled ? (enrollment!['current_session_index'] as int? ?? 0) : 0;
    final progress = totalSessions > 0 ? currentIndex / totalSessions : 0.0;

    final Color cardColor = _getCategoryColor(context, category);
    final Color cardColorLight = cardColor.withOpacity(0.12);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70.w,
        margin: EdgeInsets.only(right: 3.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cardColor.withOpacity(0.9),
              cardColor.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category + dosha badges row
              Row(
                children: [
                  _buildSmallBadge(
                    _getCategoryLabel(category),
                    Colors.white.withOpacity(0.2),
                    Colors.white,
                  ),
                  const Spacer(),
                  if (doshaAffinity.isNotEmpty)
                    ...doshaAffinity.take(2).map((d) => Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: _buildSmallBadge(
                        _doshaEmoji(d.toString()),
                        Colors.white.withOpacity(0.15),
                        Colors.white70,
                      ),
                    )),
                ],
              ),
              SizedBox(height: 1.5.h),

              // Title
              Text(
                title,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.surface,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              if (titleHindi.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  titleHindi,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],

              SizedBox(height: 0.8.h),

              // Description
              Text(
                description,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 11,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 1.5.h),

              // Meta: sessions + days + difficulty
              Row(
                children: [
                  Icon(Icons.play_circle_outline, color: Colors.white70, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '$totalSessions sessions',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.calendar_today_rounded, color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '$durationDays days',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  const Spacer(),
                  ...List.generate(5, (i) => Icon(
                    Icons.circle,
                    size: 6,
                    color: i < difficulty ? Colors.white : Colors.white24,
                  )),
                ],
              ),

              SizedBox(height: 1.5.h),

              // Progress bar or Start button
              if (isEnrolled) ...[
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: Theme.of(context).colorScheme.surface.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Day $currentIndex of $totalSessions',
                  style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.w600),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_rounded, color: Theme.of(context).colorScheme.surface, size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Start Program',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.surface,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  Color _getCategoryColor(BuildContext context, String category) {
    switch (category) {
      case 'meditation':
        return Theme.of(context).colorScheme.primary;
      case 'pranayama':
        return const Color(0xFF4A7C59);
      case 'yoga':
        return const Color(0xFFFF6B35);
      case 'mixed':
        return const Color(0xFFCD853F);
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getCategoryLabel(String category) {
    switch (category) {
      case 'meditation':
        return '🧘 Meditation';
      case 'pranayama':
        return '🌬️ Pranayama';
      case 'yoga':
        return '💪 Yoga';
      case 'mixed':
        return '✨ Mixed';
      default:
        return '📿 Practice';
    }
  }

  String _doshaEmoji(String dosha) {
    switch (dosha.toLowerCase()) {
      case 'vata':
        return '🌬️ V';
      case 'pitta':
        return '🔥 P';
      case 'kapha':
        return '🌊 K';
      default:
        return dosha;
    }
  }
}

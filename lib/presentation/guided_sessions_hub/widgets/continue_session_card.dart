import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// "Continue Where You Left Off" card for the Guided Hub.
/// Shows the last session the user was watching and lets them resume.
class ContinueSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final VoidCallback onResume;

  const ContinueSessionCard({
    super.key,
    required this.session,
    required this.onResume,
  });

  @override
  Widget build(BuildContext context) {
    final title = session['title'] as String? ?? 'Session';
    final titleHindi = session['title_hindi'] as String? ?? '';
    final category = session['category'] as String? ?? '';
    final positionSeconds = session['last_position_seconds'] as int? ?? 0;
    final totalDuration = session['duration'] as int? ?? 600;
    final progress = totalDuration > 0 ? (positionSeconds / totalDuration).clamp(0.0, 1.0) : 0.0;

    final posMin = positionSeconds ~/ 60;
    final posSec = positionSeconds % 60;
    final totalMin = totalDuration ~/ 60;

    return Container(
      margin: EdgeInsets.only(bottom: 2.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8F0), Color(0xFFFDF5EC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF8B4513).withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B4513).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.mediumImpact();
            onResume();
          },
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B4513).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Color(0xFF8B4513),
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Continue Where You Left Off',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF8B4513),
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 0.3.h),
                          Text(
                            '$posMin:${posSec.toString().padLeft(2, '0')} / ${totalMin} min  •  ${_getCategoryEmoji(category)} ${_capitalize(category)}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: const Color(0xFF5D4037).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Play button
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF8B4513), Color(0xFFA0522D)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B4513).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 1.5.h),

                // Session title
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2C1810),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (titleHindi.isNotEmpty) ...[
                  SizedBox(height: 0.3.h),
                  Text(
                    titleHindi,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: const Color(0xFF5D4037),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                SizedBox(height: 1.h),

                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF8B4513).withOpacity(0.1),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF8B4513)),
                  ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${(progress * 100).toInt()}% completed',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: const Color(0xFF5D4037).withOpacity(0.6),
                      ),
                    ),
                    Text(
                      'Tap to resume ▶',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF8B4513),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'meditation': return '🧘';
      case 'pranayama': return '🌬️';
      case 'yoga': return '🧘‍♀️';
      default: return '✨';
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

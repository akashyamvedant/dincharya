import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

/// "Today's Session" hero card — personalized recommendation at top of Guided hub
class TodaysSessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String recommendationReason;
  final VoidCallback onStart;

  const TodaysSessionCard({
    super.key,
    required this.session,
    required this.recommendationReason,
    required this.onStart,
  });

  static const Color primaryBrown = Color(0xFF8B4513);

  @override
  Widget build(BuildContext context) {
    final String title = session['title'] ?? 'Morning Practice';
    final String description = session['description'] ?? '';
    final String category = session['category'] ?? 'meditation';
    final int durationSec = session['duration'] ?? 600;
    final int difficulty = session['difficulty'] ?? 3;
    final String mediaUrl = session['media_url'] ?? '';
    String thumbnailUrl = session['thumbnail_url'] ?? '';

    if (thumbnailUrl.isEmpty && mediaUrl.isNotEmpty) {
      thumbnailUrl = _getYoutubeThumbnail(mediaUrl);
    }

    final int durationMin = durationSec ~/ 60;

    return GestureDetector(
      onTap: onStart,
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 4.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2C1810),
              primaryBrown,
              const Color(0xFFB8651A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: primaryBrown.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Background pattern
              Positioned(
                right: -20,
                top: -20,
                child: Icon(
                  _getCategoryIcon(category),
                  size: 120,
                  color: Colors.white.withOpacity(0.05),
                ),
              ),

              // Content
              Padding(
                padding: EdgeInsets.all(4.w),
                child: Row(
                  children: [
                    // Left content
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Recommended label
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withOpacity(0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.auto_awesome,
                                  color: const Color(0xFFFFD700),
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'TODAY\'S PICK',
                                  style: TextStyle(
                                    color: const Color(0xFFFFD700),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 1.5.h),

                          // Title
                          Text(
                            title,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 0.5.h),

                          // Reason
                          Text(
                            recommendationReason,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 1.5.h),

                          // Duration + Difficulty + Start
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _buildBadge(
                                Icons.access_time_rounded,
                                '$durationMin min',
                              ),
                              _buildBadge(
                                Icons.signal_cellular_alt,
                                _difficultyLabel(difficulty),
                              ),
                            ],
                          ),
                          SizedBox(height: 1.5.h),

                          // Start button
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                              ),
                              borderRadius: BorderRadius.circular(25),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700).withOpacity(0.4),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.play_arrow_rounded,
                                    color: const Color(0xFF2C1810), size: 20),
                                const SizedBox(width: 4),
                                Text(
                                  'Start Now',
                                  style: TextStyle(
                                    color: const Color(0xFF2C1810),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 2.w),

                    // Right thumbnail
                    Expanded(
                      flex: 1,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: AspectRatio(
                          aspectRatio: 0.75,
                          child: thumbnailUrl.isNotEmpty
                              ? CustomImageWidget(
                                  imageUrl: thumbnailUrl,
                                  width: double.infinity,
                                  height: double.infinity,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  color: Colors.white.withOpacity(0.1),
                                  child: Icon(
                                    _getCategoryIcon(category),
                                    color: Colors.white30,
                                    size: 40,
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

  Widget _buildBadge(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 13),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String _difficultyLabel(int difficulty) {
    if (difficulty <= 2) return 'Beginner';
    if (difficulty <= 3) return 'Moderate';
    return 'Advanced';
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'meditation':
        return Icons.self_improvement;
      case 'pranayama':
        return Icons.air;
      case 'yoga':
        return Icons.fitness_center;
      default:
        return Icons.play_circle;
    }
  }

  String _getYoutubeThumbnail(String url) {
    final regExp = RegExp(
      r'(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})',
    );
    final match = regExp.firstMatch(url);
    if (match != null) {
      return 'https://img.youtube.com/vi/${match.group(1)}/hqdefault.jpg';
    }
    return '';
  }
}

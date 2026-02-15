import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import './breathing_animation_widget.dart';

/// Minimal Headspace-inspired Session Card
class SessionCardWidget extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool showBreathingAnimation;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const SessionCardWidget({
    super.key,
    required this.session,
    required this.onTap,
    required this.onLongPress,
    this.showBreathingAnimation = false,
    this.isFavorite = false,
    this.onFavoriteToggle,
  });

  @override
  State<SessionCardWidget> createState() => _SessionCardWidgetState();
}

class _SessionCardWidgetState extends State<SessionCardWidget> {
  bool _isPressed = false;

  // App's Primary Color
  static const Color primaryBrown = Color(0xFF8B4513);
  // ignore: unused_field - kept for theme consistency
  static const Color lightBrown = Color(0xFFFFF8F0);

  @override
  Widget build(BuildContext context) {
    final bool isPremium = widget.session["isPremium"] as bool? ?? 
                           widget.session["is_premium"] as bool? ?? false;
    final int difficulty = widget.session["difficulty"] as int? ?? 1;
    final String title = widget.session["title"] as String? ?? '';
    final String description = widget.session["description"] as String? ?? '';
    final String instructor = widget.session["instructor_name"] as String? ?? 
                               widget.session["instructor"] as String? ?? '';
    final String mediaType = widget.session["media_type"] as String? ?? 'youtube';
    final String category = widget.session["category"] as String? ?? 'meditation';
    final String duration = _formatDuration(widget.session["duration"]);
    final String mediaUrl = widget.session["media_url"] as String? ?? '';
    String imageUrl = widget.session["imageUrl"] as String? ?? 
                      widget.session["thumbnail_url"] as String? ?? '';
    
    if (imageUrl.isEmpty && mediaUrl.isNotEmpty && mediaType == 'youtube') {
      imageUrl = _getYoutubeThumbnail(mediaUrl);
    }

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
        margin: EdgeInsets.only(bottom: 2.h),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: primaryBrown.withOpacity(_isPressed ? 0.15 : 0.08),
                blurRadius: _isPressed ? 20 : 15,
                offset: Offset(0, _isPressed ? 8 : 5),
                spreadRadius: _isPressed ? 2 : 0,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Section
              ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    // Thumbnail Image
                    SizedBox(
                      height: 22.h,
                      width: double.infinity,
                      child: CustomImageWidget(
                        imageUrl: imageUrl,
                        width: double.infinity,
                        height: 22.h,
                        fit: BoxFit.cover,
                      ),
                    ),
                    
                    // Soft gradient overlay
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.1),
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    // Top badges row
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        children: [
                          // Category badge
                          _buildBadge(
                            icon: _getCategoryIcon(category),
                            label: category.toUpperCase(),
                            color: primaryBrown,
                          ),
                          SizedBox(width: 8),
                          // Duration badge
                          _buildBadge(
                            icon: Icons.access_time_rounded,
                            label: duration,
                            color: Colors.black87,
                          ),
                          Spacer(),
                          // Favorite heart
                          if (widget.onFavoriteToggle != null)
                            GestureDetector(
                              onTap: widget.onFavoriteToggle,
                              child: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.9),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black12,
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                                  color: widget.isFavorite ? Colors.red : Colors.grey[600],
                                  size: 18,
                                ),
                              ),
                            ),
                          if (widget.onFavoriteToggle == null) const SizedBox(),
                          SizedBox(width: 4),
                          // Premium badge
                          if (isPremium) _buildPremiumBadge(),
                        ],
                      ),
                    ),
                    
                    // Play button overlay
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryBrown,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryBrown.withOpacity(0.4),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    
                    // Media type indicator
                    Positioned(
                      left: 12,
                      bottom: 12,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: _getMediaTypeColor(mediaType),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_getMediaTypeIcon(mediaType), color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              mediaType.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Breathing animation
                    if (widget.showBreathingAnimation)
                      Positioned(
                        top: 50,
                        right: 12,
                        child: BreathingAnimationWidget(),
                      ),
                  ],
                ),
              ),
              
              // Content Section
              Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title - LARGER
                    Text(
                      title,
                      style: TextStyle(
                        color: Color(0xFF2C1810),
                        fontSize: 20, // Bigger
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    // Instructor
                    if (instructor.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            Icon(Icons.person_outline, size: 13, color: Color(0xFF8B4513)),
                            SizedBox(width: 4),
                            Text(
                              'by $instructor',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF8B4513).withOpacity(0.7),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: 8),
                    
                    // Description - LARGER
                    Text(
                      description,
                      style: TextStyle(
                        color: Color(0xFF6B4423),
                        fontSize: 14, // Bigger
                        height: 1.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: 16),
                    
                    // Bottom row - Difficulty + Start button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Difficulty stars
                        Row(
                          children: [
                            Text(
                              'Difficulty: ',
                              style: TextStyle(
                                color: Color(0xFF6B4423),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            ...List.generate(5, (index) => Icon(
                              index < difficulty ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: index < difficulty ? Color(0xFFFFB800) : Colors.grey[300],
                              size: 18,
                            )),
                          ],
                        ),
                        
                        // Start button
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: primaryBrown,
                            borderRadius: BorderRadius.circular(25),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                              SizedBox(width: 4),
                              Text(
                                'Start',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildBadge({required IconData icon, required String label, required Color color}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Color(0xFFFFD700).withOpacity(0.4),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: Colors.white, size: 14),
          SizedBox(width: 4),
          Text(
            'PRO',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'meditation': return Icons.self_improvement;
      case 'pranayama': return Icons.air;
      case 'yoga': return Icons.fitness_center;
      default: return Icons.play_circle;
    }
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return '10 min';
    if (duration is String) return duration;
    if (duration is int) {
      final minutes = duration ~/ 60;
      return '$minutes min';
    }
    return duration.toString();
  }

  String _getYoutubeThumbnail(String url) {
    final videoId = _extractYoutubeVideoId(url);
    return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
  }

  String _extractYoutubeVideoId(String url) {
    if (url.isEmpty) return '';
    final regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\\/u\\/\w\/)|(embed\/)|(watch\?))\\??v?=?([^#\&?]*).?',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return (match != null && match.group(7)?.length == 11) ? match.group(7)! : '';
  }

  Color _getMediaTypeColor(String mediaType) {
    switch (mediaType) {
      case 'youtube': return Colors.red;
      case 'video': return Colors.blue;
      case 'audio': return Colors.green;
      default: return Colors.grey;
    }
  }

  IconData _getMediaTypeIcon(String mediaType) {
    switch (mediaType) {
      case 'youtube': return Icons.play_circle;
      case 'video': return Icons.video_file;
      case 'audio': return Icons.audiotrack;
      default: return Icons.play_circle;
    }
  }
}

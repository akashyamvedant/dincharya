// Mobile implementation of Media Player (Android/iOS)
// Now plays media INSIDE the app instead of external apps

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';
import '../../services/guided_session_service.dart';
import './widgets/in_app_youtube_player.dart';
import './widgets/in_app_video_player.dart';
import './widgets/in_app_audio_player.dart';

/// Mobile-specific Media Player Widget with Dincharya warm brown theme
/// Now plays YouTube, video, and audio INSIDE the app
class MediaPlayerPlatformWidget extends StatefulWidget {
  final Map<String, dynamic> session;

  const MediaPlayerPlatformWidget({
    super.key,
    required this.session,
  });

  @override
  State<MediaPlayerPlatformWidget> createState() => _MediaPlayerPlatformWidgetState();
}

class _MediaPlayerPlatformWidgetState extends State<MediaPlayerPlatformWidget> {
  bool _hasPlayedMedia = false;
  bool _sessionCompleted = false;
  final GuidedSessionService _guidedService = GuidedSessionService();

  // Warm brown theme colors
  static const Color _primaryBrown = Color(0xFF8B4513);
  static const Color _lightBrown = Color(0xFFD4A574);
  static const Color _darkBrown = Color(0xFF2C1810);
  static const Color _creamBackground = Color(0xFFFDF8F3);
  static const Color _mediumBrown = Color(0xFF5D4037);

  // Track current playback position for resume
  int _currentPositionSeconds = 0;

  void _onMediaStarted() {
    setState(() => _hasPlayedMedia = true);
  }

  void _onMediaCompleted() {
    setState(() => _sessionCompleted = true);
  }

  void _onPositionChanged(int positionSeconds) {
    _currentPositionSeconds = positionSeconds;
  }

  Future<bool> _onWillPop() async {
    // Save session progress for resume
    final sessionId = widget.session['id'] as String?;
    final title = widget.session['title'] as String? ?? 'Session';
    final category = widget.session['category'] as String? ?? 'meditation';
    final totalDuration = (widget.session['duration'] as int?) ?? 600;

    if (sessionId != null && _currentPositionSeconds > 5) {
      await _guidedService.saveSessionProgress(
        sessionId: sessionId,
        sessionTitle: title,
        category: category,
        positionSeconds: _currentPositionSeconds,
        totalDuration: totalDuration,
      );
    }

    // Show interstitial ad when leaving after playing media (natural stopping point)
    if (_hasPlayedMedia) {
      await AdsService().showInterstitialAdWithCapping(InterstitialPlacement.sessionEnded);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session['title'] as String? ?? 'Session';
    final titleHindi = widget.session['title_hindi'] as String? ?? '';
    final description = widget.session['description'] as String? ?? '';
    final duration = widget.session['duration'];
    final difficulty = widget.session['difficulty'] as int? ?? 3;
    final category = widget.session['category'] as String? ?? 'meditation';
    final mediaType = widget.session['media_type'] as String? ?? 'youtube';
    
    // Select correct URL field based on media_type
    // youtube → youtube_url, video → video_url, audio → audio_url
    String mediaUrl = '';
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        mediaUrl = widget.session['youtube_url'] as String? ?? '';
        break;
      case 'video':
        mediaUrl = widget.session['video_url'] as String? ?? '';
        break;
      case 'audio':
        mediaUrl = widget.session['audio_url'] as String? ?? '';
        break;
      default:
        mediaUrl = widget.session['youtube_url'] as String? ?? 
                   widget.session['video_url'] as String? ?? 
                   widget.session['audio_url'] as String? ?? '';
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: _creamBackground,
        appBar: AppBar(
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          backgroundColor: _primaryBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () async {
              await _onWillPop();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // In-App Media Player (YouTube/Video/Audio)
              _buildInAppPlayer(
                mediaType: mediaType,
                mediaUrl: mediaUrl,
                title: title,
                titleHindi: titleHindi,
                category: category,
                sessionId: widget.session['id'] as String?,
                duration: duration,
              ),

              SizedBox(height: 3.h),

              // Session Info Card
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _lightBrown.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: _darkBrown,
                      ),
                    ),
                    if (titleHindi.isNotEmpty) ...[
                      SizedBox(height: 0.5.h),
                      Text(
                        titleHindi,
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: _mediumBrown,
                        ),
                      ),
                    ],
                    SizedBox(height: 2.h),
                    // Stats
                    Wrap(
                      spacing: 2.w,
                      runSpacing: 1.h,
                      children: [
                        _buildStatChip(
                          icon: Icons.timer,
                          label: _formatDuration(duration),
                          color: _primaryBrown,
                        ),
                        _buildStatChip(
                          icon: Icons.signal_cellular_alt,
                          label: _getDifficultyLabel(difficulty),
                          color: _getDifficultyColor(difficulty),
                        ),
                        _buildStatChip(
                          icon: _getMediaIcon(mediaType),
                          label: _getMediaLabel(mediaType),
                          color: _getMediaColor(mediaType),
                        ),
                        _buildStatChip(
                          icon: Icons.category,
                          label: category.toUpperCase(),
                          color: _getCategoryColor(category),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.h),

              // Description Card
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _lightBrown.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.description, color: _primaryBrown, size: 22),
                        SizedBox(width: 2.w),
                        Text(
                          'About This Session',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: _darkBrown,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 15.sp,
                        color: _mediumBrown,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 2.h),

              // Benefits Card
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: _lightBrown.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: _primaryBrown, size: 22),
                        SizedBox(width: 2.w),
                        Text(
                          'Benefits',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: _darkBrown,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    ..._getBenefits(category).map((benefit) => Padding(
                      padding: EdgeInsets.only(bottom: 1.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check_circle, color: _primaryBrown, size: 20),
                          SizedBox(width: 2.w),
                          Expanded(
                            child: Text(
                              benefit,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: _mediumBrown,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  ],
                ),
              ),

              SizedBox(height: 4.h),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the appropriate in-app player based on media_type
  Widget _buildInAppPlayer({
    required String mediaType,
    required String mediaUrl,
    required String title,
    required String? titleHindi,
    required String category,
    required String? sessionId,
    dynamic duration,
  }) {
    // Mark media as started when player is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasPlayedMedia) {
        _onMediaStarted();
      }
    });

    // Handle empty URL
    if (mediaUrl.isEmpty) {
      return _buildNoMediaWidget();
    }

    // Use media_type to select player
    // youtube → YouTube Player (no caching - YouTube ToS)
    // video → Video Player with auto-caching
    // audio → Audio Player with auto-caching
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return InAppYoutubePlayer(
          videoUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          startPositionSeconds: widget.session['last_position_seconds'] as int? ?? 0,
          onPositionChanged: _onPositionChanged,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );

      case 'video':
        return InAppVideoPlayer(
          videoUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          sessionId: sessionId,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );

      case 'audio':
        return InAppAudioPlayer(
          audioUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          category: category,
          sessionId: sessionId,
          durationSeconds: duration is int ? duration : null,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );

      default:
        // Fallback - try YouTube player
        return InAppYoutubePlayer(
          videoUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );
    }
  }

  Widget _buildNoMediaWidget() {
    return Container(
      width: double.infinity,
      height: 25.h,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightBrown.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: Colors.grey[400]),
          SizedBox(height: 2.h),
          Text(
            'No Media Available',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: _darkBrown,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Media URL is not configured for this session',
            style: TextStyle(
              fontSize: 12.sp,
              color: _mediumBrown,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 1.5.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getBenefits(String category) {
    switch (category) {
      case 'meditation':
        return [
          'Reduces stress and anxiety',
          'Improves focus and concentration',
          'Promotes emotional well-being',
          'Better sleep quality',
        ];
      case 'pranayama':
        return [
          'Increases lung capacity',
          'Calms the nervous system',
          'Boosts energy levels',
          'Improves mental clarity',
        ];
      case 'yoga':
        return [
          'Improves flexibility and strength',
          'Reduces muscle tension',
          'Enhances body awareness',
          'Promotes relaxation',
        ];
      default:
        return ['Improves overall well-being'];
    }
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return 'N/A';
    if (duration is int) {
      final minutes = duration ~/ 60;
      return '$minutes min';
    }
    return duration.toString();
  }

  String _getDifficultyLabel(int difficulty) {
    switch (difficulty) {
      case 1: return 'Beginner';
      case 2: return 'Easy';
      case 3: return 'Moderate';
      case 4: return 'Advanced';
      case 5: return 'Expert';
      default: return 'Moderate';
    }
  }

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1:
      case 2:
        return const Color(0xFF4A7C59); // Natural green
      case 3:
        return const Color(0xFFCD853F); // Sandy brown
      case 4:
      case 5:
        return const Color(0xFFFF6B35); // Accent orange
      default:
        return const Color(0xFFCD853F);
    }
  }

  IconData _getMediaIcon(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.headphones;
      default:
        return Icons.play_arrow;
    }
  }

  String _getMediaLabel(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return 'YouTube';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      default:
        return 'Media';
    }
  }

  Color _getMediaColor(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return const Color(0xFFCC3333); // Warm red
      case 'video':
        return const Color(0xFF8B4513); // Earth brown
      case 'audio':
        return const Color(0xFFCD853F); // Sandy brown
      default:
        return _primaryBrown;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'meditation':
        return _primaryBrown;
      case 'pranayama':
        return const Color(0xFF6B7B3C); // Olive green
      case 'yoga':
        return const Color(0xFFB8860B); // Golden brown
      default:
        return _primaryBrown;
    }
  }
}

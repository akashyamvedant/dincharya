// In-App YouTube Player Widget - Clean Single Widget Design
// Plays YouTube videos inside the app without opening external apps

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

/// Professional YouTube Player - Single clean widget
class InAppYoutubePlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? titleHindi;
  final int startPositionSeconds;
  final ValueChanged<int>? onPositionChanged;
  final VoidCallback? onComplete;
  final VoidCallback? onBack;

  const InAppYoutubePlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.titleHindi,
    this.startPositionSeconds = 0,
    this.onPositionChanged,
    this.onComplete,
    this.onBack,
  });

  @override
  State<InAppYoutubePlayer> createState() => _InAppYoutubePlayerState();
}

class _InAppYoutubePlayerState extends State<InAppYoutubePlayer> {
  late YoutubePlayerController _controller;
  bool _isPlayerReady = false;
  bool _isVideoEnded = false;
  bool _hasResumed = false;
  String? _errorMessage;

  // Warm brown theme colors
  static const Color _primaryBrown = Color(0xFF8B4513);
  static const Color _lightBrown = Color(0xFFD4A574);
  static const Color _darkBrown = Color(0xFF2C1810);

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    final videoId = YoutubePlayer.convertUrlToId(widget.videoUrl);
    
    if (videoId == null || videoId.isEmpty) {
      setState(() {
        _errorMessage = 'Invalid YouTube URL. Please check the video link.';
      });
      return;
    }

    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: false,
        mute: false,
        enableCaption: true,
        loop: false,
        forceHD: false,
        controlsVisibleAtStart: true,
        hideControls: false,
        hideThumbnail: false,
        disableDragSeek: false,
        useHybridComposition: true,
      ),
    )..addListener(_playerListener);
  }

  void _playerListener() {
    if (_isPlayerReady && mounted) {
      // Report position changes for save-on-exit
      final posSeconds = _controller.value.position.inSeconds;
      widget.onPositionChanged?.call(posSeconds);

      // Auto-seek to saved position on first ready
      if (!_hasResumed && widget.startPositionSeconds > 0) {
        _hasResumed = true;
        _controller.seekTo(Duration(seconds: widget.startPositionSeconds));
        // Show resume toast
        if (mounted) {
          final min = widget.startPositionSeconds ~/ 60;
          final sec = widget.startPositionSeconds % 60;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.play_circle_fill, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text('Resuming from $min:${sec.toString().padLeft(2, '0')}'),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }

      // Check if video ended
      if (_controller.value.playerState == PlayerState.ended && !_isVideoEnded) {
        setState(() => _isVideoEnded = true);
        widget.onComplete?.call();
      }
    }
  }

  @override
  void deactivate() {
    _controller.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    // Restore orientation
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show error if invalid URL
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Single clean YouTube Player widget with built-in controls
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            // Use YoutubePlayerBuilder for proper fullscreen handling
            child: YoutubePlayerBuilder(
              onExitFullScreen: () {
                // Just restore orientation, don't pause
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.portraitUp,
                  DeviceOrientation.portraitDown,
                ]);
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
              },
              onEnterFullScreen: () {
                // Allow landscape for fullscreen
                SystemChrome.setPreferredOrientations([
                  DeviceOrientation.landscapeLeft,
                  DeviceOrientation.landscapeRight,
                ]);
                SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
              },
              player: YoutubePlayer(
                controller: _controller,
                aspectRatio: 16 / 9,
                showVideoProgressIndicator: true,
                progressIndicatorColor: _primaryBrown,
                progressColors: ProgressBarColors(
                  playedColor: _primaryBrown,
                  handleColor: _lightBrown,
                  bufferedColor: _lightBrown.withOpacity(0.5),
                  backgroundColor: Colors.grey[300]!,
                ),
                onReady: () {
                  setState(() => _isPlayerReady = true);
                },
                onEnded: (data) {
                  setState(() => _isVideoEnded = true);
                  widget.onComplete?.call();
                },
                // Built-in bottom actions from youtube_player_flutter
                bottomActions: [
                  const SizedBox(width: 14),
                  CurrentPosition(),
                  const SizedBox(width: 8),
                  ProgressBar(
                    isExpanded: true,
                    colors: ProgressBarColors(
                      playedColor: _primaryBrown,
                      handleColor: _lightBrown,
                      bufferedColor: _lightBrown.withOpacity(0.5),
                      backgroundColor: Colors.grey[600]!,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RemainingDuration(),
                  PlaybackSpeedButton(controller: _controller),
                  FullScreenButton(),
                ],
              ),
              builder: (context, player) {
                return player;
              },
            ),
          ),
        ),

        // Video ended overlay (only shows when video completes)
        if (_isVideoEnded)
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: _buildVideoEndedOverlay(),
          ),
      ],
    );
  }

  Widget _buildErrorWidget() {
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
          Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
          SizedBox(height: 2.h),
          Text(
            'Video Unavailable',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: _darkBrown,
            ),
          ),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: Text(
              _errorMessage ?? 'An error occurred',
              style: TextStyle(
                fontSize: 12.sp,
                color: _darkBrown.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoEndedOverlay() {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 32),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Complete! 🎉',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  'Great job completing this session',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          // Replay button
          IconButton(
            onPressed: () {
              _controller.seekTo(Duration.zero);
              _controller.play();
              setState(() => _isVideoEnded = false);
            },
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _primaryBrown,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.replay, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

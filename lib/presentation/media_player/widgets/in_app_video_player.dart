// In-App Video Player Widget with Automatic Caching
// Plays video files inside the app using Chewie
// Automatically caches videos for offline playback

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/media_cache_service.dart';

/// Professional Video Player with automatic offline caching
/// 1. First play → Stream from network + Auto-download in background
/// 2. Next play → Play from local cache (no internet needed)
class InAppVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String? titleHindi;
  final String? sessionId;
  final VoidCallback? onComplete;
  final VoidCallback? onBack;

  const InAppVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.title,
    this.titleHindi,
    this.sessionId,
    this.onComplete,
    this.onBack,
  });

  @override
  State<InAppVideoPlayer> createState() => _InAppVideoPlayerState();
}

class _InAppVideoPlayerState extends State<InAppVideoPlayer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isVideoEnded = false;
  
  // Cache status
  bool _isPlayingFromCache = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;
  
  final MediaCacheService _cacheService = MediaCacheService();

  // Warm brown theme colors
  static const Color _primaryBrown = Color(0xFF8B4513);
  static const Color _lightBrown = Color(0xFFD4A574);
  static const Color _darkBrown = Color(0xFF2C1810);
  static const Color _mediumBrown = Color(0xFF5D4037);

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });

      // Dispose old controllers if reinitializing
      await _disposeControllers();

      // Check if video is already cached
      final cachedPath = await _cacheService.getCachedPath(widget.videoUrl);
      
      if (cachedPath != null) {
        // Play from local cache (offline)
        debugPrint('InAppVideoPlayer: Playing from cache: $cachedPath');
        _isPlayingFromCache = true;
        
        _videoPlayerController = VideoPlayerController.file(
          File(cachedPath),
        );
      } else {
        // Play from network and cache in background
        debugPrint('InAppVideoPlayer: Streaming from network: ${widget.videoUrl}');
        _isPlayingFromCache = false;
        
        _videoPlayerController = VideoPlayerController.networkUrl(
          Uri.parse(widget.videoUrl),
          httpHeaders: {
            'User-Agent': 'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36',
          },
        );
        
        // Start background download for future offline use
        _startBackgroundDownload();
      }

      // Add timeout for initialization
      await _videoPlayerController!.initialize().timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          throw Exception('Video loading timed out');
        },
      );

      // Listen for video completion
      _videoPlayerController!.addListener(_videoListener);

      // Initialize Chewie controller with custom options
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        allowFullScreen: true,
        allowMuting: true,
        allowPlaybackSpeedChanging: true,
        playbackSpeeds: const [0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
        showControls: true,
        showControlsOnInitialize: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: _primaryBrown,
          handleColor: _lightBrown,
          bufferedColor: _lightBrown.withOpacity(0.5),
          backgroundColor: Colors.grey[300]!,
        ),
        errorBuilder: (context, errorMessage) {
          return _buildInlineErrorWidget(errorMessage);
        },
        customControls: const MaterialControls(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Video player error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  /// Start background download without blocking playback
  void _startBackgroundDownload() {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });
    
    _cacheService.cacheInBackground(
      url: widget.videoUrl,
      mediaType: 'video',
      sessionId: widget.sessionId,
      onProgress: (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress = progress;
            if (progress >= 1.0) {
              _isDownloading = false;
            }
          });
        }
      },
    );
  }

  Future<void> _disposeControllers() async {
    _videoPlayerController?.removeListener(_videoListener);
    _chewieController?.dispose();
    await _videoPlayerController?.dispose();
    _chewieController = null;
    _videoPlayerController = null;
  }

  void _videoListener() {
    if (_videoPlayerController != null && mounted) {
      final value = _videoPlayerController!.value;
      
      // Check if video ended
      if (value.position >= value.duration && 
          value.duration > Duration.zero &&
          !_isVideoEnded) {
        setState(() => _isVideoEnded = true);
        widget.onComplete?.call();
      }
    }
  }

  Future<void> _openInExternalPlayer() async {
    try {
      final uri = Uri.parse(widget.videoUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not open video'),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening external player: $e');
    }
  }

  @override
  void dispose() {
    _disposeControllers();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Cache status indicator (subtle)
        if (_isPlayingFromCache || _isDownloading)
          _buildCacheStatusIndicator(),
        
        // Video Player
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
            child: AspectRatio(
              aspectRatio: _videoPlayerController?.value.aspectRatio ?? 16/9,
              child: Chewie(controller: _chewieController!),
            ),
          ),
        ),

        // Video ended overlay
        if (_isVideoEnded)
          Padding(
            padding: EdgeInsets.only(top: 2.h),
            child: _buildVideoEndedOverlay(),
          ),
      ],
    );
  }

  /// Subtle indicator showing cache status
  Widget _buildCacheStatusIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 1.h),
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: _isPlayingFromCache 
            ? Colors.green.withOpacity(0.1)
            : _primaryBrown.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isPlayingFromCache) ...[
            Icon(Icons.offline_pin, size: 14, color: Colors.green[700]),
            SizedBox(width: 1.w),
            Text(
              'Playing Offline',
              style: TextStyle(
                fontSize: 10.sp,
                color: Colors.green[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ] else if (_isDownloading) ...[
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                value: _downloadProgress,
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(_primaryBrown),
              ),
            ),
            SizedBox(width: 1.5.w),
            Text(
              'Saving for offline... ${(_downloadProgress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 10.sp,
                color: _mediumBrown,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      width: double.infinity,
      height: 25.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightBrown.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(_primaryBrown),
            strokeWidth: 3,
          ),
          SizedBox(height: 2.h),
          Text(
            _isPlayingFromCache ? 'Loading from cache...' : 'Loading video...',
            style: TextStyle(
              fontSize: 14.sp,
              color: _mediumBrown,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInlineErrorWidget(String message) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: Colors.red[400]),
            SizedBox(height: 2.h),
            Text(
              'Playback Error',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 1.h),
            ElevatedButton.icon(
              onPressed: _openInExternalPlayer,
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open in External Player'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryBrown,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
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
              'This video format may not be supported in-app.',
              style: TextStyle(
                fontSize: 12.sp,
                color: _mediumBrown,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _initializePlayer,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryBrown,
                  side: BorderSide(color: _primaryBrown),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              ElevatedButton.icon(
                onPressed: _openInExternalPlayer,
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open External'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primaryBrown,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
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
                  _isPlayingFromCache 
                      ? 'Played offline - no data used!'
                      : 'Great job completing this session',
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
              _videoPlayerController!.seekTo(Duration.zero);
              _chewieController!.play();
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

// In-App Audio Player Widget with Automatic Caching
// Plays audio files inside the app using audioplayers
// Automatically caches audio for offline playback

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../services/media_cache_service.dart';

/// Professional Audio Player with automatic offline caching
/// 1. First play → Stream from network + Auto-download in background
/// 2. Next play → Play from local cache (no internet needed)
class InAppAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final String title;
  final String? titleHindi;
  final String? category;
  final String? sessionId;
  final int? durationSeconds;
  final VoidCallback? onComplete;
  final VoidCallback? onBack;
  final bool autoPlay;

  const InAppAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.title,
    this.titleHindi,
    this.category,
    this.sessionId,
    this.durationSeconds,
    this.onComplete,
    this.onBack,
    this.autoPlay = false,
  });

  @override
  State<InAppAudioPlayer> createState() => _InAppAudioPlayerState();
}

class _InAppAudioPlayerState extends State<InAppAudioPlayer>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final MediaCacheService _cacheService = MediaCacheService();
  
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _playbackSpeed = 1.0;
  bool _isLoading = true;
  bool _hasError = false;
  String? _errorMessage;
  bool _isAudioEnded = false;

  // Cache status
  bool _isPlayingFromCache = false;
  bool _isDownloading = false;
  double _downloadProgress = 0;

  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerCompleteSubscription;
  StreamSubscription? _playerStateSubscription;

  // Animation for breathing circle
  late AnimationController _breathingController;
  late Animation<double> _breathingAnimation;

  // Warm brown theme colors
  static const Color _primaryBrown = Color(0xFF8B4513);
  static const Color _lightBrown = Color(0xFFD4A574);
  static const Color _darkBrown = Color(0xFF2C1810);
  static const Color _mediumBrown = Color(0xFF5D4037);

  @override
  void initState() {
    super.initState();
    _initBreathingAnimation();
    _initAudioPlayer();
  }

  void _initBreathingAnimation() {
    _breathingController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    _breathingAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _breathingController,
        curve: Curves.easeInOut,
      ),
    );

    _breathingController.repeat(reverse: true);
  }

  Future<void> _initAudioPlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Set up listeners
      _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
        setState(() => _duration = duration);
      });

      _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
        setState(() => _position = position);
      });

      _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
        setState(() => _playerState = state);
        
        // Control breathing animation based on play state
        if (state == PlayerState.playing) {
          _breathingController.repeat(reverse: true);
        } else {
          _breathingController.stop();
        }
      });

      _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((event) {
        setState(() {
          _isAudioEnded = true;
          _position = _duration;
        });
        widget.onComplete?.call();
      });

      // Check if audio is already cached
      final cachedPath = await _cacheService.getCachedPath(widget.audioUrl);
      
      if (cachedPath != null) {
        // Play from local cache (offline)
        debugPrint('InAppAudioPlayer: Playing from cache: $cachedPath');
        _isPlayingFromCache = true;
        
        await _audioPlayer.setSourceDeviceFile(cachedPath);
      } else {
        // Play from network and cache in background
        debugPrint('InAppAudioPlayer: Streaming from network: ${widget.audioUrl}');
        _isPlayingFromCache = false;
        
        await _audioPlayer.setSourceUrl(widget.audioUrl);
        
        // Start background download for future offline use
        _startBackgroundDownload();
      }
      
      // Use provided duration if available
      if (widget.durationSeconds != null) {
        _duration = Duration(seconds: widget.durationSeconds!);
      }

      setState(() {
        _isLoading = false;
      });

      // Auto-play if requested (e.g., guided audio in yoga practice)
      if (widget.autoPlay) {
        await _audioPlayer.resume();
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _hasError = true;
        _errorMessage = 'Failed to load audio: ${e.toString()}';
      });
    }
  }

  /// Start background download without blocking playback
  void _startBackgroundDownload() {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });
    
    _cacheService.cacheInBackground(
      url: widget.audioUrl,
      mediaType: 'audio',
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

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    _breathingController.dispose();
    super.dispose();
  }

  Future<void> _play() async {
    await _audioPlayer.resume();
  }

  Future<void> _pause() async {
    await _audioPlayer.pause();
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> _setPlaybackSpeed(double speed) async {
    await _audioPlayer.setPlaybackRate(speed);
    setState(() => _playbackSpeed = speed);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    
    if (hours > 0) {
      return '${twoDigits(hours)}:${twoDigits(minutes)}:${twoDigits(seconds)}';
    }
    return '${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  IconData _getCategoryIcon() {
    switch (widget.category?.toLowerCase()) {
      case 'meditation':
        return Icons.self_improvement;
      case 'pranayama':
        return Icons.air;
      case 'yoga':
        return Icons.accessibility_new;
      default:
        return Icons.headphones;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_hasError) {
      return _buildErrorWidget();
    }

    // Single clean widget containing everything
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _lightBrown.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: _primaryBrown.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cache status indicator (subtle)
          if (_isPlayingFromCache || _isDownloading)
            _buildCacheStatusIndicator(),
          
          // Breathing Animation Circle with Progress
          _buildBreathingCircle(),
          
          SizedBox(height: 2.h),
          
          // Title
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: _darkBrown,
            ),
            textAlign: TextAlign.center,
          ),
          
          if (widget.titleHindi != null && widget.titleHindi!.isNotEmpty) ...[
            SizedBox(height: 0.5.h),
            Text(
              widget.titleHindi!,
              style: TextStyle(
                fontSize: 14.sp,
                color: _mediumBrown,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          
          SizedBox(height: 2.5.h),
          
          // Progress Slider
          _buildProgressSlider(),
          
          SizedBox(height: 2.h),
          
          // Playback Controls
          _buildPlaybackControls(),
          
          SizedBox(height: 2.h),
          
          // Speed Control
          _buildSpeedControl(),
          
          // Audio ended overlay
          if (_isAudioEnded) ...[
            SizedBox(height: 2.h),
            _buildAudioEndedOverlay(),
          ],
        ],
      ),
    );
  }

  /// Subtle indicator showing cache status
  Widget _buildCacheStatusIndicator() {
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
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
      height: 35.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
            _isPlayingFromCache ? 'Loading from cache...' : 'Loading audio...',
            style: TextStyle(
              fontSize: 14.sp,
              color: _mediumBrown,
            ),
          ),
        ],
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
            'Audio Unavailable',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: _darkBrown,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            _errorMessage ?? 'Failed to load audio',
            style: TextStyle(
              fontSize: 12.sp,
              color: _mediumBrown,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          ElevatedButton.icon(
            onPressed: _initAudioPlayer,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
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
    );
  }

  Widget _buildBreathingCircle() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background circle
        Container(
          width: 45.w,
          height: 45.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _lightBrown.withOpacity(0.1),
          ),
        ),
        
        // Progress ring
        SizedBox(
          width: 43.w,
          height: 43.w,
          child: CircularProgressIndicator(
            value: _duration.inSeconds > 0 
                ? _position.inSeconds / _duration.inSeconds 
                : 0,
            strokeWidth: 5,
            backgroundColor: _lightBrown.withOpacity(0.2),
            valueColor: AlwaysStoppedAnimation<Color>(_primaryBrown),
          ),
        ),
        
        // Breathing animation circle
        AnimatedBuilder(
          animation: _breathingAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _playerState == PlayerState.playing 
                  ? _breathingAnimation.value 
                  : 0.85,
              child: Container(
                width: 35.w,
                height: 35.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _primaryBrown.withOpacity(0.3),
                      _lightBrown.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    if (_playerState == PlayerState.playing)
                      BoxShadow(
                        color: _primaryBrown.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        
        // Session type icon with offline indicator
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                Icon(
                  _getCategoryIcon(),
                  size: 40,
                  color: _primaryBrown,
                ),
                if (_isPlayingFromCache)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.offline_pin,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
            SizedBox(height: 0.5.h),
            Text(
              _playerState == PlayerState.playing ? 'Playing' : 'Paused',
              style: TextStyle(
                fontSize: 11.sp,
                color: _mediumBrown,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProgressSlider() {
    return Column(
      children: [
        // Slider
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: _primaryBrown,
            inactiveTrackColor: _lightBrown.withOpacity(0.3),
            thumbColor: _primaryBrown,
            overlayColor: _primaryBrown.withOpacity(0.2),
            trackHeight: 5,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            min: 0,
            max: _duration.inSeconds.toDouble(),
            value: _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()),
            onChanged: (value) {
              _seek(Duration(seconds: value.toInt()));
            },
          ),
        ),
        
        // Time labels
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 2.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: TextStyle(
                  fontSize: 11.sp,
                  color: _mediumBrown,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: TextStyle(
                  fontSize: 11.sp,
                  color: _mediumBrown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Skip backward 15s
        _buildControlButton(
          icon: Icons.replay_10,
          onTap: () {
            final newPosition = _position - const Duration(seconds: 15);
            _seek(newPosition < Duration.zero ? Duration.zero : newPosition);
          },
          size: 28,
        ),
        
        // Previous (go to start)
        _buildControlButton(
          icon: Icons.skip_previous,
          onTap: () => _seek(Duration.zero),
          size: 32,
        ),
        
        // Play/Pause (larger)
        InkWell(
          onTap: () {
            if (_playerState == PlayerState.playing) {
              _pause();
            } else {
              _play();
            }
          },
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: 16.w,
            height: 16.w,
            decoration: BoxDecoration(
              color: _primaryBrown,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: _primaryBrown.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              _playerState == PlayerState.playing 
                  ? Icons.pause 
                  : Icons.play_arrow,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        
        // Next (go to end)
        _buildControlButton(
          icon: Icons.skip_next,
          onTap: () => _seek(_duration),
          size: 32,
        ),
        
        // Skip forward 15s
        _buildControlButton(
          icon: Icons.forward_10,
          onTap: () {
            final newPosition = _position + const Duration(seconds: 15);
            _seek(newPosition > _duration ? _duration : newPosition);
          },
          size: 28,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required double size,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(2.w),
        child: Icon(
          icon,
          color: _primaryBrown,
          size: size,
        ),
      ),
    );
  }

  Widget _buildSpeedControl() {
    final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.speed, color: _primaryBrown, size: 18),
            SizedBox(width: 2.w),
            Text(
              'Speed',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: _darkBrown,
              ),
            ),
          ],
        ),
        SizedBox(height: 1.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: speeds.map((speed) {
            final isSelected = _playbackSpeed == speed;
            return InkWell(
              onTap: () => _setPlaybackSpeed(speed),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.6.h),
                decoration: BoxDecoration(
                  color: isSelected ? _primaryBrown : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? _primaryBrown : _lightBrown.withOpacity(0.5),
                  ),
                ),
                child: Text(
                  '${speed}x',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? Colors.white : _mediumBrown,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAudioEndedOverlay() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 28),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Session Complete! 🎉',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  _isPlayingFromCache 
                      ? 'Played offline - no data used!'
                      : 'Great job!',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.green[600],
                  ),
                ),
              ],
            ),
          ),
          // Replay button
          IconButton(
            onPressed: () {
              _seek(Duration.zero);
              _play();
              setState(() => _isAudioEnded = false);
            },
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _primaryBrown,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.replay, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

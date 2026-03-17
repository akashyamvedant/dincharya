// Web implementation of Media Player - Premium Design
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

/// Web-specific Media Player Widget with Premium Design
class MediaPlayerPlatformWidget extends StatefulWidget {
  final Map<String, dynamic> session;

  const MediaPlayerPlatformWidget({
    super.key,
    required this.session,
  });

  @override
  State<MediaPlayerPlatformWidget> createState() => _MediaPlayerPlatformWidgetState();
}

class _MediaPlayerPlatformWidgetState extends State<MediaPlayerPlatformWidget>
    with TickerProviderStateMixin {
  late String _viewId;
  bool _isPlayerReady = false;
  bool _isFavorite = false;
  late AnimationController _pulseController;
  // ignore: unused_field - animation created for visual effects
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initializePlayer();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _initializePlayer() {
    final mediaType = widget.session['media_type'] as String? ?? 'youtube';
    
    String mediaUrl;
    if (mediaType == 'youtube') {
      mediaUrl = widget.session['youtube_url'] as String? ?? 
                 widget.session['media_url'] as String? ?? '';
    } else if (mediaType == 'video') {
      mediaUrl = widget.session['video_url'] as String? ?? 
                 widget.session['media_url'] as String? ?? '';
    } else if (mediaType == 'audio') {
      mediaUrl = widget.session['audio_url'] as String? ?? 
                 widget.session['media_url'] as String? ?? '';
    } else {
      mediaUrl = widget.session['media_url'] as String? ?? '';
    }
    
    debugPrint('🎬 Media player initializing: type=$mediaType, url=$mediaUrl');
    
    _viewId = 'media-player-${DateTime.now().millisecondsSinceEpoch}';
    
    if (mediaType == 'youtube') {
      _initYoutubePlayer(mediaUrl);
    } else if (mediaType == 'video') {
      _initVideoPlayer(mediaUrl);
    } else if (mediaType == 'audio') {
      _initAudioPlayer(mediaUrl);
    }

    setState(() => _isPlayerReady = true);
  }

  void _initYoutubePlayer(String url) {
    final videoId = _extractYoutubeVideoId(url);
    
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => html.IFrameElement()
        ..src = 'https://www.youtube.com/embed/$videoId?autoplay=0&rel=0&modestbranding=1&showinfo=0'
        ..style.border = 'none'
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.borderRadius = '16px'
        ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture'
        ..allowFullscreen = true,
    );
  }

  void _initVideoPlayer(String url) {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) => html.VideoElement()
        ..src = url
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000'
        ..style.borderRadius = '16px'
        ..style.objectFit = 'cover'
        ..autoplay = false,
    );
  }

  void _initAudioPlayer(String url) {
    // ignore: undefined_prefixed_name
    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int viewId) {
        final container = html.DivElement()
          ..style.width = '100%'
          ..style.height = '100%'
          ..style.display = 'flex'
          ..style.flexDirection = 'column'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.background = 'linear-gradient(135deg, #1a1a2e 0%, #16213e 50%, #0f3460 100%)'
          ..style.borderRadius = '16px';

        // Animated circles container
        final circlesContainer = html.DivElement()
          ..style.position = 'relative'
          ..style.width = '200px'
          ..style.height = '200px'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center';

        // Outer glow ring
        final outerRing = html.DivElement()
          ..style.position = 'absolute'
          ..style.width = '180px'
          ..style.height = '180px'
          ..style.borderRadius = '50%'
          ..style.border = '3px solid rgba(102, 126, 234, 0.3)'
          ..style.animation = 'pulse 2s ease-in-out infinite';

        // Main visualizer circle
        final visualizer = html.DivElement()
          ..style.width = '150px'
          ..style.height = '150px'
          ..style.borderRadius = '50%'
          ..style.background = 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)'
          ..style.display = 'flex'
          ..style.alignItems = 'center'
          ..style.justifyContent = 'center'
          ..style.boxShadow = '0 0 60px rgba(102, 126, 234, 0.5), inset 0 0 30px rgba(255,255,255,0.1)'
          ..style.animation = 'glow 2s ease-in-out infinite alternate';

        final icon = html.DivElement()
          ..style.fontSize = '50px'
          ..style.color = 'white'
          ..innerHtml = '🎵';

        visualizer.append(icon);
        circlesContainer.append(outerRing);
        circlesContainer.append(visualizer);
        container.append(circlesContainer);

        // Session title
        final titleDiv = html.DivElement()
          ..style.marginTop = '24px'
          ..style.color = 'white'
          ..style.fontSize = '18px'
          ..style.fontWeight = 'bold'
          ..style.textAlign = 'center'
          ..text = 'Now Playing';
        container.append(titleDiv);

        // Audio element with custom styling
        final audioContainer = html.DivElement()
          ..style.marginTop = '24px'
          ..style.width = '90%'
          ..style.maxWidth = '350px'
          ..style.padding = '16px'
          ..style.background = 'rgba(255,255,255,0.15)'
          ..style.borderRadius = '50px';

        final audio = html.AudioElement()
          ..src = url
          ..controls = true
          ..style.width = '100%'
          ..style.height = '40px'
          ..style.borderRadius = '20px'
          ..autoplay = false;

        audioContainer.append(audio);
        container.append(audioContainer);

        // Add CSS animation
        final style = html.StyleElement()
          ..text = '''
            @keyframes pulse {
              0%, 100% { transform: scale(1); opacity: 0.5; }
              50% { transform: scale(1.1); opacity: 1; }
            }
            @keyframes glow {
              0% { box-shadow: 0 0 40px rgba(102, 126, 234, 0.4); }
              100% { box-shadow: 0 0 80px rgba(102, 126, 234, 0.8); }
            }
          ''';
        html.document.head!.append(style);

        return container;
      },
    );
  }

  String _extractYoutubeVideoId(String url) {
    if (url.isEmpty) return 'dQw4w9WgXcQ';
    
    final regExp = RegExp(
      r'^.*((youtu.be\/)|(v\/)|(\\/u\\/\w\/)|(embed\/)|(watch\?))\\??v?=?([^#\&?]*).?',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    return (match != null && match.group(7)?.length == 11) 
        ? match.group(7)! 
        : 'dQw4w9WgXcQ';
  }

  List<Color> _getCategoryGradient(String category) {
    // Single Warm Earth Brown for all categories
    return [Theme.of(context).colorScheme.primary, Color(0xFF6B3410)];
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final title = session['title'] as String? ?? 'Session';
    final titleHindi = session['title_hindi'] as String? ?? '';
    final description = session['description'] as String? ?? '';
    final duration = session['duration'];
    final difficulty = session['difficulty'] as int? ?? 3;
    final category = session['category'] as String? ?? 'meditation';
    final mediaType = session['media_type'] as String? ?? 'youtube';
    final gradientColors = _getCategoryGradient(category);

    return Scaffold(
      backgroundColor: Color(0xFF0a0a0a),
      body: SafeArea(
        child: Column(
          children: [
            _buildPremiumHeader(context, title, gradientColors),
            Expanded(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Player Container
                    Container(
                      height: mediaType == 'audio' ? 40.h : 32.h,
                      margin: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: gradientColors.first.withOpacity(0.3),
                            blurRadius: 30,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _isPlayerReady
                            ? HtmlElementView(viewType: _viewId)
                            : Center(
                                child: CircularProgressIndicator(
                                  color: gradientColors.first,
                                ),
                              ),
                      ),
                    ),
                    
                    // Session Details Card
                    _buildSessionDetailsCard(
                      context, title, titleHindi, description, 
                      duration, difficulty, category, mediaType, gradientColors
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

  Widget _buildPremiumHeader(BuildContext context, String title, List<Color> gradientColors) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0a0a0a), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: Colors.white,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Favorite button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                setState(() => _isFavorite = !_isFavorite);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(_isFavorite ? 'Added to favorites!' : 'Removed from favorites'),
                    backgroundColor: _isFavorite ? Colors.green : Colors.grey,
                  ),
                );
              },
              icon: Icon(
                _isFavorite ? Icons.favorite : Icons.favorite_border,
                color: _isFavorite ? Colors.red : Colors.white,
                size: 22,
              ),
            ),
          ),
          SizedBox(width: 2.w),
          // Share button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Share link copied!'), backgroundColor: Colors.blue),
                );
              },
              icon: Icon(Icons.share, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetailsCard(
    BuildContext context, String title, String titleHindi, String description,
    dynamic duration, int difficulty, String category, String mediaType, List<Color> gradientColors
  ) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1a1a2e), Color(0xFF16213e)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badges Row
          Row(
            children: [
              _buildInfoChip(
                icon: _getCategoryIcon(category),
                label: category.toUpperCase(),
                colors: gradientColors,
              ),
              SizedBox(width: 2.w),
              _buildInfoChip(
                icon: Icons.access_time,
                label: _formatDuration(duration),
                colors: [Colors.white24, Colors.white12],
                textColor: Colors.white70,
              ),
              SizedBox(width: 2.w),
              _buildInfoChip(
                icon: _getMediaTypeIcon(mediaType),
                label: mediaType.toUpperCase(),
                colors: [_getMediaTypeColor(mediaType), _getMediaTypeColor(mediaType).withOpacity(0.7)],
              ),
            ],
          ),
          SizedBox(height: 3.h),
          
          // Title
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (titleHindi.isNotEmpty) ...[
            SizedBox(height: 0.5.h),
            Text(
              titleHindi,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 14.sp,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          SizedBox(height: 2.h),
          
          // Difficulty
          Row(
            children: [
              Text(
                'Difficulty: ',
                style: TextStyle(color: Colors.white60, fontSize: 12.sp),
              ),
              ...List.generate(5, (index) => Padding(
                padding: EdgeInsets.only(right: 1.w),
                child: Icon(
                  index < difficulty ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: index < difficulty ? Color(0xFFFFD700) : Colors.white30,
                  size: 18,
                ),
              )),
            ],
          ),
          SizedBox(height: 2.h),
          
          // Description
          Text(
            'About this session',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            description,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12.sp,
              height: 1.6,
            ),
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required List<Color> colors,
    Color textColor = Colors.white,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 16),
          SizedBox(width: 1.w),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 11.sp,
              fontWeight: FontWeight.bold,
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

  IconData _getMediaTypeIcon(String mediaType) {
    switch (mediaType) {
      case 'youtube': return Icons.play_circle;
      case 'video': return Icons.video_file;
      case 'audio': return Icons.audiotrack;
      default: return Icons.play_circle;
    }
  }

  Color _getMediaTypeColor(String mediaType) {
    switch (mediaType) {
      case 'youtube': return Colors.red;
      case 'video': return Colors.blue;
      case 'audio': return Colors.green;
      default: return Colors.grey;
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
}

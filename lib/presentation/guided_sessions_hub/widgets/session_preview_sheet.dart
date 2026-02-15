import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/media_cache_service.dart';

/// Session preview bottom sheet — shown on long-press of a session card.
/// Displays full details (thumbnail, description, duration, difficulty, instructor)
/// with "Start Session", "Add to Favorites", and "Download" actions.
class SessionPreviewSheet extends StatefulWidget {
  final Map<String, dynamic> session;
  final VoidCallback onStart;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;

  const SessionPreviewSheet({
    super.key,
    required this.session,
    required this.onStart,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  static const Color primaryBrown = Color(0xFF8B4513);

  @override
  State<SessionPreviewSheet> createState() => _SessionPreviewSheetState();
}

class _SessionPreviewSheetState extends State<SessionPreviewSheet> {
  final MediaCacheService _cache = MediaCacheService();
  bool _isCached = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _checkCacheStatus();
  }

  Future<void> _checkCacheStatus() async {
    final url = _getMediaUrl();
    if (url.isNotEmpty) {
      final cached = await _cache.isCached(url);
      if (mounted) setState(() => _isCached = cached);
    }
  }

  String _getMediaUrl() {
    final mediaType = (widget.session['media_type'] ?? 'youtube').toString().toLowerCase();
    switch (mediaType) {
      case 'video': return widget.session['video_url'] as String? ?? '';
      case 'audio': return widget.session['audio_url'] as String? ?? '';
      default: return widget.session['youtube_url'] as String? ?? widget.session['media_url'] as String? ?? '';
    }
  }

  Future<void> _startDownload() async {
    final url = _getMediaUrl();
    if (url.isEmpty) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    await _cache.cacheInBackground(
      url: url,
      mediaType: widget.session['media_type'] ?? 'youtube',
      sessionId: widget.session['id']?.toString(),
      onProgress: (progress) {
        if (mounted) setState(() => _downloadProgress = progress);
      },
    );

    if (mounted) {
      setState(() {
        _isDownloading = false;
        _isCached = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Downloaded for offline! ✓'),
            ],
          ),
          backgroundColor: SessionPreviewSheet.primaryBrown,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session['title'] ?? 'Session';
    final description = widget.session['description'] ?? '';
    final category = widget.session['category'] ?? 'meditation';
    final difficulty = widget.session['difficulty'] as int? ?? 1;
    final mediaType = widget.session['media_type'] ?? 'youtube';
    final duration = widget.session['duration'];
    final instructor = widget.session['instructor_name'] as String?;
    final titleHindi = widget.session['title_hindi'] as String?;

    // Try to extract YouTube thumbnail
    final youtubeUrl = widget.session['youtube_url'] as String? ?? '';
    final ytId = _extractYoutubeId(youtubeUrl);
    final thumbnailUrl = ytId != null ? 'https://img.youtube.com/vi/$ytId/hqdefault.jpg' : null;

    const primaryBrown = SessionPreviewSheet.primaryBrown;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFDF8F3),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(5.w, 0, 5.w, 3.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Thumbnail
                  if (thumbnailUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: Image.network(
                          thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[300],
                            child: const Icon(Icons.image, size: 40),
                          ),
                        ),
                      ),
                    ),

                  SizedBox(height: 2.h),

                  // Title
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2C1810),
                    ),
                  ),
                  if (titleHindi != null && titleHindi.isNotEmpty) ...[
                    SizedBox(height: 0.3.h),
                    Text(
                      titleHindi,
                      style: TextStyle(fontSize: 14.sp, color: const Color(0xFF5D4037)),
                    ),
                  ],

                  SizedBox(height: 1.h),

                  // Chips: duration, difficulty, type, instructor
                  Wrap(
                    spacing: 2.w,
                    runSpacing: 0.8.h,
                    children: [
                      _chip(Icons.timer_outlined, _formatDuration(duration)),
                      _chip(Icons.bar_chart, 'Level $difficulty'),
                      _chip(Icons.category_outlined, category),
                      _chip(Icons.play_circle_outline, mediaType),
                      if (instructor != null)
                        _chip(Icons.person_outline, 'by $instructor'),
                    ],
                  ),

                  SizedBox(height: 1.5.h),

                  // Description
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: const Color(0xFF5D4037),
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 2.h),

                  // Actions Row — Favorite, Download, Start
                  Row(
                    children: [
                      // Favorite
                      _buildActionButton(
                        icon: widget.isFavorite ? Icons.favorite : Icons.favorite_border,
                        label: widget.isFavorite ? 'Saved' : 'Save',
                        color: widget.isFavorite ? Colors.red : primaryBrown,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          widget.onToggleFavorite();
                        },
                      ),
                      SizedBox(width: 2.w),
                      // Download
                      _buildDownloadButton(primaryBrown),
                      SizedBox(width: 2.w),
                      // Start
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.pop(context);
                            widget.onStart();
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 20),
                          label: const Text(
                            'Start',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBrown,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 1.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 18),
        label: Text(
          label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildDownloadButton(Color primaryBrown) {
    if (_isCached) {
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: null,
          icon: const Icon(Icons.download_done, color: Color(0xFF4A7C59), size: 18),
          label: const Text(
            'Offline',
            style: TextStyle(color: Color(0xFF4A7C59), fontWeight: FontWeight.w600, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: Color(0xFF4A7C59)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    if (_isDownloading) {
      return Expanded(
        child: OutlinedButton.icon(
          onPressed: null,
          icon: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              value: _downloadProgress > 0 ? _downloadProgress : null,
              strokeWidth: 2,
              color: primaryBrown,
            ),
          ),
          label: Text(
            '${(_downloadProgress * 100).toInt()}%',
            style: TextStyle(color: primaryBrown, fontWeight: FontWeight.w600, fontSize: 12),
          ),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: primaryBrown.withOpacity(0.3)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      );
    }

    return Expanded(
      child: OutlinedButton.icon(
        onPressed: () {
          HapticFeedback.lightImpact();
          _startDownload();
        },
        icon: Icon(Icons.download_outlined, color: primaryBrown, size: 18),
        label: Text(
          'Download',
          style: TextStyle(color: primaryBrown, fontWeight: FontWeight.w600, fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: SessionPreviewSheet.primaryBrown.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: SessionPreviewSheet.primaryBrown),
          SizedBox(width: 1.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF5D4037),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(dynamic d) {
    if (d == null) return '—';
    final mins = d is int ? (d / 60).round() : 10;
    return '${mins} min';
  }

  String? _extractYoutubeId(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    return uri.queryParameters['v'] ?? (uri.host.contains('youtu.be') ? uri.pathSegments.lastOrNull : null);
  }
}

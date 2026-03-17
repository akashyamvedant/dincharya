import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/media_cache_service.dart';

/// "My Downloads" section for the Explore tab.
/// Shows cache stats and lets the user manage offline content.
class DownloadsSection extends StatefulWidget {
  const DownloadsSection({super.key});

  @override
  State<DownloadsSection> createState() => _DownloadsSectionState();
}

class _DownloadsSectionState extends State<DownloadsSection> {
  final MediaCacheService _cache = MediaCacheService();
  int _fileCount = 0;
  String _cacheSize = '0 B';

  static Color _primaryBrown = Color(0xFF5D4037);


  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    final count = await _cache.getCachedFileCount();
    final size = await _cache.getFormattedCacheSize();
    if (mounted) setState(() { _fileCount = count; _cacheSize = size; });
  }

  Future<void> _clearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Downloads?'),
        content: Text('This will delete $_fileCount downloaded files ($_cacheSize).'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _cache.clearAllCache();
      _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Downloads cleared ✓'),
            backgroundColor: _primaryBrown,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Don't show if nothing downloaded
    if (_fileCount == 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.download_done_rounded, color: _primaryBrown, size: 22),
                SizedBox(width: 2.w),
                Text(
                  'My Downloads',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _clearCache();
              },
              icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
              label: const Text('Clear', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
            ),
          ],
        ),
        SizedBox(height: 1.h),

        // Stats Card
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_primaryBrown.withOpacity(0.06), _primaryBrown.withOpacity(0.02)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _primaryBrown.withOpacity(0.15)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _primaryBrown.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_outlined, color: _primaryBrown, size: 28),
              ),
              SizedBox(width: 4.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$_fileCount sessions available offline',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  SizedBox(height: 0.3.h),
                  Text(
                    'Using $_cacheSize of storage',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.wifi_off_rounded, color: _primaryBrown.withOpacity(0.4), size: 20),
            ],
          ),
        ),
      ],
    );
  }
}

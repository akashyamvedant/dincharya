// lib/presentation/tapasya/badges_gallery_screen.dart
//
// Display all badges (earned + locked) in a gallery grid.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../services/tapasya_service.dart';

class BadgesGalleryScreen extends StatefulWidget {
  const BadgesGalleryScreen({super.key});

  @override
  State<BadgesGalleryScreen> createState() => _BadgesGalleryScreenState();
}

class _BadgesGalleryScreenState extends State<BadgesGalleryScreen> with WidgetsBindingObserver {
  final TapasyaService _tapasyaService = TapasyaService();
  List<Map<String, dynamic>> _badges = [];
  bool _isLoading = true;

    @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadBadges();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadBadges();
    }
  }

  Future<void> _loadBadges() async {
    setState(() => _isLoading = true);
    final badges = await _tapasyaService.getAllBadges();
    if (mounted) {
      setState(() {
        _badges = badges;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final earned = _badges.where((b) => b['is_earned'] == true).toList();
    final locked = _badges.where((b) => b['is_earned'] != true).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('🏅 Badges'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
          : RefreshIndicator(
              onRefresh: _loadBadges,
              child: ListView(
                padding: EdgeInsets.all(4.w),
                children: [
                  // Stats
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.amber.withValues(alpha: 0.12),
                          Colors.orange.withValues(alpha: 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBadgeStat('${earned.length}', 'Earned', Colors.amber),
                        Container(width: 1, height: 30, color: Colors.amber.withValues(alpha: 0.3)),
                        _buildBadgeStat('${_badges.length}', 'Total', theme.colorScheme.onSurfaceVariant),
                        Container(width: 1, height: 30, color: Colors.amber.withValues(alpha: 0.3)),
                        _buildBadgeStat(
                          _badges.isNotEmpty
                              ? '${(earned.length / _badges.length * 100).round()}%'
                              : '0%',
                          'Progress',
                          theme.colorScheme.primary,
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 3.h),

                  // Earned Badges
                  if (earned.isNotEmpty) ...[
                    Text(
                      '✨ Earned (${earned.length})',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 3.w,
                        mainAxisSpacing: 2.h,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: earned.length,
                      itemBuilder: (context, index) => _buildBadgeCard(earned[index], isEarned: true),
                    ),
                    SizedBox(height: 3.h),
                  ],

                  // Locked Badges
                  if (locked.isNotEmpty) ...[
                    Text(
                      '🔒 Locked (${locked.length})',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 1.5.h),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 3.w,
                        mainAxisSpacing: 2.h,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: locked.length,
                      itemBuilder: (context, index) => _buildBadgeCard(locked[index], isEarned: false),
                    ),
                  ],

                  // Empty state
                  if (_badges.isEmpty) ...[
                    SizedBox(height: 8.h),
                    const Center(
                      child: Text('🏅', style: TextStyle(fontSize: 64)),
                    ),
                    SizedBox(height: 2.h),
                    Center(
                      child: Text(
                        'Badges coming soon!',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        'Complete challenges and practice regularly to earn badges.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],

                  SizedBox(height: 4.h),
                ],
              ),
            ),
    );
  }

  Widget _buildBadgeStat(String value, String label, Color color) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildBadgeCard(Map<String, dynamic> badge, {required bool isEarned}) {
    final theme = Theme.of(context);
    final icon = badge['icon'] ?? '🏅';
    final title = badge['title'] ?? '';
    final titleEn = badge['title_en'] ?? '';
    final description = badge['description'] ?? '';

    return GestureDetector(
      onTap: () => _showBadgeDetail(badge, isEarned),
      child: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          gradient: isEarned
              ? LinearGradient(
                  colors: [
                    Colors.amber.withValues(alpha: 0.15),
                    Colors.orange.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isEarned ? null : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isEarned ? Colors.amber.withValues(alpha: 0.4) : theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              icon,
              style: TextStyle(
                fontSize: 32,
                color: isEarned ? null : Colors.grey,
              ),
            ),
            SizedBox(height: 0.5.h),
            Text(
              title,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: isEarned ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              titleEn,
              style: TextStyle(
                fontSize: 10.sp,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showBadgeDetail(Map<String, dynamic> badge, bool isEarned) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final theme = Theme.of(context);
        return Container(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(badge['icon'] ?? '🏅', style: const TextStyle(fontSize: 56)),
              SizedBox(height: 1.h),
              Text(
                badge['title'] ?? '',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                badge['title_en'] ?? '',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 1.5.h),
              Text(
                badge['description'] ?? '',
                style: TextStyle(fontSize: 15.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 2.h),
              if (isEarned)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '✅ Earned',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '🔒 Keep practicing to unlock!',
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              SizedBox(height: 3.h),
            ],
          ),
        );
      },
    );
  }
}

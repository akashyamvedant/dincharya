import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class BottomActionWidget extends StatefulWidget {
  final VoidCallback onSave;
  final VoidCallback onVoiceInput;
  final VoidCallback onPhotoAttach;
  final VoidCallback? onShowInsights;
  final String? currentEntryText;

  const BottomActionWidget({
    super.key,
    required this.onSave,
    required this.onVoiceInput,
    required this.onPhotoAttach,
    this.onShowInsights,
    this.currentEntryText,
  });

  @override
  State<BottomActionWidget> createState() => _BottomActionWidgetState();
}

class _BottomActionWidgetState extends State<BottomActionWidget>
    with TickerProviderStateMixin {
  late AnimationController _saveController;
  late Animation<double> _saveScale;

  @override
  void initState() {
    super.initState();
    _saveController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _saveScale = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _saveController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _saveController.dispose();
    super.dispose();
  }

  void _onSavePressed() {
    HapticFeedback.mediumImpact();
    _saveController.forward().then((_) {
      _saveController.reverse();
      widget.onSave();
    });
  }

  @override
  Widget build(BuildContext context) {
    const warmBrown = Color(0xFF8B4513);
    const warmAmber = Color(0xFFD4A574);

    return Container(
      padding: EdgeInsets.all(3.5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white,
            const Color(0xFFFFF8F0),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: warmAmber.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: warmBrown.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Quick actions row — media buttons
          Row(
            children: [
              Text(
                'Add to entry',
                style: AppTheme.lightTheme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: warmBrown,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              _buildMediaButton(
                icon: Icons.mic_rounded,
                label: 'Voice',
                gradient: [warmBrown, const Color(0xFFa05a2c)],
                onTap: widget.onVoiceInput,
              ),
              SizedBox(width: 2.w),
              _buildMediaButton(
                icon: Icons.photo_camera_rounded,
                label: 'Photo',
                gradient: [const Color(0xFF4A7C59), const Color(0xFF2E7D32)],
                onTap: widget.onPhotoAttach,
              ),
            ],
          ),
          SizedBox(height: 2.h),

          // Save button — gradient pill
          AnimatedBuilder(
            animation: _saveScale,
            builder: (context, child) {
              return Transform.scale(
                scale: _saveScale.value,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [warmBrown, Color(0xFFa05a2c)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: warmBrown.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _onSavePressed,
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 1.6.h),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_rounded, size: 20, color: Colors.white),
                            SizedBox(width: 2.w),
                            Text(
                              'Save Entry',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          SizedBox(height: 1.5.h),

          // Secondary actions — Copy, Insights, History
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSecondaryAction(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: _copyToClipboard,
                color: warmBrown,
              ),
              _buildSecondaryAction(
                icon: Icons.insights_rounded,
                label: 'Insights',
                onTap: () {
                  if (widget.onShowInsights != null) {
                    widget.onShowInsights!();
                  }
                },
                color: warmBrown,
              ),
              _buildSecondaryAction(
                icon: Icons.history_rounded,
                label: 'History',
                onTap: _navigateToHistory,
                color: warmBrown,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaButton({
    required IconData icon,
    required String label,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient.map((c) => c.withOpacity(0.12)).toList(),
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: gradient.first.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: gradient.first, size: 18),
            SizedBox(width: 1.5.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                color: gradient.first,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(2.5.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.1)),
              ),
              child: Icon(icon, color: color.withOpacity(0.6), size: 20),
            ),
            SizedBox(height: 0.6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                color: color.withOpacity(0.5),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard() {
    final text = widget.currentEntryText ?? '';
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.warning_amber, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('No text to copy'),
            ],
          ),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Entry copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _navigateToHistory() {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, AppRoutes.history);
  }
}

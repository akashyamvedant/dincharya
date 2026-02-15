import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Shimmer skeleton shown while sessions are loading from Supabase.
/// Mimics the session card layout for seamless perceived performance.
class SessionSkeletonWidget extends StatefulWidget {
  final int count;

  const SessionSkeletonWidget({super.key, this.count = 3});

  @override
  State<SessionSkeletonWidget> createState() => _SessionSkeletonWidgetState();
}

class _SessionSkeletonWidgetState extends State<SessionSkeletonWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _shimmerAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, _) {
        return Column(
          children: List.generate(widget.count, (i) => _buildSkeletonCard(i)),
        );
      },
    );
  }

  Widget _buildSkeletonCard(int index) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
      child: Container(
        height: 11.h,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment(_shimmerAnimation.value - 1, 0),
            end: Alignment(_shimmerAnimation.value, 0),
            colors: const [
              Color(0xFFF5F0EB),
              Color(0xFFEDE7E0),
              Color(0xFFF5F0EB),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Thumbnail placeholder
              Container(
                width: 18.w,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 12),
              // Text placeholders
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _shimmerLine(width: 60.w),
                    SizedBox(height: 0.8.h),
                    _shimmerLine(width: 40.w),
                    SizedBox(height: 0.8.h),
                    Row(
                      children: [
                        _shimmerLine(width: 15.w, height: 2.h),
                        const SizedBox(width: 8),
                        _shimmerLine(width: 15.w, height: 2.h),
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

  Widget _shimmerLine({required double width, double height = 10}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

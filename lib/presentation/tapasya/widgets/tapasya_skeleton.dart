// lib/presentation/tapasya/widgets/tapasya_skeleton.dart
// Skeleton loading state for TapasyaHub

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class TapasyaSkeleton extends StatefulWidget {
  const TapasyaSkeleton({super.key});

  @override
  State<TapasyaSkeleton> createState() => _TapasyaSkeletonState();
}

class _TapasyaSkeletonState extends State<TapasyaSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          children: [
            // Section header skeleton
            _buildShimmer(width: 45.w, height: 2.5.h),
            SizedBox(height: 1.5.h),
            // Challenge cards horizontal
            SizedBox(
              height: 20.h,
              child: Row(
                children: [
                  _buildCardShimmer(width: 72.w),
                  SizedBox(width: 3.w),
                  _buildCardShimmer(width: 72.w),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            // Section header
            _buildShimmer(width: 50.w, height: 2.5.h),
            SizedBox(height: 1.5.h),
            // Activity items
            ...List.generate(3, (_) => Padding(
              padding: EdgeInsets.only(bottom: 1.5.h),
              child: _buildActivityShimmer(),
            )),
          ],
        );
      },
    );
  }

  Widget _buildShimmer({required double width, required double height}) {
    final opacity = 0.15 + 0.1 * (0.5 + 0.5 * (_controller.value * 2 - 1).abs());
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(opacity),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _buildCardShimmer({required double width}) {
    final opacity = 0.08 + 0.06 * (0.5 + 0.5 * (_controller.value * 2 - 1).abs());
    return Container(
      width: width,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(opacity),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }

  Widget _buildActivityShimmer() {
    final opacity = 0.08 + 0.06 * (0.5 + 0.5 * (_controller.value * 2 - 1).abs());
    return Container(
      height: 7.h,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(opacity),
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }
}

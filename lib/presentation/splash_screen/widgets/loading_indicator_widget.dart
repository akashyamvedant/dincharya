import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class LoadingIndicatorWidget extends StatelessWidget {
  final AnimationController controller;

  const LoadingIndicatorWidget({
    super.key,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 15.w,
      height: 15.w,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Outer breathing circle
              Transform.scale(
                scale: 1.0 + (controller.value * 0.1),
                child: Container(
                  width: 15.w,
                  height: 15.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
              ),

              // Inner pulsing circle
              Transform.scale(
                scale: 0.6 + (controller.value * 0.4),
                child: Container(
                  width: 8.w,
                  height: 8.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),

              // Center dot
              Container(
                width: 2.w,
                height: 2.w,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

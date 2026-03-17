import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class BreathingAnimationWidget extends StatelessWidget {
  final Animation<double> animation;
  final String sessionType;
  final bool isPlaying;

  const BreathingAnimationWidget({
    super.key,
    required this.animation,
    required this.sessionType,
    required this.isPlaying,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.scale(
          scale: isPlaying ? animation.value : 1.0,
          child: Container(
            width: 50.w,
            height: 50.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: sessionType == "meditation"
                    ? [
                        Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.3),
                        Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.1),
                        Colors.transparent,
                      ]
                    : [
                        AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light).withValues(alpha: 0.4),
                        AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light).withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                stops: [0.0, 0.7, 1.0],
              ),
              border: Border.all(
                color: sessionType == "meditation"
                    ? Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.5)
                    : AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light).withValues(alpha: 0.6),
                width: 2.0,
              ),
            ),
            child: Center(
              child: Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: sessionType == "meditation"
                      ? Theme.of(context).colorScheme.primary
                          .withValues(alpha: 0.2)
                      : AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light).withValues(alpha: 0.3),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CustomIconWidget(
                        iconName: sessionType == "meditation"
                            ? 'self_improvement'
                            : 'air',
                        color: sessionType == "meditation"
                            ? Color(0xFF8B4513)
                            : AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light),
                        size: 32,
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        isPlaying
                            ? (sessionType == "meditation"
                                ? "Breathe"
                                : "Inhale")
                            : "Paused",
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: sessionType == "meditation"
                              ? Color(0xFF8B4513)
                              : AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light),
                          fontWeight: FontWeight.w500,
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
    );
  }
}

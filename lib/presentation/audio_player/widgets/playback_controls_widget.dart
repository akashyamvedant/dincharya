import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class PlaybackControlsWidget extends StatelessWidget {
  final bool isPlaying;
  final double playbackSpeed;
  final VoidCallback onPlayPause;
  final VoidCallback onSkipForward;
  final VoidCallback onSkipBackward;
  final Function(double) onSpeedChanged;
  final VoidCallback onSleepTimer;
  final int? sleepTimerMinutes;

  const PlaybackControlsWidget({
    super.key,
    required this.isPlaying,
    required this.playbackSpeed,
    required this.onPlayPause,
    required this.onSkipForward,
    required this.onSkipBackward,
    required this.onSpeedChanged,
    required this.onSleepTimer,
    this.sleepTimerMinutes,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
        border: Border(
          top: BorderSide(
            color:
                Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Speed and Sleep Timer Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Speed Control
              GestureDetector(
                onTap: () => _showSpeedSelector(context),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'speed',
                        color:
                            Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 16,
                      ),
                      SizedBox(width: 1.w),
                      Text(
                        '${playbackSpeed}x',
                        style:
                            Theme.of(context).textTheme.labelMedium?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sleep Timer
              GestureDetector(
                onTap: onSleepTimer,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: sleepTimerMinutes != null
                        ? AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light).withValues(alpha: 0.2)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20.0),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline
                          .withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CustomIconWidget(
                        iconName: 'bedtime',
                        color: sleepTimerMinutes != null
                            ? AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light)
                            : Theme.of(context).colorScheme.onSurface,
                        size: 16,
                      ),
                      if (sleepTimerMinutes != null) ...[
                        SizedBox(width: 1.w),
                        Text(
                          '${sleepTimerMinutes}m',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                            color: AppTheme.getAccentColor(Theme.of(context).brightness == Brightness.light),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 3.h),

          // Main Playback Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Skip Backward
              GestureDetector(
                onTap: onSkipBackward,
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline
                          .withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: CustomIconWidget(
                    iconName: 'replay_30',
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 24,
                  ),
                ),
              ),

              // Previous Session
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline
                          .withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: CustomIconWidget(
                    iconName: 'skip_previous',
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                ),
              ),

              // Play/Pause Button
              GestureDetector(
                onTap: onPlayPause,
                child: Container(
                  padding: EdgeInsets.all(4.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary
                            .withValues(alpha: 0.3),
                        blurRadius: 12.0,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CustomIconWidget(
                    iconName: isPlaying ? 'pause' : 'play_arrow',
                    color: Theme.of(context).colorScheme.onPrimary,
                    size: 36,
                  ),
                ),
              ),

              // Next Session
              GestureDetector(
                onTap: () {},
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline
                          .withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: CustomIconWidget(
                    iconName: 'skip_next',
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 28,
                  ),
                ),
              ),

              // Skip Forward
              GestureDetector(
                onTap: onSkipForward,
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline
                          .withValues(alpha: 0.3),
                      width: 1.0,
                    ),
                  ),
                  child: CustomIconWidget(
                    iconName: 'forward_30',
                    color: Theme.of(context).colorScheme.onSurface,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSpeedSelector(BuildContext context) {
    final List<double> speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.0)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Playback Speed',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 2.h),
            ...speeds.map((speed) => ListTile(
                  title: Text(
                    '${speed}x',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: playbackSpeed == speed
                      ? CustomIconWidget(
                          iconName: 'check',
                          color: Theme.of(context).colorScheme.primary,
                          size: 20,
                        )
                      : null,
                  onTap: () {
                    onSpeedChanged(speed);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

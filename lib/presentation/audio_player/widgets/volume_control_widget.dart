import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class VolumeControlWidget extends StatelessWidget {
  final double volume;
  final Function(double) onVolumeChanged;

  const VolumeControlWidget({
    super.key,
    required this.volume,
    required this.onVolumeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w),
      child: Column(
        children: [
          Row(
            children: [
              CustomIconWidget(
                iconName: 'volume_down',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
              Expanded(
                child: Slider(
                  value: volume,
                  min: 0.0,
                  max: 1.0,
                  divisions: 20,
                  onChanged: onVolumeChanged,
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.3),
                  thumbColor: Theme.of(context).colorScheme.primary,
                ),
              ),
              CustomIconWidget(
                iconName: 'volume_up',
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 20,
              ),
            ],
          ),
          Text(
            'Volume: ${(volume * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

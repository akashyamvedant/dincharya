import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Practice stats row — shows weekly minutes, streak, and sessions count
class PracticeStatsRow extends StatelessWidget {
  final int totalMinutes;
  final int streak;
  final int sessionsCount;

  const PracticeStatsRow({
    super.key,
    required this.totalMinutes,
    required this.streak,
    required this.sessionsCount,
  });



  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      padding: EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 2.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStat(
            context: context,
            icon: Icons.timer_outlined,
            iconColor: Theme.of(context).colorScheme.primary,
            value: '${totalMinutes}',
            label: 'min this week',
          ),
          _divider(context),
          _buildStat(
            context: context,
            icon: Icons.local_fire_department_rounded,
            iconColor: const Color(0xFFFF5722),
            value: '$streak',
            label: 'day streak',
          ),
          _divider(context),
          _buildStat(
            context: context,
            icon: Icons.check_circle_outline_rounded,
            iconColor: const Color(0xFF4A7C59),
            value: '$sessionsCount',
            label: 'sessions',
          ),
        ],
      ),
    );
  }

  Widget _buildStat({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 18),
             SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
         SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _divider(BuildContext context) {
    return Container(
      height: 30,
      width: 1,
      color: Theme.of(context).colorScheme.outline,
    );
  }
}

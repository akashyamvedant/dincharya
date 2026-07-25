import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../mind_games/mind_games_world.dart';

/// XP Level definitions for the gamification system
class UserLevel {
  final String name;
  final String nameHindi;
  final String icon;
  final int minXP;
  final int maxXP;
  final Color color;

  const UserLevel({
    required this.name,
    required this.nameHindi,
    required this.icon,
    required this.minXP,
    required this.maxXP,
    required this.color,
  });

  static const List<UserLevel> levels = [
    UserLevel(name: 'Beginner', nameHindi: 'शुरुआत', icon: '🌱', minXP: 0, maxXP: 100, color: Color(0xFF8BC34A)),
    UserLevel(name: 'Seeker', nameHindi: 'साधक', icon: '🔍', minXP: 100, maxXP: 300, color: Color(0xFF03A9F4)),
    UserLevel(name: 'Practitioner', nameHindi: 'अभ्यासी', icon: '🧘', minXP: 300, maxXP: 700, color: Color(0xFFCD853F)),
    UserLevel(name: 'Disciplined', nameHindi: 'अनुशासित', icon: '⚡', minXP: 700, maxXP: 1500, color: Color(0xFFFF9800)),
    UserLevel(name: 'Yogi', nameHindi: 'योगी', icon: '🕉️', minXP: 1500, maxXP: 3000, color: Color(0xFFE91E63)),
    UserLevel(name: 'Guru', nameHindi: 'गुरु', icon: '👑', minXP: 3000, maxXP: 6000, color: Color(0xFFFFD700)),
    UserLevel(name: 'Maharishi', nameHindi: 'महर्षि', icon: '✨', minXP: 6000, maxXP: 99999, color: Color(0xFFFF6F00)),
  ];

  static UserLevel fromXP(int totalXP) {
    for (int i = levels.length - 1; i >= 0; i--) {
      if (totalXP >= levels[i].minXP) return levels[i];
    }
    return levels[0];
  }

  double progressInLevel(int totalXP) {
    if (maxXP <= minXP) return 1.0;
    return ((totalXP - minXP) / (maxXP - minXP)).clamp(0.0, 1.0);
  }
}

class RoutineHeaderWidget extends StatelessWidget {
  final String selectedProfile;
  final List<String> routineProfiles;
  final Function(String?) onProfileChanged;
  final int streakCount;
  final int totalXP;
  final double weeklyCompletion; // 0.0 - 1.0
  final List<bool> weeklyDays; // Mon-Sun completion status
  final VoidCallback? onProfileTap;

  const RoutineHeaderWidget({
    super.key,
    required this.selectedProfile,
    required this.routineProfiles,
    required this.onProfileChanged,
    required this.streakCount,
    this.totalXP = 0,
    this.weeklyCompletion = 0.0,
    this.weeklyDays = const [false, false, false, false, false, false, false],
    this.onProfileTap,
  });

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final String formattedDate =
        "${_getDayName(now.weekday)}, ${now.day} ${_getMonthName(now.month)}";
    final level = UserLevel.fromXP(totalXP);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color:
                Theme.of(context).colorScheme.shadow.withValues(alpha: 0.1),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Date + Profile
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Date Text
              Flexible(
                child: Text(
                  formattedDate,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              
              SizedBox(width: 2.w),
              
              // Static Profile Label (read-only, no navigation)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      Theme.of(context).colorScheme.tertiary.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomIconWidget(
                      iconName: _getProfileIcon(selectedProfile),
                      color: Theme.of(context).colorScheme.primary,
                      size: 18,
                    ),
                    SizedBox(width: 1.5.w),
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 25.w),
                      child: Text(
                        _getProfileDisplayName(selectedProfile),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: 1.2.h),
          
          // Mind Games Entry Button
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MindGamesWorld()),
              );
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    Theme.of(context).colorScheme.secondary.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🧠', style: TextStyle(fontSize: 16.sp)),
                  SizedBox(width: 2.w),
                  Text(
                    'Mind Games',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Icon(Icons.play_arrow_rounded,
                      color: Theme.of(context).colorScheme.primary, size: 18),
                ],
              ),
            ),
          ),
          
          SizedBox(height: 1.h),
          
          // Row 2: Streak + XP Level + Weekly %
          Row(
            children: [
              // Streak Badge
              _buildStreakBadge(context),
              SizedBox(width: 3.w),
              // XP Level Badge
              _buildXPBadge(level, context),
              SizedBox(width: 3.w),
              // Weekly completion
              _buildWeeklyBadge(context),
            ],
          ),
          
          SizedBox(height: 1.h),
          
          // Row 3: Weekly Dots (Mon-Sun)
          _buildWeeklyDots(context),
        ],
      ),
    );
  }

  Widget _buildStreakBadge(BuildContext context) {
    final bool hasStreak = streakCount > 0;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
        decoration: BoxDecoration(
          gradient: hasStreak
              ? LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF4A2800), const Color(0xFF3D2000)]
                      : [const Color(0xFFFFF3E0), const Color(0xFFFFE0B2)],
                )
              : null,
          color: hasStreak ? null : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasStreak ? Color(0xFFFF8F00).withOpacity(0.3) : Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              hasStreak ? '🔥' : '💤',
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(width: 1.w),
            Flexible(
              child: Text(
                hasStreak ? '$streakCount day${streakCount > 1 ? 's' : ''}' : 'No streak',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: hasStreak ? Color(0xFFE65100) : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXPBadge(UserLevel level, BuildContext context) {
    final progress = level.progressInLevel(totalXP);
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              level.color.withOpacity(0.1),
              level.color.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: level.color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(level.icon, style: TextStyle(fontSize: 15.sp)),
                SizedBox(width: 1.w),
                Flexible(
                  child: Text(
                    level.name,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: level.color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            SizedBox(height: 0.3.h),
            // XP Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 4,
                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(level.color),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyBadge(BuildContext context) {
    final pct = (weeklyCompletion * 100).toInt();
    final isGood = pct >= 70;
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              (isGood ? Colors.green : Colors.orange).withOpacity(0.1),
              (isGood ? Colors.green : Colors.orange).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: (isGood ? Colors.green : Colors.orange).withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isGood ? '📊' : '📈',
              style: TextStyle(fontSize: 16.sp),
            ),
            SizedBox(width: 1.w),
            Flexible(
              child: Text(
                '$pct% week',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: isGood ? Colors.green : Colors.orange,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyDots(BuildContext context) {
    final now = DateTime.now();
    final todayWeekday = now.weekday; // 1 = Monday
    final dayLabels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(7, (i) {
          final isToday = i + 1 == todayWeekday;
          final isCompleted = i < weeklyDays.length && weeklyDays[i];
          final isPast = i + 1 < todayWeekday;

          return Column(
            children: [
              Text(
                dayLabels[i],
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                  color: isToday ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: 0.3.h),
              Container(
                width: 7.w,
                height: 7.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCompleted
                      ? Colors.green
                      : (isPast ? Colors.red.shade100.withOpacity(0.3) : Theme.of(context).colorScheme.surfaceContainerHighest),
                  border: isToday
                      ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
                      : null,
                  boxShadow: isToday
                      ? [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: isCompleted
                      ? Icon(Icons.check, size: 3.w, color: Colors.white)
                      : (isPast
                          ? Icon(Icons.close, size: 3.w, color: Colors.red.shade300)
                          : null),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  String _getProfileIcon(String profile) {
    switch (profile.toLowerCase()) {
      case 'yogic':
        return 'self_improvement';
      case 'student':
        return 'school';
      case 'professional':
        return 'work';
      case 'homemaker':
        return 'home';
      case 'custom':
        return 'edit';
      case 'village life':
        return 'nature';
      case 'city life':
        return 'location_city';
      default:
        return 'person';
    }
  }

  String _getProfileDisplayName(String profile) {
    switch (profile.toLowerCase()) {
      case 'yogic':
        return 'Yogic Lifestyle';
      case 'student':
        return 'Student Life';
      case 'professional':
        return 'Working Professional';
      case 'homemaker':
        return 'Homemaker';
      case 'custom':
        return 'Custom Routine';
      default:
        return profile;
    }
  }
}

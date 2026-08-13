import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/guided_session_service.dart';

/// Weekly meditation challenge card for the Guided Hub.
/// Shows progress (days practiced this week) and community participation count.
class WeeklyChallengeWidget extends StatefulWidget {
  const WeeklyChallengeWidget({super.key});

  @override
  State<WeeklyChallengeWidget> createState() => _WeeklyChallengeWidgetState();
}

class _WeeklyChallengeWidgetState extends State<WeeklyChallengeWidget>
    with SingleTickerProviderStateMixin {
  final GuidedSessionService _service = GuidedSessionService();
  int _daysCompleted = 0;
  int _participants = 0;
  bool _isLoading = true;
  late AnimationController _animController;

  static const int _targetDays = 7;
  static const Color _gold = Color(0xFFDAA520);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _service.getWeeklyChallengeProgress(),
        _service.getWeeklyChallengeParticipants(),
      ]);
      if (mounted) {
        setState(() {
          _daysCompleted = results[0];
          _participants = results[1];
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryBrown = Theme.of(context).colorScheme.primary;
    final darkBrown = Theme.of(context).colorScheme.onSurface;
    final progress = (_daysCompleted / _targetDays).clamp(0.0, 1.0);
    final isComplete = _daysCompleted >= _targetDays;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isComplete
              ? [Theme.of(context).colorScheme.primary.withOpacity(0.12), Theme.of(context).colorScheme.primary.withOpacity(0.08)]
              : [Theme.of(context).colorScheme.surfaceContainerHighest, Theme.of(context).colorScheme.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isComplete ? _gold.withOpacity(0.4) : primaryBrown.withOpacity(0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: (isComplete ? _gold : primaryBrown).withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Text(
                  isComplete ? '🎉' : '🏆',
                  style: const TextStyle(fontSize: 24),
                ),
                SizedBox(width: 2.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isComplete ? 'Challenge Complete!' : 'Weekly Challenge',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: isComplete ? _gold : primaryBrown,
                        ),
                      ),
                      Text(
                        isComplete
                            ? 'You did it — 7 days of practice! 🙌'
                            : 'Practice every day this week',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: darkBrown.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 1.5.h),

            // Day indicators
            if (!_isLoading)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(7, (i) {
                  final dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  final isDone = i < _daysCompleted;
                  final isToday = i == _daysCompleted && !isComplete;

                  return AnimatedBuilder(
                    animation: _animController,
                    builder: (_, __) {
                      final scale = isDone
                          ? Tween<double>(begin: 0.5, end: 1.0)
                              .animate(CurvedAnimation(
                                parent: _animController,
                                curve: Interval(i / 7, (i + 1) / 7, curve: Curves.elasticOut),
                              ))
                              .value
                          : 1.0;

                      return Transform.scale(
                        scale: scale,
                        child: Column(
                          children: [
                            Container(
                              width: 9.w,
                              height: 9.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDone
                                    ? primaryBrown
                                    : isToday
                                        ? primaryBrown.withOpacity(0.15)
                                        : Theme.of(context).colorScheme.outline,
                                border: isToday
                                    ? Border.all(color: primaryBrown, width: 2)
                                    : null,
                                boxShadow: isDone
                                    ? [BoxShadow(color: primaryBrown.withOpacity(0.3), blurRadius: 4)]
                                    : null,
                              ),
                              child: Center(
                                child: isDone
                                    ? const Icon(Icons.check, color: Colors.white, size: 18)
                                    : Text(
                                        dayNames[i],
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w600,
                                          color: isToday ? primaryBrown : Colors.grey,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                }),
              ),

            SizedBox(height: 1.5.h),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _isLoading ? null : progress,
                minHeight: 6,
                backgroundColor: primaryBrown.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation(isComplete ? _gold : primaryBrown),
              ),
            ),

            SizedBox(height: 1.h),

            // Footer
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$_daysCompleted / $_targetDays days',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: primaryBrown,
                  ),
                ),
                if (_participants > 0)
                  Row(
                    children: [
                      Icon(Icons.group_outlined, size: 14, color: darkBrown.withOpacity(0.5)),
                      SizedBox(width: 1.w),
                      Text(
                        '$_participants joined this week',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: darkBrown.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

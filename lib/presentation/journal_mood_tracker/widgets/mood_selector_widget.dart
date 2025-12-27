import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class MoodSelectorWidget extends StatefulWidget {
  final String selectedMood;
  final List<String> moodOptions;
  final Function(String) onMoodSelected;

  const MoodSelectorWidget({
    super.key,
    required this.selectedMood,
    required this.moodOptions,
    required this.onMoodSelected,
  });

  @override
  State<MoodSelectorWidget> createState() => _MoodSelectorWidgetState();
}

class _MoodSelectorWidgetState extends State<MoodSelectorWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  String? _animatingMood;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onMoodTap(String mood) {
    setState(() {
      _animatingMood = mood;
    });

    _animationController.forward().then((_) {
      _animationController.reverse();
    });

    widget.onMoodSelected(mood);

    // Subtle haptic feedback
    // HapticFeedback.lightImpact(); // Uncomment if haptic feedback is needed
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case '😔':
        return Colors.blue.shade300;
      case '😐':
        return Colors.grey.shade400;
      case '😊':
        return Colors.green.shade300;
      case '😄':
        return Colors.orange.shade300;
      case '😍':
        return Colors.pink.shade300;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  String _getMoodLabel(String mood) {
    switch (mood) {
      case '😔':
        return 'Sad';
      case '😐':
        return 'Neutral';
      case '😊':
        return 'Happy';
      case '😄':
        return 'Joyful';
      case '😍':
        return 'Ecstatic';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).shadowColor,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: 2.h),

          // Selected Mood Display
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: _getMoodColor(widget.selectedMood).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _getMoodColor(widget.selectedMood).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _scaleAnimation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _animatingMood == widget.selectedMood
                          ? _scaleAnimation.value
                          : 1.0,
                      child: Text(
                        widget.selectedMood,
                        style: TextStyle(fontSize: 32.sp),
                      ),
                    );
                  },
                ),
                SizedBox(width: 3.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getMoodLabel(widget.selectedMood),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _getMoodColor(widget.selectedMood),
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    Text(
                      'Current mood',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),

          // Mood Options
          Text(
            'Select your mood:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          SizedBox(height: 1.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: widget.moodOptions.map((mood) {
                final isSelected = mood == widget.selectedMood;
                return GestureDetector(
                  onTap: () => _onMoodTap(mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _getMoodColor(mood).withValues(alpha: 0.2)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? _getMoodColor(mood)
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: _scaleAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _animatingMood == mood
                                  ? _scaleAnimation.value
                                  : 1.0,
                              child: Text(
                                mood,
                                style: TextStyle(fontSize: 20.sp),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 0.5.h),
                        Text(
                          _getMoodLabel(mood),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: isSelected
                                    ? _getMoodColor(mood)
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

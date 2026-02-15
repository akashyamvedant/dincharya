import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

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
  late AnimationController _bounceController;
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  // Gradient pairs for each mood — premium, vibrant
  static const List<List<Color>> _moodGradients = [
    [Color(0xFF9E8E7E), Color(0xFF7A6B5D)], // Low — muted earth
    [Color(0xFFD4A574), Color(0xFFC19660)], // Okay — warm amber
    [Color(0xFF8BC34A), Color(0xFF558B2F)], // Good — fresh green
    [Color(0xFFFFB74D), Color(0xFFE65100)], // Great — sunset orange
    [Color(0xFFFF7043), Color(0xFFBF360C)], // Amazing — fire coral
  ];

  static const List<Color> _moodColors = [
    Color(0xFF8B7355),
    Color(0xFFD4A574),
    Color(0xFF7CB342),
    Color(0xFFE67E22),
    Color(0xFFD35400),
  ];

  static const List<String> _moodLabels = ['Low', 'Okay', 'Good', 'Great', 'Amazing'];
  static const List<String> _moodSubtitles = [
    'Take it easy',
    'Getting there',
    'Feeling nice',
    'On a roll!',
    'On top of the world!',
  ];

  int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _selectedIndex = _moodToIndex(widget.selectedMood);
  }

  @override
  void didUpdateWidget(MoodSelectorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedMood != widget.selectedMood) {
      setState(() => _selectedIndex = _moodToIndex(widget.selectedMood));
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  int _moodToIndex(String mood) {
    switch (mood) {
      case '😔': return 0;
      case '😐': return 1;
      case '😊': return 2;
      case '😄': return 3;
      case '😍': return 4;
      default: return 2;
    }
  }

  void _onMoodTap(int index) {
    HapticFeedback.mediumImpact();
    _bounceController.forward().then((_) => _bounceController.reverse());
    setState(() => _selectedIndex = index);
    widget.onMoodSelected(widget.moodOptions[index]);
  }

  @override
  Widget build(BuildContext context) {
    const warmBrown = Color(0xFF8B4513);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            warmBrown.withOpacity(0.06),
            _moodColors[_selectedIndex].withOpacity(0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _moodColors[_selectedIndex].withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: _moodColors[_selectedIndex].withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            child: Row(
              children: [
                Text(
                  "How's your spirit?",
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: warmBrown,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                // Animated label chip
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _moodGradients[_selectedIndex],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _moodColors[_selectedIndex].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _moodLabels[_selectedIndex],
                    style: AppTheme.lightTheme.textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 0.8.h),
          // Subtitle
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _moodSubtitles[_selectedIndex],
                  key: ValueKey(_selectedIndex),
                  style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: _moodColors[_selectedIndex].withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 2.h),

          // Mood circles row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(5, (index) {
              final isSelected = index == _selectedIndex;
              return _buildMoodCircle(index, isSelected);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCircle(int index, bool isSelected) {
    return GestureDetector(
      onTap: () => _onMoodTap(index),
      child: AnimatedBuilder(
        animation: _glowAnimation,
        builder: (context, child) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
            width: isSelected ? 16.w : 13.w,
            height: isSelected ? 16.w : 13.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected
                  ? LinearGradient(
                      colors: _moodGradients[index],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [
                        _moodColors[index].withOpacity(0.12),
                        _moodColors[index].withOpacity(0.06),
                      ],
                    ),
              border: Border.all(
                color: isSelected
                    ? Colors.white
                    : _moodColors[index].withOpacity(0.3),
                width: isSelected ? 3 : 1.5,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _moodColors[index]
                            .withOpacity(_glowAnimation.value * 0.5),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: _moodColors[index].withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 250),
                  style: TextStyle(
                    fontSize: isSelected ? 28 : 22,
                  ),
                  child: Text(widget.moodOptions[index]),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

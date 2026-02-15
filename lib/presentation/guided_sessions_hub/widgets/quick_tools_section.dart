import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

/// Horizontal row of quick-access tool cards for meditation timer,
/// breathing exercises, and soundscapes.
class QuickToolsSection extends StatelessWidget {
  const QuickToolsSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: const Row(
            children: [
              Text('⚡', style: TextStyle(fontSize: 18)),
              SizedBox(width: 8),
              Text(
                'Quick Tools',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1810),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 1.h),
        SizedBox(
          height: 14.h,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            children: [
              _ToolCard(
                emoji: '🧘',
                label: 'Meditation\nTimer',
                sublabel: 'Unguided',
                gradient: const [Color(0xFF8B4513), Color(0xFF6B3410)],
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, '/meditation-timer');
                },
              ),
              _ToolCard(
                emoji: '🌬️',
                label: 'Breathing\nExercise',
                sublabel: '4 techniques',
                gradient: const [Color(0xFF4A7C59), Color(0xFF6B8F5B)],
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, '/breathing-exercise');
                },
              ),
              _ToolCard(
                emoji: '🎵',
                label: 'Ambient\nSounds',
                sublabel: 'Mix & relax',
                gradient: const [Color(0xFFCD853F), Color(0xFFD4A574)],
                onTap: () {
                  HapticFeedback.mediumImpact();
                  Navigator.pushNamed(context, '/soundscape');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ToolCard extends StatelessWidget {
  final String emoji;
  final String label;
  final String sublabel;
  final List<Color> gradient;
  final VoidCallback onTap;

  const _ToolCard({
    required this.emoji,
    required this.label,
    required this.sublabel,
    required this.gradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

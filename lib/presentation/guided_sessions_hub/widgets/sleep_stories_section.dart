import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Sleep Stories Section — curated dark-themed cards for sleep content.
/// Taps open soundscape screen with sleep-appropriate presets.
class SleepStoriesSection extends StatelessWidget {
  const SleepStoriesSection({super.key});

  static const Color darkBg = Color(0xFF1A1A2E);

  static const List<Map<String, dynamic>> _stories = [
    {
      'title': 'Rainy Night',
      'subtitle': 'Gentle rain on temple roof',
      'emoji': '🌧️',
      'gradient': [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
      'route': '/soundscape',
    },
    {
      'title': 'Ocean Waves',
      'subtitle': 'Deep ocean calm',
      'emoji': '🌊',
      'gradient': [Color(0xFF0F2027), Color(0xFF2C5364)],
      'route': '/soundscape',
    },
    {
      'title': 'Forest Night',
      'subtitle': 'Crickets & gentle wind',
      'emoji': '🌲',
      'gradient': [Color(0xFF1B4332), Color(0xFF2D6A4F)],
      'route': '/soundscape',
    },
    {
      'title': 'Temple Bells',
      'subtitle': 'Sacred evening ambiance',
      'emoji': '🔔',
      'gradient': [Color(0xFF3E2723), Color(0xFF6D4C41)],
      'route': '/soundscape',
    },
    {
      'title': 'Singing Bowls',
      'subtitle': 'Tibetan bowl resonance',
      'emoji': '🎵',
      'gradient': [Color(0xFF1A1A2E), Color(0xFF16213E)],
      'route': '/soundscape',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            children: [
              const Text('🌙', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              const Text(
                'Sleep & Relax',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1810),
                ),
              ),
              const Spacer(),
              Text(
                'Unwind →',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8B4513).withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 14.h,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            itemCount: _stories.length,
            itemBuilder: (context, index) {
              final story = _stories[index];
              return _buildCard(context, story);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> story) {
    final gradientColors = story['gradient'] as List<Color>;
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, story['route']),
      child: Container(
        width: 38.w,
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: gradientColors.last.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              story['emoji'] as String,
              style: const TextStyle(fontSize: 28),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  story['title'] as String,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  story['subtitle'] as String,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

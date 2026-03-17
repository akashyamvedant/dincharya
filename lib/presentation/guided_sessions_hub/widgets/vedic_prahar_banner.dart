import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../models/lifestyle_profile.dart';

/// Beautiful time-aware Vedic Prahar banner with session recommendation
/// Shows the current prahar (time block) and suggests the ideal practice.
class VedicPraharBanner extends StatelessWidget {
  final VoidCallback? onTapRecommendation;

  const VedicPraharBanner({super.key, this.onTapRecommendation});

  @override
  Widget build(BuildContext context) {
    final prahar = Prahar.getCurrentPrahar();
    final rec = _getRecommendation(prahar);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTapRecommendation?.call();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [rec.color, rec.colorEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: rec.color.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: Row(
              children: [
                // Prahar icon circle
                Container(
                  width: 14.w,
                  height: 14.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Center(
                    child: Text(rec.emoji, style: const TextStyle(fontSize: 28)),
                  ),
                ),
                SizedBox(width: 3.w),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Prahar name
                      Row(
                        children: [
                          Text(
                            prahar.nameHindi,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.surface,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${prahar.startTime}–${prahar.endTime}',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Recommendation
                      Text(
                        rec.recommendation,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontSize: 12,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: 6),

                      // Suggested practice type
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rec.suggestedAction,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.surface,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withOpacity(0.4),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  _PraharRecommendation _getRecommendation(Prahar prahar) {
    switch (prahar.id) {
      case 'brahma_muhurta':
        return _PraharRecommendation(
          emoji: '🌅',
          recommendation: 'Brahma Muhurta — the divine hour. Ideal for deep meditation and spiritual practice.',
          suggestedAction: '🧘 Start Deep Meditation',
          category: 'meditation',
          color: const Color(0xFF2C1810),
          colorEnd: const Color(0xFF5D4037),
        );
      case 'pratah':
        return _PraharRecommendation(
          emoji: '🌄',
          recommendation: 'Morning energy is highest. Perfect for Surya Namaskar and pranayama.',
          suggestedAction: '🌬️ Try Pranayama',
          category: 'pranayama',
          color: const Color(0xFFBF360C),
          colorEnd: const Color(0xFFFF6B35),
        );
      case 'purvahna':
        return _PraharRecommendation(
          emoji: '☀️',
          recommendation: 'Pitta dosha rises. Focus on productive work, light yoga for breaks.',
          suggestedAction: '💪 Quick Yoga Break',
          category: 'yoga',
          color: const Color(0xFF5D4037),
          colorEnd: const Color(0xFFCD853F),
        );
      case 'madhyahna':
        return _PraharRecommendation(
          emoji: '🌞',
          recommendation: 'Digestive fire peaks. Rest after meals, practice calm breathing.',
          suggestedAction: '🌬️ Calming Breathwork',
          category: 'pranayama',
          color: const Color(0xFF33691E),
          colorEnd: const Color(0xFF4A7C59),
        );
      case 'aparahna':
        return _PraharRecommendation(
          emoji: '🌇',
          recommendation: 'Vata begins to rise. Grounding yoga postures restore balance.',
          suggestedAction: '💪 Grounding Yoga',
          category: 'yoga',
          color: const Color(0xFF6B3410),
          colorEnd: const Color(0xFF5D4037),
        );
      case 'sandhya':
        return _PraharRecommendation(
          emoji: '🌆',
          recommendation: 'Sandhya Kaal — the sacred transition. Evening meditation calms the mind.',
          suggestedAction: '🧘 Evening Meditation',
          category: 'meditation',
          color: const Color(0xFF2C1810),
          colorEnd: const Color(0xFF5D4037),
        );
      case 'ratri':
        return _PraharRecommendation(
          emoji: '🌙',
          recommendation: 'Time to wind down. Yoga Nidra and sleep preparation bring deep rest.',
          suggestedAction: '🎵 Sleep Soundscape',
          category: 'meditation',
          color: const Color(0xFF2C1810),
          colorEnd: const Color(0xFF2C1810),
        );
      default:
        return _PraharRecommendation(
          emoji: '✨',
          recommendation: 'Begin your practice with intention and presence.',
          suggestedAction: '🧘 Start Practice',
          category: 'meditation',
          color: const Color(0xFFCD853F),
          colorEnd: const Color(0xFFD4A574),
        );
    }
  }
}

class _PraharRecommendation {
  final String emoji;
  final String recommendation;
  final String suggestedAction;
  final String category;
  final Color color;
  final Color colorEnd;

  const _PraharRecommendation({
    required this.emoji,
    required this.recommendation,
    required this.suggestedAction,
    required this.category,
    required this.color,
    required this.colorEnd,
  });
}

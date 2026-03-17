import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/guided_session_service.dart';

/// Inline dosha quiz banner â€” shown when user hasn't set their dosha yet.
/// Provides a quick 3-question flow to determine Ayurvedic constitution.
class DoshaQuizWidget extends StatefulWidget {
  final VoidCallback? onDoshaSet;

  const DoshaQuizWidget({super.key, this.onDoshaSet});

  @override
  State<DoshaQuizWidget> createState() => _DoshaQuizWidgetState();
}

class _DoshaQuizWidgetState extends State<DoshaQuizWidget> {
  final _service = GuidedSessionService();
  bool _showQuiz = false;
  int _currentQuestion = 0;
  final Map<String, int> _scores = {'vata': 0, 'pitta': 0, 'kapha': 0};

  static const _questions = [
    {
      'question': 'What describes your body type?',
      'options': [
        {'text': 'Thin, light frame', 'dosha': 'vata', 'emoji': 'ðŸŒ¬ï¸'},
        {'text': 'Medium, athletic build', 'dosha': 'pitta', 'emoji': 'ðŸ”¥'},
        {'text': 'Solid, strong frame', 'dosha': 'kapha', 'emoji': 'ðŸŒŠ'},
      ],
    },
    {
      'question': 'How do you handle stress?',
      'options': [
        {'text': 'I get anxious, restless', 'dosha': 'vata', 'emoji': 'ðŸ˜°'},
        {'text': 'I get frustrated, irritable', 'dosha': 'pitta', 'emoji': 'ðŸ˜¤'},
        {'text': 'I withdraw, feel heavy', 'dosha': 'kapha', 'emoji': 'ðŸ˜”'},
      ],
    },
    {
      'question': 'Your natural energy pattern?',
      'options': [
        {'text': 'Bursts of energy, tire quickly', 'dosha': 'vata', 'emoji': 'âš¡'},
        {'text': 'Intense focus, strong drive', 'dosha': 'pitta', 'emoji': 'ðŸŽ¯'},
        {'text': 'Steady, enduring stamina', 'dosha': 'kapha', 'emoji': 'ðŸ”ï¸'},
      ],
    },
  ];

  void _selectAnswer(String dosha) {
    HapticFeedback.selectionClick();
    setState(() {
      _scores[dosha] = (_scores[dosha] ?? 0) + 1;
      _currentQuestion++;
    });

    if (_currentQuestion >= _questions.length) {
      _completeQuiz();
    }
  }

  void _completeQuiz() async {
    // Find dominant dosha
    final dominant = _scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;

    await _service.updateDosha(dominant);
    HapticFeedback.heavyImpact();
    widget.onDoshaSet?.call();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user already has dosha set
    if (_service.userDosha != null && _service.userDosha!.isNotEmpty) {
      return const SizedBox.shrink();
    }

    if (_currentQuestion >= _questions.length) {
      final dominant = _scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return _buildResultCard(dominant);
    }

    if (!_showQuiz) {
      return _buildPromptCard();
    }

    return _buildQuestionCard();
  }

  Widget _buildPromptCard() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          setState(() => _showQuiz = true);
        },
        child: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6B3410), Color(0xFF5D4037)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6B3410).withOpacity(0.25),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
               Text('ðŸ•‰ï¸', style: TextStyle(fontSize: 32)),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Discover Your Dosha',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Take a quick 3-question quiz for personalized recommendations',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 11,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Start',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionCard() {
    final q = _questions[_currentQuestion];
    final options = q['options'] as List<Map<String, String>>;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).colorScheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress indicator
            Row(
              children: [
                Text(
                  'Question ${_currentQuestion + 1} of ${_questions.length}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                ...List.generate(
                  _questions.length,
                  (i) => Container(
                    width: 20,
                    height: 4,
                    margin: const EdgeInsets.only(left: 4),
                    decoration: BoxDecoration(
                      color: i <= _currentQuestion
                           ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFD7CCC8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.5.h),
            Text(
              q['question'] as String,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 1.5.h),
            // Options
            ...options.map((opt) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: GestureDetector(
                onTap: () => _selectAnswer(opt['dosha']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Theme.of(context).colorScheme.outline),
                  ),
                  child: Row(
                    children: [
                      Text(opt['emoji']!, style:  TextStyle(fontSize: 20)),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          opt['text']!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Color(0xFFBCAAA4), size: 20),
                    ],
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildResultCard(String dosha) {
    final info = _doshaInfo[dosha]!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [info['color'] as Color, (info['color'] as Color).withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Text(info['emoji'] as String, style:  TextStyle(fontSize: 36)),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are ${(info['name'] as String)} dominant!',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    info['tip'] as String,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 11,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.check_circle, color: Colors.white54, size: 24),
          ],
        ),
      ),
    );
  }

  static const Map<String, Map<String, dynamic>> _doshaInfo = {
    'vata': {
      'name': 'Vata',
      'emoji': 'ðŸŒ¬ï¸',
      'color': Color(0xFFCD853F),
      'tip': 'Calming meditations and grounding yoga are best for you.',
    },
    'pitta': {
      'name': 'Pitta',
      'emoji': 'ðŸ”¥',
      'color': Color(0xFFEF6C00),
      'tip': 'Cooling breathwork and gentle yoga balance your fire.',
    },
    'kapha': {
      'name': 'Kapha',
      'emoji': 'ðŸŒŠ',
      'color': Color(0xFF4A7C59),
      'tip': 'Energizing practices and dynamic yoga awaken your energy.',
    },
  };
}

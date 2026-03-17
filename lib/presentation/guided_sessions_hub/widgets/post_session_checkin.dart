import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'dart:math';

/// Post-session mood check-in overlay
/// Shows after a guided session ends to capture mood/energy feedback
class PostSessionCheckIn extends StatefulWidget {
  final String sessionTitle;
  final String category; // meditation, pranayama, yoga
  final int durationSeconds;
  final void Function({
    required String moodBefore,
    required String moodAfter,
    required int energyBefore,
    required int energyAfter,
    String? notes,
  }) onSubmit;
  final VoidCallback onSkip;

  const PostSessionCheckIn({
    super.key,
    required this.sessionTitle,
    required this.category,
    required this.durationSeconds,
    required this.onSubmit,
    required this.onSkip,
  });

  @override
  State<PostSessionCheckIn> createState() => _PostSessionCheckInState();
}

class _PostSessionCheckInState extends State<PostSessionCheckIn>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  int _currentStep = 0; // 0: mood, 1: energy, 2: notes
  String _selectedMood = '';
  int _selectedEnergy = 3;
  final TextEditingController _notesController = TextEditingController();

  // Particle system for celebratory background
  final List<_Particle> _particles = [];

  static Color primaryBrown = Color(0xFF5D4037);
  static const Color warmCream = Color(0xFFFFF8F0);

  final List<Map<String, dynamic>> _moods = [
    {'emoji': '😌', 'label': 'Peaceful', 'color': Color(0xFF4A7C59)},
    {'emoji': '😊', 'label': 'Happy', 'color': Color(0xFFCD853F)},
    {'emoji': '🧘', 'label': 'Focused', 'color': Color(0xFF5D4037)},
    {'emoji': '😴', 'label': 'Relaxed', 'color': Color(0xFF5D4037)},
    {'emoji': '⚡', 'label': 'Energized', 'color': Color(0xFFFF6B35)},
    {'emoji': '😐', 'label': 'Neutral', 'color': Color(0xFFB8732E)},
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Generate particles
    final rng = Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 3 + rng.nextDouble() * 5,
        speed: 0.2 + rng.nextDouble() * 0.5,
        color: [
          primaryBrown.withOpacity(0.15),
          const Color(0xFFFF9800).withOpacity(0.1),
          const Color(0xFFFFD700).withOpacity(0.12),
        ][rng.nextInt(3)],
      ));
    }

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _slideController.reset();
      setState(() => _currentStep++);
      _slideController.forward();
    } else {
      _submit();
    }
  }

  void _submit() {
    widget.onSubmit(
      moodBefore: 'neutral', // Pre-session mood not captured yet
      moodAfter: _selectedMood.isEmpty ? 'neutral' : _selectedMood,
      energyBefore: 3,
      energyAfter: _selectedEnergy,
      notes: _notesController.text.isEmpty ? null : _notesController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
        child: SafeArea(
          child: Center(
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 5.w),
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: primaryBrown.withOpacity(0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    _buildHeader(),
                    SizedBox(height: 3.h),

                    // Step indicator
                    _buildStepIndicator(),
                    SizedBox(height: 3.h),

                    // Content based on step
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _buildStepContent(),
                    ),

                    SizedBox(height: 3.h),

                    // Action buttons
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final durationMin = (widget.durationSeconds / 60).round();
    return Column(
      children: [
        // Celebration icon
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primaryBrown, primaryBrown.withOpacity(0.7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryBrown.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.check_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          'Session Complete! 🎉',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          '${widget.sessionTitle} • ${durationMin} min',
          style: TextStyle(
            fontSize: 13,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final isActive = i == _currentStep;
        final isDone = i < _currentStep;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDone
                ? primaryBrown
                : isActive
                    ? primaryBrown
                    : primaryBrown.withOpacity(0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildMoodStep();
      case 1:
        return _buildEnergyStep();
      case 2:
        return _buildNotesStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildMoodStep() {
    return Column(
      key: const ValueKey('mood'),
      children: [
        Text(
          'How do you feel now?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 2.h),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.center,
          children: _moods.map((mood) {
            final isSelected = _selectedMood == mood['label'];
            return GestureDetector(
              onTap: () => setState(() => _selectedMood = mood['label'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (mood['color'] as Color).withOpacity(0.15)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? mood['color'] as Color
                        : Theme.of(context).colorScheme.outline,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(
                          color: (mood['color'] as Color).withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(mood['emoji'] as String, style:  TextStyle(fontSize: 20)),
                     SizedBox(width: 6),
                    Text(
                      mood['label'] as String,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? mood['color'] as Color
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildEnergyStep() {
    return Column(
      key: const ValueKey('energy'),
      children: [
        Text(
          'Energy Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 1.h),
        Text(
          'How energized do you feel?',
          style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)),
        ),
        SizedBox(height: 3.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final level = i + 1;
            final isSelected = _selectedEnergy >= level;
            return GestureDetector(
              onTap: () => setState(() => _selectedEnergy = level),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Color.lerp(Color(0xFFD4A574), const Color(0xFF4A7C59), i / 4)
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    shape: BoxShape.circle,
                    boxShadow: isSelected
                        ? [BoxShadow(
                            color: primaryBrown.withOpacity(0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          )]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      ['😴', '😐', '🙂', '😊', '⚡'][i],
                      style: TextStyle(fontSize: isSelected ? 22 : 18),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        SizedBox(height: 1.h),
        Text(
          ['Very Low', 'Low', 'Moderate', 'High', 'Very High'][_selectedEnergy - 1],
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: primaryBrown,
          ),
        ),
      ],
    );
  }

  Widget _buildNotesStep() {
    return Column(
      key: const ValueKey('notes'),
      children: [
        Text(
          'Any reflections? (optional)',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 2.h),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.outline),
          ),
          child: TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'What stood out during this session...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      children: [
        // Skip button
        TextButton(
          onPressed: _currentStep == 0 ? widget.onSkip : () {
            _slideController.reset();
            setState(() => _currentStep--);
            _slideController.forward();
          },
          child: Text(
            _currentStep == 0 ? 'Skip' : 'Back',
            style: TextStyle(color: Color(0xFF6B4423), fontSize: 14),
          ),
        ),
        const Spacer(),
        // Next/Done button
        GestureDetector(
          onTap: _currentStep == 0 && _selectedMood.isEmpty
              ? null
              : _nextStep,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _currentStep == 0 && _selectedMood.isEmpty
                    ? [Theme.of(context).colorScheme.outline, Colors.grey.shade400]
                    : [primaryBrown, primaryBrown.withOpacity(0.8)],
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: primaryBrown.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Text(
              _currentStep >= 2 ? 'Done ✨' : 'Next',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Particle {
  double x, y, size, speed;
  Color color;
  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.color,
  });
}

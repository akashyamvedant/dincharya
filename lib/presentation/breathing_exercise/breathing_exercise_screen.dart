import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../services/supabase_service.dart';

/// Breathing technique configuration
class BreathingTechnique {
  final String id;
  final String name;
  final String nameHindi;
  final String description;
  final int inhaleSeconds;
  final int holdAfterInhale;
  final int exhaleSeconds;
  final int holdAfterExhale;
  final int totalRounds;
  final Color color;
  final String emoji;

  const BreathingTechnique({
    required this.id,
    required this.name,
    required this.nameHindi,
    required this.description,
    required this.inhaleSeconds,
    required this.holdAfterInhale,
    required this.exhaleSeconds,
    required this.holdAfterExhale,
    required this.totalRounds,
    required this.color,
    required this.emoji,
  });

  /// Total seconds for one full round
  int get roundDuration => inhaleSeconds + holdAfterInhale + exhaleSeconds + holdAfterExhale;
}

/// Available techniques
const List<BreathingTechnique> _techniques = [
  BreathingTechnique(
    id: 'box',
    name: 'Box Breathing',
    nameHindi: 'बॉक्स ब्रीदिंग',
    description: 'Equal inhale, hold, exhale, hold.\nCalms the nervous system.',
    inhaleSeconds: 4,
    holdAfterInhale: 4,
    exhaleSeconds: 4,
    holdAfterExhale: 4,
    totalRounds: 8,
    color: Color(0xFF448AFF),
    emoji: '🔷',
  ),
  BreathingTechnique(
    id: '478',
    name: '4-7-8 Relaxation',
    nameHindi: '4-7-8 विश्राम',
    description: 'Deep relaxation technique.\nReduces anxiety & promotes sleep.',
    inhaleSeconds: 4,
    holdAfterInhale: 7,
    exhaleSeconds: 8,
    holdAfterExhale: 0,
    totalRounds: 6,
    color: Color(0xFFAB47BC),
    emoji: '🌙',
  ),
  BreathingTechnique(
    id: 'anulom',
    name: 'Anulom Vilom',
    nameHindi: 'अनुलोम विलोम',
    description: 'Alternate nostril breathing.\nBalances both hemispheres.',
    inhaleSeconds: 4,
    holdAfterInhale: 2,
    exhaleSeconds: 4,
    holdAfterExhale: 2,
    totalRounds: 10,
    color: Color(0xFF66BB6A),
    emoji: '🌿',
  ),
  BreathingTechnique(
    id: 'kapalabhati',
    name: 'Kapalabhati',
    nameHindi: 'कपालभाति',
    description: 'Skull-shining breath.\nEnergizing rapid exhales.',
    inhaleSeconds: 1,
    holdAfterInhale: 0,
    exhaleSeconds: 1,
    holdAfterExhale: 0,
    totalRounds: 30,
    color: Color(0xFFFF7043),
    emoji: '🔥',
  ),
];

enum BreathPhase { inhale, holdInhale, exhale, holdExhale }

class BreathingExerciseScreen extends StatefulWidget {
  const BreathingExerciseScreen({super.key});

  @override
  State<BreathingExerciseScreen> createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen>
    with TickerProviderStateMixin {
  final SupabaseService _supabase = SupabaseService();

  // State
  int _selectedTechniqueIndex = 0;
  bool _isActive = false;
  bool _isComplete = false;
  int _currentRound = 0;
  BreathPhase _currentPhase = BreathPhase.inhale;
  int _phaseSecondsRemaining = 0;

  // Animation
  late AnimationController _circleController;
  late Animation<double> _circleAnimation;
  Timer? _breathTimer;

  DateTime? _startTime;

  BreathingTechnique get _technique => _techniques[_selectedTechniqueIndex];

  @override
  void initState() {
    super.initState();
    _circleController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );
    _circleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _circleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathTimer?.cancel();
    _circleController.dispose();
    super.dispose();
  }

  void _startExercise() {
    HapticFeedback.mediumImpact();
    setState(() {
      _isActive = true;
      _isComplete = false;
      _currentRound = 1;
      _currentPhase = BreathPhase.inhale;
      _phaseSecondsRemaining = _technique.inhaleSeconds;
      _startTime = DateTime.now();
    });
    _animateForPhase(BreathPhase.inhale);
    _startPhaseTimer();
  }

  void _stopExercise() {
    _breathTimer?.cancel();
    _circleController.stop();
    final elapsed = _startTime != null ? DateTime.now().difference(_startTime!).inSeconds : 0;
    if (elapsed > 30) _logSession(elapsed);
    setState(() {
      _isActive = false;
      _isComplete = false;
    });
  }

  void _animateForPhase(BreathPhase phase) {
    final t = _technique;
    _circleController.stop();

    switch (phase) {
      case BreathPhase.inhale:
        _circleController.duration = Duration(seconds: t.inhaleSeconds);
        _circleController.forward(from: 0);
        break;
      case BreathPhase.holdInhale:
        // Hold expanded
        _circleController.value = 1.0;
        break;
      case BreathPhase.exhale:
        _circleController.duration = Duration(seconds: t.exhaleSeconds);
        _circleController.reverse(from: 1.0);
        break;
      case BreathPhase.holdExhale:
        // Hold contracted
        _circleController.value = 0.0;
        break;
    }
  }

  void _startPhaseTimer() {
    _breathTimer?.cancel();
    _breathTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _phaseSecondsRemaining--;
      });

      if (_phaseSecondsRemaining <= 0) {
        _advancePhase();
      }
    });
  }

  void _advancePhase() {
    HapticFeedback.lightImpact();
    final t = _technique;
    BreathPhase nextPhase;
    int nextDuration;

    switch (_currentPhase) {
      case BreathPhase.inhale:
        if (t.holdAfterInhale > 0) {
          nextPhase = BreathPhase.holdInhale;
          nextDuration = t.holdAfterInhale;
        } else {
          nextPhase = BreathPhase.exhale;
          nextDuration = t.exhaleSeconds;
        }
        break;
      case BreathPhase.holdInhale:
        nextPhase = BreathPhase.exhale;
        nextDuration = t.exhaleSeconds;
        break;
      case BreathPhase.exhale:
        if (t.holdAfterExhale > 0) {
          nextPhase = BreathPhase.holdExhale;
          nextDuration = t.holdAfterExhale;
        } else {
          // End of round
          if (_currentRound >= t.totalRounds) {
            _completeExercise();
            return;
          }
          _currentRound++;
          nextPhase = BreathPhase.inhale;
          nextDuration = t.inhaleSeconds;
        }
        break;
      case BreathPhase.holdExhale:
        // End of round
        if (_currentRound >= t.totalRounds) {
          _completeExercise();
          return;
        }
        _currentRound++;
        nextPhase = BreathPhase.inhale;
        nextDuration = t.inhaleSeconds;
        break;
    }

    setState(() {
      _currentPhase = nextPhase;
      _phaseSecondsRemaining = nextDuration;
    });
    _animateForPhase(nextPhase);
  }

  void _completeExercise() {
    _breathTimer?.cancel();
    _circleController.stop();
    HapticFeedback.heavyImpact();
    final elapsed = _startTime != null ? DateTime.now().difference(_startTime!).inSeconds : 0;
    _logSession(elapsed);
    setState(() {
      _isActive = false;
      _isComplete = true;
    });
  }

  Future<void> _logSession(int durationSeconds) async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;
      final client = await _supabase.client;
      if (client == null) return;

      await client.from('practice_sessions').insert({
        'user_id': userId,
        'technique': 'breathing_${_technique.id}',
        'duration_seconds': durationSeconds,
        'completed_at': DateTime.now().toIso8601String(),
        'notes': '${_technique.name} — $_currentRound rounds',
      });
    } catch (e) {
      debugPrint('❌ Error logging breathing: $e');
    }
  }

  String _phaseLabel(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale:
        return 'Breathe In';
      case BreathPhase.holdInhale:
        return 'Hold';
      case BreathPhase.exhale:
        return 'Breathe Out';
      case BreathPhase.holdExhale:
        return 'Hold';
    }
  }

  IconData _phaseIcon(BreathPhase phase) {
    switch (phase) {
      case BreathPhase.inhale:
        return Icons.arrow_upward_rounded;
      case BreathPhase.holdInhale:
        return Icons.pause_rounded;
      case BreathPhase.exhale:
        return Icons.arrow_downward_rounded;
      case BreathPhase.holdExhale:
        return Icons.pause_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: _isComplete
            ? _buildCompleteView()
            : (_isActive ? _buildActiveView() : _buildSelectorView()),
      ),
    );
  }

  // ─── Technique Selector ───
  Widget _buildSelectorView() {
    final t = _technique;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top bar
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
              ),
              const Spacer(),
              const Text(
                'Breathing Exercise',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const SizedBox(width: 48),
            ],
          ),

          SizedBox(height: 2.h),

          // Technique cards (horizontal)
          SizedBox(
            height: 10.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _techniques.length,
              itemBuilder: (context, i) {
                final tech = _techniques[i];
                final selected = i == _selectedTechniqueIndex;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedTechniqueIndex = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 28.w,
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: selected ? tech.color.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? tech.color : Colors.white12,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(tech.emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(height: 6),
                        Text(
                          tech.name,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: selected ? tech.color : Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 3.h),

          // Selected technique details
          Center(
            child: Column(
              children: [
                Text(
                  t.emoji,
                  style: const TextStyle(fontSize: 48),
                ),
                SizedBox(height: 1.h),
                Text(
                  t.name,
                  style: TextStyle(color: t.color, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                Text(
                  t.nameHindi,
                  style: TextStyle(color: t.color.withOpacity(0.6), fontSize: 14),
                ),
                SizedBox(height: 1.h),
                Text(
                  t.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13, height: 1.5),
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // Timing breakdown
          Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _timingChip('In', '${t.inhaleSeconds}s', t.color),
                  if (t.holdAfterInhale > 0) ...[
                    _arrow(t.color),
                    _timingChip('Hold', '${t.holdAfterInhale}s', t.color),
                  ],
                  _arrow(t.color),
                  _timingChip('Out', '${t.exhaleSeconds}s', t.color),
                  if (t.holdAfterExhale > 0) ...[
                    _arrow(t.color),
                    _timingChip('Hold', '${t.holdAfterExhale}s', t.color),
                  ],
                ],
              ),
            ),
          ),

          SizedBox(height: 1.h),
          Center(
            child: Text(
              '${t.totalRounds} rounds · ~${(t.roundDuration * t.totalRounds / 60).ceil()} min',
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 12),
            ),
          ),

          const Spacer(),

          // Start button
          Center(
            child: GestureDetector(
              onTap: _startExercise,
              child: Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [t.color, t.color.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: t.color.withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                ),
              ),
            ),
          ),

          SizedBox(height: 3.h),
        ],
      ),
    );
  }

  Widget _timingChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10)),
      ],
    );
  }

  Widget _arrow(Color c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Icon(Icons.arrow_forward_rounded, color: c.withOpacity(0.3), size: 16),
    );
  }

  // ─── Active Breathing View ───
  Widget _buildActiveView() {
    final t = _technique;
    return GestureDetector(
      onDoubleTap: _stopExercise,
      child: Container(
        color: Colors.transparent,
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _stopExercise,
                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  ),
                  const Spacer(),
                  Text(
                    t.name,
                    style: TextStyle(color: t.color.withOpacity(0.6), fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  const Spacer(),
                  // Round counter
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: t.color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$_currentRound / ${t.totalRounds}',
                      style: TextStyle(color: t.color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Animated breathing circle
            AnimatedBuilder(
              animation: _circleAnimation,
              builder: (context, _) {
                final scale = _circleAnimation.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow
                    Container(
                      width: 70.w * scale,
                      height: 70.w * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: t.color.withOpacity(0.2 * scale),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),

                    // Middle ring
                    Container(
                      width: 60.w * scale,
                      height: 60.w * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: t.color.withOpacity(0.15), width: 1),
                      ),
                    ),

                    // Inner circle
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 50.w * scale,
                      height: 50.w * scale,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            t.color.withOpacity(0.3),
                            t.color.withOpacity(0.1),
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                        border: Border.all(color: t.color.withOpacity(0.4), width: 2),
                      ),
                    ),

                    // Phase info
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_phaseIcon(_currentPhase), color: t.color, size: 32),
                        const SizedBox(height: 8),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Text(
                            _phaseLabel(_currentPhase),
                            key: ValueKey(_currentPhase),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_phaseSecondsRemaining',
                          style: TextStyle(
                            color: t.color,
                            fontSize: 40,
                            fontWeight: FontWeight.w200,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const Spacer(),

            // Phase timeline
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _phaseIndicator('In', BreathPhase.inhale, t.color),
                  if (t.holdAfterInhale > 0)
                    _phaseIndicator('Hold', BreathPhase.holdInhale, t.color),
                  _phaseIndicator('Out', BreathPhase.exhale, t.color),
                  if (t.holdAfterExhale > 0)
                    _phaseIndicator('Hold', BreathPhase.holdExhale, t.color),
                ],
              ),
            ),

            SizedBox(height: 4.h),
          ],
        ),
      ),
    );
  }

  Widget _phaseIndicator(String label, BreathPhase phase, Color color) {
    final active = _currentPhase == phase;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.2) : Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: active ? color.withOpacity(0.5) : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? color : Colors.white30,
              fontSize: 11,
              fontWeight: active ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  // ─── Complete View ───
  Widget _buildCompleteView() {
    final t = _technique;
    final elapsed = _startTime != null ? DateTime.now().difference(_startTime!).inSeconds : 0;
    final minutes = elapsed ~/ 60;
    final seconds = elapsed % 60;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 25.w,
            height: 25.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [t.color, t.color.withOpacity(0.6)],
              ),
              boxShadow: [
                BoxShadow(color: t.color.withOpacity(0.3), blurRadius: 20, spreadRadius: 3),
              ],
            ),
            child: const Center(
              child: Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            '${t.name} Complete!',
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 1.h),
          Text(
            'Well done 🙏',
            style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 14),
          ),
          SizedBox(height: 3.h),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _statCol(t.emoji, '${t.totalRounds}', 'Rounds'),
                Container(width: 1, height: 40, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 24)),
                _statCol('⏱️', '${minutes}m ${seconds}s', 'Duration'),
              ],
            ),
          ),
          SizedBox(height: 5.h),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: t.color,
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text('Done', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11)),
      ],
    );
  }
}

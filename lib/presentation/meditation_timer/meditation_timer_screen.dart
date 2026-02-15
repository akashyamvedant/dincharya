import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../services/meditation_timer_service.dart';
import '../../services/supabase_service.dart';

class MeditationTimerScreen extends StatefulWidget {
  const MeditationTimerScreen({super.key});

  @override
  State<MeditationTimerScreen> createState() => _MeditationTimerScreenState();
}

class _MeditationTimerScreenState extends State<MeditationTimerScreen>
    with TickerProviderStateMixin {
  final MeditationTimerService _timerService = MeditationTimerService();
  final SupabaseService _supabase = SupabaseService();

  // Config
  int _selectedMinutes = 10;
  int _selectedInterval = 0; // 0 = none
  bool _hasStarted = false;
  bool _isComplete = false;

  // Animations
  late AnimationController _breathController;
  late AnimationController _glowController;
  late Animation<double> _breathAnimation;
  late Animation<double> _glowAnimation;

  final List<int> _durationOptions = [5, 10, 15, 20, 30, 45, 60];
  final List<Map<String, dynamic>> _intervalOptions = [
    {'label': 'None', 'value': 0},
    {'label': '1 min', 'value': 1},
    {'label': '2 min', 'value': 2},
    {'label': '5 min', 'value': 5},
    {'label': '10 min', 'value': 10},
  ];

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _glowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _timerService.onTick = () {
      if (mounted) setState(() {});
    };

    _timerService.onComplete = () {
      HapticFeedback.heavyImpact();
      if (mounted) {
        setState(() => _isComplete = true);
        _logSession();
      }
    };

    _timerService.onBell = () {
      HapticFeedback.mediumImpact();
    };
  }

  @override
  void dispose() {
    _breathController.dispose();
    _glowController.dispose();
    _timerService.stop();
    super.dispose();
  }

  void _startMeditation() {
    HapticFeedback.mediumImpact();
    _timerService.configure(
      totalMinutes: _selectedMinutes,
      intervalMinutes: _selectedInterval,
    );
    _timerService.start();
    setState(() => _hasStarted = true);
  }

  void _togglePause() {
    HapticFeedback.lightImpact();
    if (_timerService.isRunning) {
      _timerService.pause();
    } else {
      _timerService.resume();
    }
    setState(() {});
  }

  void _stopMeditation() {
    HapticFeedback.mediumImpact();
    if (_timerService.elapsedSeconds > 60) {
      _logSession();
    }
    _timerService.reset();
    setState(() {
      _hasStarted = false;
      _isComplete = false;
    });
  }

  Future<void> _logSession() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return;

      final client = await _supabase.client;
      if (client == null) return;

      await client.from('practice_sessions').insert({
        'user_id': userId,
        'technique': 'meditation_timer',
        'duration_seconds': _timerService.elapsedSeconds,
        'completed_at': DateTime.now().toIso8601String(),
        'notes': '${_selectedMinutes}min unguided meditation',
      });
    } catch (e) {
      debugPrint('❌ Error logging meditation: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1A),
      body: SafeArea(
        child: _isComplete ? _buildCompleteView() : (_hasStarted ? _buildTimerView() : _buildConfigView()),
      ),
    );
  }

  // ─── Configuration View ───
  Widget _buildConfigView() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
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
                'Meditation Timer',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 48), // Balance
            ],
          ),

          SizedBox(height: 4.h),

          // Decorative icon
          Center(
            child: AnimatedBuilder(
              animation: _breathAnimation,
              builder: (context, _) => Transform.scale(
                scale: _breathAnimation.value,
                child: Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFF8B4513).withOpacity(0.4),
                        const Color(0xFF8B4513).withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(color: const Color(0xFF8B4513).withOpacity(0.3), width: 2),
                  ),
                  child: const Center(
                    child: Text('🧘', style: TextStyle(fontSize: 40)),
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: 4.h),

          // Duration picker
          const Text(
            'Duration',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 1.h),
          SizedBox(
            height: 5.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _durationOptions.length,
              itemBuilder: (context, i) {
                final min = _durationOptions[i];
                final selected = min == _selectedMinutes;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedMinutes = min);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF8B4513) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFF8B4513) : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$min min',
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          SizedBox(height: 3.h),

          // Interval picker
          const Text(
            'Interval Bell',
            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 1.h),
          SizedBox(
            height: 5.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _intervalOptions.length,
              itemBuilder: (context, i) {
                final opt = _intervalOptions[i];
                final selected = opt['value'] == _selectedInterval;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedInterval = opt['value'] as int);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFF4A7C59) : Colors.white.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected ? const Color(0xFF4A7C59) : Colors.white12,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        opt['label'] as String,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.white60,
                          fontSize: 13,
                          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Spacer(),

          // Summary
          Center(
            child: Column(
              children: [
                Text(
                  '$_selectedMinutes minutes',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w300,
                    letterSpacing: 2,
                  ),
                ),
                if (_selectedInterval > 0)
                  Text(
                    'Bell every $_selectedInterval min',
                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 13),
                  ),
              ],
            ),
          ),

          SizedBox(height: 4.h),

          // Start button
          Center(
            child: GestureDetector(
              onTap: _startMeditation,
              child: Container(
                width: 22.w,
                height: 22.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF8B4513), Color(0xFFCD853F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8B4513).withOpacity(0.4),
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

  // ─── Active Timer View ───
  Widget _buildTimerView() {
    return GestureDetector(
      onTap: _togglePause,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.transparent,
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _stopMeditation,
                    icon: const Icon(Icons.close_rounded, color: Colors.white38),
                  ),
                  const Spacer(),
                  Text(
                    _timerService.isRunning ? 'Meditating' : 'Paused',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            const Spacer(),

            // Circular progress + time
            AnimatedBuilder(
              animation: _glowAnimation,
              builder: (context, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Glow ring
                    Container(
                      width: 72.w,
                      height: 72.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF8B4513).withOpacity(
                              _timerService.isRunning ? _glowAnimation.value * 0.3 : 0.1,
                            ),
                            blurRadius: 40,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                    ),

                    // Progress ring
                    SizedBox(
                      width: 65.w,
                      height: 65.w,
                      child: CustomPaint(
                        painter: _CircularProgressPainter(
                          progress: _timerService.progress,
                          strokeWidth: 4,
                          backgroundColor: Colors.white.withOpacity(0.08),
                          progressColor: const Color(0xFF8B4513),
                        ),
                      ),
                    ),

                    // Inner breathing circle
                    AnimatedBuilder(
                      animation: _breathAnimation,
                      builder: (context, _) => Transform.scale(
                        scale: _timerService.isRunning ? _breathAnimation.value : 1.0,
                        child: Container(
                          width: 55.w,
                          height: 55.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                const Color(0xFF8B4513).withOpacity(0.15),
                                const Color(0xFF8B4513).withOpacity(0.05),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // Time display
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _timerService.remainingFormatted,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 48,
                            fontWeight: FontWeight.w200,
                            letterSpacing: 4,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'remaining',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 12,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),

            const Spacer(),

            // Tap hint
            Padding(
              padding: EdgeInsets.only(bottom: 4.h),
              child: Text(
                _timerService.isRunning ? 'Tap to pause' : 'Tap to resume',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.25),
                  fontSize: 12,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Complete View ───
  Widget _buildCompleteView() {
    final minutes = _timerService.elapsedSeconds ~/ 60;
    final seconds = _timerService.elapsedSeconds % 60;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Checkmark
          Container(
            width: 25.w,
            height: 25.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4A7C59), Color(0xFF6B9B7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4A7C59).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 3,
                ),
              ],
            ),
            child: const Center(
              child: Icon(Icons.check_rounded, color: Colors.white, size: 48),
            ),
          ),

          SizedBox(height: 3.h),

          const Text(
            'Session Complete',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: 1.h),

          Text(
            'Namaste 🙏',
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),

          SizedBox(height: 3.h),

          // Stats
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
                _statItem('⏱️', '${minutes}m ${seconds}s', 'Duration'),
                Container(width: 1, height: 40, color: Colors.white12, margin: const EdgeInsets.symmetric(horizontal: 24)),
                _statItem('🔔', _selectedInterval > 0 ? 'Every ${_selectedInterval}m' : 'None', 'Interval'),
              ],
            ),
          ),

          SizedBox(height: 5.h),

          // Done button
          GestureDetector(
            onTap: () {
              _timerService.reset();
              Navigator.pop(context);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF8B4513),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Text(
                'Done',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(String emoji, String value, String label) {
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

// ─── Circular Progress Painter ───
class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color backgroundColor;
  final Color progressColor;

  _CircularProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.backgroundColor,
    required this.progressColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Background circle
    final bgPaint = Paint()
      ..color = backgroundColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

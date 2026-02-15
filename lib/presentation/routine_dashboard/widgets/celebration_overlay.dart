import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Celebration overlay shown when a task is completed
/// Features: confetti particles, XP reward animation, progress update
class CelebrationOverlay extends StatefulWidget {
  final int xpEarned;
  final String taskName;
  final double dailyProgress; // 0.0 - 1.0
  final VoidCallback onDismiss;

  const CelebrationOverlay({
    super.key,
    required this.xpEarned,
    required this.taskName,
    required this.dailyProgress,
    required this.onDismiss,
  });

  @override
  State<CelebrationOverlay> createState() => _CelebrationOverlayState();
}

class _CelebrationOverlayState extends State<CelebrationOverlay>
    with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _confettiController;
  late AnimationController _checkController;
  late AnimationController _xpController;
  
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _checkScale;
  late Animation<double> _xpSlide;
  late Animation<double> _xpFade;
  late Animation<double> _progressAnimation;
  
  final List<_ConfettiParticle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _generateParticles();
    
    // Auto dismiss after 2 seconds
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (mounted) {
        _mainController.reverse().then((_) {
          if (mounted) widget.onDismiss();
        });
      }
    });
  }

  void _initAnimations() {
    // Main overlay fade
    _mainController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOut),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: Curves.easeOutBack),
    );

    // Confetti burst
    _confettiController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // Checkmark animation
    _checkController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _checkScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
    );

    // XP text slide up
    _xpController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _xpSlide = Tween<double>(begin: 20.0, end: 0.0).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeOut),
    );
    _xpFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeIn),
    );
    
    _progressAnimation = Tween<double>(
      begin: (widget.dailyProgress - 0.15).clamp(0.0, 1.0),
      end: widget.dailyProgress,
    ).animate(
      CurvedAnimation(parent: _xpController, curve: Curves.easeInOut),
    );

    // Sequence animations
    _mainController.forward().then((_) {
      _confettiController.forward();
      _checkController.forward().then((_) {
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _xpController.forward();
        });
      });
    });
  }

  void _generateParticles() {
    final colors = [
      const Color(0xFFFFB74D), // amber
      const Color(0xFFFF7043), // orange
      const Color(0xFF4A7C59), // natural green
      const Color(0xFFE91E63), // pink
      const Color(0xFFCD853F), // sandy brown
      const Color(0xFFFFD700), // gold
      const Color(0xFF8B4513), // earth brown
    ];

    for (int i = 0; i < 40; i++) {
      _particles.add(_ConfettiParticle(
        x: _random.nextDouble() * 2 - 1, // -1 to 1
        y: _random.nextDouble() * 2 - 1,
        velocity: _random.nextDouble() * 200 + 100,
        angle: _random.nextDouble() * 2 * pi,
        color: colors[_random.nextInt(colors.length)],
        size: _random.nextDouble() * 6 + 3,
        rotation: _random.nextDouble() * 2 * pi,
        rotationSpeed: (_random.nextDouble() - 0.5) * 10,
      ));
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _confettiController.dispose();
    _checkController.dispose();
    _xpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _mainController,
        _confettiController,
        _checkController,
        _xpController,
      ]),
      builder: (context, child) {
        return Opacity(
          opacity: _fadeAnimation.value,
          child: GestureDetector(
            onTap: () {
              _mainController.reverse().then((_) {
                if (mounted) widget.onDismiss();
              });
            },
            child: Container(
              color: Colors.black.withOpacity(0.3 * _fadeAnimation.value),
              child: Center(
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Confetti area
                      SizedBox(
                        width: 70.w,
                        height: 40.w,
                        child: CustomPaint(
                          painter: _ConfettiPainter(
                            particles: _particles,
                            progress: _confettiController.value,
                          ),
                          child: Center(
                            child: _buildCheckmark(),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 2.h),
                      
                      // XP Reward text
                      Transform.translate(
                        offset: Offset(0, _xpSlide.value),
                        child: Opacity(
                          opacity: _xpFade.value,
                          child: Column(
                            children: [
                              // Task name
                              Text(
                                'Task Complete! ✨',
                                style: TextStyle(
                                  fontSize: 20.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 0.5.h),
                              // XP earned
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 4.w,
                                  vertical: 1.h,
                                ),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFB74D),
                                      Color(0xFFFF8F00),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFFFB74D).withOpacity(0.4),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('⭐', style: TextStyle(fontSize: 18.sp)),
                                    SizedBox(width: 1.5.w),
                                    Text(
                                      '+${widget.xpEarned} XP',
                                      style: TextStyle(
                                        fontSize: 18.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              
                              SizedBox(height: 2.h),
                              
                              // Daily progress bar
                              Container(
                                width: 60.w,
                                padding: EdgeInsets.all(3.w),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Daily Progress',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: Colors.white70,
                                      ),
                                    ),
                                    SizedBox(height: 0.5.h),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: LinearProgressIndicator(
                                        value: _progressAnimation.value,
                                        minHeight: 10,
                                        backgroundColor: Colors.white.withOpacity(0.2),
                                        valueColor: const AlwaysStoppedAnimation(
                                          Color(0xFF4A7C59),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 0.3.h),
                                    Text(
                                      '${(_progressAnimation.value * 100).toInt()}%',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCheckmark() {
    return Transform.scale(
      scale: _checkScale.value,
      child: Container(
        width: 22.w,
        height: 22.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF4A7C59), Color(0xFF3A6249)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4A7C59).withOpacity(0.5),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Icon(
          Icons.check_rounded,
          color: Colors.white,
          size: 12.w,
        ),
      ),
    );
  }
}

// ===== Confetti Particle System =====

class _ConfettiParticle {
  final double x;
  final double y;
  final double velocity;
  final double angle;
  final Color color;
  final double size;
  final double rotation;
  final double rotationSpeed;

  _ConfettiParticle({
    required this.x,
    required this.y,
    required this.velocity,
    required this.angle,
    required this.color,
    required this.size,
    required this.rotation,
    required this.rotationSpeed,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (final particle in particles) {
      final distance = particle.velocity * progress;
      final gravity = 100 * progress * progress; // gravity effect
      
      final dx = center.dx + cos(particle.angle) * distance * particle.x;
      final dy = center.dy + sin(particle.angle) * distance * particle.y + gravity;

      final opacity = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;

      final currentRotation = particle.rotation + particle.rotationSpeed * progress;

      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate(currentRotation);
      
      // Draw confetti shape (alternating between rectangles and circles)
      if (particle.size > 5) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: particle.size, height: particle.size * 0.6),
            const Radius.circular(1),
          ),
          paint,
        );
      } else {
        canvas.drawCircle(Offset.zero, particle.size / 2, paint);
      }
      
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

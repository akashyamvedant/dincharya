// lib/presentation/routine_dashboard/mind_games/widgets/game_shell.dart
// PREMIUM GAME SHELL v2 — Spring physics, particle confetti, glow effects, blur overlays
// Inspired by Lumosity + Peak + Elevate game screen patterns

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';

// ═══════════════════════ HAPTICS ═══════════════════════

class GameHaptics {
  GameHaptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void correct() => HapticFeedback.lightImpact();
  static void wrong() => HapticFeedback.heavyImpact();
  static void win() => HapticFeedback.mediumImpact();
}

// ═══════════════════════ PREMIUM COUNTDOWN ═══════════════════════

class GameCountdown extends StatefulWidget {
  final VoidCallback onDone;
  const GameCountdown({super.key, required this.onDone});
  @override
  State<GameCountdown> createState() => _GameCountdownState();
}

class _GameCountdownState extends State<GameCountdown>
    with SingleTickerProviderStateMixin {
  int _n = 3;
  late final AnimationController _ctrl = AnimationController(
      duration: const Duration(milliseconds: 800), vsync: this);
  late final Animation<double> _scaleAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.3).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(
        CurvedAnimation(parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _tick();
  }

  void _tick() async {
    while (_n > 0 && mounted) {
      GameHaptics.tap();
      _ctrl.forward(from: 0.0);
      await Future.delayed(const Duration(milliseconds: 850));
      if (!mounted) return;
      setState(() => _n--);
    }
    if (mounted) {
      GameHaptics.win();
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            GameTheme.bg(context),
            GameTheme.primary(context).withValues(alpha: 0.08),
          ],
        ),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final isLast = _n == 0;
            final color = isLast ? GameColors.successGreen : GameTheme.accent(context);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Glow ring
                Transform.scale(
                  scale: _scaleAnim.value * 1.5,
                  child: Container(
                    width: 30.w, height: 30.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.08 * _fadeAnim.value),
                      boxShadow: [
                        BoxShadow(
                            color: color.withValues(alpha: 0.3 * _fadeAnim.value),
                            blurRadius: 40, spreadRadius: 10),
                      ],
                    ),
                  ),
                ),
                // Number
                Opacity(
                  opacity: _fadeAnim.value.clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: _scaleAnim.value,
                    child: ShaderMask(
                      shaderCallback: (bounds) => LinearGradient(
                        colors: isLast
                            ? [const Color(0xFF00E676), const Color(0xFF00C853)]
                            : [const Color(0xFFFFD700), const Color(0xFFFF6D00)],
                      ).createShader(bounds),
                      child: Text(
                        _n > 0 ? '$_n' : 'GO!',
                        style: TextStyle(
                          fontSize: 72.sp,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ═══════════════════════ PREMIUM CONFETTI ═══════════════════════

class _ParticleConfetti {
  late double x, y, vx, vy, size, rot, vrot, opacity;
  late Color color;
  _ParticleConfetti(Random rng, List<Color> palette) {
    x = rng.nextDouble();
    y = -0.15 - rng.nextDouble() * 0.3;
    vx = (rng.nextDouble() - 0.5) * 0.006;
    vy = 0.004 + rng.nextDouble() * 0.008;
    size = 4 + rng.nextDouble() * 8;
    rot = rng.nextDouble() * pi * 2;
    vrot = (rng.nextDouble() - 0.5) * 0.3;
    opacity = 0.7 + rng.nextDouble() * 0.3;
    color = palette[rng.nextInt(palette.length)];
  }
  void step() { x += vx; y += vy; rot += vrot; opacity -= 0.003; vy += 0.0002; }
}

class _ConfettiPainter extends CustomPainter {
  final List<_ParticleConfetti> pieces;
  _ConfettiPainter(this.pieces);
  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      if (p.opacity <= 0.0) continue;
      final paint = Paint()
        ..color = p.color.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(p.x * size.width, p.y * size.height);
      canvas.rotate(p.rot);
      final w = p.size, h = p.size * 0.5;
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w, height: h), const Radius.circular(2)), paint);
      // Sparkle for some
      if (p.size > 7) {
        canvas.drawCircle(const Offset(0, 0), 2.0, Paint()..color = Colors.white.withValues(alpha: p.opacity * 0.6));
      }
      canvas.restore();
    }
  }
  @override
  bool shouldRepaint(covariant _ConfettiPainter old) => true;
}

class ConfettiOverlay extends StatefulWidget {
  final int count;
  const ConfettiOverlay({super.key, this.count = 80});
  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      duration: const Duration(seconds: 5), vsync: this);
  late final List<_ParticleConfetti> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final palette = [...GameColors.chakras, GameColors.gold, GameColors.successGreen];
    _pieces = List.generate(widget.count, (_) => _ParticleConfetti(rng, palette));
    _ctrl.addListener(() {
      for (final p in _pieces) { p.step(); }
      if (mounted) setState(() {});
    });
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _ConfettiPainter(_pieces), size: Size.infinite),
    );
  }
}

// ═══════════════════════ PREMIUM RESULTS SCREEN ═══════════════════════

class GameResultStat {
  final String label;
  final String value;
  const GameResultStat(this.label, this.value);
}

class GameResultsScreen extends StatefulWidget {
  final String gameIcon, title, scoreLabel;
  final double performance;
  final int score;
  final List<GameResultStat> stats;
  final bool isNewBest;
  final VoidCallback onRetry, onDone;
  const GameResultsScreen({
    super.key,
    required this.gameIcon,
    required this.title,
    required this.performance,
    required this.score,
    this.scoreLabel = 'Score',
    this.stats = const [],
    this.isNewBest = false,
    required this.onRetry,
    required this.onDone,
  });
  @override
  State<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _GameResultsScreenState extends State<GameResultsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1600), vsync: this);
  late final Animation<double> _scoreAnim;
  late final Animation<double> _starAnim;

  int get _stars => widget.performance >= 0.85 ? 3 : widget.performance >= 0.55 ? 2 : 1;
  bool get _celebrate => _stars == 3 || widget.isNewBest;

  @override
  void initState() {
    super.initState();
    _scoreAnim = CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic));
    _starAnim = CurvedAnimation(parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.elasticOut));
    _ctrl.forward();
    if (_celebrate) GameHaptics.win();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Background gradient
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [
                GameTheme.primary(context).withValues(alpha: 0.04),
                GameTheme.bg(context),
              ],
            ),
          ),
        ),
      ),
      // Content
      Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(6.w),
          child: AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon with glow
                FadeTransition(opacity: _scoreAnim,
                  child: Container(
                    width: 24.w, height: 24.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GameTheme.primary(context).withValues(alpha: 0.1),
                      boxShadow: [BoxShadow(color: GameTheme.accent(context).withValues(alpha: 0.3), blurRadius: 20)],
                    ),
                    child: Center(child: Text(widget.gameIcon, style: TextStyle(fontSize: 40.sp))),
                  ),
                ),
                SizedBox(height: 2.h),
                // Title
                Text(widget.title, style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: GameTheme.textPrimary(context), letterSpacing: 0.5)),
                // NEW BEST badge
                if (widget.isNewBest) ...[
                  SizedBox(height: 1.h),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0), duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (_, v, __) => Transform.scale(scale: v,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [BoxShadow(color: GameColors.gold.withValues(alpha: 0.5), blurRadius: 12)],
                        ),
                        child: Text('🏆 NEW BEST!', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: const Color(0xFF3D2200)))),
                    ),
                  ),
                ],
                SizedBox(height: 2.5.h),
                // Stars
                Row(mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i < _stars;
                    final t = (_starAnim.value * 3.0 - i.toDouble()).clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: active ? t : 1.0,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                        child: Icon(
                          active ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 44,
                          color: active ? GameColors.gold : GameTheme.textMuted(context),
                          shadows: active ? [Shadow(color: GameColors.gold.withValues(alpha: 0.6), blurRadius: 12)] : null,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 2.h),
                // Score with glow ring
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: widget.score.toDouble()),
                  duration: const Duration(milliseconds: 1200), curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Column(children: [
                    Text('${v.round()}', style: TextStyle(fontSize: 48.sp, fontWeight: FontWeight.w900, color: GameTheme.accent(context),
                        shadows: [Shadow(color: GameTheme.accent(context).withValues(alpha: 0.4), blurRadius: 20)])),
                    Text(widget.scoreLabel, style: TextStyle(fontSize: 12.sp, color: GameTheme.textMuted(context), letterSpacing: 1)),
                  ]),
                ),
                SizedBox(height: 3.h),
                // Stats
                if (widget.stats.isNotEmpty)
                  Row(
                    children: widget.stats.map((s) => Expanded(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1.w),
                        child: Container(
                          padding: EdgeInsets.all(3.w),
                          decoration: BoxDecoration(
                            color: GameTheme.primary(context).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                          ),
                          child: Column(children: [
                            Text(s.value, style: TextStyle(color: GameTheme.accent(context), fontSize: 16.sp, fontWeight: FontWeight.w800)),
                            SizedBox(height: 0.3.h),
                            Text(s.label, style: TextStyle(color: GameTheme.textMuted(context), fontSize: 10.sp, letterSpacing: 0.5)),
                          ]),
                        ),
                      ),
                    )).toList(),
                  ),
                SizedBox(height: 4.h),
                // Buttons
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () { GameHaptics.tap(); widget.onRetry(); },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GameTheme.primary(context),
                        side: BorderSide(color: GameTheme.primary(context).withValues(alpha: 0.4)),
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.replay_rounded, size: 18), SizedBox(width: 2.w),
                        Text('Retry', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () { GameHaptics.tap(); widget.onDone(); },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameTheme.primary(context),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.check_rounded, size: 18), SizedBox(width: 2.w),
                        Text('Done', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700)),
                      ]),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
      // Confetti overlay
      if (_celebrate) const ConfettiOverlay(),
    ]);
  }
}

// ═══════════════════════ PREMIUM START SCREEN ═══════════════════════

class GameStartScreen extends StatefulWidget {
  final String icon, title, description, buttonLabel;
  final Widget? preview;
  final VoidCallback onStart;
  const GameStartScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.preview,
    this.buttonLabel = 'Start',
    required this.onStart,
  });
  @override
  State<GameStartScreen> createState() => _GameStartScreenState();
}

class _GameStartScreenState extends State<GameStartScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(6.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon with animated entrance
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 800),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 30.w, height: 30.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        GameTheme.primary(context).withValues(alpha: 0.15),
                        GameTheme.accent(context).withValues(alpha: 0.08),
                      ],
                    ),
                    boxShadow: [BoxShadow(color: GameTheme.primary(context).withValues(alpha: 0.2), blurRadius: 24)],
                  ),
                  child: Center(child: Text(widget.icon, style: TextStyle(fontSize: 44.sp))),
                ),
              ),
              SizedBox(height: 3.h),
              // Title with letter spacing
              Text(widget.title, textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.w800,
                      color: GameTheme.textPrimary(context), letterSpacing: 0.5)),
              SizedBox(height: 1.5.h),
              // Description
              Text(widget.description, textAlign: TextAlign.center,
                  style: TextStyle(color: GameTheme.textSecondary(context), fontSize: 13.sp, height: 1.6, letterSpacing: 0.3)),
              // Preview
              if (widget.preview != null) ...[SizedBox(height: 2.5.h), widget.preview!],
              SizedBox(height: 3.5.h),
              // Gradient start button
              SizedBox(
                width: double.infinity, height: 54,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () { GameHaptics.tap(); widget.onStart(); },
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [GameTheme.primary(context), GameTheme.accent(context)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: GameTheme.primary(context).withValues(alpha: 0.4), blurRadius: 14, offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Center(
                        child: Text(widget.buttonLabel, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

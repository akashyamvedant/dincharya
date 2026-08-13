// lib/presentation/routine_dashboard/mind_games/widgets/game_shell.dart
// PREMIUM GAME SHELL v3 — Spring physics, particle confetti, glow effects,
// XP fly animation, progress bar, pause overlay, share results.
// Inspired by Lumosity + Peak + Elevate game screen patterns.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../../../../services/ads_service.dart';
import '../../../../core/constants/ad_constants.dart';

// ═══════════════════════ HAPTICS ═══════════════════════

class GameHaptics {
  GameHaptics._();
  static void tap() => HapticFeedback.selectionClick();
  static void correct() => HapticFeedback.lightImpact();
  static void wrong() => HapticFeedback.heavyImpact();
  static void win() => HapticFeedback.mediumImpact();
  static void levelUp() {
    HapticFeedback.mediumImpact();
    Future.delayed(
        const Duration(milliseconds: 100), () => HapticFeedback.heavyImpact());
  }
}

// ═══════════════════════ GAME PROGRESS BAR ═══════════════════════

/// Thin animated progress bar for in-game round tracking.
class GameProgressBar extends StatelessWidget {
  final int current;
  final int total;
  final Color? color;
  final bool showLabel;

  const GameProgressBar({
    super.key,
    required this.current,
    required this.total,
    this.color,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    final barColor = color ?? GameTheme.primary(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel)
          Padding(
            padding: EdgeInsets.only(bottom: 0.5.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Round $current/$total',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: GameTheme.textSecondary(context),
                  ),
                ),
                Text(
                  '${(progress * 100).round()}%',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: barColor,
                  ),
                ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: progress),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => LinearProgressIndicator(
              value: v,
              minHeight: 4,
              backgroundColor: barColor.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════ PAUSE OVERLAY ═══════════════════════

/// Full-screen pause overlay with resume/quit options.
class GamePauseOverlay extends StatelessWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final String gameName;

  const GamePauseOverlay({
    super.key,
    required this.onResume,
    required this.onQuit,
    this.gameName = 'Game',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
      ),
      child: Center(
        child: Container(
          margin: EdgeInsets.all(8.w),
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: GameTheme.isDark(context)
                ? const Color(0xFF2A2015)
                : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 16.w,
                height: 16.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: GameTheme.primary(context).withValues(alpha: 0.1),
                ),
                child: Icon(
                  Icons.pause_circle_rounded,
                  size: 36.sp,
                  color: GameTheme.primary(context),
                ),
              ),
              SizedBox(height: 2.5.h),
              Text(
                'Paused',
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.w800,
                  color: GameTheme.textPrimary(context),
                ),
              ),
              SizedBox(height: 0.5.h),
              Text(
                gameName,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: GameTheme.textSecondary(context),
                ),
              ),
              SizedBox(height: 4.h),
              // Resume button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    GameHaptics.tap();
                    onResume();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameTheme.primary(context),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.play_arrow_rounded, size: 20),
                      SizedBox(width: 2.w),
                      Text('Resume',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 1.5.h),
              // Quit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {
                    GameHaptics.tap();
                    onQuit();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GameColors.errorRed,
                    side: BorderSide(
                        color: GameColors.errorRed.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout_rounded, size: 18),
                      SizedBox(width: 2.w),
                      Text('Quit Game',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w600)),
                    ],
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
    _scaleAnim = Tween<double>(begin: 0.0, end: 1.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut));
    _fadeAnim = Tween<double>(begin: 1.0, end: 0.0).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
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
            final color =
                isLast ? GameColors.successGreen : GameTheme.accent(context);
            return Stack(
              alignment: Alignment.center,
              children: [
                // Glow ring
                Transform.scale(
                  scale: _scaleAnim.value * 1.5,
                  child: Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withValues(alpha: 0.08 * _fadeAnim.value),
                      boxShadow: [
                        BoxShadow(
                            color:
                                color.withValues(alpha: 0.3 * _fadeAnim.value),
                            blurRadius: 40,
                            spreadRadius: 10),
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
                            : [
                                const Color(0xFFFFD700),
                                const Color(0xFFFF6D00)
                              ],
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
  void step() {
    x += vx;
    y += vy;
    rot += vrot;
    opacity -= 0.003;
    vy += 0.0002;
  }
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
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: w, height: h),
              const Radius.circular(2)),
          paint);
      // Sparkle for some
      if (p.size > 7) {
        canvas.drawCircle(const Offset(0, 0), 2.0,
            Paint()..color = Colors.white.withValues(alpha: p.opacity * 0.6));
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
  late final AnimationController _ctrl =
      AnimationController(duration: const Duration(seconds: 5), vsync: this);
  late final List<_ParticleConfetti> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    final palette = [
      ...GameColors.chakras,
      GameColors.gold,
      GameColors.successGreen
    ];
    _pieces =
        List.generate(widget.count, (_) => _ParticleConfetti(rng, palette));
    _ctrl.addListener(() {
      for (final p in _pieces) {
        p.step();
      }
      if (mounted) setState(() {});
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child:
          CustomPaint(painter: _ConfettiPainter(_pieces), size: Size.infinite),
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
  final int xpEarned;
  final List<GameResultStat> stats;
  final bool isNewBest;
  final String? nextGameName;
  final VoidCallback? onNextGame;
  final VoidCallback onRetry, onDone;
  const GameResultsScreen({
    super.key,
    required this.gameIcon,
    required this.title,
    required this.performance,
    required this.score,
    this.scoreLabel = 'Score',
    this.xpEarned = 0,
    this.stats = const [],
    this.isNewBest = false,
    this.nextGameName,
    this.onNextGame,
    required this.onRetry,
    required this.onDone,
  });
  @override
  State<GameResultsScreen> createState() => _GameResultsScreenState();
}

class _GameResultsScreenState extends State<GameResultsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      duration: const Duration(milliseconds: 1600), vsync: this);
  late final Animation<double> _scoreAnim;
  late final Animation<double> _starAnim;
  late final AnimationController _xpCtrl = AnimationController(
      duration: const Duration(milliseconds: 1200), vsync: this);
  late final Animation<double> _xpSlide;
  late final Animation<double> _xpFade;

  int get _stars => widget.performance >= 0.85
      ? 3
      : widget.performance >= 0.55
          ? 2
          : 1;
  bool get _celebrate => _stars == 3 || widget.isNewBest;
  bool _doubleXpClaimed = false;
  bool _adRetryClaimed = false;

  @override
  void initState() {
    super.initState();
    _scoreAnim = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic));
    _starAnim = CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.3, 1.0, curve: Curves.elasticOut));
    _xpSlide = Tween<double>(begin: 40.0, end: 0.0)
        .animate(CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOutBack));
    _xpFade = CurvedAnimation(
        parent: _xpCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _ctrl.forward();
    // Delay XP animation for dramatic effect
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && widget.xpEarned > 0) _xpCtrl.forward();
    });
    if (_celebrate) GameHaptics.win();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _xpCtrl.dispose();
    super.dispose();
  }

  void _shareScore() {
    GameHaptics.tap();
    Share.share(
      '🧠 I scored ${widget.score} in ${widget.title} on Dincharya Mind Games! '
      '${_stars == 3 ? '⭐⭐⭐' : _stars == 2 ? '⭐⭐' : '⭐'} '
      'Brain training meets wellness. Try it! 🧘',
    );
  }

  // ═══ REWARDED AD: Double XP Button ═══
  Widget _buildDoubleXpButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.5.h),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: OutlinedButton(
          onPressed: () {
            GameHaptics.tap();
            AdsService().showRewardedAdForPlacement(
              RewardedPlacement.mindGameDoubleXp,
              onRewarded: () {
                if (mounted) {
                  setState(() => _doubleXpClaimed = true);
                  // Add bonus XP via service
                  MindGamesService().addXp(widget.xpEarned);
                  GameHaptics.win();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '🎉 +${widget.xpEarned} Bonus XP earned!',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      backgroundColor: GameColors.gold,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                }
              },
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: GameColors.gold,
            side: BorderSide(
                color: GameColors.gold.withValues(alpha: 0.5), width: 1.5),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: GameColors.gold.withValues(alpha: 0.08),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  size: 20, color: GameColors.gold),
              SizedBox(width: 2.w),
              Text('Watch Ad for 2x XP (+${widget.xpEarned})',
                  style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: GameColors.gold)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══ REWARDED AD: Retry Button ═══
  Widget _buildAdRetryButton(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: SizedBox(
        width: double.infinity,
        height: 44,
        child: TextButton(
          onPressed: () {
            GameHaptics.tap();
            AdsService().showRewardedAdForPlacement(
              RewardedPlacement.mindGameRetry,
              onRewarded: () {
                if (mounted) {
                  setState(() => _adRetryClaimed = true);
                  widget.onRetry();
                }
              },
            );
          },
          style: TextButton.styleFrom(
            foregroundColor: GameTheme.textSecondary(context),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline_rounded,
                  size: 16, color: GameTheme.textMuted(context)),
              SizedBox(width: 1.5.w),
              Text('Watch Ad to Retry',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                      color: GameTheme.textMuted(context))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // Background gradient
      Positioned.fill(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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
                FadeTransition(
                  opacity: _scoreAnim,
                  child: Container(
                    width: 24.w,
                    height: 24.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: GameTheme.primary(context).withValues(alpha: 0.1),
                      boxShadow: [
                        BoxShadow(
                            color: GameTheme.accent(context)
                                .withValues(alpha: 0.3),
                            blurRadius: 20)
                      ],
                    ),
                    child: Center(
                        child: Text(widget.gameIcon,
                            style: TextStyle(fontSize: 32.sp))),
                  ),
                ),
                SizedBox(height: 2.h),
                // Title
                Text(widget.title,
                    style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                        color: GameTheme.textPrimary(context),
                        letterSpacing: 0.5)),
                // NEW BEST badge
                if (widget.isNewBest) ...[
                  SizedBox(height: 1.h),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (_, v, __) => Transform.scale(
                      scale: v,
                      child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 4.w, vertical: 0.8.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                  color: GameColors.gold.withValues(alpha: 0.5),
                                  blurRadius: 12)
                            ],
                          ),
                          child: Text('🏆 NEW BEST!',
                              style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF3D2200)))),
                    ),
                  ),
                ],
                SizedBox(height: 2.5.h),
                // Stars
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (i) {
                    final active = i < _stars;
                    final t =
                        (_starAnim.value * 3.0 - i.toDouble()).clamp(0.0, 1.0);
                    return Transform.scale(
                      scale: active ? t : 1.0,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                        child: Icon(
                          active
                              ? Icons.star_rounded
                              : Icons.star_outline_rounded,
                          size: 44,
                          color: active
                              ? GameColors.gold
                              : GameTheme.textMuted(context),
                          shadows: active
                              ? [
                                  Shadow(
                                      color: GameColors.gold
                                          .withValues(alpha: 0.6),
                                      blurRadius: 12)
                                ]
                              : null,
                        ),
                      ),
                    );
                  }),
                ),
                SizedBox(height: 2.h),
                // Score with glow ring
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.0, end: widget.score.toDouble()),
                  duration: const Duration(milliseconds: 1200),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => Column(children: [
                    Text('${v.round()}',
                        style: TextStyle(
                            fontSize: 38.sp,
                            fontWeight: FontWeight.w900,
                            color: GameTheme.accent(context),
                            shadows: [
                              Shadow(
                                  color: GameTheme.accent(context)
                                      .withValues(alpha: 0.4),
                                  blurRadius: 20)
                            ])),
                    Text(widget.scoreLabel,
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: GameTheme.textMuted(context),
                            letterSpacing: 1)),
                  ]),
                ),
                SizedBox(height: 3.h),
                // Stats
                if (widget.stats.isNotEmpty)
                  Row(
                    children: widget.stats
                        .map((s) => Expanded(
                              child: Padding(
                                padding: EdgeInsets.symmetric(horizontal: 1.w),
                                child: Container(
                                  padding: EdgeInsets.all(3.w),
                                  decoration: BoxDecoration(
                                    color: GameTheme.primary(context)
                                        .withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.white
                                            .withValues(alpha: 0.06)),
                                  ),
                                  child: Column(children: [
                                    Text(s.value,
                                        style: TextStyle(
                                            color: GameTheme.accent(context),
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w800)),
                                    SizedBox(height: 0.3.h),
                                    Text(s.label,
                                        style: TextStyle(
                                            color: GameTheme.textMuted(context),
                                            fontSize: 10.sp,
                                            letterSpacing: 0.5)),
                                  ]),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                // XP Earned Badge
                if (widget.xpEarned > 0)
                  AnimatedBuilder(
                    animation: _xpCtrl,
                    builder: (_, __) => Transform.translate(
                      offset: Offset(0, _xpSlide.value),
                      child: Opacity(
                        opacity: _xpFade.value.clamp(0.0, 1.0),
                        child: Container(
                          margin: EdgeInsets.only(top: 2.h),
                          padding: EdgeInsets.symmetric(
                              horizontal: 5.w, vertical: 1.h),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                            ),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: GameColors.gold.withValues(alpha: 0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bolt_rounded,
                                  color: const Color(0xFF3D2200), size: 16.sp),
                              SizedBox(width: 1.5.w),
                              Text(
                                '+${widget.xpEarned} XP',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF3D2200),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 2.h),
                // ═══ REWARDED AD: 2x XP ═══
                if (widget.xpEarned > 0 && !_doubleXpClaimed)
                  _buildDoubleXpButton(context),
                // ═══ REWARDED AD: Watch Ad to Retry (low score only) ═══
                if (widget.performance < 0.5 && !_adRetryClaimed)
                  _buildAdRetryButton(context),
                SizedBox(height: 1.h),
                // Action buttons row
                Row(children: [
                  // Share button
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: GameTheme.primary(context).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: GameTheme.primary(context)
                              .withValues(alpha: 0.2)),
                    ),
                    child: IconButton(
                      onPressed: _shareScore,
                      icon: Icon(Icons.share_rounded,
                          size: 20, color: GameTheme.primary(context)),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        GameHaptics.tap();
                        widget.onRetry();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: GameTheme.primary(context),
                        side: BorderSide(
                            color: GameTheme.primary(context)
                                .withValues(alpha: 0.4)),
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.replay_rounded, size: 18),
                            SizedBox(width: 2.w),
                            Text('Retry',
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600)),
                          ]),
                    ),
                  ),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        GameHaptics.tap();
                        widget.onDone();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: GameTheme.primary(context),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.5.h),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_rounded, size: 18),
                            SizedBox(width: 2.w),
                            Text('Done',
                                style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700)),
                          ]),
                    ),
                  ),
                ]),
                // Next Game suggestion
                if (widget.nextGameName != null && widget.onNextGame != null)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: GestureDetector(
                      onTap: () {
                        GameHaptics.tap();
                        widget.onNextGame!();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            horizontal: 4.w, vertical: 1.5.h),
                        decoration: BoxDecoration(
                          color: GameTheme.primary(context)
                              .withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: GameTheme.primary(context)
                                  .withValues(alpha: 0.15)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.arrow_forward_rounded,
                                size: 16.sp, color: GameTheme.primary(context)),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                'Up Next: ${widget.nextGameName}',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: GameTheme.textSecondary(context),
                                ),
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded,
                                size: 18.sp,
                                color: GameTheme.textMuted(context)),
                          ],
                        ),
                      ),
                    ),
                  ),
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

// ═══════════════════════ COMBO INDICATOR ═══════════════════════

/// Floating combo/streak indicator shown during gameplay.
/// Displays "🔥 x5" with pulse animation when combo >= 3.
class GameComboIndicator extends StatefulWidget {
  final int combo;
  final bool visible;
  const GameComboIndicator(
      {super.key, required this.combo, this.visible = true});
  @override
  State<GameComboIndicator> createState() => _GameComboIndicatorState();
}

class _GameComboIndicatorState extends State<GameComboIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  int _prevCombo = 0;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 300), vsync: this);
  }

  @override
  void didUpdateWidget(GameComboIndicator old) {
    super.didUpdateWidget(old);
    if (widget.combo > _prevCombo && widget.combo >= 3) {
      _pulseCtrl.forward(from: 0.0);
      if (widget.combo % 5 == 0) GameHaptics.levelUp();
    }
    _prevCombo = widget.combo;
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || widget.combo < 2) return const SizedBox.shrink();
    final isHot = widget.combo >= 5;
    final isFire = widget.combo >= 10;
    final color = isFire
        ? const Color(0xFFFF1744)
        : isHot
            ? const Color(0xFFFF6D00)
            : GameColors.gold;
    final emoji = isFire
        ? '🔥'
        : isHot
            ? '⚡'
            : '✨';

    return AnimatedBuilder(
      animation: _pulseCtrl,
      builder: (_, child) => Transform.scale(
        scale: 1.0 +
            (_pulseCtrl.value < 0.5
                ? _pulseCtrl.value * 0.4
                : (1.0 - _pulseCtrl.value) * 0.4),
        child: child,
      ),
      child: AnimatedOpacity(
        opacity: widget.combo >= 2 ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.7.h),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              color.withValues(alpha: 0.2),
              color.withValues(alpha: 0.08),
            ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
            boxShadow: [
              BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: -2),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: TextStyle(fontSize: 14.sp)),
              SizedBox(width: 1.5.w),
              Text('x${widget.combo}',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w900,
                    color: color,
                    shadows: [
                      Shadow(color: color.withValues(alpha: 0.5), blurRadius: 6)
                    ],
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════ DIFFICULTY SELECTOR ═══════════════════════

enum GameDifficulty { easy, medium, hard }

/// Pre-game difficulty picker with earth-tone styling.
class GameDifficultySelector extends StatelessWidget {
  final GameDifficulty selected;
  final ValueChanged<GameDifficulty> onChanged;
  final String title;

  const GameDifficultySelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.title = 'Select Difficulty',
  });

  static const _options = [
    (GameDifficulty.easy, '🌱', 'Easy', 'Relaxed pace\nPerfect for beginners'),
    (GameDifficulty.medium, '🌿', 'Medium', 'Balanced challenge\nRecommended'),
    (GameDifficulty.hard, '🌳', 'Hard', 'Intense focus\nFor experts'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: GameTheme.textPrimary(context),
            )),
        SizedBox(height: 1.5.h),
        Row(
          children: _options.map((opt) {
            final (diff, emoji, label, desc) = opt;
            final sel = selected == diff;
            final color = diff == GameDifficulty.easy
                ? GameColors.easyGreen
                : diff == GameDifficulty.medium
                    ? GameColors.mediumAmber
                    : GameColors.hardRed;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                child: GestureDetector(
                  onTap: () {
                    GameHaptics.tap();
                    onChanged(diff);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    padding:
                        EdgeInsets.symmetric(vertical: 1.5.h, horizontal: 1.w),
                    decoration: BoxDecoration(
                      color: sel
                          ? color.withValues(alpha: 0.12)
                          : GameTheme.primary(context).withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: sel
                            ? color.withValues(alpha: 0.5)
                            : GameTheme.primary(context).withValues(alpha: 0.1),
                        width: sel ? 2 : 1,
                      ),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                  color: color.withValues(alpha: 0.15),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4))
                            ]
                          : null,
                    ),
                    child: Column(
                      children: [
                        Text(emoji, style: TextStyle(fontSize: 20.sp)),
                        SizedBox(height: 0.5.h),
                        Text(label,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w600,
                              color: sel
                                  ? color
                                  : GameTheme.textSecondary(context),
                            )),
                        SizedBox(height: 0.3.h),
                        Text(desc,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: GameTheme.textMuted(context),
                              height: 1.3,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ═══════════════════════ LIVE SCORE COUNTER ═══════════════════════

/// Animated score display for during gameplay.
class GameLiveScore extends StatelessWidget {
  final int score;
  final String label;
  final IconData icon;
  final Color? color;

  const GameLiveScore({
    super.key,
    required this.score,
    this.label = 'Score',
    this.icon = Icons.emoji_events_rounded,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? GameTheme.accent(context);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.6.h),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: c),
          SizedBox(width: 1.5.w),
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: score),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutCubic,
            builder: (_, v, __) => Text('$v',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: c,
                  fontFeatures: const [FontFeature.tabularFigures()],
                )),
          ),
          SizedBox(width: 1.w),
          Text(label,
              style: TextStyle(
                  fontSize: 10.sp, color: GameTheme.textMuted(context))),
        ],
      ),
    );
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
    _ctrl = AnimationController(
        duration: const Duration(milliseconds: 700), vsync: this);
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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
                builder: (_, v, child) =>
                    Transform.scale(scale: v, child: child),
                child: Container(
                  width: 30.w,
                  height: 30.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        GameTheme.primary(context).withValues(alpha: 0.15),
                        GameTheme.accent(context).withValues(alpha: 0.08),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                          color:
                              GameTheme.primary(context).withValues(alpha: 0.2),
                          blurRadius: 24)
                    ],
                  ),
                  child: Center(
                      child:
                          Text(widget.icon, style: TextStyle(fontSize: 34.sp))),
                ),
              ),
              SizedBox(height: 3.h),
              // Title with letter spacing
              Text(widget.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w800,
                      color: GameTheme.textPrimary(context),
                      letterSpacing: 0.5)),
              SizedBox(height: 1.5.h),
              // Description
              Text(widget.description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: GameTheme.textSecondary(context),
                      fontSize: 13.sp,
                      height: 1.6,
                      letterSpacing: 0.3)),
              // Preview
              if (widget.preview != null) ...[
                SizedBox(height: 2.5.h),
                widget.preview!
              ],
              SizedBox(height: 3.5.h),
              // Gradient start button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      GameHaptics.tap();
                      widget.onStart();
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            GameTheme.primary(context),
                            GameTheme.accent(context)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                              color: GameTheme.primary(context)
                                  .withValues(alpha: 0.4),
                              blurRadius: 14,
                              offset: const Offset(0, 6)),
                        ],
                      ),
                      child: Center(
                        child: Text(widget.buttonLabel,
                            style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: Colors.white)),
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

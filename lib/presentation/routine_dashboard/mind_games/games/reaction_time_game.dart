// lib/presentation/routine_dashboard/mind_games/games/reaction_time_game.dart
// Simple reaction time — Red → Green → TAP! 5 trials. Premium UI v3.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

enum RTP { wait, ready, go, soon, done }

class ReactionTimeGame extends StatefulWidget {
  const ReactionTimeGame({super.key});
  @override
  State<ReactionTimeGame> createState() => _ReactionTimeGameState();
}

class _ReactionTimeGameState extends State<ReactionTimeGame> {
  final _rng = Random(), _service = MindGamesService();
  final _sfx = GameSfxService();
  static const _trials = 5;

  RTP _p = RTP.wait;
  int _trial = 0, _best = 9999, _worst = 0, _total = 0;
  final List<int> _all = [];
  Timer? _timer;
  DateTime? _go;
  bool _isNewBest = false;
  int _xpEarned = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _trial = 0;
      _best = 9999;
      _worst = 0;
      _total = 0;
      _all.clear();
      _isNewBest = false;
    });
    _goTrial();
  }

  void _goTrial() {
    setState(() => _p = RTP.ready);
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: 1500 + _rng.nextInt(2500)), () {
      if (mounted) {
        setState(() => _p = RTP.go);
        _go = DateTime.now();
        GameHaptics.correct();
      }
    });
  }

  void _tap() {
    if (_p == RTP.ready) {
      _timer?.cancel();
      GameHaptics.wrong();
      _sfx.playWrong();
      setState(() => _p = RTP.soon);
      Timer(const Duration(seconds: 1), () {
        if (mounted) _goTrial();
      });
      return;
    }
    if (_p == RTP.go) {
      final rt = DateTime.now().difference(_go!).inMilliseconds;
      _all.add(rt);
      _total += rt;
      if (rt < _best) _best = rt;
      if (rt > _worst) _worst = rt;
      _trial++;
      GameHaptics.tap();
      if (_trial >= _trials) {
        _end();
      } else {
        _goTrial();
      }
    }
  }

  Future<void> _end() async {
    setState(() => _p = RTP.done);
    GameHaptics.win();
    _sfx.playWin();

    final avg = _total / _trials;
    final score = (1000 - avg).clamp(0.0, 1000.0);
    _xpEarned = 10 +
        (avg < 250
            ? 20
            : avg < 350
                ? 15
                : avg < 500
                    ? 10
                    : 5);

    await _service.saveScore(
      gameType: 'reaction_time',
      score: score,
      reactionTimeMs: avg.round(),
      roundsCompleted: _trials,
    );
    _isNewBest = await _service.submitLocalBest('reaction_time', score);
    await _service.addXp(_xpEarned);
    if (_isNewBest) _sfx.playNewBest();
    if (mounted) setState(() {});
  }

  Color _bg(BuildContext ctx) => _p == RTP.ready
      ? const Color(0xFFC62828)
      : _p == RTP.go
          ? const Color(0xFF2E7D32)
          : _p == RTP.soon
              ? const Color(0xFFE65100)
              : GameTheme.bg(ctx);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _p == RTP.wait ? _start : _tap,
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: _bg(context),
        appBar: _p == RTP.wait || _p == RTP.done
            ? AppBar(
                backgroundColor: GameTheme.bg(context),
                elevation: 0,
                leading: IconButton(
                  icon: Icon(Icons.arrow_back_rounded,
                      color: GameTheme.textPrimary(context)),
                  onPressed: () => Navigator.pop(context),
                ),
                title: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('⏱️', style: TextStyle(fontSize: 16.sp)),
                    SizedBox(width: 2.w),
                    Text('Reaction Time',
                        style: TextStyle(
                            color: GameTheme.textPrimary(context),
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                centerTitle: true,
              )
            : null,
        body: _p == RTP.wait
            ? _startScreen(context)
            : _p == RTP.done
                ? _resultScreen(context)
                : _playScreen(context),
      ),
    );
  }

  Widget _startScreen(BuildContext ctx) => GameStartScreen(
        icon: '⏱️',
        title: 'Reaction Time',
        description:
            'Wait for the screen to turn GREEN,\nthen TAP as fast as you can!\n\n$_trials trials · Tests neural speed',
        buttonLabel: 'Tap to Start',
        preview: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legendDot(ctx, const Color(0xFFC62828), 'Wait'),
            SizedBox(width: 4.w),
            _legendDot(ctx, const Color(0xFF2E7D32), 'TAP!'),
            SizedBox(width: 4.w),
            _legendDot(ctx, const Color(0xFFE65100), 'Too soon'),
          ],
        ),
        onStart: _start,
      );

  Widget _legendDot(BuildContext ctx, Color color, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(height: 0.5.h),
        Text(label,
            style: TextStyle(
                fontSize: 11.sp, color: GameTheme.textSecondary(ctx))),
      ],
    );
  }

  Widget _playScreen(BuildContext ctx) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Icon(
                _p == RTP.ready
                    ? Icons.hourglass_empty_rounded
                    : _p == RTP.go
                        ? Icons.touch_app_rounded
                        : Icons.warning_amber_rounded,
                key: ValueKey(_p),
                size: 80.sp,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              _p == RTP.ready
                  ? 'Wait for green...'
                  : _p == RTP.go
                      ? 'TAP NOW!'
                      : 'Too soon! 😅',
              style: TextStyle(
                fontSize: 32.sp,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                shadows: [
                  Shadow(
                      color: Colors.black.withValues(alpha: 0.3), blurRadius: 8)
                ],
              ),
            ),
            SizedBox(height: 2.h),
            // Trial indicator dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                  _trials,
                  (i) => Container(
                        margin: EdgeInsets.symmetric(horizontal: 1.w),
                        width: 3.w,
                        height: 3.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _trial
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.3),
                        ),
                      )),
            ),
            if (_all.isNotEmpty) ...[
              SizedBox(height: 3.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('Last: ${_all.last}ms',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      );

  Widget _resultScreen(BuildContext ctx) {
    final avg = _total ~/ _trials;
    final rating = avg < 250
        ? '⚡ Lightning fast!'
        : avg < 350
            ? '👍 Quick!'
            : avg < 500
                ? '🙂 Average'
                : '🐢 Room to improve';
    final performance = ((1000 - avg) / 1000).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '⏱️',
      title: rating,
      performance: performance,
      score: avg,
      scoreLabel: 'Avg (ms) · lower is better',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Best', '${_best}ms'),
        GameResultStat('Worst', '${_worst}ms'),
        GameResultStat('Trials', '$_trials'),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}

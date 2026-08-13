// lib/presentation/routine_dashboard/mind_games/games/quick_math_game.dart
// PREMIUM v3 — Rapid arithmetic. 15 problems. + → - → × → mix.
// Combo system, sound effects, premium results, animated feedback.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class QuickMathGame extends StatefulWidget {
  const QuickMathGame({super.key});
  @override
  State<QuickMathGame> createState() => _QuickMathGameState();
}

enum _Phase { start, countdown, playing, results }

class _QuickMathGameState extends State<QuickMathGame> {
  final _rng = Random(), _svc = MindGamesService();
  final _sfx = GameSfxService();
  static const _total = 15;

  int _q = 0, _ok = 0, _totalMs = 0, _combo = 0, _maxCombo = 0;
  int _a = 0, _b = 0, _ans = 0;
  String _op = '+';
  final _tc = TextEditingController();
  final _fn = FocusNode();
  _Phase _phase = _Phase.start;
  DateTime? _t;
  bool _isNewBest = false;
  int _xpEarned = 0;
  int _lastCorrect = -1;

  @override
  void dispose() {
    _tc.dispose();
    _fn.dispose();
    super.dispose();
  }

  void _start() {
    setState(() {
      _q = 0;
      _ok = 0;
      _totalMs = 0;
      _combo = 0;
      _maxCombo = 0;
      _isNewBest = false;
      _xpEarned = 0;
      _lastCorrect = -1;
      _phase = _Phase.countdown;
      _gen();
    });
  }

  void _gen() {
    final types = ['+', '-', '×'];
    _op = types[_rng.nextInt(types.length)];
    switch (_op) {
      case '+':
        _a = _rng.nextInt(50) + 10;
        _b = _rng.nextInt(50) + 5;
        _ans = _a + _b;
        break;
      case '-':
        _a = _rng.nextInt(80) + 20;
        _b = _rng.nextInt(_a);
        _ans = _a - _b;
        break;
      case '×':
        _a = _rng.nextInt(12) + 2;
        _b = _rng.nextInt(12) + 2;
        _ans = _a * _b;
        break;
    }
    _tc.clear();
    _t = DateTime.now();
    Future.delayed(const Duration(milliseconds: 100), () => _fn.requestFocus());
    setState(() {});
  }

  void _submit(String v) {
    if (_phase != _Phase.playing) return;
    final ms = DateTime.now().difference(_t!).inMilliseconds;
    _totalMs += ms;
    final parsed = int.tryParse(v.trim());
    final correct = parsed == _ans;
    if (correct) {
      _ok++;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      GameHaptics.correct();
      _sfx.playCorrect();
    } else {
      _combo = 0;
      GameHaptics.wrong();
      _sfx.playWrong();
    }
    _lastCorrect = correct ? 1 : 0;
    _q++;
    if (_q >= _total) {
      _finish();
      return;
    }
    _gen();
    Future.delayed(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _lastCorrect = -1);
    });
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.results);
    _fn.unfocus();
    GameHaptics.win();
    _sfx.playWin();

    final avg = _totalMs ~/ _total;
    final acc = _ok / _total;
    final score = (_ok * 100.0 / _total) + (_maxCombo * 3.0);
    _xpEarned = 10 +
        (acc * 20).round() +
        (avg < 3000 ? 5 : 0) +
        (_maxCombo >= 8 ? 5 : 0);

    await _svc.saveScore(
      gameType: 'quick_math',
      score: score,
      accuracy: acc,
      reactionTimeMs: avg,
      roundsCompleted: _total,
    );
    _isNewBest = await _svc.submitLocalBest('quick_math', score);
    await _svc.addXp(_xpEarned);
    if (_isNewBest) _sfx.playNewBest();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(
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
            Text('🔢', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 2.w),
            Text('Quick Math',
                style: TextStyle(
                    color: GameTheme.textPrimary(context),
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w700)),
          ],
        ),
        centerTitle: true,
      ),
      body: Stack(children: [
        if (_phase == _Phase.start) _startScreen(context),
        if (_phase == _Phase.countdown)
          GameCountdown(onDone: () => setState(() => _phase = _Phase.playing)),
        if (_phase == _Phase.playing) _gameScreen(context),
        if (_phase == _Phase.results) _resultScreen(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) => GameStartScreen(
        icon: '🔢',
        title: 'Quick Math',
        description:
            'Solve $_total arithmetic problems\nas fast as you can!\n\nAddition · Subtraction · Multiplication',
        buttonLabel: 'Start Solving',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Column(children: [
            Text('24 + 37 = ?',
                style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                    color: GameTheme.textPrimary(ctx))),
            SizedBox(height: 1.h),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.timer_outlined,
                  size: 14.sp, color: GameTheme.textMuted(ctx)),
              SizedBox(width: 1.5.w),
              Text('Speed matters — answer fast!',
                  style: TextStyle(
                      fontSize: 12.sp, color: GameTheme.textSecondary(ctx))),
            ]),
          ]),
        ),
        onStart: _start,
      );

  Widget _gameScreen(BuildContext ctx) => Column(children: [
        // Progress bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          child: GameProgressBar(current: _q + 1, total: _total),
        ),
        // Score + combo
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: GameColors.successGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: GameColors.successGreen.withValues(alpha: 0.2),
                      width: 0.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.check_circle_rounded,
                      size: 14.sp, color: GameColors.successGreen),
                  SizedBox(width: 1.5.w),
                  Text('$_ok',
                      style: TextStyle(
                          color: GameColors.successGreen,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              SizedBox(width: 3.w),
              GameComboIndicator(combo: _combo),
              SizedBox(width: 3.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                decoration: BoxDecoration(
                  color: GameTheme.primary(ctx).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: GameTheme.primary(ctx).withValues(alpha: 0.15),
                      width: 0.5),
                ),
                child: Text('${_q + 1}/$_total',
                    style: TextStyle(
                        color: GameTheme.textSecondary(ctx),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
        // Problem display
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Container(
                    key: ValueKey('$_q'),
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: _lastCorrect == 1
                          ? GameColors.successGreen.withValues(alpha: 0.06)
                          : _lastCorrect == 0
                              ? GameColors.errorRed.withValues(alpha: 0.06)
                              : GameTheme.primary(ctx).withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _lastCorrect == 1
                            ? GameColors.successGreen.withValues(alpha: 0.3)
                            : _lastCorrect == 0
                                ? GameColors.errorRed.withValues(alpha: 0.3)
                                : GameTheme.primary(ctx)
                                    .withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      '$_a $_op $_b = ?',
                      style: TextStyle(
                        color: GameTheme.textPrimary(ctx),
                        fontSize: 38.sp,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4.h),
                // Answer input
                SizedBox(
                  width: 50.w,
                  child: TextField(
                    controller: _tc,
                    focusNode: _fn,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GameTheme.textPrimary(ctx),
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w800,
                    ),
                    decoration: InputDecoration(
                      hintText: '?',
                      hintStyle: TextStyle(
                          color: GameTheme.textMuted(ctx), fontSize: 28.sp),
                      enabledBorder: UnderlineInputBorder(
                        borderSide: BorderSide(
                            color:
                                GameTheme.primary(ctx).withValues(alpha: 0.3),
                            width: 2),
                      ),
                      focusedBorder: UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: GameTheme.primary(ctx), width: 3),
                      ),
                    ),
                    onSubmitted: _submit,
                  ),
                ),
                SizedBox(height: 2.h),
                Text('Type answer & press Enter',
                    style: TextStyle(
                        fontSize: 11.sp, color: GameTheme.textMuted(ctx))),
              ],
            ),
          ),
        ),
      ]);

  Widget _resultScreen(BuildContext ctx) {
    final avg = _totalMs ~/ _total;
    final performance = (_ok / _total).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '🔢',
      title: 'Quick Math Complete!',
      performance: performance,
      score: (_ok * 100 ~/ _total) + (_maxCombo * 3),
      scoreLabel: 'Score',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Correct', '$_ok/$_total'),
        GameResultStat('Avg Speed', '${(avg / 1000).toStringAsFixed(1)}s'),
        GameResultStat('Max Combo', 'x$_maxCombo'),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}

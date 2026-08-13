// lib/presentation/routine_dashboard/mind_games/games/hand_gesture_switch.dart
// PREMIUM v3 — "एक हाथ में मुट्ठी, दूसरे में V — SWITCH!"
// User sees left-hand ✊ + right-hand ✌️. On switch → tap. Combo system.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class HandGestureSwitchGame extends StatefulWidget {
  const HandGestureSwitchGame({super.key});
  @override
  State<HandGestureSwitchGame> createState() => _HandGestureSwitchGameState();
}

enum _Phase { start, countdown, playing, results }

class _HandGestureSwitchGameState extends State<HandGestureSwitchGame> {
  final _rng = Random(), _svc = MindGamesService();
  final _sfx = GameSfxService();
  static const _rounds = 10;
  static const _gestures = ['✊', '✌️', '✋', '👆'];

  int _r = 0, _ok = 0, _totalMs = 0, _combo = 0, _maxCombo = 0;
  int _leftG = 0, _rightG = 1;
  bool _shouldSwitch = false;
  DateTime? _showTime;
  Timer? _switchTimer;
  _Phase _phase = _Phase.start;
  bool _isNewBest = false;
  int _xpEarned = 0;
  int _lastCorrect = -1;

  @override
  void dispose() {
    _switchTimer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _r = 0;
      _ok = 0;
      _totalMs = 0;
      _combo = 0;
      _maxCombo = 0;
      _isNewBest = false;
      _xpEarned = 0;
      _lastCorrect = -1;
      _phase = _Phase.countdown;
    });
  }

  void _beginPlay() {
    setState(() => _phase = _Phase.playing);
    _nextRound();
  }

  void _nextRound() {
    _leftG = _rng.nextInt(_gestures.length);
    do {
      _rightG = _rng.nextInt(_gestures.length);
    } while (_rightG == _leftG);
    _shouldSwitch = _rng.nextDouble() > 0.5;
    _showTime = DateTime.now();
    _lastCorrect = -1;
    setState(() {});

    if (_shouldSwitch) {
      _switchTimer?.cancel();
      final delay = 800 + _rng.nextInt(1200);
      _switchTimer = Timer(Duration(milliseconds: delay), () {
        if (mounted && _phase == _Phase.playing) {
          final t = _leftG;
          _leftG = _rightG;
          _rightG = t;
          setState(() {});
        }
      });
    }
  }

  void _tapSwitch() {
    if (_phase != _Phase.playing) return;
    final rt = DateTime.now().difference(_showTime!).inMilliseconds;
    _switchTimer?.cancel();
    _r++;

    if (_shouldSwitch) {
      _ok++;
      _totalMs += rt;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      GameHaptics.correct();
      _sfx.playCorrect();
      _lastCorrect = 1;
    } else {
      _combo = 0;
      GameHaptics.wrong();
      _sfx.playWrong();
      _lastCorrect = 0;
    }
    if (_r >= _rounds) {
      _finish();
    } else {
      _nextRound();
    }
  }

  void _tapWait() {
    if (_phase != _Phase.playing) return;
    _switchTimer?.cancel();
    _r++;

    if (!_shouldSwitch) {
      _ok++;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      GameHaptics.correct();
      _sfx.playCorrect();
      _lastCorrect = 1;
    } else {
      _combo = 0;
      GameHaptics.wrong();
      _sfx.playWrong();
      _lastCorrect = 0;
    }
    if (_r >= _rounds) {
      _finish();
    } else {
      _nextRound();
    }
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.results);
    _switchTimer?.cancel();
    GameHaptics.win();
    _sfx.playWin();

    final acc = _ok / _rounds;
    final avgMs = _ok > 0 ? _totalMs ~/ _ok : 0;
    final score = (_ok * 10.0) + (_maxCombo * 3.0);
    _xpEarned = 10 + (acc * 20).round() + (_maxCombo >= 7 ? 5 : 0);

    await _svc.saveScore(
      gameType: 'hand_gesture',
      score: score,
      accuracy: acc,
      reactionTimeMs: avgMs,
      roundsCompleted: _rounds,
    );
    _isNewBest = await _svc.submitLocalBest('hand_gesture', score);
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
            Text('🖐️', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 2.w),
            Text('Gesture Switch',
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
        if (_phase == _Phase.countdown) GameCountdown(onDone: _beginPlay),
        if (_phase == _Phase.playing) _gameScreen(context),
        if (_phase == _Phase.results) _resultScreen(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) => GameStartScreen(
        icon: '🖐️',
        title: 'Hand Gesture Switch',
        description:
            'Two hands show gestures.\nSometimes they SWITCH!\nTap SWITCH when they change, WAIT if they stay.\n\n$_rounds rounds · Tests bimanual coordination',
        buttonLabel: 'Start Game',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('✊', style: TextStyle(fontSize: 28.sp)),
              SizedBox(width: 3.w),
              Icon(Icons.swap_horiz_rounded,
                  size: 20.sp, color: GameTheme.accent(ctx)),
              SizedBox(width: 3.w),
              Text('✌️', style: TextStyle(fontSize: 28.sp)),
              SizedBox(width: 4.w),
              Text('→',
                  style: TextStyle(
                      fontSize: 18.sp, color: GameTheme.textMuted(ctx))),
              SizedBox(width: 2.w),
              Text('✌️', style: TextStyle(fontSize: 28.sp)),
              SizedBox(width: 3.w),
              Text('✊', style: TextStyle(fontSize: 28.sp)),
            ],
          ),
        ),
        onStart: _start,
      );

  Widget _gameScreen(BuildContext ctx) => Column(children: [
        // Progress bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          child: GameProgressBar(current: _r + 1, total: _rounds),
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
            ],
          ),
        ),
        // Hand display
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Feedback flash
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _lastCorrect == 1
                      ? Icon(Icons.check_circle_rounded,
                          key: const ValueKey('ok'),
                          size: 24.sp,
                          color: GameColors.successGreen)
                      : _lastCorrect == 0
                          ? Icon(Icons.cancel_rounded,
                              key: const ValueKey('no'),
                              size: 24.sp,
                              color: GameColors.errorRed)
                          : SizedBox(
                              key: const ValueKey('none'), height: 24.sp),
                ),
                SizedBox(height: 2.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Column(children: [
                      Text('LEFT',
                          style: TextStyle(
                              color: GameTheme.textSecondary(ctx),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                      SizedBox(height: 1.h),
                      _hand(ctx, _gestures[_leftG]),
                    ]),
                    SizedBox(width: 8.w),
                    Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: GameTheme.accent(ctx).withValues(alpha: 0.08),
                        border: Border.all(
                            color:
                                GameTheme.accent(ctx).withValues(alpha: 0.2)),
                      ),
                      child: Icon(Icons.swap_horiz_rounded,
                          size: 22.sp, color: GameTheme.accent(ctx)),
                    ),
                    SizedBox(width: 8.w),
                    Column(children: [
                      Text('RIGHT',
                          style: TextStyle(
                              color: GameTheme.textSecondary(ctx),
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1)),
                      SizedBox(height: 1.h),
                      _hand(ctx, _gestures[_rightG]),
                    ]),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Action buttons
        Padding(
          padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 5.h),
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: _tapSwitch,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 2.2.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [
                      GameColors.successGreen.withValues(alpha: 0.2),
                      GameColors.successGreen.withValues(alpha: 0.08),
                    ]),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: GameColors.successGreen.withValues(alpha: 0.5),
                        width: 2),
                    boxShadow: [
                      BoxShadow(
                          color:
                              GameColors.successGreen.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  child: Center(
                      child: Text('SWITCH! 🔄',
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                              color: GameColors.successGreen))),
                ),
              ),
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: GestureDetector(
                onTap: _tapWait,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 2.2.h),
                  decoration: BoxDecoration(
                    color: GameTheme.primary(ctx).withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: GameTheme.primary(ctx).withValues(alpha: 0.25),
                        width: 1.5),
                  ),
                  child: Center(
                      child: Text('WAIT ⏸️',
                          style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: GameTheme.textSecondary(ctx)))),
                ),
              ),
            ),
          ]),
        ),
      ]);

  Widget _hand(BuildContext ctx, String gesture) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutBack,
        width: 22.w,
        height: 22.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              GameTheme.accent(ctx).withValues(alpha: 0.12),
              GameTheme.accent(ctx).withValues(alpha: 0.04),
            ],
          ),
          border: Border.all(
              color: GameTheme.accent(ctx).withValues(alpha: 0.3), width: 2),
          boxShadow: [
            BoxShadow(
                color: GameTheme.accent(ctx).withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Center(child: Text(gesture, style: TextStyle(fontSize: 36.sp))),
      );

  Widget _resultScreen(BuildContext ctx) {
    final acc = (_ok / _rounds * 100).round();
    final avgMs = _ok > 0 ? _totalMs ~/ _ok : 0;
    final performance = (_ok / _rounds).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '🖐️',
      title: 'Gesture Switch Complete!',
      performance: performance,
      score: (_ok * 10 + _maxCombo * 3),
      scoreLabel: 'Score',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '$acc%'),
        GameResultStat('Avg Speed', '${avgMs}ms'),
        GameResultStat('Max Combo', 'x$_maxCombo'),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}

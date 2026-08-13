// lib/presentation/routine_dashboard/mind_games/games/speed_match_game.dart
// PREMIUM v3 — Rapid visual comparison: SAME or DIFFERENT? 20 rounds.
// Spring animations, combo system, sound effects, premium results.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class SpeedMatchGame extends StatefulWidget {
  const SpeedMatchGame({super.key});
  @override
  State<SpeedMatchGame> createState() => _SpeedMatchGameState();
}

enum _Phase { start, countdown, playing, results }

class _SpeedMatchGameState extends State<SpeedMatchGame> {
  final _rng = Random(), _service = MindGamesService();
  final _sfx = GameSfxService();
  static const _total = 20;
  static const _syms = ['★', '●', '◆', '▲', '⬟', '⬢', '✿', '❖', '♣', '♥'];

  int _r = 0, _ok = 0, _ng = 0, _rt = 0, _combo = 0, _maxCombo = 0;
  bool _same = false;
  String _l = '', _ri = '';
  DateTime? _t;
  _Phase _phase = _Phase.start;
  bool _isNewBest = false;
  int _xpEarned = 0;
  int _lastCorrect = -1; // Flash feedback: 1=correct, 0=wrong, -1=none

  void _start() {
    setState(() {
      _r = 0;
      _ok = 0;
      _ng = 0;
      _rt = 0;
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
    _same = _rng.nextBool();
    final s = _syms[_rng.nextInt(_syms.length)];
    _l = s;
    _ri = _same
        ? s
        : _syms.where((x) => x != s).toList()[_rng.nextInt(_syms.length - 1)];
    _t = DateTime.now();
  }

  void _ans(bool u) {
    if (_phase != _Phase.playing) return;
    final ms = DateTime.now().difference(_t!).inMilliseconds;
    _rt += ms;
    final correct = u == _same;
    if (correct) {
      _ok++;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      GameHaptics.correct();
      _sfx.playCorrect();
    } else {
      _ng++;
      _combo = 0;
      GameHaptics.wrong();
      _sfx.playWrong();
    }
    _lastCorrect = correct ? 1 : 0;
    _r++;
    if (_r >= _total) {
      _finish();
      return;
    }
    _gen();
    setState(() {});
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _lastCorrect = -1);
    });
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.results);
    GameHaptics.win();
    _sfx.playWin();

    final acc = _ok / _total;
    final avgRT = _rt ~/ _total;
    final score = (_ok * 5.0) + (_maxCombo * 2.0);
    _xpEarned = 10 +
        (acc * 20).round() +
        (avgRT < 600 ? 5 : 0) +
        (_maxCombo >= 10 ? 5 : 0);

    await _service.saveScore(
      gameType: 'speed_match',
      score: score,
      accuracy: acc,
      reactionTimeMs: avgRT,
      roundsCompleted: _total,
    );
    _isNewBest = await _service.submitLocalBest('speed_match', score);
    await _service.addXp(_xpEarned);
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
            Text('⚡', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 2.w),
            Text('Speed Match',
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
        icon: '⚡',
        title: 'Speed Match',
        description:
            'Two symbols appear — are they\nthe SAME or DIFFERENT?\n\n$_total rounds · Tests visual processing speed',
        buttonLabel: 'Start Match',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('★',
                  style: TextStyle(
                      fontSize: 32.sp, color: GameTheme.textPrimary(ctx))),
              SizedBox(width: 4.w),
              Icon(Icons.help_outline_rounded,
                  size: 20.sp, color: GameTheme.textMuted(ctx)),
              SizedBox(width: 4.w),
              Text('★',
                  style: TextStyle(
                      fontSize: 32.sp, color: GameTheme.textPrimary(ctx))),
              SizedBox(width: 3.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.4.h),
                decoration: BoxDecoration(
                  color: GameColors.successGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: GameColors.successGreen.withValues(alpha: 0.3)),
                ),
                child: Text('SAME',
                    style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: GameColors.successGreen)),
              ),
            ],
          ),
        ),
        onStart: _start,
      );

  Widget _gameScreen(BuildContext ctx) {
    return Column(children: [
      // Progress bar
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        child: GameProgressBar(current: _r + 1, total: _total),
      ),
      // Score + combo row
      Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _chip(ctx, Icons.check_circle_rounded, '$_ok',
                GameColors.successGreen),
            SizedBox(width: 3.w),
            GameComboIndicator(combo: _combo),
            SizedBox(width: 3.w),
            _chip(ctx, Icons.cancel_rounded, '$_ng', GameColors.errorRed),
          ],
        ),
      ),
      // Symbol display
      Expanded(
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Container(
              key: ValueKey('$_r'),
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: _lastCorrect == 1
                    ? GameColors.successGreen.withValues(alpha: 0.06)
                    : _lastCorrect == 0
                        ? GameColors.errorRed.withValues(alpha: 0.06)
                        : GameTheme.primary(ctx).withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: _lastCorrect == 1
                      ? GameColors.successGreen.withValues(alpha: 0.3)
                      : _lastCorrect == 0
                          ? GameColors.errorRed.withValues(alpha: 0.3)
                          : GameTheme.primary(ctx).withValues(alpha: 0.12),
                  width: 1.5,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_l,
                        style: TextStyle(
                            fontSize: 40.sp,
                            color: GameTheme.textPrimary(ctx))),
                    SizedBox(width: 5.w),
                    Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: GameTheme.primary(ctx).withValues(alpha: 0.06),
                        border: Border.all(
                            color:
                                GameTheme.primary(ctx).withValues(alpha: 0.15)),
                      ),
                      child: Icon(Icons.compare_arrows_rounded,
                          size: 16.sp, color: GameTheme.textMuted(ctx)),
                    ),
                    SizedBox(width: 5.w),
                    Text(_ri,
                        style: TextStyle(
                            fontSize: 40.sp,
                            color: GameTheme.textPrimary(ctx))),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      // Answer buttons
      Padding(
        padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 5.h),
        child: Row(children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _ans(true),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2.2.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GameColors.successGreen.withValues(alpha: 0.2),
                      GameColors.successGreen.withValues(alpha: 0.08)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: GameColors.successGreen.withValues(alpha: 0.5),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: GameColors.successGreen.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: Text('SAME ✓',
                      style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: GameColors.successGreen)),
                ),
              ),
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: GestureDetector(
              onTap: () => _ans(false),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 2.2.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      GameColors.errorRed.withValues(alpha: 0.15),
                      GameColors.errorRed.withValues(alpha: 0.05)
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: GameColors.errorRed.withValues(alpha: 0.4),
                      width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: GameColors.errorRed.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ],
                ),
                child: Center(
                  child: Text('DIFFERENT ✗',
                      style: TextStyle(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                          color: GameColors.errorRed)),
                ),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _chip(BuildContext ctx, IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 1.5.w),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 13.sp, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final acc = (_ok / _total * 100).round();
    final avgRT = _rt ~/ _total;
    final performance = (_ok / _total).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '⚡',
      title: 'Speed Match Complete!',
      performance: performance,
      score: (_ok * 5 + _maxCombo * 2),
      scoreLabel: 'Score',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '$acc%'),
        GameResultStat('Avg Speed', '${avgRT}ms'),
        GameResultStat('Max Combo', 'x$_maxCombo'),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}

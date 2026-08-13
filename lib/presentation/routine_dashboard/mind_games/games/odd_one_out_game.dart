// lib/presentation/routine_dashboard/mind_games/games/odd_one_out_game.dart
// PREMIUM v3 — Grid of similar items, find the different one. 10 rounds.
// Increasing grid size, combo system, sound effects, premium results.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class OddOneOutGame extends StatefulWidget {
  const OddOneOutGame({super.key});
  @override
  State<OddOneOutGame> createState() => _OddOneOutGameState();
}

enum _Phase { start, countdown, playing, results }

class _OddOneOutGameState extends State<OddOneOutGame> {
  final _rng = Random(), _svc = MindGamesService();
  final _sfx = GameSfxService();
  static const _rounds = 10;
  static const _gridSizes = [9, 12, 16, 20, 25];

  int _r = 0, _ok = 0, _totalMs = 0, _gridSize = 9, _combo = 0, _maxCombo = 0;
  List<bool> _items = [];
  DateTime? _roundStart;
  _Phase _phase = _Phase.start;
  bool _isNewBest = false;
  int _xpEarned = 0;
  int _wrongTap = -1; // Index of wrong tap for flash

  void _start() {
    setState(() {
      _r = 0;
      _ok = 0;
      _totalMs = 0;
      _combo = 0;
      _maxCombo = 0;
      _isNewBest = false;
      _xpEarned = 0;
      _wrongTap = -1;
      _phase = _Phase.countdown;
      _genRound();
    });
  }

  void _genRound() {
    _gridSize = _gridSizes[min(_r, _gridSizes.length - 1)];
    final oddIdx = _rng.nextInt(_gridSize);
    _items = List.generate(_gridSize, (i) => i == oddIdx);
    _roundStart = DateTime.now();
    setState(() {});
  }

  void _tap(int i) {
    if (_phase != _Phase.playing) return;
    final ms = DateTime.now().difference(_roundStart!).inMilliseconds;
    _totalMs += ms;
    if (_items[i]) {
      _ok++;
      _combo++;
      if (_combo > _maxCombo) _maxCombo = _combo;
      GameHaptics.correct();
      _sfx.playCorrect();
      _r++;
      if (_r >= _rounds) {
        _finish();
        return;
      }
      _genRound();
    } else {
      _combo = 0;
      GameHaptics.wrong();
      _sfx.playWrong();
      setState(() => _wrongTap = i);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _wrongTap = -1);
      });
    }
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.results);
    GameHaptics.win();
    _sfx.playWin();

    final acc = _ok / _rounds;
    final avg = _totalMs ~/ _rounds;
    final score = (_ok * 10.0) + (_maxCombo * 3.0);
    _xpEarned = 10 +
        (acc * 20).round() +
        (avg < 1500 ? 5 : 0) +
        (_maxCombo >= 7 ? 5 : 0);

    await _svc.saveScore(
      gameType: 'odd_one_out',
      score: score,
      accuracy: acc,
      reactionTimeMs: avg,
      roundsCompleted: _rounds,
    );
    _isNewBest = await _svc.submitLocalBest('odd_one_out', score);
    await _svc.addXp(_xpEarned);
    if (_isNewBest) _sfx.playNewBest();
    if (mounted) setState(() {});
  }

  int _cols() => _gridSize <= 9
      ? 3
      : _gridSize <= 16
          ? 4
          : 5;

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
            Text('🔍', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 2.w),
            Text('Odd One Out',
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
        icon: '🔍',
        title: 'Odd One Out',
        description:
            'Find the different item in the grid.\n$_rounds rounds · Grid grows each round!\n\nTests visual perception & scanning',
        buttonLabel: 'Start Search',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Column(children: [
            Text('🔴 🔴 🔵 🔴', style: TextStyle(fontSize: 22.sp)),
            SizedBox(height: 1.h),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.touch_app_rounded,
                  size: 14.sp, color: GameTheme.textMuted(ctx)),
              SizedBox(width: 1.5.w),
              Text('Tap the odd one!',
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: GameTheme.textSecondary(ctx),
                      fontWeight: FontWeight.w600)),
            ]),
          ]),
        ),
        onStart: _start,
      );

  Widget _gameScreen(BuildContext ctx) => Padding(
        padding: EdgeInsets.all(3.w),
        child: Column(children: [
          // Progress bar
          Padding(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            child: GameProgressBar(current: _r + 1, total: _rounds),
          ),
          // Score + combo
          Row(
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
                child: Text('$_gridSize items',
                    style: TextStyle(
                        color: GameTheme.textSecondary(ctx),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          // Grid
          Expanded(
            child: GridView.count(
              crossAxisCount: _cols(),
              mainAxisSpacing: 2.w,
              crossAxisSpacing: 2.w,
              children: List.generate(_gridSize, (i) {
                final isWrong = _wrongTap == i;
                return GestureDetector(
                  onTap: () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isWrong
                          ? GameColors.errorRed.withValues(alpha: 0.2)
                          : GameTheme.primary(ctx).withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWrong
                            ? GameColors.errorRed.withValues(alpha: 0.5)
                            : GameTheme.primary(ctx).withValues(alpha: 0.12),
                        width: isWrong ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _items[i] ? '★' : '●',
                        style: TextStyle(
                          fontSize: _gridSize > 16 ? 16.sp : 20.sp,
                          color: _items[i]
                              ? GameTheme.accent(ctx)
                              : GameTheme.textPrimary(ctx)
                                  .withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ]),
      );

  Widget _resultScreen(BuildContext ctx) {
    final acc = (_ok / _rounds * 100).round();
    final avg = _totalMs ~/ _rounds;
    final performance = (_ok / _rounds).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '🔍',
      title: 'Odd One Out Complete!',
      performance: performance,
      score: (_ok * 10 + _maxCombo * 3),
      scoreLabel: 'Score',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '$acc%'),
        GameResultStat('Avg Speed', '${avg}ms'),
        GameResultStat('Max Combo', 'x$_maxCombo'),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}

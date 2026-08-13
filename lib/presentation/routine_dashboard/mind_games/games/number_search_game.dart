// lib/presentation/routine_dashboard/mind_games/games/number_search_game.dart
// PREMIUM v3 — 5×5 grid. Find numbers 1→25 in order as fast as possible.
// Premium shell, sound effects, animated grid, live timer.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class NumberSearchGame extends StatefulWidget {
  const NumberSearchGame({super.key});
  @override
  State<NumberSearchGame> createState() => _NumberSearchGameState();
}

enum _Phase { start, countdown, playing, results }

class _NumberSearchGameState extends State<NumberSearchGame> {
  final _rng = Random(), _service = MindGamesService();
  final _sfx = GameSfxService();
  late List<int> _grid = List.generate(25, (i) => i + 1);
  int _next = 1, _correct = 0, _wrong = 0;
  _Phase _phase = _Phase.start;
  final _sw = Stopwatch();
  int _finalMs = 0;
  bool _isNewBest = false;
  int _xpEarned = 0;
  Timer? _uiTimer;
  int _elapsedMs = 0;
  int _wrongFlash = -1; // Grid index that was wrong-tapped

  @override
  void dispose() {
    _uiTimer?.cancel();
    super.dispose();
  }

  void _start() {
    _grid = List.generate(25, (i) => i + 1)..shuffle(_rng);
    setState(() {
      _next = 1;
      _correct = 0;
      _wrong = 0;
      _elapsedMs = 0;
      _isNewBest = false;
      _xpEarned = 0;
      _wrongFlash = -1;
      _phase = _Phase.countdown;
    });
  }

  void _beginPlay() {
    setState(() => _phase = _Phase.playing);
    _sw
      ..reset()
      ..start();
    _uiTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (mounted) setState(() => _elapsedMs = _sw.elapsedMilliseconds);
    });
  }

  void _tap(int n, int idx) {
    if (_phase != _Phase.playing) return;
    if (n == _next) {
      _correct++;
      GameHaptics.correct();
      _sfx.playCorrect();
      if (_next >= 25) {
        _sw.stop();
        _finalMs = _sw.elapsedMilliseconds;
        _uiTimer?.cancel();
        _finish();
        return;
      }
      _next++;
      setState(() {});
    } else {
      _wrong++;
      GameHaptics.wrong();
      _sfx.playWrong();
      setState(() => _wrongFlash = idx);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _wrongFlash = -1);
      });
    }
  }

  Future<void> _finish() async {
    setState(() => _phase = _Phase.results);
    GameHaptics.win();
    _sfx.playWin();

    final timeSec = _finalMs / 1000.0;
    final acc = _correct > 0 ? _correct / (_correct + _wrong) : 0.0;
    final score =
        (100 - timeSec).clamp(0.0, 100.0) + (_wrong == 0 ? 20.0 : 0.0);
    _xpEarned = 10 +
        (_wrong == 0
            ? 15
            : _wrong < 3
                ? 10
                : 5) +
        (timeSec < 20
            ? 10
            : timeSec < 35
                ? 5
                : 0);

    await _service.saveScore(
      gameType: 'number_search',
      score: timeSec,
      accuracy: acc,
      reactionTimeMs: _finalMs,
      roundsCompleted: _correct,
    );
    // Lower is better for this game
    _isNewBest = await _service.submitLocalBest('number_search', score);
    await _service.addXp(_xpEarned);
    if (_isNewBest) _sfx.playNewBest();
    if (mounted) setState(() {});
  }

  String _fmt(int ms) {
    final s = ms ~/ 1000;
    final d = (ms % 1000) ~/ 100;
    return '$s.${d}s';
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
            Text('Number Search',
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
        icon: '🔢',
        title: 'Number Search',
        description:
            'Find numbers 1→25 in order\non a shuffled 5×5 grid.\n\nTap as fast as you can! · Tests scanning speed',
        buttonLabel: 'Start Search',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _miniCell(ctx, '1', true),
              _miniCell(ctx, '14', false),
              _miniCell(ctx, '7', false),
              _miniCell(ctx, '22', false),
            ]),
            SizedBox(height: 1.h),
            Text('Find 1, then 2, then 3...',
                style: TextStyle(
                    fontSize: 12.sp, color: GameTheme.textSecondary(ctx))),
          ]),
        ),
        onStart: _start,
      );

  Widget _miniCell(BuildContext ctx, String n, bool highlight) {
    return Container(
      width: 10.w,
      height: 10.w,
      margin: EdgeInsets.symmetric(horizontal: 1.w),
      decoration: BoxDecoration(
        color: highlight
            ? GameTheme.accent(ctx).withValues(alpha: 0.15)
            : GameTheme.primary(ctx).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: highlight
                ? GameTheme.accent(ctx).withValues(alpha: 0.5)
                : GameTheme.primary(ctx).withValues(alpha: 0.12)),
      ),
      child: Center(
          child: Text(n,
              style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: highlight ? FontWeight.w800 : FontWeight.w500,
                  color: highlight
                      ? GameTheme.accent(ctx)
                      : GameTheme.textPrimary(ctx).withValues(alpha: 0.6)))),
    );
  }

  Widget _gameScreen(BuildContext ctx) => Column(children: [
        // Timer + next number header
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Next number to find
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    GameTheme.accent(ctx).withValues(alpha: 0.15),
                    GameTheme.accent(ctx).withValues(alpha: 0.05),
                  ]),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: GameTheme.accent(ctx).withValues(alpha: 0.4),
                      width: 1.5),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Find: ',
                      style: TextStyle(
                          fontSize: 13.sp,
                          color: GameTheme.textSecondary(ctx),
                          fontWeight: FontWeight.w500)),
                  Text('$_next',
                      style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: GameTheme.accent(ctx))),
                ]),
              ),
              // Live timer
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 0.8.h),
                decoration: BoxDecoration(
                  color: GameTheme.primary(ctx).withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: GameTheme.primary(ctx).withValues(alpha: 0.15)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.timer_outlined,
                      size: 14.sp, color: GameTheme.textSecondary(ctx)),
                  SizedBox(width: 1.5.w),
                  Text(_fmt(_elapsedMs),
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: GameTheme.textPrimary(ctx),
                        fontFeatures: const [FontFeature.tabularFigures()],
                      )),
                ]),
              ),
            ],
          ),
        ),
        // Progress
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w),
          child:
              GameProgressBar(current: _correct, total: 25, showLabel: false),
        ),
        SizedBox(height: 1.5.h),
        // Grid
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(3.w),
            child: GridView.count(
              crossAxisCount: 5,
              mainAxisSpacing: 1.5.w,
              crossAxisSpacing: 1.5.w,
              children: List.generate(25, (i) {
                final n = _grid[i];
                final done = n < _next;
                final isNext = n == _next;
                final isWrong = _wrongFlash == i;
                return GestureDetector(
                  onTap: done ? null : () => _tap(n, i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isWrong
                          ? GameColors.errorRed.withValues(alpha: 0.2)
                          : done
                              ? GameColors.successGreen.withValues(alpha: 0.12)
                              : isNext
                                  ? GameTheme.accent(ctx).withValues(alpha: 0.1)
                                  : GameTheme.primary(ctx)
                                      .withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isWrong
                            ? GameColors.errorRed.withValues(alpha: 0.6)
                            : done
                                ? GameColors.successGreen.withValues(alpha: 0.4)
                                : isNext
                                    ? GameTheme.accent(ctx)
                                        .withValues(alpha: 0.6)
                                    : GameTheme.primary(ctx)
                                        .withValues(alpha: 0.1),
                        width: isNext
                            ? 2.5
                            : isWrong
                                ? 2
                                : 1,
                      ),
                      boxShadow: isNext
                          ? [
                              BoxShadow(
                                  color: GameTheme.accent(ctx)
                                      .withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2))
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        done ? '✓' : '$n',
                        style: TextStyle(
                          color: done
                              ? GameColors.successGreen
                              : isNext
                                  ? GameTheme.accent(ctx)
                                  : GameTheme.textPrimary(ctx)
                                      .withValues(alpha: 0.6),
                          fontSize: 16.sp,
                          fontWeight:
                              isNext ? FontWeight.w900 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        // Wrong taps indicator
        if (_wrong > 0)
          Padding(
            padding: EdgeInsets.only(bottom: 2.h),
            child: Text('$_wrong misses',
                style: TextStyle(
                    fontSize: 11.sp,
                    color: GameColors.errorRed,
                    fontWeight: FontWeight.w600)),
          ),
      ]);

  Widget _resultScreen(BuildContext ctx) {
    final timeSec = _finalMs / 1000.0;
    final performance = (1.0 - (timeSec / 60.0)).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '🔢',
      title: _wrong == 0 ? '🎯 Perfect Run!' : 'Number Search Complete!',
      performance: performance,
      score: _finalMs ~/ 1000,
      scoreLabel: 'Time (seconds) · lower is better',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Time', '${timeSec.toStringAsFixed(1)}s'),
        GameResultStat('Found', '$_correct/25'),
        GameResultStat('Misses', '$_wrong'),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}

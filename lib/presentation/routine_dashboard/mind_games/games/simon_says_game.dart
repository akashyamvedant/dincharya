// lib/presentation/routine_dashboard/mind_games/games/simon_says_game.dart
// PREMIUM v3 — 4 colored circles. App blinks sequence. User repeats. Grows each round.
// Sound effects, glow animations, premium results, combo tracking.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../game_sfx_service.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class SimonSaysGame extends StatefulWidget {
  const SimonSaysGame({super.key});
  @override
  State<SimonSaysGame> createState() => _SimonSaysGameState();
}

enum _Phase { start, countdown, playing, results }

class _SimonSaysGameState extends State<SimonSaysGame> {
  final _rng = Random(), _svc = MindGamesService();
  final _sfx = GameSfxService();
  final _colors = GameColors.simon;
  final List<int> _seq = [];
  int _playerIdx = 0, _round = 0, _best = 0;
  bool _showing = false;
  int? _highlighted;
  _Phase _phase = _Phase.start;
  bool _isNewBest = false;
  int _xpEarned = 0;

  void _start() {
    setState(() {
      _seq.clear();
      _round = 0;
      _best = 0;
      _isNewBest = false;
      _xpEarned = 0;
      _phase = _Phase.countdown;
    });
  }

  void _beginPlay() {
    setState(() => _phase = _Phase.playing);
    _addAndShow();
  }

  void _addAndShow() {
    _seq.add(_rng.nextInt(4));
    _playerIdx = 0;
    _showing = true;
    setState(() {});
    Future.delayed(const Duration(milliseconds: 600), () => _playSeq());
  }

  void _playSeq() async {
    for (final c in _seq) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _highlighted = c);
      GameHaptics.tap();
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _highlighted = null);
    }
    setState(() => _showing = false);
  }

  void _tap(int i) {
    if (_showing || _phase != _Phase.playing) return;
    if (i != _seq[_playerIdx]) {
      GameHaptics.wrong();
      _sfx.playWrong();
      _finish();
      return;
    }
    GameHaptics.correct();
    _sfx.playCorrect();
    setState(() => _highlighted = i);
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) setState(() => _highlighted = null);
    });
    _playerIdx++;
    _round++;
    if (_playerIdx >= _seq.length) {
      final max = _seq.length;
      setState(() {
        if (max > _best) _best = max;
      });
      GameHaptics.win();
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted && _phase == _Phase.playing) _addAndShow();
      });
    }
  }

  Future<void> _finish() async {
    setState(() {
      _phase = _Phase.results;
      if (_seq.length - 1 > _best) _best = _seq.length - 1;
    });
    GameHaptics.win();
    _sfx.playWin();

    final score = _best * 10.0;
    _xpEarned = 10 +
        (_best >= 10
            ? 20
            : _best >= 7
                ? 15
                : _best >= 5
                    ? 10
                    : 5);

    await _svc.saveScore(
      gameType: 'simon_says',
      score: score,
      roundsCompleted: _best,
    );
    _isNewBest = await _svc.submitLocalBest('simon_says', score);
    await _svc.addXp(_xpEarned);
    if (_isNewBest) _sfx.playNewBest();
    if (mounted) setState(() {});
  }

  Color _color(int i) =>
      _highlighted == i ? _colors[i] : _colors[i].withValues(alpha: 0.25);

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
            Text('🎵', style: TextStyle(fontSize: 16.sp)),
            SizedBox(width: 2.w),
            Text('Simon Says',
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
        icon: '🎵',
        title: 'Simon Says',
        description:
            'Watch the color sequence.\nRepeat it by tapping the colors.\nEach round adds one more!\n\nTests sequential memory',
        buttonLabel: 'Start Sequence',
        preview: Container(
          padding: EdgeInsets.all(4.w),
          decoration: GameTheme.card(ctx),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: _colors
                .map((c) => Padding(
                      padding: EdgeInsets.symmetric(horizontal: 1.5.w),
                      child: Container(
                        width: 10.w,
                        height: 10.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.withValues(alpha: 0.6),
                          boxShadow: [
                            BoxShadow(
                                color: c.withValues(alpha: 0.3), blurRadius: 8)
                          ],
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
        onStart: _start,
      );

  Widget _gameScreen(BuildContext ctx) => Column(children: [
        // Status indicator
        Padding(
          padding: EdgeInsets.symmetric(vertical: 2.h),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Container(
              key: ValueKey(_showing),
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: _showing
                    ? GameColors.mediumAmber.withValues(alpha: 0.1)
                    : GameColors.successGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _showing
                      ? GameColors.mediumAmber.withValues(alpha: 0.3)
                      : GameColors.successGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _showing
                        ? Icons.visibility_rounded
                        : Icons.touch_app_rounded,
                    size: 16.sp,
                    color: _showing
                        ? GameColors.mediumAmber
                        : GameColors.successGreen,
                  ),
                  SizedBox(width: 2.w),
                  Text(
                    _showing ? 'Watch...' : 'Your turn!',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: _showing
                          ? GameColors.mediumAmber
                          : GameColors.successGreen,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Sequence length indicator
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Sequence: ',
                style: TextStyle(
                    fontSize: 13.sp, color: GameTheme.textSecondary(ctx))),
            Text('${_seq.length}',
                style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: GameTheme.accent(ctx))),
            if (_best > 0) ...[
              SizedBox(width: 4.w),
              Text('Best: $_best',
                  style: TextStyle(
                      fontSize: 12.sp,
                      color: GameColors.gold,
                      fontWeight: FontWeight.w600)),
            ],
          ],
        ),
        // Color pads
        Expanded(
          child: Center(
            child: GridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 4.w,
              crossAxisSpacing: 4.w,
              padding: EdgeInsets.all(10.w),
              shrinkWrap: true,
              childAspectRatio: 1,
              children: List.generate(4, (i) {
                return GestureDetector(
                  onTap: _showing ? null : () => _tap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _color(i),
                      border: Border.all(
                        color: _colors[i]
                            .withValues(alpha: _highlighted == i ? 0.8 : 0.3),
                        width: _highlighted == i ? 3 : 1.5,
                      ),
                      boxShadow: _highlighted == i
                          ? [
                              BoxShadow(
                                  color: _colors[i].withValues(alpha: 0.6),
                                  blurRadius: 24,
                                  spreadRadius: 4),
                              BoxShadow(
                                  color: _colors[i].withValues(alpha: 0.3),
                                  blurRadius: 40,
                                  spreadRadius: 8),
                            ]
                          : [
                              BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3)),
                            ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.circle_rounded,
                        size: _highlighted == i ? 16.sp : 10.sp,
                        color: Colors.white
                            .withValues(alpha: _highlighted == i ? 0.8 : 0.3),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        // Round dots
        Padding(
          padding: EdgeInsets.only(bottom: 3.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _seq.length.clamp(1, 12),
              (i) => Container(
                margin: EdgeInsets.symmetric(horizontal: 0.8.w),
                width: 2.5.w,
                height: 2.5.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < _playerIdx
                      ? GameColors.successGreen
                      : GameTheme.primary(ctx).withValues(alpha: 0.15),
                ),
              ),
            ),
          ),
        ),
      ]);

  Widget _resultScreen(BuildContext ctx) {
    final performance = (_best / 15.0).clamp(0.0, 1.0);

    return GameResultsScreen(
      gameIcon: '🎵',
      title: _best >= 10
          ? '🧠 Incredible Memory!'
          : _best >= 7
              ? '👏 Great Sequence!'
              : 'Simon Says Complete!',
      performance: performance,
      score: _best,
      scoreLabel: 'Longest Sequence',
      xpEarned: _xpEarned,
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Best', '$_best'),
        GameResultStat('Rounds', '$_round'),
        GameResultStat('Level', '${_seq.length}'),
      ],
      onRetry: _start,
      onDone: () => Navigator.pop(context),
    );
  }
}

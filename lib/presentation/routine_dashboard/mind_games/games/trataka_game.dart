import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class TratakaGame extends StatefulWidget {
  const TratakaGame({super.key});
  @override
  State<TratakaGame> createState() => _TratakaGameState();
}

class _TratakaGameState extends State<TratakaGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 10;
  static const _ringCount = 8;

  int _roundNum = 0;
  int _correctCount = 0;
  int _totalTimeMs = 0;
  DateTime? _roundStartTime;

  // Colors for the ring
  late List<Color> _ringColors;
  int _oddIndex = -1;
  bool _showingTarget = false;
  bool _answered = false;
  bool _wrongTap = false;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _roundNum = 0;
    _correctCount = 0;
    _totalTimeMs = 0;
    _isDone = false;
    _isNewBest = false;
    setState(() {
      _showingCountdown = true;
    });
  }

  void _onCountdownDone() {
    setState(() {
      _showingCountdown = false;
      _started = true;
    });
    _generateRound();
  }

  void _generateRound() {
    _hideTimer?.cancel();
    _answered = false;
    _wrongTap = false;

    // Generate ring — all same color except one slightly different
    final baseR = 100 + _rng.nextInt(155);
    final baseG = 100 + _rng.nextInt(155);
    final baseB = 100 + _rng.nextInt(155);
    final baseColor = Color.fromARGB(255, baseR, baseG, baseB);

    // Odd one: shift one channel by 30-50
    final shift = 25 + _rng.nextInt(25);
    final channels = [0, 1, 2]..shuffle(_rng);
    int oddR = baseR, oddG = baseG, oddB = baseB;
    switch (channels[0]) {
      case 0:
        oddR = (baseR + shift).clamp(0, 255);
        break;
      case 1:
        oddG = (baseG + shift).clamp(0, 255);
        break;
      case 2:
        oddB = (baseB + shift).clamp(0, 255);
        break;
    }
    final oddColor = Color.fromARGB(255, oddR, oddG, oddB);

    _oddIndex = _rng.nextInt(_ringCount);
    _ringColors = List.generate(_ringCount, (i) {
      return i == _oddIndex ? oddColor : baseColor;
    });

    _showingTarget = true;
    _roundStartTime = DateTime.now();

    // Auto-hide after 3 seconds (harder = shorter)
    final displayMs =
        3000 - (_roundNum * 200).clamp(0, 3000);
    _hideTimer = Timer(Duration(milliseconds: displayMs), () {
      if (mounted) {
        setState(() {
          _showingTarget = false;
        });
      }
    });
  }

  void _tapRing(int index) {
    if (_answered || !_started || _isDone) {
      return;
    }
    final elapsedMs = DateTime.now()
        .difference(_roundStartTime!)
        .inMilliseconds;

    if (index == _oddIndex) {
      _correctCount++;
      _totalTimeMs += elapsedMs;
      GameHaptics.correct();
    } else {
      _wrongTap = true;
      GameHaptics.wrong();
    }

    setState(() {
      _answered = true;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) {
        return;
      }
      _roundNum++;
      if (_roundNum >= _totalRounds) {
        _finishGame();
      } else {
        _generateRound();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  Future<void> _finishGame() async {
    _hideTimer?.cancel();
    _isDone = true;
    _started = false;

    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 9999;
    final finalScore =
        ((accuracy * 600) + max(0, 400 - avgTimeMs * 0.1))
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'trataka',
      score: finalScore,
      accuracy: accuracy,
      reactionTimeMs: avgTimeMs,
      roundsCompleted: _totalRounds,
      metadata: {'correct': _correctCount},
    );
    _isNewBest =
        await _service.submitLocalBest('trataka', finalScore);
    await _service.addXp(10 + (accuracy * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: _started && !_isDone
          ? null
          : AppBar(
              backgroundColor: GameTheme.bg(context),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: GameTheme.textPrimary(context)),
                onPressed: () {
                  _hideTimer?.cancel();
                  Navigator.pop(context);
                },
              ),
              title: Text(
                'Trataka',
                style: TextStyle(
                  color: GameTheme.textPrimary(context),
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              centerTitle: true,
            ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (!_started && !_isDone && !_showingCountdown) {
      return _startScreen(context);
    }
    if (_showingCountdown) {
      return GameCountdown(onDone: _onCountdownDone);
    }
    if (_isDone) {
      return _resultScreen(context);
    }
    return _gameScreen(context);
  }

  Widget _startScreen(BuildContext ctx) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('👁️', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Trataka',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Focus on the center dot.\nPeripheral colors appear —\none is slightly different.\nFind it without moving your gaze!\n$_totalRounds rounds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 4.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.primary(ctx),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.6.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Begin Trataka',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _gameScreen(BuildContext ctx) {
    return SafeArea(
      child: Stack(
        children: [
          // Central dot (always visible)
          Center(
            child: Container(
              width: 5.w,
              height: 5.w,
              decoration: const BoxDecoration(
                color: GameColors.gold,
                shape: BoxShape.circle,
              ),
            ),
          ),
          // Ring of colors
          if (_showingTarget)
            ...List.generate(_ringCount, (i) {
              final angle = (i / _ringCount) * 2 * pi - pi / 2;
              final radius = 28.w;
              final dx = cos(angle) * radius;
              final dy = sin(angle) * radius;

              return Positioned(
                left: MediaQuery.of(context).size.width / 2 +
                    dx -
                    30,
                top: MediaQuery.of(context).size.height / 2 +
                    dy -
                    30,
                child: GestureDetector(
                  onTap: () => _tapRing(i),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 200),
                    width: 15.w,
                    height: 15.w,
                    decoration: BoxDecoration(
                      color: _ringColors[i],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white
                            .withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              );
            }),
          // Round info
          if (_started && !_isDone)
            Positioned(
              top: 2.h,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Round ${_roundNum + 1}/$_totalRounds  ·  ${_showingTarget ? "Find the odd color" : "Too slow! Next round..."}',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ),
          // Wrong tap feedback
          if (_wrongTap)
            Center(
              child: Text(
                'Not that one!',
                style: TextStyle(
                  color: GameColors.errorRed,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 9999;
    return GameResultsScreen(
      gameIcon: '👁️',
      title: 'Trataka Complete!',
      performance: accuracy,
      score: ((accuracy * 600) +
              max(0, 400 - avgTimeMs * 0.1))
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Focus Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat(
            'Avg Time', '${avgTimeMs}ms'),
        GameResultStat(
            'Correct', '$_correctCount/$_totalRounds'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

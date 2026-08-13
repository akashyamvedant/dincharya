import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class FistClenchGame extends StatefulWidget {
  const FistClenchGame({super.key});
  @override
  State<FistClenchGame> createState() => _FistClenchGameState();
}

class _FistClenchGameState extends State<FistClenchGame> {
  final _service = MindGamesService();

  static const _holdSecs = 45;

  // 0=right(encoding), 1=left(recall)
  int _phase = 0;
  int _secondsLeft = 0;
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  bool _phaseActive = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _phase = 0;
    _secondsLeft = _holdSecs;
    _isDone = false;
    _isNewBest = false;
    _phaseActive = false;
    setState(() {
      _showingCountdown = true;
    });
  }

  void _onCountdownDone() {
    setState(() {
      _showingCountdown = false;
      _started = true;
    });
  }

  void _startPhase() {
    _secondsLeft = _holdSecs;
    setState(() {
      _phaseActive = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secondsLeft <= 1) {
        t.cancel();
        if (mounted) {
          _endPhase();
        }
        return;
      }
      setState(() {
        _secondsLeft--;
      });
    });
  }

  void _endPhase() {
    _timer?.cancel();
    _phaseActive = false;

    if (_phase == 0) {
      setState(() {
        _phase = 1;
        _secondsLeft = _holdSecs;
      });
    } else {
      _finishGame();
    }
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    const finalScore = 500.0;

    await _service.saveScore(
      gameType: 'fist_clench',
      score: finalScore,
      accuracy: 1.0,
      roundsCompleted: 2,
      metadata: {'hold_secs': _holdSecs},
    );
    _isNewBest =
        await _service.submitLocalBest('fist_clench', finalScore);
    await _service.addXp(10);
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: _started
          ? null
          : AppBar(
              backgroundColor: GameTheme.bg(context),
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: GameTheme.textPrimary(context)),
                onPressed: () {
                  _timer?.cancel();
                  Navigator.pop(context);
                },
              ),
              title: Text(
                'Fist Clench',
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
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✊', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Fist Clench Power',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Research: Clenching RIGHT fist\nboosts memory ENCODING.\nClenching LEFT fist boosts\nmemory RECALL.\n\nHold each for $_holdSecs seconds\nwith full strength!',
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
                  'Start',
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
    final isRight = _phase == 0;
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isRight ? '✊' : '🤛',
            style: TextStyle(fontSize: 80.sp),
          ),
          SizedBox(height: 2.h),
          Text(
            isRight
                ? 'RIGHT FIST — ENCODING'
                : 'LEFT FIST — RECALL',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: GameTheme.accent(ctx),
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Step ${_phase + 1} of 2',
            style: TextStyle(
              color: GameTheme.textSecondary(ctx),
              fontSize: 13.sp,
            ),
          ),
          SizedBox(height: 4.h),
          if (!_phaseActive)
            Column(
              children: [
                Text(
                  isRight
                      ? 'Clench your RIGHT fist\nas tight as you can!'
                      : 'Clench your LEFT fist\nas tight as you can!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: GameTheme.textPrimary(ctx),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 3.h),
                SizedBox(
                  width: 60.w,
                  child: ElevatedButton(
                    onPressed: _startPhase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          GameTheme.primary(ctx),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          vertical: 1.6.h),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Start Hold',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_phaseActive)
            Column(
              children: [
                SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: CircularProgressIndicator(
                    value: _secondsLeft / _holdSecs,
                    strokeWidth: 8,
                    backgroundColor: GameTheme.primary(ctx)
                        .withValues(alpha: 0.1),
                    color: GameColors.errorRed,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${_secondsLeft}s',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.accent(ctx),
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Squeeze harder!',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: GameTheme.primary(ctx),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 3.h),
                TextButton(
                  onPressed: _endPhase,
                  child: Text(
                    'Release Early',
                    style: TextStyle(
                      color: GameTheme.textMuted(ctx),
                      fontSize: 14.sp,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    return GameResultsScreen(
      gameIcon: '✊',
      title: 'Both Fists Complete!',
      performance: 1.0,
      score: 500,
      scoreLabel: 'Power Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Right Hold', '${_holdSecs}s'),
        GameResultStat('Left Hold', '${_holdSecs}s'),
        GameResultStat('Brain', '🧠++'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class StopTechGame extends StatefulWidget {
  const StopTechGame({super.key});
  @override
  State<StopTechGame> createState() => _StopTechGameState();
}

class _StopTechGameState extends State<StopTechGame> {
  final _service = MindGamesService();

  int _minutesSelected = 10;
  int _secondsLeft = 0;
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _timerRunning = false;
  bool _isNewBest = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _secondsLeft = _minutesSelected * 60;
    _isDone = false;
    _timerRunning = false;
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
  }

  void _startTimer() {
    setState(() {
      _timerRunning = true;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _secondsLeft <= 1) {
        t.cancel();
        if (mounted) {
          _finishTimer();
        }
        return;
      }
      setState(() {
        _secondsLeft--;
      });
    });
  }

  Future<void> _finishTimer() async {
    _timerRunning = false;
    _isDone = true;
    _started = false;

    final finalScore =
        (_minutesSelected * 50.0).clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'stop_tech',
      score: finalScore,
      accuracy: 1.0,
      roundsCompleted: 1,
      metadata: {'minutes': _minutesSelected},
    );
    _isNewBest =
        await _service.submitLocalBest('stop_tech', finalScore);
    await _service.addXp(5 + _minutesSelected);
    if (mounted) {
      setState(() {});
    }
  }

  String _timeDisplay() {
    final mins = _secondsLeft ~/ 60;
    final secs = _secondsLeft % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
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
                'Stop Tech',
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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('📵', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Stop Tech Challenge',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Put your phone down.\nFace down, do not touch.\nTrain your digital discipline.\nEarn XP for time away!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Duration:',
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 1.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [5, 10, 15, 30].map((mins) {
                final sel = _minutesSelected == mins;
                return GestureDetector(
                  onTap: () => setState(
                      () => _minutesSelected = mins),
                  child: Container(
                    margin: EdgeInsets.symmetric(
                        horizontal: 1.5.w),
                    padding: EdgeInsets.symmetric(
                        horizontal: 5.w, vertical: 1.2.h),
                    decoration: BoxDecoration(
                      color: sel
                          ? GameTheme.primary(ctx)
                              .withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color: sel
                            ? GameTheme.primary(ctx)
                            : GameTheme.textMuted(ctx),
                        width: sel ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      '${mins}m',
                      style: TextStyle(
                        color: sel
                            ? GameTheme.primary(ctx)
                            : GameTheme.textSecondary(ctx),
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
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
                  'Start Detox',
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '📵',
            style: TextStyle(fontSize: 64.sp),
          ),
          SizedBox(height: 2.h),
          if (!_timerRunning)
            Column(
              children: [
                Text(
                  'Put your phone face down.\nDo not touch it until\nthe timer ends!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18.sp,
                    color: GameTheme.textPrimary(ctx),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 4.h),
                SizedBox(
                  width: 60.w,
                  child: ElevatedButton(
                    onPressed: _startTimer,
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
                      'Start Timer',
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          if (_timerRunning)
            Column(
              children: [
                SizedBox(
                  width: 45.w,
                  height: 45.w,
                  child: CircularProgressIndicator(
                    value: _secondsLeft /
                        (_minutesSelected * 60),
                    strokeWidth: 8,
                    backgroundColor: GameTheme.primary(ctx)
                        .withValues(alpha: 0.1),
                    color: GameColors.successGreen,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  _timeDisplay(),
                  style: TextStyle(
                    fontSize: 44.sp,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.accent(ctx),
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Stay away from your phone!',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 14.sp,
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
      gameIcon: '📵',
      title: 'Digital Detox Done!',
      performance: 1.0,
      score: (_minutesSelected * 50.0)
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Detox Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Time', '${_minutesSelected} min'),
        GameResultStat('XP', '+${5 + _minutesSelected}'),
        GameResultStat('Brain', '🧠+'),
      ],
      onRetry: () {
        _secondsLeft =
            _minutesSelected * 60;
        _startGame();
      },
      onDone: () => Navigator.pop(context),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class NonDominantHandGame extends StatefulWidget {
  const NonDominantHandGame({super.key});
  @override
  State<NonDominantHandGame> createState() => _NonDominantHandGameState();
}

class _NonDominantHandGameState extends State<NonDominantHandGame> {
  final _service = MindGamesService();

  static const _tasks = [
    'Write your name',
    'Eat a snack',
    'Brush your teeth',
    'Open a bottle',
    'Draw a circle',
    'Use your phone',
    'Hold a cup',
    'Button your shirt',
  ];

  int _selectedTask = 0;
  int _secondsLeft = 60;
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _timerRunning = false;
  bool _isNewBest = false;
  Timer? _timer;

  // Daily streak tracking
  int _streak = 0;
  bool _completedToday = false;

  @override
  void initState() {
    super.initState();
    _loadStreak();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadStreak() async {
    _streak = await _service.getStreak();
    if (mounted) {
      setState(() {});
    }
  }

  void _startGame() {
    _secondsLeft = 60;
    _isDone = false;
    _timerRunning = false;
    _isNewBest = false;
    _completedToday = false;
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
    _completedToday = true;
    _isDone = true;
    _started = false;

    final finalScore = 500.0;

    await _service.saveScore(
      gameType: 'non_dominant_hand',
      score: finalScore,
      accuracy: 1.0,
      roundsCompleted: 1,
      metadata: {'task': _tasks[_selectedTask]},
    );
    _isNewBest = await _service.submitLocalBest('non_dominant_hand', finalScore);
    await _service.markGamePlayed();
    await _service.addXp(10);
    _streak = await _service.getStreak();
    if (mounted) {
      setState(() {});
    }
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
          onPressed: () {
            _timer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Non-Dominant Hand',
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
      child: SingleChildScrollView(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('✋', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Non-Dominant Hand',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Research shows using your\nnon-dominant hand builds\nnew neural pathways.\n\nPick a task and do it\nwith your OTHER hand!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 14.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              'Streak: $_streak days',
              style: TextStyle(
                color: GameColors.gold,
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Choose a task:',
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 13.sp,
              ),
            ),
            SizedBox(height: 2.h),
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
                  'Start Challenge',
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
            '✋',
            style: TextStyle(fontSize: 42.sp),
          ),
          SizedBox(height: 3.h),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            padding: EdgeInsets.all(5.w),
            decoration: GameTheme.heroCard(ctx),
            child: Column(
              children: [
                Text(
                  'Your task:',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  _tasks[_selectedTask],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.primary(ctx),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          if (!_timerRunning)
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Text(
                'Switch hands NOW.\nUse your non-dominant hand!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16.sp,
                  color: GameTheme.textSecondary(ctx),
                  height: 1.5,
                ),
              ),
            ),
          if (_timerRunning)
            Column(
              children: [
                SizedBox(
                  width: 40.w,
                  height: 40.w,
                  child: CircularProgressIndicator(
                    value: _secondsLeft / 60.0,
                    strokeWidth: 6,
                    backgroundColor: GameTheme.primary(ctx)
                        .withValues(alpha: 0.1),
                    color: GameTheme.accent(ctx),
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
                  'Keep going with your other hand!',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          SizedBox(height: 4.h),
          if (!_timerRunning)
            SizedBox(
              width: double.infinity,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: ElevatedButton(
                  onPressed: _startTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: GameTheme.primary(ctx),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.6.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Start 60s Timer',
                    style: TextStyle(
                      fontSize: 17.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    return GameResultsScreen(
      gameIcon: '✋',
      title: 'Challenge Complete!',
      performance: 1.0,
      score: 500,
      scoreLabel: 'Neurobic Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Task', _tasks[_selectedTask]),
        GameResultStat('Streak', '$_streak days'),
        GameResultStat('Brain', '🧠+'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

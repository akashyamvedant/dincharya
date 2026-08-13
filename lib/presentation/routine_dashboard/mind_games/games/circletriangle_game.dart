import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class CircleTriangleGame extends StatefulWidget {
  const CircleTriangleGame({super.key});
  @override
  State<CircleTriangleGame> createState() => _CircleTriangleGameState();
}

class _CircleTriangleGameState extends State<CircleTriangleGame>
    with SingleTickerProviderStateMixin {
  final _service = MindGamesService();

  static const _rounds = 5;
  int _roundNum = 0;
  int _switchCount = 0;
  bool _rightIsCircle = true;

  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  Timer? _switchTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        duration: const Duration(milliseconds: 800), vsync: this);
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.3)
        .animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _pulseCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _startGame() {
    _roundNum = 0;
    _switchCount = 0;
    _rightIsCircle = true;
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
    _startSwitchTimer();
  }

  void _startSwitchTimer() {
    _switchTimer?.cancel();
    _switchTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted || _isDone) {
        return;
      }
      setState(() {
        _rightIsCircle = !_rightIsCircle;
        _switchCount++;
      });
      GameHaptics.tap();
      _roundNum++;
      if (_roundNum >= _rounds) {
        _finishGame();
      } else {
        _startSwitchTimer();
      }
    });
  }

  Future<void> _finishGame() async {
    _switchTimer?.cancel();
    _isDone = true;
    _started = false;

    const finalScore = 500.0;
    await _service.saveScore(
      gameType: 'circle_triangle',
      score: finalScore,
      accuracy: 1.0,
      roundsCompleted: _rounds,
      metadata: {'switches': _switchCount},
    );
    _isNewBest = await _service.submitLocalBest('circle_triangle', finalScore);
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
                  _switchTimer?.cancel();
                  Navigator.pop(context);
                },
              ),
              title: Text(
                'Circle-Triangle',
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
            SizedBox(height: 4.h),
            Text('🔺⭕', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 2.h),
            Text('Circle-Triangle Switch',
                style: GameTheme.heading(ctx, size: 22)),
            SizedBox(height: 1.5.h),
            Text(
              'Draw shapes in the air!\nRight hand = shown shape\nLeft hand = other shape\nSwitch every 5 seconds.\n$_rounds switches.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 12.sp,
                height: 1.5,
              ),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startGame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.primary(ctx),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 1.4.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Start',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(height: 2.h),
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
            'Switch ${_roundNum + 1}/$_rounds',
            style: TextStyle(
              color: GameTheme.textSecondary(ctx),
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Right hand
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: _rightIsCircle ? _pulseAnim.value : 1.0,
                      child: Text(
                        '✋',
                        style: TextStyle(fontSize: 36.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    _rightIsCircle ? '⭕ Circle' : '🔺 Triangle',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: GameTheme.accent(ctx),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Right Hand',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: GameTheme.textMuted(ctx),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              // Left hand
              Column(
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnim,
                    builder: (_, __) => Transform.scale(
                      scale: !_rightIsCircle ? _pulseAnim.value : 1.0,
                      child: Text(
                        '🤚',
                        style: TextStyle(fontSize: 36.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    !_rightIsCircle ? '⭕ Circle' : '🔺 Triangle',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: GameTheme.primary(ctx),
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Left Hand',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: GameTheme.textMuted(ctx),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            'Draw the shapes in the air!',
            style: TextStyle(
              fontSize: 12.sp,
              color: GameTheme.textSecondary(ctx),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'SWITCH soon...',
            style: TextStyle(
              fontSize: 10.sp,
              color: GameColors.gold,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    return GameResultsScreen(
      gameIcon: '🔺',
      title: 'Switches Complete!',
      performance: 1.0,
      score: 500,
      scoreLabel: 'Coordination',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Switches', '$_switchCount'),
        GameResultStat('Rounds', '$_rounds'),
        GameResultStat('Brain', '🧠++'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class ThoughtWatchGame extends StatefulWidget {
  const ThoughtWatchGame({super.key});
  @override
  State<ThoughtWatchGame> createState() => _ThoughtWatchGameState();
}

class _ThoughtWatchGameState extends State<ThoughtWatchGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _sessionSecs = 30;
  static const _thoughts = [
    'Work deadline',
    'What to eat?',
    'That argument',
    'Phone buzz',
    'Tomorrow plan',
    'Past mistake',
    'Someone said...',
    'Forgot to...',
    'Need to buy...',
    'Why did I...',
    'Future worry',
    'Body ache',
    'To-do list',
    'Social media',
    'Comparison',
    'Regret',
    'Money stress',
    'Health concern',
    'Relationship',
    'Career path',
  ];

  int _thoughtsAppeared = 0;
  int _thoughtsNoticed = 0;
  int _secondsLeft = _sessionSecs;
  Timer? _timer;
  Timer? _thoughtTimer;

  // Current floating thought
  String? _currentThought;
  double _thoughtX = 0.5;
  double _thoughtY = 0.3;
  double _thoughtOpacity = 0.0;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;

  @override
  void dispose() {
    _timer?.cancel();
    _thoughtTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _thoughtsAppeared = 0;
    _thoughtsNoticed = 0;
    _secondsLeft = _sessionSecs;
    _currentThought = null;
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
    _startSession();
  }

  void _startSession() {
    // Countdown timer
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_secondsLeft <= 1) {
        t.cancel();
        _finishGame();
        return;
      }
      setState(() {
        _secondsLeft--;
      });
    });

    // Spawn thoughts randomly
    _spawnThought();
  }

  void _spawnThought() {
    if (!_started || _isDone) {
      return;
    }
    setState(() {
      _currentThought =
          _thoughts[_rng.nextInt(_thoughts.length)];
      _thoughtX = 0.1 + _rng.nextDouble() * 0.8;
      _thoughtY = 0.15 + _rng.nextDouble() * 0.6;
      _thoughtOpacity = 1.0;
      _thoughtsAppeared++;
    });

    // Thought fades after 2 seconds
    _thoughtTimer?.cancel();
    _thoughtTimer =
        Timer(const Duration(milliseconds: 2000), () {
      if (mounted) {
        setState(() {
          _thoughtOpacity = 0.0;
        });
        // Next thought after random delay
        _thoughtTimer = Timer(Duration(
            milliseconds: 1500 + _rng.nextInt(2500)), () {
          if (mounted && _started && !_isDone) {
            _spawnThought();
          }
        });
      }
    });
  }

  void _tapThought() {
    if (!_started || _isDone || _currentThought == null) {
      return;
    }
    if (_thoughtOpacity < 0.3) {
      return;
    }
    setState(() {
      _thoughtsNoticed++;
      _thoughtOpacity = 0.0;
    });
    GameHaptics.correct();
  }

  Future<void> _finishGame() async {
    _timer?.cancel();
    _thoughtTimer?.cancel();
    _isDone = true;
    _started = false;

    final noticedRatio = _thoughtsAppeared > 0
        ? (_thoughtsNoticed / _thoughtsAppeared).clamp(0.0, 1.0)
        : 0.0;
    final finalScore = (noticedRatio * 1000.0);

    await _service.saveScore(
      gameType: 'thought_watch',
      score: finalScore,
      accuracy: noticedRatio,
      roundsCompleted: _thoughtsAppeared,
      metadata: {
        'appeared': _thoughtsAppeared,
        'noticed': _thoughtsNoticed,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('thought_watch', finalScore);
    await _service.addXp(5 + (noticedRatio * 15.0).round());
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
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Thought Watch',
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
    return _meditationScreen(context);
  }

  Widget _startScreen(BuildContext ctx) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(6.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('🧘', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Thought Watch',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Thoughts will appear as words.\nTap to acknowledge each one\nwithout engaging it.\n$_sessionSecs second Vipassana session.',
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
                  'Begin Meditation',
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

  Widget _meditationScreen(BuildContext ctx) {
    return GestureDetector(
      onTap: _tapThought,
      behavior: HitTestBehavior.translucent,
      child: Container(
        color: GameTheme.bg(ctx),
        child: Stack(
          children: [
            // Timer
            Positioned(
              top: 5.h,
              left: 0,
              right: 0,
              child: Center(
                child: Column(
                  children: [
                    Text(
                      '🕉️',
                      style: TextStyle(fontSize: 28.sp),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      '$_secondsLeft',
                      style: TextStyle(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.w300,
                        color: GameTheme.textSecondary(ctx),
                      ),
                    ),
                    SizedBox(height: 0.5.h),
                    Text(
                      'Tap thoughts to release',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: GameTheme.textMuted(ctx),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Score display
            Positioned(
              bottom: 4.h,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Noticed: $_thoughtsNoticed',
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: GameTheme.accent(ctx),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // Floating thoughts
            if (_currentThought != null)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 500),
                left: FractionalOffset(_thoughtX, 0).dx *
                    MediaQuery.of(context).size.width -
                    80,
                top: FractionalOffset(0, _thoughtY).dy *
                    MediaQuery.of(context).size.height,
                child: AnimatedOpacity(
                  duration:
                      const Duration(milliseconds: 400),
                  opacity: _thoughtOpacity,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 4.w, vertical: 2.h),
                    decoration: BoxDecoration(
                      color: GameTheme.primary(ctx)
                          .withValues(alpha: 0.9),
                      borderRadius:
                          BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: GameTheme.primary(ctx)
                              .withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      _currentThought!,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final noticedRatio = _thoughtsAppeared > 0
        ? (_thoughtsNoticed / _thoughtsAppeared)
            .clamp(0.0, 1.0)
        : 0.0;
    String insight;
    if (noticedRatio >= 0.9) {
      insight = 'Excellent awareness!';
    } else if (noticedRatio >= 0.6) {
      insight = 'Good mindfulness!';
    } else {
      insight = 'Keep practicing...';
    }

    return GameResultsScreen(
      gameIcon: '🧘',
      title: insight,
      performance: noticedRatio,
      score: (noticedRatio * 1000.0).round(),
      scoreLabel: 'Awareness Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Noticed', '$_thoughtsNoticed'),
        GameResultStat(
            'Appeared', '$_thoughtsAppeared'),
        GameResultStat('Time',
            '${_sessionSecs}s'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

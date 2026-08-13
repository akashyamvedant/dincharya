import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class GunaBalanceGame extends StatefulWidget {
  const GunaBalanceGame({super.key});
  @override
  State<GunaBalanceGame> createState() => _GunaBalanceGameState();
}

class _GunaBalanceGameState extends State<GunaBalanceGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 15;
  static const _items = [
    ('Fresh fruits', 0),
    ('Meditation', 0),
    ('Early morning walk', 0),
    ('Drinking water', 0),
    ('Reading scripture', 0),
    ('Helping others', 0),
    ('Silence (Mauna)', 0),
    ('Clean room', 0),
    ('Exercise', 1),
    ('Work deadline', 1),
    ('Debate / Argument', 1),
    ('Spicy food', 1),
    ('Competition', 1),
    ('Social media scrolling', 1),
    ('Travel / Commute', 1),
    ('Coffee / Tea', 1),
    ('Junk food', 2),
    ('Oversleeping', 2),
    ('Laziness (Alasya)', 2),
    ('Gossip', 2),
    ('Watching TV all day', 2),
    ('Alcohol', 2),
    ('Anger (Krodha)', 2),
    ('Jealousy (Irshya)', 2),
  ];

  // Current question
  int _roundNum = 0;
  int _correctCount = 0;
  int _totalTimeMs = 0;
  DateTime? _roundStartTime;
  late String _currentItem;
  late int _correctGuna;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  bool _answered = false;
  int? _selectedGuna;

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
    _answered = false;
    _selectedGuna = null;

    final item = _items[_rng.nextInt(_items.length)];
    _currentItem = item.$1;
    _correctGuna = item.$2;
    _roundStartTime = DateTime.now();
  }

  void _selectGuna(int guna) {
    if (_answered || !_started || _isDone) {
      return;
    }
    final isCorrect = guna == _correctGuna;
    final elapsedMs = DateTime.now()
        .difference(_roundStartTime!)
        .inMilliseconds;

    if (isCorrect) {
      _correctCount++;
      _totalTimeMs += elapsedMs;
      GameHaptics.correct();
    } else {
      GameHaptics.wrong();
    }

    setState(() {
      _selectedGuna = guna;
      _answered = true;
    });

    Future.delayed(const Duration(milliseconds: 700), () {
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
    _isDone = true;
    _started = false;

    final accuracy = _correctCount / _totalRounds;
    final avgTimeMs = _correctCount > 0
        ? _totalTimeMs ~/ _correctCount
        : 9999;
    final finalScore =
        ((accuracy * 700) + max(0, 300 - avgTimeMs * 0.1))
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'guna_balance',
      score: finalScore,
      accuracy: accuracy,
      reactionTimeMs: avgTimeMs,
      roundsCompleted: _totalRounds,
      metadata: {'correct': _correctCount},
    );
    _isNewBest =
        await _service.submitLocalBest('guna_balance', finalScore);
    await _service.addXp(10 + (accuracy * 20.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  Color _gunaColor(int guna) {
    switch (guna) {
      case 0:
        return const Color(0xFFF5F5DC);
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFF808080);
      default:
        return Colors.grey;
    }
  }

  String _gunaName(int guna) {
    switch (guna) {
      case 0:
        return 'Sattva';
      case 1:
        return 'Rajas';
      case 2:
        return 'Tamas';
      default:
        return '';
    }
  }

  String _gunaDesc(int guna) {
    switch (guna) {
      case 0:
        return 'Pure · Calm · Light';
      case 1:
        return 'Active · Passion · Motion';
      case 2:
        return 'Dull · Inert · Heavy';
      default:
        return '';
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Guna Balance',
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
            Text('⚖️', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Guna Balance',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Sort each item into its Guna:\n\nSattva — Pure, calm, light\nRajas — Active, passionate, moving\nTamas — Dull, inert, heavy\n\n$_totalRounds rounds.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: GameTheme.textSecondary(ctx),
                fontSize: 13.sp,
                height: 1.6,
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
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Round ${_roundNum + 1}/$_totalRounds',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Score: $_correctCount',
                  style: TextStyle(
                    color: GameTheme.accent(ctx),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 2.h),
          // Item card
          Container(
            margin: EdgeInsets.symmetric(horizontal: 5.w),
            padding: EdgeInsets.all(5.w),
            decoration: GameTheme.heroCard(ctx),
            child: Column(
              children: [
                Text(
                  'Which Guna?',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 12.sp,
                  ),
                ),
                SizedBox(height: 1.5.h),
                Text(
                  _currentItem,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: GameTheme.primary(ctx),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 3.h),
          // Guna options
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Column(
                children: List.generate(3, (guna) {
                  final isSelected = _selectedGuna == guna;
                  final isCorrectGuna =
                      _answered && guna == _correctGuna;
                  final isWrong =
                      isSelected && !isCorrectGuna;
                  return Padding(
                    padding: EdgeInsets.only(bottom: 2.h),
                    child: GestureDetector(
                      onTap: () => _selectGuna(guna),
                      child: AnimatedContainer(
                        duration: const Duration(
                            milliseconds: 300),
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                            vertical: 2.h),
                        decoration: BoxDecoration(
                          color: isCorrectGuna
                              ? GameColors.successGreen
                                  .withValues(alpha: 0.15)
                              : isWrong
                                  ? GameColors.errorRed
                                      .withValues(alpha: 0.15)
                                  : _gunaColor(guna)
                                      .withValues(alpha: 0.1),
                          borderRadius:
                              BorderRadius.circular(14),
                          border: Border.all(
                            color: isCorrectGuna
                                ? GameColors.successGreen
                                : isWrong
                                    ? GameColors.errorRed
                                    : _gunaColor(guna)
                                        .withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _gunaName(guna),
                              style: TextStyle(
                                fontSize: 20.sp,
                                fontWeight: FontWeight.bold,
                                color: GameTheme
                                    .textPrimary(ctx),
                              ),
                            ),
                            SizedBox(height: 0.5.h),
                            Text(
                              _gunaDesc(guna),
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: GameTheme
                                    .textMuted(ctx),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
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
    String insight;
    if (accuracy >= 0.9) {
      insight = 'Guna Master!';
    } else if (accuracy >= 0.7) {
      insight = 'Good Understanding!';
    } else {
      insight = 'Keep Learning!';
    }

    return GameResultsScreen(
      gameIcon: '⚖️',
      title: insight,
      performance: accuracy,
      score: ((accuracy * 700) +
              max(0, 300 - avgTimeMs * 0.1))
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Guna Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat(
            'Correct', '$_correctCount/$_totalRounds'),
        GameResultStat(
            'Speed', '${avgTimeMs}ms avg'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

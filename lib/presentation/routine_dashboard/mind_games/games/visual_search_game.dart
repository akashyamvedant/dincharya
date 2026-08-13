import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class VisualSearchGame extends StatefulWidget {
  const VisualSearchGame({super.key});
  @override
  State<VisualSearchGame> createState() => _VisualSearchGameState();
}

class _VisualSearchGameState extends State<VisualSearchGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 10;
  static const _shapes = ['circle', 'square', 'triangle', 'diamond'];
  static const _colors = [
    Color(0xFFE53935),
    Color(0xFF1E88E5),
    Color(0xFF43A047),
    Color(0xFFFFA000),
    Color(0xFF8E24AA),
  ];

  // Difficulty: (gridSize, shapeCount, colorCount)
  static const _levels = [
    (3, 2, 2),
    (3, 3, 3),
    (4, 3, 3),
    (4, 4, 4),
    (5, 4, 4),
    (6, 4, 5),
  ];

  int _gridSize = 3;
  int _shapePool = 2;
  int _colorPool = 2;
  int _roundNum = 0;
  String _targetShape = '';
  Color _targetColor = Colors.black;

  // Grid data: (shape, color)
  late List<(String, Color)> _grid;
  int _targetIndex = -1;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  int _totalCorrect = 0;
  int _totalTimeMs = 0;
  DateTime? _roundStartTime;

  @override
  void initState() {
    super.initState();
  }

  void _startGame() {
    _totalCorrect = 0;
    _totalTimeMs = 0;
    _roundNum = 0;
    _isDone = false;
    _isNewBest = false;
    _updateDifficulty();
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

  void _updateDifficulty() {
    final idx = min(_roundNum ~/ 2, _levels.length - 1);
    final (gs, sc, cc) = _levels[idx];
    _gridSize = gs;
    _shapePool = sc;
    _colorPool = cc;
  }

  void _generateRound() {
    _updateDifficulty();

    final shapeSubset = _shapes.take(_shapePool).toList();
    final colorSubset = _colors.take(_colorPool).toList();

    // Pick unique target
    _targetShape = shapeSubset[_rng.nextInt(shapeSubset.length)];
    _targetColor = colorSubset[_rng.nextInt(colorSubset.length)];

    // Place distractor or identical target at each cell
    final total = _gridSize * _gridSize;
    _targetIndex = _rng.nextInt(total);

    _grid = List.generate(total, (_) {
      return (shapeSubset[_rng.nextInt(shapeSubset.length)],
          colorSubset[_rng.nextInt(colorSubset.length)]);
    });

    // Insert the actual target at targetIndex
    _grid[_targetIndex] = (_targetShape, _targetColor);

    _roundStartTime = DateTime.now();
    setState(() {});
  }

  void _onTapCell(int index) {
    if (!_started || _isDone) {
      return;
    }

    final elapsedMs =
        DateTime.now().difference(_roundStartTime!).inMilliseconds;
    final isCorrect = index == _targetIndex;

    if (isCorrect) {
      _totalCorrect++;
      _totalTimeMs += elapsedMs;
      GameHaptics.correct();
    } else {
      GameHaptics.wrong();
    }

    _roundNum++;
    if (_roundNum >= _totalRounds) {
      _finishGame();
    } else {
      _generateRound();
    }
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    final accuracy = _totalCorrect / _totalRounds;
    final avgTimeMs = _totalCorrect > 0
        ? _totalTimeMs ~/ _totalCorrect
        : 9999;
    final finalScore =
        ((accuracy * 500) + max(0, 500 - avgTimeMs)).clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'visual_search',
      score: finalScore,
      accuracy: accuracy,
      reactionTimeMs: avgTimeMs,
      roundsCompleted: _totalRounds,
      metadata: {
        'correct': _totalCorrect,
        'avg_time_ms': avgTimeMs,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('visual_search', finalScore);
    await _service.addXp(10 + (accuracy * 25.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  IconData _shapeIcon(String shape) {
    switch (shape) {
      case 'circle':
        return Icons.circle;
      case 'square':
        return Icons.square_rounded;
      case 'triangle':
        return Icons.change_history_rounded;
      case 'diamond':
        return Icons.diamond_rounded;
      default:
        return Icons.circle;
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
          'Visual Search',
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
            Text('🔍', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Visual Search', style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Find the shape that matches the target.\nGrid gets bigger, colors get trickier.\n$_totalRounds rounds.',
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
    return SafeArea(
      child: Column(
        children: [
          // Target display
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
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
                Row(
                  children: [
                    Text(
                      'Find: ',
                      style: TextStyle(
                        color: GameTheme.textSecondary(ctx),
                        fontSize: 14.sp,
                      ),
                    ),
                    Icon(
                      _shapeIcon(_targetShape),
                      color: _targetColor,
                      size: 28,
                    ),
                  ],
                ),
                Text(
                  '${_gridSize}x${_gridSize}',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          Divider(
            color: GameTheme.primary(ctx).withValues(alpha: 0.1),
          ),
          // Search grid
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: EdgeInsets.all(2.w),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridSize,
                    ),
                    itemCount: _grid.length,
                    itemBuilder: (_, idx) {
                      final (shape, color) = _grid[idx];
                      return GestureDetector(
                        onTap: () => _onTapCell(idx),
                        child: Container(
                          margin: EdgeInsets.all(1.w),
                          decoration: BoxDecoration(
                            color: GameTheme.surface(ctx).withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: GameTheme.primary(ctx).withValues(alpha: 0.1),
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              _shapeIcon(shape),
                              color: color,
                              size: _gridSize <= 3
                                  ? 36
                                  : _gridSize <= 4
                                      ? 28
                                      : 22,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(3.w),
            child: Text(
              'Tap the matching shape as fast as you can',
              style: TextStyle(
                color: GameTheme.textMuted(ctx),
                fontSize: 12.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _totalCorrect / _totalRounds;
    final avgTimeMs = _totalCorrect > 0
        ? _totalTimeMs ~/ _totalCorrect
        : 9999;
    return GameResultsScreen(
      gameIcon: '🔍',
      title: 'Search Complete!',
      performance: accuracy,
      score: ((accuracy * 500) + max(0, 500 - avgTimeMs))
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Search Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat('Avg Time', '${avgTimeMs}ms'),
        GameResultStat('Correct', '$_totalCorrect/$_totalRounds'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

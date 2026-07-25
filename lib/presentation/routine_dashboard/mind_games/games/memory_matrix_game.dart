import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class MemoryMatrixGame extends StatefulWidget {
  const MemoryMatrixGame({super.key});
  @override
  State<MemoryMatrixGame> createState() => _MemoryMatrixGameState();
}

class _MemoryMatrixGameState extends State<MemoryMatrixGame> {
  final _service = MindGamesService(), _rng = Random();

  // Level configs: (gridSize, tileCount, displayMs)
  static const _levels = [
    (4, 4, 3000),
    (4, 5, 2500),
    (5, 6, 3000),
    (5, 8, 2000),
    (6, 9, 2000),
  ];
  static const _roundsPerGame = 3;
  int _levelIdx = 0;
  int get _gridSize => _levels[_levelIdx].$1;
  int get _tileCount => _levels[_levelIdx].$2;
  int get _displayMs => _levels[_levelIdx].$3;

  // State
  late List<bool> _pattern;   // true = highlighted tile
  late List<bool> _response;  // user's tap selection
  bool _started = false;
  bool _showingCountdown = false;
  bool _displayingPattern = false;
  bool _recalling = false;
  bool _isDone = false;
  int _roundNum = 0;
  int _totalCorrect = 0;
  int _totalTiles = 0;
  int _totalRounds = 0;
  bool _isNewBest = false;

  // Results tracking
  final List<double> _roundAccuracies = [];

  @override
  void initState() {
    super.initState();
    _resetState();
  }

  void _resetState() {
    _pattern = List.filled(_gridSize * _gridSize, false);
    _response = List.filled(_gridSize * _gridSize, false);
    _started = false;
    _showingCountdown = false;
    _displayingPattern = false;
    _recalling = false;
    _isDone = false;
    _roundNum = 0;
    _totalCorrect = 0;
    _totalTiles = 0;
    _totalRounds = 0;
    _isNewBest = false;
    _roundAccuracies.clear();
  }

  void _startGame() {
    _resetState();
    _levelIdx = 0;
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
    final total = _gridSize * _gridSize;
    _pattern = List.filled(total, false);
    _response = List.filled(total, false);

    // Pick random unique tile positions
    final indices = List.generate(total, (i) => i)..shuffle(_rng);
    for (int i = 0; i < _tileCount; i++) {
      _pattern[indices[i]] = true;
    }

    setState(() {
      _displayingPattern = true;
      _recalling = false;
    });

    // Show pattern, then switch to recall
    Future.delayed(Duration(milliseconds: _displayMs), () {
      if (mounted && _started && !_isDone) {
        setState(() {
          _displayingPattern = false;
          _recalling = true;
        });
      }
    });
  }

  void _toggleCell(int index) {
    if (!_recalling || _isDone) {
      return;
    }
    setState(() {
      _response[index] = !_response[index];
    });
    GameHaptics.tap();
  }

  void _submitResponse() {
    if (!_recalling || _isDone) {
      return;
    }

    int correct = 0;
    int falseAlarms = 0;
    for (int i = 0; i < _pattern.length; i++) {
      if (_pattern[i] && _response[i]) {
        correct++;
      } else if (!_pattern[i] && _response[i]) {
        falseAlarms++;
      }
    }

    final accuracy = _tileCount > 0
        ? (correct / _tileCount).clamp(0.0, 1.0)
        : 0.0;
    _totalCorrect += correct;
    _totalTiles += _tileCount;
    _totalRounds++;
    _roundAccuracies.add(accuracy);

    GameHaptics.correct();

    _roundNum++;
    if (_roundNum >= _roundsPerGame) {
      // Advance level or finish
      if (_levelIdx < _levels.length - 1 && _averageAccuracy() >= 0.7) {
        _levelIdx++;
        _roundNum = 0;
        _generateRound();
      } else {
        _finishGame();
      }
    } else {
      _generateRound();
    }
  }

  double _averageAccuracy() {
    if (_roundAccuracies.isEmpty) {
      return 0.0;
    }
    return _roundAccuracies.reduce((a, b) => a + b) / _roundAccuracies.length;
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    final accuracy = _totalTiles > 0
        ? (_totalCorrect / _totalTiles).clamp(0.0, 1.0)
        : 0.0;
    final finalScore = (accuracy * 1000).round().toDouble();

    await _service.saveScore(
      gameType: 'memory_matrix',
      score: finalScore,
      accuracy: accuracy,
      roundsCompleted: _totalRounds,
      metadata: {
        'level': _levelIdx + 1,
        'grid_size': _gridSize,
        'tiles_per_round': _tileCount,
      },
    );
    _isNewBest = await _service.submitLocalBest('memory_matrix', finalScore);
    await _service.addXp(10 + (accuracy * 30.0).round());
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
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Memory Matrix',
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
            Text('🧠', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Memory Matrix', style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'A pattern of tiles lights up briefly.\nTap the SAME tiles from memory.\n$_roundsPerGame rounds, increasing difficulty.',
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
          // Status bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Round ${_roundNum + 1}/$_roundsPerGame',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Level ${_levelIdx + 1}',
                  style: TextStyle(
                    color: GameTheme.accent(ctx),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
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
          // Grid
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    color: GameTheme.surface(ctx).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: GameTheme.primary(ctx).withValues(alpha: 0.15),
                    ),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridSize,
                    ),
                    itemCount: _gridSize * _gridSize,
                    itemBuilder: (_, idx) {
                      final showPattern = _displayingPattern && _pattern[idx];
                      final userTapped = _recalling && _response[idx];

                      return GestureDetector(
                        onTap: () => _toggleCell(idx),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: EdgeInsets.all(0.5.w),
                          decoration: BoxDecoration(
                            color: showPattern
                                ? GameTheme.accent(ctx)
                                : userTapped
                                    ? GameTheme.primary(ctx).withValues(alpha: 0.7)
                                    : GameTheme.primary(ctx).withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: showPattern
                                  ? Colors.white.withValues(alpha: 0.8)
                                  : userTapped
                                      ? GameTheme.primary(ctx)
                                      : GameTheme.primary(ctx).withValues(alpha: 0.12),
                              width: showPattern || userTapped ? 2.0 : 1.0,
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
          // Instructions + submit
          Padding(
            padding: EdgeInsets.all(4.w),
            child: Column(
              children: [
                Text(
                  _displayingPattern
                      ? 'Memorize the pattern!'
                      : 'Tap tiles to recreate the pattern',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 14.sp,
                  ),
                ),
                if (_recalling)
                  Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _submitResponse,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: GameTheme.primary(ctx),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 1.4.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Submit',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: 1.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _totalTiles > 0
        ? (_totalCorrect / _totalTiles).clamp(0.0, 1.0)
        : 0.0;
    return GameResultsScreen(
      gameIcon: '🧠',
      title: 'Matrix Complete!',
      performance: accuracy,
      score: (accuracy * 1000).round(),
      scoreLabel: 'Memory Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat('Tiles', '$_totalCorrect/$_totalTiles'),
        GameResultStat('Level', '${_levelIdx + 1}'),
      ],
      onRetry: () {
        _resetState();
        _startGame();
      },
      onDone: () => Navigator.pop(context),
    );
  }
}

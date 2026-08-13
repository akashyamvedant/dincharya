import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class MandalaMirrorGame extends StatefulWidget {
  const MandalaMirrorGame({super.key});
  @override
  State<MandalaMirrorGame> createState() => _MandalaMirrorGameState();
}

class _MandalaMirrorGameState extends State<MandalaMirrorGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _totalRounds = 3;
  final _colors = [
    const Color(0xFFE53935),
    const Color(0xFFFB8C00),
    const Color(0xFF1E88E5),
    const Color(0xFF43A047),
    const Color(0xFF8E24AA),
  ];

  // Grid size per round
  static const _sizes = [4, 6, 8];
  int _roundNum = 0;

  // Left half = the "source" pattern, right half = user fills
  late List<Color?> _grid;
  int _gridSize = _sizes[0];
  int _totalCorrect = 0;
  int _totalCells = 0;

  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;

  void _startGame() {
    _roundNum = 0;
    _totalCorrect = 0;
    _totalCells = 0;
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
    _gridSize = _sizes[_roundNum];
    final total = _gridSize * _gridSize;
    _grid = List.filled(total, null);

    // Generate random left-half pattern
    final mid = _gridSize ~/ 2;
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < mid; c++) {
        _grid[r * _gridSize + c] =
            _colors[_rng.nextInt(_colors.length)];
      }
    }
  }

  void _tapCell(int index) {
    if (!_started || _isDone) {
      return;
    }

    final row = index ~/ _gridSize;
    final col = index % _gridSize;
    final mid = _gridSize ~/ 2;

    // Only allow tapping on the right half
    if (col < mid) {
      return;
    }

    // Cycle through colors
    final current = _grid[index];
    Color? nextColor;
    if (current == null) {
      nextColor = _colors[0];
    } else {
      final idx = _colors.indexOf(current);
      nextColor = _colors[(idx + 1) % _colors.length];
    }

    setState(() {
      _grid[index] = nextColor;
    });
    GameHaptics.tap();
  }

  void _submitRound() {
    if (!_started || _isDone) {
      return;
    }

    final mid = _gridSize ~/ 2;
    int correct = 0;
    int total = 0;

    // Mirror check: left[r][c] should match right[r][gridSize-1-c]
    for (int r = 0; r < _gridSize; r++) {
      for (int c = 0; c < mid; c++) {
        final rightCol = _gridSize - 1 - c;
        final left = _grid[r * _gridSize + c];
        final right = _grid[r * _gridSize + rightCol];
        if (right != null) {
          total++;
          if (left != null && left.value == right.value) {
            correct++;
          }
        }
      }
    }

    _totalCorrect += correct;
    _totalCells += total;
    GameHaptics.correct();

    _roundNum++;
    if (_roundNum >= _totalRounds) {
      _finishGame();
    } else {
      _generateRound();
      setState(() {});
    }
  }

  Future<void> _finishGame() async {
    _isDone = true;
    _started = false;

    final accuracy = _totalCells > 0
        ? (_totalCorrect / _totalCells).clamp(0.0, 1.0)
        : 0.0;
    final finalScore = (accuracy * 1000.0);

    await _service.saveScore(
      gameType: 'mandala_mirror',
      score: finalScore,
      accuracy: accuracy,
      roundsCompleted: _totalRounds,
      metadata: {
        'correct': _totalCorrect,
        'total': _totalCells,
      },
    );
    _isNewBest =
        await _service.submitLocalBest('mandala_mirror', finalScore);
    await _service.addXp(10 + (accuracy * 25.0).round());
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
          'Mandala Mirror',
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
            Text('🪷', style: TextStyle(fontSize: 40.sp)),
            SizedBox(height: 3.h),
            Text('Mandala Mirror',
                style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'The left half of a mandala is shown.\nTap cells on the right half\nto mirror the pattern.\n$_totalRounds rounds, increasing size.',
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
    final mid = _gridSize ~/ 2;

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
                  '${_gridSize}x$_gridSize',
                  style: TextStyle(
                    color: GameTheme.accent(ctx),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
          // Divider line
          Padding(
            padding: EdgeInsets.symmetric(vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Pattern',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: GameTheme.textMuted(ctx),
                  ),
                ),
                SizedBox(width: 20.w),
                Text(
                  'Your Mirror',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: GameTheme.accent(ctx),
                    fontWeight: FontWeight.w600,
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
                  margin: EdgeInsets.all(2.w),
                  child: GridView.builder(
                    physics:
                        const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _gridSize,
                    ),
                    itemCount: _gridSize * _gridSize,
                    itemBuilder: (_, idx) {
                      final col = idx % _gridSize;
                      final isLeft = col < mid;
                      final color = _grid[idx];

                      return GestureDetector(
                        onTap: () => _tapCell(idx),
                        child: Container(
                          margin: EdgeInsets.all(0.3.w),
                          decoration: BoxDecoration(
                            color: color ??
                                (isLeft
                                    ? Colors.transparent
                                    : GameTheme.primary(ctx)
                                        .withValues(
                                            alpha: 0.05)),
                            borderRadius:
                                BorderRadius.circular(
                                    _gridSize <= 4 ? 4 : 3),
                            border: Border.all(
                              color: isLeft
                                  ? Colors.transparent
                                  : GameTheme.primary(ctx)
                                      .withValues(
                                          alpha: 0.2),
                              width: isLeft ? 0 : 1,
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
          // Submit button
          Padding(
            padding: EdgeInsets.all(4.w),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitRound,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GameTheme.primary(ctx),
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(vertical: 1.4.h),
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
        ],
      ),
    );
  }

  Widget _resultScreen(BuildContext ctx) {
    final accuracy = _totalCells > 0
        ? (_totalCorrect / _totalCells).clamp(0.0, 1.0)
        : 0.0;
    return GameResultsScreen(
      gameIcon: '🪷',
      title: 'Mandala Complete!',
      performance: accuracy,
      score: (accuracy * 1000.0).round(),
      scoreLabel: 'Mirror Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat(
            'Accuracy', '${(accuracy * 100).round()}%'),
        GameResultStat(
            'Cells', '$_totalCorrect/$_totalCells'),
        GameResultStat(
            'Rounds', '$_totalRounds'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

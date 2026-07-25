import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class TileMatchGame extends StatefulWidget {
  const TileMatchGame({super.key});
  @override
  State<TileMatchGame> createState() => _TileMatchGameState();
}

class _TileMatchGameState extends State<TileMatchGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _rows = 6;
  static const _cols = 8;
  static const _totalTiles = _rows * _cols; // 48 tiles, 24 pairs

  static const _tileIcons = [
    '🧘', '🕉️', '🌿', '🌸', '☀️', '🌙', '🔥', '💧',
    '🪷', '🕊️', '🍃', '✨', '🌍', '⭐', '🦋', '🐚',
    '🎋', '🍀', '💎', '🌈', '🌺', '🪨', '🍂', '🌾',
  ];

  // Grid: -1 = cleared, >=0 = icon index
  late List<int> _grid;
  int _selectedIndex = -1;
  int _pairsCleared = 0;
  int _totalPairs = _totalTiles ~/ 2;
  int _hintsUsed = 0;
  bool _started = false;
  bool _showingCountdown = false;
  bool _isDone = false;
  bool _isNewBest = false;
  late Stopwatch _sw;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch();
  }

  void _startGame() {
    // Generate pairs: each icon appears exactly twice
    final pairs = List.generate(_totalPairs, (i) => i);
    final tiles = <int>[...pairs, ...pairs]..shuffle(_rng);
    _grid = tiles;
    _selectedIndex = -1;
    _pairsCleared = 0;
    _hintsUsed = 0;
    _isDone = false;
    _isNewBest = false;
    setState(() {
      _showingCountdown = true;
    });
  }

  void _onCountdownDone() {
    _sw..reset()..start();
    setState(() {
      _showingCountdown = false;
      _started = true;
    });
  }

  bool _isTileFree(int index) {
    if (_grid[index] < 0) {
      return false;
    }
    final row = index ~/ _cols;
    final col = index % _cols;

    // A tile is free if at least one horizontal side is clear
    // Left side: all tiles to the left are cleared
    bool leftFree = true;
    for (int c = col - 1; c >= 0; c--) {
      if (_grid[row * _cols + c] >= 0) {
        leftFree = false;
        break;
      }
    }
    // Right side: all tiles to the right are cleared
    bool rightFree = true;
    for (int c = col + 1; c < _cols; c++) {
      if (_grid[row * _cols + c] >= 0) {
        rightFree = false;
        break;
      }
    }
    return leftFree || rightFree;
  }

  void _onTapTile(int index) {
    if (!_started || _isDone) {
      return;
    }
    if (_grid[index] < 0) {
      return;
    }
    if (!_isTileFree(index)) {
      GameHaptics.wrong();
      return;
    }

    if (_selectedIndex < 0) {
      // First selection
      setState(() {
        _selectedIndex = index;
      });
      GameHaptics.tap();
    } else if (_selectedIndex == index) {
      // Deselect
      setState(() {
        _selectedIndex = -1;
      });
    } else if (_grid[_selectedIndex] == _grid[index]) {
      // Match!
      GameHaptics.correct();
      setState(() {
        _grid[_selectedIndex] = -1;
        _grid[index] = -1;
        _selectedIndex = -1;
        _pairsCleared++;
      });
      if (_pairsCleared >= _totalPairs) {
        _finishGame();
      }
    } else {
      // No match — switch selection
      GameHaptics.wrong();
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  void _useHint() {
    if (!_started || _isDone) {
      return;
    }
    // Find a matching pair where at least one is free
    for (int i = 0; i < _grid.length; i++) {
      if (_grid[i] < 0 || !_isTileFree(i)) {
        continue;
      }
      for (int j = i + 1; j < _grid.length; j++) {
        if (_grid[j] == _grid[i] && _isTileFree(j) && i != j) {
          _hintsUsed++;
          if (_selectedIndex >= 0) {
            _grid[_selectedIndex] = -1;
            _grid[j] = -1;
            _pairsCleared++;
            setState(() {
              _selectedIndex = -1;
            });
          } else {
            // Highlight both temporarily
            setState(() {
              _selectedIndex = i;
            });
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) {
                setState(() {
                  _selectedIndex = -1;
                });
              }
            });
          }
          return;
        }
      }
    }
  }

  Future<void> _finishGame() async {
    _sw.stop();
    _isDone = true;
    _started = false;

    final timeSec = _sw.elapsedMilliseconds / 1000.0;
    // Score: base 500 + speed bonus - hint penalty
    final finalScore =
        (500.0 + max(0.0, 300.0 - timeSec * 2.0) - _hintsUsed * 30.0)
            .clamp(0.0, 1000.0);

    await _service.saveScore(
      gameType: 'tile_match',
      score: finalScore,
      accuracy: max(0.0, 1.0 - _hintsUsed * 0.1),
      roundsCompleted: _pairsCleared,
      metadata: {
        'pairs': _pairsCleared,
        'hints': _hintsUsed,
        'time_sec': timeSec.round(),
      },
    );
    _isNewBest =
        await _service.submitLocalBest('tile_match', finalScore);
    await _service.addXp(
        15 + ((finalScore / 1000.0) * 25.0).round());
    if (mounted) {
      setState(() {});
    }
  }

  Color _tileBorder(int index) {
    if (_selectedIndex == index) {
      return GameColors.gold;
    }
    if (!_isTileFree(index)) {
      return GameTheme.primary(context).withValues(alpha: 0.1);
    }
    return GameTheme.primary(context).withValues(alpha: 0.25);
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
          'Tile Match',
          style: TextStyle(
            color: GameTheme.textPrimary(context),
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_started && !_isDone)
            IconButton(
              icon: Icon(Icons.lightbulb_outline_rounded,
                  color: GameColors.gold),
              onPressed: _useHint,
              tooltip: 'Hint',
            ),
        ],
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
            Text('🀄', style: TextStyle(fontSize: 54.sp)),
            SizedBox(height: 3.h),
            Text('Tile Match', style: GameTheme.heading(ctx, size: 26)),
            SizedBox(height: 2.h),
            Text(
              'Match pairs of identical tiles.\nTiles must have a clear path\non at least one side.\n$_totalPairs pairs to clear!',
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
          // Header
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Cleared: $_pairsCleared/$_totalPairs',
                  style: TextStyle(
                    color: GameTheme.textSecondary(ctx),
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Hints: $_hintsUsed',
                  style: TextStyle(
                    color: GameTheme.accent(ctx),
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
                aspectRatio: _cols / _rows,
                child: Container(
                  margin: EdgeInsets.all(2.w),
                  decoration: BoxDecoration(
                    color: GameTheme.surface(ctx).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: _cols,
                    ),
                    itemCount: _totalTiles,
                    itemBuilder: (_, idx) {
                      if (_grid[idx] < 0) {
                        return const SizedBox.shrink();
                      }
                      final iconIdx = _grid[idx];
                      final isSelected = _selectedIndex == idx;
                      final isFree = _isTileFree(idx);

                      return GestureDetector(
                        onTap: () => _onTapTile(idx),
                        child: AnimatedContainer(
                          duration:
                              const Duration(milliseconds: 200),
                          margin: EdgeInsets.all(0.3.w),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? GameColors.gold.withValues(alpha: 0.2)
                                : GameTheme.primary(ctx)
                                    .withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _tileBorder(idx),
                              width: isSelected ? 2.5 : 1.5,
                            ),
                          ),
                          child: Opacity(
                            opacity: isFree ? 1.0 : 0.45,
                            child: Center(
                              child: Text(
                                _tileIcons[iconIdx],
                                style: TextStyle(fontSize: 18.sp),
                              ),
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
              'Tap a tile, then tap its matching pair',
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
    final timeSec = _sw.elapsedMilliseconds / 1000.0;
    return GameResultsScreen(
      gameIcon: '🀄',
      title: 'Board Cleared!',
      performance: max(0.0, 1.0 - _hintsUsed * 0.1)
          .clamp(0.0, 1.0),
      score: (500.0 +
              max(0.0, 300.0 - timeSec * 2.0) -
              _hintsUsed * 30.0)
          .clamp(0.0, 1000.0)
          .round(),
      scoreLabel: 'Match Score',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Pairs', '$_pairsCleared/$_totalPairs'),
        GameResultStat('Time', '${timeSec.round()}s'),
        GameResultStat('Hints', '$_hintsUsed'),
      ],
      onRetry: _startGame,
      onDone: () => Navigator.pop(context),
    );
  }
}

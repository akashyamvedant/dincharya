import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class FlowFreeGame extends StatefulWidget {
  const FlowFreeGame({super.key});
  @override
  State<FlowFreeGame> createState() => _FlowFreeGameState();
}

class _FlowFreeGameState extends State<FlowFreeGame> {
  final _service = MindGamesService();

  // Levels: grid size → color pairs
  static const _levels = [
    (5, 5),   // 5x5, 5 pairs
    (6, 7),   // 6x6, 7 pairs
    (7, 9),   // 7x7, 9 pairs
  ];
  int _levelIdx = 0;

  int get _size => _levels[_levelIdx].$1;
  int get _pairs => _levels[_levelIdx].$2;

  final _palette = GameColors.chakras;

  // Cells: -1 = empty, >=0 = color index
  late List<List<int>> _grid;
  // Endpoints: (r1, c1) and (r2, c2) for each color
  late List<(int, int)> _end1, _end2;
  // Paths drawn so far: for each color, list of (r,c)
  late List<List<(int, int)>> _paths;
  int _selectedColor = -1;

  int _score = 0, _moves = 0;
  bool _started = false, _done = false, _showingCountdown = false;
  bool _isNewBest = false;
  late Stopwatch _sw;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch();
    _generateLevel();
  }

  void _generateLevel() {
    final rng = Random();
    _grid = List.generate(_size, (_) => List.filled(_size, -1));
    _end1 = [];
    _end2 = [];
    _paths = List.generate(_pairs, (_) => []);

    // Place endpoints randomly with minimum distance
    for (int c = 0; c < _pairs; c++) {
      int r1, c1, r2, c2;
      do {
        r1 = rng.nextInt(_size);
        c1 = rng.nextInt(_size);
        r2 = rng.nextInt(_size);
        c2 = rng.nextInt(_size);
      } while (_grid[r1][c1] != -1 || _grid[r2][c2] != -1 ||
          (r1 == r2 && c1 == c2) || (r1 - r2).abs() + (c1 - c2).abs() < 3);

      _grid[r1][c1] = c;
      _grid[r2][c2] = c;
      _end1.add((r1, c1));
      _end2.add((r2, c2));
    }
  }

  void _start() {
    _generateLevel();
    _paths = List.generate(_pairs, (_) => []);
    _selectedColor = -1;
    _score = 0;
    _moves = 0;
    _done = false;
    setState(() => _showingCountdown = true);
  }

  void _countdownDone() {
    _sw..reset()..start();
    setState(() { _showingCountdown = false; _started = true; });
  }

  void _selectColor(int color) {
    if (!_started || _done) return;
    setState(() {
      if (_selectedColor == color) {
        // Deselect — reset this color's path
        _paths[color] = [];
        _refreshGrid();
        _moves++;
        _selectedColor = -1;
      } else {
        _selectedColor = color;
      }
    });
  }

  void _onTapCell(int r, int c) {
    if (!_started || _done || _selectedColor < 0) return;

    final color = _selectedColor;
    final path = _paths[color];

    if (_grid[r][c] == color) {
      // If tapping an endpoint
      if (path.isEmpty) {
        // Start path
        path.add((r, c));
        _refreshGrid();
      } else if (path.length > 1 &&
          (r == _end2[color].$1 && c == _end2[color].$2)) {
        // Finished connecting
        _refreshGrid();
        GameHaptics.correct();
        _moves++;
        _selectedColor = -1;
        // Check if all pairs connected
        if (_checkComplete()) _finish();
      } else if ((r, c) == path.last && path.length > 1) {
        // Tapping current end — deselect
        _selectedColor = -1;
      }
      return;
    }

    if (_grid[r][c] != -1) return; // Cell occupied

    // Add to path if adjacent to last cell
    if (path.isEmpty) return;
    final last = path.last;
    final dr = (r - last.$1).abs(), dc = (c - last.$2).abs();
    if (dr + dc != 1) return; // Must be adjacent

    path.add((r, c));
    _refreshGrid();
    _moves++;
  }

  void _refreshGrid() {
    // Reset grid
    _grid = List.generate(_size, (_) => List.filled(_size, -1));
    // Place endpoints
    for (int c = 0; c < _pairs; c++) {
      _grid[_end1[c].$1][_end1[c].$2] = c;
      _grid[_end2[c].$1][_end2[c].$2] = c;
    }
    // Place paths (skip endpoints to avoid overwriting)
    for (int c = 0; c < _pairs; c++) {
      for (final p in _paths[c]) {
        _grid[p.$1][p.$2] = c;
      }
    }
  }

  bool _checkComplete() {
    for (int c = 0; c < _pairs; c++) {
      final path = _paths[c];
      if (path.length < 2) return false;
      if (path.last != _end2[c] || path.first != _end1[c]) return false;
    }
    // Check all cells filled
    for (int r = 0; r < _size; r++)
      for (int c = 0; c < _size; c++)
        if (_grid[r][c] == -1) return false;
    return true;
  }

  Future<void> _finish() async {
    _sw.stop();
    _done = true;
    _started = false;

    final timeSec = _sw.elapsedMilliseconds / 1000;
    final perfScore = max(0, 1000 - timeSec * 2 - _moves).round();

    await _service.saveScore(
        gameType: 'flow_free', score: perfScore.toDouble(),
        accuracy: _pairs / (_moves > 0 ? _moves : 1),
        roundsCompleted: _pairs,
        metadata: {'level': _size, 'pairs': _pairs, 'moves': _moves});
    _isNewBest = await _service.submitLocalBest('flow_free', perfScore.toDouble());
    await _service.addXp(20 + _pairs * 2);
    if (mounted) setState(() {});
  }

  void _nextLevel() {
    if (_levelIdx < _levels.length - 1) _levelIdx++;
    _start();
  }

  Color _pathColor(int idx) => _palette[idx % _palette.length];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(
        backgroundColor: GameTheme.bg(context), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        title: Text('Flow Free', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true,
      ),
      body: Stack(children: [
        if (!_started && !_done && !_showingCountdown) _startScreen(context),
        if (_showingCountdown) GameCountdown(onDone: _countdownDone),
        if (_started) _gameView(context),
        if (_done) _resultScreen(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🔗', style: TextStyle(fontSize: 54.sp)), SizedBox(height: 3.h),
    Text('Flow Free', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Connect matching colors without\ncrossing paths. Fill the entire board!\n${_size}x${_size} grid · $_pairs pairs',
        textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp, height: 1.6)),
    if (_levelIdx > 0) ...[
      SizedBox(height: 2.h),
      Text('Level ${_levelIdx + 1}/${_levels.length}', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 15.sp, fontWeight: FontWeight.w600)),
    ],
    SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.6.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _gameView(BuildContext ctx) {
    return SafeArea(child: Column(children: [
      Padding(padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Moves: $_moves', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
          Text('Level ${_levelIdx + 1}', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 14.sp, fontWeight: FontWeight.bold)),
          Container(padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h), decoration: BoxDecoration(color: GameTheme.primary(ctx).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text('$_size x $_size', style: TextStyle(color: GameTheme.primary(ctx), fontSize: 12.sp, fontWeight: FontWeight.w600))),
        ])),
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              margin: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: GameTheme.surface(ctx).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.15)),
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _size),
                itemCount: _size * _size,
                itemBuilder: (_, idx) {
                  final r = idx ~/ _size, c = idx % _size;
                  final cellColor = _grid[r][c];
                  final isEndpoint = cellColor >= 0 &&
                      ((r == _end1[cellColor].$1 && c == _end1[cellColor].$2) ||
                       (r == _end2[cellColor].$1 && c == _end2[cellColor].$2));
                  final isSelected = _selectedColor >= 0 && cellColor == _selectedColor;

                  return GestureDetector(
                    onTap: () => _onTapCell(r, c),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.08)),
                      ),
                      child: Center(
                        child: cellColor >= 0
                            ? Container(
                                width: isEndpoint ? 70.0 : 20.0,
                                height: isEndpoint ? 70.0 : 20.0,
                                decoration: BoxDecoration(
                                  color: _pathColor(cellColor),
                                  shape: isEndpoint ? BoxShape.circle : BoxShape.circle,
                                  border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                  boxShadow: isEndpoint ? [
                                    BoxShadow(color: _pathColor(cellColor).withValues(alpha: 0.5), blurRadius: 4)
                                  ] : null,
                                ),
                              )
                            : _selectedColor >= 0
                                ? Icon(Icons.circle, size: 8.sp, color: GameTheme.primary(ctx).withValues(alpha: 0.15))
                                : null,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
      // Color legend
      Container(
        padding: EdgeInsets.all(2.w),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_pairs, (i) {
          final done = _paths[i].length >= 2 &&
              _paths[i].first == _end1[i] &&
              _paths[i].last == _end2[i];
          return GestureDetector(
            onTap: () => _selectColor(i),
            child: Container(
              width: 10.w, height: 10.w,
              margin: EdgeInsets.symmetric(horizontal: 1.w),
              decoration: BoxDecoration(
                color: done ? GameColors.successGreen : _pathColor(i),
                shape: BoxShape.circle,
                border: _selectedColor == i ? Border.all(color: Colors.white, width: 2.5) : null,
                boxShadow: _selectedColor == i ? [BoxShadow(color: _pathColor(i).withValues(alpha: 0.6), blurRadius: 8)] : null,
              ),
            ),
          );
        })),
      ),
      Text('Select color → tap to draw path', style: TextStyle(color: GameTheme.textMuted(ctx), fontSize: 11.sp)),
      SizedBox(height: 1.h),
    ]));
  }

  Widget _resultScreen(BuildContext ctx) {
    final timeSec = _sw.elapsedMilliseconds / 1000;
    final completed = _checkComplete();
    return GameResultsScreen(
      gameIcon: '🔗', title: completed ? 'Board Complete!' : 'Level Done',
      performance: completed ? 1.0 : 0.5,
      score: _score > 0 ? _score : (_checkComplete() ? 100 : 50),
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Time', '${timeSec.toStringAsFixed(0)}s'),
        GameResultStat('Moves', '$_moves'),
        GameResultStat('Pairs', '$_pairs'),
      ],
      onRetry: _start,
      onDone: () {
        if (_levelIdx < _levels.length - 1) _nextLevel();
        Navigator.pop(context);
      },
    );
  }
}

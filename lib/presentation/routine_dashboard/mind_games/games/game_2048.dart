import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class Game2048 extends StatefulWidget {
  const Game2048({super.key});

  @override
  State<Game2048> createState() => _Game2048State();
}

class _Game2048State extends State<Game2048> {
  final MindGamesService _service = MindGamesService();
  final _rng = Random();
  late List<List<int>> _grid;
  int _score = 0, _moves = 0, _bestTile = 0;
  bool _isPlaying = false, _isGameOver = false;
  bool _showingCountdown = false, _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _initGrid();
  }

  void _initGrid() {
    _grid = List.generate(4, (_) => List.filled(4, 0));
    _score = 0;
    _moves = 0;
    _bestTile = 0;
    _isGameOver = false;
    _isNewBest = false;
  }

  void _startGame() {
    setState(() {
      _initGrid();
      _addRandomTile();
      _addRandomTile();
      _showingCountdown = true;
    });
  }

  void _onCountdownDone() {
    setState(() {
      _showingCountdown = false;
      _isPlaying = true;
    });
  }

  void _addRandomTile() {
    final empty = <int>[];
    for (int i = 0; i < 16; i++) {
      if (_grid[i ~/ 4][i % 4] == 0) empty.add(i);
    }
    if (empty.isNotEmpty) {
      final idx = empty[_rng.nextInt(empty.length)];
      _grid[idx ~/ 4][idx % 4] = _rng.nextDouble() < 0.9 ? 2 : 4;
    }
  }

  // ── Merge logic: merge into a list of non-zero values, then pad ──
  List<int> _mergeRow(List<int> row, bool reverse) {
    final values = row.where((v) => v != 0).toList();

    final merged = <int>[];
    if (reverse) {
      // Merge from right to left
      int i = values.length - 1;
      while (i >= 0) {
        if (i > 0 && values[i] == values[i - 1]) {
          final val = values[i] * 2;
          merged.insert(0, val);
          _score += val;
          if (val > _bestTile) _bestTile = val;
          GameHaptics.correct();
          i -= 2;
        } else {
          merged.insert(0, values[i]);
          i--;
        }
      }
      while (merged.length < 4) merged.insert(0, 0);
    } else {
      // Merge from left to right
      int i = 0;
      while (i < values.length) {
        if (i + 1 < values.length && values[i] == values[i + 1]) {
          final val = values[i] * 2;
          merged.add(val);
          _score += val;
          if (val > _bestTile) _bestTile = val;
          GameHaptics.correct();
          i += 2;
        } else {
          merged.add(values[i]);
          i++;
        }
      }
      while (merged.length < 4) merged.add(0);
    }
    return merged;
  }

  bool _linesEqual(List<int> a, List<int> b) {
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _handleSwipe(Offset delta) {
    if (!_isPlaying || _isGameOver) return;

    final dx = delta.dx.abs();
    final dy = delta.dy.abs();
    if (dx + dy < 10) return;

    bool moved = false;
    if (dx > dy) {
      // Horizontal
      for (int r = 0; r < 4; r++) {
        final old = List<int>.from(_grid[r]);
        _grid[r] = _mergeRow(old, delta.dx > 0);
        if (!_linesEqual(old, _grid[r])) moved = true;
      }
    } else {
      // Vertical
      for (int c = 0; c < 4; c++) {
        final col = [_grid[0][c], _grid[1][c], _grid[2][c], _grid[3][c]];
        final merged = _mergeRow(col, delta.dy > 0);
        for (int r = 0; r < 4; r++) {
          if (_grid[r][c] != merged[r]) moved = true;
          _grid[r][c] = merged[r];
        }
      }
    }

    if (moved) {
      setState(() {
        _moves++;
        _addRandomTile();
        if (_isBoardFull() && !_hasMoves()) {
          _finishGame();
        }
      });
    }
  }

  bool _isBoardFull() {
    for (final row in _grid) {
      if (row.contains(0)) return false;
    }
    return true;
  }

  bool _hasMoves() {
    for (int r = 0; r < 4; r++) {
      for (int c = 0; c < 4; c++) {
        if (c < 3 && _grid[r][c] == _grid[r][c + 1]) return true;
        if (r < 3 && _grid[r][c] == _grid[r + 1][c]) return true;
      }
    }
    return false;
  }

  Future<void> _finishGame() async {
    _isPlaying = false;
    _isGameOver = true;
    if (mounted) setState(() {});

    final perf = (_score / 2048).clamp(0.0, 1.0);
    await _service.saveScore(
      gameType: 'game_2048',
      score: _score.toDouble(),
      roundsCompleted: _moves,
      metadata: {'best_tile': _bestTile},
    );
    _isNewBest = await _service.submitLocalBest('game_2048', _score.toDouble());
    await _service.addXp(10 + (perf * 40).round());
    if (mounted) setState(() {});
  }

  Color _tileColor(int v) {
    if (v == 0) return GameTheme.surface(context).withValues(alpha: 0.35);
    final p = (log(v) / log(2)).round();
    final colors = [
      const Color(0xFFEDE0C8), const Color(0xFFF2B179), const Color(0xFFF59563),
      const Color(0xFFF67C5F), const Color(0xFFF65E3B), const Color(0xFFEDCF72),
      const Color(0xFFEDCC61), const Color(0xFFEDC850), const Color(0xFFEDC53F),
      const Color(0xFFEDC22E), const Color(0xFF3C3A32), const Color(0xFF2B2B2B),
    ];
    return colors[(p - 1).clamp(0, colors.length - 1)];
  }

  Color _tileTextColor(int v) =>
      v <= 4 ? const Color(0xFF776E65) : const Color(0xFFF9F6F2);

  BoxShadow? _tileShadow(int v) {
    if (v <= 4) return null;
    return BoxShadow(
        color: _tileColor(v).withValues(alpha: 0.5),
        blurRadius: 8, offset: const Offset(0, 3));
  }

  double _tileFontSize(int v) {
    if (v < 100) return 24;
    if (v < 1000) return 20;
    return 16;
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
        title: Text('2048',
            style: TextStyle(
                color: GameTheme.textPrimary(context),
                fontSize: 16.sp,
                fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          if (!_isPlaying && !_isGameOver && !_showingCountdown)
            GameStartScreen(
              icon: '🧩',
              title: '2048 Puzzle',
              description:
                  'Swipe to merge tiles with the same number.\nReach 2048 tile or go beyond!',
              onStart: _startGame,
            ),
          if (_showingCountdown) GameCountdown(onDone: _onCountdownDone),
          if (_isPlaying) _buildBoard(),
          if (_isGameOver)
            GameResultsScreen(
              gameIcon: '🧩',
              title: 'Game Over!',
              performance: (_score / 2048).clamp(0.0, 1.0),
              score: _score,
              isNewBest: _isNewBest,
              stats: [
                GameResultStat('Moves', '$_moves'),
                GameResultStat('Best Tile', '$_bestTile'),
              ],
              onRetry: _startGame,
              onDone: () => Navigator.pop(context),
            ),
        ],
      ),
    );
  }

  Widget _buildBoard() {
    return GestureDetector(
      onPanEnd: (d) => _handleSwipe(d.velocity.pixelsPerSecond),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Score bar
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 6.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _scoreBox('Score', '$_score'),
                  _scoreBox('Best', '$_bestTile'),
                  _scoreBox('Moves', '$_moves'),
                ],
              ),
            ),
            SizedBox(height: 3.h),
            // Board
            Container(
              width: 88.w,
              height: 88.w,
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: const Color(0xFFBBADA0),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFBBADA0).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: 16,
                itemBuilder: (_, i) {
                  final r = i ~/ 4, c = i % 4, v = _grid[r][c];
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: _tileColor(v),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _tileShadow(v) != null
                          ? [_tileShadow(v)!]
                          : null,
                    ),
                    child: Center(
                      child: v == 0
                          ? null
                          : Text('$v',
                              style: TextStyle(
                                color: _tileTextColor(v),
                                fontSize: _tileFontSize(v).sp,
                                fontWeight: FontWeight.w900,
                              )),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 3.h),
            Text('Swipe to move tiles',
                style: TextStyle(
                    color: GameTheme.textMuted(context), fontSize: 11.sp, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _scoreBox(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [const Color(0xFF8F7A66), const Color(0xFF6D5D4B)],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: const Color(0xFF8F7A66).withValues(alpha: 0.3), blurRadius: 8)],
      ),
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: const Color(0xFFEEE4DA).withValues(alpha: 0.8), fontSize: 9.sp, fontWeight: FontWeight.w700, letterSpacing: 1)),
          SizedBox(height: 0.3.h),
          Text(value,
              style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

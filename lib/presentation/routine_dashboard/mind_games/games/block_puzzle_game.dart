import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class BlockPuzzleGame extends StatefulWidget {
  const BlockPuzzleGame({super.key});
  @override
  State<BlockPuzzleGame> createState() => _BlockPuzzleGameState();
}

class _BlockPuzzleGameState extends State<BlockPuzzleGame> {
  final _service = MindGamesService(), _rng = Random();
  static const _rows = 8, _cols = 8;

  // Board: null = empty, Color = filled
  List<List<Color?>> _board = [];
  int _score = 0, _clears = 0;
  List<bool>? _preview;
  int? _previewRow, _previewCol;

  // Available pieces (3 at a time)
  List<List<List<bool>>> _pieces = [];
  int _selectedPiece = -1;

  final _pieceColors = GameColors.chakras;

  // Standard tetromino-like pieces
  static const _allShapes = [
    [1, 1, 1, 1],               // I (4)
    [1,1, 1,1],                 // O (2x2)
    [0,1,0, 1,1,1],             // T
    [1,0, 1,0, 1,1],            // L
    [0,1, 0,1, 1,1],            // J
    [1,1,0, 0,1,1],             // S
    [0,1,1, 1,1,0],             // Z
    [1],                        // dot
    [1,1],                      // 2 horizontal
  ];

  bool _started = false, _done = false, _gameOver = false;
  bool _showingCountdown = false, _isNewBest = false;

  @override
  void initState() {
    super.initState();
    _resetBoard();
  }

  void _resetBoard() {
    _board = List.generate(_rows, (_) => List.filled(_cols, null));
    _score = 0; _clears = 0; _gameOver = false;
    _selectedPiece = -1;
    _preview = null;
    _previewRow = null; _previewCol = null;
  }

  void _start() {
    _resetBoard();
    _pieces = List.generate(3, (_) => _randomPiece());
    _selectedPiece = -1;
    _preview = null; _previewRow = null; _previewCol = null;
    setState(() => _showingCountdown = true);
  }

  void _countdownDone() => setState(() { _showingCountdown = false; _started = true; });

  List<List<bool>> _randomPiece() {
    final shape = _allShapes[_rng.nextInt(_allShapes.length)];
    // Determine dimensions
    int w = 1, h = 1;
    if (shape.length == 4) { w = 4; h = 1; }
    else if (shape.length == 2) { w = 2; h = 1; }
    else if (shape.length == 1) { w = 1; h = 1; }
    else if (shape.length == 6) { w = 3; h = 2; }

    final grid = List.generate(h, (_) => List.filled(w, false));
    for (int i = 0; i < shape.length; i++) {
      if (shape[i] == 1) {
        grid[i ~/ w][i % w] = true;
      }
    }
    // Random rotate
    if (_rng.nextBool()) {
      // Rotate 90
      final nw = h, nh = w;
      final rotated = List.generate(nh, (r) => List.filled(nw, false));
      for (int r = 0; r < h; r++)
        for (int c = 0; c < w; c++) {
          rotated[c][nw - 1 - r] = grid[r][c];
        }
      return rotated;
    }
    return grid;
  }

  void _selectPiece(int idx) {
    if (!_started || _gameOver) return;
    setState(() {
      if (_selectedPiece == idx) {
        _selectedPiece = -1;
        _preview = null;
      } else {
        _selectedPiece = idx;
        _preview = null; _previewRow = null; _previewCol = null;
      }
    });
  }

  void _onTapCell(int row, int col) {
    if (!_started || _gameOver || _selectedPiece < 0) return;

    final piece = _pieces[_selectedPiece];
    final h = piece.length, w = piece[0].length;

    // Try to place piece with its top-left at (row, col)
    if (!_canPlace(piece, row, col)) {
      GameHaptics.wrong();
      return;
    }
    _placePiece(piece, row, col, _pieceColors[_selectedPiece % _pieceColors.length]);
    GameHaptics.correct();

    // Remove piece and check for new one
    setState(() {
      _pieces[_selectedPiece] = _randomPiece();
      _selectedPiece = -1;
      _preview = null;
      _checkLines();
      if (!_hasMoves()) {
        _gameOver = true;
        _started = false;
        GameHaptics.wrong();
        _finish();
      }
    });
  }

  void _onHoverCell(int row, int col) {
    if (_selectedPiece < 0 || _gameOver) return;
    final piece = _pieces[_selectedPiece];
    setState(() {
      _previewRow = row; _previewCol = col;
      _preview = _canPlace(piece, row, col)
          ? _buildPreview(piece, row, col)
          : null;
    });
  }

  List<bool> _buildPreview(List<List<bool>> piece, int row, int col) {
    final h = piece.length, w = piece[0].length;
    final flat = <bool>[];
    for (int r = 0; r < _rows; r++) {
      for (int c = 0; c < _cols; c++) {
        final pr = r - row, pc = c - col;
        flat.add(pr >= 0 && pr < h && pc >= 0 && pc < w && piece[pr][pc]);
      }
    }
    return flat;
  }

  bool _canPlace(List<List<bool>> piece, int row, int col) {
    final h = piece.length, w = piece[0].length;
    for (int r = 0; r < h; r++) {
      for (int c = 0; c < w; c++) {
        if (!piece[r][c]) continue;
        final br = row + r, bc = col + c;
        if (br < 0 || br >= _rows || bc < 0 || bc >= _cols) return false;
        if (_board[br][bc] != null) return false;
      }
    }
    return true;
  }

  void _placePiece(List<List<bool>> piece, int row, int col, Color color) {
    final h = piece.length, w = piece[0].length;
    for (int r = 0; r < h; r++)
      for (int c = 0; c < w; c++) {
        if (piece[r][c]) _board[row + r][col + c] = color;
      }
    _score += piece.expand((r) => r).where((b) => b).length;
  }

  void _checkLines() {
    // Rows
    for (int r = _rows - 1; r >= 0; r--) {
      if (_board[r].every((c) => c != null)) {
        _score += 10; _clears++;
        for (int rr = r; rr > 0; rr--) {
          _board[rr] = List<Color?>.from(_board[rr - 1]);
        }
        _board[0] = List.filled(_cols, null);
      }
    }
    // Columns
    for (int c = _cols - 1; c >= 0; c--) {
      if (List.generate(_rows, (r) => _board[r][c]).every((x) => x != null)) {
        _score += 10; _clears++;
        for (int cc = c; cc > 0; cc--)
          for (int r = 0; r < _rows; r++) {
            _board[r][cc] = _board[r][cc - 1];
          }
        for (int r = 0; r < _rows; r++) {
          _board[r][0] = null;
        }
      }
    }
  }

  bool _hasMoves() {
    for (final piece in _pieces) {
      for (int r = 0; r < _rows; r++)
        for (int c = 0; c < _cols; c++) {
          if (_canPlace(piece, r, c)) return true;
        }
    }
    return false;
  }

  Future<void> _finish() async {
    final perf = (_score / 100).clamp(0.0, 1.0);
    await _service.saveScore(gameType: 'block_puzzle', score: _score.toDouble(),
        roundsCompleted: _clears, metadata: {'fills': _score});
    _isNewBest = await _service.submitLocalBest('block_puzzle', _score.toDouble());
    await _service.addXp(10 + (perf * 30).round());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        title: Text('Block Puzzle', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: Stack(children: [
        if (!_started && !_gameOver && !_showingCountdown) _startScreen(context),
        if (_showingCountdown) GameCountdown(onDone: _countdownDone),
        if (_started) _gameView(context),
        if (_gameOver && !_started) _resultScreen(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🧱', style: TextStyle(fontSize: 54.sp)), SizedBox(height: 3.h),
    Text('Block Puzzle', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Select a piece, then tap the board\nto place it. Fill rows or columns\nto clear them and score points!',
        textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp, height: 1.6)),
    SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.6.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _gameView(BuildContext ctx) {
    return SafeArea(child: Column(children: [
      // Score
      Padding(padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Score: $_score', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 16.sp, fontWeight: FontWeight.bold)),
          Text('Clears: $_clears', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
        ])),
      // Board
      Expanded(
        child: Center(
          child: AspectRatio(
            aspectRatio: _cols / _rows,
            child: GestureDetector(
              onTapDown: (d) {
                final rSize = (context.findRenderObject() as RenderBox).size;
                final cellW = rSize.width / _cols, cellH = rSize.height / _rows;
                final local = d.localPosition;
                if (local.dx < 0 || local.dy < 0) return;
                final col = (local.dx / cellW).floor();
                final row = (local.dy / cellH).floor();
                if (row >= 0 && row < _rows && col >= 0 && col < _cols) {
                  _onTapCell(row, col);
                }
              },
              onTapUp: (_) => setState(() { _preview = null; }),
              child: Container(
                margin: EdgeInsets.all(2.w),
                decoration: BoxDecoration(
                  color: GameTheme.surface(ctx).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.2)),
                ),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _cols),
                  itemCount: _rows * _cols,
                  itemBuilder: (_, idx) {
                    final r = idx ~/ _cols, c = idx % _cols;
                    final cellColor = _board[r][c];
                    final isPreview = _preview != null && _preview!.length > idx && _preview![idx];
                    return Container(
                      decoration: BoxDecoration(
                        color: cellColor ?? (isPreview ? GameTheme.accent(ctx).withValues(alpha: 0.4) : Colors.transparent),
                        border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.08)),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
      // Piece tray
      Container(
        padding: EdgeInsets.all(3.w),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: List.generate(_pieces.length, (i) {
          final piece = _pieces[i];
          final selected = _selectedPiece == i;
          return GestureDetector(
            onTap: () => _selectPiece(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: selected ? GameTheme.primary(ctx).withValues(alpha: 0.12) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: selected ? GameTheme.primary(ctx) : GameTheme.textMuted(ctx).withValues(alpha: 0.3), width: selected ? 2 : 1),
              ),
              child: _pieceWidget(piece, _pieceColors[i % _pieceColors.length]),
            ),
          );
        })),
      ),
      Text('Select a piece → tap board', style: TextStyle(color: GameTheme.textMuted(ctx), fontSize: 11.sp)),
      SizedBox(height: 1.h),
    ]));
  }

  Widget _pieceWidget(List<List<bool>> piece, Color color) {
    final h = piece.length, w = piece[0].length;
    return Column(mainAxisSize: MainAxisSize.min, children: List.generate(h, (r) =>
      Row(mainAxisSize: MainAxisSize.min, children: List.generate(w, (c) =>
        Container(width: 5.w, height: 5.w, decoration: BoxDecoration(
          color: piece[r][c] ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(2),
        )),
      )),
    ));
  }

  Widget _resultScreen(BuildContext ctx) {
    return GameResultsScreen(
      gameIcon: '🧱', title: 'Game Over!',
      performance: (_score / 100).clamp(0.0, 1.0),
      score: _score, isNewBest: _isNewBest,
      stats: [
        GameResultStat('Clears', '$_clears'),
        GameResultStat('Blocks', '$_score'),
      ],
      onRetry: _start, onDone: () => Navigator.pop(context),
    );
  }
}

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class SudokuGame extends StatefulWidget {
  const SudokuGame({super.key});
  @override
  State<SudokuGame> createState() => _SudokuGameState();
}

class _SudokuGameState extends State<SudokuGame> {
  final _service = MindGamesService(), _rng = Random();
  static const _n = 9, _sub = 3;

  late List<List<int>> _solution, _puzzle, _player;
  late List<List<bool>> _fixed;
  int _score = 0, _mistakes = 0, _hintsUsed = 0;
  int? _selectedRow, _selectedCol;
  bool _started = false, _done = false, _showingCountdown = false;
  bool _isNewBest = false;
  late Stopwatch _sw;

  final _difficulties = {'Easy': 38, 'Medium': 30, 'Hard': 24};
  String _difficulty = 'Medium';
  int get _clues => _difficulties[_difficulty]!;

  @override
  void initState() {
    super.initState();
    _sw = Stopwatch();
    _solution = List.generate(_n, (_) => List.filled(_n, 0));
    _puzzle = List.generate(_n, (_) => List.filled(_n, 0));
    _player = List.generate(_n, (_) => List.filled(_n, 0));
    _fixed = List.generate(_n, (_) => List.filled(_n, false));
  }

  bool _safe(List<List<int>> g, int r, int c, int v) {
    for (int i = 0; i < _n; i++)
      if (g[r][i] == v || g[i][c] == v) return false;
    final br = (r ~/ _sub) * _sub, bc = (c ~/ _sub) * _sub;
    for (int i = br; i < br + _sub; i++)
      for (int j = bc; j < bc + _sub; j++)
        if (g[i][j] == v) return false;
    return true;
  }

  bool _fill(List<List<int>> g) {
    for (int r = 0; r < _n; r++) {
      for (int c = 0; c < _n; c++) {
        if (g[r][c] == 0) {
          final nums = List.generate(_n, (i) => i + 1)..shuffle(_rng);
          for (final v in nums) {
            if (_safe(g, r, c, v)) {
              g[r][c] = v;
              if (_fill(g)) return true;
              g[r][c] = 0;
            }
          }
          return false;
        }
      }
    }
    return true;
  }

  void _generate() {
    _solution = List.generate(_n, (_) => List.filled(_n, 0));
    _fill(_solution);
    _puzzle = _solution.map((row) => List<int>.from(row)).toList();

    final all = <int>[];
    for (int i = 0; i < _n * _n; i++) all.add(i);
    all.shuffle(_rng);
    int removed = 0;
    for (final idx in all) {
      if (removed >= _n * _n - _clues) break;
      final r = idx ~/ _n, c = idx % _n;
      _puzzle[r][c] = 0;
      removed++;
    }

    _player = _solution.map((row) => List<int>.from(row)).toList();
    for (int r = 0; r < _n; r++)
      for (int c = 0; c < _n; c++)
        if (_puzzle[r][c] == 0) _player[r][c] = 0;

    _fixed = List.generate(_n, (r) =>
        List.generate(_n, (c) => _puzzle[r][c] != 0));
  }

  void _start() {
    _generate();
    setState(() {
      _score = 0; _mistakes = 0; _hintsUsed = 0;
      _selectedRow = null; _selectedCol = null;
      _done = false; _showingCountdown = true;
    });
  }

  void _countdownDone() {
    _sw..reset()..start();
    setState(() { _showingCountdown = false; _started = true; });
  }

  void _enterNumber(int v) {
    if (!_started || _done) return;
    if (_selectedRow == null || _selectedCol == null) return;
    final r = _selectedRow!, c = _selectedCol!;
    if (_fixed[r][c]) return;

    setState(() {
      _player[r][c] = v;
      if (v != 0 && v != _solution[r][c]) {
        _mistakes++;
        GameHaptics.wrong();
      } else if (v != 0) {
        GameHaptics.correct();
      }
      if (_checkComplete()) _finish();
    });
  }

  void _useHint() {
    if (!_started || _done) return;
    final empty = <(int, int)>[];
    for (int r = 0; r < _n; r++)
      for (int c = 0; c < _n; c++)
        if (!_fixed[r][c] && _player[r][c] != _solution[r][c])
          empty.add((r, c));
    if (empty.isEmpty) return;
    final (r, c) = empty[_rng.nextInt(empty.length)];
    setState(() {
      _player[r][c] = _solution[r][c];
      _hintsUsed++;
      if (_checkComplete()) _finish();
    });
  }

  bool _checkComplete() {
    for (int r = 0; r < _n; r++)
      for (int c = 0; c < _n; c++)
        if (_player[r][c] != _solution[r][c]) return false;
    return true;
  }

  Future<void> _finish() async {
    _sw.stop();
    _done = true; _started = false;
    final timeSec = _sw.elapsedMilliseconds / 1000;
    final perfScore = max(0, 1000 - (_mistakes * 8) - (_hintsUsed * 15) - timeSec * 0.5);
    final finalScore = perfScore.round();

    await _service.saveScore(
        gameType: 'sudoku', score: finalScore.toDouble(),
        accuracy: _n * _n / (_n * _n + _mistakes),
        roundsCompleted: _n * _n - _clues,
        metadata: {'difficulty': _difficulty, 'mistakes': _mistakes, 'hints': _hintsUsed});
    _isNewBest = await _service.submitLocalBest('sudoku', finalScore.toDouble());
    await _service.addXp(15 + (perfScore / 10).round());
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(
        backgroundColor: GameTheme.bg(context), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        title: Text('Sudoku', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true,
        actions: [
          if (_started)
            IconButton(icon: Icon(Icons.lightbulb_outline_rounded, color: GameColors.gold), onPressed: _hintsUsed < 3 ? _useHint : null, tooltip: 'Hint (${3 - _hintsUsed} left)'),
        ],
      ),
      body: Stack(children: [
        if (!_started && !_done && !_showingCountdown) _startScreen(context),
        if (_showingCountdown) GameCountdown(onDone: _countdownDone),
        if (_started) _gameBoard(context),
        if (_done) _results(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) {
    return SingleChildScrollView(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 8.h),
        Text('📋', style: TextStyle(fontSize: 54.sp)), SizedBox(height: 3.h),
        Text('Sudoku', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
        Text('Fill the grid so every row, column\nand 3×3 box has digits 1-9.',
            textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp, height: 1.5)),
        SizedBox(height: 3.h),
        Text('Difficulty', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp, fontWeight: FontWeight.w600)),
        SizedBox(height: 1.h),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: _difficulties.keys.map((d) {
          final sel = _difficulty == d;
          return Padding(padding: EdgeInsets.symmetric(horizontal: 2.w), child: GestureDetector(
            onTap: () => setState(() => _difficulty = d),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.2.h),
              decoration: BoxDecoration(
                color: sel ? GameTheme.primary(ctx).withValues(alpha: 0.15) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: sel ? GameTheme.primary(ctx) : GameTheme.textMuted(ctx), width: sel ? 2 : 1),
              ),
              child: Text(d, style: TextStyle(color: sel ? GameTheme.primary(ctx) : GameTheme.textSecondary(ctx), fontSize: 14.sp, fontWeight: FontWeight.w600)),
            ),
          ));
        }).toList()),
        SizedBox(height: 4.h),
        SizedBox(width: 70.w, child: ElevatedButton(
          onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.6.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: Text('Start', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)),
        )),
      ]),
    );
  }

  Widget _gameBoard(BuildContext ctx) {
    return SafeArea(
      child: Column(children: [
        // Status bar
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Mistakes: $_mistakes', style: TextStyle(color: _mistakes > 0 ? GameColors.errorRed : GameTheme.textSecondary(ctx), fontSize: 13.sp, fontWeight: FontWeight.w600)),
            Text(_difficulty, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 13.sp, fontWeight: FontWeight.w600)),
            Text('Hints: $_hintsUsed/3', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
          ])),
        // Grid
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: EdgeInsets.all(3.w),
                decoration: BoxDecoration(border: Border.all(color: GameTheme.primary(ctx), width: 2.5), borderRadius: BorderRadius.circular(8)),
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: _n),
                  itemCount: _n * _n,
                  itemBuilder: (_, idx) {
                    final r = idx ~/ _n, c = idx % _n;
                    final sel = _selectedRow == r && _selectedCol == c;
                    final sameRowOrCol = _selectedRow != null && (_selectedRow == r || _selectedCol == c);
                    final sameBox = _selectedRow != null && _selectedCol != null &&
                        r ~/ _sub == _selectedRow! ~/ _sub && c ~/ _sub == _selectedCol! ~/ _sub;
                    return GestureDetector(
                      onTap: () => setState(() { _selectedRow = r; _selectedCol = c; }),
                      child: Container(
                        decoration: BoxDecoration(
                          color: sel ? GameTheme.primary(ctx).withValues(alpha: 0.25)
                              : sameBox ? GameTheme.primary(ctx).withValues(alpha: 0.06)
                              : sameRowOrCol ? GameTheme.primary(ctx).withValues(alpha: 0.03)
                              : Colors.transparent,
                          border: Border(
                            right: BorderSide(color: (c + 1) % _sub == 0 && c < _n - 1 ? GameTheme.primary(ctx).withValues(alpha: 0.5) : GameTheme.primary(ctx).withValues(alpha: 0.12)),
                            bottom: BorderSide(color: (r + 1) % _sub == 0 && r < _n - 1 ? GameTheme.primary(ctx).withValues(alpha: 0.5) : GameTheme.primary(ctx).withValues(alpha: 0.12)),
                          ),
                        ),
                        child: Center(
                          child: _player[r][c] != 0
                              ? Text('${_player[r][c]}',
                                  style: TextStyle(
                                    fontSize: 18.sp, fontWeight: FontWeight.bold,
                                    color: _fixed[r][c]
                                        ? GameTheme.textPrimary(ctx)
                                        : _player[r][c] == _solution[r][c]
                                            ? GameTheme.primary(ctx)
                                            : GameColors.errorRed,
                                  ))
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
        // Number pad
        Container(
          padding: EdgeInsets.all(3.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (int n = 1; n <= 9; n++)
                _numBtn(ctx, n),
              _numBtn(ctx, 0),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _numBtn(BuildContext ctx, int n) {
    return GestureDetector(
      onTap: () => _enterNumber(n),
      child: Container(
        width: 8.w, height: 8.w,
        decoration: BoxDecoration(
          color: n == 0 ? GameTheme.primary(ctx).withValues(alpha: 0.08) : GameTheme.surface(ctx).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.2)),
        ),
        child: Center(
          child: n == 0
              ? Icon(Icons.backspace_outlined, size: 16.sp, color: GameTheme.textSecondary(ctx))
              : Text('$n', style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 15.sp, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _results(BuildContext ctx) {
    final timeSec = _sw.elapsedMilliseconds / 1000;
    final perf = max(0.0, 1.0 - (_mistakes * 0.08) - (_hintsUsed * 0.12));
    return GameResultsScreen(
      gameIcon: '📋', title: 'Puzzle Complete!',
      performance: perf, score: _score,
      scoreLabel: 'Performance',
      isNewBest: _isNewBest,
      stats: [
        GameResultStat('Time', '${timeSec.toStringAsFixed(0)}s'),
        GameResultStat('Mistakes', '$_mistakes'),
        GameResultStat('Hints', '$_hintsUsed'),
      ],
      onRetry: _start, onDone: () => Navigator.pop(context),
    );
  }
}

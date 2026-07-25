// lib/presentation/routine_dashboard/mind_games/games/number_search_game.dart
// 5×5 grid. Find numbers 1→25 as fast as possible.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class NumberSearchGame extends StatefulWidget {
  const NumberSearchGame({super.key});
  @override
  State<NumberSearchGame> createState() => _NumberSearchGameState();
}

class _NumberSearchGameState extends State<NumberSearchGame> {
  final _rng = Random(), _service = MindGamesService();
  late List<int> _grid = List.generate(25, (i) => i + 1);
  int _next = 1, _correct = 0, _wrong = 0;
  bool _started = false;
  final _sw = Stopwatch();
  int _finalMs = 0;

  void _start() { setState(() { _grid.shuffle(_rng); _next = 1; _correct = 0; _wrong = 0; _started = true; _sw..reset()..start(); }); }

  void _tap(int n) {
    if (!_started) return;
    if (n == _next) {
      _correct++;
      if (_next >= 25) { _sw.stop(); _finalMs = _sw.elapsedMilliseconds; _end(); return; }
      _next++; setState(() {});
    } else { _wrong++; setState(() {}); }
  }

  Future<void> _end() async {
    setState(() => _started = false);
    final s = _finalMs == 0 ? _sw.elapsedMilliseconds / 1000 : _finalMs / 1000.0;
    final acc = _correct > 0 ? _correct / (_correct + _wrong) : 0.0;
    await _service.saveScore(gameType: 'number_search', score: s, accuracy: acc, reactionTimeMs: _finalMs == 0 ? _sw.elapsedMilliseconds : _finalMs, roundsCompleted: _correct);
  }

  String _fmt(int ms) { final s = ms ~/ 1000, m = (ms % 1000) ~/ 10; return '$s.${m.toString().padLeft(2, '0')}s'; }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Number Search', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: !_started && _correct == 0 ? _startScrn(context) : _started ? _game(context) : _result(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🔢', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Number Search', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Find numbers 1→25 in order.\nTap as fast as you can!', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Column(children: [
    Padding(padding: EdgeInsets.all(4.w), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Next: $_next', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 20.sp, fontWeight: FontWeight.bold)),
      Text(_fmt(_sw.elapsedMilliseconds), style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 18.sp)),
    ])),
    Expanded(child: Padding(padding: EdgeInsets.all(2.w), child: GridView.count(crossAxisCount: 5, children: List.generate(25, (i) {
      final n = _grid[i]; final done = n < _next;
      return Padding(padding: EdgeInsets.all(1.w), child: GestureDetector(onTap: done ? null : () => _tap(n), child: Container(
        decoration: BoxDecoration(color: done ? GameColors.successGreen.withValues(alpha: 0.15) : GameTheme.primary(ctx).withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: done ? GameColors.successGreen.withValues(alpha: 0.4) : n == _next ? GameTheme.accent(ctx).withValues(alpha: 0.7) : GameTheme.primary(ctx).withValues(alpha: 0.12), width: n == _next ? 2.5 : 1)),
        child: Center(child: Text(done ? '✓' : '$n', style: TextStyle(color: done ? GameColors.successGreen : n == _next ? GameTheme.accent(ctx) : GameTheme.textPrimary(ctx).withValues(alpha: 0.7), fontSize: 16.sp, fontWeight: n == _next ? FontWeight.bold : FontWeight.normal))),
      )));
    })))),
  ]);

  Widget _result(BuildContext ctx) {
    final t = _finalMs / 1000.0;
    return Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🏆', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
      Text('Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
      Row(children: [_stat(ctx, '${t.toStringAsFixed(1)}s', 'Your Time'), SizedBox(width: 3.w), _stat(ctx, '$_correct/25', 'Found')]), SizedBox(height: 3.h),
      Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Text(_wrong == 0 ? '🎯 Perfect!' : '$_wrong misses', style: TextStyle(color: _wrong == 0 ? GameColors.successGreen : GameTheme.textSecondary(ctx), fontSize: 16.sp, fontWeight: FontWeight.w600))),
      SizedBox(height: 4.h),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Play Again', style: TextStyle(fontSize: 15.sp)))),
        SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)))),
      ]),
    ])));
  }

  Widget _stat(BuildContext ctx, String v, String l) => Expanded(child: Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Column(children: [
    Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 22.sp, fontWeight: FontWeight.bold)), SizedBox(height: 0.5.h),
    Text(l, style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.6), fontSize: 11.sp)),
  ])));
}

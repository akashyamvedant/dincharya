// Sprint 2.3 — Odd One Out
// Grid of similar items, find the different one. 10 rounds.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class OddOneOutGame extends StatefulWidget {
  const OddOneOutGame({super.key});
  @override
  State<OddOneOutGame> createState() => _OddOneOutGameState();
}

class _OddOneOutGameState extends State<OddOneOutGame> {
  final _rng = Random(), _svc = MindGamesService();
  static const _rounds = 10, _gridSizes = [9, 12, 16, 20, 25]; // items per round
  int _r = 0, _ok = 0, _totalMs = 0, _gridSize = 9;
  List<bool> _items = []; // true = odd one
  DateTime? _roundStart;

  void _start() { setState(() { _r = 0; _ok = 0; _totalMs = 0; _genRound(); }); }

  void _genRound() {
    _gridSize = _gridSizes[min(_r, _gridSizes.length - 1)];
    final oddIdx = _rng.nextInt(_gridSize);
    _items = List.generate(_gridSize, (i) => i == oddIdx);
    _roundStart = DateTime.now();
    setState(() {});
  }

  void _tap(int i) {
    final ms = DateTime.now().difference(_roundStart!).inMilliseconds; _totalMs += ms;
    if (_items[i]) _ok++;
    _r++;
    if (_r >= _rounds) { _finish(); } else { _genRound(); }
  }

  Future<void> _finish() async {
    setState(() {});
    final acc = _ok / _rounds; final avg = _totalMs ~/ _rounds;
    await _svc.saveScore(gameType: 'odd_one_out', score: (_ok * 10.0), accuracy: acc, reactionTimeMs: avg, roundsCompleted: _rounds);
  }

  int _cols() => _gridSize <= 9 ? 3 : _gridSize <= 16 ? 4 : 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Odd One Out', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: _r == 0 && _items.isEmpty ? _startScrn(context) : _r >= _rounds ? _result(context) : _game(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🔍', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Odd One Out', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Find the different item in the grid.\n$_rounds rounds, increasing difficulty.', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)),
    SizedBox(height: 2.h),
    Text('🔴🔴🔵🔴  ← spot the blue!', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 18.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Padding(
    padding: EdgeInsets.all(3.w),
    child: Column(children: [
      Padding(padding: EdgeInsets.all(2.w), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${_r + 1}/$_rounds', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp)),
        Text('✓ $_ok', style: TextStyle(color: GameColors.successGreen, fontSize: 14.sp, fontWeight: FontWeight.w600)),
      ])),
      ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: _r / _rounds, backgroundColor: GameTheme.primary(ctx).withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation(GameTheme.primary(ctx)), minHeight: 4)),
      SizedBox(height: 2.h),
      Expanded(child: GridView.count(crossAxisCount: _cols(), mainAxisSpacing: 1.5.w, crossAxisSpacing: 1.5.w, children: List.generate(_gridSize, (i) {
        return GestureDetector(
          onTap: () => _tap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            decoration: BoxDecoration(
              color: _items[i] ? GameTheme.accent(ctx).withValues(alpha: 0.18) : GameTheme.primary(ctx).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.15)),
            ),
            child: Center(child: Text(_items[i] ? '★' : '●', style: TextStyle(fontSize: 20.sp, color: _items[i] ? GameTheme.accent(ctx) : GameTheme.textPrimary(ctx).withValues(alpha: 0.5)))),
          ),
        );
      }))),
    ]),
  );

  Widget _result(BuildContext ctx) {
    final acc = (_ok / _rounds * 100).round();
    return Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🔍', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
      Text('Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
      Row(children: [_s(ctx, '$_ok/$_rounds', '$acc%'), SizedBox(width: 3.w), _s(ctx, '${_totalMs ~/ _rounds}ms', 'Avg speed')]),
      SizedBox(height: 4.h),
      Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
    ])));
  }

  Widget _s(BuildContext ctx, String v, String l) => Expanded(child: Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Column(children: [Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 22.sp, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.5), fontSize: 11.sp))])));
}

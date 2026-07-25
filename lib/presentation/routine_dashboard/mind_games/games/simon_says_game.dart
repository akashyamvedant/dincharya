// Sprint 2.2 — Simon Says (Color Sequence)
// 4 colored circles. App blinks sequence. User repeats. Grows each round.

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class SimonSaysGame extends StatefulWidget {
  const SimonSaysGame({super.key});
  @override
  State<SimonSaysGame> createState() => _SimonSaysGameState();
}

class _SimonSaysGameState extends State<SimonSaysGame>
    with SingleTickerProviderStateMixin {
  final _rng = Random(), _svc = MindGamesService();
  final _colors = GameColors.simon;
  List<int> _seq = [];
  int _playerIdx = 0, _round = 0, _best = 0;
  bool _showing = false, _started = false, _done = false;
  int? _highlighted;

  void _start() { setState(() { _seq.clear(); _round = 0; _best = 0; _started = true; _done = false; _addAndShow(); }); }

  void _addAndShow() {
    _seq.add(_rng.nextInt(4)); _playerIdx = 0; _showing = true; setState(() {});
    Future.delayed(const Duration(milliseconds: 600), () => _playSeq());
  }

  void _playSeq() async {
    for (final c in _seq) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _highlighted = c);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _highlighted = null);
    }
    setState(() => _showing = false);
  }

  void _tap(int i) {
    if (_showing || _done) return;
    if (i != _seq[_playerIdx]) { _finish(); return; }
    setState(() => _highlighted = i);
    Future.delayed(const Duration(milliseconds: 150), () { if (mounted) setState(() => _highlighted = null); });
    _playerIdx++; _round++;
    if (_playerIdx >= _seq.length) {
      final max = _seq.length;
      setState(() { if (max > _best) _best = max; });
      Future.delayed(const Duration(milliseconds: 600), () { if (mounted && !_done) _addAndShow(); });
    }
  }

  Future<void> _finish() async {
    setState(() { _done = true; if (_seq.length - 1 > _best) _best = _seq.length - 1; });
    await _svc.saveScore(gameType: 'simon_says', score: _best.toDouble(), roundsCompleted: _best);
  }

  Color _color(int i) => _highlighted == i ? _colors[i] : _colors[i].withValues(alpha: 0.3);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Simon Says', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: !_started ? _startScrn(context) : _done ? _result(context) : _game(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: EdgeInsets.all(4.w), decoration: BoxDecoration(shape: BoxShape.circle, color: GameTheme.primary(ctx).withValues(alpha: 0.1)), child: Row(mainAxisSize: MainAxisSize.min, children: _colors.map((c) => Padding(padding: EdgeInsets.all(1.w), child: Container(width: 30, height: 30, decoration: BoxDecoration(shape: BoxShape.circle, color: c)))).toList())),
    SizedBox(height: 3.h),
    Text('Simon Says', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Watch the sequence.\nRepeat it by tapping the colors.\nEach round gets longer!', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Column(children: [
    Padding(padding: EdgeInsets.all(4.w), child: Text(_showing ? '👀 Watch...' : '👆 Your turn!', style: TextStyle(color: _showing ? GameTheme.textSecondary(ctx) : GameTheme.accent(ctx), fontSize: 18.sp, fontWeight: FontWeight.w600))),
    Expanded(child: Center(child: GridView.count(crossAxisCount: 2, mainAxisSpacing: 4.w, crossAxisSpacing: 4.w, padding: EdgeInsets.all(8.w), shrinkWrap: true, childAspectRatio: 1, children: List.generate(4, (i) {
      return GestureDetector(
        onTap: _showing ? null : () => _tap(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(shape: BoxShape.circle, color: _color(i), boxShadow: _highlighted == i ? [BoxShadow(color: _colors[i].withValues(alpha: 0.6), blurRadius: 20, spreadRadius: 2)] : []),
          child: Center(child: Text('${i + 1}', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 18.sp, fontWeight: FontWeight.bold))),
        ),
      );
    })))), SizedBox(height: 2.h),
    Text('Sequence: ${_seq.length}', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp)),
    SizedBox(height: 4.h),
  ]);

  Widget _result(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🎯', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
    Text('Game Over!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 2.h),
    Container(padding: EdgeInsets.all(4.w), decoration: GameTheme.card(ctx), child: Column(children: [
      Text('$_best', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 42.sp, fontWeight: FontWeight.bold)),
      Text('Longest Sequence', style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.5), fontSize: 13.sp)),
    ])),
    SizedBox(height: 4.h),
    Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Play Again', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
  ])));
}

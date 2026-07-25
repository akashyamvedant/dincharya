// Sprite 2.1 — Memory Card Match
// Grid of face-down cards. Flip two, find matching pairs.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});
  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame>
    with SingleTickerProviderStateMixin {
  final _rng = Random(), _svc = MindGamesService();
  static const _icons = ['🧘', '🕉️', '🌿', '🌸', '☀️', '🌙', '🔥', '💧', '🪷', '🕊️', '🍃', '✨'];
  static const _levels = [6, 8, 10]; // pairs per level
  int _level = 6, _moves = 0, _found = 0, _totalMs = 0;
  List<String> _cards = [];
  List<bool> _flipped = [], _matched = [];
  int? _first, _second;
  bool _lock = false, _started = false, _done = false;
  DateTime? _startTime;
  late AnimationController _flipCtrl;
  final _sw = Stopwatch();

  @override
  void initState() { super.initState(); _flipCtrl = AnimationController(duration: const Duration(milliseconds: 300), vsync: this); }
  @override
  void dispose() { _flipCtrl.dispose(); super.dispose(); }

  void _start() {
    final pool = _icons.take(_level).toList();
    _cards = [...pool, ...pool]..shuffle(_rng);
    _flipped = List.filled(_cards.length, false);
    _matched = List.filled(_cards.length, false);
    setState(() { _moves = 0; _found = 0; _started = true; _done = false; _first = null; _second = null; _lock = false; _startTime = DateTime.now(); _sw..reset()..start(); });
  }

  void _tap(int i) {
    if (!_started || _done || _lock || _flipped[i] || _matched[i]) return;
    setState(() => _flipped[i] = true);
    if (_first == null) { _first = i; return; }
    _second = i; _moves++; _lock = true;
    if (_cards[_first!] == _cards[_second!]) {
      setState(() { _matched[_first!] = true; _matched[_second!] = true; _found++; });
      _reset();
    } else {
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) setState(() { _flipped[_first!] = false; _flipped[_second!] = false; _reset(); });
      });
    }
  }

  void _reset() { _first = null; _second = null; _lock = false; if (_found >= _level) _finish(); setState(() {}); }
  void _nextLevel() { if (_level < 10) { _level += 2; _start(); } }

  Future<void> _finish() async {
    _sw.stop(); _totalMs = _sw.elapsedMilliseconds; setState(() => _done = true);
    final score = (_level * 10) - (_moves - _level) * 0.5;
    await _svc.saveScore(gameType: 'memory_match', score: score.clamp(0.0, 100.0), accuracy: _level / _moves, reactionTimeMs: _totalMs, roundsCompleted: _found);
  }

  int _cols() => _cards.length <= 16 ? 4 : 5;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Memory Match', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true),
      body: !_started ? _startScrn(context) : _done ? _result(context) : _game(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🃏', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Memory Card Match', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Find matching pairs.\nMinimum moves = better memory!', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)),
    SizedBox(height: 3.h),
    Text('Level: $_level pairs (${_level * 2} cards)', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 16.sp, fontWeight: FontWeight.w600)),
    SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Padding(
    padding: EdgeInsets.all(2.w),
    child: Column(children: [
      Padding(padding: EdgeInsets.all(2.w), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('Moves: $_moves', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp)),
        Text('Found: $_found/$_level', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 14.sp, fontWeight: FontWeight.w600)),
      ])),
      Expanded(child: GridView.count(crossAxisCount: _cols(), childAspectRatio: 0.9, mainAxisSpacing: 1.5.w, crossAxisSpacing: 1.5.w, children: List.generate(_cards.length, (i) {
        final show = _flipped[i] || _matched[i];
        return GestureDetector(
          onTap: () => _tap(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              color: show ? GameTheme.primary(ctx).withValues(alpha: 0.12) : GameTheme.primary(ctx).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _matched[i] ? GameColors.successGreen.withValues(alpha: 0.6) : GameTheme.primary(ctx).withValues(alpha: 0.2)),
            ),
            child: Center(child: show ? Text(_cards[i], style: TextStyle(fontSize: 26.sp)) : Text('?', style: TextStyle(fontSize: 20.sp, color: GameTheme.textPrimary(ctx).withValues(alpha: 0.5)))),
          ),
        );
      }))),
    ]),
  );

  Widget _result(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text(_level >= 10 ? '🏆' : '🎉', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
    Text(_level >= 10 ? 'All Levels Complete!' : 'Level Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
    Row(children: [_s(ctx, '$_moves', 'Moves'), SizedBox(width: 3.w), _s(ctx, '$_found', 'Pairs'), SizedBox(width: 3.w), _s(ctx, _fmt(_totalMs), 'Time')]),
    SizedBox(height: 3.h),
    if (_level >= 10) ...[
      Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Text('🧠 All 3 levels beaten!', style: TextStyle(color: GameColors.gold, fontSize: 17.sp, fontWeight: FontWeight.bold))),
    ] else ...[
      Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Text('Next: ${_level + 2} pairs (${(_level + 2) * 2} cards)', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 16.sp))),
      SizedBox(height: 2.h),
      SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _nextLevel, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Next Level', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)))),
    ],
    SizedBox(height: 3.h),
    Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
  ])));

  String _fmt(int ms) { final s = ms ~/ 1000; return '${s}s'; }
  Widget _s(BuildContext ctx, String v, String l) => Expanded(child: Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Column(children: [Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 20.sp, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.5), fontSize: 11.sp))])));
}

// lib/presentation/routine_dashboard/mind_games/games/stroop_test_game.dart
// Stroop Color-Word Test (Stroop, 1935). Context-aware theme.

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class StroopTestGame extends StatefulWidget {
  const StroopTestGame({super.key});
  @override
  State<StroopTestGame> createState() => _StroopTestGameState();
}

class _StroopTestGameState extends State<StroopTestGame> {
  final _rng = Random(), _service = MindGamesService();
  static const _total = 20, _choices = 4;

  int _idx = 0, _correct = 0, _wrong = 0;
  List<int> _rts = [];
  String _word = '';
  Color _inkColor = Colors.black;
  List<Color> _choiceColors = [];
  DateTime? _start;
  GamePhase _phase = GamePhase.start;

  @override
  void initState() { super.initState(); _genRound(); }

  void _genRound() {
    final wi = _rng.nextInt(GameColors.stroop.length);
    int ii;
    do { ii = _rng.nextInt(GameColors.stroop.length); }
    while (ii == wi && GameColors.stroop.length > 1);
    _word = GameColors.stroopNames[wi];
    _inkColor = GameColors.stroop[ii];
    _choiceColors = [_inkColor];
    while (_choiceColors.length < _choices) {
      final c = GameColors.stroop[_rng.nextInt(GameColors.stroop.length)];
      if (!_choiceColors.contains(c)) _choiceColors.add(c);
    }
    _choiceColors.shuffle(_rng);
    _start = DateTime.now();
  }

  void _tap(Color c) {
    if (_phase != GamePhase.playing) return;
    _rts.add(DateTime.now().difference(_start!).inMilliseconds);
    if (c == _inkColor) _correct++; else _wrong++;
    _idx++;
    if (_idx >= _total) { _finish(); return; }
    _genRound(); setState(() {});
  }

  Future<void> _finish() async {
    setState(() => _phase = GamePhase.results);
    final acc = _correct / _total;
    final avgRT = _rts.isNotEmpty ? _rts.reduce((a, b) => a + b) / _rts.length : 0.0;
    final score = ((_correct - _wrong * 0.5) / _total * 100).clamp(0.0, 100.0);
    await _service.saveScore(gameType: 'stroop', score: score, accuracy: acc, reactionTimeMs: avgRT.round(), roundsCompleted: _total);
  }

  void _startGame() { setState(() { _phase = GamePhase.playing; _idx = 0; _correct = 0; _wrong = 0; _rts.clear(); _genRound(); }); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(
        backgroundColor: GameTheme.bg(context), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        title: Text('Stroop Color Test', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: _phase == GamePhase.start ? _startScrn(context) :
            _phase == GamePhase.playing ? _gameScrn(context) : _resultScrn(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🎨', style: TextStyle(fontSize: 56.sp)), SizedBox(height: 3.h),
    Text('Stroop Color Test', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Container(padding: EdgeInsets.all(4.w), decoration: GameTheme.card(ctx), child: Column(children: [
      Text('BLUE', style: TextStyle(color: Colors.red, fontSize: 30.sp, fontWeight: FontWeight.bold)), SizedBox(height: 1.h),
      Text('→ Tap "RED" (the ink color), not "BLUE"', textAlign: TextAlign.center, style: TextStyle(color: GameColors.chakraRed, fontSize: 14.sp)),
    ])), SizedBox(height: 2.h),
    Text('20 words · 30 seconds', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _startGame, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start Test', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _gameScrn(BuildContext ctx) {
    final prog = _idx / _total;
    return Column(children: [
      Padding(padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h), child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${_idx + 1}/$_total', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
          Text('$_correct ✓', style: TextStyle(color: GameColors.successGreen, fontSize: 13.sp)),
        ]), SizedBox(height: 0.5.h),
        ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: prog, backgroundColor: GameTheme.primary(ctx).withValues(alpha: 0.15), valueColor: AlwaysStoppedAnimation(GameTheme.primary(ctx)), minHeight: 6)),
      ])),
      Expanded(child: Center(child: Text(_word, style: TextStyle(color: _inkColor, fontSize: 48.sp, fontWeight: FontWeight.bold)))),
      Padding(padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 4.h), child: GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, mainAxisSpacing: 2.w, crossAxisSpacing: 2.w, childAspectRatio: 2.5, children: _choiceColors.map((c) {
        final name = GameColors.stroopNames[GameColors.stroop.indexOf(c)];
        return GestureDetector(onTap: () => _tap(c), child: Container(decoration: BoxDecoration(color: c.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: c.withValues(alpha: 0.6), width: 2)), child: Center(child: Text(name, style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold)))));
      }).toList())),
    ]);
  }

  Widget _resultScrn(BuildContext ctx) {
    final acc = (_correct / _total * 100).round();
    final avgRT = _rts.isNotEmpty ? _rts.reduce((a, b) => a + b) ~/ _rts.length : 0;
    return Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('🎨', style: TextStyle(fontSize: 48.sp)), SizedBox(height: 2.h),
      Text('Test Complete!', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
      Row(children: [_stat(ctx, '$_correct/$_total', 'Accuracy', '$acc%'), SizedBox(width: 3.w), _stat(ctx, '${avgRT}ms', 'Avg Speed', '')]),
      SizedBox(height: 4.h),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _startGame, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Retry', style: TextStyle(fontSize: 15.sp)))),
        SizedBox(width: 3.w),
        Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold)))),
      ]),
    ])));
  }

  Widget _stat(BuildContext ctx, String v, String l, String sub) => Expanded(child: Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Column(children: [
    Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 22.sp, fontWeight: FontWeight.bold)), SizedBox(height: 0.5.h),
    Text(l, style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.6), fontSize: 11.sp)),
    if (sub.isNotEmpty) Text(sub, style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 13.sp, fontWeight: FontWeight.w600)),
  ])));
}

enum GamePhase { start, playing, results }

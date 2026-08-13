// lib/presentation/routine_dashboard/mind_games/games/breath_counting_game.dart
// Count breaths 1→10. Mind wanders → tap "wandered" → restart.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';

class BreathCountingGame extends StatefulWidget {
  const BreathCountingGame({super.key});
  @override
  State<BreathCountingGame> createState() => _BreathCountingGameState();
}

class _BreathCountingGameState extends State<BreathCountingGame>
    with SingleTickerProviderStateMixin {
  final _service = MindGamesService();
  int _count = 0, _rounds = 0, _wanders = 0, _maxStreak = 0, _streak = 0;
  bool _started = false, _finished = false;
  late final _ctrl = AnimationController(duration: const Duration(seconds: 5), vsync: this)..repeat(reverse: true);
  late final _anim = Tween<double>(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _start() => setState(() { _started = true; _finished = false; _count = 0; _rounds = 0; _wanders = 0; _maxStreak = 0; _streak = 0; });

  void _exhale() {
    if (!_started || _finished) return;
    setState(() { _count++; if (_count >= 10) { _rounds++; _count = 0; _streak++; if (_streak > _maxStreak) _maxStreak = _streak; } });
  }

  void _wander() {
    if (!_started || _finished) return;
    setState(() { _wanders++; if (_streak > _maxStreak) _maxStreak = _streak; _streak = 0; _count = 0; });
  }

  Future<void> _end() async {
    setState(() => _finished = true); _ctrl.stop();
    final s = (_rounds * 10.0 + _maxStreak * 2.0 - _wanders * 2.0).clamp(0.0, 100.0);
    await _service.saveScore(gameType: 'breath_counting', score: s.toDouble(), accuracy: _wanders > 0 ? _rounds / (_rounds + _wanders) : 1.0, roundsCompleted: _rounds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(backgroundColor: GameTheme.bg(context), elevation: 0, leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)), title: Text('Breath Focus', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true, actions: _started && !_finished ? [TextButton(onPressed: _end, child: Text('Done', style: TextStyle(color: GameTheme.primary(context))))] : null),
      body: !_started ? _startScrn(context) : _finished ? _result(context) : _game(context),
    );
  }

  Widget _startScrn(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🧘', style: TextStyle(fontSize: 38.sp)), SizedBox(height: 3.h),
    Text('Breath Counting Focus', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 2.h),
    Text('Count your breaths 1→10.\nIf your mind wanders, tap "Wandered".', textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 15.sp)), SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.8.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Begin', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _game(BuildContext ctx) => Column(children: [
    Expanded(child: Center(child: AnimatedBuilder(animation: _anim, builder: (_, __) => Container(
      width: 80.w * _anim.value, height: 80.w * _anim.value,
      decoration: BoxDecoration(shape: BoxShape.circle, color: GameTheme.primary(ctx).withValues(alpha: 0.08 * _anim.value), border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.25), width: 2)),
      child: Center(child: Text(_count == 0 ? 'Breathe...' : '$_count', style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: _count == 0 ? 18.sp : 42.sp, fontWeight: FontWeight.bold))),
    )))),
    Padding(padding: EdgeInsets.symmetric(horizontal: 4.w), child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      Text('🔄 $_rounds rounds', style: TextStyle(color: GameTheme.textPrimary(ctx), fontSize: 13.sp)),
      Text('🧠 $_maxStreak max', style: TextStyle(color: GameTheme.accent(ctx), fontSize: 13.sp)),
      Text('💭 $_wanders', style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 13.sp)),
    ])), SizedBox(height: 2.h),
    Padding(padding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 6.h), child: Row(children: [
      Expanded(flex: 3, child: ElevatedButton(onPressed: _exhale, style: ElevatedButton.styleFrom(backgroundColor: GameColors.successGreen.withValues(alpha: 0.2), foregroundColor: GameColors.successGreen, padding: EdgeInsets.symmetric(vertical: 2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Exhale 🌬️', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold)))),
      SizedBox(width: 3.w), Expanded(flex: 1, child: ElevatedButton(onPressed: _wander, style: ElevatedButton.styleFrom(backgroundColor: GameColors.errorRed.withValues(alpha: 0.12), foregroundColor: GameColors.errorRed, padding: EdgeInsets.symmetric(vertical: 2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('💭', style: TextStyle(fontSize: 22.sp)))),
    ])),
  ]);

  Widget _result(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🧘', style: TextStyle(fontSize: 36.sp)), SizedBox(height: 2.h),
    Text('Session Complete', style: GameTheme.heading(ctx, size: 24)), SizedBox(height: 3.h),
    Row(children: [_stat(ctx, '$_rounds', 'Rounds'), SizedBox(width: 3.w), _stat(ctx, '$_maxStreak', 'Max Streak')]), SizedBox(height: 2.h),
    _stat(ctx, '$_wanders', 'Mind Wanders'), SizedBox(height: 4.h),
    Row(children: [Expanded(child: OutlinedButton(onPressed: _start, style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Again', style: TextStyle(fontSize: 15.sp)))), SizedBox(width: 3.w), Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(context), style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.5.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold))))]),
  ])));

  Widget _stat(BuildContext ctx, String v, String l) => Expanded(child: Container(padding: EdgeInsets.all(3.w), decoration: GameTheme.card(ctx), child: Column(children: [Text(v, style: TextStyle(color: GameTheme.accent(ctx), fontSize: 24.sp, fontWeight: FontWeight.bold)), Text(l, style: TextStyle(color: GameTheme.textPrimary(ctx).withValues(alpha: 0.6), fontSize: 12.sp))])));
}

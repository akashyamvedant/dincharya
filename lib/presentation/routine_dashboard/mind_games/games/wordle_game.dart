import 'dart:math';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import '../mind_games_service.dart';
import '../widgets/game_shell.dart';

class WordleGame extends StatefulWidget {
  const WordleGame({super.key});
  @override
  State<WordleGame> createState() => _WordleGameState();
}

class _WordleGameState extends State<WordleGame> {
  final _service = MindGamesService(), _rng = Random();

  static const _wordLen = 5, _maxGuesses = 6;
  static const _words = [
    'PEACE', 'MIND', 'BRAIN', 'FOCUS', 'LIGHT', 'TRUTH', 'STILL', 'AWARE',
    'HEART', 'SPACE', 'BREAK', 'FRESH', 'SHARP', 'CLEAR', 'DEPTH', 'GRACE',
    'POWER', 'DREAM', 'RISE', 'FLAME', 'QUIET', 'STORM', 'BLOOM', 'SHIFT',
    'PULSE', 'WAVES', 'CREST', 'STONE', 'CLIMB', 'VAULT', 'SPARK', 'GLEAM',
    'VITAL', 'PRIME', 'NOBLE', 'SWIFT', 'BLISS', 'CHARM', 'VIGOR', 'ZENITH',
  ];

  late String _target;
  List<String> _guesses = [];
  List<String> _currentGuess = [];
  int _cursor = 0;
  String _message = '';
  bool _started = false, _done = false, _won = false;
  bool _showingCountdown = false, _isNewBest = false;

  final _keys = [
    ['Q','W','E','R','T','Y','U','I','O','P'],
    ['A','S','D','F','G','H','J','K','L'],
    ['ENTER','Z','X','C','V','B','N','M','⌫'],
  ];
  final Set<String> _usedLetters = {};
  final Map<String, int> _letterState = {}; // 0=unused, 1=wrongPos, 2=correct

  @override
  void initState() {
    super.initState();
    _newGame();
  }

  void _newGame() {
    _target = _words[_rng.nextInt(_words.length)];
    _guesses = [];
    _currentGuess = List.filled(_wordLen, '');
    _cursor = 0;
    _message = '';
    _started = false;
    _done = false;
    _won = false;
    _isNewBest = false;
    _usedLetters.clear();
    _letterState.clear();
  }

  void _start() => setState(() { _showingCountdown = true; _newGame(); });
  void _countdownDone() => setState(() { _showingCountdown = false; _started = true; });

  void _onKey(String key) {
    if (!_started || _done) return;

    if (key == '⌫') {
      if (_cursor > 0) setState(() => _currentGuess[--_cursor] = '');
    } else if (key == 'ENTER') {
      _submit();
    } else if (_cursor < _wordLen) {
      setState(() => _currentGuess[_cursor++] = key);
    }
  }

  void _submit() {
    if (_currentGuess.any((c) => c.isEmpty)) {
      setState(() => _message = 'Not enough letters');
      return;
    }
    final word = _currentGuess.join();
    _guesses.add(word);

    // Check each position
    for (int i = 0; i < _wordLen; i++) {
      if (word[i] == _target[i]) {
        _letterState[word[i]] = 2;
        _usedLetters.add(word[i]);
      } else if (_target.contains(word[i])) {
        _letterState.putIfAbsent(word[i], () => 1);
        _usedLetters.add(word[i]);
      } else {
        _letterState.putIfAbsent(word[i], () => 0);
        _usedLetters.add(word[i]);
      }
    }

    if (word == _target) {
      setState(() { _won = true; _done = true; });
      GameHaptics.win();
      _finish();
    } else if (_guesses.length >= _maxGuesses) {
      setState(() => _done = true);
      GameHaptics.wrong();
      _finish();
    } else {
      setState(() {
        _currentGuess = List.filled(_wordLen, '');
        _cursor = 0;
        _message = '';
      });
    }
  }

  Future<void> _finish() async {
    final score = _won ? ((_maxGuesses - _guesses.length + 1) * 200).toDouble() : 50.0;
    await _service.saveScore(
        gameType: 'wordle', score: score,
        accuracy: _won ? 1.0 : _guesses.where((g) => g != _target && _target.split('').any((c) => g.contains(c))).length / _maxGuesses,
        roundsCompleted: _guesses.length,
        metadata: {'won': _won, 'target': _target});
    _isNewBest = await _service.submitLocalBest('wordle', score);
    await _service.addXp(_won ? 30 : 5);
    if (mounted) setState(() {});
  }

  Color _tileColor(int i, String word) {
    if (word.isEmpty) return Colors.transparent;
    if (word[i] == _target[i]) return GameColors.successGreen;
    if (_target.contains(word[i])) return GameColors.chakraOrange;
    return GameTheme.primary(context).withValues(alpha: 0.3);
  }

  Color _keyColor(String k) {
    if (!_letterState.containsKey(k)) return GameTheme.surface(context);
    final s = _letterState[k]!;
    if (s == 2) return GameColors.successGreen;
    if (s == 1) return GameColors.chakraOrange;
    return GameTheme.textMuted(context).withValues(alpha: 0.3);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: AppBar(
        backgroundColor: GameTheme.bg(context), elevation: 0,
        leading: IconButton(icon: Icon(Icons.arrow_back_rounded, color: GameTheme.textPrimary(context)), onPressed: () => Navigator.pop(context)),
        title: Text('Wordle', style: TextStyle(color: GameTheme.textPrimary(context), fontSize: 16.sp, fontWeight: FontWeight.bold)), centerTitle: true,
      ),
      body: Stack(children: [
        if (!_started && !_done && !_showingCountdown) _startScreen(context),
        if (_showingCountdown) GameCountdown(onDone: _countdownDone),
        if (_started || _done) _gameView(context),
      ]),
    );
  }

  Widget _startScreen(BuildContext ctx) => Center(child: Padding(padding: EdgeInsets.all(6.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Text('🟩', style: TextStyle(fontSize: 54.sp)), SizedBox(height: 3.h),
    Text('Wordle', style: GameTheme.heading(ctx, size: 26)), SizedBox(height: 2.h),
    Text('Guess the 5-letter word in $_maxGuesses tries.\nGreen = correct position\nOrange = wrong position\nGrey = not in word',
        textAlign: TextAlign.center, style: TextStyle(color: GameTheme.textSecondary(ctx), fontSize: 14.sp, height: 1.6)),
    SizedBox(height: 4.h),
    SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.6.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: Text('Start', style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold)))),
  ])));

  Widget _gameView(BuildContext ctx) {
    return Column(children: [
      if (_done) ...[
        if (_won)
          Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 1.5.h), color: GameColors.successGreen.withValues(alpha: 0.15), child: Text('🎉 You got it in ${_guesses.length} tries!', textAlign: TextAlign.center, style: TextStyle(color: GameColors.successGreen, fontSize: 15.sp, fontWeight: FontWeight.bold)))
        else
          Container(width: double.infinity, padding: EdgeInsets.symmetric(vertical: 1.5.h), color: GameColors.errorRed.withValues(alpha: 0.1), child: Text('The word was: $_target', textAlign: TextAlign.center, style: TextStyle(color: GameColors.errorRed, fontSize: 15.sp, fontWeight: FontWeight.bold))),
        SizedBox(height: 2.h),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(width: 40.w, child: ElevatedButton(onPressed: _start, style: ElevatedButton.styleFrom(backgroundColor: GameTheme.primary(ctx), foregroundColor: Colors.white, padding: EdgeInsets.symmetric(vertical: 1.2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Play Again', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)))),
          SizedBox(width: 3.w),
          SizedBox(width: 30.w, child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(foregroundColor: GameTheme.primary(ctx), side: BorderSide(color: GameTheme.primary(ctx).withValues(alpha: 0.5)), padding: EdgeInsets.symmetric(vertical: 1.2.h), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text('Done', style: TextStyle(fontSize: 14.sp)))),
        ]),
        SizedBox(height: 2.h),
      ],
      // Grid
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 6.w),
          child: Column(children: [
            SizedBox(height: 1.h),
            ...List.generate(_maxGuesses, (r) {
              final word = r < _guesses.length ? _guesses[r] : r == _guesses.length ? _currentGuess.join() : '';
              final isCurrent = r == _guesses.length && !_done;
              return Padding(
                padding: EdgeInsets.only(bottom: 1.2.h),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_wordLen, (c) {
                  final letter = c < word.length ? word[c] : '';
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 14.w, height: 14.w,
                    margin: EdgeInsets.all(0.8.w),
                    decoration: BoxDecoration(
                      color: isCurrent ? Colors.transparent : _tileColor(c, word),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: letter.isNotEmpty && !isCurrent ? Colors.transparent
                            : isCurrent && c == _cursor ? GameTheme.accent(ctx)
                            : GameTheme.primary(ctx).withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(child: Text(letter, style: TextStyle(
                      color: letter.isNotEmpty && !isCurrent ? Colors.white : GameTheme.textPrimary(ctx),
                      fontSize: 20.sp, fontWeight: FontWeight.bold))));
                })),
              );
            }),
            if (_message.isNotEmpty)
              Padding(padding: EdgeInsets.only(top: 1.h), child: Text(_message, style: TextStyle(color: GameColors.errorRed, fontSize: 13.sp))),
          ]),
        ),
      ),
      // Keyboard
      Container(
        padding: EdgeInsets.fromLTRB(1.w, 1.h, 1.w, 2.h),
        child: Column(children: _keys.map((row) {
          return Padding(
            padding: EdgeInsets.only(bottom: 0.8.h),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: row.map((k) {
              final isSpecial = k == 'ENTER' || k == '⌫';
              return GestureDetector(
                onTap: () => _onKey(k),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: isSpecial ? 14.w : 9.w,
                  height: 13.w,
                  margin: EdgeInsets.all(0.5.w),
                  decoration: BoxDecoration(
                    color: _keyColor(k),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: GameTheme.primary(ctx).withValues(alpha: 0.15)),
                  ),
                  child: Center(child: Text(k, style: TextStyle(
                    color: _letterState.containsKey(k) && _letterState[k]! >= 1 ? Colors.white : GameTheme.textPrimary(ctx),
                    fontSize: isSpecial ? 10.sp : 14.sp,
                    fontWeight: FontWeight.bold))),
                ),
              );
            }).toList()),
          );
        }).toList()),
      ),
    ]);
  }
}

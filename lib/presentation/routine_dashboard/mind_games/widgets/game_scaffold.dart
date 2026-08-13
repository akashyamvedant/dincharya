// lib/presentation/routine_dashboard/mind_games/widgets/game_scaffold.dart
// PREMIUM GAME SCAFFOLD — Standardized game lifecycle wrapper.
// Provides: Start Screen → Countdown → Gameplay (with progress bar + pause) → Results
// All games should use this for consistent UX.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../game_theme.dart';
import 'game_shell.dart';

/// Game lifecycle phases
enum GamePhase { start, countdown, playing, paused, results }

/// Standardized game scaffold that wraps the full game lifecycle.
/// Usage:
/// ```dart
/// GameScaffold(
///   gameName: 'Stroop Test',
///   gameIcon: '🎨',
///   description: 'Tap the INK color, not the word!',
///   totalRounds: 20,
///   currentRound: _round,
///   isPlaying: _started,
///   isDone: _done,
///   onStart: _startGame,
///   onQuit: () => Navigator.pop(context),
///   gameContent: _buildGameContent(),
///   resultsScreen: _buildResults(),
/// )
/// ```
class GameScaffold extends StatelessWidget {
  final String gameName;
  final String gameIcon;
  final String description;
  final String buttonLabel;
  final Widget? startPreview;

  // Game state
  final GamePhase phase;
  final int totalRounds;
  final int currentRound;

  // Callbacks
  final VoidCallback onStart;
  final VoidCallback onQuit;
  final VoidCallback? onResume;

  // Content
  final Widget gameContent;
  final Widget? resultsScreen;

  // Progress bar config
  final bool showProgressBar;
  final Color? progressColor;

  const GameScaffold({
    super.key,
    required this.gameName,
    required this.gameIcon,
    required this.description,
    this.buttonLabel = 'Start',
    this.startPreview,
    required this.phase,
    this.totalRounds = 0,
    this.currentRound = 0,
    required this.onStart,
    required this.onQuit,
    this.onResume,
    required this.gameContent,
    this.resultsScreen,
    this.showProgressBar = true,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameTheme.bg(context),
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          // Main content based on phase
          _buildPhaseContent(),
          // Pause overlay
          if (phase == GamePhase.paused)
            GamePauseOverlay(
              gameName: gameName,
              onResume: onResume ?? onStart,
              onQuit: onQuit,
            ),
        ],
      ),
    );
  }

  Widget _buildPhaseContent() {
    switch (phase) {
      case GamePhase.start:
        return GameStartScreen(
          icon: gameIcon,
          title: gameName,
          description: description,
          buttonLabel: buttonLabel,
          preview: startPreview,
          onStart: onStart,
        );
      case GamePhase.countdown:
        return GameCountdown(onDone: onResume ?? onStart);
      case GamePhase.playing:
      case GamePhase.paused:
        return Column(
          children: [
            // Progress bar
            if (showProgressBar && totalRounds > 0)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                child: GameProgressBar(
                  current: currentRound,
                  total: totalRounds,
                  color: progressColor,
                ),
              ),
            // Game content
            Expanded(child: gameContent),
          ],
        );
      case GamePhase.results:
        return resultsScreen ?? const SizedBox.shrink();
    }
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: GameTheme.bg(context),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_rounded,
            color: GameTheme.textPrimary(context)),
        onPressed: () {
          GameHaptics.tap();
          if (phase == GamePhase.playing) {
            // Show confirmation if in-game
            _showQuitDialog(context);
          } else {
            onQuit();
          }
        },
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(gameIcon, style: TextStyle(fontSize: 16.sp)),
          SizedBox(width: 2.w),
          Text(
            gameName,
            style: TextStyle(
              color: GameTheme.textPrimary(context),
              fontSize: 16.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      centerTitle: true,
      actions: [
        // Pause button during gameplay
        if (phase == GamePhase.playing)
          IconButton(
            icon: Icon(Icons.pause_rounded,
                color: GameTheme.textSecondary(context), size: 20),
            onPressed: () {
              GameHaptics.tap();
              // Parent handles pause state
            },
          ),
        SizedBox(width: 2.w),
      ],
    );
  }

  void _showQuitDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor:
            GameTheme.isDark(context) ? const Color(0xFF2A2015) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Quit Game?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: GameTheme.textPrimary(context),
          ),
        ),
        content: Text(
          'Your progress in this round will be lost.',
          style: TextStyle(color: GameTheme.textSecondary(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Stay',
                style: TextStyle(color: GameTheme.primary(context))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onQuit();
            },
            child: const Text('Quit',
                style: TextStyle(color: GameColors.errorRed)),
          ),
        ],
      ),
    );
  }
}

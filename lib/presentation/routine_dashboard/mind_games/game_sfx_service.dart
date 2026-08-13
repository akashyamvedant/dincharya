// lib/presentation/routine_dashboard/mind_games/game_sfx_service.dart
// Sound effects for Mind Games — lightweight singleton.
// Uses bell.wav for wins, system sounds for correct/wrong feedback.
// Respects user's sound preference via SharedPreferences.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameSfxService {
  GameSfxService._();
  static final GameSfxService _instance = GameSfxService._();
  factory GameSfxService() => _instance;

  final AudioPlayer _correctPlayer = AudioPlayer();
  final AudioPlayer _wrongPlayer = AudioPlayer();
  final AudioPlayer _winPlayer = AudioPlayer();
  final AudioPlayer _tapPlayer = AudioPlayer();

  bool _enabled = true;
  bool _initialized = false;
  bool get isEnabled => _enabled;

  static const String _prefKey = 'mind_games_sfx_enabled';

  /// Initialize and load preference
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_prefKey) ?? true;
    } catch (_) {
      _enabled = true;
    }
  }

  /// Toggle sound on/off
  Future<void> toggle() async {
    _enabled = !_enabled;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, _enabled);
    } catch (_) {}
  }

  /// Set enabled state explicitly
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKey, value);
    } catch (_) {}
  }

  // ─── Sound Effects ──────────────────────────────

  /// Correct answer — short pleasant click
  Future<void> playCorrect() async {
    if (!_enabled) return;
    try {
      await _correctPlayer.setVolume(0.3);
      await _correctPlayer.play(AssetSource('sounds/bell.wav'));
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// Wrong answer — subtle low tone
  Future<void> playWrong() async {
    if (!_enabled) return;
    try {
      // Use system alert as a subtle wrong indicator
      await SystemSound.play(SystemSoundType.alert);
    } catch (_) {}
  }

  /// Game complete / win — celebration bell
  Future<void> playWin() async {
    if (!_enabled) return;
    try {
      await _winPlayer.setVolume(0.5);
      await _winPlayer.play(AssetSource('sounds/bell.wav'));
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Button tap — very subtle
  Future<void> playTap() async {
    if (!_enabled) return;
    try {
      await SystemSound.play(SystemSoundType.click);
    } catch (_) {}
  }

  /// Countdown tick
  Future<void> playCountdown() async {
    if (!_enabled) return;
    try {
      await _tapPlayer.setVolume(0.2);
      await _tapPlayer.play(AssetSource('sounds/bell.wav'));
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (_) {}
    }
  }

  /// New best score — double bell
  Future<void> playNewBest() async {
    if (!_enabled) return;
    try {
      await _winPlayer.setVolume(0.5);
      await _winPlayer.play(AssetSource('sounds/bell.wav'));
      await Future.delayed(const Duration(milliseconds: 300));
      await _correctPlayer.setVolume(0.4);
      await _correctPlayer.play(AssetSource('sounds/bell.wav'));
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  /// Level up — ascending pattern
  Future<void> playLevelUp() async {
    if (!_enabled) return;
    try {
      await _winPlayer.setVolume(0.4);
      await _winPlayer.play(AssetSource('sounds/bell.wav'));
      await Future.delayed(const Duration(milliseconds: 200));
      await _correctPlayer.setVolume(0.5);
      await _correctPlayer.play(AssetSource('sounds/bell.wav'));
      await Future.delayed(const Duration(milliseconds: 200));
      await _tapPlayer.setVolume(0.6);
      await _tapPlayer.play(AssetSource('sounds/bell.wav'));
    } catch (_) {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
    }
  }

  // ─── Rich Haptic Patterns ──────────────────────

  /// Correct answer haptic
  static void hapticCorrect() {
    HapticFeedback.lightImpact();
  }

  /// Wrong answer haptic
  static void hapticWrong() {
    HapticFeedback.heavyImpact();
  }

  /// Win/complete haptic pattern
  static Future<void> hapticWin() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.heavyImpact();
  }

  /// Countdown haptic (progressive)
  static void hapticCountdown(int value) {
    switch (value) {
      case 3:
        HapticFeedback.lightImpact();
        break;
      case 2:
        HapticFeedback.mediumImpact();
        break;
      case 1:
        HapticFeedback.heavyImpact();
        break;
      default:
        HapticFeedback.selectionClick();
    }
  }

  void dispose() {
    _correctPlayer.dispose();
    _wrongPlayer.dispose();
    _winPlayer.dispose();
    _tapPlayer.dispose();
  }
}

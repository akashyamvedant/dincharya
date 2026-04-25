// lib/services/practice_sfx_service.dart
// Sound effects & rich haptic feedback for yoga practice.
// Uses separate AudioPlayer instances per sound type to prevent overlap.

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';

class PracticeSfxService {
  // Separate players to prevent sounds cutting each other off
  final AudioPlayer _bellPlayer = AudioPlayer();
  final AudioPlayer _tickPlayer = AudioPlayer();
  final AudioPlayer _celebrationPlayer = AudioPlayer();

  bool _enabled = true;
  bool get isEnabled => _enabled;
  bool _disposed = false;

  void toggle() => _enabled = !_enabled;

  // ─── Sound Effects ──────────────────────────────

  /// Play a gentle transition bell sound (pose change)
  Future<void> playTransitionBell() async {
    if (!_enabled || _disposed) return;
    try {
      await _bellPlayer.setVolume(0.4);
      await _bellPlayer.play(AssetSource('sounds/bell.wav'));
    } catch (_) {
      // Fallback: system click
      try { SystemSound.play(SystemSoundType.click); } catch (_) {}
    }
  }

  /// Play countdown tick sound
  Future<void> playCountdownTick() async {
    if (!_enabled || _disposed) return;
    try {
      await _tickPlayer.setVolume(0.3);
      await _tickPlayer.play(AssetSource('sounds/countdown_tick.mp3'));
    } catch (_) {
      try { SystemSound.play(SystemSoundType.click); } catch (_) {}
    }
  }

  /// Play celebration sound
  Future<void> playCelebration() async {
    if (!_enabled || _disposed) return;
    try {
      await _celebrationPlayer.setVolume(0.5);
      await _celebrationPlayer.play(AssetSource('sounds/celebration.mp3'));
    } catch (_) {
      try { SystemSound.play(SystemSoundType.alert); } catch (_) {}
    }
  }

  /// Play last 3 seconds warning sound
  Future<void> playLastSeconds() async {
    if (!_enabled || _disposed) return;
    try {
      await _tickPlayer.setVolume(0.25);
      await _tickPlayer.play(AssetSource('sounds/tick.mp3'));
    } catch (_) {
      try { SystemSound.play(SystemSoundType.click); } catch (_) {}
    }
  }

  void dispose() {
    _disposed = true;
    _bellPlayer.dispose();
    _tickPlayer.dispose();
    _celebrationPlayer.dispose();
  }

  // ─── Rich Haptic Patterns ──────────────────────

  /// Countdown: progressive intensity (3=light, 2=medium, 1=heavy)
  static Future<void> hapticCountdown(int value) async {
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
        HapticFeedback.lightImpact();
    }
  }

  /// Pose transition: double-tap haptic
  static Future<void> hapticTransition() async {
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.mediumImpact();
  }

  /// Last 3 seconds: rhythmic pulse
  static Future<void> hapticLastSeconds() async {
    HapticFeedback.selectionClick();
  }

  /// Practice complete: success pattern (short-short-long)
  static Future<void> hapticSuccess() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    HapticFeedback.heavyImpact();
  }

  /// Camera PIP snap to corner
  static Future<void> hapticSnap() async {
    HapticFeedback.selectionClick();
  }
}

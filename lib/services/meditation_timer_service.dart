import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';

/// Service for managing the meditation timer state and bell audio.
class MeditationTimerService {
  MeditationTimerService._();
  static final MeditationTimerService _instance = MeditationTimerService._();
  factory MeditationTimerService() => _instance;

  Timer? _timer;
  final AudioPlayer _bellPlayer = AudioPlayer();

  // State
  int _totalSeconds = 600; // 10 min default
  int _elapsedSeconds = 0;
  int _intervalSeconds = 0; // 0 = no interval bells
  bool _isRunning = false;

  // Callbacks
  VoidCallback? onTick;
  VoidCallback? onComplete;
  VoidCallback? onBell;

  // ── Getters ──
  int get totalSeconds => _totalSeconds;
  int get elapsedSeconds => _elapsedSeconds;
  int get remainingSeconds => _totalSeconds - _elapsedSeconds;
  double get progress => _totalSeconds > 0 ? _elapsedSeconds / _totalSeconds : 0;
  bool get isRunning => _isRunning;
  String get elapsedFormatted => _format(_elapsedSeconds);
  String get remainingFormatted => _format(remainingSeconds);

  String _format(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── Configuration ──
  void configure({required int totalMinutes, int intervalMinutes = 0}) {
    _totalSeconds = totalMinutes * 60;
    _intervalSeconds = intervalMinutes * 60;
    _elapsedSeconds = 0;
  }

  // ── Controls ──
  void start() {
    if (_isRunning) return;
    _isRunning = true;
    _playBell(); // Start bell
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      onTick?.call();

      // Interval bell
      if (_intervalSeconds > 0 && _elapsedSeconds % _intervalSeconds == 0 && _elapsedSeconds < _totalSeconds) {
        _playBell();
        onBell?.call();
      }

      // Complete
      if (_elapsedSeconds >= _totalSeconds) {
        _playBell();
        stop();
        onComplete?.call();
      }
    });
  }

  void pause() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  void resume() {
    if (_isRunning) return;
    _isRunning = true;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds++;
      onTick?.call();

      if (_intervalSeconds > 0 && _elapsedSeconds % _intervalSeconds == 0 && _elapsedSeconds < _totalSeconds) {
        _playBell();
        onBell?.call();
      }

      if (_elapsedSeconds >= _totalSeconds) {
        _playBell();
        stop();
        onComplete?.call();
      }
    });
  }

  void stop() {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
  }

  void reset() {
    stop();
    _elapsedSeconds = 0;
    onTick?.call();
  }

  // ── Audio ──
  Future<void> _playBell() async {
    try {
      // Use a built-in Android notification sound as bell
      await _bellPlayer.play(
        AssetSource('sounds/bell.wav'),
        volume: 0.8,
      );
    } catch (e) {
      debugPrint('🔔 Bell play fallback (no audio asset): $e');
      // Silently fail — bell audio is optional
    }
  }

  void dispose() {
    stop();
    _bellPlayer.dispose();
  }
}

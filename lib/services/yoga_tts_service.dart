// lib/services/yoga_tts_service.dart
// Hindi/English text-to-speech service for yoga teacher guidance

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class YogaTtsService {
  static final YogaTtsService _instance = YogaTtsService._();
  factory YogaTtsService() => _instance;
  YogaTtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isSpeaking = false;
  bool _isEnabled = true; // User toggle
  String _language = 'hi-IN'; // Default Hindi

  bool get isEnabled => _isEnabled;
  bool get isSpeaking => _isSpeaking;
  String get language => _language;

  Future<void> init() async {
    if (_isInitialized) return;
    try {
      await _tts.setLanguage(_language);
      await _tts.setSpeechRate(0.38); // Slow, calm yoga teacher pace
      await _tts.setVolume(1.0);
      await _tts.setPitch(0.95); // Slightly warm, deeper tone
      
      // CRITICAL: Makes speak() return a Future that completes
      // only when speech finishes — enables voice-first timer pattern
      await _tts.awaitSpeakCompletion(true);
      
      _tts.setStartHandler(() => _isSpeaking = true);
      _tts.setCompletionHandler(() => _isSpeaking = false);
      _tts.setCancelHandler(() => _isSpeaking = false);
      _tts.setErrorHandler((msg) {
        debugPrint('🔊 TTS Error: $msg');
        _isSpeaking = false;
      });
      
      _isInitialized = true;
      debugPrint('🔊 TTS initialized with language: $_language, awaitCompletion=true');
    } catch (e) {
      debugPrint('🔊 TTS init error: $e');
    }
  }

  Future<void> setLanguage(bool hindi) async {
    _language = hindi ? 'hi-IN' : 'en-IN';
    await _tts.setLanguage(_language);
    debugPrint('🔊 TTS language set to: $_language');
  }

  void toggle() {
    _isEnabled = !_isEnabled;
    if (!_isEnabled) stop();
    debugPrint('🔊 TTS ${_isEnabled ? "ON" : "OFF"}');
  }

  Future<void> speak(String text) async {
    if (!_isEnabled || text.isEmpty) return;
    await init();
    // Stop any ongoing speech first
    if (_isSpeaking) await _tts.stop();
    await _tts.speak(text);
  }

  /// Speak multiple lines sequentially with natural pauses between
  Future<void> speakSequence(List<String> lines) async {
    if (!_isEnabled || lines.isEmpty) return;
    await init();
    if (_isSpeaking) await _tts.stop();
    
    // Join with pause-inducing punctuation for natural rhythm
    // Using "। ... " creates a longer, natural pause between parts
    final combined = lines.where((l) => l.isNotEmpty).join('। ... ');
    await _tts.speak(combined);
  }

  /// Speak pose guidance: name + instruction + breathing
  Future<void> speakPoseGuidance({
    required String poseName,
    String? instruction,
    String? breathing,
    String? mantra,
  }) async {
    if (!_isEnabled) return;
    
    final parts = <String>[poseName];
    if (instruction != null && instruction.isNotEmpty) {
      parts.add(instruction);
    }
    if (breathing != null && breathing.isNotEmpty) {
      final breathLabel = _language.startsWith('hi') 
          ? _getBreathingHindi(breathing)
          : _getBreathingEnglish(breathing);
      parts.add(breathLabel);
    }
    
    await speakSequence(parts);
  }

  String _getBreathingHindi(String breathing) {
    switch (breathing) {
      case 'inhale': return 'श्वास लें';
      case 'exhale': return 'श्वास छोड़ें';
      case 'hold': return 'श्वास रोकें';
      default: return 'सामान्य श्वास';
    }
  }

  String _getBreathingEnglish(String breathing) {
    switch (breathing) {
      case 'inhale': return 'Inhale slowly';
      case 'exhale': return 'Exhale slowly';
      case 'hold': return 'Hold your breath';
      default: return 'Breathe normally';
    }
  }

  Future<void> stop() async {
    if (_isSpeaking) await _tts.stop();
    _isSpeaking = false;
  }

  Future<void> dispose() async {
    await stop();
    _isInitialized = false;
  }
}

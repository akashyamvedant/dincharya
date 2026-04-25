import 'dart:async';
import 'package:audioplayers/audioplayers.dart' as ap;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/yoga_tts_service.dart';
import '../../../services/tts_audio_service.dart';
import './cached_pose_image.dart';
import '../../media_player/widgets/in_app_audio_player.dart';
import '../../../services/media_cache_service.dart';

/// Breathing practice phases for pranayam steps
enum _BreathPracticePhase { inhale, holdInhale, exhale, holdExhale }

/// ═══════════════════════════════════════════════════════════════
/// PRACTICE TAB — Rich interactive step-by-step yoga practice guide
/// Features: Overview mode, Guided practice, TTS, Breathing indicator,
///           Pose card with image, mantra, instructions, playback controls,
///           Embedded breathing pacer for pranayam sessions
/// ═══════════════════════════════════════════════════════════════
class PracticeTab extends StatefulWidget {
  final Map<String, dynamic> pose;
  final List<Map<String, dynamic>> steps;

  const PracticeTab({
    super.key,
    required this.pose,
    required this.steps,
  });

  @override
  State<PracticeTab> createState() => _PracticeTabState();
}

class _PracticeTabState extends State<PracticeTab>
    with TickerProviderStateMixin {
  // ── State ──
  bool _isPracticing = false; // overview vs guided mode
  int _currentStep = 0;
  bool _isPlaying = false;
  bool _useHindi = true;
  bool _voiceEnabled = true;
  Timer? _stepTimer;
  int _remainingSeconds = 0;
  bool _isAutoAdvancing = false; // Prevents onPageChanged from cancelling auto-advance

  // ── Breathing Practice (Pranayam) ──
  bool _isBreathingPractice = false;
  _BreathPracticePhase _breathPracticePhase = _BreathPracticePhase.inhale;
  int _breathPracticeRound = 0;
  int _breathPracticeTotalRounds = 10;
  int _breathPracticePhaseRemaining = 0;
  Timer? _breathPracticeTimer;
  late AnimationController _breathPracticeController;
  late Animation<double> _breathPracticeAnimation;

  // ── Guided Audio (Meditation Type 1) ──
  bool _isGuidedAudioStep = false;
  // Note: InAppAudioPlayer manages its own audio lifecycle internally.
  // We only track the step type flag for pause/resume/dispose coordination.

  // ── Open Meditation (Meditation Type 2) ──
  bool _isMeditationOpen = false;
  int _meditationOpenElapsed = 0;      // Count-UP timer (seconds)
  Timer? _meditationOpenTimer;
  int _bellIntervalMinutes = 0;        // 0 = no bell
  ap.AudioPlayer? _meditationLoopPlayer; // Looping audio (Om sound etc.)
  late AnimationController _meditationGlowController;
  late Animation<double> _meditationGlowAnimation;

  // ── TTS ──
  final YogaTtsService _tts = YogaTtsService();
  final TtsAudioService _ttsAudio = TtsAudioService(); // Sarvam AI natural voice

  // ── Breathing ──
  late AnimationController _breathController;
  late Animation<double> _breathAnimation;
  String _breathLabel = '';
  bool _showBreathIndicator = false;

  // ── Page controller ──
  final PageController _pageController = PageController();

  // ── Camera PIP ──
  CameraController? _cameraController;
  bool _isCameraOpen = false;
  Offset _cameraPosition = Offset(0, 0); // Draggable position
  bool _cameraInitialized = false;
  
  // Camera PIP size (expandable/resizable)
  double _cameraWidth = 120;
  double _cameraHeight = 160;
  static const double _cameraMinW = 80;
  static const double _cameraMinH = 107;
  static const double _cameraMaxW = 280;
  static const double _cameraMaxH = 373;
  int _cameraSizePreset = 0; // 0=small, 1=medium, 2=large

  @override
  void initState() {
    super.initState();
    _initTts();
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breathAnimation = Tween<double>(begin: 0.95, end: 1.15).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
    // Breathing practice circle controller
    _breathPracticeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _breathPracticeAnimation = Tween<double>(begin: 0.45, end: 1.0).animate(
      CurvedAnimation(parent: _breathPracticeController, curve: Curves.easeInOut),
    );
    // Meditation open glow controller
    _meditationGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    );
    _meditationGlowAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _meditationGlowController, curve: Curves.easeInOut),
    );
    // Set initial camera position (bottom-right)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _cameraPosition = Offset(
            MediaQuery.of(context).size.width - _cameraWidth - 16,
            MediaQuery.of(context).size.height * 0.3,
          );
        });
      }
    });
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage(_useHindi);
    } catch (e) {
      debugPrint('TTS init error: $e');
    }
  }

  @override
  void deactivate() {
    // Kill all audio IMMEDIATELY when widget is removed from tree
    // (tab switch, navigation back, etc.) — before dispose()
    _speechCancelToken++;
    _stepTimer?.cancel();
    _breathPracticeTimer?.cancel();
    _meditationOpenTimer?.cancel();
    _meditationLoopPlayer?.stop();
    _tts.stop();
    _ttsAudio.stop();
    super.deactivate();
  }

  @override
  void dispose() {
    _speechCancelToken++; // Ensure any in-flight speech Future aborts
    _stepTimer?.cancel();
    _breathPracticeTimer?.cancel();
    _meditationOpenTimer?.cancel();
    _meditationLoopPlayer?.stop();
    _meditationLoopPlayer?.dispose();
    _meditationLoopPlayer = null;
    _tts.stop();
    _ttsAudio.stop();
    _breathController.dispose();
    _breathPracticeController.dispose();
    _meditationGlowController.dispose();
    _cameraController?.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ─── Camera ─────────────
  Future<void> _toggleCamera() async {
    if (_isCameraOpen) {
      await _cameraController?.dispose();
      setState(() {
        _isCameraOpen = false;
        _cameraInitialized = false;
        _cameraController = null;
        // Reset size to default on close
        _cameraSizePreset = 0;
        _cameraWidth = 120;
        _cameraHeight = 160;
      });
    } else {
      try {
        final cameras = await availableCameras();
        if (cameras.isEmpty) return;
        // Prefer front camera
        final front = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _cameraController = CameraController(
          front,
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraOpen = true;
            _cameraInitialized = true;
          });
        }
      } catch (e) {
        debugPrint('Camera error: $e');
      }
    }
  }

  /// Cycle camera PIP through 3 size presets: Small → Medium → Large → Small
  void _cycleCameraSize() {
    HapticFeedback.lightImpact();
    setState(() {
      _cameraSizePreset = (_cameraSizePreset + 1) % 3;
      switch (_cameraSizePreset) {
        case 0: // Small
          _cameraWidth = 120;
          _cameraHeight = 160;
          break;
        case 1: // Medium
          _cameraWidth = 180;
          _cameraHeight = 240;
          break;
        case 2: // Large
          _cameraWidth = 260;
          _cameraHeight = 347;
          break;
      }
      // Clamp position so camera doesn't go off screen after resize
      final maxX = MediaQuery.of(context).size.width - _cameraWidth - 8;
      final maxY = MediaQuery.of(context).size.height * 0.7;
      _cameraPosition = Offset(
        _cameraPosition.dx.clamp(0.0, maxX),
        _cameraPosition.dy.clamp(0.0, maxY),
      );
    });
  }

  // ─── TTS speak ─────────────
  Future<void> _speak(String text) async {
    if (!_voiceEnabled || text.isEmpty) return;
    await _tts.speak(text);
  }

  /// Speak full pose guidance using Sarvam AI natural voice
  /// Falls back to device TTS if Sarvam is unavailable
  Future<void> _speakStepGuidance(Map<String, dynamic> step) async {
    if (!_voiceEnabled) return;
    final poseName = _useHindi
        ? (step['name_hindi'] ?? step['name'] ?? '')
        : (step['name'] ?? '');
    final instruction = _useHindi
        ? (step['instruction_hindi'] ?? step['instruction'] ?? '')
        : (step['instruction'] ?? '');
    final breathing = step['breathing'] ?? '';
    final mantra = step['mantra'] ?? '';
    final poseId = widget.pose['id']?.toString() ?? '';
    final stepNumber = step['step_number'] as int? ?? (_currentStep + 1);
    final language = _useHindi ? 'hi' : 'en';

    // Build full guidance text for Sarvam AI
    final breathLabel = _useHindi
        ? _getBreathingLabel(breathing.toString())
        : _getBreathingLabelEn(breathing.toString());
    final parts = <String>[poseName.toString()];
    if (instruction.toString().isNotEmpty) parts.add(instruction.toString());
    if (breathLabel.isNotEmpty) parts.add(breathLabel);
    final guidanceText = parts.join('। ... ');

    // Try Sarvam AI natural voice first
    if (poseId.isNotEmpty && guidanceText.isNotEmpty) {
      final success = await _ttsAudio.speakStepGuidance(
        poseId: poseId,
        stepNumber: stepNumber,
        language: language,
        guidanceText: guidanceText,
      );
      if (success) return; // Sarvam AI worked! ✅
    }

    // ⚠️ Stop AI audio before fallback to prevent simultaneous playback
    await _ttsAudio.stop();

    // Fallback: device TTS (robotic but works offline without cache)
    debugPrint('🔊 Falling back to device TTS...');
    await _tts.speakPoseGuidance(
      poseName: poseName.toString(),
      instruction: instruction.toString(),
      breathing: breathing.toString(),
      mantra: mantra.toString(),
    );
  }

  String _getBreathingLabel(String breathing) {
    switch (breathing) {
      case 'inhale': return 'श्वास लें';
      case 'exhale': return 'श्वास छोड़ें';
      case 'hold': return 'श्वास रोकें';
      default: return '';
    }
  }

  String _getBreathingLabelEn(String breathing) {
    switch (breathing) {
      case 'inhale': return 'Inhale slowly';
      case 'exhale': return 'Exhale slowly';
      case 'hold': return 'Hold your breath';
      default: return '';
    }
  }

  // ─── Step timer (Voice-First Pattern) ─────────────
  // Phase 1: Voice speaks guidance → await completion
  // Phase 2: Hold timer counts down → auto-advance
  bool _isSpeechPhase = false;
  int _speechCancelToken = 0; // Incremented on cancel to abort speech-phase

  void _startStepTimer(int seconds) {
    _stepTimer?.cancel();
    _breathPracticeTimer?.cancel();
    _speechCancelToken++; // Cancel any previous speech-phase

    setState(() {
      _remainingSeconds = seconds;
      _isPlaying = true;
      _isSpeechPhase = true;
    });

    final step = widget.steps[_currentStep];
    final stepType = step['step_type'] as String? ?? 'pose';

    // Only show old breathing indicator badge for normal pose steps
    if (stepType == 'pose') {
      final breathType = step['breathing'] ?? '';
      if (breathType.toString().isNotEmpty) {
        _startBreathing(breathType.toString());
      } else {
        _stopBreathing();
      }
    } else {
      _stopBreathing(); // No badge for breathing/guided/meditation steps
    }

    // Voice-first: speak guidance, THEN start hold timer or breathing cycle
    _runVoiceThenHold(step, seconds);
  }

  /// Speaks guidance first, waits for completion, then starts hold countdown
  Future<void> _runVoiceThenHold(Map<String, dynamic> step, int holdSeconds) async {
    final token = _speechCancelToken;

    // Phase 1: Speak guidance (awaits TTS completion)
    if (_voiceEnabled) {
      await _speakStepGuidance(step);
    }

    // Check if cancelled while speaking (user skipped/paused/stopped)
    if (token != _speechCancelToken || !mounted) return;

    // Phase 2: Check step type for special handling
    final stepType = step['step_type'] as String? ?? 'pose';
    if (stepType == 'breathing_practice') {
      setState(() => _isSpeechPhase = false);
      _beginBreathingCycle(step);
      return;
    }
    if (stepType == 'guided_audio') {
      setState(() {
        _isSpeechPhase = false;
        _isGuidedAudioStep = true;
        _isPlaying = true;
      });
      // InAppAudioPlayer handles its own playback; we just mark the state
      return;
    }
    if (stepType == 'meditation_open') {
      setState(() => _isSpeechPhase = false);
      _beginMeditationOpen(step);
      return;
    }

    // Normal pose step: Start hold timer
    setState(() => _isSpeechPhase = false);

    _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _autoAdvance();
      }
    });
  }

  void _pauseTimer() {
    _stepTimer?.cancel();
    _breathPracticeTimer?.cancel();
    _meditationOpenTimer?.cancel();
    _speechCancelToken++; // Cancel any speech-phase Future
    _tts.stop();
    _ttsAudio.stop();
    setState(() {
      _isPlaying = false;
      _isSpeechPhase = false;
    });
    _stopBreathing();
    // Pause breathing practice animation (don't reset round/phase)
    if (_isBreathingPractice) {
      _breathPracticeController.stop();
    }
    // Pause meditation open looping audio & glow
    if (_isMeditationOpen) {
      _meditationLoopPlayer?.pause();
      _meditationGlowController.stop();
    }
  }

  void _autoAdvance() {
    if (_currentStep < widget.steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      // Practice complete — clean up ALL step type resources
      _speechCancelToken++;
      _tts.stop();
      _ttsAudio.stop();
      setState(() => _isPlaying = false);
      _stopBreathing();
      _stopBreathingPractice();
      _stopGuidedAudio();
      _stopMeditationOpen();
      HapticFeedback.heavyImpact();
      _showCompletionDialog();
    }
  }

  void _goToStep(int index) {
    if (index < 0 || index >= widget.steps.length) return;
    _stepTimer?.cancel();
    _breathPracticeTimer?.cancel();
    _speechCancelToken++; // Cancel any in-flight speech Future
    _tts.stop();          // Stop device TTS
    _ttsAudio.stop();     // Stop Sarvam AI audio
    _stopBreathing();
    _stopBreathingPractice();
    _stopGuidedAudio();
    _stopMeditationOpen();
    _isAutoAdvancing = true; // Flag to prevent onPageChanged from cancelling
    setState(() => _currentStep = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    ).then((_) {
      _isAutoAdvancing = false;
    });
    final dur = widget.steps[index]['duration_seconds'] as int? ?? 10;
    _startStepTimer(dur);
  }

  void _stopPractice() {
    _stepTimer?.cancel();
    _breathPracticeTimer?.cancel();
    _speechCancelToken++; // Cancel any speech-phase Future
    _tts.stop();
    _ttsAudio.stop();
    _stopBreathing();
    _stopBreathingPractice();
    _stopGuidedAudio();
    _stopMeditationOpen();
    setState(() {
      _isPlaying = false;
      _isPracticing = false;
      _isSpeechPhase = false;
      _currentStep = 0;
    });
  }

  // ─── Breathing ─────────────
  void _startBreathing(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('inhale') || lower.contains('श्वास लें')) {
      _breathLabel = '🫁 श्वास लें';
      _breathController.duration = const Duration(seconds: 4);
      _breathController.forward();
    } else if (lower.contains('exhale') || lower.contains('श्वास छोड़ें')) {
      _breathLabel = '🫁 श्वास छोड़ें';
      _breathController.duration = const Duration(seconds: 4);
      _breathController.reverse(from: 1.0);
    } else if (lower.contains('hold') || lower.contains('रोकें')) {
      _breathLabel = '🫁 रोकें';
    } else {
      _breathLabel = '🫁 श्वास छोड़ें';
      _breathController.repeat(reverse: true);
    }
    setState(() => _showBreathIndicator = true);
  }

  void _stopBreathing() {
    _breathController.stop();
    setState(() {
      _showBreathIndicator = false;
      _breathLabel = '';
    });
  }

  // ═══════════════════════════════════════════════════════════════
  // BREATHING PRACTICE ENGINE (Pranayam)
  // Cycle: Inhale → Hold → Exhale → Hold → repeat for N rounds
  // ═══════════════════════════════════════════════════════════════

  /// Initialize and start the breathing cycle from step metadata
  void _beginBreathingCycle(Map<String, dynamic> step) {
    final inhale = step['inhale_seconds'] as int? ?? 4;
    final holdIn = step['hold_after_inhale'] as int? ?? 0;
    final exhale = step['exhale_seconds'] as int? ?? 4;
    final holdOut = step['hold_after_exhale'] as int? ?? 0;
    final rounds = step['total_rounds'] as int? ?? 10;

    // Calculate total duration for progress tracking
    final totalPerRound = inhale + holdIn + exhale + holdOut;

    setState(() {
      _isBreathingPractice = true;
      _breathPracticeRound = 1;
      _breathPracticeTotalRounds = rounds;
      _breathPracticePhase = _BreathPracticePhase.inhale;
      _breathPracticePhaseRemaining = inhale;
      _remainingSeconds = totalPerRound * rounds;
    });

    _animateBreathPhase(_BreathPracticePhase.inhale, inhale);
    _startBreathPracticeTimer();

    // Speak first phase
    if (_voiceEnabled) {
      _speak(_getBreathPracticePhaseLabel(_BreathPracticePhase.inhale));
    }
  }

  /// Drive the circle animation for a given phase
  void _animateBreathPhase(_BreathPracticePhase phase, int durationSeconds) {
    _breathPracticeController.stop();
    final dur = Duration(seconds: durationSeconds.clamp(1, 60));

    switch (phase) {
      case _BreathPracticePhase.inhale:
        _breathPracticeController.duration = dur;
        _breathPracticeController.forward(from: 0);
        break;
      case _BreathPracticePhase.holdInhale:
        _breathPracticeController.value = 1.0; // Stay expanded
        break;
      case _BreathPracticePhase.exhale:
        _breathPracticeController.duration = dur;
        _breathPracticeController.reverse(from: 1.0);
        break;
      case _BreathPracticePhase.holdExhale:
        _breathPracticeController.value = 0.0; // Stay contracted
        break;
    }
  }

  /// Countdown timer for the current breathing phase
  void _startBreathPracticeTimer() {
    _breathPracticeTimer?.cancel();
    _breathPracticeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        _breathPracticePhaseRemaining--;
        _remainingSeconds = (_remainingSeconds - 1).clamp(0, 999999);
      });

      if (_breathPracticePhaseRemaining <= 0) {
        _advanceBreathPracticePhase();
      }
    });
  }

  /// Transition to the next phase (or next round, or complete)
  void _advanceBreathPracticePhase() {
    HapticFeedback.lightImpact();
    final step = widget.steps[_currentStep];
    final inhale = step['inhale_seconds'] as int? ?? 4;
    final holdIn = step['hold_after_inhale'] as int? ?? 0;
    final exhale = step['exhale_seconds'] as int? ?? 4;
    final holdOut = step['hold_after_exhale'] as int? ?? 0;

    _BreathPracticePhase nextPhase;
    int nextDuration;

    switch (_breathPracticePhase) {
      case _BreathPracticePhase.inhale:
        if (holdIn > 0) {
          nextPhase = _BreathPracticePhase.holdInhale;
          nextDuration = holdIn;
        } else {
          nextPhase = _BreathPracticePhase.exhale;
          nextDuration = exhale;
        }
        break;
      case _BreathPracticePhase.holdInhale:
        nextPhase = _BreathPracticePhase.exhale;
        nextDuration = exhale;
        break;
      case _BreathPracticePhase.exhale:
        if (holdOut > 0) {
          nextPhase = _BreathPracticePhase.holdExhale;
          nextDuration = holdOut;
        } else {
          // End of round
          if (_breathPracticeRound >= _breathPracticeTotalRounds) {
            _completeBreathingPractice();
            return;
          }
          setState(() => _breathPracticeRound++);
          nextPhase = _BreathPracticePhase.inhale;
          nextDuration = inhale;
        }
        break;
      case _BreathPracticePhase.holdExhale:
        if (_breathPracticeRound >= _breathPracticeTotalRounds) {
          _completeBreathingPractice();
          return;
        }
        setState(() => _breathPracticeRound++);
        nextPhase = _BreathPracticePhase.inhale;
        nextDuration = inhale;
        break;
    }

    // Speak phase label
    if (_voiceEnabled) {
      _speak(_getBreathPracticePhaseLabel(nextPhase));
    }

    setState(() {
      _breathPracticePhase = nextPhase;
      _breathPracticePhaseRemaining = nextDuration;
    });
    _animateBreathPhase(nextPhase, nextDuration);
  }

  /// All rounds done → auto-advance to next step
  void _completeBreathingPractice() {
    _breathPracticeTimer?.cancel();
    _breathPracticeController.stop();
    HapticFeedback.heavyImpact();
    setState(() => _isBreathingPractice = false);
    _autoAdvance();
  }

  /// Hard stop — resets breathing practice state completely
  void _stopBreathingPractice() {
    _breathPracticeTimer?.cancel();
    _breathPracticeController.stop();
    setState(() {
      _isBreathingPractice = false;
      _breathPracticeRound = 0;
    });
  }

  /// Resume breathing practice from paused state
  void _resumeBreathingPractice() {
    if (!_isBreathingPractice) return;
    setState(() => _isPlaying = true);
    _animateBreathPhase(_breathPracticePhase, _breathPracticePhaseRemaining);
    _startBreathPracticeTimer();
  }

  String _getBreathPracticePhaseLabel(_BreathPracticePhase phase) {
    if (_useHindi) {
      switch (phase) {
        case _BreathPracticePhase.inhale: return 'श्वास लें';
        case _BreathPracticePhase.holdInhale: return 'रोकें';
        case _BreathPracticePhase.exhale: return 'श्वास छोड़ें';
        case _BreathPracticePhase.holdExhale: return 'रोकें';
      }
    }
    switch (phase) {
      case _BreathPracticePhase.inhale: return 'Breathe In';
      case _BreathPracticePhase.holdInhale: return 'Hold';
      case _BreathPracticePhase.exhale: return 'Breathe Out';
      case _BreathPracticePhase.holdExhale: return 'Hold';
    }
  }

  IconData _getBreathPracticePhaseIcon(_BreathPracticePhase phase) {
    switch (phase) {
      case _BreathPracticePhase.inhale: return Icons.arrow_upward_rounded;
      case _BreathPracticePhase.holdInhale: return Icons.pause_rounded;
      case _BreathPracticePhase.exhale: return Icons.arrow_downward_rounded;
      case _BreathPracticePhase.holdExhale: return Icons.pause_rounded;
    }
  }

  Color _getBreathPracticePhaseColor(_BreathPracticePhase phase) {
    switch (phase) {
      case _BreathPracticePhase.inhale: return const Color(0xFF66BB6A);
      case _BreathPracticePhase.holdInhale: return const Color(0xFFFFB74D);
      case _BreathPracticePhase.exhale: return const Color(0xFF42A5F5);
      case _BreathPracticePhase.holdExhale: return const Color(0xFFFFB74D);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // GUIDED AUDIO — Type 1 Meditation
  // ═══════════════════════════════════════════════════════════════
  void _stopGuidedAudio() {
    // InAppAudioPlayer is a separate widget that manages its own AudioPlayer.
    // We just reset the flag. The widget itself disposes when removed from tree.
    if (_isGuidedAudioStep) {
      setState(() => _isGuidedAudioStep = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // OPEN MEDITATION — Type 2 Meditation
  // ═══════════════════════════════════════════════════════════════
  void _beginMeditationOpen(Map<String, dynamic> step) {
    final audioUrl = step['audio_url'] as String?;
    final bellInterval = step['bell_interval_minutes'] as int? ?? 0;

    setState(() {
      _isMeditationOpen = true;
      _meditationOpenElapsed = 0;
      _bellIntervalMinutes = bellInterval;
      _isPlaying = true;
    });

    // Start glow animation
    _meditationGlowController.repeat(reverse: true);

    // Start count-UP timer
    _meditationOpenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _meditationOpenElapsed++);

      // Interval bell
      if (_bellIntervalMinutes > 0) {
        final intervalSec = _bellIntervalMinutes * 60;
        if (_meditationOpenElapsed % intervalSec == 0) {
          HapticFeedback.heavyImpact();
          _playMeditationBell();
        }
      }
    });

    // Start looping audio (if audio_url is provided)
    if (audioUrl != null && audioUrl.isNotEmpty) {
      _startMeditationLoopAudio(audioUrl);
    }
  }

  Future<void> _startMeditationLoopAudio(String url) async {
    try {
      _meditationLoopPlayer?.dispose();
      final player = ap.AudioPlayer();
      _meditationLoopPlayer = player;
      await player.setReleaseMode(ap.ReleaseMode.loop);

      // Check cache first
      final cachedPath = await MediaCacheService().getCachedPath(url);
      // Safety: if widget disposed or meditation stopped during await, abort
      if (!mounted || _meditationLoopPlayer != player) return;

      if (cachedPath != null) {
        await player.play(ap.DeviceFileSource(cachedPath), volume: 0.6);
      } else {
        await player.play(ap.UrlSource(url), volume: 0.6);
        // Cache in background for offline use
        MediaCacheService().cacheInBackground(url: url, mediaType: 'audio');
      }
    } catch (e) {
      debugPrint('🧘 Meditation loop audio error: $e');
    }
  }

  Future<void> _playMeditationBell() async {
    try {
      final bellPlayer = ap.AudioPlayer();
      await bellPlayer.play(ap.AssetSource('sounds/bell.wav'), volume: 0.8);
      // Auto-dispose after playing, with a safety timeout
      bellPlayer.onPlayerComplete.first.then((_) => bellPlayer.dispose());
      // Safety: dispose after 10s even if onPlayerComplete never fires
      Future.delayed(const Duration(seconds: 10), () {
        try { bellPlayer.dispose(); } catch (_) {}
      });
    } catch (e) {
      debugPrint('🔔 Bell play error: $e');
    }
  }

  void _resumeMeditationOpen() {
    if (!_isMeditationOpen) return;
    setState(() => _isPlaying = true);
    _meditationGlowController.repeat(reverse: true);
    _meditationLoopPlayer?.resume();
    _meditationOpenTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _meditationOpenElapsed++);
      if (_bellIntervalMinutes > 0) {
        final intervalSec = _bellIntervalMinutes * 60;
        if (_meditationOpenElapsed % intervalSec == 0) {
          HapticFeedback.heavyImpact();
          _playMeditationBell();
        }
      }
    });
  }

  void _endMeditationOpen() {
    _playMeditationBell();
    _stopMeditationOpen();
    _autoAdvance();
  }

  void _stopMeditationOpen() {
    _meditationOpenTimer?.cancel();
    _meditationOpenTimer = null;
    _meditationLoopPlayer?.stop();
    _meditationLoopPlayer?.dispose();
    _meditationLoopPlayer = null;
    _meditationGlowController.stop();
    _meditationGlowController.reset();
    if (_isMeditationOpen) {
      setState(() {
        _isMeditationOpen = false;
        _meditationOpenElapsed = 0;
      });
    }
  }

  String _formatMeditationTime(int totalSeconds) {
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ─── Overview Step Icon / Color Helpers ──────────────
  String? _getOverviewStepIcon(String stepType) {
    switch (stepType) {
      case 'breathing_practice': return '🌬️';
      case 'guided_audio': return '🎧';
      case 'meditation_open': return '🧘';
      default: return null; // Normal pose — no icon, show image
    }
  }

  Color _getOverviewStepColor(String stepType) {
    switch (stepType) {
      case 'breathing_practice': return const Color(0xFF66BB6A);
      case 'guided_audio': return const Color(0xFF7E57C2);
      case 'meditation_open': return const Color(0xFF26C6DA);
      default: return const Color(0xFF66BB6A);
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('🎉 Practice Complete!', style: TextStyle(fontSize: 22)),
        content: Text(
          'Excellent! You completed all ${widget.steps.length} steps.',
          style: const TextStyle(height: 1.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _stopPractice();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Done!'),
          ),
        ],
      ),
    );
  }

  // ─── Total duration ─────────────
  String _totalDuration() {
    int total = 0;
    for (final s in widget.steps) {
      total += (s['duration_seconds'] as int?) ?? 10;
    }
    final min = total ~/ 60;
    final sec = total % 60;
    return min > 0 ? '${min}m ${sec}s' : '${sec}s';
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    if (widget.steps.isEmpty) return _buildEmptyState();
    return _isPracticing ? _buildGuidedPractice() : _buildOverview();
  }

  // ═══════════════════════════════════════════════════════════════
  // OVERVIEW MODE — Session info, pose grid, start button
  // ═══════════════════════════════════════════════════════════════
  Widget _buildOverview() {
    final poseName = widget.pose['name'] ?? 'Practice';
    final poseNameHindi = widget.pose['name_hindi'] ?? '';
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
      child: Column(
        children: [
          // ── Session Info Card ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(5.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Emoji
                Text('🧘', style: TextStyle(fontSize: 36)),
                SizedBox(height: 1.h),
                // Title
                Text(
                  poseNameHindi.isNotEmpty ? poseNameHindi : poseName,
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (poseNameHindi.isNotEmpty)
                  Text(
                    poseName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                SizedBox(height: 1.5.h),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _infoChip(Icons.format_list_numbered, '${widget.steps.length} Steps', primary),
                    SizedBox(width: 3.w),
                    _infoChip(Icons.timer_outlined, _totalDuration(), primary),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // ── Pose Sequence Grid ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.grid_view_rounded, size: 20, color: primary),
                    SizedBox(width: 2.w),
                    Text(
                      'Pose Sequence',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 2.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 2.w,
                    mainAxisSpacing: 2.w,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: widget.steps.length,
                  itemBuilder: (_, i) {
                    final step = widget.steps[i];
                    final img = step['image_url'] as String?;
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _isPracticing = true;
                          _currentStep = i;
                        });
                        Future.microtask(() {
                          if (_pageController.hasClients) {
                            _pageController.jumpToPage(i);
                          }
                          final dur = step['duration_seconds'] as int? ?? 10;
                          _startStepTimer(dur);
                        });
                      },
                      child: Column(
                        children: [
                          Expanded(
                            child: _getOverviewStepIcon(step['step_type'] as String? ?? 'pose') != null
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: _getOverviewStepColor(step['step_type'] as String? ?? 'pose').withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getOverviewStepColor(step['step_type'] as String? ?? 'pose').withOpacity(0.3),
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(_getOverviewStepIcon(step['step_type'] as String? ?? 'pose')!, style: const TextStyle(fontSize: 28)),
                                    ),
                                  )
                                : CachedPoseThumbnail(
                                    imageUrl: img,
                                    index: i,
                                    borderColor: primary.withValues(alpha: 0.2),
                                  ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: 3.h),

          // ── Hindi / Voice Toggle Row ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() => _useHindi = !_useHindi);
                    _initTts();
                  },
                  icon: Text('ॐ', style: TextStyle(fontSize: 16, color: primary)),
                  label: Text(
                    _useHindi ? 'हिंदी' : 'English',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: primary.withOpacity(0.3)),
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _voiceEnabled = !_voiceEnabled),
                  icon: Icon(
                    _voiceEnabled ? Icons.volume_up : Icons.volume_off,
                    color: _voiceEnabled ? primary : theme.colorScheme.onSurfaceVariant,
                    size: 20,
                  ),
                  label: Text(
                    _voiceEnabled ? 'Voice ON' : 'Voice OFF',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _voiceEnabled ? primary : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: _voiceEnabled
                          ? primary.withOpacity(0.3)
                          : theme.colorScheme.outline.withOpacity(0.3),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 3.h),

          // ── Start Practice Button ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _isPracticing = true;
                  _currentStep = 0;
                });
                Future.microtask(() {
                  final dur = widget.steps[0]['duration_seconds'] as int? ?? 10;
                  _startStepTimer(dur);
                });
              },
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: Text(
                'Start Practice',
                style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: primary.withOpacity(0.3),
              ),
            ),
          ),

          SizedBox(height: 2.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GUIDED PRACTICE MODE — Step-by-step with timer, breathing, controls
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGuidedPractice() {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Stack(
      children: [
        Column(
          children: [
            // ── Step indicator + audio + camera + timer ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              child: Row(
                children: [
                  // Step badge
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Step ${_currentStep + 1}/${widget.steps.length}',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Camera toggle
                  GestureDetector(
                    onTap: _toggleCamera,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: _isCameraOpen
                            ? primary.withOpacity(0.15)
                            : theme.colorScheme.surface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _isCameraOpen
                              ? primary
                              : theme.colorScheme.outline.withOpacity(0.3),
                        ),
                      ),
                      child: Icon(
                        _isCameraOpen ? Icons.videocam : Icons.videocam_outlined,
                        color: _isCameraOpen ? primary : theme.colorScheme.onSurfaceVariant,
                        size: 20,
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  // Audio icon
                  GestureDetector(
                    onTap: () => setState(() => _voiceEnabled = !_voiceEnabled),
                    child: Icon(
                      _voiceEnabled ? Icons.volume_up : Icons.volume_off,
                      color: _voiceEnabled ? primary : theme.colorScheme.onSurfaceVariant,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 3.w),
                  // Timer badge (shows speech/hold/breathing phase)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: _isSpeechPhase 
                          ? Colors.green.shade600
                          : _isBreathingPractice
                              ? _getBreathPracticePhaseColor(_breathPracticePhase)
                              : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSpeechPhase) ...[
                          const Icon(Icons.mic, color: Colors.white, size: 14),
                          SizedBox(width: 1.w),
                        ] else if (_isBreathingPractice) ...[
                          Icon(_getBreathPracticePhaseIcon(_breathPracticePhase), color: Colors.white, size: 14),
                          SizedBox(width: 1.w),
                        ],
                        Text(
                          _isSpeechPhase
                              ? 'सुनें'
                              : _isBreathingPractice
                                  ? '${_breathPracticePhaseRemaining}s'
                                  : '${_remainingSeconds}s',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Step progress bar ──
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: widget.steps.length > 0
                      ? (_currentStep + 1) / widget.steps.length
                      : 0,
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation<Color>(primary),
                ),
              ),
            ),

            SizedBox(height: 1.h),

            // ── Step PageView ──
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.steps.length,
                onPageChanged: (index) {
                  // Only cancel timer on manual swipe, not auto-advance
                  if (!_isAutoAdvancing) {
                    _stepTimer?.cancel();
                    _breathPracticeTimer?.cancel();
                    _speechCancelToken++; // Cancel any in-flight speech
                    _tts.stop();          // Stop device TTS
                    _ttsAudio.stop();     // Stop Sarvam AI audio
                    _stopBreathingPractice();
                    _stopGuidedAudio();
                    _stopMeditationOpen();
                    setState(() {
                      _currentStep = index;
                      _isPlaying = false;
                      _isSpeechPhase = false;
                    });
                    _stopBreathing();
                  }
                },
                physics: _isPlaying
                    ? const NeverScrollableScrollPhysics()
                    : const BouncingScrollPhysics(),
                itemBuilder: (context, index) {
                  return _buildStepCard(index);
                },
              ),
            ),

            // ── Playback Controls ──
            Container(
              padding: EdgeInsets.fromLTRB(4.w, 1.h, 4.w, 2.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Previous
                  _controlButton(
                    icon: Icons.skip_previous_rounded,
                    size: 28,
                    onTap: _currentStep > 0 ? () => _goToStep(_currentStep - 1) : null,
                    theme: theme,
                  ),
                  // Play/Pause
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      if (_isPlaying) {
                        _pauseTimer();
                      } else if (_isBreathingPractice) {
                        // Resume breathing practice from paused state
                        _resumeBreathingPractice();
                      } else if (_isMeditationOpen) {
                        // Resume open meditation
                        _resumeMeditationOpen();
                      } else if (_isGuidedAudioStep) {
                        // Guided audio manages own play/pause via embedded player
                        setState(() => _isPlaying = true);
                      } else if (_remainingSeconds > 0) {
                        // Resume hold timer from where it was paused
                        // Do NOT re-trigger _speakStepGuidance — just resume countdown
                        setState(() => _isPlaying = true);
                        final step = widget.steps[_currentStep];
                        final stepType = step['step_type'] as String? ?? 'pose';
                        if (stepType == 'pose') {
                          final breathType = step['breathing'] ?? '';
                          if (breathType.toString().isNotEmpty) {
                            _startBreathing(breathType.toString());
                          }
                        }
                        _stepTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                          if (!mounted) { timer.cancel(); return; }
                          setState(() => _remainingSeconds--);
                          if (_remainingSeconds <= 0) {
                            timer.cancel();
                            _autoAdvance();
                          }
                        });
                      } else {
                        // Fresh start — no remaining time
                        final dur = widget.steps[_currentStep]['duration_seconds'] as int? ?? 10;
                        _startStepTimer(dur);
                      }
                    },
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [primary, primary.withOpacity(0.8)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: primary.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                  // Next
                  _controlButton(
                    icon: Icons.skip_next_rounded,
                    size: 28,
                    onTap: _currentStep < widget.steps.length - 1
                        ? () => _goToStep(_currentStep + 1)
                        : null,
                    theme: theme,
                  ),
                  // Stop
                  _controlButton(
                    icon: Icons.stop_rounded,
                    size: 28,
                    color: Colors.redAccent,
                    onTap: _stopPractice,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),

        // ── Draggable & Resizable Camera PIP ──
        if (_isCameraOpen && _cameraInitialized && _cameraController != null)
          Positioned(
            left: _cameraPosition.dx,
            top: _cameraPosition.dy,
            child: GestureDetector(
              // Drag to move
              onPanUpdate: (details) {
                setState(() {
                  _cameraPosition += details.delta;
                  // Keep within screen bounds
                  final maxX = MediaQuery.of(context).size.width - _cameraWidth - 8;
                  final maxY = MediaQuery.of(context).size.height * 0.7;
                  _cameraPosition = Offset(
                    _cameraPosition.dx.clamp(0.0, maxX),
                    _cameraPosition.dy.clamp(0.0, maxY),
                  );
                });
              },
              // Double-tap to cycle size presets
              onDoubleTap: _cycleCameraSize,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: _cameraWidth,
                height: _cameraHeight,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: primary, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    // Camera feed
                    Positioned.fill(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _cameraController!.value.previewSize?.height ?? 480,
                          height: _cameraController!.value.previewSize?.width ?? 640,
                          child: CameraPreview(_cameraController!),
                        ),
                      ),
                    ),
                    
                    // Top bar: expand + close buttons
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Expand/shrink toggle
                          GestureDetector(
                            onTap: _cycleCameraSize,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _cameraSizePreset == 2
                                    ? Icons.close_fullscreen_rounded
                                    : Icons.open_in_full_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          // Close button
                          GestureDetector(
                            onTap: _toggleCamera,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Bottom-right resize handle (drag to resize freely)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onPanUpdate: (details) {
                          setState(() {
                            _cameraWidth = (_cameraWidth + details.delta.dx)
                                .clamp(_cameraMinW, _cameraMaxW);
                            _cameraHeight = (_cameraHeight + details.delta.dy)
                                .clamp(_cameraMinH, _cameraMaxH);
                          });
                        },
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.7),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(8),
                              bottomRight: Radius.circular(14),
                            ),
                          ),
                          child: const Icon(
                            Icons.drag_handle_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ),
                      ),
                    ),
                    
                    // Size label (shows briefly on size change via preset)
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // STEP CARD — Pose image + name + mantra + instruction
  // ═══════════════════════════════════════════════════════════════
  Widget _buildStepCard(int index) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final step = widget.steps[index];

    // ── Branch: Breathing practice card for pranayam steps ──
    final stepType = step['step_type'] as String? ?? 'pose';
    if (stepType == 'breathing_practice') {
      return _buildBreathingPracticeCard(index);
    } else if (stepType == 'guided_audio') {
      return _buildGuidedAudioCard(index);
    } else if (stepType == 'meditation_open') {
      return _buildMeditationOpenCard(index);
    }

    // ── Normal pose step card ──
    final stepTitle = step['name'] ?? 'Step ${index + 1}';
    final stepTitleHindi = step['name_hindi'] ?? '';
    final stepDesc = _useHindi
        ? (step['instruction_hindi'] ?? step['instruction'] ?? '')
        : (step['instruction'] ?? '');
    final stepImage = step['image_url'] as String?;
    final mantra = step['mantra'] ?? '';
    final tips = step['tips'] as List? ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          SizedBox(height: 1.h),
          // ── Pose Card with image ──
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primary.withOpacity(0.15)),
              boxShadow: [
                BoxShadow(
                  color: primary.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Image with breathing indicator overlay
                if (stepImage != null && stepImage.isNotEmpty)
                  Stack(
                    children: [
                      CachedPoseImage(
                        imageUrl: stepImage,
                        width: double.infinity,
                        height: 22.h,
                        fit: BoxFit.contain,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                        animate: true,
                        breathe: _isPlaying && _currentStep == index,
                        placeholderColor: primary.withValues(alpha: 0.08),
                      ),
                      // Breathing indicator badge on image
                      if (_showBreathIndicator)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: ScaleTransition(
                            scale: _breathAnimation,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 3.w,
                                vertical: 0.5.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4CAF50).withOpacity(0.9),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                _breathLabel,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                // Title + Mantra
                Padding(
                  padding: EdgeInsets.all(4.w),
                  child: Column(
                    children: [
                      Text(
                        stepTitleHindi.isNotEmpty ? stepTitleHindi : stepTitle,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (mantra.toString().isNotEmpty) ...[
                        SizedBox(height: 0.8.h),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 4.w,
                            vertical: 0.8.h,
                          ),
                          decoration: BoxDecoration(
                            color: primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            mantra.toString(),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // ── Instructions Card ──
          if (stepDesc.toString().isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: primary),
                      SizedBox(width: 2.w),
                      Text(
                        _useHindi ? 'निर्देश' : 'Instructions',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    stepDesc.toString(),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  // Tips
                  if (tips.isNotEmpty) ...[
                    SizedBox(height: 1.5.h),
                    ...tips.map((tip) => Padding(
                          padding: EdgeInsets.only(bottom: 0.5.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💡 ', style: TextStyle(fontSize: 13.sp)),
                              Expanded(
                                child: Text(
                                  tip.toString(),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BREATHING PRACTICE CARD — Animated circle + phase + rounds
  // Used for pranayam steps with step_type = 'breathing_practice'
  // ═══════════════════════════════════════════════════════════════
  Widget _buildBreathingPracticeCard(int index) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final step = widget.steps[index];
    final stepTitle = _useHindi
        ? (step['name_hindi'] ?? step['name'] ?? 'Main Practice')
        : (step['name'] ?? 'Main Practice');
    final stepDesc = _useHindi
        ? (step['instruction_hindi'] ?? step['instruction'] ?? '')
        : (step['instruction'] ?? '');
    final tips = step['tips'] as List? ?? [];
    final inhale = step['inhale_seconds'] as int? ?? 4;
    final holdIn = step['hold_after_inhale'] as int? ?? 0;
    final exhale = step['exhale_seconds'] as int? ?? 4;
    final holdOut = step['hold_after_exhale'] as int? ?? 0;
    final rounds = step['total_rounds'] as int? ?? 10;

    final isActive = _isPlaying && _isBreathingPractice && _currentStep == index;

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          SizedBox(height: 1.h),

          // ── Breathing Practice Card ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 2.5.h, horizontal: 4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? _getBreathPracticePhaseColor(_breathPracticePhase).withOpacity(0.4)
                    : primary.withOpacity(0.15),
                width: isActive ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isActive
                          ? _getBreathPracticePhaseColor(_breathPracticePhase)
                          : primary)
                      .withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Title ──
                Text(
                  '🌬️ $stepTitle',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                // ── Round counter (when active) ──
                if (isActive) ...[
                  SizedBox(height: 0.8.h),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.3.h),
                    decoration: BoxDecoration(
                      color: _getBreathPracticePhaseColor(_breathPracticePhase)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _useHindi
                          ? 'चक्र $_breathPracticeRound / $_breathPracticeTotalRounds'
                          : 'Round $_breathPracticeRound / $_breathPracticeTotalRounds',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: _getBreathPracticePhaseColor(_breathPracticePhase),
                      ),
                    ),
                  ),
                ],

                SizedBox(height: 2.h),

                // ── Animated Breathing Circle ──
                if (isActive)
                  _buildAnimatedBreathCircle()
                else
                  _buildBreathCirclePreview(inhale, holdIn, exhale, holdOut, rounds),

                SizedBox(height: 2.h),

                // ── Phase indicator pills (when active) ──
                if (isActive)
                  _buildPhaseIndicatorRow(holdIn > 0, holdOut > 0),

                if (isActive) SizedBox(height: 1.h),
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // ── Instructions Card ──
          if (stepDesc.toString().isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: primary),
                      SizedBox(width: 2.w),
                      Text(
                        _useHindi ? 'निर्देश' : 'Instructions',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    stepDesc.toString(),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  if (tips.isNotEmpty) ...[
                    SizedBox(height: 1.5.h),
                    ...tips.map((tip) => Padding(
                          padding: EdgeInsets.only(bottom: 0.5.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💡 ', style: TextStyle(fontSize: 13.sp)),
                              Expanded(
                                child: Text(
                                  tip.toString(),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // GUIDED AUDIO CARD — Embedded audio player for guided meditation
  // Uses InAppAudioPlayer widget (streaming + offline caching built-in)
  // ═══════════════════════════════════════════════════════════════
  Widget _buildGuidedAudioCard(int index) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final step = widget.steps[index];
    final stepTitle = _useHindi
        ? (step['name_hindi'] ?? step['name'] ?? 'Guided Practice')
        : (step['name'] ?? 'Guided Practice');
    final stepDesc = _useHindi
        ? (step['instruction_hindi'] ?? step['instruction'] ?? '')
        : (step['instruction'] ?? '');
    final audioUrl = step['audio_url'] as String? ?? '';
    final tips = step['tips'] as List? ?? [];

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          SizedBox(height: 1.h),

          // ── Guided Audio Title Card ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 2.h, horizontal: 4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF7E57C2).withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF7E57C2).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Text(
                  '🎧 $stepTitle',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (stepDesc.toString().isNotEmpty) ...[
                  SizedBox(height: 0.8.h),
                  Text(
                    stepDesc.toString(),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // ── Embedded Audio Player ──
          if (audioUrl.isNotEmpty)
            InAppAudioPlayer(
              audioUrl: audioUrl,
              title: _useHindi
                  ? (step['name_hindi'] ?? step['name'] ?? 'Guided Meditation')
                  : (step['name'] ?? 'Guided Meditation'),
              titleHindi: step['name_hindi'] as String?,
              category: 'meditation',
              durationSeconds: step['duration_seconds'] as int?,
              autoPlay: true,
              onComplete: () {
                // Auto-advance to next step when audio finishes
                _stopGuidedAudio();
                _autoAdvance();
              },
            )
          else
            Container(
              width: double.infinity,
              height: 20.h,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.audio_file, size: 40, color: primary.withOpacity(0.4)),
                    SizedBox(height: 1.h),
                    Text(
                      _useHindi ? 'ऑडियो उपलब्ध नहीं है' : 'Audio not available',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Tips ──
          if (tips.isNotEmpty) ...[
            SizedBox(height: 2.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.tips_and_updates, size: 18, color: primary),
                      SizedBox(width: 2.w),
                      Text(
                        _useHindi ? 'सुझाव' : 'Tips',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  ...tips.map((tip) => Padding(
                        padding: EdgeInsets.only(bottom: 0.5.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('💡 ', style: TextStyle(fontSize: 13.sp)),
                            Expanded(
                              child: Text(
                                tip.toString(),
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
          ],

          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // OPEN MEDITATION CARD — Self-paced with count-up timer + glow
  // Looping audio (Om), optional interval bell, manual end
  // ═══════════════════════════════════════════════════════════════
  Widget _buildMeditationOpenCard(int index) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final step = widget.steps[index];
    final stepTitle = _useHindi
        ? (step['name_hindi'] ?? step['name'] ?? 'Open Meditation')
        : (step['name'] ?? 'Open Meditation');
    final stepDesc = _useHindi
        ? (step['instruction_hindi'] ?? step['instruction'] ?? '')
        : (step['instruction'] ?? '');
    final tips = step['tips'] as List? ?? [];
    final bellInterval = step['bell_interval_minutes'] as int? ?? 0;

    final isActive = _isPlaying && _isMeditationOpen && _currentStep == index;

    // Meditation theme colors
    const meditationCyan = Color(0xFF26C6DA);
    const meditationDeep = Color(0xFF00838F);
    const meditationGlow = Color(0xFF4DD0E1);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        children: [
          SizedBox(height: 1.h),

          // ── Main Meditation Card ──
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 4.w),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isActive
                    ? meditationCyan.withOpacity(0.5)
                    : meditationCyan.withOpacity(0.2),
                width: isActive ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isActive ? meditationCyan : primary).withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // ── Title ──
                Text(
                  '🧘 $stepTitle',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),

                SizedBox(height: 3.h),

                // ── Breathing Glow Circle with Timer ──
                if (isActive)
                  AnimatedBuilder(
                    animation: _meditationGlowAnimation,
                    builder: (context, child) {
                      final scale = _meditationGlowAnimation.value;
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 50.w,
                              height: 50.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    meditationGlow.withOpacity(0.2 * scale),
                                    meditationCyan.withOpacity(0.05),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Inner circle
                          Container(
                            width: 38.w,
                            height: 38.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  meditationDeep.withOpacity(0.25),
                                  meditationCyan.withOpacity(0.1),
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: meditationCyan.withOpacity(0.3),
                                  blurRadius: 24,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _formatMeditationTime(_meditationOpenElapsed),
                                    style: TextStyle(
                                      fontSize: 26.sp,
                                      fontWeight: FontWeight.w300,
                                      color: meditationDeep,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  SizedBox(height: 0.5.h),
                                  Text(
                                    _useHindi ? 'ध्यान में' : 'meditating',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: meditationDeep.withOpacity(0.7),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  )
                else
                  // Preview state
                  Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          meditationCyan.withOpacity(0.15),
                          meditationCyan.withOpacity(0.05),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.self_improvement,
                              size: 40, color: meditationDeep.withOpacity(0.6)),
                          SizedBox(height: 0.5.h),
                          Text(
                            _useHindi ? 'ध्यान शुरू करें' : 'Start Meditation',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: meditationDeep.withOpacity(0.6),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                SizedBox(height: 2.5.h),

                // ── Bell Interval Indicator ──
                if (bellInterval > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: meditationCyan.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('🔔', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 1.5.w),
                        Text(
                          _useHindi
                              ? 'हर $bellInterval मिनट पर घंटी'
                              : 'Bell every $bellInterval min',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: meditationDeep,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                // ── End Meditation Button (only when active) ──
                if (isActive) ...[
                  SizedBox(height: 3.h),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.heavyImpact();
                      _endMeditationOpen();
                    },
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 1.5.h),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [meditationDeep, meditationCyan],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: meditationCyan.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.stop_rounded, color: Colors.white, size: 24),
                          SizedBox(width: 2.w),
                          Text(
                            _useHindi ? 'ध्यान समाप्त करें 🙏' : 'End Meditation 🙏',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          SizedBox(height: 2.h),

          // ── Instructions Card ──
          if (stepDesc.toString().isNotEmpty)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outline.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, size: 18, color: primary),
                      SizedBox(width: 2.w),
                      Text(
                        _useHindi ? 'निर्देश' : 'Instructions',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    stepDesc.toString(),
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.6,
                    ),
                  ),
                  if (tips.isNotEmpty) ...[
                    SizedBox(height: 1.5.h),
                    ...tips.map((tip) => Padding(
                          padding: EdgeInsets.only(bottom: 0.5.h),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('💡 ', style: TextStyle(fontSize: 13.sp)),
                              Expanded(
                                child: Text(
                                  tip.toString(),
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: theme.colorScheme.onSurfaceVariant,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),

          SizedBox(height: 4.h),
        ],
      ),
    );
  }


  Widget _buildAnimatedBreathCircle() {
    final phaseColor = _getBreathPracticePhaseColor(_breathPracticePhase);
    final phaseLabel = _getBreathPracticePhaseLabel(_breathPracticePhase);
    final phaseIcon = _getBreathPracticePhaseIcon(_breathPracticePhase);

    return AnimatedBuilder(
      animation: _breathPracticeAnimation,
      builder: (context, child) {
        final circleSize = 100 + (_breathPracticeAnimation.value * 60);
        return SizedBox(
          height: 180,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Glow ring
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: circleSize + 24,
                  height: circleSize + 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: phaseColor.withOpacity(0.2),
                      width: 2,
                    ),
                  ),
                ),
                // Main circle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        phaseColor.withOpacity(0.3),
                        phaseColor.withOpacity(0.15),
                        phaseColor.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(color: phaseColor.withOpacity(0.6), width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: phaseColor.withOpacity(0.25),
                        blurRadius: 20,
                        spreadRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(phaseIcon, color: phaseColor, size: 28),
                      SizedBox(height: 0.5.h),
                      Text(
                        phaseLabel,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w700,
                          color: phaseColor,
                        ),
                      ),
                      Text(
                        '${_breathPracticePhaseRemaining}',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: phaseColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Preview circle shown when breathing practice is not yet started
  Widget _buildBreathCirclePreview(
    int inhale, int holdIn, int exhale, int holdOut, int rounds,
  ) {
    final theme = Theme.of(context);
    final previewColor = const Color(0xFF66BB6A);

    return SizedBox(
      height: 180,
      child: Center(
        child: Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: previewColor.withOpacity(0.08),
            border: Border.all(color: previewColor.withOpacity(0.3), width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.air_rounded, size: 32, color: previewColor),
              SizedBox(height: 0.5.h),
              Text(
                _useHindi ? 'श्वास अभ्यास' : 'Breathing',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: previewColor,
                ),
              ),
              SizedBox(height: 0.3.h),
              Text(
                '$rounds ${_useHindi ? 'चक्र' : 'rounds'}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              // Timing info
              Text(
                '${inhale}s-${holdIn > 0 ? '${holdIn}s-' : ''}${exhale}s${holdOut > 0 ? '-${holdOut}s' : ''}',
                style: TextStyle(
                  fontSize: 10.sp,
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Phase indicator pills showing the current position in the breathing cycle
  Widget _buildPhaseIndicatorRow(bool hasHoldIn, bool hasHoldOut) {
    Widget pill(_BreathPracticePhase phase, String label) {
      final isActive = _breathPracticePhase == phase;
      final color = _getBreathPracticePhaseColor(phase);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 2.5.w, vertical: 0.4.h),
        decoration: BoxDecoration(
          color: isActive ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isActive ? color : color.withOpacity(0.25),
            width: isActive ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? color : color.withOpacity(0.5),
          ),
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        pill(_BreathPracticePhase.inhale, _useHindi ? 'श्वास' : 'In'),
        SizedBox(width: 1.w),
        Icon(Icons.arrow_forward_ios, size: 8, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3)),
        if (hasHoldIn) ...[
          SizedBox(width: 1.w),
          pill(_BreathPracticePhase.holdInhale, _useHindi ? 'रोकें' : 'Hold'),
          SizedBox(width: 1.w),
          Icon(Icons.arrow_forward_ios, size: 8, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3)),
        ],
        SizedBox(width: 1.w),
        pill(_BreathPracticePhase.exhale, _useHindi ? 'निश्वास' : 'Out'),
        if (hasHoldOut) ...[
          SizedBox(width: 1.w),
          Icon(Icons.arrow_forward_ios, size: 8, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3)),
          SizedBox(width: 1.w),
          pill(_BreathPracticePhase.holdExhale, _useHindi ? 'रोकें' : 'Hold'),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // HELPER WIDGETS
  // ═══════════════════════════════════════════════════════════════

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(8.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 56,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
            SizedBox(height: 2.h),
            Text(
              'No practice steps available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Steps for this pose will be added soon',
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          SizedBox(width: 1.w),
          Text(
            text,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required double size,
    VoidCallback? onTap,
    Color? color,
    required ThemeData theme,
  }) {
    final c = color ?? theme.colorScheme.onSurface;
    return GestureDetector(
      onTap: onTap != null
          ? () {
              HapticFeedback.lightImpact();
              onTap();
            }
          : null,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: onTap != null
                ? theme.colorScheme.outline.withOpacity(0.3)
                : theme.colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Icon(
          icon,
          size: size,
          color: onTap != null ? c : c.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _stepPlaceholder(int index) {
    return Container(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
      child: Center(
        child: Text(
          '${index + 1}',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          ),
        ),
      ),
    );
  }
}

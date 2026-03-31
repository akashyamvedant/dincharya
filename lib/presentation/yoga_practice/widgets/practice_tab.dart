import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../../services/yoga_tts_service.dart';
import '../../../services/tts_audio_service.dart';
import './cached_pose_image.dart';

/// ═══════════════════════════════════════════════════════════════
/// PRACTICE TAB — Rich interactive step-by-step yoga practice guide
/// Features: Overview mode, Guided practice, TTS, Breathing indicator,
///           Pose card with image, mantra, instructions, playback controls
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
  void dispose() {
    _stepTimer?.cancel();
    _tts.stop();
    _ttsAudio.stop();
    _breathController.dispose();
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
    _speechCancelToken++; // Cancel any previous speech-phase

    setState(() {
      _remainingSeconds = seconds;
      _isPlaying = true;
      _isSpeechPhase = true;
    });

    // Start breathing animation if this is a breathing step
    final step = widget.steps[_currentStep];
    final breathType = step['breathing'] ?? '';
    if (breathType.toString().isNotEmpty) {
      _startBreathing(breathType.toString());
    } else {
      _stopBreathing();
    }

    // Voice-first: speak guidance, THEN start hold timer
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

    // Phase 2: Start hold timer
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
    _speechCancelToken++; // Cancel any speech-phase Future
    _tts.stop();
    _ttsAudio.stop();
    setState(() {
      _isPlaying = false;
      _isSpeechPhase = false;
    });
    _stopBreathing();
  }

  void _autoAdvance() {
    if (_currentStep < widget.steps.length - 1) {
      _goToStep(_currentStep + 1);
    } else {
      // Practice complete
      setState(() => _isPlaying = false);
      _stopBreathing();
      HapticFeedback.heavyImpact();
      _showCompletionDialog();
    }
  }

  void _goToStep(int index) {
    if (index < 0 || index >= widget.steps.length) return;
    _stepTimer?.cancel();
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
    _speechCancelToken++; // Cancel any speech-phase Future
    _tts.stop();
    _ttsAudio.stop();
    _stopBreathing();
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
                            child: CachedPoseThumbnail(
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
                  // Timer badge (shows speech/hold phase)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                    decoration: BoxDecoration(
                      color: _isSpeechPhase 
                          ? Colors.green.shade600 
                          : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isSpeechPhase) ...[
                          const Icon(Icons.mic, color: Colors.white, size: 14),
                          SizedBox(width: 1.w),
                        ],
                        Text(
                          _isSpeechPhase ? 'सुनें' : '${_remainingSeconds}s',
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
                    setState(() {
                      _currentStep = index;
                      _isPlaying = false;
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
                      } else {
                        final dur = widget.steps[_currentStep]['duration_seconds'] as int? ?? 10;
                        _startStepTimer(_remainingSeconds > 0 ? _remainingSeconds : dur);
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

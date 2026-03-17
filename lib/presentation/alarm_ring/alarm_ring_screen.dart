// lib/presentation/alarm_ring/alarm_ring_screen.dart
// Premium alarm ring screen for wakeup tasks.
// Plays custom ringtone from Supabase-cached file using audioplayers.
// The notification sound provides fallback; this screen plays the user's chosen sound.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../services/alarm_service.dart';

class AlarmRingScreen extends StatefulWidget {
  final String taskId;
  final String taskTitle;
  final String soundId;

  const AlarmRingScreen({
    super.key,
    required this.taskId,
    required this.taskTitle,
    this.soundId = 'gentle_morning',
  });

  /// Create from notification payload
  factory AlarmRingScreen.fromPayload(String payload) {
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      return AlarmRingScreen(
        taskId: data['taskId'] as String? ?? '',
        taskTitle: data['taskTitle'] as String? ?? 'Wake Up',
        soundId: data['soundId'] as String? ?? 'gentle_morning',
      );
    } catch (e) {
      return const AlarmRingScreen(
        taskId: '',
        taskTitle: 'Wake Up',
      );
    }
  }

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _glowController;

  Timer? _autoDismissTimer;
  bool _isDismissing = false;
  double _dismissDragOffset = 0;

  // Audio player for custom ringtone from Supabase
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAudioPlaying = false;

  // Premium warm color scheme matching DinCharya wakeup theme
  static const Color _primaryAmber = Color(0xFFF57F17);
  static const Color _darkBg = Color(0xFF1A1208);
  static const Color _warmGold = Color(0xFFFFD54F);
  static const Color _deepOrange = Color(0xFFFF8F00);
  static const Color _softWhite = Color(0xFFFFF8E1);

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _startAutoDismissTimer();
    _startCustomRingtone();

    // Enable immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Start playing the user's custom ringtone from cached Supabase file
  Future<void> _startCustomRingtone() async {
    try {
      final alarmService = AlarmService();
      
      // Get the cached sound file path (downloads from Supabase if needed)
      final sound = AlarmService.availableSounds.firstWhere(
        (s) => s.id == widget.soundId,
        orElse: () => AlarmService.availableSounds.first,
      );

      final cachedPath = await alarmService.getCachedSoundPath(sound.fileName);
      
      if (cachedPath != null) {
        // Alarm channel is SILENT (v4) — no notification sound to compete with.
        // Just play the custom ringtone directly.
        
        // Set looping mode — alarm should repeat until dismissed
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
        
        // Set volume to max for alarm
        await _audioPlayer.setVolume(1.0);
        
        // Play the custom sound from cached file
        await _audioPlayer.play(DeviceFileSource(cachedPath));
        _isAudioPlaying = true;
        
        debugPrint('🎵 Custom ringtone playing: ${sound.displayName} from $cachedPath');
      } else {
        debugPrint('⚠️ Custom ringtone not cached, falling back to notification sound');
        // Notification sound (alarm_tone) continues playing via FLAG_INSISTENT
      }
    } catch (e) {
      debugPrint('❌ Failed to play custom ringtone: $e');
      // Notification sound continues as fallback
    }
  }

  /// Stop the custom ringtone
  Future<void> _stopCustomRingtone() async {
    try {
      if (_isAudioPlaying) {
        await _audioPlayer.stop();
        _isAudioPlaying = false;
        debugPrint('🔇 Custom ringtone stopped');
      }
    } catch (e) {
      debugPrint('Error stopping ringtone: $e');
    }
  }

  void _startAutoDismissTimer() {
    _autoDismissTimer = Timer(const Duration(minutes: 5), () {
      if (mounted) _dismissAlarm();
    });
  }

  void _dismissAlarm() async {
    if (_isDismissing) return;
    _isDismissing = true;

    // Stop custom ringtone first
    await _stopCustomRingtone();

    // Cancel the notification — this stops the alarm sound (FLAG_INSISTENT)
    await AlarmService().cancelAlarm(widget.taskId);

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    if (mounted) {
      HapticFeedback.heavyImpact();
      Navigator.of(context).pop();
    }
  }

  void _snoozeAlarm() async {
    if (_isDismissing) return;
    _isDismissing = true;

    // Stop custom ringtone
    await _stopCustomRingtone();

    // Cancel current notification (stops sound), then schedule snooze
    await AlarmService().cancelAlarm(widget.taskId);
    await AlarmService().snoozeAlarm(
      taskId: widget.taskId,
      soundId: widget.soundId,
      taskTitle: widget.taskTitle,
      snoozeMinutes: 5,
    );

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    HapticFeedback.mediumImpact();

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _pulseController.dispose();
    _glowController.dispose();
    _audioPlayer.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: _darkBg,
        body: Stack(
          children: [
            // Animated gradient background
            _buildAnimatedBackground(),

            // Main content
            SafeArea(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: screenHeight -
                        MediaQuery.of(context).padding.top -
                        MediaQuery.of(context).padding.bottom,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.symmetric(horizontal: screenWidth * 0.06),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        SizedBox(height: screenHeight * 0.04),

                        // Top section: label + time + title
                        Column(
                          children: [
                            _buildAlarmLabel(screenWidth),
                            SizedBox(height: screenHeight * 0.03),
                            _buildTimeDisplay(),
                            SizedBox(height: screenHeight * 0.01),
                            _buildTaskTitle(),
                          ],
                        ),

                        SizedBox(height: screenHeight * 0.03),

                        // Center section: pulsing icon
                        _buildAlarmIcon(screenWidth),

                        SizedBox(height: screenHeight * 0.03),

                        // Bottom section: motivational + buttons
                        Column(
                          children: [
                            _buildMotivationalText(),
                            SizedBox(height: screenHeight * 0.04),
                            _buildActionButtons(),
                            SizedBox(height: screenHeight * 0.02),
                            _buildSlideHint(),
                            SizedBox(height: screenHeight * 0.03),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 1.5,
              colors: [
                _primaryAmber.withOpacity(_glowController.value * 0.15),
                _darkBg.withOpacity(0.95),
                _darkBg,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAlarmLabel(double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: _primaryAmber.withOpacity(0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: _primaryAmber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.alarm,
            color: _warmGold,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'WAKE UP ALARM',
            style: TextStyle(
              color: _warmGold,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeDisplay() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        final now = DateTime.now();
        final hour =
            now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
        final minute = now.minute.toString().padLeft(2, '0');
        final period = now.hour >= 12 ? 'PM' : 'AM';

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$hour:$minute',
                style: TextStyle(
                  color: _softWhite,
                  fontSize: 80,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 2,
                  height: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                period,
                style: TextStyle(
                  color: _warmGold.withOpacity(0.8),
                  fontSize: 28,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTaskTitle() {
    return Text(
      widget.taskTitle,
      style: TextStyle(
        color: _softWhite.withOpacity(0.7),
        fontSize: 20,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildAlarmIcon(double screenWidth) {
    final iconSize = screenWidth * 0.28;
    final midRing = screenWidth * 0.38;
    final outerRing = screenWidth * 0.48;

    return AnimatedBuilder(
      animation: Listenable.merge([_pulseController, _glowController]),
      builder: (context, child) {
        final pulseValue = Tween<double>(begin: 0.9, end: 1.1)
            .animate(
              CurvedAnimation(
                  parent: _pulseController, curve: Curves.easeInOut),
            )
            .value;
        final glowValue = Tween<double>(begin: 0.3, end: 0.8)
            .animate(
              CurvedAnimation(
                  parent: _glowController, curve: Curves.easeInOut),
            )
            .value;

        return SizedBox(
          width: outerRing,
          height: outerRing,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer glow ring
              Container(
                width: outerRing,
                height: outerRing,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _primaryAmber.withOpacity(glowValue * 0.3),
                    width: 1.5,
                  ),
                ),
              ),
              // Middle ring
              Container(
                width: midRing,
                height: midRing,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _warmGold.withOpacity(glowValue * 0.4),
                    width: 1.5,
                  ),
                ),
              ),
              // Inner circle with icon
              Transform.scale(
                scale: pulseValue,
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _deepOrange.withOpacity(0.9),
                        _primaryAmber.withOpacity(0.7),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryAmber.withOpacity(glowValue * 0.5),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.wb_sunny_rounded,
                    color: _softWhite,
                    size: iconSize * 0.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMotivationalText() {
    const quotes = [
      'Rise and shine! ✨',
      'A new day awaits you 🌅',
      'Your routine begins now 🧘',
      'Good morning, champion! 💪',
      'Time to conquer the day! 🌞',
    ];

    final quote = quotes[DateTime.now().minute % quotes.length];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        quote,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _warmGold.withOpacity(0.7),
          fontSize: 18,
          fontWeight: FontWeight.w400,
          fontStyle: FontStyle.italic,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Snooze button
        Expanded(
          child: GestureDetector(
            onTap: _snoozeAlarm,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.snooze_rounded,
                    color: _softWhite.withOpacity(0.8),
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Snooze',
                    style: TextStyle(
                      color: _softWhite.withOpacity(0.9),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '5 min',
                    style: TextStyle(
                      color: _softWhite.withOpacity(0.5),
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Dismiss button
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _dismissAlarm,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _primaryAmber,
                    _deepOrange,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primaryAmber.withOpacity(0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.alarm_off_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Dismiss',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'I\'m awake!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlideHint() {
    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dismissDragOffset += details.delta.dx;
          if (_dismissDragOffset.abs() >
              MediaQuery.of(context).size.width * 0.5) {
            _dismissAlarm();
          }
        });
      },
      onHorizontalDragEnd: (details) {
        setState(() {
          _dismissDragOffset = 0;
        });
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chevron_left_rounded,
            color: _softWhite.withOpacity(0.25),
            size: 18,
          ),
          const SizedBox(width: 4),
          Text(
            'Swipe to dismiss',
            style: TextStyle(
              color: _softWhite.withOpacity(0.3),
              fontSize: 13,
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.chevron_right_rounded,
            color: _softWhite.withOpacity(0.25),
            size: 18,
          ),
        ],
      ),
    );
  }
}

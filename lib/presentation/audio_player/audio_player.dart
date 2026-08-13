import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import './widgets/breathing_animation_widget.dart';
import './widgets/playback_controls_widget.dart';
import './widgets/session_header_widget.dart';
import './widgets/sleep_timer_widget.dart';
import './widgets/timer_display_widget.dart';
import './widgets/volume_control_widget.dart';

class AudioPlayer extends StatefulWidget {
  const AudioPlayer({super.key});

  @override
  State<AudioPlayer> createState() => _AudioPlayerState();
}

class _AudioPlayerState extends State<AudioPlayer>
    with TickerProviderStateMixin {
  // Mock session data
  final Map<String, dynamic> currentSession = {
    "id": 1,
    "title": "Morning Meditation",
    "instructor": "Guru Ananda",
    "type": "meditation",
    "duration": 1200,
    "description": "Start your day with peaceful mindfulness and inner calm",
    "audioUrl": "https://example.com/morning-meditation.mp3",
    "imageUrl":
        "https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=400&h=400&fit=crop",
  };

  // Audio player state
  bool _isPlaying = false;
  bool _isLoading = false;
  double _currentPosition = 0.0;
  double _totalDuration = 1200.0;
  double _playbackSpeed = 1.0;
  double _volume = 0.7;
  bool _showSleepTimer = false;
  int? _sleepTimerMinutes;

  // Animation controllers
  late AnimationController _breathingController;
  late AnimationController _progressController;
  late Animation<double> _breathingAnimation;
  late Animation<double> _progressAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadSession();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
  }

  void _initializeAnimations() {
    _breathingController = AnimationController(
      duration:
          Duration(seconds: currentSession["type"] == "meditation" ? 4 : 6),
      vsync: this,
    );

    _progressController = AnimationController(
      duration: Duration(seconds: _totalDuration.toInt()),
      vsync: this,
    );

    _breathingAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _breathingController,
      curve: Curves.easeInOut,
    ));

    _progressAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(_progressController);

    if (currentSession["type"] == "meditation") {
      _breathingController.repeat(reverse: true);
    } else {
      _startPranayamaBreathing();
    }
  }

  void _startPranayamaBreathing() {
    _breathingController.repeat(reverse: true);
  }

  void _loadSession() {
    setState(() {
      _isLoading = true;
    });

    Future.delayed(Duration(seconds: 2), () {
      setState(() {
        _isLoading = false;
        _totalDuration = currentSession["duration"].toDouble();
      });
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });

    if (_isPlaying) {
      _progressController.forward();
      _startPositionTimer();
    } else {
      _progressController.stop();
    }

    HapticFeedback.lightImpact();
  }

  void _startPositionTimer() {
    if (_isPlaying) {
      Future.delayed(Duration(seconds: 1), () {
        if (_isPlaying && _currentPosition < _totalDuration) {
          setState(() {
            _currentPosition += _playbackSpeed;
          });
          _startPositionTimer();
        }
      });
    }
  }

  void _skipForward() {
    setState(() {
      _currentPosition = (_currentPosition + 30).clamp(0.0, _totalDuration);
    });
    HapticFeedback.selectionClick();
  }

  void _skipBackward() {
    setState(() {
      _currentPosition = (_currentPosition - 30).clamp(0.0, _totalDuration);
    });
    HapticFeedback.selectionClick();
  }

  void _changeSpeed(double speed) {
    setState(() {
      _playbackSpeed = speed;
    });
  }

  void _changeVolume(double volume) {
    setState(() {
      _volume = volume;
    });
    HapticFeedback.selectionClick();
  }

  void _setSleepTimer(int minutes) {
    setState(() {
      _sleepTimerMinutes = minutes;
      _showSleepTimer = false;
    });

    Future.delayed(Duration(minutes: minutes), () {
      if (mounted && _isPlaying) {
        _togglePlayPause();
      }
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _progressController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      'Loading session...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  // Session Header
                  SessionHeaderWidget(
                    title: currentSession["title"],
                    instructor: currentSession["instructor"],
                    onClose: () => Navigator.of(context).pop(),
                  ),

                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          SizedBox(height: 4.h),

                          // Breathing Animation with Timer
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Progress Ring
                              AnimatedBuilder(
                                animation: _progressAnimation,
                                builder: (context, child) {
                                  return SizedBox(
                                    width: 60.w,
                                    height: 60.w,
                                    child: CircularProgressIndicator(
                                      value: _currentPosition / _totalDuration,
                                      strokeWidth: 4.0,
                                      backgroundColor: Theme.of(context).colorScheme.surface,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF8B4513),
                                      ),
                                    ),
                                  );
                                },
                              ),

                              // Breathing Animation
                              BreathingAnimationWidget(
                                animation: _breathingAnimation,
                                sessionType: currentSession["type"],
                                isPlaying: _isPlaying,
                              ),

                              // Timer Display
                              TimerDisplayWidget(
                                currentTime: _currentPosition,
                                totalTime: _totalDuration,
                              ),
                            ],
                          ),

                          SizedBox(height: 6.h),

                          // Session Info
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6.w),
                            child: Column(
                              children: [
                                Text(
                                  currentSession["title"],
                                  style: Theme.of(context).textTheme.headlineSmall
                                      ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 1.h),
                                Text(
                                  'with ${currentSession["instructor"]}',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 4.h),

                          // Volume Control
                          VolumeControlWidget(
                            volume: _volume,
                            onVolumeChanged: _changeVolume,
                          ),

                          SizedBox(height: 4.h),
                        ],
                      ),
                    ),
                  ),

                  // Playback Controls
                  PlaybackControlsWidget(
                    isPlaying: _isPlaying,
                    playbackSpeed: _playbackSpeed,
                    onPlayPause: _togglePlayPause,
                    onSkipForward: _skipForward,
                    onSkipBackward: _skipBackward,
                    onSpeedChanged: _changeSpeed,
                    onSleepTimer: () {
                      setState(() {
                        _showSleepTimer = true;
                      });
                    },
                    sleepTimerMinutes: _sleepTimerMinutes,
                  ),

                  SizedBox(height: 2.h),
                ],
              ),
      ),

      // Sleep Timer Bottom Sheet
      bottomSheet: _showSleepTimer
          ? SleepTimerWidget(
              onTimerSet: _setSleepTimer,
              onClose: () {
                setState(() {
                  _showSleepTimer = false;
                });
              },
            )
          : null,
    );
  }
}

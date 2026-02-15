import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:audioplayers/audioplayers.dart';

/// Individual sound channel definition
class SoundChannel {
  final String id;
  final String name;
  final String emoji;
  final String audioUrl;
  final Color color;

  const SoundChannel({
    required this.id,
    required this.name,
    required this.emoji,
    required this.audioUrl,
    required this.color,
  });
}

/// Free ambient sounds from public CDN sources
const List<SoundChannel> _channels = [
  SoundChannel(
    id: 'rain',
    name: 'Rain',
    emoji: '🌧️',
    audioUrl: 'https://cdn.pixabay.com/audio/2022/08/31/audio_419263b619.mp3',
    color: Color(0xFF42A5F5),
  ),
  SoundChannel(
    id: 'ocean',
    name: 'Ocean Waves',
    emoji: '🌊',
    audioUrl: 'https://cdn.pixabay.com/audio/2022/06/07/audio_b9bd4170e4.mp3',
    color: Color(0xFF26C6DA),
  ),
  SoundChannel(
    id: 'forest',
    name: 'Forest',
    emoji: '🌿',
    audioUrl: 'https://cdn.pixabay.com/audio/2022/08/02/audio_884fe92c21.mp3',
    color: Color(0xFF66BB6A),
  ),
  SoundChannel(
    id: 'fire',
    name: 'Fireplace',
    emoji: '🔥',
    audioUrl: 'https://cdn.pixabay.com/audio/2021/08/09/audio_c4e9dd291d.mp3',
    color: Color(0xFFFF7043),
  ),
  SoundChannel(
    id: 'bells',
    name: 'Temple Bells',
    emoji: '🕉️',
    audioUrl: 'https://cdn.pixabay.com/audio/2022/10/09/audio_c7e5e7e305.mp3',
    color: Color(0xFFFFCA28),
  ),
  SoundChannel(
    id: 'bowl',
    name: 'Singing Bowl',
    emoji: '🎵',
    audioUrl: 'https://cdn.pixabay.com/audio/2022/03/10/audio_fc55928dfc.mp3',
    color: Color(0xFFAB47BC),
  ),
  SoundChannel(
    id: 'crickets',
    name: 'Night Crickets',
    emoji: '🦗',
    audioUrl: 'https://cdn.pixabay.com/audio/2022/09/07/audio_dd3b130a05.mp3',
    color: Color(0xFF78909C),
  ),
  SoundChannel(
    id: 'wind',
    name: 'Wind',
    emoji: '💨',
    audioUrl: 'https://cdn.pixabay.com/audio/2021/09/06/audio_0e8eaec8f8.mp3',
    color: Color(0xFF90A4AE),
  ),
];

class SoundscapeScreen extends StatefulWidget {
  const SoundscapeScreen({super.key});

  @override
  State<SoundscapeScreen> createState() => _SoundscapeScreenState();
}

class _SoundscapeScreenState extends State<SoundscapeScreen>
    with TickerProviderStateMixin {
  // AudioPlayer pool — one per channel
  final Map<String, AudioPlayer> _players = {};
  final Map<String, bool> _activeChannels = {};
  final Map<String, double> _volumes = {};
  final Map<String, bool> _loading = {};

  // Sleep timer
  int _sleepTimerMinutes = 0; // 0 = off
  Timer? _sleepTimer;
  int _sleepSecondsRemaining = 0;

  // Animation
  late AnimationController _bgController;
  late Animation<double> _bgAnimation;

  final List<int> _sleepOptions = [0, 5, 10, 15, 30, 60];

  int get _activeCount => _activeChannels.values.where((v) => v).length;

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat(reverse: true);

    _bgAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _bgController, curve: Curves.easeInOut),
    );

    // Initialize channel states
    for (final ch in _channels) {
      _activeChannels[ch.id] = false;
      _volumes[ch.id] = 0.6;
      _loading[ch.id] = false;
    }
  }

  @override
  void dispose() {
    _sleepTimer?.cancel();
    _bgController.dispose();
    for (final p in _players.values) {
      p.stop();
      p.dispose();
    }
    super.dispose();
  }

  Future<void> _toggleChannel(SoundChannel channel) async {
    final isActive = _activeChannels[channel.id] ?? false;

    if (isActive) {
      // Stop
      await _players[channel.id]?.stop();
      setState(() => _activeChannels[channel.id] = false);
    } else {
      // Limit to 3 simultaneous
      if (_activeCount >= 3) {
        HapticFeedback.heavyImpact();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Maximum 3 sounds at once'),
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      HapticFeedback.mediumImpact();
      setState(() => _loading[channel.id] = true);

      try {
        // Create player if needed
        if (!_players.containsKey(channel.id)) {
          _players[channel.id] = AudioPlayer();
          _players[channel.id]!.setReleaseMode(ReleaseMode.loop);
        }

        final player = _players[channel.id]!;
        await player.play(UrlSource(channel.audioUrl));
        await player.setVolume(_volumes[channel.id] ?? 0.6);

        if (mounted) {
          setState(() {
            _activeChannels[channel.id] = true;
            _loading[channel.id] = false;
          });
        }
      } catch (e) {
        debugPrint('❌ Error playing ${channel.name}: $e');
        if (mounted) {
          setState(() => _loading[channel.id] = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not load ${channel.name}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  void _setVolume(String channelId, double volume) {
    _volumes[channelId] = volume;
    _players[channelId]?.setVolume(volume);
  }

  void _setSleepTimer(int minutes) {
    HapticFeedback.selectionClick();
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerMinutes = minutes;
      _sleepSecondsRemaining = minutes * 60;
    });

    if (minutes == 0) return;

    _sleepTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _sleepSecondsRemaining--);
      if (_sleepSecondsRemaining <= 0) {
        _stopAll();
        _sleepTimer?.cancel();
      }
    });
  }

  void _stopAll() {
    for (final ch in _channels) {
      _players[ch.id]?.stop();
      _activeChannels[ch.id] = false;
    }
    _sleepTimer?.cancel();
    setState(() {
      _sleepTimerMinutes = 0;
      _sleepSecondsRemaining = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08081A),
      body: AnimatedBuilder(
        animation: _bgAnimation,
        builder: (context, _) {
          // Subtle animated gradient based on active sounds
          final activeColors = _channels
              .where((c) => _activeChannels[c.id] == true)
              .map((c) => c.color)
              .toList();

          return Container(
            decoration: BoxDecoration(
              gradient: activeColors.isEmpty
                  ? null
                  : LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF08081A),
                        (activeColors.first).withOpacity(0.08 * _bgAnimation.value),
                        const Color(0xFF08081A),
                      ],
                    ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  // Top bar
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            _stopAll();
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70),
                        ),
                        const Spacer(),
                        const Text(
                          'Soundscapes',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        if (_activeCount > 0)
                          IconButton(
                            onPressed: _stopAll,
                            icon: const Icon(Icons.stop_rounded, color: Colors.white38),
                          )
                        else
                          const SizedBox(width: 48),
                      ],
                    ),
                  ),

                  SizedBox(height: 1.h),

                  // Sound grid
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.symmetric(horizontal: 4.w),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: _channels.length,
                      itemBuilder: (context, i) {
                        final ch = _channels[i];
                        final active = _activeChannels[ch.id] == true;
                        final isLoading = _loading[ch.id] == true;

                        return GestureDetector(
                          onTap: () => _toggleChannel(ch),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            decoration: BoxDecoration(
                              color: active
                                  ? ch.color.withOpacity(0.12)
                                  : Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: active ? ch.color.withOpacity(0.5) : Colors.white10,
                                width: active ? 2 : 1,
                              ),
                              boxShadow: active
                                  ? [
                                      BoxShadow(
                                        color: ch.color.withOpacity(0.15),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Emoji + loading indicator
                                  Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Text(ch.emoji, style: TextStyle(fontSize: active ? 36 : 30)),
                                      if (isLoading)
                                        SizedBox(
                                          width: 36,
                                          height: 36,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: ch.color,
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 1.h),
                                  Text(
                                    ch.name,
                                    style: TextStyle(
                                      color: active ? ch.color : Colors.white54,
                                      fontSize: 13,
                                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                                    ),
                                  ),
                                  if (active) ...[
                                    SizedBox(height: 1.h),
                                    // Volume slider
                                    SliderTheme(
                                      data: SliderThemeData(
                                        activeTrackColor: ch.color,
                                        inactiveTrackColor: ch.color.withOpacity(0.2),
                                        thumbColor: ch.color,
                                        trackHeight: 3,
                                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                      ),
                                      child: Slider(
                                        value: _volumes[ch.id] ?? 0.6,
                                        onChanged: (v) {
                                          setState(() => _setVolume(ch.id, v));
                                        },
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Sleep Timer section
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.bedtime_rounded, color: Colors.white38, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              'Sleep Timer',
                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            if (_sleepSecondsRemaining > 0)
                              Text(
                                '${_sleepSecondsRemaining ~/ 60}:${(_sleepSecondsRemaining % 60).toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: Color(0xFFCD853F),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: _sleepOptions.map((min) {
                            final selected = min == _sleepTimerMinutes;
                            return Expanded(
                              child: GestureDetector(
                                onTap: () => _setSleepTimer(min),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(horizontal: 3),
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? const Color(0xFFCD853F).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.06),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: selected ? const Color(0xFFCD853F).withOpacity(0.5) : Colors.transparent,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      min == 0 ? 'Off' : '${min}m',
                                      style: TextStyle(
                                        color: selected ? const Color(0xFFCD853F) : Colors.white38,
                                        fontSize: 11,
                                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 2.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

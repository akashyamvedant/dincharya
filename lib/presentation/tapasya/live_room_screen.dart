import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:camera/camera.dart';

import '../../services/tapasya_service.dart';

class LiveRoomScreen extends StatefulWidget {
  const LiveRoomScreen({super.key});

  @override
  State<LiveRoomScreen> createState() => _LiveRoomScreenState();
}

class _LiveRoomScreenState extends State<LiveRoomScreen> with TickerProviderStateMixin {
  final TapasyaService _tapasyaService = TapasyaService();
  final SupabaseClient _supabase = Supabase.instance.client;

  Map<String, dynamic>? _room;
  Map<String, dynamic>? _circle;
  List<Map<String, dynamic>> _participants = [];
  List<Map<String, dynamic>> _messages = [];

  bool _isHost = false;
  int _remainingSeconds = 600;
  int _totalDurationSeconds = 600;
  Timer? _countdownTimer;
  Timer? _pingTimer;
  Timer? _messagesTimer;
  bool _isLoading = true;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Camera self-view
  CameraController? _cameraController;
  bool _isCameraOn = false;
  bool _isCameraInitializing = false;

  static const _primaryColor = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // 4 second breathing cycle
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.96, end: 1.04).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _room == null) {
      _room = args['room'] as Map<String, dynamic>;
      _circle = args['circle'] as Map<String, dynamic>;
      _initRoom();
    }
  }

  void _initRoom() {
    final userId = _supabase.auth.currentUser?.id;
    _isHost = _room!['host_id'] == userId;
    _totalDurationSeconds = _room!['duration_seconds'] ?? 600;

    // Keep screen awake during practice
    WakelockPlus.enable();

    _updateTimerValue();
    _startTimers();
    _loadParticipantsAndMessages();
    setState(() => _isLoading = false);
  }

  void _updateTimerValue() {
    final startedAtStr = _room!['started_at'] as String?;
    if (startedAtStr != null) {
      final startedAt = DateTime.tryParse(startedAtStr)?.toUtc();
      if (startedAt != null) {
        final elapsed = DateTime.now().toUtc().difference(startedAt).inSeconds;
        final remaining = _totalDurationSeconds - elapsed;
        if (remaining <= 0) {
          _remainingSeconds = 0;
          _onTimerFinished();
        } else {
          _remainingSeconds = remaining;
        }
      }
    }
  }

  void _startTimers() {
    // 1. Local Countdown timer ticking every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _countdownTimer?.cancel();
            _onTimerFinished();
          }
        });
      }
    });

    // 2. Presence & active users ping every 6 seconds
    _pingTimer = Timer.periodic(const Duration(seconds: 6), (timer) async {
      if (mounted && _room != null) {
        // Send ping
        await _tapasyaService.updatePing(_room!['id']);
        // Fetch active members
        final parts = await _tapasyaService.getActiveParticipants(_room!['id']);
        // Verify room status (if room got completed by host, redirect users)
        final activeRooms = await _tapasyaService.getActiveLiveRooms(_circle!['id']);
        final stillActive = activeRooms.any((r) => r['id'] == _room!['id']);

        if (!stillActive && !_isHost && mounted) {
          _exitRoomAndGoToSummary();
          return;
        }

        if (mounted) {
          setState(() {
            _participants = parts;
          });
        }
      }
    });

    // 3. Message feed fetcher every 3 seconds
    _messagesTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (mounted && _room != null) {
        final msgs = await _tapasyaService.getLiveRoomMessages(_room!['id'], _circle!['id']);
        if (mounted) {
          setState(() {
            _messages = msgs;
          });
        }
      }
    });
  }

  Future<void> _loadParticipantsAndMessages() async {
    if (_room == null) return;
    final parts = await _tapasyaService.getActiveParticipants(_room!['id']);
    final msgs = await _tapasyaService.getLiveRoomMessages(_room!['id'], _circle!['id']);
    if (mounted) {
      setState(() {
        _participants = parts;
        _messages = msgs;
      });
    }
  }

  void _onTimerFinished() {
    _countdownTimer?.cancel();
    if (_isHost) {
      _endRoom();
    } else {
      _exitRoomAndGoToSummary();
    }
  }

  Future<void> _endRoom() async {
    if (_room == null) return;
    await _tapasyaService.endLiveRoom(_room!['id']);
    _exitRoomAndGoToSummary();
  }

  void _exitRoomAndGoToSummary() {
    _cancelTimers();
    if (mounted) {
      Navigator.pushReplacementNamed(
        context,
        '/tapasya/live-summary',
        arguments: {
          'room': _room,
          'circle': _circle,
          'duration_seconds': _totalDurationSeconds - _remainingSeconds,
        },
      );
    }
  }

  void _cancelTimers() {
    _countdownTimer?.cancel();
    _pingTimer?.cancel();
    _messagesTimer?.cancel();
  }

  Future<void> _leaveRoomOnly() async {
    if (_room != null) {
      await _tapasyaService.leaveLiveRoom(_room!['id']);
    }
    _cancelTimers();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _sendReaction(String emoji) async {
    if (_room == null) return;
    await _tapasyaService.sendLiveRoomMessage(_room!['id'], emoji, _circle!['id']);
    // Instantly refresh local messages
    final msgs = await _tapasyaService.getLiveRoomMessages(_room!['id'], _circle!['id']);
    if (mounted) {
      setState(() {
        _messages = msgs;
      });
    }
  }

  Future<void> _toggleCamera() async {
    if (_isCameraOn) {
      // Turn off camera
      await _cameraController?.dispose();
      _cameraController = null;
      if (mounted) setState(() => _isCameraOn = false);
    } else {
      // Turn on camera
      if (_isCameraInitializing) return;
      setState(() => _isCameraInitializing = true);
      try {
        final cameras = await availableCameras();
        final frontCamera = cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );
        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.low,
          enableAudio: false,
        );
        await _cameraController!.initialize();
        if (mounted) {
          setState(() {
            _isCameraOn = true;
            _isCameraInitializing = false;
          });
        }
      } catch (e) {
        debugPrint('📸 Camera error: $e');
        if (mounted) setState(() => _isCameraInitializing = false);
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cancelTimers();
    _cameraController?.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatTime(int totalSecs) {
    final mins = totalSecs ~/ 60;
    final secs = totalSecs % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: _primaryColor)),
      );
    }

    final categoryEmoji = _room!['category'] == 'yoga'
        ? '🧘'
        : _room!['category'] == 'pranayama'
            ? '🌬️'
            : _room!['category'] == 'meditation'
                ? '🕉️'
                : '🔥';

    final double progress = _totalDurationSeconds > 0
        ? _remainingSeconds / _totalDurationSeconds
        : 0.0;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F0B07), Color(0xFF1E1004)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Row: Exit & Title
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70, size: 28),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Leave Practice Room?'),
                            content: const Text(
                              'Are you sure you want to exit the live room? Your practice time so far will be saved.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Stay'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(ctx);
                                  _leaveRoomOnly();
                                },
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Exit'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    Expanded(
                      child: Text(
                        _room!['title'] ?? 'Sangha Practice',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(2.w),
                      decoration: const BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: Text(categoryEmoji, style: const TextStyle(fontSize: 20)),
                    ),
                    SizedBox(width: 1.w),
                    GestureDetector(
                      onTap: _toggleCamera,
                      child: Container(
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: _isCameraOn ? _primaryColor.withOpacity(0.3) : Colors.white10,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _isCameraOn ? Icons.videocam : Icons.videocam_off,
                          color: _isCameraOn ? _primaryColor : Colors.white70,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4.h),

                Expanded(
                  flex: 5,
                  child: Center(
                    child: ScaleTransition(
                      scale: _pulseAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 65.w,
                            height: 65.w,
                            child: CircularProgressIndicator(
                              value: progress,
                              strokeWidth: 10,
                              color: _primaryColor,
                              backgroundColor: Colors.white12,
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _formatTime(_remainingSeconds),
                                style: TextStyle(
                                  fontSize: 36.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 2,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'REMAINING',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white60,
                                  letterSpacing: 4,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Live Members avatars strip
                Text(
                  '👥 Practice Members (${_participants.isEmpty ? 1 : _participants.length} Active)',
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
                SizedBox(height: 1.h),
                SizedBox(
                  height: 6.h,
                  child: _participants.isEmpty
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: CircleAvatar(
                            radius: 18,
                            backgroundColor: _primaryColor,
                            child: const Text('Me', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        )
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _participants.length,
                          separatorBuilder: (_, __) => SizedBox(width: 2.w),
                          itemBuilder: (context, index) {
                            final p = _participants[index];
                            final name = p['display_name'] as String? ?? 'U';
                            final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                            return CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.deepOrange.shade900,
                              backgroundImage: p['avatar_url'] != null ? NetworkImage(p['avatar_url']) : null,
                              child: p['avatar_url'] == null
                                  ? Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12))
                                  : null,
                            );
                          },
                        ),
                ),
                SizedBox(height: 3.h),

                // Rolling messages/reactions overlay
                Expanded(
                  flex: 3,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 2.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            'Send a reaction to encourage the Sangha! 🙏',
                            style: TextStyle(color: Colors.white30, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          reverse: true,
                          padding: EdgeInsets.all(2.w),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final msg = _messages[index];
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 0.5.h),
                              child: Row(
                                children: [
                                  Text(
                                    '${msg['display_name']}: ',
                                    style: const TextStyle(color: _primaryColor, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    msg['message'] ?? '',
                                    style: const TextStyle(color: Colors.white, fontSize: 14),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ),
                SizedBox(height: 2.h),

                // Predefined Emojis Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildReactionBtn('🙏'),
                    _buildReactionBtn('🔥'),
                    _buildReactionBtn('💪'),
                    _buildReactionBtn('👏'),
                    _buildReactionBtn('🕉️'),
                  ],
                ),
                SizedBox(height: 3.h),

                // Host Action / Leave Action
                if (_isHost)
                  ElevatedButton(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Complete Practice Room?'),
                          content: const Text(
                            'This will end the live room for all circle members. Your group session stats will be calculated.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _endRoom();
                              },
                              style: TextButton.styleFrom(foregroundColor: Colors.green),
                              child: const Text('Complete'),
                            ),
                          ],
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade900,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 1.8.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Complete Sadhana',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                    ),
                  )
                else
                  ElevatedButton(
                    onPressed: _leaveRoomOnly,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white10,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 1.8.h),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      'Leave Room',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),

          // Camera PiP overlay
          if (_isCameraOn && _cameraController != null && _cameraController!.value.isInitialized)
            Positioned(
              bottom: 14.h,
              right: 4.w,
              child: GestureDetector(
                onTap: _toggleCamera,
                child: Container(
                  width: 28.w,
                  height: 18.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _primaryColor.withOpacity(0.6), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: CameraPreview(_cameraController!),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReactionBtn(String emoji) {
    return GestureDetector(
      onTap: () => _sendReaction(emoji),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 22),
        ),
      ),
    );
  }
}

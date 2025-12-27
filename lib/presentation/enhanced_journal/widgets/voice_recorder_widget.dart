import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

// lib/presentation/enhanced_journal/widgets/voice_recorder_widget.dart

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String) onRecordingComplete;
  final VoidCallback? onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with TickerProviderStateMixin {
  bool _isRecording = false;
  bool _isPaused = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _timer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.3,
    ).animate(CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _isRecording ? 'Recording...' : 'Voice Recorder',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 24.h),
          _buildRecordingVisualizer(),
          SizedBox(height: 24.h),
          Text(
            _formatDuration(_recordingDuration),
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.w600,
              color: _isRecording ? Colors.red : Colors.grey[600],
            ),
          ),
          SizedBox(height: 32.h),
          _buildControlButtons(),
        ],
      ),
    );
  }

  Widget _buildRecordingVisualizer() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isRecording ? _pulseAnimation.value : 1.0,
          child: Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isRecording
                  ? Colors.red.withAlpha(26)
                  : Colors.grey.withAlpha(26),
              border: Border.all(
                color: _isRecording ? Colors.red : Colors.grey,
                width: 2,
              ),
            ),
            child: Icon(
              Icons.mic,
              size: 48,
              color: _isRecording ? Colors.red : Colors.grey[600],
            ),
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    if (!_isRecording && _recordingDuration == Duration.zero) {
      // Initial state - show record button
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.close,
            color: Colors.grey,
            onPressed: widget.onCancel,
          ),
          _buildRecordButton(),
        ],
      );
    } else if (_isRecording) {
      // Recording state - show pause and stop buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: _isPaused ? Icons.play_arrow : Icons.pause,
            color: Colors.orange,
            onPressed: _togglePauseResume,
          ),
          _buildControlButton(
            icon: Icons.stop,
            color: Colors.red,
            onPressed: _stopRecording,
          ),
        ],
      );
    } else {
      // Recorded state - show play, delete, and save buttons
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlButton(
            icon: Icons.delete,
            color: Colors.red,
            onPressed: _deleteRecording,
          ),
          _buildControlButton(
            icon: Icons.play_arrow,
            color: Colors.blue,
            onPressed: _playRecording,
          ),
          _buildControlButton(
            icon: Icons.check,
            color: Colors.green,
            onPressed: _saveRecording,
          ),
        ],
      );
    }
  }

  Widget _buildRecordButton() {
    return GestureDetector(
      onTap: _startRecording,
      child: Container(
        width: 80.w,
        height: 80.w,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
        ),
        child: const Icon(
          Icons.mic,
          color: Colors.white,
          size: 32,
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 56.w,
        height: 56.w,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(26),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }

  void _startRecording() {
    setState(() {
      _isRecording = true;
      _recordingDuration = Duration.zero;
    });

    _pulseController.repeat(reverse: true);

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isPaused) {
        setState(() {
          _recordingDuration =
              Duration(seconds: _recordingDuration.inSeconds + 1);
        });
      }
    });
  }

  void _togglePauseResume() {
    setState(() {
      _isPaused = !_isPaused;
    });

    if (_isPaused) {
      _pulseController.stop();
    } else {
      _pulseController.repeat(reverse: true);
    }
  }

  void _stopRecording() {
    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    _timer?.cancel();
    _pulseController.stop();
    _pulseController.reset();
  }

  void _deleteRecording() {
    setState(() {
      _recordingDuration = Duration.zero;
    });
  }

  void _playRecording() {
    // In a real app, this would play the recorded audio
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playing recording...')),
    );
  }

  void _saveRecording() {
    // In a real app, this would save the audio file and return the path
    final mockAudioPath =
        'recordings/voice_${DateTime.now().millisecondsSinceEpoch}.wav';
    widget.onRecordingComplete(mockAudioPath);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

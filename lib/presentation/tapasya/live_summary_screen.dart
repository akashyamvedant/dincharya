import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/guided_session_service.dart';
import '../../services/tapasya_service.dart';

class LiveSummaryScreen extends StatefulWidget {
  const LiveSummaryScreen({super.key});

  @override
  State<LiveSummaryScreen> createState() => _LiveSummaryScreenState();
}

class _LiveSummaryScreenState extends State<LiveSummaryScreen> {
  final GuidedSessionService _guidedSessionService = GuidedSessionService();
  final TapasyaService _tapasyaService = TapasyaService();

  Map<String, dynamic>? _room;
  Map<String, dynamic>? _circle;
  int _durationSeconds = 0;

  String? _selectedMood = '🙂';
  int _selectedEnergy = 3;
  final TextEditingController _notesController = TextEditingController();
  bool _isSaving = false;

  final List<String> _moods = ['😢', '😐', '🙂', '😃', '🧘'];
  static const _primaryColor = Color(0xFFE65100);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map<String, dynamic> && _room == null) {
      _room = args['room'] as Map<String, dynamic>;
      _circle = args['circle'] as Map<String, dynamic>;
      _durationSeconds = args['duration_seconds'] as int? ?? 0;
    }
  }

  Future<void> _saveSession() async {
    if (_room == null || _isSaving) return;
    setState(() => _isSaving = true);

    try {
      // 1. Map emojis to text for mood description
      final moodText = _selectedMood == '😢'
          ? 'Sad'
          : _selectedMood == '😐'
              ? 'Neutral'
              : _selectedMood == '🙂'
                  ? 'Good'
                  : _selectedMood == '😃'
                      ? 'Excellent'
                      : 'Peaceful';

      // 2. Record practice session
      await _guidedSessionService.recordSession(
        practiceType: _room!['category'] ?? 'any',
        technique: '${_room!['title']} (Live Group)',
        durationSeconds: _durationSeconds,
        moodAfter: moodText,
        energyAfter: _selectedEnergy,
        notes: _notesController.text.trim().isEmpty ? 'Group live practice session' : _notesController.text.trim(),
      );

      // 3. Sync challenge progress for any active challenges
      final durationMin = _durationSeconds ~/ 60;
      if (durationMin > 0) {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId != null) {
          await _tapasyaService.syncChallengeProgress(
            userId: userId,
            category: _room!['category'] ?? 'any',
            sessionId: _room!['session_id'],
            durationSeconds: _durationSeconds,
          );
        }
      }

      if (mounted) {
        // Go back to the circle details screen
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('❌ Error saving live session stats: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final durationMin = _durationSeconds ~/ 60;
    final durationSecsRemaining = _durationSeconds % 60;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Practice Summary 🧘'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Banner/Illustration
            Center(
              child: Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Text('🎉', style: TextStyle(fontSize: 48)),
              ),
            ),
            SizedBox(height: 2.h),
            Center(
              child: Text(
                'Sadhana Completed!',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.green),
              ),
            ),
            Center(
              child: Text(
                'You practiced together with the Sangha.',
                style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            SizedBox(height: 4.h),

            // Room / Session Detail Card
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  children: [
                    Text(
                      _room?['title'] ?? 'Live Practice Room',
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 1.h),
                    Text(
                      'Group: ${_circle?['name'] ?? 'Circle'}',
                      style: TextStyle(fontSize: 11.sp, color: theme.colorScheme.onSurfaceVariant),
                    ),
                    Divider(height: 3.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatItem('Practice Time', '$durationMin Min'),
                        _buildStatItem('Category', _room?['category']?.toString().toUpperCase() ?? 'YOGA'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 3.h),

            // Mood rating
            Text(
              'How do you feel after this session?',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 1.5.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: _moods.map((m) {
                final isSelected = m == _selectedMood;
                return GestureDetector(
                  onTap: () => setState(() => _selectedMood = m),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.all(3.5.w),
                    decoration: BoxDecoration(
                      color: isSelected ? _primaryColor.withOpacity(0.12) : theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? _primaryColor : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Text(m, style: TextStyle(fontSize: 22.sp)),
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 3.h),

            // Energy Rating
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Energy Level',
                  style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
                ),
                Text(
                  '⚡ ' * _selectedEnergy,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _primaryColor),
                ),
              ],
            ),
            Slider(
              value: _selectedEnergy.toDouble(),
              min: 1,
              max: 5,
              divisions: 4,
              activeColor: _primaryColor,
              inactiveColor: _primaryColor.withOpacity(0.2),
              onChanged: (val) {
                setState(() => _selectedEnergy = val.toInt());
              },
            ),
            SizedBox(height: 3.h),

            // Practice Notes
            Text(
              'Practice Notes (optional)',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 1.h),
            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Share your experience (e.g. "Deep focus today", "Felt calm")',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            SizedBox(height: 4.h),

            // Submit Button
            ElevatedButton(
              onPressed: _isSaving ? null : _saveSession,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Save Sadhana & Complete', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: 2.h),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel & Discard',
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: theme.colorScheme.onSurfaceVariant),
        ),
        SizedBox(height: 0.5.h),
        Text(
          value,
          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: _primaryColor),
        ),
      ],
    );
  }
}

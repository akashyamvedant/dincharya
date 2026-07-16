// lib/presentation/tapasya/create_circle_screen.dart
//
// Screen to create a new Tapasya Circle / Group.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/tapasya_service.dart';

class CreateCircleScreen extends StatefulWidget {
  const CreateCircleScreen({super.key});

  @override
  State<CreateCircleScreen> createState() => _CreateCircleScreenState();
}

class _CreateCircleScreenState extends State<CreateCircleScreen> {
  final TapasyaService _tapasyaService = TapasyaService();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isPublic = false;
  int _maxMembers = 50;
  bool _isCreating = false;

    @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createCircle() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a circle name'),
          backgroundColor: Colors.red[700],
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    final circle = await _tapasyaService.createCircle(
      name: name,
      description: _descriptionController.text.trim(),
      isPublic: _isPublic,
      maxMembers: _maxMembers,
    );

    setState(() => _isCreating = false);

    if (circle != null && mounted) {
      _showSuccessDialog(circle);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to create circle. Please try again.'),
          backgroundColor: Colors.red[700],
        ),
      );
    }
  }

  void _showSuccessDialog(Map<String, dynamic> circle) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Text('👥', style: TextStyle(fontSize: 28)),
            SizedBox(width: 8),
            Text('Circle Created!'),
          ],
        ),
        content: Text(
          'Your circle "${circle['name']}" is ready. Share the invite link with friends to practice together!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Later'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              final shareText = TapasyaService.generateCircleShareText(circle);
              Share.share(shareText);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            icon: const Icon(Icons.share, size: 18),
            label: const Text('Share Invite'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('New Circle 👥'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Image/Emoji Placeholder
            Center(
              child: Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3), width: 2),
                ),
                child: const Center(
                  child: Text('👥', style: TextStyle(fontSize: 48)),
                ),
              ),
            ),
            SizedBox(height: 3.h),

            // ── Circle Name ──
            _buildLabel('Circle Name'),
            SizedBox(height: 1.h),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'e.g., Family Yoga, Morning Sadhaks',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              maxLength: 50,
            ),

            SizedBox(height: 2.h),

            // ── Description ──
            _buildLabel('Description (optional)'),
            SizedBox(height: 1.h),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'e.g., Let\'s support each other in maintaining daily yoga & meditation routines.',
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                ),
              ),
              maxLength: 200,
            ),

            SizedBox(height: 2.h),

            // ── Max Members Slider ──
            _buildLabel('Member Limit: $_maxMembers'),
            SizedBox(height: 1.h),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: theme.colorScheme.primary,
                thumbColor: theme.colorScheme.primary,
                overlayColor: theme.colorScheme.primary.withValues(alpha: 0.2),
                inactiveTrackColor: theme.colorScheme.primary.withValues(alpha: 0.15),
              ),
              child: Slider(
                value: _maxMembers.toDouble(),
                min: 5,
                max: 100,
                divisions: 19,
                onChanged: (val) => setState(() => _maxMembers = val.round()),
              ),
            ),

            SizedBox(height: 3.h),

            // ── Public toggle ──
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Text('🌐', style: TextStyle(fontSize: 22)),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Public Circle',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          'Anyone can search and join this circle',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isPublic,
                    onChanged: (val) => setState(() => _isPublic = val),
                    activeColor: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),

            SizedBox(height: 5.h),

            // ── Create Button ──
            SizedBox(
              width: double.infinity,
              height: 7.h,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createCircle,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
                ),
                child: _isCreating
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        '👥 Create Circle',
                        style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: TextStyle(
        fontSize: 16.sp,
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

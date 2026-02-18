import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../models/lifestyle_profile.dart';
import '../../services/supabase_service.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// Profile Selection Screen for choosing lifestyle type
class ProfileSelectionScreen extends StatefulWidget {
  final bool isOnboarding;
  final VoidCallback? onProfileSelected;

  const ProfileSelectionScreen({
    super.key,
    this.isOnboarding = false,
    this.onProfileSelected,
  });

  @override
  State<ProfileSelectionScreen> createState() => _ProfileSelectionScreenState();
}

class _ProfileSelectionScreenState extends State<ProfileSelectionScreen> {
  String? _selectedProfileId;
  bool _isSaving = false;
  final SupabaseService _supabaseService = SupabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.colorScheme.surface,
      appBar: widget.isOnboarding ? null : AppBar(
        title: const Text('Choose Your Path'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                children: [
                  if (widget.isOnboarding) ...[
                    SizedBox(height: 2.h),
                    Text(
                      '🧘 अपना मार्ग चुनें',
                      style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.lightTheme.colorScheme.primary,
                      ),
                    ),
                    SizedBox(height: 1.h),
                  ],
                  Text(
                    'Choose Your Lifestyle',
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Select the lifestyle that best matches your daily routine',
                    style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                      color: Colors.black54,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            // Profile Cards
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                itemCount: LifestyleProfile.presets.length + 1, // +1 for custom
                itemBuilder: (context, index) {
                  if (index < LifestyleProfile.presets.length) {
                    final profile = LifestyleProfile.presets[index];
                    return _buildProfileCard(profile);
                  } else {
                    return _buildCustomProfileCard();
                  }
                },
              ),
            ),

            // Banner Ad at bottom
            const BannerAdWidget(placement: BannerPlacement.changeProfile),

            // Continue Button
            Padding(
              padding: EdgeInsets.all(4.w),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _selectedProfileId == null || _isSaving
                      ? null
                      : _saveAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.lightTheme.colorScheme.onPrimary,
                          ),
                        )
                      : Text(
                          widget.isOnboarding ? 'Continue' : 'Save Changes',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.lightTheme.colorScheme.onPrimary,
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

  Widget _buildProfileCard(LifestyleProfile profile) {
    final isSelected = _selectedProfileId == profile.id;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProfileId = profile.id;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.lightTheme.colorScheme.primary.withOpacity(0.1)
              : AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.primary
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.lightTheme.colorScheme.primary.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.primary
                    : AppTheme.lightTheme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomIconWidget(
                iconName: profile.icon,
                size: 32,
                color: isSelected
                    ? Colors.white
                    : AppTheme.lightTheme.colorScheme.primary,
              ),
            ),
            SizedBox(width: 4.w),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.name,
                          style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? AppTheme.lightTheme.colorScheme.primary
                                : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Flexible(
                        child: Text(
                          profile.nameHindi,
                          style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    profile.description,
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 1.h),
                  // Time info
                  Row(
                    children: [
                      Icon(Icons.wb_sunny, size: 14, color: Colors.orange),
                      SizedBox(width: 1.w),
                      Flexible(
                        child: Text(
                          'Wake: ${_formatTime(profile.wakeTime)}',
                          style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 3.w),
                      Icon(Icons.bedtime, size: 14, color: Colors.indigo),
                      SizedBox(width: 1.w),
                      Flexible(
                        child: Text(
                          'Sleep: ${_formatTime(profile.sleepTime)}',
                          style: AppTheme.lightTheme.textTheme.labelSmall?.copyWith(
                            color: Colors.black54,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Checkmark
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomProfileCard() {
    final isSelected = _selectedProfileId == 'custom';
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedProfileId = 'custom';
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppTheme.lightTheme.colorScheme.tertiary.withOpacity(0.1)
              : AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.lightTheme.colorScheme.tertiary
                : Colors.grey.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(3.w),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.lightTheme.colorScheme.tertiary
                    : AppTheme.lightTheme.colorScheme.tertiary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: CustomIconWidget(
                iconName: 'edit',
                size: 32,
                color: isSelected
                    ? Colors.white
                    : AppTheme.lightTheme.colorScheme.tertiary,
              ),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Routine',
                    style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? AppTheme.lightTheme.colorScheme.tertiary
                          : Colors.black87,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    'Build your own unique routine based on your needs',
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      int hour = int.parse(parts[0]);
      final minute = parts[1];
      final period = hour >= 12 ? 'PM' : 'AM';
      if (hour > 12) hour -= 12;
      if (hour == 0) hour = 12;
      return '$hour:$minute $period';
    } catch (e) {
      return time24;
    }
  }

  Future<void> _saveAndContinue() async {
    if (_selectedProfileId == null) return;

    setState(() => _isSaving = true);

    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not logged in');
      }

      // Get selected profile (no deletion — tasks are preserved)
      LifestyleProfile? selectedProfile;
      if (_selectedProfileId != 'custom') {
        selectedProfile = LifestyleProfile.presets.firstWhere(
          (p) => p.id == _selectedProfileId,
        );
      }

      // Save profile to user_profiles table
      final client = await _supabaseService.client;
      if (client == null) {
        throw Exception('Supabase client not initialized');
      }
      await client
          .from('user_profiles')
          .update({
            'lifestyle_profile': _selectedProfileId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Only create tasks if none exist for this profile yet
      if (selectedProfile != null) {
        final existing = await _supabaseService.getTasksByProfileSource(userId, selectedProfile.id);
        if (existing.isEmpty) {
          await _createTasksFromProfile(userId, selectedProfile);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile "${selectedProfile?.name ?? 'Custom'}" selected!'),
            backgroundColor: AppTheme.getSuccessColor(true),
          ),
        );

        widget.onProfileSelected?.call();
        
        if (widget.isOnboarding) {
          Navigator.pushReplacementNamed(context, '/routine-dashboard');
        } else {
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      debugPrint('Error saving profile: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving profile: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _createTasksFromProfile(String userId, LifestyleProfile profile) async {
    // Get all activities from the default routine
    final allActivities = <Map<String, dynamic>>[];
    
    profile.defaultRoutine.forEach((prahar, activities) {
      if (activities is List) {
        for (final activity in activities) {
          allActivities.add({
            ...activity,
            'prahar': prahar,
          });
        }
      }
    });

    // Create tasks from activities with profile_source tag
    for (final activity in allActivities) {
      try {
        await _supabaseService.createLocalTask({
          'user_id': userId,
          'title': activity['activity'],
          'description': 'Part of ${profile.name} routine',
          'time': _formatTime(activity['time']),
          'duration': '${activity['duration']} min',
          'category': activity['category'],
          'prahar': activity['prahar'],
          'profile_source': profile.id,
          'is_completed': false,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Error creating task: $e');
      }
    }
  }
}

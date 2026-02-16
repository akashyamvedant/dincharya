import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../services/subscription_manager.dart';
import '../../widgets/ads/native_ad_widget.dart';
import '../payment/payment_plans_screen.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  int _currentIndex = 3; // Me tab is active
  // ignore: unused_field - used for loading state
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _notificationsEnabled = true;
  String _appVersion = 'Loading...';
  String _buildNumber = '';
  Map<String, dynamic>? _userData;
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();

  /// Check if current user is admin (from database is_admin field)
  bool get _isAdmin {
    return _userData?['is_admin'] == true;
  }

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppVersion();
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = packageInfo.version;
      _buildNumber = packageInfo.buildNumber;
    });
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isLoggedIn = await _authService.isUserLoggedIn();

      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        final client = await _supabaseService.client;
        final userId = _supabaseService.currentUser?.id;
        
        // Default values
        int currentStreak = 0;
        int bestStreak = 0;
        int completedRoutines = 0;
        int journalEntries = 0;
        int totalTasksCompleted = 0;
        
        // Fetch real data from Supabase
        if (client != null && userId != null) {
          try {
            // Get user profile stats
            final profileData = await client
                .from('user_profiles')
                .select('current_streak, best_streak, total_tasks_completed, total_practice_days')
                .eq('id', userId)
                .maybeSingle();
            
            if (profileData != null) {
              currentStreak = profileData['current_streak'] ?? 0;
              bestStreak = profileData['best_streak'] ?? 0;
              totalTasksCompleted = profileData['total_tasks_completed'] ?? 0;
            }
            
            // Count completed routines (completed tasks today)
            final today = DateTime.now().toIso8601String().split('T')[0];
            final completedToday = await client
                .from('routine_tracking')
                .select('id')
                .eq('user_id', userId)
                .eq('completed', true)
                .gte('tracking_date', today);
            completedRoutines = completedToday.length;
            
            // Count journal entries
            final journals = await client
                .from('journal_entries')
                .select('id')
                .eq('user_id', userId);
            journalEntries = journals.length;
            
            debugPrint('📊 Profile Stats: Streak=$currentStreak, Routines=$completedRoutines, Journals=$journalEntries');
          } catch (e) {
            debugPrint('⚠️ Error fetching stats: $e');
          }
        }
        
        // Get subscription plan from SubscriptionManager (always refresh for accurate status)
        final subManager = SubscriptionManager();
        await subManager.refresh();
        final subPlan = subManager.isPremium
            ? (subManager.isTrial ? 'Trial' : 'Premium')
            : 'Free';

        setState(() {
          _isLoggedIn = true;
          _userData = user ?? {};
          _userData!['currentStreak'] = currentStreak;
          _userData!['bestStreak'] = bestStreak;
          _userData!['completedRoutines'] = completedRoutines;
          _userData!['journalEntries'] = journalEntries;
          _userData!['totalTasksCompleted'] = totalTasksCompleted;
          _userData!['subscriptionPlan'] = subPlan;
          _userData!['preferences'] = {
            'darkMode': false,
            'language': 'English',
            'adProvider': 'AdMob',
            'notifications': {
              'routineReminders': true,
              'streakNotifications': true,
              'weeklySummaries': false
            }
          };
        });
      } else {
        setState(() {
          _isLoggedIn = false;
          _userData = null;
        });
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      setState(() {
        _isLoggedIn = false;
        _userData = {
          "id": "error_user",
          "name": "User",
          "email": "user@dincharya.com",
          "avatar": null,
          "joinDate": "Today",
          "currentStreak": 0,
          "totalMeditationTime": 0,
          "completedRoutines": 0,
          "journalEntries": 0,
          "subscriptionPlan": SubscriptionManager().isPremium ? "Premium" : "Free",
          "achievements": <String>[],
          "preferences": {
            "darkMode": false,
            "language": "English",
            "adProvider": "AdMob",
            "notifications": {
              "routineReminders": true,
              "streakNotifications": true,
              "weeklySummaries": false
            }
          }
        };
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always show content immediately with default data while loading
    final userData = _userData ??
        {
          "id": "default_user",
          "name": "Loading...",
          "full_name": "Loading...",
          "email": "loading@dincharya.com",
          "avatar": null,
          "joinDate": "Today",
          "currentStreak": 0,
          "totalMeditationTime": 0,
          "completedRoutines": 0,
          "journalEntries": 0,
          "subscriptionPlan": SubscriptionManager().isPremium ? "Premium" : "Free",
          "achievements": <String>[],
          "preferences": {
            "darkMode": false,
            "language": "English",
            "adProvider": "AdMob",
            "notifications": {
              "routineReminders": true,
              "streakNotifications": true,
              "weeklySummaries": false
            }
          }
        };

    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Enhanced Profile Header
              _buildEnhancedProfileHeader(userData),

                    SizedBox(height: 2.h),

              // Quick Stats Row
              _buildQuickStatsRow(userData),

              SizedBox(height: 2.h),

              // Subscription Card
              if (userData["subscriptionPlan"] != "Premium")
                _buildSubscriptionCard(userData),

              if (userData["subscriptionPlan"] != "Premium")
                SizedBox(height: 2.h),

              // Settings Sections
              _buildSimpleSettings(),

              SizedBox(height: 2.h),
              
              // Native Ad — single ad per screen (AdMob policy)
              const NativeAdWidget(placement: NativePlacement.meTab),

              SizedBox(height: 8.h), // Bottom padding for tab bar
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor:
            AppTheme.lightTheme.bottomNavigationBarTheme.backgroundColor,
        selectedItemColor:
            AppTheme.lightTheme.bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor:
            AppTheme.lightTheme.bottomNavigationBarTheme.unselectedItemColor,
        items: [
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'clock',
              color: _currentIndex == 0
                  ? AppTheme
                      .lightTheme.bottomNavigationBarTheme.selectedItemColor!
                  : AppTheme
                      .lightTheme.bottomNavigationBarTheme.unselectedItemColor!,
              size: 24,
            ),
            label: 'Routine',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'meditation',
              color: _currentIndex == 1
                  ? AppTheme
                      .lightTheme.bottomNavigationBarTheme.selectedItemColor!
                  : AppTheme
                      .lightTheme.bottomNavigationBarTheme.unselectedItemColor!,
              size: 24,
            ),
            label: 'Guided',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'book',
              color: _currentIndex == 2
                  ? AppTheme
                      .lightTheme.bottomNavigationBarTheme.selectedItemColor!
                  : AppTheme
                      .lightTheme.bottomNavigationBarTheme.unselectedItemColor!,
              size: 24,
            ),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'person',
              color: _currentIndex == 3
                  ? AppTheme
                      .lightTheme.bottomNavigationBarTheme.selectedItemColor!
                  : AppTheme
                      .lightTheme.bottomNavigationBarTheme.unselectedItemColor!,
              size: 24,
            ),
            label: 'Me',
          ),
        ],
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pushReplacementNamed(context, '/routine-dashboard');
        break;
      case 1:
        Navigator.pushReplacementNamed(context, '/guided-sessions-hub');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/journal-mood-tracker');
        break;
      case 3:
        // Already on Me tab
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // Prevent dismissing during logout
      builder: (BuildContext dialogContext) {
        bool isLoggingOut = false;
        
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDF8F3), // Warm cream background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(
                  color: Color(0xFFD4A574), // Brown border
                  width: 1,
                ),
              ),
              title: Row(
                children: [
                  Icon(
                    Icons.logout_rounded,
                    color: AppTheme.lightTheme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Logout',
                    style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF2C1810), // Dark brown text
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: isLoggingOut
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B4513)),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Logging out...',
                          style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5D4037),
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Are you sure you want to logout?',
                      style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF5D4037), // Medium brown text
                      ),
                    ),
              actions: isLoggingOut
                  ? [] // No actions while logging out
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: const Color(0xFF8B7355), // Light brown
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          // Show loading state
                          setDialogState(() => isLoggingOut = true);
                          
                          try {
                            // Wait for sign out to complete
                            await _authService.signOut();
                            
                            // Small delay to ensure state is cleared
                            await Future.delayed(const Duration(milliseconds: 300));
                            
                            // Close dialog first
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            
                            // Then navigate to auth screen
                            if (mounted) {
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '/authentication-screen',
                                (route) => false,
                              );
                            }
                          } catch (e) {
                            // Handle error
                            setDialogState(() => isLoggingOut = false);
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop();
                            }
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Logout failed: $e')),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B4513), // Brown button
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Logout',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );
  }

  void _navigateToAuth() {
    Navigator.pushNamed(context, '/authentication-screen');
  }

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool isLoading = false;
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    String? errorMessage;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFDF8F3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: const BorderSide(color: Color(0xFFD4A574), width: 1),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_outline, color: Colors.orange, size: 28),
                  SizedBox(width: 2.w),
                  const Text(
                    'Change Password',
                    style: TextStyle(
                      color: Color(0xFF2C1810),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Error message
                    if (errorMessage != null)
                      Container(
                        padding: EdgeInsets.all(2.w),
                        margin: EdgeInsets.only(bottom: 2.h),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: Colors.red, size: 20),
                            SizedBox(width: 2.w),
                            Expanded(
                              child: Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red, fontSize: 12.sp),
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Current Password
                    TextField(
                      controller: currentPasswordController,
                      obscureText: obscureCurrent,
                      style: const TextStyle(color: Color(0xFF2C1810)),
                      decoration: InputDecoration(
                        labelText: 'Current Password',
                        labelStyle: TextStyle(color: Color(0xFF2C1810).withOpacity(0.7)),
                        prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF8B4513)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureCurrent ? Icons.visibility : Icons.visibility_off,
                            color: Color(0xFF8B4513),
                          ),
                          onPressed: () => setDialogState(() => obscureCurrent = !obscureCurrent),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFD4A574)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF8B4513), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    
                    // New Password
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      style: const TextStyle(color: Color(0xFF2C1810)),
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: TextStyle(color: Color(0xFF2C1810).withOpacity(0.7)),
                        prefixIcon: Icon(Icons.lock, color: Color(0xFF8B4513)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew ? Icons.visibility : Icons.visibility_off,
                            color: Color(0xFF8B4513),
                          ),
                          onPressed: () => setDialogState(() => obscureNew = !obscureNew),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFD4A574)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF8B4513), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        helperText: 'Min 8 chars, upper, lower, number, special',
                        helperStyle: TextStyle(color: Color(0xFF8B4513), fontSize: 11),
                        helperMaxLines: 2,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    
                    // Confirm Password
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      style: const TextStyle(color: Color(0xFF2C1810)),
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: TextStyle(color: Color(0xFF2C1810).withOpacity(0.7)),
                        prefixIcon: Icon(Icons.lock_reset, color: Color(0xFF8B4513)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm ? Icons.visibility : Icons.visibility_off,
                            color: Color(0xFF8B4513),
                          ),
                          onPressed: () => setDialogState(() => obscureConfirm = !obscureConfirm),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFFD4A574)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Color(0xFF8B4513), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoading ? null : () => Navigator.pop(dialogContext),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
                ElevatedButton(
                  onPressed: isLoading ? null : () async {
                    // Validate inputs
                    final currentPassword = currentPasswordController.text.trim();
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword = confirmPasswordController.text.trim();
                    
                    if (currentPassword.isEmpty || newPassword.isEmpty || confirmPassword.isEmpty) {
                      setDialogState(() => errorMessage = 'All fields are required');
                      return;
                    }
                    
                    if (newPassword != confirmPassword) {
                      setDialogState(() => errorMessage = 'New passwords do not match');
                      return;
                    }
                    
                    if (newPassword.length < 8) {
                      setDialogState(() => errorMessage = 'Password must be at least 8 characters');
                      return;
                    }
                    
                    setDialogState(() {
                      isLoading = true;
                      errorMessage = null;
                    });
                    
                    try {
                      final result = await _authService.changePassword(
                        currentPassword: currentPassword,
                        newPassword: newPassword,
                      );
                      
                      if (result['success'] == true) {
                        Navigator.pop(dialogContext);
                        if (mounted) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white),
                                  SizedBox(width: 2.w),
                                  Text('Password changed successfully!'),
                                ],
                              ),
                              backgroundColor: Colors.green,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          );
                        }
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMessage = result['message'] ?? 'Failed to change password';
                        });
                      }
                    } catch (e) {
                      setDialogState(() {
                        isLoading = false;
                        errorMessage = 'Error: ${e.toString()}';
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.5.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Change Password',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEnhancedProfileHeader(Map<String, dynamic> userData) {
    return Container(
      padding: EdgeInsets.all(5.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.lightTheme.colorScheme.primary,
            AppTheme.lightTheme.colorScheme.primary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lightTheme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 24.w,
                height: 24.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: userData["avatar_url"] != null &&
                          (userData["avatar_url"] as String).isNotEmpty
                      ? Image.network(
                          userData["avatar_url"] as String,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildAvatarFallback(userData);
                          },
                        )
                      : _buildAvatarFallback(userData),
                ),
              ),
              if (_isLoggedIn)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.all(1.5.w),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 3.w,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            userData["name"] as String,
            style: AppTheme.lightTheme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 0.5.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
                Icons.email_outlined,
                color: Colors.white.withOpacity(0.9),
                size: 16,
              ),
              SizedBox(width: 1.w),
              Flexible(
                child: Text(
                  userData["email"] as String,
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (_isLoggedIn) ...[
            SizedBox(height: 1.5.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.star,
                    color: Colors.white,
                    size: 16,
                  ),
                  SizedBox(width: 1.w),
                  Text(
                    userData["subscriptionPlan"] as String,
                    style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickStatsRow(Map<String, dynamic> userData) {
    return Row(
      children: [
        Expanded(
          child: _buildModernStatCard(
            '${userData["currentStreak"]}',
            'Day Streak',
            Icons.local_fire_department,
            Colors.orange,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: _buildModernStatCard(
            '${userData["completedRoutines"]}',
            'Routines',
            Icons.check_circle,
            Colors.green,
          ),
        ),
        SizedBox(width: 2.w),
        Expanded(
          child: _buildModernStatCard(
            '${userData["journalEntries"]}',
            'Journals',
            Icons.book,
            AppTheme.lightTheme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 3.h, horizontal: 2.w),
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(2.5.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
            icon,
            color: color,
              size: 5.w,
          ),
          ),
          SizedBox(height: 1.5.h),
          Text(
            value,
            style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 0.3.h),
          Text(
            label,
            style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
              color: AppTheme.lightTheme.colorScheme.onSurface
                  .withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOnlineStatusCard() {
    final isOnline = _supabaseService.currentUser != null;
    
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isOnline
              ? [
                  Colors.green.withOpacity(0.1),
                  Colors.green.withOpacity(0.05),
                ]
              : [
                  Colors.orange.withOpacity(0.1),
                  Colors.orange.withOpacity(0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.orange)
                .withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: isOnline ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isOnline ? Icons.cloud_done : Icons.cloud_off,
              color: Colors.white,
              size: 28,
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOnline ? 'Online & Synced' : 'Not Connected',
                  style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isOnline ? Colors.green[700] : Colors.orange[700],
                  ),
                ),
                SizedBox(height: 0.5.h),
                Text(
                  isOnline
                      ? 'All your data is synced to the cloud'
                      : 'Please sign in to sync your data',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurface
                        .withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          if (!isOnline)
            IconButton(
              onPressed: _navigateToAuth,
              icon: Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange[700],
                size: 20,
              ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleSettings() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Account Section
          if (!_isLoggedIn) ...[
          _buildModernSettingsCard(
            title: 'Account',
            children: [
              _buildModernSettingsTile(
              'Sign In',
                'Sign in to sync your data',
              Icons.login,
                Colors.blue,
              onTap: _navigateToAuth,
                isPrimary: true,
            ),
            ],
          ),
          SizedBox(height: 2.h),
          ] else ...[
          _buildModernSettingsCard(
            title: 'Account',
            children: [
            _buildModernSettingsTile(
              'Edit Profile',
              'Update your personal information',
              Icons.person_outline,
              AppTheme.lightTheme.colorScheme.primary,
              onTap: () async {
                final result = await Navigator.pushNamed(
                  context,
                  '/edit-profile',
                );
                if (result == true) {
                  // Refresh user data after profile update
                  await _loadUserData();
                }
              },
            ),
              _buildDivider(),
              _buildModernSettingsTile(
              'Change Password',
              'Update your account password',
              Icons.lock_outline,
                Colors.orange,
              onTap: () => _showChangePasswordDialog(),
            ),
          ],
          ),
        SizedBox(height: 2.h),
        ],

        // Activity Section (History)
        _buildModernSettingsCard(
          title: 'Activity',
          children: [
            _buildModernSettingsTile(
              'Your Journey',
              'View task completion history',
              Icons.calendar_month,
              Colors.teal,
              onTap: () {
                Navigator.pushNamed(context, '/history');
              },
            ),
            _buildDivider(),
            _buildModernSettingsTile(
              'Change Profile',
              'Switch your lifestyle routine',
              Icons.swap_horiz,
              Colors.purple,
              onTap: () {
                Navigator.pushNamed(context, '/profile-selection');
              },
            ),
            // Admin-only: Manage Sessions (hidden for regular users)
            if (_isAdmin) ...[
              _buildDivider(),
              _buildModernSettingsTile(
                'Manage Sessions',
                'Admin: Add/Edit guided sessions',
                Icons.admin_panel_settings,
                Colors.deepPurple,
                onTap: () {
                  Navigator.pushNamed(context, '/sessions-admin');
                },
              ),
            ],
          ],
        ),

        SizedBox(height: 2.h),

        // Preferences
        _buildModernSettingsCard(
          title: 'Notifications',
          children: [
            _buildModernSwitchTile(
              'Task Reminders',
              'Get notified 5 mins before each task',
              Icons.notifications_active,
              Colors.blue,
              _notificationsEnabled,
              (value) {
                setState(() => _notificationsEnabled = value);
                // Show feedback
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(
                          value ? Icons.notifications_active : Icons.notifications_off,
                          color: Colors.white,
                        ),
                        SizedBox(width: 2.w),
                        Text(value 
                          ? 'Task reminders enabled' 
                          : 'Task reminders disabled'),
                      ],
                    ),
                    backgroundColor: value ? Colors.green : Colors.orange,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        SizedBox(height: 2.h),

        // Support & Info
        _buildModernSettingsCard(
          title: 'Support & Info',
          children: [
            _buildModernSettingsTile(
              'Help Center',
              'FAQs और troubleshooting guide',
              Icons.help_center,
              Colors.blue,
              onTap: () => Navigator.pushNamed(context, '/help-center'),
            ),
            _buildDivider(),
            _buildModernSettingsTile(
              'Contact Support',
              'हमारी team से संपर्क करें',
              Icons.support_agent,
              Colors.purple,
              onTap: () => Navigator.pushNamed(context, '/contact-support'),
            ),
            _buildDivider(),
            _buildModernSettingsTile(
              'Share App',
              'Friends को DinCharya recommend करें',
              Icons.share,
              Colors.green,
              onTap: () async {
                const appUrl = 'https://play.google.com/store/apps/details?id=com.akashyam.dincharya';
                const shareText = '''🧘 *DinCharya* - Daily Routine Tracker

अपनी daily routine को track करें और disciplined lifestyle जीएं!

✅ Smart Task Management
✅ Personalized Routines  
✅ Progress Analytics
✅ Reminder Notifications

📲 Download करें: $appUrl''';
                
                await Share.share(
                  shareText,
                  subject: 'DinCharya - Daily Routine Tracker App',
                );
              },
            ),
            _buildDivider(),
            _buildModernSettingsTile(
              'Rate App ⭐',
              'Play Store पर rate करें',
              Icons.star_rate,
              Colors.orange,
              onTap: () => _launchUrl('https://play.google.com/store/apps/details?id=com.akashyam.dincharya'),
            ),
            _buildDivider(),
            _buildModernSettingsTile(
              'Privacy Policy',
              'हमारी privacy policy पढ़ें',
              Icons.privacy_tip,
              Colors.grey,
              onTap: () => _launchUrl('https://sites.google.com/view/dincharyaapp/home?authuser=0'),
            ),
            _buildDivider(),
            _buildModernSettingsTile(
              'Terms of Use',
              'हमारी terms of use पढ़ें',
              Icons.article,
              Colors.blueGrey,
              onTap: () => _launchUrl('https://sites.google.com/view/dincharyaappacountdelete/home'),
            ),
            _buildDivider(),
            _buildModernSettingsTile(
              'App Version',
              'v$_appVersion (Build $_buildNumber)',
              Icons.info_outline,
              Colors.teal,
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Icon(Icons.celebration, color: Colors.white),
                        SizedBox(width: 2.w),
                        Text('DinCharya v$_appVersion - Made with ❤️ in India'),
                      ],
                    ),
                    backgroundColor: Colors.teal,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                );
              },
            ),
          ],
        ),

        if (_isLoggedIn) ...[
          SizedBox(height: 3.h),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: ElevatedButton(
              onPressed: _showLogoutDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.red,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(vertical: 2.5.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 2.w),
                  Text(
                    'Logout',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModernSettingsCard({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 2.w, bottom: 1.5.h),
      child: Text(
        title,
            style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: AppTheme.lightTheme.colorScheme.onSurface,
        ),
      ),
        ),
        Container(
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.lightTheme.colorScheme.outline
                  .withValues(alpha: 0.1),
              width: 1,
            ),
        boxShadow: [
          BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 16.w,
      color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.1),
    );
  }

  Widget _buildAvatarFallback(Map<String, dynamic> userData) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.white.withValues(alpha: 0.9),
          ],
        ),
      ),
      child: Center(
        child: Container(
          width: 22.w,
          height: 22.w,
          decoration: BoxDecoration(
            color: AppTheme.lightTheme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              (userData["name"] as String).isNotEmpty
                  ? (userData["name"] as String)[0].toUpperCase()
                  : 'U',
              style: TextStyle(
                fontSize: 8.w,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernSettingsTile(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor, {
    VoidCallback? onTap,
    bool isPrimary = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
                  color: iconColor,
                  size: 5.w,
        ),
      ),
              SizedBox(width: 4.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
        title,
        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isPrimary
                            ? iconColor
                            : AppTheme.lightTheme.colorScheme.onSurface,
        ),
      ),
                    SizedBox(height: 0.3.h),
                    Text(
        subtitle,
        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.onSurface
                            .withValues(alpha: 0.6),
        ),
      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
              color: AppTheme.lightTheme.colorScheme.onSurface
                    .withValues(alpha: 0.3),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    Color iconColor,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
              color: iconColor,
              size: 5.w,
        ),
      ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
        title,
        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
        ),
      ),
                SizedBox(height: 0.3.h),
                Text(
        subtitle,
        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurface
                        .withValues(alpha: 0.6),
        ),
      ),
              ],
            ),
          ),
          Switch(
        value: value,
        onChanged: onChanged,
            activeColor: iconColor,
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(Map<String, dynamic> userData) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.lightTheme.colorScheme.primary,
            AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.white,
                size: 24,
              ),
              SizedBox(width: 2.w),
              Expanded(
                child: Text(
                  'Upgrade to Premium',
                  style: AppTheme.lightTheme.textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '₹199/month',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          Text(
            'Unlock unlimited features:',
            style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          SizedBox(height: 1.h),
          ...[
            'Unlimited Routines',
            'Premium Meditations',
            'Advanced Analytics',
            'Priority Support'
          ]
              .map((feature) => Padding(
                    padding: EdgeInsets.only(bottom: 0.5.h),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 2.w),
                        Text(
                          feature,
                          style:
                              AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ))
              ,
          SizedBox(height: 2.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _showSubscriptionDialog(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.lightTheme.colorScheme.primary,
                padding: EdgeInsets.symmetric(vertical: 2.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Upgrade Now',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSubscriptionDialog() async {
    // Navigate to the new premium PaymentPlansScreen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaymentPlansScreen(userData: _userData ?? {}),
      ),
    );
    
    // If payment was successful, refresh user data
    if (result == true) {
      setState(() {
        _userData!["subscriptionPlan"] = "Premium";
      });
    }
  }
  Future<void> _launchUrl(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not launch $urlString'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error launching URL: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}

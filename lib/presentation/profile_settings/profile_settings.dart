import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';

class ProfileSettings extends StatefulWidget {
  const ProfileSettings({super.key});

  @override
  State<ProfileSettings> createState() => _ProfileSettingsState();
}

class _ProfileSettingsState extends State<ProfileSettings> {
  int _currentIndex = 3; // Me tab is active
  bool _isLoading = true;
  bool _isLoggedIn = false;
  Map<String, dynamic>? _userData;
  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final isLoggedIn = await _authService.isUserLoggedIn();

      if (isLoggedIn) {
        final user = await _authService.getCurrentUser();
        setState(() {
          _isLoggedIn = true;
          _userData = user ??
              {
                "id": "authenticated_user",
                "name": "User",
                "email": "user@dincharya.com",
                "avatar": null,
                "joinDate": "Today",
                "currentStreak": 0,
                "totalMeditationTime": 0,
                "completedRoutines": 0,
                "journalEntries": 0,
                "subscriptionPlan": "Free",
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
          "subscriptionPlan": "Free",
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
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(
            color: AppTheme.lightTheme.colorScheme.primary,
          ),
        ),
      );
    }

    // Ensure we always have valid user data
    final userData = _userData ??
        {
          "id": "default_user",
          "name": "User",
          "email": "user@dincharya.com",
          "avatar": null,
          "joinDate": "Today",
          "currentStreak": 0,
          "totalMeditationTime": 0,
          "completedRoutines": 0,
          "journalEntries": 0,
          "subscriptionPlan": "Free",
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

              // Online Status Card
              _buildOnlineStatusCard(),

                    SizedBox(height: 2.h),

              // Subscription Card
              if (userData["subscriptionPlan"] != "Premium")
                _buildSubscriptionCard(userData),

              if (userData["subscriptionPlan"] != "Premium")
                SizedBox(height: 2.h),

              // Settings Sections
              _buildSimpleSettings(),

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
        Navigator.pushReplacementNamed(context, '/guided-meditation');
        break;
      case 2:
        Navigator.pushReplacementNamed(context, '/journal');
        break;
      case 3:
        // Already on Me tab
        break;
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Logout',
            style: AppTheme.lightTheme.textTheme.titleLarge,
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: AppTheme.lightTheme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppTheme.lightTheme.colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _authService.signOut();
                if (mounted) {
                  Navigator.pushReplacementNamed(
                      context, '/authentication-screen');
                }
              },
              child: Text(
                'Logout',
                style: TextStyle(
                  color: AppTheme.lightTheme.colorScheme.error,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAuth() {
    Navigator.pushNamed(context, '/authentication-screen');
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
            AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.3),
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
                      color: Colors.black.withValues(alpha: 0.2),
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
                color: Colors.white.withValues(alpha: 0.9),
                size: 16,
              ),
              SizedBox(width: 1.w),
              Flexible(
                child: Text(
                  userData["email"] as String,
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
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
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.3),
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
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
              color: color.withValues(alpha: 0.1),
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
                  .withValues(alpha: 0.6),
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
                  Colors.green.withValues(alpha: 0.1),
                  Colors.green.withValues(alpha: 0.05),
                ]
              : [
                  Colors.orange.withValues(alpha: 0.1),
                  Colors.orange.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOnline
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? Colors.green : Colors.orange)
                .withValues(alpha: 0.1),
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
                        .withValues(alpha: 0.7),
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
              onTap: () {},
            ),
          ],
          ),
        SizedBox(height: 2.h),
        ],

        // Preferences
        _buildModernSettingsCard(
          title: 'Preferences',
          children: [
            _buildModernSwitchTile(
            'Routine Reminders',
              'Get notified about daily routines',
            Icons.notifications,
              Colors.blue,
            true,
            (value) {},
          ),
            _buildDivider(),
            _buildModernSwitchTile(
            'Streak Notifications',
            'Celebrate your meditation streaks',
            Icons.local_fire_department,
              Colors.orange,
            true,
            (value) {},
          ),
            _buildDivider(),
            _buildModernSwitchTile(
            'Weekly Summaries',
            'Receive weekly progress reports',
            Icons.summarize,
              Colors.purple,
            false,
            (value) {},
          ),
          ],
          ),

        SizedBox(height: 2.h),

        // Data & Sync
        _buildModernSettingsCard(
          title: 'Data & Sync',
          children: [
            _buildModernSettingsTile(
            'Export Data',
              'Download your data from cloud',
            Icons.cloud_download,
              Colors.green,
            onTap: () {},
          ),
            _buildDivider(),
            _buildModernSettingsTile(
              'Sync Status',
              _isLoggedIn ? 'All data synced' : 'Sign in to sync',
              Icons.sync,
              _isLoggedIn ? Colors.green : Colors.orange,
              onTap: () {
                if (_isLoggedIn) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 2.w),
                          Text('All data is synced to the cloud'),
                        ],
                      ),
                      backgroundColor: Colors.green,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  _navigateToAuth();
                }
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
            'Get help and support',
            Icons.help_outline,
              Colors.blue,
            onTap: () {},
          ),
            _buildDivider(),
            _buildModernSettingsTile(
            'Contact Support',
            'Reach out to our team',
            Icons.support_agent,
              Colors.purple,
            onTap: () {},
          ),
            _buildDivider(),
            _buildModernSettingsTile(
            'Rate App',
            'Rate us on the app store',
            Icons.star_outline,
              Colors.orange,
            onTap: () {},
          ),
            _buildDivider(),
            _buildModernSettingsTile(
            'Privacy Policy',
            'Read our privacy policy',
            Icons.privacy_tip_outlined,
              Colors.grey,
            onTap: () {},
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
                  '₹299/month',
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

  void _showSubscriptionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            bool isYearlySelected = false;

            return AlertDialog(
              title: Text(
                'Upgrade to Premium',
                style: AppTheme.lightTheme.textTheme.titleLarge?.copyWith(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium Features:',
                      style:
                          AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
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
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 2.w),
                                  Expanded(
                                    child: Text(
                                      feature,
                                      style: AppTheme
                                          .lightTheme.textTheme.bodyMedium
                                          ?.copyWith(
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        ,
                    SizedBox(height: 2.h),

                    // Monthly Plan
                    GestureDetector(
                      onTap: () => setState(() => isYearlySelected = false),
                      child: Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: !isYearlySelected
                              ? AppTheme.lightTheme.colorScheme.primary
                                  .withValues(alpha: 0.1)
                              : Colors.grey[100]!,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: !isYearlySelected
                                ? AppTheme.lightTheme.colorScheme.primary
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: !isYearlySelected
                                    ? AppTheme.lightTheme.colorScheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: !isYearlySelected
                                      ? AppTheme.lightTheme.colorScheme.primary
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: !isYearlySelected
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Monthly Plan',
                                    style: AppTheme
                                        .lightTheme.textTheme.titleMedium
                                        ?.copyWith(
                                      color: Colors.black87,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    'Perfect for trying out',
                                    style: AppTheme
                                        .lightTheme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '₹199/month',
                              style: AppTheme.lightTheme.textTheme.titleMedium
                                  ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.lightTheme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 1.h),

                    // Yearly Plan
                    GestureDetector(
                      onTap: () => setState(() => isYearlySelected = true),
                      child: Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: isYearlySelected
                              ? AppTheme.lightTheme.colorScheme.primary
                                  .withValues(alpha: 0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isYearlySelected
                                ? AppTheme.lightTheme.colorScheme.primary
                                : Colors.grey[300]!,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isYearlySelected
                                    ? AppTheme.lightTheme.colorScheme.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: isYearlySelected
                                      ? AppTheme.lightTheme.colorScheme.primary
                                      : Colors.grey[400]!,
                                  width: 2,
                                ),
                              ),
                              child: isYearlySelected
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 3.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Yearly Plan',
                                        style: AppTheme
                                            .lightTheme.textTheme.titleMedium
                                            ?.copyWith(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 1.w, vertical: 0.5.h),
                                        decoration: BoxDecoration(
                                          color: Colors.green,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          'SAVE 17%',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    'Best value for money',
                                    style: AppTheme
                                        .lightTheme.textTheme.bodySmall
                                        ?.copyWith(
                                      color: Colors.black54,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '₹1,999/year',
                                  style: AppTheme
                                      .lightTheme.textTheme.titleMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color:
                                        AppTheme.lightTheme.colorScheme.primary,
                                  ),
                                ),
                                Text(
                                  '₹167/month',
                                  style: AppTheme.lightTheme.textTheme.bodySmall
                                      ?.copyWith(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _processPayment(isYearlySelected);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.lightTheme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    isYearlySelected ? 'Pay ₹1,999' : 'Pay ₹199',
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

  void _processPayment(bool isYearly) {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppTheme.lightTheme.colorScheme.primary,
              ),
              SizedBox(height: 2.h),
              Text('Processing payment...'),
            ],
          ),
        );
      },
    );

    // Simulate payment processing
    Future.delayed(Duration(seconds: 2), () {
      Navigator.of(context).pop(); // Close loading dialog

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isYearly
              ? 'Payment successful! Premium Yearly activated!'
              : 'Payment successful! Premium Monthly activated!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );

      // Update user data to Premium
      setState(() {
        _userData!["subscriptionPlan"] = "Premium";
      });
    });
  }
}

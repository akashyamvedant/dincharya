import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';

class SettingsSectionWidget extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback? onLogout;
  final VoidCallback? onLogin;
  final bool isLoggedIn;

  const SettingsSectionWidget({
    super.key,
    required this.userData,
    this.onLogout,
    this.onLogin,
    required this.isLoggedIn,
  });

  @override
  State<SettingsSectionWidget> createState() => _SettingsSectionWidgetState();
}

class _SettingsSectionWidgetState extends State<SettingsSectionWidget> {
  late Map<String, dynamic> preferences;

  @override
  void initState() {
    super.initState();
    preferences =
        Map<String, dynamic>.from(widget.userData["preferences"] as Map);
  }

  void _updatePreference(String key, dynamic value) {
    setState(() {
      if (key.contains('.')) {
        final keys = key.split('.');
        if (keys.length == 2) {
          (preferences[keys[0]] as Map<String, dynamic>)[keys[1]] = value;
        }
      } else {
        preferences[key] = value;
      }
    });
  }

  void _showLanguageSelector() {
    final languages = ['English', 'Hindi', 'Tamil', 'Telugu', 'Bengali'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Language',
            style: AppTheme.lightTheme.textTheme.titleMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((language) {
              return RadioListTile<String>(
                title: Text(language),
                value: language,
                groupValue: preferences["language"] as String,
                onChanged: (String? value) {
                  if (value != null) {
                    _updatePreference("language", value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showAdProviderSelector() {
    final providers = ['AdMob', 'Facebook', 'None'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Ad Provider',
            style: AppTheme.lightTheme.textTheme.titleMedium,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: providers.map((provider) {
              return RadioListTile<String>(
                title: Text(provider),
                value: provider,
                groupValue: preferences["adProvider"] as String,
                onChanged: (String? value) {
                  if (value != null) {
                    _updatePreference("adProvider", value);
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showDataManagementDialog(String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            action,
            style: AppTheme.lightTheme.textTheme.titleMedium,
          ),
          content: Text(
            '$action functionality will be implemented here.',
            style: AppTheme.lightTheme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showSupportDialog(String action) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            action,
            style: AppTheme.lightTheme.textTheme.titleMedium,
          ),
          content: Text(
            '$action will be available in the next update.',
            style: AppTheme.lightTheme.textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final notifications = preferences["notifications"] as Map<String, dynamic>;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Section
          _buildSectionHeader('Account'),
          _buildSettingsCard([
            if (!widget.isLoggedIn) ...[
              _buildSettingsTile(
                'Sign In',
                'Sign in with email or Google',
                'login',
                onTap: widget.onLogin,
              ),
            ] else ...[
              _buildSettingsTile(
                'Edit Profile',
                'Update your personal information',
                'person_outline',
                onTap: () => _showDataManagementDialog('Edit Profile'),
              ),
              _buildSettingsTile(
                'Change Password',
                'Update your account password',
                'lock_outline',
                onTap: () => _showDataManagementDialog('Change Password'),
              ),
            ],
          ]),

          SizedBox(height: 2.h),

          // Notification Preferences
          _buildSectionHeader('Notifications'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Routine Reminders',
              'Get notified about your daily routines',
              'notifications',
              notifications["routineReminders"] as bool,
              (value) =>
                  _updatePreference("notifications.routineReminders", value),
            ),
            _buildSwitchTile(
              'Streak Notifications',
              'Celebrate your meditation streaks',
              'local_fire_department',
              notifications["streakNotifications"] as bool,
              (value) =>
                  _updatePreference("notifications.streakNotifications", value),
            ),
            _buildSwitchTile(
              'Weekly Summaries',
              'Receive weekly progress reports',
              'summarize',
              notifications["weeklySummaries"] as bool,
              (value) =>
                  _updatePreference("notifications.weeklySummaries", value),
            ),
          ]),

          SizedBox(height: 2.h),

          // App Preferences
          _buildSectionHeader('App Preferences'),
          _buildSettingsCard([
            _buildSwitchTile(
              'Dark Mode',
              'Switch to dark theme',
              'dark_mode',
              preferences["darkMode"] as bool,
              (value) => _updatePreference("darkMode", value),
            ),
            _buildSettingsTile(
              'Language',
              preferences["language"] as String,
              'language',
              onTap: _showLanguageSelector,
              showArrow: true,
            ),
            if (widget.userData["subscriptionPlan"] == "Premium")
              _buildSettingsTile(
                'Ad Provider',
                preferences["adProvider"] as String,
                'ads_click',
                onTap: _showAdProviderSelector,
                showArrow: true,
              ),
          ]),

          SizedBox(height: 2.h),

          // Data Management
          _buildSectionHeader('Data Management'),
          _buildSettingsCard([
            _buildSettingsTile(
              'Export Data',
              'Download your personal data',
              'download',
              onTap: () => _showDataManagementDialog('Export Data'),
            ),
            _buildSettingsTile(
              'Backup Settings',
              'Backup your app preferences',
              'backup',
              onTap: () => _showDataManagementDialog('Backup Settings'),
            ),
            _buildSettingsTile(
              'Clear Cache',
              'Free up storage space',
              'cleaning_services',
              onTap: () => _showDataManagementDialog('Clear Cache'),
            ),
          ]),

          SizedBox(height: 2.h),

          // Support Section
          _buildSectionHeader('Support'),
          _buildSettingsCard([
            _buildSettingsTile(
              'Help Center',
              'Get help and support',
              'help_outline',
              onTap: () => _showSupportDialog('Help Center'),
            ),
            _buildSettingsTile(
              'Contact Support',
              'Reach out to our team',
              'support_agent',
              onTap: () => _showSupportDialog('Contact Support'),
            ),
            _buildSettingsTile(
              'Rate App',
              'Rate us on the app store',
              'star_outline',
              onTap: () => _showSupportDialog('Rate App'),
            ),
            _buildSettingsTile(
              'Privacy Policy',
              'Read our privacy policy',
              'privacy_tip',
              onTap: () => _showSupportDialog('Privacy Policy'),
            ),
          ]),

          SizedBox(height: 3.h),

          // Logout Button (only if logged in)
          if (widget.isLoggedIn && widget.onLogout != null) ...[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 2.w),
              child: OutlinedButton(
                onPressed: widget.onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.lightTheme.colorScheme.error,
                  side:
                      BorderSide(color: AppTheme.lightTheme.colorScheme.error),
                  padding: EdgeInsets.symmetric(vertical: 1.5.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CustomIconWidget(
                      iconName: 'logout',
                      color: AppTheme.lightTheme.colorScheme.error,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Logout',
                      style: AppTheme.lightTheme.textTheme.labelLarge?.copyWith(
                        color: AppTheme.lightTheme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Text(
        title,
        style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.lightTheme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.lightTheme.colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildSettingsTile(
    String title,
    String subtitle,
    String iconName, {
    VoidCallback? onTap,
    bool showArrow = false,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomIconWidget(
          iconName: iconName,
          color: AppTheme.lightTheme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
          color:
              AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      trailing: showArrow
          ? CustomIconWidget(
              iconName: 'chevron_right',
              color: AppTheme.lightTheme.colorScheme.onSurface
                  .withValues(alpha: 0.5),
              size: 20,
            )
          : null,
      onTap: onTap,
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
    );
  }

  Widget _buildSwitchTile(
    String title,
    String subtitle,
    String iconName,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomIconWidget(
          iconName: iconName,
          color: AppTheme.lightTheme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTheme.lightTheme.textTheme.bodySmall?.copyWith(
          color:
              AppTheme.lightTheme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
    );
  }
}

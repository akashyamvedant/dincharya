import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../services/theme_provider.dart';

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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Language',
            style: theme.textTheme.titleMedium,
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
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Ad Provider',
            style: theme.textTheme.titleMedium,
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            action,
            style: theme.textTheme.titleMedium,
          ),
          content: Text(
            '$action functionality will be implemented here.',
            style: theme.textTheme.bodyMedium,
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
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            action,
            style: theme.textTheme.titleMedium,
          ),
          content: Text(
            '$action will be available in the next update.',
            style: theme.textTheme.bodyMedium,
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
    final theme = Theme.of(context);
    final notifications = preferences["notifications"] as Map<String, dynamic>;
    final themeProvider = ThemeProvider();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Account Section
          _buildSectionHeader('Account', theme),
          _buildSettingsCard(theme, [
            if (!widget.isLoggedIn) ...[
              _buildSettingsTile(
                'Sign In',
                'Sign in with email or Google',
                'login',
                theme,
                onTap: widget.onLogin,
              ),
            ] else ...[
              _buildSettingsTile(
                'Edit Profile',
                'Update your personal information',
                'person_outline',
                theme,
                onTap: () => _showDataManagementDialog('Edit Profile'),
              ),
              _buildSettingsTile(
                'Change Password',
                'Update your account password',
                'lock_outline',
                theme,
                onTap: () => _showDataManagementDialog('Change Password'),
              ),
            ],
          ]),

          SizedBox(height: 2.h),

          // Notification Preferences
          _buildSectionHeader('Notifications', theme),
          _buildSettingsCard(theme, [
            _buildSwitchTile(
              'Routine Reminders',
              'Get notified about your daily routines',
              'notifications',
              notifications["routineReminders"] as bool,
              (value) =>
                  _updatePreference("notifications.routineReminders", value),
              theme,
            ),
            _buildSwitchTile(
              'Streak Notifications',
              'Celebrate your meditation streaks',
              'local_fire_department',
              notifications["streakNotifications"] as bool,
              (value) =>
                  _updatePreference("notifications.streakNotifications", value),
              theme,
            ),
            _buildSwitchTile(
              'Weekly Summaries',
              'Receive weekly progress reports',
              'summarize',
              notifications["weeklySummaries"] as bool,
              (value) =>
                  _updatePreference("notifications.weeklySummaries", value),
              theme,
            ),
          ]),

          SizedBox(height: 2.h),

          // App Preferences
          _buildSectionHeader('App Preferences', theme),
          _buildSettingsCard(theme, [
            // Dark Mode Toggle — uses ThemeProvider
            _buildSwitchTile(
              'Dark Mode',
              'Switch to dark theme',
              'dark_mode',
              themeProvider.isDarkMode,
              (value) {
                themeProvider.setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
              theme,
            ),
            _buildSettingsTile(
              'Language',
              preferences["language"] as String,
              'language',
              theme,
              onTap: _showLanguageSelector,
              showArrow: true,
            ),
            if (widget.userData["subscriptionPlan"] == "Premium")
              _buildSettingsTile(
                'Ad Provider',
                preferences["adProvider"] as String,
                'ads_click',
                theme,
                onTap: _showAdProviderSelector,
                showArrow: true,
              ),
          ]),

          SizedBox(height: 2.h),

          // Data Management
          _buildSectionHeader('Data Management', theme),
          _buildSettingsCard(theme, [
            _buildSettingsTile(
              'Export Data',
              'Download your personal data',
              'download',
              theme,
              onTap: () => _showDataManagementDialog('Export Data'),
            ),
            _buildSettingsTile(
              'Backup Settings',
              'Backup your app preferences',
              'backup',
              theme,
              onTap: () => _showDataManagementDialog('Backup Settings'),
            ),
            _buildSettingsTile(
              'Clear Cache',
              'Free up storage space',
              'cleaning_services',
              theme,
              onTap: () => _showDataManagementDialog('Clear Cache'),
            ),
          ]),

          SizedBox(height: 2.h),

          // Support Section
          _buildSectionHeader('Support', theme),
          _buildSettingsCard(theme, [
            _buildSettingsTile(
              'Help Center',
              'Get help and support',
              'help_outline',
              theme,
              onTap: () => _showSupportDialog('Help Center'),
            ),
            _buildSettingsTile(
              'Contact Support',
              'Reach out to our team',
              'support_agent',
              theme,
              onTap: () => _showSupportDialog('Contact Support'),
            ),
            _buildSettingsTile(
              'Rate App',
              'Rate us on the app store',
              'star_outline',
              theme,
              onTap: () => _showSupportDialog('Rate App'),
            ),
            _buildSettingsTile(
              'Privacy Policy',
              'Read our privacy policy',
              'privacy_tip',
              theme,
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
                  foregroundColor: theme.colorScheme.error,
                  side: BorderSide(color: theme.colorScheme.error),
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
                      color: theme.colorScheme.error,
                      size: 20,
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      'Logout',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.error,
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

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(ThemeData theme, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
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
    String iconName,
    ThemeData theme, {
    VoidCallback? onTap,
    bool showArrow = false,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomIconWidget(
          iconName: iconName,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      trailing: showArrow
          ? CustomIconWidget(
              iconName: 'chevron_right',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
    ThemeData theme,
  ) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(2.w),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: CustomIconWidget(
          iconName: iconName,
          color: theme.colorScheme.primary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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

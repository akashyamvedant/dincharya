// lib/presentation/enhanced_profile/widgets/data_management_widget.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class DataManagementWidget extends StatelessWidget {
  const DataManagementWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Export Data Section
          _buildSectionHeader(context, 'Export Data'),
          _buildActionCard(
            context,
            icon: 'download',
            title: 'Export Journal Entries',
            subtitle: 'Download all your journal entries as a text file',
            onTap: () => _exportJournalEntries(context),
          ),

          _buildActionCard(
            context,
            icon: 'download',
            title: 'Export Routine Data',
            subtitle: 'Download your routine and task history',
            onTap: () => _exportRoutineData(context),
          ),

          _buildActionCard(
            context,
            icon: 'download',
            title: 'Export All Data',
            subtitle: 'Download complete backup of your account data',
            onTap: () => _exportAllData(context),
          ),

          SizedBox(height: 3.h),

          // Import Data Section
          _buildSectionHeader(context, 'Import Data'),
          _buildActionCard(
            context,
            icon: 'upload',
            title: 'Import from Backup',
            subtitle: 'Restore data from a previous backup file',
            onTap: () => _importFromBackup(context),
          ),

          SizedBox(height: 3.h),

          // Storage Usage Section
          _buildSectionHeader(context, 'Storage Usage'),
          _buildStorageCard(context),

          SizedBox(height: 3.h),

          // Privacy Section
          _buildSectionHeader(context, 'Privacy & Security'),
          _buildActionCard(
            context,
            icon: 'visibility_off',
            title: 'Make Profile Private',
            subtitle: 'Hide your profile from other users',
            onTap: () => _togglePrivateProfile(context),
          ),

          _buildActionCard(
            context,
            icon: 'security',
            title: 'Two-Factor Authentication',
            subtitle: 'Add an extra layer of security',
            onTap: () => _setupTwoFactor(context),
          ),

          SizedBox(height: 3.h),

          // Danger Zone Section
          _buildSectionHeader(context, 'Danger Zone'),
          _buildActionCard(
            context,
            icon: 'delete_forever',
            title: 'Clear All Local Data',
            subtitle: 'Remove all locally stored data (cannot be undone)',
            onTap: () => _clearLocalData(context),
            isDestructive: true,
          ),

          _buildActionCard(
            context,
            icon: 'delete_forever',
            title: 'Delete Account',
            subtitle: 'Permanently delete your account and all data',
            onTap: () => _deleteAccount(context),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 1.h),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 1.h),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: (isDestructive
                    ? Colors.red
                    : Theme.of(context).colorScheme.primary)
                .withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomIconWidget(
            iconName: icon,
            color: isDestructive
                ? Colors.red
                : Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: isDestructive ? Colors.red : null,
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: CustomIconWidget(
          iconName: 'arrow_forward_ios',
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          size: 16,
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildStorageCard(BuildContext context) {
    // Mock data - in real app, get from actual storage usage
    const double totalStorage = 100.0; // MB
    const double usedStorage = 45.0; // MB
    const double storagePercentage = usedStorage / totalStorage;

    return Card(
      margin: EdgeInsets.only(bottom: 1.h),
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomIconWidget(
                  iconName: 'storage',
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Storage Used',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        '${usedStorage.toInt()} MB of ${totalStorage.toInt()} MB',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(storagePercentage * 100).toInt()}%',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            LinearProgressIndicator(
              value: storagePercentage,
              backgroundColor:
                  Theme.of(context).colorScheme.outline.withAlpha(51),
              valueColor: AlwaysStoppedAnimation<Color>(
                Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: 1.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildStorageItem(context, 'Journal', '25 MB', Colors.blue),
                _buildStorageItem(context, 'Audio', '15 MB', Colors.green),
                _buildStorageItem(context, 'Images', '5 MB', Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStorageItem(
      BuildContext context, String label, String size, Color color) {
    return Column(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(height: 0.5.h),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        Text(
          size,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  void _exportJournalEntries(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting journal entries...')),
    );
    // Implement journal export logic
  }

  void _exportRoutineData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting routine data...')),
    );
    // Implement routine export logic
  }

  void _exportAllData(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Exporting all data...')),
    );
    // Implement full export logic
  }

  void _importFromBackup(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Import functionality coming soon')),
    );
    // Implement import logic
  }

  void _togglePrivateProfile(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Privacy settings updated')),
    );
    // Implement privacy toggle logic
  }

  void _setupTwoFactor(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Two-factor setup coming soon')),
    );
    // Implement 2FA setup logic
  }

  void _clearLocalData(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Local Data'),
        content: const Text(
          'This will remove all locally cached data and journal entries stored on this device. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement clear logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Local data cleared')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _deleteAccount(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This will permanently delete your account and all associated data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Implement account deletion logic
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion initiated')),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
  }
}

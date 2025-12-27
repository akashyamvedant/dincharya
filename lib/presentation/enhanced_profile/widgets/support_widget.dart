// lib/presentation/enhanced_profile/widgets/support_widget.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class SupportWidget extends StatelessWidget {
  const SupportWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Help Center Section
          _buildSectionHeader(context, 'Help Center'),
          _buildSupportCard(
            context,
            icon: 'help',
            title: 'Frequently Asked Questions',
            subtitle: 'Find answers to common questions',
            onTap: () => _openFAQ(context),
          ),

          _buildSupportCard(
            context,
            icon: 'video_library',
            title: 'Video Tutorials',
            subtitle: 'Learn how to use DinCharya effectively',
            onTap: () => _openTutorials(context),
          ),

          _buildSupportCard(
            context,
            icon: 'menu_book',
            title: 'User Guide',
            subtitle: 'Complete guide to all features',
            onTap: () => _openUserGuide(context),
          ),

          SizedBox(height: 3.h),

          // Contact Support Section
          _buildSectionHeader(context, 'Contact Support'),
          _buildSupportCard(
            context,
            icon: 'email',
            title: 'Email Support',
            subtitle: 'Get help via email support@dincharya.com',
            onTap: () => _sendEmail(),
          ),

          _buildSupportCard(
            context,
            icon: 'chat',
            title: 'Live Chat',
            subtitle: 'Chat with our support team',
            onTap: () => _openLiveChat(context),
          ),

          _buildSupportCard(
            context,
            icon: 'phone',
            title: 'Phone Support',
            subtitle: 'Call us at +1-800-DINCHARYA',
            onTap: () => _callSupport(),
          ),

          SizedBox(height: 3.h),

          // Feedback Section
          _buildSectionHeader(context, 'Feedback'),
          _buildSupportCard(
            context,
            icon: 'feedback',
            title: 'Send Feedback',
            subtitle: 'Help us improve the app',
            onTap: () => _sendFeedback(context),
          ),

          _buildSupportCard(
            context,
            icon: 'star_rate',
            title: 'Rate the App',
            subtitle: 'Rate us on the app store',
            onTap: () => _rateApp(),
          ),

          _buildSupportCard(
            context,
            icon: 'bug_report',
            title: 'Report a Bug',
            subtitle: 'Report technical issues',
            onTap: () => _reportBug(context),
          ),

          SizedBox(height: 3.h),

          // Community Section
          _buildSectionHeader(context, 'Community'),
          _buildSupportCard(
            context,
            icon: 'forum',
            title: 'Community Forum',
            subtitle: 'Join discussions with other users',
            onTap: () => _openForum(),
          ),

          _buildSupportCard(
            context,
            icon: 'groups',
            title: 'User Groups',
            subtitle: 'Connect with local user groups',
            onTap: () => _openUserGroups(),
          ),

          SizedBox(height: 3.h),

          // App Information
          _buildSectionHeader(context, 'App Information'),
          _buildInfoCard(context),
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

  Widget _buildSupportCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 1.h),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: CustomIconWidget(
            iconName: icon,
            color: Theme.of(context).colorScheme.primary,
            size: 24,
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w500,
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

  Widget _buildInfoCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(4.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CustomIconWidget(
                  iconName: 'info',
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                SizedBox(width: 3.w),
                Text(
                  'App Information',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
            SizedBox(height: 2.h),
            _buildInfoRow(context, 'Version', '1.0.0 (Build 1)'),
            _buildInfoRow(context, 'Last Updated', 'December 2024'),
            _buildInfoRow(context, 'Developer', 'DinCharya Team'),
            _buildInfoRow(context, 'Website', 'www.dincharya.com'),
            SizedBox(height: 2.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => _openPrivacyPolicy(),
                  child: const Text('Privacy Policy'),
                ),
                TextButton(
                  onPressed: () => _openTermsOfService(),
                  child: const Text('Terms of Service'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 0.5.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  void _openFAQ(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening FAQ...')),
    );
    // Navigate to FAQ screen or open web link
  }

  void _openTutorials(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening tutorials...')),
    );
    // Navigate to tutorials screen or open video playlist
  }

  void _openUserGuide(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening user guide...')),
    );
    // Navigate to user guide screen or open documentation
  }

  Future<void> _sendEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'support@dincharya.com',
      query: 'subject=DinCharya Support Request',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _openLiveChat(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Live chat coming soon...')),
    );
    // Implement live chat functionality
  }

  Future<void> _callSupport() async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: '+1-800-346-2427',
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  void _sendFeedback(BuildContext context) {
    // Show feedback dialog
    showDialog(
      context: context,
      builder: (context) => _FeedbackDialog(),
    );
  }

  Future<void> _rateApp() async {
    // Open app store for rating
    const String playStoreUrl =
        'https://play.google.com/store/apps/details?id=com.dincharya.app';

    // Try to open appropriate store
    final Uri uri = Uri.parse(playStoreUrl); // Default to Play Store

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _reportBug(BuildContext context) {
    // Show bug report dialog
    showDialog(
      context: context,
      builder: (context) => _BugReportDialog(),
    );
  }

  Future<void> _openForum() async {
    final Uri forumUri = Uri.parse('https://forum.dincharya.com');

    if (await canLaunchUrl(forumUri)) {
      await launchUrl(forumUri);
    }
  }

  Future<void> _openUserGroups() async {
    final Uri groupsUri = Uri.parse('https://groups.dincharya.com');

    if (await canLaunchUrl(groupsUri)) {
      await launchUrl(groupsUri);
    }
  }

  Future<void> _openPrivacyPolicy() async {
    final Uri privacyUri = Uri.parse('https://dincharya.com/privacy');

    if (await canLaunchUrl(privacyUri)) {
      await launchUrl(privacyUri);
    }
  }

  Future<void> _openTermsOfService() async {
    final Uri termsUri = Uri.parse('https://dincharya.com/terms');

    if (await canLaunchUrl(termsUri)) {
      await launchUrl(termsUri);
    }
  }
}

class _FeedbackDialog extends StatefulWidget {
  @override
  State<_FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<_FeedbackDialog> {
  final TextEditingController _feedbackController = TextEditingController();
  int _rating = 5;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Feedback'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How would you rate your experience?'),
          SizedBox(height: 1.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                onPressed: () {
                  setState(() {
                    _rating = index + 1;
                  });
                },
                icon: Icon(
                  index < _rating ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                ),
              );
            }),
          ),
          SizedBox(height: 2.h),
          TextField(
            controller: _feedbackController,
            decoration: const InputDecoration(
              labelText: 'Your feedback',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Thank you for your feedback!')),
            );
          },
          child: const Text('Send'),
        ),
      ],
    );
  }
}

class _BugReportDialog extends StatefulWidget {
  @override
  State<_BugReportDialog> createState() => _BugReportDialogState();
}

class _BugReportDialogState extends State<_BugReportDialog> {
  final TextEditingController _bugController = TextEditingController();
  String _severity = 'Medium';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Report a Bug'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _severity,
            decoration: const InputDecoration(
              labelText: 'Severity',
              border: OutlineInputBorder(),
            ),
            items: ['Low', 'Medium', 'High', 'Critical'].map((severity) {
              return DropdownMenuItem(
                value: severity,
                child: Text(severity),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _severity = value!;
              });
            },
          ),
          SizedBox(height: 2.h),
          TextField(
            controller: _bugController,
            decoration: const InputDecoration(
              labelText: 'Describe the bug',
              border: OutlineInputBorder(),
            ),
            maxLines: 4,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bug report submitted')),
            );
          },
          child: const Text('Report'),
        ),
      ],
    );
  }
}

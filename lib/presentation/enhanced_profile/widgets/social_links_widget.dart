// lib/presentation/enhanced_profile/widgets/social_links_widget.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/app_export.dart';
import '../../../widgets/custom_icon_widget.dart';

class SocialLinksWidget extends StatelessWidget {
  const SocialLinksWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Follow Us Section
          _buildSectionHeader(context, 'Follow Us'),
          _buildSocialCard(
            context,
            icon: 'facebook',
            title: 'Facebook',
            subtitle: 'Follow us for daily inspiration',
            url: 'https://facebook.com/dincharya',
            color: const Color(0xFF1877F2),
          ),

          _buildSocialCard(
            context,
            icon: 'twitter',
            title: 'Twitter',
            subtitle: 'Get the latest updates and tips',
            url: 'https://twitter.com/dincharya',
            color: const Color(0xFF1DA1F2),
          ),

          _buildSocialCard(
            context,
            icon: 'instagram',
            title: 'Instagram',
            subtitle: 'Visual inspiration and community',
            url: 'https://instagram.com/dincharya',
            color: const Color(0xFFE4405F),
          ),

          _buildSocialCard(
            context,
            icon: 'youtube',
            title: 'YouTube',
            subtitle: 'Guided meditation and tutorials',
            url: 'https://youtube.com/dincharya',
            color: const Color(0xFFFF0000),
          ),

          _buildSocialCard(
            context,
            icon: 'linkedin',
            title: 'LinkedIn',
            subtitle: 'Professional wellness insights',
            url: 'https://linkedin.com/company/dincharya',
            color: const Color(0xFF0A66C2),
          ),

          SizedBox(height: 3.h),

          // Community Section
          _buildSectionHeader(context, 'Join Our Community'),
          _buildSocialCard(
            context,
            icon: 'discord',
            title: 'Discord',
            subtitle: 'Connect with fellow practitioners',
            url: 'https://discord.gg/dincharya',
            color: const Color(0xFF5865F2),
          ),

          _buildSocialCard(
            context,
            icon: 'telegram',
            title: 'Telegram',
            subtitle: 'Daily motivation and support',
            url: 'https://t.me/dincharya',
            color: const Color(0xFF0088CC),
          ),

          _buildSocialCard(
            context,
            icon: 'reddit',
            title: 'Reddit',
            subtitle: 'Community discussions and Q&A',
            url: 'https://reddit.com/r/dincharya',
            color: const Color(0xFFFF4500),
          ),

          SizedBox(height: 3.h),

          // Share Section
          _buildSectionHeader(context, 'Share DinCharya'),
          Card(
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'share',
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Share with Friends',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Help your friends discover mindful living',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: 2.h),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildShareButton(
                        context,
                        icon: 'message',
                        label: 'Message',
                        onTap: () => _shareViaMessage(),
                      ),
                      _buildShareButton(
                        context,
                        icon: 'email',
                        label: 'Email',
                        onTap: () => _shareViaEmail(),
                      ),
                      _buildShareButton(
                        context,
                        icon: 'link',
                        label: 'Copy Link',
                        onTap: () => _copyAppLink(context),
                      ),
                      _buildShareButton(
                        context,
                        icon: 'more_horiz',
                        label: 'More',
                        onTap: () => _showMoreShareOptions(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 3.h),

          // Newsletter Section
          _buildSectionHeader(context, 'Stay Updated'),
          Card(
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CustomIconWidget(
                        iconName: 'mail',
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        'Newsletter',
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.h),
                  Text(
                    'Get weekly wellness tips and app updates',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  SizedBox(height: 2.h),
                  ElevatedButton(
                    onPressed: () => _subscribeToNewsletter(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 5.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Subscribe to Newsletter'),
                  ),
                ],
              ),
            ),
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

  Widget _buildSocialCard(
    BuildContext context, {
    required String icon,
    required String title,
    required String subtitle,
    required String url,
    required Color color,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: 1.h),
      child: ListTile(
        leading: Container(
          padding: EdgeInsets.all(2.w),
          decoration: BoxDecoration(
            color: color.withAlpha(26),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getIconData(icon),
            color: color,
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
        onTap: () => _openUrl(url),
      ),
    );
  }

  Widget _buildShareButton(
    BuildContext context, {
    required String icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withAlpha(26),
              borderRadius: BorderRadius.circular(12),
            ),
            child: CustomIconWidget(
              iconName: icon,
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'facebook':
        return Icons.facebook;
      case 'twitter':
        return Icons.alternate_email;
      case 'instagram':
        return Icons.photo_camera;
      case 'youtube':
        return Icons.play_circle_fill;
      case 'linkedin':
        return Icons.business;
      case 'discord':
        return Icons.chat;
      case 'telegram':
        return Icons.send;
      case 'reddit':
        return Icons.forum;
      default:
        return Icons.link;
    }
  }

  Future<void> _openUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _shareViaMessage() async {
    const String shareText =
        'Check out DinCharya - A mindful living app that helps you build healthy daily routines! Download it now: https://dincharya.com';

    final Uri smsUri = Uri(
      scheme: 'sms',
      queryParameters: {'body': shareText},
    );

    if (await canLaunchUrl(smsUri)) {
      await launchUrl(smsUri);
    }
  }

  Future<void> _shareViaEmail() async {
    const String shareText =
        'Check out DinCharya - A mindful living app that helps you build healthy daily routines! Download it now: https://dincharya.com';

    final Uri emailUri = Uri(
      scheme: 'mailto',
      queryParameters: {
        'subject': 'Discover DinCharya - Mindful Living App',
        'body': shareText,
      },
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _copyAppLink(BuildContext context) {
    // In a real app, you would copy to clipboard
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App link copied to clipboard!')),
    );
  }

  void _showMoreShareOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12.w,
              height: 0.5.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: 2.h),
            Text(
              'Share DinCharya',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 2.h),
            ListTile(
              leading: const Icon(Icons.qr_code),
              title: const Text('QR Code'),
              subtitle: const Text('Share via QR code'),
              onTap: () {
                Navigator.pop(context);
                _showQRCode(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.near_me),
              title: const Text('AirDrop'),
              subtitle: const Text('Share with nearby devices'),
              onTap: () {
                Navigator.pop(context);
                // Implement AirDrop sharing
              },
            ),
            ListTile(
              leading: const Icon(Icons.wifi),
              title: const Text('WiFi Direct'),
              subtitle: const Text('Share via WiFi Direct'),
              onTap: () {
                Navigator.pop(context);
                // Implement WiFi Direct sharing
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showQRCode(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share via QR Code'),
        content: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Text('QR Code\n(Placeholder)', textAlign: TextAlign.center),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('QR code saved to gallery')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _subscribeToNewsletter(BuildContext context) {
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscribe to Newsletter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Enter your email to receive weekly wellness tips and app updates.'),
            SizedBox(height: 2.h),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
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
                const SnackBar(
                    content: Text('Successfully subscribed to newsletter!')),
              );
            },
            child: const Text('Subscribe'),
          ),
        ],
      ),
    );
  }
}

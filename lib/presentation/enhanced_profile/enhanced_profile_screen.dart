import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_icon_widget.dart';
import './widgets/app_preferences_widget.dart';
import './widgets/data_management_widget.dart';
import './widgets/profile_edit_widget.dart';
import './widgets/social_links_widget.dart';
import './widgets/support_widget.dart';

// lib/presentation/enhanced_profile/enhanced_profile_screen.dart

class EnhancedProfileScreen extends StatefulWidget {
  const EnhancedProfileScreen({super.key});

  @override
  State<EnhancedProfileScreen> createState() => _EnhancedProfileScreenState();
}

class _EnhancedProfileScreenState extends State<EnhancedProfileScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadCurrentUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentUser() async {
    try {
      final user = await _authService.getCurrentUser();
      setState(() {
        _currentUser = user;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to load user data: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('Profile Settings',
                style: Theme.of(context).textTheme.titleLarge),
            bottom: TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Edit Profile'),
                  Tab(text: 'Preferences'),
                  Tab(text: 'Data'),
                  Tab(text: 'Support'),
                  Tab(text: 'Social'),
                ]),
            actions: [
              // Blue tick verification indicator
              if (_currentUser?['is_verified'] == true)
                Padding(
                    padding: EdgeInsets.only(right: 3.w),
                    child: CustomIconWidget(
                        iconName: 'verified', color: Colors.blue, size: 24)),
            ]),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(controller: _tabController, children: [
                ProfileEditWidget(onProfileUpdated: () => _loadCurrentUser()),
                AppPreferencesWidget(),
                DataManagementWidget(),
                SupportWidget(),
                SocialLinksWidget(),
              ]));
  }
}

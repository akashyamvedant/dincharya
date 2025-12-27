import 'package:flutter/material.dart';

import '../../core/app_export.dart';
import '../../services/supabase_service.dart';
import '../../widgets/custom_icon_widget.dart';
import 'widgets/ad_settings_widget.dart';
import 'widgets/app_settings_widget.dart';
import 'widgets/audio_management_widget.dart';
import 'widgets/user_management_widget.dart';

// lib/presentation/admin_control_panel/admin_control_panel.dart

class AdminControlPanel extends StatefulWidget {
  const AdminControlPanel({super.key});

  @override
  State<AdminControlPanel> createState() => _AdminControlPanelState();
}

class _AdminControlPanelState extends State<AdminControlPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseService _supabase = SupabaseService();

  bool _isLoading = false;
  Map<String, dynamic> _adminSettings = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAdminSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminSettings() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final settings = await _supabase.getAdminSettings();
      if (settings.isNotEmpty) {
        setState(() {
          _adminSettings = settings.first;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load admin settings: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Admin Control Panel',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ad Settings'),
            Tab(text: 'Audio'),
            Tab(text: 'Users'),
            Tab(text: 'App Settings'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadAdminSettings,
            icon: CustomIconWidget(
              iconName: 'refresh',
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                AdSettingsWidget(
                  adminSettings: _adminSettings,
                  onSettingsUpdated: _loadAdminSettings,
                ),
                AudioManagementWidget(
                  audioSessions: [],
                  onRefresh: () {},
                ),
                UserManagementWidget(
                  users: [],
                  onRefresh: () {},
                ),
                AppSettingsWidget(
                  settings: {},
                  onSettingsChanged: (p0) {},
                ),
              ],
            ),
    );
  }
}

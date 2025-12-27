import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../services/supabase_service.dart';

// lib/presentation/admin_control_panel/widgets/user_management_widget.dart

class UserManagementWidget extends StatefulWidget {
  final List<Map<String, dynamic>> users;
  final Function() onRefresh;

  const UserManagementWidget({
    super.key,
    required this.users,
    required this.onRefresh,
  });

  @override
  State<UserManagementWidget> createState() => _UserManagementWidgetState();
}

class _UserManagementWidgetState extends State<UserManagementWidget> {
  final SupabaseService _supabase = SupabaseService();
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Card(
        child: Padding(
            padding: EdgeInsets.all(16.h),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('User Management',
                    style: TextStyle(
                        fontSize: 18.sp, fontWeight: FontWeight.bold)),
                IconButton(
                    onPressed: _isLoading ? null : widget.onRefresh,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child:
                                const CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.refresh)),
              ]),
              SizedBox(height: 16.h),
              if (widget.users.isEmpty)
                Center(
                    child: Text('No users found',
                        style: TextStyle(fontSize: 14.sp)))
              else
                ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: widget.users.length,
                    itemBuilder: (context, index) {
                      final user = widget.users[index];
                      return _buildUserTile(user);
                    }),
            ])));
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final isAdmin = user['is_admin'] ?? false;
    final isActive = user['is_active'] ?? true;

    return ListTile(
        leading: CircleAvatar(
            backgroundColor: isAdmin ? Colors.orange : Colors.blue,
            child: Icon(isAdmin ? Icons.admin_panel_settings : Icons.person,
                color: Colors.white)),
        title: Text(user['full_name'] ?? 'Unknown User'),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(user['email'] ?? 'No email'),
          Row(children: [
            Icon(isActive ? Icons.circle : Icons.circle_outlined,
                size: 12, color: isActive ? Colors.green : Colors.grey),
            SizedBox(width: 4.w),
            Text(isActive ? 'Active' : 'Inactive',
                style: TextStyle(
                    fontSize: 12.sp,
                    color: isActive ? Colors.green : Colors.grey)),
            if (isAdmin) ...[
              SizedBox(width: 8.w),
              Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                      color: Colors.orange.withAlpha(51),
                      borderRadius: BorderRadius.circular(10)),
                  child: Text('ADMIN',
                      style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange))),
            ],
          ]),
        ]),
        trailing: PopupMenuButton(
            itemBuilder: (context) => [
                  PopupMenuItem(
                      value: isActive ? 'deactivate' : 'activate',
                      child: Row(children: [
                        Icon(isActive ? Icons.block : Icons.check_circle),
                        SizedBox(width: 8.w),
                        Text(isActive ? 'Deactivate' : 'Activate'),
                      ])),
                  if (!isAdmin)
                    const PopupMenuItem(
                        value: 'make_admin',
                        child: Row(children: [
                          Icon(Icons.admin_panel_settings),
                          SizedBox(width: 8),
                          Text('Make Admin'),
                        ])),
                  if (isAdmin)
                    const PopupMenuItem(
                        value: 'remove_admin',
                        child: Row(children: [
                          Icon(Icons.person),
                          SizedBox(width: 8),
                          Text('Remove Admin'),
                        ])),
                ],
            onSelected: (value) => _handleUserAction(value, user)));
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'activate':
      case 'deactivate':
        _toggleUserStatus(user['id'], action == 'activate');
        break;
      case 'make_admin':
        _toggleAdminStatus(user['id'], true);
        break;
      case 'remove_admin':
        _toggleAdminStatus(user['id'], false);
        break;
    }
  }

  Future<void> _toggleUserStatus(String userId, bool isActive) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.updateUserProfile(userId, {'is_active': isActive});
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'User ${isActive ? 'activated' : 'deactivated'} successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update user status: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleAdminStatus(String userId, bool isAdmin) async {
    setState(() => _isLoading = true);
    try {
      await _supabase.updateUserProfile(userId, {'is_admin': isAdmin});
      widget.onRefresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(isAdmin
                ? 'Admin privileges granted'
                : 'Admin privileges removed')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update admin status: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}

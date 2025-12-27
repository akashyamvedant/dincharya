import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

// lib/presentation/admin_control_panel/widgets/app_settings_widget.dart

class AppSettingsWidget extends StatefulWidget {
  final Map<String, dynamic> settings;
  final Function(Map<String, dynamic>) onSettingsChanged;

  const AppSettingsWidget({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<AppSettingsWidget> createState() => _AppSettingsWidgetState();
}

class _AppSettingsWidgetState extends State<AppSettingsWidget> {
  late Map<String, dynamic> _localSettings;

  @override
  void initState() {
    super.initState();
    _localSettings = Map.from(widget.settings);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Settings',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16.h),
            _buildSwitchTile(
              'Enable Push Notifications',
              _localSettings['push_notifications'] ?? true,
              (value) {
                setState(() {
                  _localSettings['push_notifications'] = value;
                });
                widget.onSettingsChanged(_localSettings);
              },
            ),
            _buildSwitchTile(
              'Enable Dark Mode',
              _localSettings['dark_mode'] ?? true,
              (value) {
                setState(() {
                  _localSettings['dark_mode'] = value;
                });
                widget.onSettingsChanged(_localSettings);
              },
            ),
            _buildSwitchTile(
              'Enable Analytics',
              _localSettings['analytics'] ?? false,
              (value) {
                setState(() {
                  _localSettings['analytics'] = value;
                });
                widget.onSettingsChanged(_localSettings);
              },
            ),
            _buildSwitchTile(
              'Maintenance Mode',
              _localSettings['maintenance_mode'] ?? false,
              (value) {
                setState(() {
                  _localSettings['maintenance_mode'] = value;
                });
                widget.onSettingsChanged(_localSettings);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(
    String title,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
      dense: true,
    );
  }
}

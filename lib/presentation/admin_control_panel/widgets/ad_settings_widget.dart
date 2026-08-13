// lib/presentation/admin_control_panel/widgets/ad_settings_widget.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../../../services/ads_service.dart';

class AdSettingsWidget extends StatefulWidget {
  final Map<String, dynamic> adminSettings;
  final VoidCallback onSettingsUpdated;

  const AdSettingsWidget({
    super.key,
    required this.adminSettings,
    required this.onSettingsUpdated,
  });

  @override
  State<AdSettingsWidget> createState() => _AdSettingsWidgetState();
}

class _AdSettingsWidgetState extends State<AdSettingsWidget> {
  final AdsService _adsService = AdsService();
  final _formKey = GlobalKey<FormState>();

  late String _selectedAdNetwork;
  final Map<String, TextEditingController> _adMobControllers = {};

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeSettings();
  }

  @override
  void dispose() {
    for (var controller in _adMobControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _initializeSettings() {
    _selectedAdNetwork = widget.adminSettings['ad_network'] ?? 'admob';

    // Initialize AdMob controllers
    final adMobSettings = widget.adminSettings['admob_settings'] ?? {};
    _adMobControllers['app_id'] = TextEditingController(
      text: adMobSettings['app_id'] ?? '',
    );
    _adMobControllers['banner_id'] = TextEditingController(
      text: adMobSettings['banner_id'] ?? '',
    );
    _adMobControllers['interstitial_id'] = TextEditingController(
      text: adMobSettings['interstitial_id'] ?? '',
    );
    _adMobControllers['rewarded_id'] = TextEditingController(
      text: adMobSettings['rewarded_id'] ?? '',
    );
    _adMobControllers['open_app_id'] = TextEditingController(
      text: adMobSettings['open_app_id'] ?? '',
    );
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final adMobSettings = {
        'app_id': _adMobControllers['app_id']!.text,
        'banner_id': _adMobControllers['banner_id']!.text,
        'interstitial_id': _adMobControllers['interstitial_id']!.text,
        'rewarded_id': _adMobControllers['rewarded_id']!.text,
        'open_app_id': _adMobControllers['open_app_id']!.text,
      };

      final result = await _adsService.updateAdSettings(
        adNetwork: _selectedAdNetwork,
        adMobSettings: adMobSettings,
      );

      if (result['success']) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          );
          widget.onSettingsUpdated();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: ${e.toString()}'),
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
    return SingleChildScrollView(
      padding: EdgeInsets.all(4.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ad Network Selection
            Card(
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ad Network Selection',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 2.h),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedAdNetwork,
                      decoration: const InputDecoration(
                        labelText: 'Select Ad Network',
                        prefixIcon: Icon(Icons.ads_click),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'admob',
                          child: Text('Google AdMob'),
                        ),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedAdNetwork = value!;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 2.h),

            // AdMob Settings
            Card(
              child: Padding(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Google AdMob Settings',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _adMobControllers['app_id']!,
                      label: 'AdMob App ID',
                      hint: 'ca-app-pub-xxxxxxxxxxxxxxxx~yyyyyyyyyy',
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _adMobControllers['banner_id']!,
                      label: 'Banner Ad ID',
                      hint: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy',
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _adMobControllers['interstitial_id']!,
                      label: 'Interstitial Ad ID',
                      hint: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy',
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _adMobControllers['rewarded_id']!,
                      label: 'Rewarded Ad ID',
                      hint: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy',
                    ),
                    SizedBox(height: 2.h),
                    _buildTextField(
                      controller: _adMobControllers['open_app_id']!,
                      label: 'App Open Ad ID',
                      hint: 'ca-app-pub-xxxxxxxxxxxxxxxx/yyyyyyyyyy',
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 4.h),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _saveSettings,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Save Ad Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool isRequired = false,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: isRequired
          ? (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter $label';
              }
              return null;
            }
          : null,
    );
  }
}

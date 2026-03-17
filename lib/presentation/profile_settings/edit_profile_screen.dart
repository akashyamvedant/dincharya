import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/ads/banner_ad_widget.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _emailController = TextEditingController();

  final AuthService _authService = AuthService();
  final SupabaseService _supabaseService = SupabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = false;
  bool _isInitialLoading = true;
  bool _isUploadingImage = false;
  File? _selectedImage;
  String? _currentAvatarUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isInitialLoading = true;
    });

    try {
      final user = await _authService.getCurrentUser();
      if (user != null) {
        setState(() {
          _nameController.text = user['full_name'] ?? user['name'] ?? '';
          _bioController.text = user['bio'] ?? '';
          _emailController.text = user['email'] ?? '';
          _currentAvatarUrl = user['avatar_url'];
        });

        // Try to get profile from user_profiles table for bio and avatar
        final userId = _supabaseService.currentUser?.id;
        if (userId != null) {
          final profile = await _supabaseService.getUserProfile(userId);
          if (profile.isNotEmpty) {
            setState(() {
              _bioController.text = profile.first['bio'] ?? '';
              _currentAvatarUrl = profile.first['avatar_url'] ?? _currentAvatarUrl;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load profile data'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isInitialLoading = false;
        });
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _uploadProfileImage() async {
    if (_selectedImage == null) return null;

    setState(() {
      _isUploadingImage = true;
    });

    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated. Please sign in again.');
      }

      // Wait for Supabase to be initialized
      await _supabaseService.initFuture;

      // Read image file
      final imageBytes = await _selectedImage!.readAsBytes();
      
      if (imageBytes.isEmpty) {
        throw Exception('Selected image is empty or corrupted');
      }

      debugPrint('📤 Uploading profile image...');
      debugPrint('   - User ID: $userId');
      debugPrint('   - File size: ${(imageBytes.length / 1024).toStringAsFixed(2)} KB');

      // Generate unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'profile_${userId}_$timestamp.jpg';
      final filePath = '$userId/$fileName';

      debugPrint('   - File path: $filePath');

      // Upload to Supabase storage
      final imageUrl = await _supabaseService.uploadFile(
        'profile_images',
        filePath,
        imageBytes,
      );

      debugPrint('✅ Image uploaded successfully: $imageUrl');

      setState(() {
        _isUploadingImage = false;
        _currentAvatarUrl = imageUrl;
      });

      return imageUrl;
    } catch (e) {
      debugPrint('❌ Error uploading image: $e');
      setState(() {
        _isUploadingImage = false;
      });
      
      String errorMessage = 'Failed to upload image';
      if (e.toString().contains('bucket')) {
        errorMessage = 'Storage bucket not configured. Please contact support.';
      } else if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
        errorMessage = 'Permission denied. Please check your account settings.';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else {
        errorMessage = 'Upload failed: ${e.toString().replaceAll('Exception: ', '')}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Upload image first if selected
      String? avatarUrl = _currentAvatarUrl;
      if (_selectedImage != null) {
        avatarUrl = await _uploadProfileImage();
        if (avatarUrl == null && _selectedImage != null) {
          // Image upload failed, but continue with profile update
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      final updates = {
        'full_name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        if (avatarUrl != null) 'avatar_url': avatarUrl,
      };

      final result = await _authService.updateProfile(updates);

      if (mounted) {
        if (result['success'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 2.w),
                  Text(result['message'] ?? 'Profile updated successfully'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Pop back to profile settings
          Navigator.of(context).pop(true);
        } else {
          String errorMessage = result['message'] ?? 'Failed to update profile';
          
          // Check for specific backend errors
          if (errorMessage.contains('does not exist') || 
              errorMessage.contains('relation') ||
              errorMessage.contains('table')) {
            errorMessage = 'Database table not found. Please run Supabase setup SQL script.';
          } else if (errorMessage.contains('permission') || 
                     errorMessage.contains('unauthorized')) {
            errorMessage = 'Permission denied. Please check database policies.';
          } else if (errorMessage.contains('bucket')) {
            errorMessage = 'Storage bucket not configured. Please create profile_images bucket.';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      errorMessage,
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Setup Guide',
                textColor: Colors.white,
                onPressed: () {
                  // You can navigate to setup guide or show dialog
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Backend Setup Required'),
                      content: Text(
                        'Please run the SQL script from SUPABASE_SETUP.sql file in your Supabase SQL Editor.\n\n'
                        'Steps:\n'
                        '1. Open Supabase Dashboard\n'
                        '2. Go to SQL Editor\n'
                        '3. Copy and paste the entire SUPABASE_SETUP.sql file\n'
                        '4. Click "Run" to execute',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('OK'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating profile: $e');
      if (mounted) {
        String errorMessage = 'Something went wrong';
        final errorString = e.toString().toLowerCase();
        
        if (errorString.contains('table not found') || 
            errorString.contains('does not exist') ||
            errorString.contains('relation')) {
          errorMessage = 'Database table not found. Please run Supabase setup SQL script.';
        } else if (errorString.contains('permission') || 
                   errorString.contains('unauthorized')) {
          errorMessage = 'Permission denied. Please check database policies.';
        } else if (errorString.contains('network') || 
                   errorString.contains('connection')) {
          errorMessage = 'Network error. Please check your internet connection.';
        } else {
          errorMessage = 'We encountered an unexpected error while processing your request.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
            action: errorMessage.contains('table not found') 
                ? SnackBarAction(
                    label: 'Setup Guide',
                    textColor: Colors.white,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Backend Setup Required'),
                          content: Text(
                            'Please run the SQL script from SUPABASE_SETUP.sql file in your Supabase SQL Editor.\n\n'
                            'Steps:\n'
                            '1. Open Supabase Dashboard\n'
                            '2. Go to SQL Editor\n'
                            '3. Copy and paste the entire SUPABASE_SETUP.sql file\n'
                            '4. Click "Run" to execute',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('OK'),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 100) {
      return 'Name must be less than 100 characters';
    }
    return null;
  }

  String? _validateBio(String? value) {
    if (value != null && value.length > 500) {
      return 'Bio must be less than 500 characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Edit Profile'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(4.w),
              child: Center(
                child: SizedBox(
                  width: 5.w,
                  height: 5.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _saveProfile,
              child: Text(
                'Save',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.all(4.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Picture Section
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickImage,
                          child: Container(
                            width: 30.w,
                            height: 30.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 3,
                              ),
                            ),
                            child: ClipOval(
                              child: _isUploadingImage
                                  ? Container(
                                      color: Theme.of(context).colorScheme.primary,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      ),
                                    )
                                  : _selectedImage != null
                                      ? Image.file(
                                          _selectedImage!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) {
                                            return _buildAvatarFallback();
                                          },
                                        )
                                      : _currentAvatarUrl != null &&
                                              _currentAvatarUrl!.isNotEmpty
                                          ? Image.network(
                                              _currentAvatarUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return _buildAvatarFallback();
                                              },
                                            )
                                          : _buildAvatarFallback(),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _isUploadingImage ? null : _pickImage,
                            child: Container(
                              padding: EdgeInsets.all(2.5.w),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 5.w,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 1.5.h),
                    TextButton.icon(
                      onPressed: _isUploadingImage ? null : _pickImage,
                      icon: Icon(
                        Icons.photo_library,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      label: Text(
                        _selectedImage != null
                            ? 'Change Photo'
                            : 'Add Photo',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (_selectedImage != null)
                      Padding(
                        padding: EdgeInsets.only(top: 0.5.h),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _selectedImage = null;
                            });
                          },
                          child: Text(
                            'Remove Photo',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              SizedBox(height: 4.h),

              // Name Field
              _buildSectionLabel('Full Name'),
              SizedBox(height: 1.h),
              _buildTextField(
                controller: _nameController,
                label: 'Enter your full name',
                icon: Icons.person_outline,
                validator: _validateName,
                maxLength: 100,
              ),

              SizedBox(height: 3.h),

              // Email Field (Read-only)
              _buildSectionLabel('Email'),
              SizedBox(height: 1.h),
              _buildTextField(
                controller: _emailController,
                label: 'Email address',
                icon: Icons.email_outlined,
                readOnly: true,
                enabled: false,
              ),
              Padding(
                padding: EdgeInsets.only(top: 0.5.h, left: 2.w),
                child: Text(
                  'Email cannot be changed',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),

              SizedBox(height: 3.h),

              // Bio Field
              _buildSectionLabel('Bio'),
              SizedBox(height: 1.h),
              _buildTextField(
                controller: _bioController,
                label: 'Tell us about yourself (optional)',
                icon: Icons.description_outlined,
                validator: _validateBio,
                maxLines: 4,
                maxLength: 500,
                onChanged: () => setState(() {}),
              ),
              Padding(
                padding: EdgeInsets.only(top: 0.5.h, left: 2.w),
                child: Text(
                  '${_bioController.text.length}/500 characters',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _bioController.text.length > 500
                        ? Colors.red
                        : Theme.of(context).colorScheme.onSurface
                            .withValues(alpha: 0.6),
                  ),
                ),
              ),

              SizedBox(height: 4.h),

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 3.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 2,
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 5.w,
                          height: 5.w,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.save, size: 20),
                            SizedBox(width: 2.w),
                            Text(
                              'Save Changes',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              SizedBox(height: 2.h),
              
              // Banner Ad at bottom
              const BannerAdWidget(placement: BannerPlacement.editProfile),
              
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    bool readOnly = false,
    bool enabled = true,
    int maxLines = 1,
    int? maxLength,
    VoidCallback? onChanged,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      readOnly: readOnly,
      enabled: enabled,
      maxLines: maxLines,
      maxLength: maxLength,
      onChanged: onChanged != null ? (_) => onChanged() : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(
          icon,
          color: enabled
              ? Color(0xFF8B4513)
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        filled: true,
        fillColor: enabled
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 3.h),
      ),
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }

  Widget _buildAvatarFallback() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Text(
          (_nameController.text.isNotEmpty
                  ? _nameController.text[0]
                  : 'U')
              .toUpperCase(),
          style: TextStyle(
            fontSize: 10.w,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}


import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import './supabase_service.dart';

// lib/services/auth_service.dart

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supabase = SupabaseService();
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Input validation helpers
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
        .hasMatch(email);
  }

  bool _isValidPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]')
            .hasMatch(password);
  }

  bool _isValidFullName(String fullName) {
    return fullName.isNotEmpty &&
        fullName.length <= 100 &&
        RegExp(r'^[a-zA-Z\s]+$').hasMatch(fullName);
  }

  // Secure hash function for sensitive data
  String _hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    try {
      final supabaseClient = await _supabase.client;
      return supabaseClient?.auth.currentUser != null;
    } catch (e) {
      debugPrint('Error checking login status: $e');
      return false;
    }
  }

  // Get current user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final supabaseClient = await _supabase.client;
      final user = supabaseClient?.auth.currentUser;
      if (user != null) {
        // Try to get profile from user_profiles table
        Map<String, dynamic>? profileData;
        try {
          final profile = await _supabase.getUserProfile(user.id);
          if (profile.isNotEmpty) {
            profileData = profile.first;
          }
        } catch (e) {
          debugPrint('Error fetching user profile: $e');
        }

        // Return basic user info from auth and profile table
        return {
          'id': user.id,
          'email': user.email ?? 'user@dincharya.com',
          'full_name': profileData?['full_name'] ??
              user.userMetadata?['full_name'] ??
              user.email?.split('@')[0] ??
              'User',
          'bio': profileData?['bio'] ?? '',
          'avatar_url': profileData?['avatar_url'] ??
              user.userMetadata?['avatar_url'],
          'created_at': user.createdAt,
          'name': profileData?['full_name'] ??
              user.userMetadata?['full_name'] ??
              user.email?.split('@')[0] ??
              'User',
          'joinDate': 'Today',
          'currentStreak': 0,
          'totalMeditationTime': 0,
          'completedRoutines': 0,
          'journalEntries': 0,
          'subscriptionPlan': 'Free',
          'achievements': <String>[],
          'preferences': {
            'darkMode': false,
            'language': 'English',
            'adProvider': 'AdMob',
            'notifications': {
              'routineReminders': true,
              'streakNotifications': true,
              'weeklySummaries': false
            }
          }
        };
      }
      return null;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Get current user (synchronous getter)
  User? get currentUser {
    try {
      // This is a synchronous getter, but we need to access the client
      // We'll use a different approach - get from SupabaseService directly
      return _supabase.currentUser;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signIn({
    required String email,
    required String password,
  }) async {
    try {
      // Input validation
      if (!_isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Please enter a valid email address',
        };
      }

      if (!_isValidPassword(password)) {
        return {
          'success': false,
          'message': 'Please enter a valid password',
        };
      }

      final response = await _supabase.signIn(email, password);

      if (response.user != null) {
        // Save login state securely
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('has_completed_onboarding', true);

        // Store hashed user info for security
        final hashedUserId = _hashData(response.user!.id);
        await prefs.setString('user_hash', hashedUserId);

        return {
          'success': true,
          'user': response.user,
          'message': 'Signed in successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'Invalid email or password',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Google sign in
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      debugPrint('🔄 Starting Google Sign-In...');

      // Check if Google Sign-In is available
      final isAvailable = await _googleSignIn.isSignedIn();
      debugPrint('📱 Google Sign-In available: $isAvailable');

      final result = await _googleSignIn.signIn();
      debugPrint('🔍 Google Sign-In result: ${result?.email ?? 'null'}');

      if (result != null) {
        // Get Google authentication details
        final googleAuth = await result.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        debugPrint(
            '🔑 Google Auth - AccessToken: ${accessToken != null ? 'present' : 'null'}');
        debugPrint(
            '🔑 Google Auth - IdToken: ${idToken != null ? 'present' : 'null'}');

        if (accessToken != null && idToken != null) {
          // Use Supabase for Google authentication with tokens
          final supabaseClient = await _supabase.client;
          if (supabaseClient != null) {
            debugPrint('🌐 Authenticating with Supabase...');

            final response = await supabaseClient.auth.signInWithIdToken(
              provider: OAuthProvider.google,
              idToken: idToken,
              accessToken: accessToken,
            );

            if (response.user != null) {
              debugPrint('✅ Supabase authentication successful');

              // Save login state securely
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('has_completed_onboarding', true);

              // Store hashed user info for security
              final hashedUserId = _hashData(response.user!.id);
              await prefs.setString('user_hash', hashedUserId);

              return {
                'success': true,
                'user': response.user,
                'message': 'Google sign in successful',
              };
            } else {
              debugPrint('❌ Supabase authentication failed - no user returned');
            }
          } else {
            debugPrint('❌ Supabase client is null');
          }
        } else {
          debugPrint('❌ Google authentication tokens are null');
        }
      } else {
        debugPrint('❌ Google Sign-In result is null (user cancelled)');
      }

      return {
        'success': false,
        'message': 'Google sign in cancelled or failed',
      };
    } catch (e) {
      debugPrint('❌ Google sign in error: $e');

      // Provide more specific error messages
      String errorMessage = 'Google sign in failed';
      if (e.toString().contains('ApiException: 10')) {
        errorMessage =
            'Google Sign-In needs proper configuration. Please check GOOGLE_SIGNIN_SETUP.md or use Email/Password.';
      } else if (e.toString().contains('sign_in_failed')) {
        errorMessage =
            'Google Sign-In failed. Please try again or use Email/Password.';
      } else if (e.toString().contains('network')) {
        errorMessage = 'Network error. Please check your connection.';
      }

      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Sign up with email and password
  Future<Map<String, dynamic>> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    try {
      // Input validation
      if (!_isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Please enter a valid email address',
        };
      }

      if (!_isValidPassword(password)) {
        return {
          'success': false,
          'message':
              'Password must be at least 8 characters with uppercase, lowercase, number, and special character',
        };
      }

      if (!_isValidFullName(fullName)) {
        return {
          'success': false,
          'message': 'Please enter a valid full name',
        };
      }

      final response = await _supabase.signUp(email, password);

      if (response.user != null) {
        // Create user profile with full name
        try {
          final supabaseClient = await _supabase.client;
          if (supabaseClient != null) {
            await supabaseClient.from('user_profiles').insert({
              'id': response.user!.id,
              'full_name': fullName,
              'email': email,
              'bio': '',
              'avatar_url': null,
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            }).select();
            debugPrint('✅ User profile created successfully');
          }
        } catch (e) {
          debugPrint('⚠️ Error creating user profile: $e');
          // Continue even if profile creation fails - it will be created on first update
        }

        return {
          'success': true,
          'user': response.user,
          'message':
              'Account created successfully! Please check your email to verify your account.',
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to create account. Please try again.',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': e.toString().replaceAll('Exception: ', ''),
      };
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      if (!_isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Please enter a valid email address',
        };
      }

      final supabaseClient = await _supabase.client;
      if (supabaseClient != null) {
        await supabaseClient.auth.resetPasswordForEmail(email);
      }

      return {
        'success': true,
        'message': 'Password reset email sent successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to send reset email. Please try again.',
      };
    }
  }

  // Fixed UserAttributes import and usage
  // Change password - Fixed UserAttributes usage with validation
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      // Input validation
      if (!_isValidPassword(newPassword)) {
        return {
          'success': false,
          'message':
              'New password must be at least 8 characters with uppercase, lowercase, number, and special character',
        };
      }

      // First verify current password by attempting to sign in
      final supabaseClient = await _supabase.client;
      final currentUser = supabaseClient?.auth.currentUser;

      if (currentUser?.email != null) {
        // Try to sign in with current password to verify
        try {
          await _supabase.signIn(currentUser!.email!, currentPassword);
        } catch (e) {
          return {
            'success': false,
            'message': 'Current password is incorrect',
          };
        }

        // Update password - Fixed method call
        if (supabaseClient != null) {
          await supabaseClient.auth.updateUser(
            UserAttributes(
              password: newPassword,
            ),
          );
        }

        return {
          'success': true,
          'message': 'Password changed successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'User not found',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Failed to change password: ${e.toString()}',
      };
    }
  }

  // Update user profile
  Future<Map<String, dynamic>> updateProfile(
      Map<String, dynamic> updates) async {
    try {
      final supabaseClient = await _supabase.client;
      final user = supabaseClient?.auth.currentUser;

      if (user != null) {
        // Validate updates
        final validatedUpdates = <String, dynamic>{};
        final authMetadataUpdates = <String, dynamic>{};

        for (final entry in updates.entries) {
          final key = entry.key;
          final value = entry.value;

          if (key == 'full_name' && _isValidFullName(value.toString())) {
            final trimmedValue = value.toString().trim();
            validatedUpdates[key] = trimmedValue;
            authMetadataUpdates['full_name'] = trimmedValue;
          } else if (key == 'bio') {
            // Bio can be empty, just check max length
            final trimmedValue = value.toString().trim();
            if (trimmedValue.length <= 500) {
              validatedUpdates[key] = trimmedValue;
            }
          } else if (key == 'avatar_url') {
            final trimmedValue = value.toString().trim();
            if (trimmedValue.isEmpty || trimmedValue.length <= 500) {
              validatedUpdates[key] = trimmedValue;
              if (trimmedValue.isNotEmpty) {
                authMetadataUpdates['avatar_url'] = trimmedValue;
              }
            }
          } else if (key == 'phone' && value.toString().length <= 20) {
            validatedUpdates[key] = value.toString().trim();
          } else if (key == 'updated_at') {
            validatedUpdates[key] = value;
          }
        }

        validatedUpdates['updated_at'] = DateTime.now().toIso8601String();

        // Update user_profiles table
        await _supabase.updateUserProfile(user.id, validatedUpdates);

        // Also update auth metadata if full_name was updated
        if (authMetadataUpdates.isNotEmpty && supabaseClient != null) {
          try {
            await supabaseClient.auth.updateUser(
              UserAttributes(data: authMetadataUpdates),
            );
          } catch (e) {
            debugPrint('Error updating auth metadata: $e');
            // Don't fail the whole operation if metadata update fails
          }
        }

        return {
          'success': true,
          'message': 'Profile updated successfully',
        };
      } else {
        return {
          'success': false,
          'message': 'User not found',
        };
      }
    } catch (e) {
      debugPrint('❌ Error in updateProfile: $e');
      
      String errorMessage = 'Failed to update profile';
      final errorString = e.toString().toLowerCase();
      
      // Provide user-friendly error messages
      if (errorString.contains('table not found') || 
          errorString.contains('does not exist') ||
          errorString.contains('relation') ||
          errorString.contains('42p01')) {
        errorMessage = 'Database table not found. Please run Supabase setup SQL script.';
      } else if (errorString.contains('permission') || 
                 errorString.contains('unauthorized') ||
                 errorString.contains('42501')) {
        errorMessage = 'Permission denied. Please check database policies.';
      } else if (errorString.contains('network') || 
                 errorString.contains('connection') ||
                 errorString.contains('timeout')) {
        errorMessage = 'Network error. Please check your internet connection.';
      } else if (errorString.contains('not initialized')) {
        errorMessage = 'Service not initialized. Please try again.';
      } else {
        errorMessage = 'Something went wrong: ${e.toString().replaceAll('Exception: ', '')}';
      }
      
      return {
        'success': false,
        'message': errorMessage,
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.signOut();
      await _googleSignIn.signOut();

      // Clear stored preferences securely
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('has_completed_onboarding');
      await prefs.remove('user_hash');
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  // Check if user has completed onboarding
  Future<bool> hasCompletedOnboarding() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('has_completed_onboarding') ?? false;
    } catch (e) {
      debugPrint('Error checking onboarding status: $e');
      return false;
    }
  }

  // Mark onboarding as completed
  Future<void> markOnboardingCompleted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('has_completed_onboarding', true);
      debugPrint('Onboarding marked as completed');
    } catch (e) {
      debugPrint('Error marking onboarding as completed: $e');
      rethrow;
    }
  }

  // Verify user session integrity
  Future<bool> verifySessionIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString('user_hash');

      if (storedHash == null) return false;

      final currentUser = await getCurrentUser();
      if (currentUser == null) return false;

      final currentHash = _hashData(currentUser['id'] ?? '');
      return storedHash == currentHash;
    } catch (e) {
      debugPrint('Error verifying session integrity: $e');
      return false;
    }
  }
}

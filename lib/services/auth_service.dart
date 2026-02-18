import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:convert';
import 'dart:io' show Platform;

import './supabase_service.dart';
import './subscription_manager.dart';
import '../core/utils/validators.dart';

// lib/services/auth_service.dart

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseService _supabase = SupabaseService();
  
  // GoogleSignIn with serverClientId for Supabase integration
  // The serverClientId MUST be the Web Client ID from Google Cloud Console
  // Without this, Supabase cannot validate the idToken and users won't be created
  late final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: dotenv.env['GOOGLE_WEB_CLIENT_ID'],
    scopes: ['email', 'profile'],
  );

  // Input validation helpers - using centralized Validators class

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
          'is_admin': profileData?['is_admin'] ?? false, // Admin flag from database
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
      // Input validation
      if (!Validators.isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Please enter a valid email address',
        };
      }

      if (!Validators.isValidPassword(password)) {
        return {
          'success': false,
          'message': 'Please enter a valid password',
        };
      }

      final response = await _supabase.signIn(email, password);

      if (response.user != null) {
        // Save login state securely
        final prefs = await SharedPreferences.getInstance();

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
      debugPrint('═══════════════════════════════════════════════════════════');
      debugPrint('🔄 Starting Google Sign-In...');
      debugPrint('📋 serverClientId loaded: ${dotenv.env['GOOGLE_WEB_CLIENT_ID'] != null}');
      debugPrint('📋 serverClientId value: ${dotenv.env['GOOGLE_WEB_CLIENT_ID']?.substring(0, 20) ?? 'NULL'}...');
      debugPrint('═══════════════════════════════════════════════════════════');

      // First sign out to clear any cached state
      await _googleSignIn.signOut();
      debugPrint('🔄 Cleared previous Google sign-in state');

      final result = await _googleSignIn.signIn();
      debugPrint('🔍 Google Sign-In result: ${result?.email ?? 'null'}');

      if (result != null) {
        debugPrint('✅ Google account selected: ${result.email}');
        debugPrint('👤 Display name: ${result.displayName}');
        
        // Get Google authentication details
        final googleAuth = await result.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        debugPrint('🔑 AccessToken present: ${accessToken != null}');
        debugPrint('🔑 IdToken present: ${idToken != null}');
        if (idToken != null) {
          debugPrint('🔑 IdToken length: ${idToken.length}');
          debugPrint('🔑 IdToken preview: ${idToken.substring(0, 50)}...');
        }

        if (accessToken != null && idToken != null) {
          // Use Supabase for Google authentication with tokens
          final supabaseClient = await _supabase.client;
          if (supabaseClient != null) {
            debugPrint('🌐 Authenticating with Supabase...');
            debugPrint('🌐 Supabase client ready');

            try {
              final response = await supabaseClient.auth.signInWithIdToken(
                provider: OAuthProvider.google,
                idToken: idToken,
                accessToken: accessToken,
              );
              
              debugPrint('🌐 Supabase response received');
              debugPrint('🌐 Response user: ${response.user?.id ?? 'NULL'}');
              debugPrint('🌐 Response session: ${response.session != null}');

              if (response.user != null) {
                debugPrint('✅ Supabase authentication successful');
                debugPrint('👤 User ID: ${response.user!.id}');
                debugPrint('📧 User Email: ${response.user!.email}');

                // Profile is now created automatically by database trigger
                // This is just a verification/fallback step
                try {
                  // Small delay to let trigger execute
                  await Future.delayed(const Duration(milliseconds: 500));
                  
                  final existingProfile = await supabaseClient
                      .from('user_profiles')
                      .select('id, email')
                      .eq('id', response.user!.id)
                      .limit(1);
                  
                  if (existingProfile != null && (existingProfile as List).isNotEmpty) {
                    debugPrint('✅ User profile verified/created by trigger');
                  } else {
                    // Fallback: Create profile if trigger didn't work
                    debugPrint('⚠️ Trigger may not have fired, creating profile manually...');
                    await supabaseClient.from('user_profiles').upsert({
                      'id': response.user!.id,
                      'full_name': result.displayName ?? response.user!.userMetadata?['full_name'] ?? 'User',
                      'email': result.email ?? response.user!.email ?? '',
                      'bio': '',
                      'avatar_url': result.photoUrl ?? response.user!.userMetadata?['avatar_url'],
                      'created_at': DateTime.now().toIso8601String(),
                      'updated_at': DateTime.now().toIso8601String(),
                    }).select();
                    debugPrint('✅ User profile created manually (fallback)');
                  }
                } catch (profileError) {
                  debugPrint('⚠️ Profile verification error (non-fatal): $profileError');
                  // Non-fatal - user can still use the app, profile will be created on next action
                }

                // Save login state securely
                final prefs = await SharedPreferences.getInstance();

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
                debugPrint('❌ Response details: session=${response.session}');
              }
            } catch (supabaseError, stackTrace) {
              debugPrint('❌ SUPABASE AUTH ERROR: $supabaseError');
              debugPrint('❌ Stack trace: $stackTrace');
              
              // Return specific error message
              return {
                'success': false,
                'message': 'Supabase auth error: ${supabaseError.toString()}',
              };
            }
          } else {
            debugPrint('❌ Supabase client is null');
          }
        } else {
          debugPrint('❌ Google authentication tokens are null');
          debugPrint('❌ This usually means serverClientId is not configured correctly');
        }
      } else {
        debugPrint('❌ Google Sign-In result is null (user cancelled)');
      }

      return {
        'success': false,
        'message': 'Google sign in cancelled or failed',
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Google sign in error: $e');
      debugPrint('❌ Stack trace: $stackTrace');

      // Provide more specific error messages
      String errorMessage = 'Google sign in failed: ${e.toString()}';
      if (e.toString().contains('ApiException: 10')) {
        errorMessage =
            'Google Sign-In needs proper configuration. serverClientId may be wrong.';
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
      // Input validation
      if (!Validators.isValidEmail(email)) {
        return {
          'success': false,
          'message': 'Please enter a valid email address',
        };
      }

      if (!Validators.isValidPassword(password)) {
        return {
          'success': false,
          'message':
              'Password must be at least 8 characters with uppercase, lowercase, number, and special character',
        };
      }

      if (!Validators.isValidName(fullName)) {
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

        // Auto-login: Save session state
        try {
          final prefs = await SharedPreferences.getInstance();
          
          // Store hashed user info for security
          final hashedUserId = _hashData(response.user!.id);
          await prefs.setString('user_hash', hashedUserId);
          
          debugPrint('✅ User auto-logged in after signup');
        } catch (e) {
          debugPrint('⚠️ Error saving session: $e');
        }

        // Auto-start 7-day free trial for new users
        try {
          final trialStarted = await SubscriptionManager().startFreeTrial();
          if (trialStarted) {
            debugPrint('🎉 7-day free trial activated for new user');
          }
        } catch (e) {
          debugPrint('⚠️ Trial activation failed (non-blocking): $e');
        }

        return {
          'success': true,
          'user': response.user,
          'message': 'Account created successfully! Welcome to DinCharya.',
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
      if (!Validators.isValidEmail(email)) {
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
      // Input validation
      if (!Validators.isValidPassword(newPassword)) {
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

          if (key == 'full_name' && Validators.isValidName(value.toString())) {
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

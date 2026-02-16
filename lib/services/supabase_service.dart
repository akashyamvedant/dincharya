// lib/services/supabase_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../core/utils/validators.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  late final SupabaseClient _client;
  bool _isInitialized = false;
  late final Future<void> _initFuture;

  final Uuid _uuid = const Uuid();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal() {
    _initFuture = _initializeSupabase();
  }

  // Add getter for _initFuture
  Future<void> get initFuture => _initFuture;

  // Add initialize method that was missing
  Future<void> initialize() async {
    await _initFuture;
  }

  // Input validation helper - using centralized Validators class



  Future<void> _initializeSupabase() async {
    // Get environment variables from .env file
    String supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
    String supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    // Validation: fail if keys are missing to prevent using default/insecure keys
    if (supabaseUrl.isEmpty || supabaseUrl == 'your-supabase-url-here') {
      debugPrint('❌ Fatal: SUPABASE_URL not found in .env file');
      debugPrint('💡 Tip: Make sure .env file exists with SUPABASE_URL');
      _isInitialized = false;
      return; 
    }

    if (supabaseAnonKey.isEmpty ||
        supabaseAnonKey == 'your-supabase-anon-key-here') {
      debugPrint('❌ Fatal: SUPABASE_ANON_KEY not found in .env file');
      debugPrint('💡 Tip: Make sure .env file exists with SUPABASE_ANON_KEY');
      _isInitialized = false;
      return;
    }

    debugPrint('Supabase URL: ${supabaseUrl.isEmpty ? "NOT SET" : "SET"}');
    debugPrint(
        'Supabase Anon Key: ${supabaseAnonKey.isEmpty ? "NOT SET" : "SET"}');

    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );

      _client = Supabase.instance.client;
      _isInitialized = true;
      debugPrint('✅ Supabase initialized successfully');
    } catch (e) {
      debugPrint('❌ Failed to initialize Supabase: $e');
      _isInitialized = false;
    }
  }

  Future<SupabaseClient?> get client async {
    if (!_isInitialized) {
      await _initFuture;
    }
    return _isInitialized ? _client : null;
  }

  // Get current user
  User? get currentUser {
    if (!_isInitialized) {
      return null;
    }
    return _client.auth.currentUser;
  }

  // Authentication methods with input validation
  Future<AuthResponse> signUp(String email, String password) async {
    try {
      // Ensure client is initialized
      final client = await this.client;

      if (client == null) {
        throw Exception(
            'Supabase not initialized. Please check your internet connection and try again.');
      }

      // Input validation
      if (!Validators.isValidEmail(email)) {
        throw Exception('Invalid email format');
      }
      if (!Validators.isValidPassword(password)) {
        throw Exception(
            'Password must be at least 8 characters with uppercase, lowercase, number, and special character');
      }

      // Sign up with auto-confirm option (no email verification required)
      return await client.auth.signUp(
        email: email, 
        password: password,
        emailRedirectTo: null, // Disable email verification redirect
      );
    } catch (e) {
      throw Exception('Sign up failed: $e');
    }
  }

  Future<AuthResponse> signIn(String email, String password) async {
    try {
      // Ensure client is initialized
      final client = await this.client;

      if (client == null) {
        throw Exception(
            'Supabase not initialized. Please check your internet connection and try again.');
      }

      // Input validation
      if (!Validators.isValidEmail(email)) {
        throw Exception('Invalid email format');
      }
      if (!Validators.isValidString(password)) {
        throw Exception('Password cannot be empty');
      }

      return await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      throw Exception('Sign in failed: $e');
    }
  }

  Future<void> signOut() async {
    try {
      final client = await this.client;
      if (client != null) {
        await client.auth.signOut();
      }
    } catch (e) {
      debugPrint('Sign out failed: $e');
    }
  }

  Future<bool> signInWithGoogle() async {
    try {
      final client = await this.client;
      if (client == null) {
        debugPrint('Supabase not initialized, cannot sign in with Google');
        return false;
      }
      return await client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (e) {
      debugPrint('Google sign in failed: $e');
      return false;
    }
  }

  // User profile methods with validation
  Future<List<Map<String, dynamic>>> getUserProfile(String userId) async {
    try {
      if (!Validators.isValidUserId(userId)) {
        throw Exception('Invalid user ID');
      }

      if (!_isInitialized) {
        debugPrint('⚠️ Supabase not initialized, returning empty profile');
        return [];
      }

      final response = await _client
          .from('user_profiles')
          .select()
          .eq('id', userId)
          .limit(1);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> updateUserProfile(
      String userId, Map<String, dynamic> updates) async {
    try {
      if (!Validators.isValidUserId(userId)) {
        throw Exception('Invalid user ID');
      }

      if (!_isInitialized) {
        debugPrint('⚠️ Supabase not initialized, cannot update profile');
        throw Exception('Supabase not initialized');
      }

      // Validate and sanitize updates
      final sanitizedUpdates = <String, dynamic>{};
      debugPrint('📝 Updating profile with data: ${updates.keys.toList()}');
      
      for (final entry in updates.entries) {
        final key = entry.key;
        final value = entry.value;

        if (key == 'full_name') {
          final trimmedValue = value.toString().trim();
          if (Validators.isValidString(trimmedValue, maxLength: 100)) {
            sanitizedUpdates[key] = trimmedValue;
            debugPrint('   ✓ full_name: ${trimmedValue.substring(0, trimmedValue.length > 20 ? 20 : trimmedValue.length)}...');
          }
        } else if (key == 'bio') {
          // Bio can be empty, so allow empty string
          final trimmedValue = value.toString().trim();
          if (trimmedValue.isEmpty || Validators.isValidString(trimmedValue, maxLength: 500)) {
            sanitizedUpdates[key] = trimmedValue;
            debugPrint('   ✓ bio: ${trimmedValue.isEmpty ? "(empty)" : "${trimmedValue.substring(0, trimmedValue.length > 30 ? 30 : trimmedValue.length)}..."}');
          }
        } else if (key == 'avatar_url') {
          final trimmedValue = value.toString().trim();
          if (trimmedValue.isEmpty || Validators.isValidString(trimmedValue, maxLength: 500)) {
            sanitizedUpdates[key] = trimmedValue;
            debugPrint('   ✓ avatar_url: ${trimmedValue.isEmpty ? "(empty)" : "set"}');
          }
        } else if (key == 'updated_at') {
          sanitizedUpdates[key] = value;
        }
      }

      // Ensure updated_at is set
      sanitizedUpdates['updated_at'] = DateTime.now().toIso8601String();
      debugPrint('📤 Final sanitized updates: ${sanitizedUpdates.keys.toList()}');

      // Try to update first, if no rows affected, insert
      try {
        // First, try to update existing profile
        final updateResponse = await _client
            .from('user_profiles')
            .update(sanitizedUpdates)
            .eq('id', userId)
            .select();

        if (updateResponse.isNotEmpty) {
          debugPrint('✅ Profile updated successfully');
          return List<Map<String, dynamic>>.from(updateResponse);
        }

        // If no rows updated, profile doesn't exist, so insert
        debugPrint('📝 Profile does not exist, creating new profile for user: $userId');
        final insertData = {
          'id': userId,
          'created_at': DateTime.now().toIso8601String(),
          ...sanitizedUpdates,
        };
        
        final insertResponse = await _client
            .from('user_profiles')
            .insert(insertData)
            .select();

        debugPrint('✅ Profile created successfully');
        return List<Map<String, dynamic>>.from(insertResponse);
      } catch (dbError) {
        debugPrint('❌ Database error: $dbError');
        
        // Check for specific database errors
        final errorString = dbError.toString().toLowerCase();
        if (errorString.contains('relation') || 
            errorString.contains('does not exist') ||
            errorString.contains('table') ||
            errorString.contains('42p01')) {
          throw Exception('Database table "user_profiles" not found. Please run SUPABASE_SETUP.sql in your Supabase SQL Editor.');
        } else if (errorString.contains('permission') || 
                   errorString.contains('unauthorized') ||
                   errorString.contains('42501') ||
                   errorString.contains('new row violates row-level security')) {
          throw Exception('Permission denied. Please check RLS policies in Supabase. Make sure the user_profiles table has proper RLS policies.');
        } else if (errorString.contains('duplicate key') ||
                   errorString.contains('unique constraint')) {
          // If duplicate key error, try update again
          try {
            final updateResponse = await _client
                .from('user_profiles')
                .update(sanitizedUpdates)
                .eq('id', userId)
                .select();
            return List<Map<String, dynamic>>.from(updateResponse);
          } catch (retryError) {
            throw Exception('Failed to update profile: ${retryError.toString()}');
          }
        } else {
          throw Exception('Database error: ${dbError.toString()}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating user profile: $e');
      rethrow; // Re-throw to let caller handle the error
    }
  }

  // Local tasks methods with validation
  Future<List<Map<String, dynamic>>> getLocalTasks(String userId) async {
    try {
      if (!Validators.isValidUserId(userId)) {
        throw Exception('Invalid user ID');
      }

      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      // Get user's active lifestyle profile
      final profileData = await client
          .from('user_profiles')
          .select('lifestyle_profile')
          .eq('id', userId)
          .maybeSingle();
      final activeProfile = profileData?['lifestyle_profile'] ?? 'custom';

      final response = await client
          .from('local_tasks')
          .select()
          .eq('user_id', userId)
          .order('created_at');

      // Filter: show only tasks matching active profile + user's custom tasks
      final allTasks = List<Map<String, dynamic>>.from(response);
      final filtered = allTasks.where((task) {
        final source = task['profile_source']?.toString() ?? 'custom';
        if (activeProfile == 'custom') return source == 'custom';
        return source == activeProfile || source == 'custom';
      }).toList();

      return filtered;
    } catch (e) {
      debugPrint('Error getting local tasks: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> createLocalTask(
      Map<String, dynamic> taskData) async {
    try {
      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      final userId = taskData['user_id']?.toString() ?? '';
      if (!Validators.isValidUserId(userId)) {
        throw Exception('Invalid user ID');
      }
      if (!Validators.isValidString(taskData['title']?.toString() ?? '',
          maxLength: 200)) {
        throw Exception('Invalid task title');
      }

      final sanitizedTaskData = {
        'id': Validators.isValidString(taskData['id']?.toString() ?? '')
            ? taskData['id'].toString()
            : _uuid.v4(),
        'user_id': userId,
        'title': taskData['title'].toString().trim(),
        'description': taskData['description']?.toString().trim() ?? '',
        'category': taskData['category']?.toString().trim(),
        'time': taskData['time']?.toString().trim(),
        'due_date': taskData['due_date'],
        'priority': taskData['priority'],
        'status': taskData['status'],
        'is_completed': taskData['is_completed'] ?? false,
        'profile_source': taskData['profile_source']?.toString() ?? 'custom',
        'created_at':
            taskData['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }..removeWhere((key, value) => value == null);

      final response =
          await client.from('local_tasks').upsert(sanitizedTaskData).select();

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to create local task: $e');
    }
  }

  Future<List<Map<String, dynamic>>> updateLocalTask(
      String taskId, Map<String, dynamic> updates) async {
    try {
      if (!Validators.isValidString(taskId)) {
        throw Exception('Invalid task ID');
      }

      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      final sanitizedUpdates = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };
      for (final entry in updates.entries) {
        final key = entry.key;
        final value = entry.value;

        if (value == null) continue;
        if (key == 'title' &&
            Validators.isValidString(value.toString(), maxLength: 200)) {
          sanitizedUpdates[key] = value.toString().trim();
        } else if (key == 'description' &&
            Validators.isValidString(value.toString(), maxLength: 1000)) {
          sanitizedUpdates[key] = value.toString().trim();
        } else if (key == 'time' &&
            Validators.isValidString(value.toString(), maxLength: 50)) {
          sanitizedUpdates[key] = value.toString().trim();
        } else if (key == 'category' &&
            Validators.isValidString(value.toString(), maxLength: 100)) {
          sanitizedUpdates[key] = value.toString().trim();
        } else if (key == 'status' &&
            Validators.isValidString(value.toString(), maxLength: 50)) {
          sanitizedUpdates[key] = value.toString().trim();
        } else if (key == 'priority' && value is int) {
          sanitizedUpdates[key] = value;
        } else if (key == 'due_date') {
          sanitizedUpdates[key] = value;
        } else if (key == 'is_completed' && value is bool) {
          sanitizedUpdates[key] = value;
        }
      }

      final response = await client
          .from('local_tasks')
          .update(sanitizedUpdates)
          .eq('id', taskId)
          .select()
          .limit(1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to update local task: $e');
    }
  }

  Future<void> deleteLocalTask(String taskId) async {
    try {
      if (!Validators.isValidString(taskId)) {
        throw Exception('Invalid task ID');
      }

      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      await client.from('local_tasks').delete().eq('id', taskId);
    } catch (e) {
      throw Exception('Failed to delete local task: $e');
    }
  }

  /// Delete all tasks created from a specific profile
  /// Used to prevent duplicates when re-selecting a profile
  Future<void> deleteTasksByProfile(String userId, String profileName) async {
    try {
      if (!Validators.isValidUserId(userId)) {
        throw Exception('Invalid user ID');
      }

      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      // Delete tasks where description contains the profile name
      final descriptionPattern = 'Part of $profileName routine';
      await client
          .from('local_tasks')
          .delete()
          .eq('user_id', userId)
          .ilike('description', '%$descriptionPattern%');
      
      debugPrint('✅ Deleted existing tasks for profile: $profileName');
    } catch (e) {
      debugPrint('⚠️ Error deleting profile tasks: $e');
      // Don't throw - allow task creation to proceed
    }
  }

  /// Delete all preset profile tasks (used when switching to Custom Routine)
  /// This preserves user's manually created custom tasks
  Future<void> deleteAllPresetProfileTasks(String userId) async {
    const presetProfiles = ['Yogic Lifestyle', 'Student Life', 'Working Professional', 'Homemaker'];
    
    for (final profileName in presetProfiles) {
      await deleteTasksByProfile(userId, profileName);
    }
    debugPrint('✅ Deleted all preset profile tasks');
  }

  /// Get tasks by profile_source column (e.g., 'student', 'yogic')
  Future<List<Map<String, dynamic>>> getTasksByProfileSource(String userId, String profileId) async {
    try {
      if (!Validators.isValidUserId(userId)) return [];
      final client = await this.client;
      if (client == null) return [];

      final response = await client
          .from('local_tasks')
          .select()
          .eq('user_id', userId)
          .eq('profile_source', profileId);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting tasks by profile source: $e');
      return [];
    }
  }

  // Admin settings management with validation
  Future<List<dynamic>> getAdminSettings() async {
    try {
      // Check if user has admin privileges
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // TODO: Implement proper admin role checking
      // For now, we'll allow access but this should be restricted

      return await _client.from('admin_settings').select().limit(1);
    } catch (e) {
      throw Exception('Failed to get admin settings: $e');
    }
  }

  Future<List<dynamic>> updateAdminSettings(
      Map<String, dynamic> settings) async {
    try {
      // Check if user has admin privileges
      final user = _client.auth.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // TODO: Implement proper admin role checking
      // For now, we'll allow access but this should be restricted

      // Validate settings
      if (settings['ad_network'] != null &&
          !['admob', 'facebook', 'unity'].contains(settings['ad_network'])) {
        throw Exception('Invalid ad network');
      }

      return await _client.from('admin_settings').upsert(settings).select();
    } catch (e) {
      throw Exception('Failed to update admin settings: $e');
    }
  }

  // Journal entries (online only)
  Future<List<Map<String, dynamic>>> getJournalEntries(String userId) async {
    try {
      if (!Validators.isValidUserId(userId)) {
        throw Exception('Invalid user ID');
      }

      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      final response = await client
          .from('journal_entries')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting journal entries: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> createJournalEntry(
      Map<String, dynamic> entryData) async {
    try {
      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      if (!Validators.isValidUserId(entryData['user_id']?.toString() ?? '')) {
        throw Exception('Invalid user ID');
      }
      if (!Validators.isValidString(entryData['title']?.toString() ?? '',
          maxLength: 200)) {
        throw Exception('Invalid entry title');
      }
      if (!Validators.isValidString(entryData['content']?.toString() ?? '',
          maxLength: 5000)) {
        throw Exception('Invalid entry content');
      }

      var entryId = entryData['id']?.toString().trim();
      if (!Validators.isValidString(entryId)) {
        entryId = _uuid.v4();
      }

      final sanitizedEntryData = {
        'id': entryId,
        'user_id': entryData['user_id'].toString().trim(),
        'title': entryData['title']?.toString().trim() ?? '',
        'content': entryData['content']?.toString().trim() ?? '',
        'mood_rating': entryData['mood_rating'] is int
            ? (entryData['mood_rating'] as int).clamp(1, 5)
            : 3,
        'image_urls':
            entryData['image_urls'] is List ? entryData['image_urls'] : [],
        'audio_url': entryData['audio_url']?.toString() ?? '',
        'date': entryData['date'],
        'word_count': entryData['word_count'],
        'writing_time': entryData['writing_time'],
        'has_photo': entryData['has_photo'] ?? false,
        'created_at':
            entryData['created_at'] ?? DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      }..removeWhere((key, value) => value == null);

      final response = await client
          .from('journal_entries')
          .upsert(sanitizedEntryData)
          .select();

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to create journal entry: $e');
    }
  }

  Future<void> deleteJournalEntry(String entryId) async {
    try {
      if (!Validators.isValidString(entryId)) {
        throw Exception('Invalid entry ID');
      }

      final client = await this.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      await client.from('journal_entries').delete().eq('id', entryId);
    } catch (e) {
      throw Exception('Failed to delete journal entry: $e');
    }
  }

  // Storage operations with file validation
  Future<String> uploadFile(
      String bucket, String path, List<int> fileBytes) async {
    try {
      // Validate bucket name - added sessions-media for video/audio uploads
      if (!['journal_images', 'journal_audio', 'profile_images', 'sessions-media']
          .contains(bucket)) {
        throw Exception('Invalid bucket name: $bucket');
      }

      // Validate file size (max 50MB for sessions-media, 10MB for others)
      final maxSize = bucket == 'sessions-media' ? 50 * 1024 * 1024 : 10 * 1024 * 1024;
      if (fileBytes.length > maxSize) {
        throw Exception('File size too large. Maximum size is ${maxSize ~/ (1024 * 1024)}MB');
      }

      // Validate file path
      if (!Validators.isValidString(path, maxLength: 200)) {
        throw Exception('Invalid file path: $path');
      }

      if (!_isInitialized) {
        throw Exception('Supabase not initialized');
      }

      final uint8List = Uint8List.fromList(fileBytes);

      debugPrint('📤 Attempting upload to bucket: $bucket, path: $path');

      // Determine content type based on file extension
      final extension = path.split('.').last.toLowerCase();
      String contentType = 'application/octet-stream';
      if (['mp4', 'mov', 'avi', 'mkv', 'webm'].contains(extension)) {
        contentType = 'video/$extension';
      } else if (['mp3', 'wav', 'aac', 'm4a', 'ogg'].contains(extension)) {
        contentType = 'audio/$extension';
      } else if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension)) {
        contentType = 'image/$extension';
      }
      debugPrint('📄 Content type: $contentType');

      // Upload file with upsert option to overwrite if exists
      try {
        await _client.storage.from(bucket).uploadBinary(
              path,
              uint8List,
              fileOptions: FileOptions(
                upsert: true,
                contentType: contentType,
              ),
            );
        debugPrint('✅ Upload successful');
      } catch (uploadError) {
        debugPrint('❌ Upload error: $uploadError');
        debugPrint('   Error type: ${uploadError.runtimeType}');

        // Try alternative upload method without FileOptions
        try {
          debugPrint('🔄 Retrying upload without FileOptions...');
          await _client.storage.from(bucket).uploadBinary(path, uint8List);
          debugPrint('✅ Retry upload successful');
        } catch (retryError) {
          debugPrint('❌ Retry upload also failed: $retryError');

          // Check if it's a permission/bucket issue
          if (uploadError.toString().contains('bucket') ||
              uploadError.toString().contains('not found')) {
            throw Exception(
                'Storage bucket "$bucket" not found or not accessible. Please check Supabase configuration.');
          } else if (uploadError.toString().contains('permission') ||
              uploadError.toString().contains('unauthorized') ||
              uploadError.toString().contains('403')) {
            throw Exception(
                'Permission denied. Please check storage bucket permissions in Supabase.');
          } else if (uploadError.toString().contains('duplicate') ||
              uploadError.toString().contains('already exists')) {
            // File already exists, try to delete first or use different path
            throw Exception('File already exists. Please try again.');
          } else {
            throw Exception('Upload failed: ${uploadError.toString()}');
          }
        }
      }

      // Get public URL
      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
      debugPrint('✅ File uploaded successfully. Public URL: $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('❌ Upload file error: $e');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }

  Future<List<int>> downloadFile(String bucket, String path) async {
    try {
      // Validate bucket name
      if (!['journal_images', 'journal_audio', 'profile_images']
          .contains(bucket)) {
        throw Exception('Invalid bucket name');
      }

      // Validate file path
      if (!Validators.isValidString(path, maxLength: 200)) {
        throw Exception('Invalid file path');
      }

      return await _client.storage.from(bucket).download(path);
    } catch (e) {
      throw Exception('Failed to download file: $e');
    }
  }
}

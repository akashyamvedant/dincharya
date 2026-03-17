import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Service for community group chat — WhatsApp-style messaging
/// with real-time delivery and admin controls.
class CommunityService {
  static final CommunityService _instance = CommunityService._internal();
  factory CommunityService() => _instance;
  CommunityService._internal();

  final SupabaseService _supabaseService = SupabaseService();
  RealtimeChannel? _channel;

  /// Load messages, newest last (for chat scroll).
  /// [before] for pagination (load older messages).
  Future<List<Map<String, dynamic>>> loadMessages({
    int limit = 50,
    DateTime? before,
  }) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return [];

      var query = client
          .from('community_messages')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      if (before != null) {
        query = client
            .from('community_messages')
            .select()
            .lt('created_at', before.toIso8601String())
            .order('created_at', ascending: false)
            .limit(limit);
      }

      final data = await query;
      // Reverse so oldest is first (chat order)
      return List<Map<String, dynamic>>.from(data.reversed);
    } catch (e) {
      debugPrint('❌ Error loading messages: $e');
      return [];
    }
  }

  /// Load pinned messages
  Future<List<Map<String, dynamic>>> loadPinnedMessages() async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return [];

      final data = await client
          .from('community_messages')
          .select()
          .eq('is_pinned', true)
          .order('created_at', ascending: false)
          .limit(10);

      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('❌ Error loading pinned messages: $e');
      return [];
    }
  }

  /// Send a new message (with optional media)
  Future<bool> sendMessage(String text, {String? mediaUrl, String? mediaType}) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      final user = _supabaseService.currentUser;
      if (user == null) return false;

      // Get user profile for name and avatar
      final profile = await client
          .from('user_profiles')
          .select('full_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final userName = profile?['full_name'] ??
          user.userMetadata?['full_name'] ??
          user.email?.split('@').first ??
          'User';
      final avatarUrl = profile?['avatar_url'] ??
          user.userMetadata?['avatar_url'];

      final insertData = <String, dynamic>{
        'user_id': user.id,
        'user_name': userName,
        'user_avatar_url': avatarUrl,
        'message': text.trim(),
      };

      if (mediaUrl != null) insertData['media_url'] = mediaUrl;
      if (mediaType != null) insertData['media_type'] = mediaType;

      await client.from('community_messages').insert(insertData);

      return true;
    } catch (e) {
      debugPrint('❌ Error sending message: $e');
      return false;
    }
  }

  /// Upload media file to Supabase storage and return public URL
  Future<String?> uploadMedia(File file, String type) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return null;

      final user = _supabaseService.currentUser;
      if (user == null) return null;

      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${user.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';

      // Determine correct MIME type so Supabase serves it properly
      final mimeTypes = {
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'avi': 'video/x-msvideo',
        '3gp': 'video/3gpp',
        'mkv': 'video/x-matroska',
        'webm': 'video/webm',
      };
      final contentType = mimeTypes[ext] ?? (type == 'video' ? 'video/mp4' : 'image/jpeg');

      await client.storage
          .from('community-media')
          .upload(
            fileName,
            file,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );

      final publicUrl = client.storage
          .from('community-media')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      debugPrint('❌ Error uploading media: $e');
      return null;
    }
  }

  /// Delete a message (own or admin)
  Future<bool> deleteMessage(String messageId) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      await client
          .from('community_messages')
          .delete()
          .eq('id', messageId);

      return true;
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      return false;
    }
  }

  /// Pin/unpin a message (admin only)
  Future<bool> togglePin(String messageId, bool pinned) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      await client
          .from('community_messages')
          .update({'is_pinned': pinned})
          .eq('id', messageId);

      return true;
    } catch (e) {
      debugPrint('❌ Error toggling pin: $e');
      return false;
    }
  }

  /// Check if current user is admin
  Future<bool> isCurrentUserAdmin() async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      final user = _supabaseService.currentUser;
      if (user == null) return false;

      final profile = await client
          .from('user_profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();

      return profile?['is_admin'] == true;
    } catch (e) {
      debugPrint('❌ Error checking admin: $e');
      return false;
    }
  }

  /// Subscribe to new messages in real-time
  void subscribeToMessages({
    required Function(Map<String, dynamic> newMessage) onInsert,
    Function(Map<String, dynamic> oldMessage)? onDelete,
    Function(Map<String, dynamic> updatedMessage)? onUpdate,
  }) {
    try {
      final client = Supabase.instance.client;

      _channel = client
          .channel('community_chat')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'community_messages',
            callback: (payload) {
              onInsert(payload.newRecord);
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: 'community_messages',
            callback: (payload) {
              if (onDelete != null) {
                onDelete(payload.oldRecord);
              }
            },
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'community_messages',
            callback: (payload) {
              if (onUpdate != null) {
                onUpdate(payload.newRecord);
              }
            },
          )
          .subscribe();

      debugPrint('✅ Subscribed to community chat');
    } catch (e) {
      debugPrint('❌ Error subscribing to chat: $e');
    }
  }

  /// Unsubscribe from real-time channel
  void unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
    debugPrint('🔌 Unsubscribed from community chat');
  }
}

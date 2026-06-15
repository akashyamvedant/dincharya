// lib/services/admin_message_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'supabase_service.dart';
import 'subscription_manager.dart';

/// Service to fetch and manage admin-sent in-app messages.
/// Checks for unread messages from `admin_messages` table
/// and tracks read receipts in `admin_message_reads`.
class AdminMessageService {
  static final AdminMessageService _instance = AdminMessageService._internal();
  factory AdminMessageService() => _instance;
  AdminMessageService._internal();

  final SupabaseService _supabaseService = SupabaseService();

  // Minimum interval between API checks per page (30 minutes)
  static const int _checkIntervalMinutes = 30;
  static const String _lastCheckPrefix = 'admin_msg_last_check_';
  static const String _impressionPrefix = 'admin_msg_imp_';

  /// Check for unread messages for a specific page.
  /// [triggerPage] — which page is requesting messages (e.g., 'dashboard', 'guided').
  /// Respects a per-page minimum check interval to avoid hammering the API.
  Future<List<Map<String, dynamic>>> checkForMessages({
    String triggerPage = 'dashboard',
    bool force = false,
  }) async {
    try {
      // Rate limit: skip if this page was checked recently
      if (!force) {
        final prefs = await SharedPreferences.getInstance();
        final lastCheck = prefs.getInt('$_lastCheckPrefix$triggerPage') ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = now - lastCheck;
        if (elapsed < _checkIntervalMinutes * 60 * 1000) {
          debugPrint('📨 Admin messages [$triggerPage]: skipped (checked ${(elapsed / 60000).toStringAsFixed(0)}m ago)');
          return [];
        }
      }

      final client = await _supabaseService.client;
      if (client == null) return [];

      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return [];

      // Fetch active, non-expired, started messages that target this page
      final now = DateTime.now().toUtc().toIso8601String();
      final messages = await client
          .from('admin_messages')
          .select('id, title, message, type, cta_text, cta_url, image_url, '
              'is_active, show_once, max_impressions, priority, '
              'target_audience, trigger_pages, starts_at, expires_at, created_at')
          .eq('is_active', true)
          .or('expires_at.is.null,expires_at.gt.$now')
          .or('starts_at.is.null,starts_at.lte.$now')
          .order('priority', ascending: false)
          .order('created_at', ascending: false);
      // trigger_pages filtering is done client-side since Supabase Dart
      // doesn't support PostgreSQL array overlap operator natively.

      if (messages.isEmpty) {
        _updateLastCheckTime(triggerPage);
        return [];
      }

      // Fetch user's read receipts (for show_once / basic read tracking)
      final readReceipts = await client
          .from('admin_message_reads')
          .select('message_id')
          .eq('user_id', userId);

      final readMessageIds = <String, bool>{};
      for (final r in readReceipts) {
        readMessageIds[r['message_id'] as String] = true;
      }

      // Load local impression counts for max_impressions logic
      final prefs = await SharedPreferences.getInstance();

      // Filter: unread + matching target audience + matching trigger page
      final isPremium = SubscriptionManager().isPremium;
      final unreadMessages = <Map<String, dynamic>>[];

      for (final msg in messages) {
        final msgId = msg['id'] as String;

        // Check trigger page match
        final triggerPages = _parseTriggerPages(msg['trigger_pages']);
        if (!triggerPages.contains(triggerPage) && !triggerPages.contains('any')) {
          continue;
        }

        // Check max impressions (via local counter — not DB row count)
        final maxImpressions = msg['max_impressions'] as int? ?? 1;
        final localImpressions = prefs.getInt('$_impressionPrefix$msgId') ?? 0;
        if (maxImpressions > 0 && localImpressions >= maxImpressions) {
          continue; // User has seen it enough times
        }

        // Legacy show_once check (backward compat)
        if (msg['show_once'] == true && readMessageIds.containsKey(msgId)) {
          continue;
        }

        // Check target audience
        final target = msg['target_audience'] as String? ?? 'all';
        if (target == 'premium' && !isPremium) continue;
        if (target == 'free' && isPremium) continue;
        // 'new_users' and 'all' pass through

        unreadMessages.add(msg);
      }

      _updateLastCheckTime(triggerPage);
      debugPrint('📨 Admin messages [$triggerPage]: ${unreadMessages.length} unread of ${messages.length} total');
      return unreadMessages;
    } catch (e) {
      debugPrint('❌ Error checking admin messages: $e');
      return [];
    }
  }

  /// Parse trigger_pages from DB (handles both List and String formats).
  List<String> _parseTriggerPages(dynamic raw) {
    if (raw is List) {
      return raw.map((e) => e.toString()).toList();
    }
    if (raw is String) {
      // Handle PostgreSQL array format: {dashboard,guided}
      return raw.replaceAll('{', '').replaceAll('}', '').split(',').map((e) => e.trim()).toList();
    }
    return ['dashboard']; // Default fallback
  }

  /// Mark a message as read/dismissed by the current user.
  /// Also increments the local impression counter for max_impressions logic.
  Future<void> markAsRead(String messageId, {bool dismissed = true}) async {
    try {
      // Increment local impression counter (critical for max_impressions)
      final prefs = await SharedPreferences.getInstance();
      final currentCount = prefs.getInt('$_impressionPrefix$messageId') ?? 0;
      await prefs.setInt('$_impressionPrefix$messageId', currentCount + 1);

      final client = await _supabaseService.client;
      if (client == null) return;

      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      await client.from('admin_message_reads').upsert({
        'message_id': messageId,
        'user_id': userId,
        'dismissed': dismissed,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'message_id,user_id');

      debugPrint('✅ Message $messageId marked as read (impression #${currentCount + 1})');
    } catch (e) {
      debugPrint('❌ Error marking message as read: $e');
    }
  }

  /// Mark that user took the action (clicked button) on a message.
  Future<void> markActionTaken(String messageId) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return;

      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      await client.from('admin_message_reads').upsert({
        'message_id': messageId,
        'user_id': userId,
        'action_taken': true,
        'dismissed': true,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'message_id,user_id');

      debugPrint('✅ Message $messageId action taken');
    } catch (e) {
      debugPrint('❌ Error marking action: $e');
    }
  }

  // --- ADMIN METHODS ---

  /// Create a new admin message (admin only).
  Future<bool> createMessage(Map<String, dynamic> messageData) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      final userId = _supabaseService.currentUser?.id;
      messageData['created_by'] = userId;
      messageData['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await client.from('admin_messages').insert(messageData);
      debugPrint('✅ Admin message created');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating message: $e');
      return false;
    }
  }

  /// Update an existing admin message (admin only).
  Future<bool> updateMessage(String messageId, Map<String, dynamic> updates) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await client
          .from('admin_messages')
          .update(updates)
          .eq('id', messageId);

      debugPrint('✅ Admin message $messageId updated');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating message: $e');
      return false;
    }
  }

  /// Duplicate an existing message as a new paused campaign.
  Future<bool> duplicateMessage(String messageId) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      final userId = _supabaseService.currentUser?.id;

      // Fetch original message
      final original = await client
          .from('admin_messages')
          .select('title, message, type, cta_text, cta_url, image_url, '
              'show_once, max_impressions, priority, '
              'target_audience, trigger_pages')
          .eq('id', messageId)
          .single();

      // Create copy with new metadata
      final copy = Map<String, dynamic>.from(original);
      copy.remove('id'); // Let DB generate new ID
      copy['title'] = '${copy['title']} (Copy)';
      copy['is_active'] = false; // Start as paused
      copy['created_by'] = userId;
      copy['created_at'] = DateTime.now().toUtc().toIso8601String();
      copy['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await client.from('admin_messages').insert(copy);
      debugPrint('✅ Message $messageId duplicated');
      return true;
    } catch (e) {
      debugPrint('❌ Error duplicating message: $e');
      return false;
    }
  }

  /// Fetch all messages (admin view with read stats).
  Future<List<Map<String, dynamic>>> getAllMessages() async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return [];

      final messages = await client
          .from('admin_messages')
          .select('id, title, message, type, cta_text, cta_url, image_url, '
              'is_active, show_once, max_impressions, priority, '
              'target_audience, trigger_pages, starts_at, expires_at, '
              'created_by, created_at, updated_at')
          .order('created_at', ascending: false);

      if (messages.isEmpty) return [];

      // Batch fetch all read receipts at once (1 query instead of 2N)
      final allMessageIds = messages.map((m) => m['id'] as String).toList();
      final allReads = await client
          .from('admin_message_reads')
          .select('message_id, action_taken')
          .inFilter('message_id', allMessageIds);

      // Count reads and actions per message
      final readCounts = <String, int>{};
      final actionCounts = <String, int>{};
      for (final read in allReads) {
        final msgId = read['message_id'] as String;
        readCounts[msgId] = (readCounts[msgId] ?? 0) + 1;
        if (read['action_taken'] == true) {
          actionCounts[msgId] = (actionCounts[msgId] ?? 0) + 1;
        }
      }

      // Attach counts to messages
      for (int i = 0; i < messages.length; i++) {
        final msgId = messages[i]['id'] as String;
        messages[i]['read_count'] = readCounts[msgId] ?? 0;
        messages[i]['action_count'] = actionCounts[msgId] ?? 0;
      }

      return List<Map<String, dynamic>>.from(messages);
    } catch (e) {
      debugPrint('❌ Error fetching all messages: $e');
      return [];
    }
  }

  /// Toggle message active status.
  Future<bool> toggleActive(String messageId, bool isActive) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      await client
          .from('admin_messages')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', messageId);
      return true;
    } catch (e) {
      debugPrint('❌ Error toggling message: $e');
      return false;
    }
  }

  /// Delete a message.
  Future<bool> deleteMessage(String messageId) async {
    try {
      final client = await _supabaseService.client;
      if (client == null) return false;

      await client.from('admin_messages').delete().eq('id', messageId);
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting message: $e');
      return false;
    }
  }

  Future<void> _updateLastCheckTime(String triggerPage) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_lastCheckPrefix$triggerPage', DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('⚠️ Failed to save last check time: $e');
    }
  }
}

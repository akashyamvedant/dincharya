import 'package:flutter/foundation.dart';

/// Service to handle notification deep linking and task highlighting
/// When user taps a notification, this service manages which task should be highlighted
class NotificationDeepLinkService {
  static final NotificationDeepLinkService _instance = NotificationDeepLinkService._internal();
  factory NotificationDeepLinkService() => _instance;
  NotificationDeepLinkService._internal();

  /// ValueNotifier that holds the currently highlighted task ID
  /// Dashboard listens to this and highlights the matching task
  final ValueNotifier<String?> highlightedTaskId = ValueNotifier<String?>(null);
  
  /// Duration for which the task should remain highlighted
  /// Increased to 8 seconds to account for task loading time
  static const Duration highlightDuration = Duration(seconds: 8);

  /// Set a task to be highlighted
  /// The highlight will automatically clear after [highlightDuration]
  void setHighlightedTask(String taskId) {
    debugPrint('🔦 Highlighting task: $taskId');
    highlightedTaskId.value = taskId;
    
    // Auto-clear highlight after specified duration
    Future.delayed(highlightDuration, () {
      if (highlightedTaskId.value == taskId) {
        debugPrint('🔦 Clearing highlight for task: $taskId');
        highlightedTaskId.value = null;
      }
    });
  }

  /// Clear the highlighted task immediately
  void clearHighlight() {
    highlightedTaskId.value = null;
  }

  /// Parse notification payload and extract task ID
  /// Payload format: "task_id:<uuid>"
  String? parseTaskIdFromPayload(String? payload) {
    if (payload == null || payload.isEmpty) return null;
    
    if (payload.startsWith('task_id:')) {
      return payload.replaceFirst('task_id:', '');
    }
    
    // Try JSON format as fallback
    try {
      if (payload.contains('"task_id"')) {
        // Simple extraction for {"task_id": "..."}
        final match = RegExp(r'"task_id"\s*:\s*"([^"]+)"').firstMatch(payload);
        return match?.group(1);
      }
    } catch (e) {
      debugPrint('Error parsing notification payload: $e');
    }
    
    return null;
  }
}

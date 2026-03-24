import 'package:flutter/foundation.dart';

/// Service to handle notification deep linking and task highlighting.
/// When user taps a task notification, this service:
/// 1. Navigates to the Routine tab
/// 2. Waits for tasks to load
/// 3. Scrolls to + highlights the target task
class NotificationDeepLinkService {
  static final NotificationDeepLinkService _instance = NotificationDeepLinkService._internal();
  factory NotificationDeepLinkService() => _instance;
  NotificationDeepLinkService._internal();

  /// ValueNotifier that holds the currently highlighted task ID
  /// Dashboard listens to this and highlights the matching task
  final ValueNotifier<String?> highlightedTaskId = ValueNotifier<String?>(null);
  
  /// ValueNotifier that triggers navigation to the Routine tab
  /// Dashboard listens to this and switches to tab index 0
  final ValueNotifier<bool> navigateToRoutineTab = ValueNotifier<bool>(false);
  
  /// Pending task ID — set when notification tap fires before dashboard is ready.
  /// Dashboard checks this on initState and after tasks load.
  String? _pendingTaskId;
  String? get pendingTaskId => _pendingTaskId;
  
  /// Duration for which the task should remain highlighted.
  /// Must be longer than: Supabase load time (1-5s) + scroll retry window (5s)
  /// + render time (0.5s) to avoid race condition where highlight clears mid-scroll.
  static const Duration highlightDuration = Duration(seconds: 15);

  /// Set a task to be highlighted.
  /// Also triggers navigation to Routine tab.
  void setHighlightedTask(String taskId) {
    debugPrint('🔦 Deep link: Highlighting task: $taskId');
    
    // Store as pending in case dashboard isn't ready yet
    _pendingTaskId = taskId;
    
    // Trigger navigation to Routine tab
    navigateToRoutineTab.value = true;
    // Reset after triggering (so it can fire again next time)
    Future.microtask(() => navigateToRoutineTab.value = false);
    
    // Set highlighted task
    highlightedTaskId.value = taskId;
    
    // Auto-clear highlight after specified duration
    Future.delayed(highlightDuration, () {
      if (highlightedTaskId.value == taskId) {
        debugPrint('🔦 Deep link: Clearing highlight for task: $taskId');
        highlightedTaskId.value = null;
      }
    });
  }
  
  /// Consume the pending task ID (called after successful scroll)
  void consumePendingTask() {
    _pendingTaskId = null;
  }

  /// Clear the highlighted task immediately
  void clearHighlight() {
    highlightedTaskId.value = null;
    _pendingTaskId = null;
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

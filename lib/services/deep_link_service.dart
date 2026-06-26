import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import './supabase_service.dart';
import '../presentation/guided_sessions_hub/widgets/session_preview_sheet.dart';

/// Service to handle Android App Links (deep links) for session sharing.
///
/// Flow:
/// 1. User shares a session → generates `https://dincharya.app/session/{uuid}`
/// 2. Receiver clicks the link → Android verifies the domain → opens the app
/// 3. This service parses the URI, fetches session data from Supabase,
///    and navigates to the MediaPlayerScreen.
///
/// Handles both:
/// - **Cold start**: App was not running, link launches it
/// - **Warm resume**: App is already open, link brings it to foreground
///
/// Official Docs:
/// - https://developer.android.com/training/app-links
/// - https://pub.dev/packages/app_links
class DeepLinkService {
  static final DeepLinkService _instance = DeepLinkService._internal();
  factory DeepLinkService() => _instance;
  DeepLinkService._internal();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  GlobalKey<NavigatorState>? _navigatorKey;

  /// The base URL used for shareable session links
  static const String baseUrl = 'https://dincharya.app';

  /// Whether the service has been initialized
  bool _initialized = false;

  /// Initialize the deep link service.
  /// Must be called AFTER the navigator is ready (i.e., after first frame).
  /// [navigatorKey] is the global navigator key from main.dart.
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;
    _appLinks = AppLinks();
    _initialized = true;

    // Handle the initial link that launched the app (cold start)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        debugPrint('🔗 Deep link (cold start): $initialUri');
        // Delay to ensure navigator is ready after splash → dashboard transition
        Future.delayed(const Duration(seconds: 2), () {
          _handleDeepLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error getting initial deep link: $e');
    }

    // Listen for links while app is already running (warm resume)
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (Uri uri) {
        debugPrint('🔗 Deep link (warm): $uri');
        _handleDeepLink(uri);
      },
      onError: (err) {
        debugPrint('⚠️ Deep link stream error: $err');
      },
    );

    debugPrint('✅ DeepLinkService initialized');
  }

  /// Parse incoming URI and navigate to the appropriate screen.
  ///
  /// Supported formats:
  /// - `https://dincharya.app/session/{uuid}` → opens session in MediaPlayer
  void _handleDeepLink(Uri uri) {
    // Only handle our domain
    if (uri.host != 'dincharya.app') {
      debugPrint('⚠️ Unknown deep link host: ${uri.host}');
      return;
    }

    // Route: /session/{uuid}
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'session') {
      final sessionId = uri.pathSegments[1];
      _openSessionById(sessionId);
      return;
    }

    debugPrint('⚠️ Unrecognized deep link path: ${uri.path}');
  }

  /// Fetch session from Supabase by UUID and navigate to GuidedSessionsHub.
  /// Shows a preview sheet for the shared session so the user can decide
  /// whether to start it — instead of auto-playing.
  Future<void> _openSessionById(String sessionId) async {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      debugPrint('❌ Navigator not available for deep link');
      return;
    }

    debugPrint('🔗 Opening session via deep link: $sessionId');

    // Show a loading indicator while fetching
    _showLoadingDialog(navigator);

    try {
      final supabase = SupabaseService();
      final client = await supabase.client;
      if (client == null) {
        _dismissLoadingDialog(navigator);
        _showErrorSnackBar(navigator, 'Unable to connect. Please try again.');
        return;
      }

      // Fetch session data
      final response = await client
          .from('sessions')
          .select('id, title, title_hindi, description, category, difficulty, duration, '
              'media_type, media_url, youtube_url, video_url, audio_url, '
              'thumbnail_url, instructor_name, is_premium, tags, view_count')
          .eq('id', sessionId)
          .eq('is_active', true)
          .maybeSingle();

      _dismissLoadingDialog(navigator);

      if (response == null) {
        _showErrorSnackBar(navigator, 'This session is no longer available.');
        return;
      }

      final session = Map<String, dynamic>.from(response);
      debugPrint('✅ Deep link: Session found — "${session['title']}"');

      // Navigate to Guided Sessions Hub (the sessions list)
      navigator.pushNamed('/guided-sessions-hub');

      // After a brief delay (to let the hub build), show the session preview sheet
      Future.delayed(const Duration(milliseconds: 600), () {
        final context = navigator.context;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          builder: (sheetContext) => SessionPreviewSheet(
            session: session,
            onStart: () {
              Navigator.pop(sheetContext);
              navigator.pushNamed('/media-player', arguments: session);
            },
            onToggleFavorite: () {
              // Favorite toggle — handled by hub's state, just close sheet
              Navigator.pop(sheetContext);
            },
            isFavorite: false,
          ),
        );
      });
    } catch (e) {
      debugPrint('❌ Deep link session fetch error: $e');
      _dismissLoadingDialog(navigator);
      _showErrorSnackBar(navigator, 'Could not load session. Please try again.');
    }
  }

  /// Generate a shareable link for a session.
  /// Returns a URL string like: `https://dincharya.app/session/{uuid}`
  static String generateSessionLink(Map<String, dynamic> session) {
    final sessionId = session['id']?.toString() ?? '';
    return '$baseUrl/session/$sessionId';
  }

  /// Generate share text with session details + link
  static String generateShareText(Map<String, dynamic> session) {
    final title = session['title'] ?? 'Session';
    final description = session['description'] ?? '';
    final category = (session['category'] ?? 'meditation').toString();
    final duration = session['duration'];
    final durationMin = duration is int ? (duration / 60).round() : 10;
    final link = generateSessionLink(session);

    final emoji = _getCategoryEmoji(category);

    return '$emoji $title — $durationMin min\n'
        '$description\n\n'
        'Try this session on Dincharya:\n'
        '$link';
  }

  static String _getCategoryEmoji(String category) {
    switch (category) {
      case 'yoga':
        return '🧘';
      case 'pranayama':
        return '🌬️';
      case 'meditation':
        return '🧘‍♂️';
      default:
        return '✨';
    }
  }

  // ── UI Helpers ──

  void _showLoadingDialog(NavigatorState navigator) {
    showDialog(
      context: navigator.context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Opening session...',
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dismissLoadingDialog(NavigatorState navigator) {
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  void _showErrorSnackBar(NavigatorState navigator, String message) {
    final context = navigator.context;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Browse',
          textColor: Colors.white,
          onPressed: () {
            navigator.pushNamed('/guided-sessions-hub');
          },
        ),
      ),
    );
  }

  /// Clean up resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}

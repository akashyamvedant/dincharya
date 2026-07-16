import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to handle Android App Links (deep links) for session sharing.
///
/// Flow:
/// 1. User shares a session → generates `https://dincharya.app/session/{uuid}`
/// 2. Receiver clicks the link → Android verifies the domain → opens the app
/// 3. This service parses the URI, navigates to GuidedSessionsHub,
///    and highlights the shared session card in the list.
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

  /// Pending deep link URI to process after app is ready
  Uri? _pendingDeepLink;

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
        _pendingDeepLink = initialUri;
        // Wait for navigator to be fully ready with the dashboard route
        _waitForNavigatorAndProcess();
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

  /// Wait until the navigator has a valid route (dashboard loaded)
  /// before processing the pending deep link.
  void _waitForNavigatorAndProcess() {
    int attempts = 0;
    Timer.periodic(const Duration(milliseconds: 300), (timer) {
      attempts++;
      final navigator = _navigatorKey?.currentState;

      if (navigator != null && navigator.canPop() == false && attempts > 3) {
        timer.cancel();
        if (_pendingDeepLink != null) {
          debugPrint('🔗 Navigator ready after ${attempts * 300}ms — processing deep link');
          _handleDeepLink(_pendingDeepLink!);
          _pendingDeepLink = null;
        }
      } else if (navigator != null && attempts > 5) {
        timer.cancel();
        if (_pendingDeepLink != null) {
          debugPrint('🔗 Fallback: processing deep link after ${attempts * 300}ms');
          _handleDeepLink(_pendingDeepLink!);
          _pendingDeepLink = null;
        }
      } else if (attempts > 20) {
        timer.cancel();
        debugPrint('❌ Deep link timeout: navigator not ready after 6s');
      }
    });
  }

  /// Parse incoming URI and navigate to the appropriate screen.
  void _handleDeepLink(Uri uri) {
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

    // Route: /challenge/{uuid}
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'challenge') {
      final challengeId = uri.pathSegments[1];
      _openChallengeById(challengeId);
      return;
    }

    // Route: /circle/{code}
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'circle') {
      final inviteCode = uri.pathSegments[1];
      _openCircleByInviteCode(inviteCode);
      return;
    }

    debugPrint('⚠️ Unrecognized deep link path: ${uri.path}');
  }

  /// Navigate to GuidedSessionsHub with the session ID to highlight.
  /// The hub will auto-switch to the correct tab and highlight the card.
  void _openSessionById(String sessionId) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      debugPrint('❌ Navigator not available for deep link');
      return;
    }

    debugPrint('🔗 Opening session via deep link: $sessionId');

    try {
      // Pop all routes back to root first
      navigator.popUntil((route) => route.isFirst);

      // Navigate to GuidedSessionsHub with session ID to highlight
      navigator.pushNamed(
        '/guided-sessions-hub',
        arguments: {'highlightSessionId': sessionId},
      );

      debugPrint('✅ Deep link: Navigated to hub with highlight for $sessionId');
    } catch (e) {
      debugPrint('⚠️ Deep link navigation error: $e');
      try {
        navigator.pushNamed(
          '/guided-sessions-hub',
          arguments: {'highlightSessionId': sessionId},
        );
      } catch (e2) {
        debugPrint('❌ Deep link fallback also failed: $e2');
      }
    }
  }

  /// Navigate to ChallengeDetailScreen with the challenge ID.
  void _openChallengeById(String challengeId) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      debugPrint('❌ Navigator not available for challenge deep link');
      return;
    }

    debugPrint('🔗 Opening challenge via deep link: $challengeId');

    try {
      navigator.popUntil((route) => route.isFirst);
      navigator.pushNamed(
        '/tapasya/challenge',
        arguments: {'id': challengeId},
      );
      debugPrint('✅ Deep link: Navigated to challenge $challengeId');
    } catch (e) {
      debugPrint('⚠️ Challenge deep link navigation error: $e');
    }
  }

  /// Navigate to TapasyaHub with circle invite code to auto-join.
  void _openCircleByInviteCode(String inviteCode) {
    final navigator = _navigatorKey?.currentState;
    if (navigator == null) {
      debugPrint('❌ Navigator not available for circle deep link');
      return;
    }

    debugPrint('🔗 Opening circle via deep link: $inviteCode');

    try {
      navigator.popUntil((route) => route.isFirst);
      navigator.pushNamed(
        '/tapasya',
        arguments: {'joinCircleInviteCode': inviteCode},
      );
      debugPrint('✅ Deep link: Navigated to tapasya hub with circle invite $inviteCode');
    } catch (e) {
      debugPrint('⚠️ Circle deep link navigation error: $e');
    }
  }

  /// Generate a shareable link for a session.
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
        '"$description"\n\n'
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

  /// Clean up resources
  void dispose() {
    _linkSubscription?.cancel();
  }
}

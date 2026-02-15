import 'package:flutter/material.dart';

// Conditional import for web
import 'media_player_web.dart' if (dart.library.io) 'media_player_mobile.dart';

/// Media Player Screen - supports YouTube, Video, and Audio
class MediaPlayerScreen extends StatelessWidget {
  final Map<String, dynamic> session;

  const MediaPlayerScreen({
    super.key,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    // Use platform-specific implementation
    return MediaPlayerPlatformWidget(session: session);
  }
}

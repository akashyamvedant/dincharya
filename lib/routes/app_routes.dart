// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/onboarding_flow/onboarding_flow.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/routine_dashboard/routine_dashboard.dart';
import '../presentation/routine_builder/routine_builder.dart';
import '../presentation/guided_sessions_hub/guided_sessions_hub.dart';
import '../presentation/journal_mood_tracker/journal_mood_tracker.dart';
import '../presentation/profile_settings/profile_settings.dart';
import '../presentation/profile_settings/edit_profile_screen.dart';
import '../presentation/audio_player/audio_player.dart';
import '../presentation/payment/payment_plans_screen.dart';
import '../presentation/admin_control_panel/admin_control_panel.dart';
import '../presentation/local_tasks/local_tasks_screen.dart';
import '../presentation/enhanced_profile/enhanced_profile_screen.dart';
import '../presentation/enhanced_journal/enhanced_journal_screen.dart';
import '../presentation/profile_selection/profile_selection_screen.dart';
import '../presentation/history/history_screen.dart';
import '../presentation/media_player/media_player_screen.dart';
import '../presentation/sessions_admin/sessions_admin_screen.dart';
import '../presentation/admin_messages/send_message_screen.dart';
import '../presentation/support/help_center_screen.dart';
import '../presentation/support/contact_support_screen.dart';
import '../presentation/support/my_tickets_screen.dart';
import '../presentation/support/ticket_detail_screen.dart';
import '../presentation/meditation_timer/meditation_timer_screen.dart';
import '../presentation/breathing_exercise/breathing_exercise_screen.dart';
import '../presentation/soundscape/soundscape_screen.dart';
import '../presentation/session_history/session_history_screen.dart';
import '../presentation/program_detail/program_detail_screen.dart';
import '../presentation/ai_guide/ai_guide_screen.dart';
import '../presentation/community/community_chat_screen.dart';
import '../presentation/alarm_ring/alarm_ring_screen.dart';
import '../presentation/tapasya/tapasya_hub.dart';
import '../presentation/tapasya/create_challenge_screen.dart';
import '../presentation/tapasya/challenge_detail_screen.dart';
import '../presentation/tapasya/badges_gallery_screen.dart';
import '../presentation/tapasya/community_challenges_screen.dart';
import '../presentation/tapasya/create_circle_screen.dart';
import '../presentation/tapasya/circle_detail_screen.dart';
import '../presentation/tapasya/live_room_screen.dart';
import '../presentation/tapasya/live_summary_screen.dart';

class AppRoutes {
  static const String splashScreen = '/splash-screen';
  static const String onboardingFlow = '/onboarding-flow';
  static const String authenticationScreen = '/authentication-screen';
  static const String routineDashboard = '/routine-dashboard';
  static const String routineBuilder = '/routine-builder';
  static const String guidedSessionsHub = '/guided-sessions-hub';
  static const String journalMoodTracker = '/journal-mood-tracker';
  static const String enhancedJournal = '/enhanced-journal';
  static const String profileSettings = '/profile-settings';
  static const String editProfile = '/edit-profile';
  static const String enhancedProfile = '/enhanced-profile';
  static const String audioPlayer = '/audio-player';
  static const String paymentPlans = '/payment-plans';
  static const String adminControlPanel = '/admin-control-panel';
  static const String localTasks = '/local-tasks';
  static const String profileSelection = '/profile-selection';
  static const String history = '/history';
  static const String mediaPlayer = '/media-player';
  static const String sessionsAdmin = '/sessions-admin';
  static const String helpCenter = '/help-center';
  static const String contactSupport = '/contact-support';
  static const String meditationTimer = '/meditation-timer';
  static const String breathingExercise = '/breathing-exercise';
  static const String soundscape = '/soundscape';
  static const String sessionHistory = '/session-history';
  static const String programDetail = '/program-detail';
  static const String aiGuide = '/ai-guide';
  static const String myTickets = '/my-tickets';
  static const String ticketDetail = '/ticket-detail';
  static const String community = '/community';
  static const String alarmRing = '/alarm-ring';
  static const String adminMessages = '/admin-messages';

  // Tapasya routes
  static const String tapasyaHub = '/tapasya';
  static const String createChallenge = '/tapasya/create-challenge';
  static const String challengeDetail = '/tapasya/challenge';
  static const String badgesGallery = '/tapasya/badges';
  static const String communityChallenge = '/tapasya/community';
  static const String createCircle = '/tapasya/create-circle';
  static const String circleDetail = '/tapasya/circle';
  static const String liveRoom = '/tapasya/live-room';
  static const String liveSummary = '/tapasya/live-summary';

  static Map<String, WidgetBuilder> get routes => {
        splashScreen: (context) => const SplashScreen(),
        onboardingFlow: (context) => const OnboardingFlow(),
        authenticationScreen: (context) => const AuthenticationScreen(),
        routineDashboard: (context) => const RoutineDashboard(),
        routineBuilder: (context) => const RoutineBuilder(),
        guidedSessionsHub: (context) => const GuidedSessionsHub(),
        journalMoodTracker: (context) => const JournalMoodTracker(),
        enhancedJournal: (context) => const EnhancedJournalScreen(),
        profileSettings: (context) => const ProfileSettings(),
        editProfile: (context) => const EditProfileScreen(),
        enhancedProfile: (context) => const EnhancedProfileScreen(),
        audioPlayer: (context) => const AudioPlayer(),
        adminControlPanel: (context) => const AdminControlPanel(),
        localTasks: (context) => const LocalTasksScreen(),
        profileSelection: (context) => const ProfileSelectionScreen(isOnboarding: true),
        history: (context) => const HistoryScreen(),
        sessionsAdmin: (context) => const SessionsAdminScreen(),
        helpCenter: (context) => const HelpCenterScreen(),
        contactSupport: (context) => const ContactSupportScreen(),
        myTickets: (context) => const MyTicketsScreen(),
        meditationTimer: (context) => const MeditationTimerScreen(),
        breathingExercise: (context) => const BreathingExerciseScreen(),
        soundscape: (context) => const SoundscapeScreen(),
        sessionHistory: (context) => const SessionHistoryScreen(),
        aiGuide: (context) => const AiGuideScreen(),
        community: (context) => const CommunityChatScreen(),
        adminMessages: (context) => const SendMessageScreen(),
        tapasyaHub: (context) => const TapasyaHub(),
        createChallenge: (context) => const CreateChallengeScreen(),
        badgesGallery: (context) => const BadgesGalleryScreen(),
        communityChallenge: (context) => const CommunityChallengesScreen(),
        createCircle: (context) => const CreateCircleScreen(),
        circleDetail: (context) => const CircleDetailScreen(),
        liveRoom: (context) => const LiveRoomScreen(),
        liveSummary: (context) => const LiveSummaryScreen(),
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    // ── Deep link handling ──
    // Android may pass the full URL or just the path as the route name.
    // Extract the path portion to handle both cases.
    final routeName = settings.name ?? '';
    String pathToMatch = routeName;

    // If the route is a full URL, extract just the path
    if (routeName.startsWith('http://') || routeName.startsWith('https://')) {
      try {
        final uri = Uri.parse(routeName);
        pathToMatch = uri.path;
        debugPrint('🔗 onGenerateRoute: Extracted path "$pathToMatch" from URL "$routeName"');
      } catch (_) {}
    }

    // ── Deep link route: /session/{uuid} ──
    if (pathToMatch.startsWith('/session/')) {
      final sessionId = pathToMatch.substring('/session/'.length);
      if (sessionId.isNotEmpty) {
        debugPrint('🔗 onGenerateRoute: Intercepted session deep link → $sessionId');
        return MaterialPageRoute(
          settings: RouteSettings(
            name: guidedSessionsHub,
            arguments: {'highlightSessionId': sessionId},
          ),
          builder: (context) => const GuidedSessionsHub(),
        );
      }
    }

    // ── Deep link route: /challenge/{uuid} ──
    if (pathToMatch.startsWith('/challenge/')) {
      final challengeId = pathToMatch.substring('/challenge/'.length);
      if (challengeId.isNotEmpty) {
        debugPrint('🔗 onGenerateRoute: Intercepted challenge deep link → $challengeId');
        return MaterialPageRoute(
          settings: RouteSettings(
            name: challengeDetail,
            arguments: {'id': challengeId},
          ),
          builder: (context) => const ChallengeDetailScreen(),
        );
      }
    }

    // ── Deep link route: /circle/{code} ──
    if (pathToMatch.startsWith('/circle/')) {
      final inviteCode = pathToMatch.substring('/circle/'.length);
      if (inviteCode.isNotEmpty) {
        debugPrint('🔗 onGenerateRoute: Intercepted circle deep link → $inviteCode');
        return MaterialPageRoute(
          settings: RouteSettings(
            name: tapasyaHub,
            arguments: {'joinCircleInviteCode': inviteCode},
          ),
          builder: (context) => const TapasyaHub(),
        );
      }
    }

    switch (settings.name) {
      // Tapasya circle detail (accepts arguments)
      case circleDetail:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const CircleDetailScreen(),
        );
      // Tapasya challenge detail (accepts arguments)
      case challengeDetail:
        return MaterialPageRoute(
          settings: settings,
          builder: (context) => const ChallengeDetailScreen(),
        );
      case alarmRing:
        final payload = settings.arguments as String?;
        if (payload != null) {
          return MaterialPageRoute(
            builder: (context) => AlarmRingScreen.fromPayload(payload),
          );
        }
        return MaterialPageRoute(
          builder: (context) => const AlarmRingScreen(
            taskId: '',
            taskTitle: 'Wake Up',
          ),
        );
      case paymentPlans:
        final userData = settings.arguments as Map<String, dynamic>?;
        if (userData != null) {
          return MaterialPageRoute(
            builder: (context) => PaymentPlansScreen(userData: userData),
          );
        }
        break;
      case mediaPlayer:
        final session = settings.arguments as Map<String, dynamic>?;
        if (session != null) {
          return MaterialPageRoute(
            builder: (context) => MediaPlayerScreen(session: session),
          );
        }
        break;
      case programDetail:
        final args = settings.arguments as Map<String, dynamic>?;
        if (args != null) {
          return MaterialPageRoute(
            builder: (context) => ProgramDetailScreen(
              program: args['program'] as Map<String, dynamic>,
              enrollment: args['enrollment'] as Map<String, dynamic>?,
            ),
          );
        }
        break;
      case ticketDetail:
        final ticket = settings.arguments as Map<String, dynamic>?;
        if (ticket != null) {
          return MaterialPageRoute(
            builder: (context) => TicketDetailScreen(ticket: ticket),
          );
        }
        break;
    }
    return null;
  }
}

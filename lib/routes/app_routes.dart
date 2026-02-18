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
      };

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
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

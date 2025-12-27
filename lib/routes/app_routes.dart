// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import '../presentation/splash_screen/splash_screen.dart';
import '../presentation/onboarding_flow/onboarding_flow.dart';
import '../presentation/authentication_screen/authentication_screen.dart';
import '../presentation/routine_dashboard/routine_dashboard.dart';
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

class AppRoutes {
  static const String splashScreen = '/splash-screen';
  static const String onboardingFlow = '/onboarding-flow';
  static const String authenticationScreen = '/authentication-screen';
  static const String routineDashboard = '/routine-dashboard';
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

  static Map<String, WidgetBuilder> get routes => {
        splashScreen: (context) => const SplashScreen(),
        onboardingFlow: (context) => const OnboardingFlow(),
        authenticationScreen: (context) => const AuthenticationScreen(),
        routineDashboard: (context) => const RoutineDashboard(),
        guidedSessionsHub: (context) => const GuidedSessionsHub(),
        journalMoodTracker: (context) => const JournalMoodTracker(),
        enhancedJournal: (context) => const EnhancedJournalScreen(),
        profileSettings: (context) => const ProfileSettings(),
        editProfile: (context) => const EditProfileScreen(),
        enhancedProfile: (context) => const EnhancedProfileScreen(),
        audioPlayer: (context) => const AudioPlayer(),
        adminControlPanel: (context) => const AdminControlPanel(),
        localTasks: (context) => const LocalTasksScreen(),
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
    }
    return null;
  }
}

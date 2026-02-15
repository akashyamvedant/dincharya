import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

/// Service to manage app tour for new users
/// Shows interactive tour highlighting key features only for first-time users
class AppTourService {
  static final AppTourService _instance = AppTourService._internal();
  factory AppTourService() => _instance;
  AppTourService._internal();

  static const String _tourShownKey = 'app_tour_shown_v1';
  
  TutorialCoachMark? _tutorialCoachMark;
  bool _isTourShowing = false;

  /// Check if tour should be shown (first-time user)
  Future<bool> shouldShowTour() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_tourShownKey) ?? false);
  }

  /// Mark tour as shown (won't show again)
  Future<void> markTourShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_tourShownKey, true);
    debugPrint('📚 App tour marked as shown');
  }

  /// Reset tour (for testing - show tour again)
  Future<void> resetTour() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tourShownKey);
    debugPrint('📚 App tour reset');
  }

  /// Create tour targets for the main dashboard
  List<TargetFocus> createTourTargets({
    required GlobalKey progressSummaryKey,
    required GlobalKey addTaskFabKey,
    required GlobalKey? firstTaskCardKey,
    required GlobalKey bottomNavKey,
  }) {
    final targets = <TargetFocus>[];

    // 1. Welcome / Progress Summary
    targets.add(
      TargetFocus(
        identify: 'progress_summary',
        keyTarget: progressSummaryKey,
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.emoji_events,
                title: 'Welcome to Dincharya! 🙏',
                description: 'Track your daily streak and progress here. Complete all tasks to build your streak!',
                stepNumber: 1,
                totalSteps: 5,
                onNext: controller.next,
                onSkip: controller.skip,
              );
            },
          ),
        ],
      ),
    );

    // 2. First Task Card (if exists)
    if (firstTaskCardKey != null) {
      targets.add(
        TargetFocus(
          identify: 'task_card',
          keyTarget: firstTaskCardKey,
          alignSkip: Alignment.bottomRight,
          enableOverlayTab: true,
          shape: ShapeLightFocus.RRect,
          radius: 12,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              builder: (context, controller) {
                return _buildTourContent(
                  icon: Icons.check_circle_outline,
                  title: 'Your Tasks 📋',
                  description: 'Tap to complete tasks. Swipe right for quick actions, swipe left to delete.',
                  stepNumber: 2,
                  totalSteps: 5,
                  onNext: controller.next,
                  onSkip: controller.skip,
                );
              },
            ),
          ],
        ),
      );
    }

    // 3. Add Task FAB
    targets.add(
      TargetFocus(
        identify: 'add_task_fab',
        keyTarget: addTaskFabKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.add_circle,
                title: 'Add New Tasks ➕',
                description: 'Tap here to add new tasks to your daily routine.',
                stepNumber: firstTaskCardKey != null ? 3 : 2,
                totalSteps: 5,
                onNext: controller.next,
                onSkip: controller.skip,
              );
            },
          ),
        ],
      ),
    );

    // 4. Bottom Navigation
    targets.add(
      TargetFocus(
        identify: 'bottom_nav',
        keyTarget: bottomNavKey,
        alignSkip: Alignment.topRight,
        enableOverlayTab: true,
        shape: ShapeLightFocus.RRect,
        radius: 0,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTourContent(
                icon: Icons.apps,
                title: 'Explore Features 🧭',
                description: '''
• Routine: Your daily tasks
• Guided: Meditation & yoga sessions  
• Journal: Daily reflections & mood
• Me: Profile & settings''',
                stepNumber: firstTaskCardKey != null ? 4 : 3,
                totalSteps: 5,
                onNext: controller.next,
                onSkip: controller.skip,
              );
            },
          ),
        ],
      ),
    );

    // 5. Final - Ready to go!
    targets.add(
      TargetFocus(
        identify: 'final',
        keyTarget: progressSummaryKey,
        alignSkip: Alignment.bottomRight,
        enableOverlayTab: true,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildFinalContent(
                onFinish: controller.next,
              );
            },
          ),
        ],
      ),
    );

    return targets;
  }

  /// Build consistent tour content widget
  Widget _buildTourContent({
    required IconData icon,
    required String title,
    required String description,
    required int stepNumber,
    required int totalSteps,
    required VoidCallback onNext,
    required VoidCallback onSkip,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B35).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Step $stepNumber of $totalSteps',
                  style: const TextStyle(
                    color: Color(0xFFFF6B35),
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              Icon(icon, color: const Color(0xFFFF6B35), size: 28),
            ],
          ),
          const SizedBox(height: 16),
          
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          
          // Description
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          
          // Buttons
          Row(
            children: [
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip Tour',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: onNext,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF6B35),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Next', style: TextStyle(fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Build final completion content
  Widget _buildFinalContent({required VoidCallback onFinish}) {
    return Container(
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF6B35), Color(0xFFFF8F5C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF6B35).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.celebration,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'You\'re All Set! 🎉',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Start building healthy habits today.\nComplete your tasks and watch your streak grow!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFFFF6B35),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'Let\'s Go!',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// Show the app tour
  void showTour({
    required BuildContext context,
    required List<TargetFocus> targets,
    VoidCallback? onFinish,
    VoidCallback? onSkip,
  }) {
    if (_isTourShowing) return;
    
    _isTourShowing = true;
    debugPrint('📚 Starting app tour with ${targets.length} targets');

    _tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black,
      opacityShadow: 0.85,
      hideSkip: true, // We have custom skip buttons
      paddingFocus: 10,
      focusAnimationDuration: const Duration(milliseconds: 400),
      pulseAnimationDuration: const Duration(milliseconds: 1000),
      onFinish: () {
        debugPrint('📚 App tour finished');
        _isTourShowing = false;
        markTourShown();
        onFinish?.call();
      },
      onSkip: () {
        debugPrint('📚 App tour skipped');
        _isTourShowing = false;
        markTourShown();
        onSkip?.call();
        return true;
      },
      onClickTarget: (target) {
        debugPrint('📚 Tour target clicked: ${target.identify}');
      },
    );

    _tutorialCoachMark!.show(context: context);
  }

  /// Check if tour is currently showing
  bool get isTourShowing => _isTourShowing;
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/routine_service.dart';
import '../../services/auth_service.dart';
import './widgets/profile_step_widget.dart';
import './widgets/routine_preview_widget.dart';
import './widgets/schedule_step_widget.dart';
import './widgets/welcome_step_widget.dart';

class OnboardingFlow extends StatefulWidget {
  const OnboardingFlow({super.key});

  @override
  State<OnboardingFlow> createState() => _OnboardingFlowState();
}

class _OnboardingFlowState extends State<OnboardingFlow>
    with TickerProviderStateMixin {
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _currentStep = 0;
  final int _totalSteps = 4;

  // User data collection
  String _userName = '';
  String _selectedAgeGroup = '';
  List<String> _selectedGoals = [];
  TimeOfDay _wakeTime = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _sleepTime = const TimeOfDay(hour: 22, minute: 0);
  bool _isUserLoggedIn = false;

  final List<String> _ageGroups = ['Student', 'Professional', 'Elder'];
  final List<String> _availableGoals = [
    'Better Sleep',
    'Stress Relief',
    'Focus & Productivity',
    'Physical Fitness',
    'Spiritual Growth',
    'Mindfulness',
    'Energy Boost',
    'Emotional Balance'
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
    _checkLoginStatus();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      // Add haptic feedback for better UX
      HapticFeedback.lightImpact();

      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.reset();
      _animationController.forward();
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      // Add haptic feedback for better UX
      HapticFeedback.lightImpact();

      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _animationController.reset();
      _animationController.forward();
    }
  }

  Future<void> _skipOnboarding() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isUserLoggedIn();

    await authService.markOnboardingCompleted();
    if (!mounted) return;

    if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, AppRoutes.routineDashboard);
    } else {
      await _navigateToAuthentication(replaceRoute: true);
    }
  }

  void _completeOnboarding() async {
    // Show loading dialog while creating routine
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            SizedBox(height: 2.h),
            Text(
              'Creating your personalized routine...',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );

    try {
      // Check if user is authenticated
      final authService = AuthService();
      final isLoggedIn = await authService.isUserLoggedIn();

      if (!isLoggedIn) {
        await authService.markOnboardingCompleted();
        if (mounted) {
          Navigator.of(context).pop();
          await _navigateToAuthentication(replaceRoute: true);
        }
        return;
      }

      if (mounted) {
        setState(() {
          _isUserLoggedIn = true;
        });
      }

        final userId = authService.currentUser?.id;
        if (userId != null) {
          await RoutineService().createDefaultRoutine(
            userId: userId,
            userName: _userName,
            ageGroup: _selectedAgeGroup,
            goals: _selectedGoals,
            wakeTime: _wakeTime,
            sleepTime: _sleepTime,
          );
        }

      await authService.markOnboardingCompleted();

      // Mark onboarding as completed
      await authService.markOnboardingCompleted();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CustomIconWidget(
                  iconName: 'celebration',
                  color: Theme.of(context).colorScheme.primary,
                  size: 48,
                ),
                SizedBox(height: 2.h),
                Text(
                  'Welcome to DinCharya!',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 1.h),
                Text(
                  'Your personalized routine is ready!',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(
                      context, AppRoutes.routineDashboard);
                },
                child: const Text('Get Started'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();

        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to create routine: $e'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.pushReplacementNamed(
                      context, AppRoutes.routineDashboard);
                },
                child: const Text('Continue Anyway'),
              ),
            ],
          ),
        );
      }
    }
  }

  bool _canProceed() {
    switch (_currentStep) {
      case 0:
        return true; // Welcome step
      case 1:
        return _userName.isNotEmpty && _selectedAgeGroup.isNotEmpty;
      case 2:
        return _selectedGoals.isNotEmpty;
      case 3:
        return true; // Schedule step
      default:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Progress indicator
            Container(
              padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Enhanced progress dots with animation
                  Row(
                    children: List.generate(_totalSteps, (index) {
                      final isActive = index == _currentStep;
                      final isCompleted = index < _currentStep;

                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: EdgeInsets.only(right: 2.w),
                        width: isActive ? 3.w : 2.w,
                        height: isActive ? 3.w : 2.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isCompleted
                              ? Color(0xFF8B4513)
                              : isActive
                                  ? Color(0xFF8B4513)
                                  : Theme.of(context).colorScheme.primary
                                      .withValues(alpha: 0.3),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary
                                        .withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: isCompleted
                            ? Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 1.5.w,
                              )
                            : null,
                      );
                    }),
                  ),
                  // Skip button
                  TextButton(
                    onPressed: _skipOnboarding,
                    child: Text(
                      _isUserLoggedIn ? 'Skip' : 'Continue',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Page content
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: PageView(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentStep = index;
                    });
                    _animationController.reset();
                    _animationController.forward();
                  },
                  children: [
                    WelcomeStepWidget(),
                    ProfileStepWidget(
                      userName: _userName,
                      selectedAgeGroup: _selectedAgeGroup,
                      ageGroups: _ageGroups,
                      onNameChanged: (value) {
                        setState(() {
                          _userName = value;
                        });
                      },
                      onAgeGroupChanged: (value) {
                        setState(() {
                          _selectedAgeGroup = value;
                        });
                      },
                    ),
                    ScheduleStepWidget(
                      selectedGoals: _selectedGoals,
                      availableGoals: _availableGoals,
                      onGoalsChanged: (goals) {
                        setState(() {
                          _selectedGoals = goals;
                        });
                      },
                      wakeTime: _wakeTime,
                      sleepTime: _sleepTime,
                      onWakeTimeChanged: (time) {
                        setState(() {
                          _wakeTime = time;
                        });
                      },
                      onSleepTimeChanged: (time) {
                        setState(() {
                          _sleepTime = time;
                        });
                      },
                    ),
                    RoutinePreviewWidget(
                      userName: _userName,
                      ageGroup: _selectedAgeGroup,
                      goals: _selectedGoals,
                      wakeTime: _wakeTime,
                      sleepTime: _sleepTime,
                    ),
                  ],
                ),
              ),
            ),

            // Navigation buttons
            Container(
              padding: EdgeInsets.all(4.w),
              child: Row(
                children: [
                  // Back button
                  _currentStep > 0
                      ? Expanded(
                          child: OutlinedButton(
                            onPressed: _previousStep,
                            child: const Text('Back'),
                          ),
                        )
                      : const Spacer(),

                  SizedBox(width: 4.w),

                  // Enhanced Continue button with better states
                  Expanded(
                    flex: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      child: ElevatedButton(
                        onPressed: _canProceed() ? _nextStep : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _canProceed()
                              ? Color(0xFF8B4513)
                              : Theme.of(context).colorScheme.primary
                                  .withValues(alpha: 0.3),
                          foregroundColor: Colors.white,
                          elevation: _canProceed() ? 4 : 0,
                          padding: EdgeInsets.symmetric(vertical: 2.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep == _totalSteps - 1
                                  ? 'Complete'
                                  : 'Continue',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (_canProceed()) ...[
                              SizedBox(width: 2.w),
                              Icon(
                                _currentStep == _totalSteps - 1
                                    ? Icons.check_circle
                                    : Icons.arrow_forward,
                                size: 20,
                                color: Colors.white,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkLoginStatus() async {
    final authService = AuthService();
    final isLoggedIn = await authService.isUserLoggedIn();
    if (!mounted) return;
    setState(() {
      _isUserLoggedIn = isLoggedIn;
    });
  }

  Future<void> _navigateToAuthentication({bool replaceRoute = false}) async {
    if (!mounted) return;
    if (replaceRoute) {
      Navigator.pushReplacementNamed(context, AppRoutes.authenticationScreen);
    } else {
      await Navigator.pushNamed(context, AppRoutes.authenticationScreen);
      await _checkLoginStatus();
    }
  }

}

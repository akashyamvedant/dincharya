import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../services/auth_service.dart';
import './widgets/loading_indicator_widget.dart';
import './widgets/logo_animation_widget.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _loadingController;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _logoFadeAnimation;

  bool _isInitializing = true;
  bool _initializationError = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat();

    _logoScaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.elasticOut,
    ));

    _logoFadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
    ));

    _logoController.forward();
  }

  Future<void> _initializeApp() async {
    try {
      // Simulate initialization tasks
      await Future.wait([
        _checkAuthenticationStatus(),
        _loadUserPreferences(),
        _prepareCachedContent(),
      ]);

      // Minimum splash duration (reduced for faster startup)
      await Future.delayed(const Duration(milliseconds: 1000));

      if (mounted) {
        _navigateToNextScreen();
      }
    } catch (e) {
      // Handle initialization errors
      if (mounted) {
        setState(() {
          _initializationError = true;
          _isInitializing = false;
        });
      }
    }
  }

  Future<void> _checkAuthenticationStatus() async {
    // Simulate auth check
    await Future.delayed(const Duration(milliseconds: 500));
  }

  Future<void> _loadUserPreferences() async {
    // Simulate loading preferences
    await Future.delayed(const Duration(milliseconds: 300));
  }

  Future<void> _prepareCachedContent() async {
    // Simulate content preparation
    await Future.delayed(const Duration(milliseconds: 400));
  }

  void _navigateToNextScreen() async {
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isUserLoggedIn();

      debugPrint('🎯 Splash Screen Navigation:');
      debugPrint('  - isLoggedIn: $isLoggedIn');

      if (isLoggedIn) {
        debugPrint('  - Navigating to: routine-dashboard');
        Navigator.pushReplacementNamed(context, AppRoutes.routineDashboard);
      } else {
        debugPrint('  - Navigating to: authentication-screen');
        Navigator.pushReplacementNamed(
            context, AppRoutes.authenticationScreen);
      }
    } catch (e) {
      debugPrint('Error determining navigation: $e');
      debugPrint('  - Fallback to: authentication-screen');
      Navigator.pushReplacementNamed(context, AppRoutes.authenticationScreen);
    }
  }

  void _retryInitialization() {
    setState(() {
      _initializationError = false;
      _isInitializing = true;
    });
    _initializeApp();
  }

  @override
  void dispose() {
    _logoController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Theme.of(context).primaryColor,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        body: Container(
          width: 100.w,
          height: 100.h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Theme.of(context).primaryColor,
                Color(0xFFD4A574),
                const Color(0xFFFFE4B5), // Sunrise color
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo Animation
                      AnimatedBuilder(
                        animation: _logoController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _logoScaleAnimation.value,
                            child: Opacity(
                              opacity: _logoFadeAnimation.value,
                              child: LogoAnimationWidget(
                                size: 25.w,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 4.h),

                      // App Name
                      AnimatedBuilder(
                        animation: _logoFadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoFadeAnimation.value,
                            child: Text(
                              'DinCharya',
                              style: Theme.of(context).textTheme.headlineLarge
                                  ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 1.h),

                      // Tagline
                      AnimatedBuilder(
                        animation: _logoFadeAnimation,
                        builder: (context, child) {
                          return Opacity(
                            opacity: _logoFadeAnimation.value * 0.8,
                            child: Text(
                              'दिनचर्या - Daily Wellness Routine',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                                letterSpacing: 0.5,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Loading Section
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  child: Column(
                    children: [
                      if (_isInitializing) ...[
                        LoadingIndicatorWidget(
                          controller: _loadingController,
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Preparing your wellness journey...',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      if (_initializationError) ...[
                        Container(
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            children: [
                              CustomIconWidget(
                                iconName: 'error_outline',
                                color: Colors.white,
                                size: 6.w,
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'Something went wrong',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(height: 1.h),
                              Text(
                                'Please check your connection and try again.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 2.h),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _retryInitialization,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).cardColor,
                                    foregroundColor:
                                        Theme.of(context).primaryColor,
                                    padding:
                                        EdgeInsets.symmetric(vertical: 2.h),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: Text(
                                    'Try Again',
                                    style: Theme.of(context).textTheme.labelLarge
                                        ?.copyWith(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

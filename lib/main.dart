import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';

import 'package:dincharya/widgets/custom_error_widget.dart';
import './services/ads_service.dart';
import './services/auth_service.dart';
import './services/notification_service.dart';
import './services/supabase_service.dart';
import 'core/app_export.dart';

// lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set up global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
  };

  // Set up custom error widget
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return CustomErrorWidget(
      errorDetails: details,
    );
  };

  // Set device orientation
  try {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
  } catch (e) {
    debugPrint('Failed to set device orientation: $e');
  }

  // Start the app immediately for faster startup
  runApp(const MyApp());

  // Initialize heavy services in background after app starts
  _initializeServicesInBackground();
}

// Initialize heavy services in background to avoid blocking app startup
void _initializeServicesInBackground() async {
  // Initialize Supabase
  try {
    await SupabaseService().initFuture;
    debugPrint('Supabase initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize Supabase: $e');
  }

  // Initialize services with error handling
  try {
    await AdsService().initialize();
    debugPrint('Ads service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize ads service: $e');
  }

  try {
    await NotificationService().initialize();
    debugPrint('Notification service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
  }

  // Initialize payment service
  try {
    PaymentService().initialize();
    debugPrint('Payment service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize payment service: $e');
  }

  // Log security initialization
  SecurityConfig.logSecurityEvent('APP_INITIALIZED',
      details: 'All services initialized');
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = true; // Default to dark mode (pure black)
  String _initialRoute = AppRoutes.splashScreen;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Future.wait([
        _loadThemePreference(),
        _determineInitialRoute(),
      ]);

      setState(() {
        _isInitialized = true;
      });

      SecurityConfig.logSecurityEvent('APP_READY',
          details: 'App initialization complete');
    } catch (e) {
      debugPrint('Failed to initialize app: $e');
      SecurityConfig.logSecurityViolation('INITIALIZATION_FAILED',
          details: e.toString());

      // Set default values on failure
      setState(() {
        _isDarkMode = true;
        _initialRoute = AppRoutes.splashScreen;
        _isInitialized = true;
      });
    }
  }

  // Load theme preference
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _isDarkMode = prefs.getBool('is_dark_mode') ?? true; // Default to dark
      });
    } catch (e) {
      debugPrint('Failed to load theme preference: $e');
      SecurityConfig.logSecurityEvent('THEME_LOAD_FAILED',
          details: e.toString());
      // Keep default dark mode
    }
  }

  // Determine initial route based on authentication status
  Future<void> _determineInitialRoute() async {
    try {
      final authService = AuthService();
      final isLoggedIn = await authService.isUserLoggedIn();
      final hasCompletedOnboarding = await authService.hasCompletedOnboarding();

      setState(() {
        if (isLoggedIn && hasCompletedOnboarding) {
          // User is logged in and has completed onboarding - go to dashboard
          _initialRoute = AppRoutes.routineDashboard;
        } else if (isLoggedIn && !hasCompletedOnboarding) {
          // User is logged in but hasn't completed onboarding - go to onboarding
          _initialRoute = AppRoutes.onboardingFlow;
        } else {
          // New user (not logged in) - start with splash screen for better UX
          _initialRoute = AppRoutes.splashScreen;
        }
      });
    } catch (e) {
      debugPrint('Failed to determine initial route: $e');
      SecurityConfig.logSecurityEvent('ROUTE_DETERMINATION_FAILED',
          details: e.toString());
      setState(() {
        _initialRoute = AppRoutes.splashScreen;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Initializing...'),
              ],
            ),
          ),
        ),
      );
    }

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp(
          title: 'DinCharya',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) {
            return MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(1.0),
              ),
              child: child!,
            );
          },
          initialRoute: _initialRoute,
          routes: AppRoutes.routes,
          onGenerateRoute: AppRoutes.onGenerateRoute,
          // Add error handling for navigation
          onUnknownRoute: (settings) {
            SecurityConfig.logSecurityEvent('UNKNOWN_ROUTE',
                details: 'Route: ${settings.name}');
            return MaterialPageRoute(
              builder: (context) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text('Page not found'),
                      SizedBox(height: 8),
                      Text('The requested page does not exist.'),
                      SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () =>
                            Navigator.of(context).pushReplacementNamed('/'),
                        child: Text('Go Home'),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

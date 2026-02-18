import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:dincharya/widgets/custom_error_widget.dart';
import './services/ads_service.dart';
import './services/auth_service.dart';
import './services/notification_service.dart';
import './services/routine_tracking_service.dart';
import './services/supabase_service.dart';
import './services/subscription_manager.dart';
import 'core/app_export.dart';

// lib/main.dart

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
    debugPrint('✅ Environment variables loaded successfully');
  } catch (e) {
    debugPrint('❌ Failed to load .env file: $e');
    debugPrint('💡 Make sure .env file exists in the project root');
  }

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
  // Initialize timezone for scheduled notifications
  try {
    tz.initializeTimeZones();
    debugPrint('✅ Timezone initialized');
  } catch (e) {
    debugPrint('Failed to initialize timezone: $e');
  }

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
    debugPrint('✅ Notification service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize notification service: $e');
  }

  // Initialize routine tracking service for notifications
  try {
    await RoutineTrackingService().initialize();
    debugPrint('✅ Routine tracking service initialized');
  } catch (e) {
    debugPrint('Failed to initialize routine tracking: $e');
  }

  // Initialize payment service
  try {
    PaymentService().initialize();
    debugPrint('Payment service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize payment service: $e');
  }

  // Initialize subscription manager (checks premium status)
  try {
    await SubscriptionManager().initialize();
    debugPrint('✅ Subscription manager initialized: ${SubscriptionManager().isPremium ? "PREMIUM" : "FREE"}');
  } catch (e) {
    debugPrint('Failed to initialize subscription manager: $e');
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

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isDarkMode = true; // Default to dark mode (pure black)
  String _initialRoute = AppRoutes.splashScreen;
  bool _isInitialized = false;
  
  // App Open Ad tracking
  bool _isShowingAd = false;
  bool _hasShownAdThisSession = false; // Only show ad ONCE per session
  DateTime? _appPausedTime;
  
  // AdMob Policy Compliant Settings:
  // - App Open ads should show when user returns to app after being away
  // - Google recommends showing only when user has engaged with app a few times
  // - Must NOT show on app exit or before content is visible
  static const int _minSecondsInBackground = 30; // 30 seconds - reasonable time away
  int _appLaunchCount = 0;
  static const int _showAfterLaunches = 3; // Show after 3rd launch for better UX

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
    _incrementLaunchCount();
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // Track app launches for frequency capping
  Future<void> _incrementLaunchCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _appLaunchCount = (prefs.getInt('app_launch_count') ?? 0) + 1;
      await prefs.setInt('app_launch_count', _appLaunchCount);
      debugPrint('📱 App launch count: $_appLaunchCount');
    } catch (e) {
      debugPrint('Error tracking launch: $e');
    }
  }
  
  // App lifecycle observer - for App Open Ad
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 App lifecycle: $state');
    
    if (state == AppLifecycleState.paused) {
      // App going to background - record time
      _appPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // App coming to foreground - show App Open Ad
      _showAppOpenAdOnResume();
    }
  }
  
  // Show App Open Ad when app resumes from background (ONCE per session)
  Future<void> _showAppOpenAdOnResume({bool isFromBackground = true}) async {
    // Skip if already showing
    if (_isShowingAd) {
      debugPrint('⏳ Already showing ad');
      return;
    }
    
    // CRITICAL: Only show ad ONCE per session
    if (_hasShownAdThisSession) {
      debugPrint('✅ Ad already shown this session - skipping');
      return;
    }
    
    // Skip on first 2 launches (better UX)
    if (_appLaunchCount < _showAfterLaunches) {
      debugPrint('🔢 Skipping: Launch $_appLaunchCount < $_showAfterLaunches');
      return;
    }
    
    // If coming from background, check if user was away for 5+ minutes
    if (isFromBackground && _appPausedTime != null) {
      final secondsSincePause = DateTime.now().difference(_appPausedTime!).inSeconds;
      if (secondsSincePause < _minSecondsInBackground) {
        debugPrint('⏱️ Not long enough in background: ${secondsSincePause}s < ${_minSecondsInBackground}s (5 min)');
        return;
      }
    }
    
    final adsService = AdsService();
    
    if (!adsService.shouldShowAds) {
      debugPrint('👑 Premium user - no ads');
      return;
    }
    
    _isShowingAd = true;
    debugPrint('🎬 Showing App Open Ad...');
    
    try {
      await adsService.showAppOpenAd();
      _hasShownAdThisSession = true; // Mark as shown for this session
      debugPrint('✅ App Open Ad shown - will not show again this session');
    } catch (e) {
      debugPrint('❌ App Open Ad error: $e');
    } finally {
      _isShowingAd = false;
    }
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
      
      // Show App Open Ad on app launch (not from background)
      if (_appLaunchCount >= _showAfterLaunches) {
        _showAppOpenAdOnResume(isFromBackground: false);
      }
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

      setState(() {
        if (isLoggedIn) {
          // User is logged in - go directly to dashboard
          _initialRoute = AppRoutes.routineDashboard;
        } else {
          // New user (not logged in) - start with splash screen → auth
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

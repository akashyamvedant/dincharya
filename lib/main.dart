import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'package:dincharya/widgets/custom_error_widget.dart';
import './services/ads_service.dart';
import './services/deep_link_service.dart';
import './core/constants/ad_constants.dart';
import './services/auth_service.dart';
import './services/notification_service.dart';
import './services/routine_tracking_service.dart';
import './services/supabase_service.dart';
import './services/subscription_manager.dart';
import './services/alarm_service.dart';
import './services/theme_provider.dart';
import './services/task_lifecycle_service.dart';
import './services/firebase_analytics_service.dart';
import 'core/app_export.dart';

/// Global navigator key for navigation from services (e.g., notification taps)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global notifier: fires when a day change is detected at app level.
/// RoutineDashboard listens to this to refresh its UI.
final ValueNotifier<int> dayChangeNotifier = ValueNotifier<int>(0);

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



  // Enable edge-to-edge display for Android 15+ (SDK 35) compatibility.
  // This fixes Play Console recommendation: "Edge-to-edge may not display for all users"
  // and handles deprecated LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  // Initialize Firebase BEFORE runApp (required for Analytics observer)
  try {
    await Firebase.initializeApp();
    debugPrint('🔥 Firebase initialized (Analytics active)');
    
    // 🛡️ SECURITY: Activate Firebase App Check with Play Integrity
    // This verifies that ad requests come from the genuine, untampered app binary.
    // Blocks hijackers who embed our ad unit IDs in their fake apps.
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug      // Debug token for development
          : AndroidProvider.playIntegrity, // Play Integrity for production
    );
    debugPrint('🛡️ Firebase App Check activated (Play Integrity)');
  } catch (e) {
    debugPrint('❌ Firebase initialization failed: $e');
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

  // CRITICAL: Initialize SubscriptionManager BEFORE AdsService!
  // AdsService checks isPremium during init — if SubscriptionManager isn't
  // loaded yet, premium users get treated as free → ads load for them.
  try {
    await SubscriptionManager().initialize();
    debugPrint('✅ Subscription manager initialized: ${SubscriptionManager().isPremium ? "PREMIUM" : "FREE"}');
  } catch (e) {
    debugPrint('Failed to initialize subscription manager: $e');
  }

  // Initialize ads service (AFTER SubscriptionManager so premium check works)
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

  // Initialize alarm service (AFTER notification service)
  try {
    await AlarmService().initialize();
    debugPrint('✅ Alarm service initialized successfully');
  } catch (e) {
    debugPrint('Failed to initialize alarm service: $e');
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
  String _initialRoute = AppRoutes.splashScreen;
  bool _isInitialized = false;
  
  final ThemeProvider _themeProvider = ThemeProvider();
  
  // App Open Ad tracking
  bool _isShowingAd = false;
  DateTime? _appPausedTime;
  
  // AdMob Policy Compliant Settings:
  // - App Open ads show when user returns after being away 30+ seconds
  // - Time-based cooldown (60 min) replaces session-based blocking
  // - Must NOT show on app exit or before content is visible
  static const int _minSecondsInBackground = 30; // 30 seconds - reasonable time away
  static const String _prefFirstSessionDone = 'first_session_done'; // First-session no-ad guard
  static const int _firstSessionGuardSeconds = 60; // App Open blocked for first 60s of first session
  
  // Layer 2: Midnight cross-over timer
  Timer? _midnightTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeApp();
  }
  
  @override
  void dispose() {
    _midnightTimer?.cancel();
    DeepLinkService().dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  // App lifecycle observer — handles day change + App Open Ad
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('📱 App lifecycle: $state');
    
    if (state == AppLifecycleState.paused) {
      // App going to background - record time
      _appPausedTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // Layer 1: Check day change on EVERY resume (regardless of active tab)
      _checkDayChangeOnResume();
      // App Open Ad on resume — first-session guard prevents new-user churn
      _showAppOpenAdOnResume();
      // Layer 2: Re-schedule midnight timer (in case timer was lost in background)
      _scheduleMidnightCheck();
    }
  }
  
  /// First-session guard: prevents App Open ads for the first 60 seconds
  /// of the user's very first session. After this timer fires, the flag is
  /// persisted to SharedPreferences and App Open ads unlock on subsequent resumes.
  void _scheduleFirstSessionComplete() {
    final prefs = SharedPreferences.getInstance();
    Future.delayed(Duration(seconds: _firstSessionGuardSeconds), () async {
      final p = await prefs;
      final alreadySet = p.getBool(_prefFirstSessionDone) ?? false;
      if (!alreadySet) {
        await p.setBool(_prefFirstSessionDone, true);
        debugPrint('✅ First session guard lifted — App Open ads now enabled');
      }
    });
  }
  
  /// Layer 1: App-level day change detection.
  /// This fires on EVERY app resume, unlike RoutineDashboard's observer
  /// which only works when that specific widget is mounted/alive.
  Future<void> _checkDayChangeOnResume() async {
    try {
      final dayChanged = await TaskLifecycleService().checkAndProcessDayChange();
      if (dayChanged) {
        debugPrint('📅 [App-Level] Day changed! Tasks reset. Notifying UI...');
        dayChangeNotifier.value = DateTime.now().millisecondsSinceEpoch;
      }
    } catch (e) {
      debugPrint('❌ App-level day change check failed: $e');
    }
  }
  
  /// Layer 2: Schedule a timer to fire right after next midnight.
  /// Handles the edge case where the app stays open through midnight.
  /// Only fires if the app process is alive — if Android kills the process,
  /// Layer 1 handles it on next cold start/resume.
  void _scheduleMidnightCheck() {
    _midnightTimer?.cancel();
    
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    // Add 5 seconds buffer to ensure we're definitely past midnight
    final duration = nextMidnight.difference(now) + const Duration(seconds: 5);
    
    _midnightTimer = Timer(duration, () async {
      debugPrint('🕛 Midnight crossed — checking day change...');
      await _checkDayChangeOnResume();
      // Reschedule for next midnight
      _scheduleMidnightCheck();
    });
    
    debugPrint('⏰ Midnight check scheduled: ${duration.inMinutes}m from now');
  }
  
  // Show App Open Ad when app resumes from background (time-based cooldown)
  Future<void> _showAppOpenAdOnResume({bool isFromBackground = true}) async {
    // SAFETY: Skip App Open during the user's first session (first 60s of app lifetime).
    // First impressions matter for retention — no ads before user has engaged.
    final prefs = await SharedPreferences.getInstance();
    final firstSessionDone = prefs.getBool(_prefFirstSessionDone) ?? false;
    if (!firstSessionDone) {
      debugPrint('🚫 App Open blocked — first session protection active');
      return;
    }
    
    // Skip if already showing
    if (_isShowingAd) {
      debugPrint('⏳ Already showing ad');
      return;
    }
    
    // If coming from background, check if user was away for 30+ seconds
    if (isFromBackground && _appPausedTime != null) {
      final secondsSincePause = DateTime.now().difference(_appPausedTime!).inSeconds;
      if (secondsSincePause < _minSecondsInBackground) {
        debugPrint('⏱️ Not long enough in background: ${secondsSincePause}s < ${_minSecondsInBackground}s');
        return;
      }
    }
    
    final adsService = AdsService();
    
    if (!adsService.shouldShowAds) {
      debugPrint('👑 Premium user - no ads');
      return;
    }
    
    // TIME-BASED COOLDOWN: Check if 60+ minutes since last App Open ad
    final lastAppOpenTime = await adsService.getLastAppOpenTime();
    if (lastAppOpenTime != null) {
      final minutesSinceLast = DateTime.now().difference(lastAppOpenTime).inMinutes;
      if (minutesSinceLast < AdConstants.minMinutesBetweenAppOpenAds) {
        debugPrint('⏳ App Open cooldown: ${minutesSinceLast}m < ${AdConstants.minMinutesBetweenAppOpenAds}m — skipping');
        return;
      }
    }
    
    _isShowingAd = true;
    debugPrint('🎬 Showing App Open Ad...');
    
    try {
      final wasShown = await adsService.showAppOpenAd();
      if (wasShown) {
        await adsService.persistLastAppOpenTime();
        debugPrint('✅ App Open Ad shown — cooldown reset to ${AdConstants.minMinutesBetweenAppOpenAds}m');
      } else {
        debugPrint('⚠️ App Open Ad not shown — will retry on next resume');
      }
    } catch (e) {
      debugPrint('❌ App Open Ad error: $e');
    } finally {
      _isShowingAd = false;
    }
  }

  Future<void> _initializeApp() async {
    try {
      await Future.wait([
        _themeProvider.initialize(),
        _determineInitialRoute(),
      ]);

      setState(() {
        _isInitialized = true;
      });

      SecurityConfig.logSecurityEvent('APP_READY',
          details: 'App initialization complete');
      
      // First-session guard: mark session as "done" after 60s,
      // unlocking App Open ads for subsequent resumes.
      _scheduleFirstSessionComplete();
      
      // Layer 1: Check day change on cold start
      _checkDayChangeOnResume();
      
      // Layer 2: Start midnight cross-over timer
      _scheduleMidnightCheck();
      
      // CRITICAL: Check if app was launched from alarm notification tap.
      // If so, navigate to AlarmRingScreen INSTEAD of showing App Open Ad.
      final notifService = NotificationService();
      final hasAlarmLaunch = await notifService.checkForAlarmLaunch();
      
      if (hasAlarmLaunch) {
        // Navigate to alarm screen after first frame (navigator needs to be ready)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifService.navigateToPendingAlarm();
        });
      } else {
        // App Open Ad on cold launch — REMOVED for premium feel
        // _showAppOpenAdOnResume(isFromBackground: false);
      }
      
      // Initialize Deep Link Service for shareable session links
      // Must be after navigator is ready (post first frame)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        DeepLinkService().initialize(navigatorKey);
      });
    } catch (e) {
      debugPrint('Failed to initialize app: $e');
      SecurityConfig.logSecurityViolation('INITIALIZATION_FAILED',
          details: e.toString());

      // Set default values on failure
      setState(() {
        _initialRoute = AppRoutes.splashScreen;
        _isInitialized = true;
      });
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
        // Set dynamic orientation: unlock landscape for tablet/desktop, lock portrait for mobile
        final double shortestSide = MediaQuery.of(context).size.shortestSide;
        if (shortestSide >= 600 || kIsWeb) {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
            DeviceOrientation.landscapeLeft,
            DeviceOrientation.landscapeRight,
          ]);
        } else {
          SystemChrome.setPreferredOrientations([
            DeviceOrientation.portraitUp,
            DeviceOrientation.portraitDown,
          ]);
        }
        return ListenableBuilder(
          listenable: _themeProvider,
          builder: (context, _) {
            return MaterialApp(
              navigatorKey: navigatorKey,
              title: 'DinCharya',
              // Firebase Analytics: auto-track screen_view on every route change
              navigatorObservers: [
                FirebaseAnalyticsService().observer,
              ],
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: _themeProvider.themeMode,
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
      },
    );
  }
}

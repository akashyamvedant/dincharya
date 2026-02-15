import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/supabase_service.dart';
import '../../services/ads_service.dart';
import '../../services/subscription_manager.dart';
import '../../widgets/premium_paywall_widget.dart';
import '../../services/guided_session_service.dart';
import '../../widgets/ads/native_ad_widget.dart';
import './widgets/session_card_widget.dart';
import './widgets/programs_section.dart';
import './widgets/quick_tools_section.dart';
import './widgets/vedic_prahar_banner.dart';
import './widgets/session_skeleton_widget.dart';
import './widgets/dosha_quiz_widget.dart';
import './widgets/routine_link_banner.dart';
import './widgets/session_preview_sheet.dart';
import './widgets/sleep_stories_section.dart';
import './widgets/todays_session_card.dart';
import './widgets/practice_stats_row.dart';
import './widgets/post_session_checkin.dart';
import './widgets/continue_session_card.dart';
import './widgets/downloads_section.dart';
import './widgets/weekly_challenge_widget.dart';

class GuidedSessionsHub extends StatefulWidget {
  const GuidedSessionsHub({super.key});

  @override
  State<GuidedSessionsHub> createState() => _GuidedSessionsHubState();
}

class _GuidedSessionsHubState extends State<GuidedSessionsHub>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final SupabaseService _supabaseService = SupabaseService();
  final GuidedSessionService _guidedService = GuidedSessionService();
  int _currentBottomIndex = 1; // Guided tab active
  String _selectedDurationFilter = 'All';
  String _selectedDifficultyFilter = 'All';
  // ignore: unused_field - used for loading state
  bool _isLoadingFromDB = true;
  bool _hasError = false;

  // Sessions from database
  List<Map<String, dynamic>> _meditationSessions = [];
  List<Map<String, dynamic>> _pranayamaSessions = [];
  List<Map<String, dynamic>> _yogaSessions = [];

  // Today's session recommendation
  Map<String, dynamic>? _todaysSession;

  // Practice stats
  int _weeklyMinutes = 0;
  int _streak = 0;
  int _sessionsCount = 0;

  // Resume session
  Map<String, dynamic>? _resumeSession;


  // Mock data as fallback if database fails
  final List<Map<String, dynamic>> _fallbackMeditationSessions = [
    {"id": 1, "title": "Morning Mindfulness", "description": "Start your day with peaceful awareness.", "duration": 900, "difficulty": 3, "category": "meditation", "media_type": "youtube", "media_url": "https://www.youtube.com/watch?v=inpok4MKVLM"},
  ];
  final List<Map<String, dynamic>> _fallbackPranayamaSessions = [
    {"id": 2, "title": "Anulom Vilom", "description": "Alternate nostril breathing technique.", "duration": 600, "difficulty": 2, "category": "pranayama", "media_type": "youtube", "media_url": "https://www.youtube.com/watch?v=8VwufJrUhic"},
  ];
  final List<Map<String, dynamic>> _fallbackYogaSessions = [
    {"id": 3, "title": "Surya Namaskar", "description": "Sun salutation flow.", "duration": 900, "difficulty": 3, "category": "yoga", "media_type": "youtube", "media_url": "https://www.youtube.com/watch?v=AbPufvvYiSw"},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadSessionsFromDB();
    _loadExtras();
  }

  /// Load favorites, today's session, and stats in parallel
  Future<void> _loadExtras() async {
    await Future.wait([
      _guidedService.loadFavorites(),
      _loadTodaysSession(),
      _loadPracticeStats(),
      _loadResumeSession(),
    ]);
  }

  Future<void> _loadResumeSession() async {
    final session = await _guidedService.getLastPlayedSession();
    if (mounted) setState(() => _resumeSession = session);
  }

  Future<void> _loadTodaysSession() async {
    final session = await _guidedService.getTodaysSession();
    if (mounted) setState(() => _todaysSession = session);
  }

  Future<void> _loadPracticeStats() async {
    final stats = await _guidedService.getWeeklyPracticeStats();
    if (mounted) {
      setState(() {
        _weeklyMinutes = stats['totalMinutes'] ?? 0;
        _streak = stats['streak'] ?? 0;
        _sessionsCount = stats['sessionsCount'] ?? 0;
      });
    }
  }

  Future<void> _loadSessionsFromDB() async {
    if (!mounted) return;
    setState(() => _isLoadingFromDB = true);
    try {
      final client = await _supabaseService.client;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      final response = await client
          .from('sessions')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      final sessions = List<Map<String, dynamic>>.from(response);

      if (mounted) {
        setState(() {
          _meditationSessions = sessions.where((s) => s['category'] == 'meditation').toList();
          _pranayamaSessions = sessions.where((s) => s['category'] == 'pranayama').toList();
          _yogaSessions = sessions.where((s) => s['category'] == 'yoga').toList();
          _isLoadingFromDB = false;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      if (mounted) {
        setState(() {
          _isLoadingFromDB = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getCurrentTabSessions() {
    switch (_tabController.index) {
      case 0:
        return _meditationSessions.isEmpty ? _fallbackMeditationSessions : _meditationSessions;
      case 1:
        return _pranayamaSessions.isEmpty ? _fallbackPranayamaSessions : _pranayamaSessions;
      case 2:
        return _yogaSessions.isEmpty ? _fallbackYogaSessions : _yogaSessions;
      default:
        return _meditationSessions.isEmpty ? _fallbackMeditationSessions : _meditationSessions;
    }
  }

  List<Map<String, dynamic>> _getFilteredSessions() {
    List<Map<String, dynamic>> sessions = _getCurrentTabSessions();

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      sessions = sessions
          .where((session) =>
              (session["title"] as String)
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()) ||
              (session["description"] as String)
                  .toLowerCase()
                  .contains(_searchController.text.toLowerCase()))
          .toList();
    }

    // Apply duration filter
    if (_selectedDurationFilter != 'All') {
      sessions = sessions.where((session) {
        int durationMinutes;
        var rawDuration = session["duration"];
        if (rawDuration is int) {
          // Duration in seconds, convert to minutes
          durationMinutes = rawDuration ~/ 60;
        } else if (rawDuration is String) {
          // Duration as string like "10 min"
          durationMinutes = int.tryParse(rawDuration.split(' ')[0]) ?? 10;
        } else {
          durationMinutes = 10; // Default
        }
        switch (_selectedDurationFilter) {
          case '5-15 min':
            return durationMinutes >= 5 && durationMinutes <= 15;
          case '16-30 min':
            return durationMinutes >= 16 && durationMinutes <= 30;
          case '30+ min':
            return durationMinutes > 30;
          default:
            return true;
        }
      }).toList();
    }

    // Apply difficulty filter
    if (_selectedDifficultyFilter != 'All') {
      sessions = sessions.where((session) {
        int difficulty = session["difficulty"] as int;
        switch (_selectedDifficultyFilter) {
          case 'Beginner':
            return difficulty <= 2;
          case 'Intermediate':
            return difficulty == 3 || difficulty == 4;
          case 'Advanced':
            return difficulty == 5;
          default:
            return true;
        }
      }).toList();
    }

    return sessions;
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadSessionsFromDB(),
      _loadTodaysSession(),
      _loadPracticeStats(),
      _guidedService.loadFavorites(),
    ]);
  }

  void _onSessionTap(Map<String, dynamic> session) async {
    final adsService = AdsService();
    
    // ── Premium session gating ──
    // If session is marked as premium, check subscription status
    final bool isSessionPremium = session['is_premium'] == true;
    if (isSessionPremium) {
      final subManager = SubscriptionManager();
      await subManager.initialize();
      if (!subManager.isPremium) {
        // Show premium paywall
        if (mounted) {
          showPremiumPaywall(
            context,
            featureName: 'Premium Session',
            description: 'This guided session is exclusive to Premium members. Upgrade to unlock all premium sessions and features.',
            icon: Icons.self_improvement,
          );
        }
        return;
      }
    }
    
    // AdMob Policy: Rewarded ads must be OPT-IN with clear choice
    // Show dialog to ALL non-premium users (not just when ad is ready)
    if (adsService.shouldShowAds) {
      // Show opt-in dialog (AdMob policy requires clear user consent)
      final shouldWatch = await showDialog<bool>(
        context: context,
        barrierDismissible: false, // User must make a choice
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.play_circle_outline, color: Color(0xFF8B4513)),
              SizedBox(width: 8),
              Text('Watch Ad to Continue'),
            ],
          ),
          content: const Text(
            'Watch a short video ad to unlock this session for free.\n\nOr skip to browse other sessions.',
            style: TextStyle(fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Skip', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8B4513),
                foregroundColor: Colors.white,
              ),
              child: const Text('Watch Ad'),
            ),
          ],
        ),
      );
      
      if (shouldWatch == true) {
        // Show loading if ad not ready
        if (!adsService.isRewardedAdReady) {
          // Show loading indicator
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFF8B4513)),
                    SizedBox(height: 16),
                    Text('Loading ad...', style: TextStyle(fontSize: 14)),
                  ],
                ),
              ),
            ),
          );
          
          // Load ad on demand
          await adsService.loadRewardedAd();
          
          // Close loading dialog
          if (mounted) Navigator.pop(context);
          
          // Small delay for ad to be ready
          await Future.delayed(Duration(milliseconds: 500));
        }
        
        // Now show the ad
        final wasRewarded = await adsService.showRewardedAd(
          onRewarded: () {
            // Navigate after reward
            if (mounted) {
              _navigateAndCheckIn(session);
            }
          },
        );
        
        // If ad failed to show, still allow access (good UX)
        if (!wasRewarded && mounted) {
          _navigateAndCheckIn(session);
        }
      }
      // If user clicked "Skip", do nothing (they stay on current screen)
    } else {
      // Premium user - direct access
      _navigateAndCheckIn(session);
    }
  }

  /// Navigate to media player and show post-session check-in on return
  Future<void> _navigateAndCheckIn(Map<String, dynamic> session) async {
    await Navigator.pushNamed(context, '/media-player', arguments: session);
    if (!mounted) return;

    final title = session['title'] ?? 'Session';
    final category = session['category'] ?? 'meditation';
    final duration = session['duration'] as int? ?? 600;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PostSessionCheckIn(
        sessionTitle: title,
        category: category,
        durationSeconds: duration,
        onSubmit: ({
          required String moodBefore,
          required String moodAfter,
          required int energyBefore,
          required int energyAfter,
          String? notes,
        }) async {
          Navigator.pop(context);
          try {
            await _guidedService.recordSession(
              practiceType: category,
              technique: title,
              durationSeconds: duration,
              moodBefore: moodBefore,
              moodAfter: moodAfter,
              energyBefore: energyBefore,
              energyAfter: energyAfter,
              notes: notes,
            );
          } catch (_) {}
          // Refresh stats
          _loadPracticeStats();
        },
        onSkip: () => Navigator.pop(context),
      ),
    );
  }

  void _onSessionLongPress(Map<String, dynamic> session) {
    final sessionId = session['id']?.toString() ?? '';
    final isFav = _guidedService.isFavorite(sessionId);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => SessionPreviewSheet(
        session: session,
        isFavorite: isFav,
        onStart: () => _onSessionTap(session),
        onToggleFavorite: () async {
          Navigator.pop(context);
          await _guidedService.toggleFavorite(sessionId);
          if (mounted) setState(() {});
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightTheme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Premium Header with Gradient
            Container(
              padding: EdgeInsets.fromLTRB(4.w, 2.h, 4.w, 2.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    _getTabColor(_tabController.index),
                    _getTabColor(_tabController.index).withOpacity(0.7),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _getTabColor(_tabController.index).withOpacity(0.3),
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    'Guided Sessions',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    _getTabSubtitle(_tabController.index),
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14.sp,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search sessions...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search, color: _getTabColor(_tabController.index)),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                },
                                icon: Icon(Icons.clear, color: Colors.grey),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.8.h),
                      ),
                      onChanged: (value) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 1.h),

            // Premium Tab Bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.all(1.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicator: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getTabColor(_tabController.index),
                      _getTabColor(_tabController.index).withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getTabColor(_tabController.index).withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey[600],
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.sp),
                unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 11.sp),
                labelPadding: EdgeInsets.symmetric(horizontal: 2.w),
                tabs: const [
                  Tab(text: 'Meditate'),
                  Tab(text: 'Breathe'),
                  Tab(text: 'Yoga'),
                  Tab(text: 'Explore'),
                ],
                onTap: (index) => setState(() {}),
              ),
            ),

            SizedBox(height: 2.h),

            // Filter Chips
            SizedBox(
              height: 5.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                children: [
                  _buildPremiumFilterChip(
                    label: 'Duration',
                    selectedValue: _selectedDurationFilter,
                    options: const ['All', '5-15 min', '16-30 min', '30+ min'],
                    onChanged: (value) => setState(() => _selectedDurationFilter = value),
                  ),
                  SizedBox(width: 2.w),
                  _buildPremiumFilterChip(
                    label: 'Difficulty',
                    selectedValue: _selectedDifficultyFilter,
                    options: const ['All', 'Beginner', 'Intermediate', 'Advanced'],
                    onChanged: (value) => setState(() => _selectedDifficultyFilter = value),
                  ),
                ],
              ),
            ),

            SizedBox(height: 1.h),

            // Sessions List
            Expanded(
              child: RefreshIndicator(
                onRefresh: _handleRefresh,
                color: AppTheme.lightTheme.colorScheme.primary,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildSessionsList(_getFilteredSessions()),
                    _buildSessionsList(_getFilteredSessions()),
                    _buildSessionsList(_getFilteredSessions()),
                    _buildExploreTab(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentBottomIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.lightTheme.colorScheme.surface,
        selectedItemColor: AppTheme.lightTheme.colorScheme.primary,
        unselectedItemColor: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
        items: [
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'schedule',
              color: _currentBottomIndex == 0
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Routine',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'self_improvement',
              color: _currentBottomIndex == 1
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Guided',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'book',
              color: _currentBottomIndex == 2
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: CustomIconWidget(
              iconName: 'person',
              color: _currentBottomIndex == 3
                  ? AppTheme.lightTheme.colorScheme.primary
                  : AppTheme.lightTheme.colorScheme.onSurfaceVariant,
              size: 24,
            ),
            label: 'Me',
          ),
        ],
        onTap: (index) {
          setState(() {
            _currentBottomIndex = index;
          });

          switch (index) {
            case 0:
              Navigator.pushNamed(context, '/routine-dashboard');
              break;
            case 1:
              // Already on guided sessions hub
              break;
            case 2:
              Navigator.pushNamed(context, '/journal-mood-tracker');
              break;
            case 3:
              Navigator.pushNamed(context, '/profile-settings');
              break;
          }
        },
      ),
    );
  }

  /// Explore tab — all discovery/browse widgets in one place
  Widget _buildExploreTab() {
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      children: [
        // Stats overview (tappable) — first
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/session-history'),
          child: PracticeStatsRow(
            totalMinutes: _weeklyMinutes,
            streak: _streak,
            sessionsCount: _sessionsCount,
          ),
        ),
        SizedBox(height: 2.h),

        // ✨ Ask Disha — AI Guide
        GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/ai-guide'),
          child: Container(
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFF3C4), Color(0xFFFFF8E1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFDAA520).withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFDAA520).withOpacity(0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDAA520), Color(0xFFB8860B)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('दि', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
                SizedBox(width: 3.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ask Disha — AI Guide ✨',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF8B4513),
                        ),
                      ),
                      Text(
                        'Your personal Ayurvedic wellness companion',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: const Color(0xFF5D4037),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: const Color(0xFF8B4513).withOpacity(0.5)),
              ],
            ),
          ),
        ),
        SizedBox(height: 2.h),

        if (_resumeSession != null)
          ContinueSessionCard(
            session: _resumeSession!,
            onResume: () => _navigateAndCheckIn(_resumeSession!),
          ),

        // Vedic Prahar — time-aware recommendation
        const VedicPraharBanner(),
        SizedBox(height: 1.5.h),

        // Routine Link — bridge to routine tab
        const RoutineLinkBanner(),
        SizedBox(height: 2.h),

        // Programs & Courses
        const ProgramsSection(),
        SizedBox(height: 2.h),

        // Quick Tools
        const QuickToolsSection(),
        SizedBox(height: 2.h),

        // My Downloads (only shown if downloads exist)
        const DownloadsSection(),
        SizedBox(height: 2.h),

        // Sleep & Relax
        const SleepStoriesSection(),
        SizedBox(height: 2.h),

        // Weekly Challenge
        const WeeklyChallengeWidget(),
        SizedBox(height: 2.h),

        // Dosha Quiz
        const DoshaQuizWidget(),
        SizedBox(height: 3.h),
      ],
    );
  }

  Widget _buildSessionsList(List<Map<String, dynamic>> sessions) {
    // Show skeleton while loading
    if (_isLoadingFromDB) {
      return const SessionSkeletonWidget(count: 4);
    }

    // Show error UI
    if (_hasError) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(8.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 56, color: Colors.grey[400]),
              SizedBox(height: 2.h),
              Text(
                'Couldn\'t load sessions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C1810),
                ),
              ),
              SizedBox(height: 1.h),
              Text(
                'Check your internet connection and try again',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
              ),
              SizedBox(height: 2.h),
              ElevatedButton.icon(
                onPressed: _loadSessionsFromDB,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B4513),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Count extra items: hero (0|1) + stats (1)
    final int heroCount = _todaysSession != null ? 1 : 0;
    final int headerCount = heroCount + 1; // just stats
    final int adSlots = sessions.length >= 3 ? sessions.length ~/ 3 : 0;
    final int totalCount = headerCount + sessions.length + adSlots;

    if (sessions.isEmpty) {
      return ListView(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
        children: [
          // Still show hero card + stats even when no sessions match filter
          if (_todaysSession != null)
            Padding(
              padding: EdgeInsets.only(bottom: 1.5.h),
              child: TodaysSessionCard(
                session: _todaysSession!,
                recommendationReason:
                    _todaysSession!['recommendation_reason'] ?? 'Start your practice ✨',
                onStart: () => _onSessionTap(_todaysSession!),
              ),
            ),
          GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/session-history'),
            child: PracticeStatsRow(
              totalMinutes: _weeklyMinutes,
              streak: _streak,
              sessionsCount: _sessionsCount,
            ),
          ),
          SizedBox(height: 4.h),
          Center(
            child: Column(
              children: [
                CustomIconWidget(
                  iconName: 'search_off',
                  color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  size: 48,
                ),
                SizedBox(height: 2.h),
                Text(
                  'No sessions found',
                  style: AppTheme.lightTheme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: 1.h),
                Text(
                  'Try adjusting your search or filters',
                  style: AppTheme.lightTheme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        // ── Hero Card (index 0 if present) ──
        if (heroCount > 0 && index == 0) {
          return Padding(
            padding: EdgeInsets.only(bottom: 1.5.h),
            child: TodaysSessionCard(
              session: _todaysSession!,
              recommendationReason:
                  _todaysSession!['recommendation_reason'] ?? 'Start your practice ✨',
              onStart: () => _onSessionTap(_todaysSession!),
            ),
          );
        }

        // ── Stats Row (tappable → session history) ──
        if (index == heroCount) {
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/session-history'),
            child: Padding(
              padding: EdgeInsets.only(bottom: 1.5.h),
              child: PracticeStatsRow(
                totalMinutes: _weeklyMinutes,
                streak: _streak,
                sessionsCount: _sessionsCount,
              ),
            ),
          );
        }

        // ── Session cards + ads ──
        final adjustedIndex = index - headerCount;
        final adCount = adjustedIndex >= 0 ? (adjustedIndex) ~/ 4 : 0;
        final isAdSlot = adjustedIndex >= 0 && (adjustedIndex + 1) % 4 == 0 && adjustedIndex > 0 && sessions.length >= 3;

        if (isAdSlot) {
          return const NativeAdWidget(placement: NativePlacement.sessionFeed);
        }

        final sessionIndex = adjustedIndex - adCount;
        if (sessionIndex < 0 || sessionIndex >= sessions.length) return const SizedBox.shrink();

        final session = sessions[sessionIndex];
        final sessionId = session['id']?.toString() ?? '';
        return SessionCardWidget(
          session: session,
          onTap: () => _onSessionTap(session),
          onLongPress: () => _onSessionLongPress(session),
          showBreathingAnimation:
              _tabController.index == 0,
          isFavorite: _guidedService.isFavorite(sessionId),
          onFavoriteToggle: () async {
            await _guidedService.toggleFavorite(sessionId);
            if (mounted) setState(() {});
          },
        );
      },
    );
  }

  Color _getTabColor(int index) {
    switch (index) {
      case 0: return const Color(0xFF8B4513); // Earth brown for Meditate
      case 1: return const Color(0xFF4A7C59); // Natural green for Breathe
      case 2: return const Color(0xFFFF6B35); // Accent orange for Yoga
      default: return const Color(0xFF8B4513);
    }
  }

  String _getTabSubtitle(int index) {
    switch (index) {
      case 0: return 'Find peace and clarity through meditation';
      case 1: return 'Master the art of conscious breathing';
      case 2: return 'Strengthen body, mind and spirit';
      default: return 'Explore guided sessions';
    }
  }

  Widget _buildPremiumFilterChip({
    required String label,
    required String selectedValue,
    required List<String> options,
    required Function(String) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
      decoration: BoxDecoration(
        color: selectedValue != 'All' 
            ? _getTabColor(_tabController.index).withOpacity(0.1) 
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selectedValue != 'All' 
              ? _getTabColor(_tabController.index) 
              : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _showFilterOptions(label, options, onChanged),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              label == 'Duration' ? Icons.access_time : Icons.trending_up,
              size: 16,
              color: selectedValue != 'All' 
                  ? _getTabColor(_tabController.index) 
                  : Colors.grey[600],
            ),
            SizedBox(width: 1.w),
            Text(
              selectedValue == 'All' ? label : selectedValue,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: selectedValue != 'All' ? FontWeight.bold : FontWeight.w500,
                color: selectedValue != 'All' 
                    ? _getTabColor(_tabController.index) 
                    : Colors.grey[600],
              ),
            ),
            SizedBox(width: 1.w),
            Icon(
              Icons.keyboard_arrow_down,
              size: 18,
              color: selectedValue != 'All' 
                  ? _getTabColor(_tabController.index) 
                  : Colors.grey[600],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterOptions(String label, List<String> options, Function(String) onChanged) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              'Select $label',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C1810),
              ),
            ),
            SizedBox(height: 2.h),
            ...options.map((option) => ListTile(
              title: Text(
                option,
                style: TextStyle(
                  color: Color(0xFF2C1810),
                  fontSize: 14.sp,
                ),
              ),
              trailing: option == _selectedDurationFilter || option == _selectedDifficultyFilter
                  ? Icon(Icons.check, color: _getTabColor(_tabController.index))
                  : null,
              onTap: () {
                onChanged(option);
                Navigator.pop(context);
              },
            )),
            SizedBox(height: 2.h),
          ],
        ),
      ),
    );
  }
}

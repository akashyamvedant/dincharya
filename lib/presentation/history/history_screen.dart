import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/supabase_service.dart';
import '../../services/analytics_service.dart';
import '../../widgets/ads/banner_ad_widget.dart';

/// Professional History Screen with calendar and stats
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with TickerProviderStateMixin {
  final SupabaseService _supabaseService = SupabaseService();
  final AnalyticsService _analyticsService = AnalyticsService();
  
  // Tab Controller
  late TabController _tabController;
  
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  Map<String, List<Map<String, dynamic>>> _tasksByDate = {};
  bool _isLoading = true;
  
  // Stats
  int _totalTasks = 0;
  int _completedTasks = 0;
  int _currentStreak = 0;
  int _bestStreak = 0;
  
  // Journal Entries
  List<Map<String, dynamic>> _journalEntries = [];
  
  // Analytics Data
  DisciplineScore? _disciplineScore;
  WeeklyPattern? _weeklyPattern;
  TimeAnalysis? _timeAnalysis;
  List<HabitStats> _habitStats = [];
  List<Achievement> _achievements = [];

  late AnimationController _statsAnimationController;
  late Animation<double> _statsAnimation;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // 4 tabs now
    _statsAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _statsAnimation = CurvedAnimation(
      parent: _statsAnimationController,
      curve: Curves.easeOutBack,
    );
    _loadData();
    _loadAnalytics();
    _loadJournalEntries(); // Load journal entries
  }

  @override
  void dispose() {
    _tabController.dispose();
    _statsAnimationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      final client = await _supabaseService.client;
      if (client == null) return;

      // Fetch actual tracking history from routine_tracking table
      final trackingHistory = await client
          .from('routine_tracking')
          .select()
          .eq('user_id', userId)
          .order('tracking_date', ascending: false);
      
      // Also fetch user profile for best_streak
      final userProfile = await client
          .from('user_profiles')
          .select('current_streak, best_streak, total_tasks_completed')
          .eq('id', userId)
          .maybeSingle();
      
      // Group tasks by tracking_date — DEDUPLICATED by task_id
      // Same task can have both completed + missed records (from end-of-day processing)
      // We keep only the best result per task per day (completed wins)
      final Map<String, Map<String, Map<String, dynamic>>> rawGrouped = {};
      
      for (final task in trackingHistory) {
        final dateKey = task['tracking_date'] ?? DateTime.now().toIso8601String().split('T')[0];
        final taskId = task['task_id']?.toString() ?? task['activity_name']?.toString() ?? '';
        
        rawGrouped[dateKey] ??= {};
        
        // Keep the completed record if one exists (completed wins over missed)
        final existing = rawGrouped[dateKey]![taskId];
        if (existing == null || (existing['completed'] != true && task['completed'] == true)) {
          rawGrouped[dateKey]![taskId] = task;
        }
      }
      
      // Convert to final grouped format
      final Map<String, List<Map<String, dynamic>>> grouped = {};
      int completed = 0;
      int missed = 0;
      
      for (final entry in rawGrouped.entries) {
        grouped[entry.key] = entry.value.values.toList();
        for (final task in grouped[entry.key]!) {
          if (task['completed'] == true) {
            completed++;
          } else {
            missed++;
          }
        }
      }
      
      // Get streak values from user_profiles
      final profileStreak = userProfile?['current_streak'] ?? 0;
      final profileBestStreak = userProfile?['best_streak'] ?? 0;
      
      setState(() {
        _tasksByDate = grouped;
        _totalTasks = trackingHistory.length;
        _completedTasks = completed;
        _currentStreak = profileStreak;
        _bestStreak = profileBestStreak > profileStreak ? profileBestStreak : profileStreak;
        _isLoading = false;
      });
      
      debugPrint('📊 History loaded: ${trackingHistory.length} records, Streak: $_currentStreak, Best: $_bestStreak');
      _statsAnimationController.forward();
    } catch (e) {
      debugPrint('Error loading history: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _loadAnalytics() async {
    try {
      // Load all analytics data in parallel
      final results = await Future.wait([
        _analyticsService.calculateDisciplineScore(),
        _analyticsService.getWeeklyPattern(),
        _analyticsService.getTimeBasedAnalysis(),
        _analyticsService.getHabitBreakdown(),
        _analyticsService.getAchievements(),
      ]);
      
      setState(() {
        _disciplineScore = results[0] as DisciplineScore;
        _weeklyPattern = results[1] as WeeklyPattern;
        _timeAnalysis = results[2] as TimeAnalysis;
        _habitStats = results[3] as List<HabitStats>;
        _achievements = results[4] as List<Achievement>;
      });
      
      debugPrint('📈 Analytics loaded: Score=${_disciplineScore?.totalScore}');
    } catch (e) {
      debugPrint('Error loading analytics: $e');
    }
  }

  Future<void> _loadJournalEntries() async {
    try {
      final userId = _supabaseService.currentUser?.id;
      if (userId == null) return;

      final entries = await _supabaseService.getJournalEntries(userId);
      setState(() {
        _journalEntries = entries;
      });
      debugPrint('📓 Journal entries loaded: ${_journalEntries.length}');
    } catch (e) {
      debugPrint('Error loading journal entries: $e');
    }
  }

  int _calculateStreak(Map<String, List<Map<String, dynamic>>> grouped) {
    int streak = 0;
    DateTime checkDate = DateTime.now();
    
    for (int i = 0; i < 365; i++) {
      final dateKey = '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      final dayTasks = grouped[dateKey];
      
      if (dayTasks == null || dayTasks.isEmpty) {
        if (i > 0) break; // First day can be empty
        checkDate = checkDate.subtract(const Duration(days: 1));
        continue;
      }
      
      // Use 'completed' field (not 'is_completed') — routine_tracking table field
      final completedCount = dayTasks.where((t) => 
        t['completed'] == true
      ).length;
      
      // Consider day as streak if >50% tasks completed (matches dashboard logic)
      if (completedCount > dayTasks.length / 2) {
        streak++;
        checkDate = checkDate.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }
    
    return streak;
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Header
                  _buildHeader(),
                  
                  // Tab Bar - Full width indicator
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: BoxDecoration(
                      color: primaryBrown.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        indicator: BoxDecoration(
                          color: primaryBrown,
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor: Theme.of(context).colorScheme.onSurface,
                        labelStyle: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        unselectedLabelStyle: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        dividerColor: Colors.transparent,
                        labelPadding: EdgeInsets.symmetric(vertical: 0.5.h),
                        tabs: [
                          Tab(
                            icon: Icon(Icons.calendar_month, size: 18),
                            child: Text('Calendar', style: TextStyle(fontSize: 12.sp)),
                          ),
                          Tab(
                            icon: Icon(Icons.insights, size: 18),
                            child: Text('Insights', style: TextStyle(fontSize: 12.sp)),
                          ),
                          Tab(
                            icon: Icon(Icons.emoji_events, size: 18),
                            child: Text('Medals', style: TextStyle(fontSize: 12.sp)),
                          ),
                          Tab(
                            icon: Icon(Icons.book, size: 18),
                            child: Text('Journal', style: TextStyle(fontSize: 12.sp)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 1.h),
                  
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        // Tab 1: Calendar
                        _buildCalendarTab(),
                        
                        // Tab 2: Insights
                        _buildInsightsTab(),
                        
                        // Tab 3: Medals
                        _buildMedalsTab(),
                        
                        // Tab 4: Journal
                        _buildJournalTab(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
  
  // ===== TAB 1: CALENDAR =====
  Widget _buildCalendarTab() {
    return CustomScrollView(
      slivers: [
        // Stats Cards
        SliverToBoxAdapter(child: _buildStatsSection()),
        
        // Calendar
        SliverToBoxAdapter(child: _buildCalendar()),
        
        // Selected Day Tasks
        SliverToBoxAdapter(child: _buildSelectedDayTasks()),
        
        // Banner Ad at bottom
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w),
            child: const BannerAdWidget(placement: BannerPlacement.yourJourney),
          ),
        ),
        
        SliverPadding(padding: EdgeInsets.only(bottom: 10.h)),
      ],
    );
  }
  
  // ===== TAB 2: INSIGHTS =====
  Widget _buildInsightsTab() {
    const Color darkBrown = Color(0xFF2C1810);
    
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),
          
          // Discipline Score Card
          _buildDisciplineScoreCard(),
          
          SizedBox(height: 2.5.h),
          
          // Section Title
          Text(
            '📊 Weekly Pattern',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          SizedBox(height: 1.5.h),
          _buildWeeklyPatternChart(),
          
          SizedBox(height: 2.5.h),
          
          // Time Analysis
          Text(
            '⏰ Time-Based Performance',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.5.h),
          _buildTimeAnalysisCard(),
          
          SizedBox(height: 2.5.h),
          
          // Habit Breakdown
          Text(
            '📋 Habit Performance',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: darkBrown,
            ),
          ),
          SizedBox(height: 1.5.h),
          _buildHabitBreakdown(),
          
          SizedBox(height: 10.h),
        ],
      ),
    );
  }
  
  // ===== TAB 3: MEDALS =====
  Widget _buildMedalsTab() {
    const Color darkBrown = Color(0xFF2C1810);
    
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 2.h),
          
          // Unlocked Section
          Text(
            '🏆 Your Achievements',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.5.h),
          
          // Achievement Cards
          ..._achievements.map((a) => _buildAchievementCard(a)),
          
          SizedBox(height: 10.h),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    const Color mediumBrown = Color(0xFF5D4037);
    
    return Container(
      padding: EdgeInsets.all(4.w),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: primaryBrown.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryBrown.withOpacity(0.2)),
              ),
              child: Icon(
                Icons.arrow_back_ios_new, 
                size: 20,
                color: primaryBrown,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Journey',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Track your daily progress',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          // Month selector
          Container(
            padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.h),
            decoration: BoxDecoration(
              color: primaryBrown.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: primaryBrown.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month, 
                  size: 18,
                  color: primaryBrown,
                ),
                SizedBox(width: 1.w),
                Text(
                  _getMonthYear(_focusedMonth),
                  style: TextStyle(
                    color: primaryBrown,
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return AnimatedBuilder(
      animation: _statsAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.8 + (0.2 * _statsAnimation.value),
          child: Opacity(
            opacity: _statsAnimation.value,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                children: [
                  Expanded(child: _buildStatCard(
                    icon: Icons.task_alt,
                    value: '$_completedTasks',
                    label: 'Completed',
                    color: Colors.green,
                  )),
                  SizedBox(width: 3.w),
                  Expanded(child: _buildStatCard(
                    icon: Icons.local_fire_department,
                    value: '$_currentStreak',
                    label: 'Day Streak',
                    color: Colors.orange,
                  )),
                  SizedBox(width: 3.w),
                  Expanded(child: _buildStatCard(
                    icon: Icons.emoji_events,
                    value: '$_bestStreak',
                    label: 'Best Streak',
                    color: Colors.amber,
                  )),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          SizedBox(height: 0.5.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    final firstDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7; // Sunday = 0
    
    return Container(
      margin: EdgeInsets.all(4.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Month navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
                  });
                },
                icon: Icon(Icons.chevron_left),
              ),
              Text(
                _getMonthYear(_focusedMonth),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1);
                  });
                },
                icon: Icon(Icons.chevron_right),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) => 
              SizedBox(
                width: 10.w,
                child: Text(
                  d,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    fontSize: 13.sp,
                  ),
                ),
              ),
            ).toList(),
          ),
          SizedBox(height: 1.h),
          
          // Calendar grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemCount: firstWeekday + lastDayOfMonth.day,
            itemBuilder: (context, index) {
              if (index < firstWeekday) {
                return const SizedBox();
              }
              
              final day = index - firstWeekday + 1;
              final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
              final dateKey = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              final dayTasks = _tasksByDate[dateKey];
              
              final isToday = _isToday(date);
              final isSelected = _isSameDay(date, _selectedDate);
              final completionColor = _getCompletionColor(dayTasks);
              
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedDate = date);
                },
                child: Container(
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? Color(0xFF8B4513)
                        : completionColor?.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: isToday ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ) : null,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$day',
                          style: TextStyle(
                            color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14.sp,
                          ),
                        ),
                        if (dayTasks != null && dayTasks.isNotEmpty)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? Colors.white : completionColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          
          // Legend
          SizedBox(height: 2.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(Colors.green, '100%'),
              SizedBox(width: 4.w),
              _buildLegendItem(Colors.orange, '50%+'),
              SizedBox(width: 4.w),
              _buildLegendItem(Colors.red, '<50%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        SizedBox(width: 1.w),
        Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedDayTasks() {
    final dateKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final dayTasks = _tasksByDate[dateKey] ?? [];
    
    // Use 'completed' field (not 'is_completed') — routine_tracking table field
    final completedCount = dayTasks.where((t) => 
      t['completed'] == true
    ).length;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 4.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatDate(_selectedDate),
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (dayTasks.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.5.h),
                  decoration: BoxDecoration(
                    color: _getCompletionColor(dayTasks)?.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completedCount/${dayTasks.length} done',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: _getCompletionColor(dayTasks),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 2.h),
          
          if (dayTasks.isEmpty)
            Container(
              padding: EdgeInsets.all(4.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_busy, color: Colors.grey[400], size: 40),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No tasks for this day',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          'Tasks created on this date will appear here',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ...dayTasks.map((task) => _buildTaskItem(task)),
        ],
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task) {
    // Use routine_tracking table fields
    final isCompleted = task['completed'] == true;
    final activityName = task['activity_name'] ?? task['title'] ?? 'Task';
    final scheduledTime = task['scheduled_time'] ?? task['time'] ?? '';
    final xpEarned = task['xp_earned'] ?? 0;
    final skipReason = task['skip_reason'];
    
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCompleted ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_circle : Icons.cancel,
              color: isCompleted ? Colors.green : Colors.red,
              size: 20,
            ),
          ),
          SizedBox(width: 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activityName,
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                    color: isCompleted ? Colors.grey : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    if (scheduledTime.isNotEmpty)
                      Text(
                        scheduledTime,
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    if (skipReason != null && !isCompleted) ...[
                      SizedBox(width: 2.w),
                      Text(
                        '• $skipReason',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.red.shade400,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // XP Badge or status
          if (isCompleted && xpEarned > 0)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('⭐', style: TextStyle(fontSize: 12.sp)),
                  SizedBox(width: 1.w),
                  Text(
                    '+$xpEarned XP',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800,
                    ),
                  ),
                ],
              ),
            )
          else if (isCompleted)
            Text('✅', style: TextStyle(fontSize: 16.sp))
          else
            Text('❌', style: TextStyle(fontSize: 16.sp)),
        ],
      ),
    );
  }

  Color? _getCompletionColor(List<Map<String, dynamic>>? tasks) {
    if (tasks == null || tasks.isEmpty) return null;
    
    final completed = tasks.where((t) => 
      t['completed'] == true || t['completed'] == 1
    ).length;
    
    final percentage = completed / tasks.length;
    
    if (percentage >= 1.0) return Colors.green;
    if (percentage >= 0.5) return Colors.orange;
    return Colors.red;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _getMonthYear(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDate(DateTime date) {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const months = ['January', 'February', 'March', 'April', 'May', 'June',
                    'July', 'August', 'September', 'October', 'November', 'December'];
    return '${days[date.weekday % 7]}, ${date.day} ${months[date.month - 1]}';
  }
  
  // ===== INSIGHT WIDGETS =====
  
  Widget _buildDisciplineScoreCard() {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    
    final score = _disciplineScore?.totalScore ?? 0;
    final completionRate = _disciplineScore?.completionRate ?? 0;
    
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            primaryBrown.withOpacity(0.15),
            primaryBrown.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBrown.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('🏅', style: TextStyle(fontSize: 24.sp)),
              SizedBox(width: 2.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your Discipline Score',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      'Based on your habit consistency',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  color: _getScoreColor(score),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$score/100',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 2.h),
          
          // Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: score / 100,
              minHeight: 10,
              backgroundColor: primaryBrown.withOpacity(0.2),
              valueColor: AlwaysStoppedAnimation(_getScoreColor(score)),
            ),
          ),
          
          SizedBox(height: 1.5.h),
          
          // Score Breakdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildScoreChip('📊 Completion', '${completionRate.toStringAsFixed(0)}%'),
              _buildScoreChip('🔥 Streak', '${_disciplineScore?.streakBonus ?? 0}pts'),
              _buildScoreChip('⏰ On-Time', '${(_disciplineScore?.onTimeBonus ?? 0).toStringAsFixed(0)}pts'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildScoreChip(String label, String value) {
    const Color darkBrown = Color(0xFF2C1810);
    
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13.sp,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
  
  Color _getScoreColor(int score) {
    if (score >= 80) return Colors.green;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.amber;
    return Colors.red;
  }
  
  Widget _buildWeeklyPatternChart() {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    
    final pattern = _weeklyPattern;
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBrown.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          ...days.map((day) {
            final rate = pattern?.dailyRates[day] ?? 0;
            final isBest = day == pattern?.bestDay;
            final isWorst = day == pattern?.worstDay && rate < 70;
            
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 0.5.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 10.w,
                    child: Text(
                      day,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: rate / 100,
                        minHeight: 16,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(
                          isBest ? Colors.green : (isWorst ? Colors.red : primaryBrown),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  SizedBox(
                    width: 12.w,
                    child: Text(
                      '${rate.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isBest) Text('🔥', style: TextStyle(fontSize: 14.sp)),
                  if (isWorst) Text('⚠️', style: TextStyle(fontSize: 14.sp)),
                ],
              ),
            );
          }),
          
          // Insight tip
          if (pattern != null && pattern.worstDay.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 1.h),
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      '${pattern.worstDay} is your weakest day. Focus more!',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.amber.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTimeAnalysisCard() {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    
    final analysis = _timeAnalysis;
    
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBrown.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTimeRow('🌅 Morning', analysis?.morningRate ?? 0, analysis?.bestTime == 'Morning'),
          SizedBox(height: 1.h),
          _buildTimeRow('☀️ Afternoon', analysis?.afternoonRate ?? 0, analysis?.bestTime == 'Afternoon'),
          SizedBox(height: 1.h),
          _buildTimeRow('🌙 Evening', analysis?.eveningRate ?? 0, analysis?.bestTime == 'Evening'),
          
          // Insight tip
          if (analysis != null && analysis.worstTime.isNotEmpty)
            Container(
              margin: EdgeInsets.only(top: 1.5.h),
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text('💡', style: TextStyle(fontSize: 14.sp)),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Text(
                      '${analysis.worstTime} tasks need attention!',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildTimeRow(String label, double rate, bool isBest) {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    
    return Row(
      children: [
        SizedBox(
          width: 28.w,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: rate / 100,
              minHeight: 14,
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation(
                isBest ? Colors.green : (rate < 50 ? Colors.red : primaryBrown),
              ),
            ),
          ),
        ),
        SizedBox(width: 2.w),
        SizedBox(
          width: 12.w,
          child: Text(
            '${rate.toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        if (isBest) Text('⭐', style: TextStyle(fontSize: 14.sp)),
      ],
    );
  }
  
  Widget _buildHabitBreakdown() {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    
    if (_habitStats.isEmpty) {
      return Container(
        padding: EdgeInsets.all(4.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: primaryBrown.withOpacity(0.2)),
        ),
        child: Center(
          child: Text(
            'No habit data yet. Start tracking!',
            style: TextStyle(
              fontSize: 14.sp,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ),
      );
    }
    
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryBrown.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: _habitStats.take(5).map((habit) {
          final isStruggling = habit.completionRate < 50;
          final isExcellent = habit.completionRate >= 80;
          
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 0.8.h),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    habit.habitName,
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 2.w),
                Text(
                  '${habit.completionRate.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.bold,
                    color: isExcellent ? Colors.green : (isStruggling ? Colors.red : Theme.of(context).colorScheme.onSurface),
                  ),
                ),
                SizedBox(width: 1.w),
                if (habit.currentStreak > 0)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 1.5.w, vertical: 0.3.h),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '🔥 ${habit.currentStreak}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800,
                      ),
                    ),
                  ),
                if (isStruggling)
                  Padding(
                    padding: EdgeInsets.only(left: 1.w),
                    child: Text('⚠️', style: TextStyle(fontSize: 12.sp)),
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
  
  // ===== ACHIEVEMENT WIDGETS =====
  
  Widget _buildAchievementCard(Achievement achievement) {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color darkBrown = Color(0xFF2C1810);
    
    final isUnlocked = achievement.isUnlocked;
    
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.amber.withOpacity(0.1) : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isUnlocked ? Colors.amber : primaryBrown.withOpacity(0.2),
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked ? [
          BoxShadow(
            color: Colors.amber.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ] : null,
      ),
      child: Row(
        children: [
          // Medal Icon
          Container(
            width: 14.w,
            height: 14.w,
            decoration: BoxDecoration(
              color: isUnlocked ? Colors.amber.withOpacity(0.2) : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                achievement.icon,
                style: TextStyle(
                  fontSize: 24.sp,
                  color: isUnlocked ? null : Colors.grey,
                ),
              ),
            ),
          ),
          
          SizedBox(width: 3.w),
          
          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? Theme.of(context).colorScheme.onSurface : Colors.grey,
                  ),
                ),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: isUnlocked ? Theme.of(context).colorScheme.onSurface.withOpacity(0.7) : Colors.grey.shade500,
                  ),
                ),
                SizedBox(height: 0.5.h),
                // Progress bar
                if (!isUnlocked)
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: achievement.progress,
                            minHeight: 6,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            valueColor: const AlwaysStoppedAnimation(Colors.amber),
                          ),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      Text(
                        '${achievement.currentValue}/${achievement.requiredValue}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Unlocked badge
          if (isUnlocked)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 0.5.h),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '✓',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ===== TAB 4: JOURNAL =====
  Widget _buildJournalTab() {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color warmAmber = Color(0xFFD4A574);
    
    final moodEmojis = {1: '😔', 2: '😐', 3: '😊', 4: '😄', 5: '😍'};
    
    if (_journalEntries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.book_outlined, size: 60, color: Colors.grey[400]),
            SizedBox(height: 2.h),
            Text(
              'No journal entries yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              'Start writing your thoughts in the Journal tab',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: EdgeInsets.all(4.w),
      itemCount: _journalEntries.length,
      itemBuilder: (context, index) {
        final entry = _journalEntries[index];
        final moodRating = entry['mood_rating'] as int? ?? 3;
        final mood = moodEmojis[moodRating] ?? '😊';
        final content = entry['content']?.toString() ?? '';
        final date = entry['date']?.toString() ?? entry['created_at']?.toString().split('T')[0] ?? '';
        final wordCount = entry['word_count'] as int? ?? 0;
        final hasPhoto = entry['has_photo'] == true || (entry['image_urls'] as List?)?.isNotEmpty == true;
        final hasAudio = entry['audio_url']?.toString().isNotEmpty == true;
        
        // Parse date for display
        DateTime? parsedDate;
        try {
          parsedDate = DateTime.parse(date);
        } catch (_) {}
        final displayDate = parsedDate != null 
            ? '${parsedDate.day}/${parsedDate.month}/${parsedDate.year}'
            : date;
        
        return GestureDetector(
          onTap: () => _showJournalEntryDetail(entry),
          child: Container(
            margin: EdgeInsets.only(bottom: 2.h),
            padding: EdgeInsets.all(4.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: warmAmber.withOpacity(0.3)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Mood + Date + Attachments
                Row(
                  children: [
                    Text(mood, style: TextStyle(fontSize: 28)),
                    SizedBox(width: 3.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayDate,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: primaryBrown,
                            ),
                          ),
                          Text(
                            '$wordCount words',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Attachment icons
                    if (hasPhoto)
                      Padding(
                        padding: EdgeInsets.only(right: 2.w),
                        child: Icon(Icons.image, size: 20, color: Colors.green),
                      ),
                    if (hasAudio)
                      Icon(Icons.audiotrack, size: 20, color: Colors.blue),
                  ],
                ),
                SizedBox(height: 1.5.h),
                // Content preview
                Text(
                  content.length > 150 ? '${content.substring(0, 150)}...' : content,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showJournalEntryDetail(Map<String, dynamic> entry) {
    const Color primaryBrown = Color(0xFF8B4513);
    const Color warmAmber = Color(0xFFD4A574);
    
    final moodEmojis = {1: '😔', 2: '😐', 3: '😊', 4: '😄', 5: '😍'};
    final moodRating = entry['mood_rating'] as int? ?? 3;
    final mood = moodEmojis[moodRating] ?? '😊';
    final content = entry['content']?.toString() ?? '';
    final date = entry['date']?.toString() ?? '';
    final wordCount = entry['word_count'] as int? ?? 0;
    final imageUrls = entry['image_urls'] as List? ?? [];
    final audioUrl = entry['audio_url']?.toString() ?? '';
    final entryId = entry['id']?.toString() ?? '';
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: 80.h,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 12.w,
              height: 0.5.h,
              margin: EdgeInsets.symmetric(vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: Row(
                children: [
                  Text(mood, style: TextStyle(fontSize: 36)),
                  SizedBox(width: 3.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          date,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: primaryBrown,
                          ),
                        ),
                        Text(
                          '$wordCount words',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Delete button
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text('Delete Entry?'),
                          content: Text('This action cannot be undone.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      
                      if (confirm == true && entryId.isNotEmpty) {
                        try {
                          await _supabaseService.deleteJournalEntry(entryId);
                          Navigator.pop(context);
                          _loadJournalEntries(); // Refresh
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Entry deleted'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to delete: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
            Divider(height: 3.h),
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(4.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Images
                    if (imageUrls.isNotEmpty) ...[
                      Text(
                        'Photos',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      SizedBox(
                        height: 15.h,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: imageUrls.length,
                          itemBuilder: (ctx, i) => Container(
                            margin: EdgeInsets.only(right: 2.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: warmAmber.withOpacity(0.3)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(
                                imageUrls[i].toString(),
                                height: 15.h,
                                width: 25.w,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  height: 15.h,
                                  width: 25.w,
                                  color: Colors.grey[200],
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 2.h),
                    ],
                    // Audio
                    if (audioUrl.isNotEmpty) ...[
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.audiotrack, color: Colors.blue),
                            SizedBox(width: 2.w),
                            Text('Audio attached', style: TextStyle(color: Colors.blue)),
                          ],
                        ),
                      ),
                      SizedBox(height: 2.h),
                    ],
                    // Journal text
                    Text(
                      content,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

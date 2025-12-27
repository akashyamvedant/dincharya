import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../core/app_export.dart';
import './widgets/filter_chip_widget.dart';
import './widgets/session_card_widget.dart';

class GuidedSessionsHub extends StatefulWidget {
  const GuidedSessionsHub({super.key});

  @override
  State<GuidedSessionsHub> createState() => _GuidedSessionsHubState();
}

class _GuidedSessionsHubState extends State<GuidedSessionsHub>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  int _currentBottomIndex = 1; // Guided tab active
  String _selectedDurationFilter = 'All';
  String _selectedDifficultyFilter = 'All';
  // Removed unused fields: _selectedTypeFilter and _isRefreshing

  // Mock data for sessions
  final List<Map<String, dynamic>> _meditationSessions = [
    {
      "id": 1,
      "title": "Morning Mindfulness",
      "description":
          "Start your day with peaceful awareness and gentle breathing techniques for mental clarity.",
      "duration": "15 min",
      "difficulty": 3,
      "imageUrl":
          "https://images.pexels.com/photos/3822622/pexels-photo-3822622.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "meditation",
      "isDownloaded": true,
      "isPremium": false,
      "breathingPattern": "4-7-8"
    },
    {
      "id": 2,
      "title": "Deep Sleep Meditation",
      "description":
          "Drift into peaceful slumber with guided relaxation and soothing nature sounds.",
      "duration": "30 min",
      "difficulty": 2,
      "imageUrl":
          "https://images.pexels.com/photos/3771115/pexels-photo-3771115.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "meditation",
      "isDownloaded": false,
      "isPremium": true,
      "breathingPattern": "box"
    },
    {
      "id": 3,
      "title": "Stress Relief Session",
      "description":
          "Release tension and anxiety through mindful breathing and body awareness practices.",
      "duration": "20 min",
      "difficulty": 4,
      "imageUrl":
          "https://images.pexels.com/photos/4056723/pexels-photo-4056723.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "meditation",
      "isDownloaded": true,
      "isPremium": false,
      "breathingPattern": "coherent"
    }
  ];

  final List<Map<String, dynamic>> _pranayamaSessions = [
    {
      "id": 4,
      "title": "Anulom Vilom",
      "description":
          "Alternate nostril breathing technique for balancing energy and calming the nervous system.",
      "duration": "10 min",
      "difficulty": 2,
      "imageUrl":
          "https://images.pexels.com/photos/4056723/pexels-photo-4056723.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "pranayama",
      "isDownloaded": true,
      "isPremium": false,
      "breathingPattern": "alternate"
    },
    {
      "id": 5,
      "title": "Bhramari Pranayama",
      "description":
          "Humming bee breath technique for reducing stress and improving concentration levels.",
      "duration": "12 min",
      "difficulty": 3,
      "imageUrl":
          "https://images.pexels.com/photos/3822622/pexels-photo-3822622.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "pranayama",
      "isDownloaded": false,
      "isPremium": true,
      "breathingPattern": "humming"
    },
    {
      "id": 6,
      "title": "Kapalbhati",
      "description":
          "Skull shining breath for detoxification and energizing the body and mind.",
      "duration": "8 min",
      "difficulty": 4,
      "imageUrl":
          "https://images.pexels.com/photos/3771115/pexels-photo-3771115.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "pranayama",
      "isDownloaded": true,
      "isPremium": false,
      "breathingPattern": "rapid"
    }
  ];

  final List<Map<String, dynamic>> _yogaSessions = [
    {
      "id": 7,
      "title": "Sun Salutation Flow",
      "description":
          "Complete sequence of 12 poses to energize body and mind with flowing movements.",
      "duration": "25 min",
      "difficulty": 3,
      "imageUrl":
          "https://images.pexels.com/photos/3822622/pexels-photo-3822622.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "yoga",
      "isDownloaded": true,
      "isPremium": false,
      "poseSequence": ["mountain", "forward_fold", "plank", "cobra"]
    },
    {
      "id": 8,
      "title": "Gentle Evening Yoga",
      "description":
          "Relaxing poses and stretches to unwind after a long day and prepare for rest.",
      "duration": "35 min",
      "difficulty": 2,
      "imageUrl":
          "https://images.pexels.com/photos/4056723/pexels-photo-4056723.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "yoga",
      "isDownloaded": false,
      "isPremium": true,
      "poseSequence": ["child", "cat_cow", "pigeon", "savasana"]
    },
    {
      "id": 9,
      "title": "Power Yoga Flow",
      "description":
          "Dynamic and challenging sequence to build strength, flexibility and endurance.",
      "duration": "45 min",
      "difficulty": 5,
      "imageUrl":
          "https://images.pexels.com/photos/3771115/pexels-photo-3771115.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=1",
      "type": "yoga",
      "isDownloaded": true,
      "isPremium": false,
      "poseSequence": ["warrior", "triangle", "crow", "headstand"]
    }
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        return _meditationSessions;
      case 1:
        return _pranayamaSessions;
      case 2:
        return _yogaSessions;
      default:
        return _meditationSessions;
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
        int duration = int.parse((session["duration"] as String).split(' ')[0]);
        switch (_selectedDurationFilter) {
          case '5-15 min':
            return duration >= 5 && duration <= 15;
          case '16-30 min':
            return duration >= 16 && duration <= 30;
          case '30+ min':
            return duration > 30;
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
    // Simulate network call
    await Future.delayed(const Duration(seconds: 2));

    // Refresh the data
    setState(() {
      // Trigger rebuild to refresh the UI
    });
  }

  void _onSessionTap(Map<String, dynamic> session) {
    Navigator.pushNamed(context, '/audio-player', arguments: session);
  }

  void _onSessionLongPress(Map<String, dynamic> session) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: AppTheme.lightTheme.colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.outline,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'favorite_border',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              title: Text('Add to Favorites'),
              onTap: () => Navigator.pop(context),
            ),
            if (session["isPremium"] == false)
              ListTile(
                leading: CustomIconWidget(
                  iconName: 'download',
                  color: AppTheme.lightTheme.colorScheme.primary,
                  size: 24,
                ),
                title: Text('Download'),
                onTap: () => Navigator.pop(context),
              ),
            ListTile(
              leading: CustomIconWidget(
                iconName: 'share',
                color: AppTheme.lightTheme.colorScheme.primary,
                size: 24,
              ),
              title: Text('Share'),
              onTap: () => Navigator.pop(context),
            ),
            SizedBox(height: 2.h),
          ],
        ),
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
            // Search Bar
            Container(
              padding: EdgeInsets.all(4.w),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search sessions...',
                  prefixIcon: Padding(
                    padding: EdgeInsets.all(3.w),
                    child: CustomIconWidget(
                      iconName: 'search',
                      color: AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: CustomIconWidget(
                            iconName: 'clear',
                            color: AppTheme
                                .lightTheme.colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        )
                      : null,
                ),
                onChanged: (value) => setState(() {}),
              ),
            ),

            // Tab Bar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: AppTheme.lightTheme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.lightTheme.colorScheme.outline
                      .withValues(alpha: 0.2),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppTheme.lightTheme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: AppTheme.lightTheme.colorScheme.onPrimary,
                unselectedLabelColor:
                    AppTheme.lightTheme.colorScheme.onSurfaceVariant,
                tabs: const [
                  Tab(text: 'Meditation'),
                  Tab(text: 'Pranayama'),
                  Tab(text: 'Yoga'),
                ],
                onTap: (index) => setState(() {}),
              ),
            ),

            SizedBox(height: 2.h),

            // Filter Chips
            SizedBox(
              height: 6.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 4.w),
                children: [
                  FilterChipWidget(
                    label: 'Duration',
                    selectedValue: _selectedDurationFilter,
                    options: const ['All', '5-15 min', '16-30 min', '30+ min'],
                    onChanged: (value) {
                      setState(() {
                        _selectedDurationFilter = value;
                      });
                    },
                  ),
                  SizedBox(width: 2.w),
                  FilterChipWidget(
                    label: 'Difficulty',
                    selectedValue: _selectedDifficultyFilter,
                    options: const [
                      'All',
                      'Beginner',
                      'Intermediate',
                      'Advanced'
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDifficultyFilter = value;
                      });
                    },
                  ),
                ],
              ),
            ),

            SizedBox(height: 2.h),

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

  Widget _buildSessionsList(List<Map<String, dynamic>> sessions) {
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        final session = sessions[index];
        return SessionCardWidget(
          session: session,
          onTap: () => _onSessionTap(session),
          onLongPress: () => _onSessionLongPress(session),
          showBreathingAnimation:
              _tabController.index == 0, // Only for meditation
        );
      },
    );
  }
}

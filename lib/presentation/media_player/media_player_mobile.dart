// Mobile implementation of Media Player (Android/iOS)
// Now plays media INSIDE the app instead of external apps

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/app_export.dart';
import '../../core/constants/ad_constants.dart';
import '../../services/ads_service.dart';
import '../../widgets/ads/native_ad_widget.dart';
import '../../widgets/ads/banner_ad_widget.dart';
import '../../services/guided_session_service.dart';
import '../../services/yoga_pose_service.dart';
import '../../services/yoga_tts_service.dart';
import '../../services/tts_audio_service.dart';
import '../yoga_practice/widgets/practice_tab.dart';
import './widgets/in_app_youtube_player.dart';
import './widgets/in_app_video_player.dart';
import './widgets/in_app_audio_player.dart';

/// Mobile-specific Media Player Widget with Dincharya warm brown theme
/// Now plays YouTube, video, and audio INSIDE the app
class MediaPlayerPlatformWidget extends StatefulWidget {
  final Map<String, dynamic> session;

  const MediaPlayerPlatformWidget({
    super.key,
    required this.session,
  });

  @override
  State<MediaPlayerPlatformWidget> createState() => _MediaPlayerPlatformWidgetState();
}

class _MediaPlayerPlatformWidgetState extends State<MediaPlayerPlatformWidget>
    with TickerProviderStateMixin {
  bool _hasPlayedMedia = false;
  bool _sessionCompleted = false;
  final GuidedSessionService _guidedService = GuidedSessionService();

  // Theme colors resolved via Theme.of(context) in build methods
  static const Color _primaryBrown = Color(0xFF8B4513); // Fallback; prefer Theme.of(context).colorScheme.primary
  static const Color _lightBrown = Color(0xFFD4A574);

  // Track current playback position for resume
  int _currentPositionSeconds = 0;

  // Yoga pose data (if linked)
  final YogaPoseService _yogaPoseService = YogaPoseService();
  Map<String, dynamic>? _linkedPose;
  List<Map<String, dynamic>> _poseSteps = [];
  bool _isPoseLoading = true;
  bool _stepsExpanded = false;
  bool _literatureInHindi = true; // Default Hindi
  bool _benefitsExpanded = false;
  bool _precautionsExpanded = false;
  int _currentBookPage = 0;
  PageController? _bookPageController;

  // Tab controller for Theory/Practical (only used when pose linked)
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadLinkedPose();
  }

  void _initTabController() {
    _tabController?.dispose();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    // Stop all singleton TTS audio to prevent zombie playback
    YogaTtsService().stop();
    TtsAudioService().stop();
    _tabController?.dispose();
    _bookPageController?.dispose();
    super.dispose();
  }

  Future<void> _loadLinkedPose() async {
    try {
      final sessionId = widget.session['id']?.toString();
      debugPrint('🧘 _loadLinkedPose START — sessionId=$sessionId');
      debugPrint('🧘 session keys: ${widget.session.keys.toList()}');
      
      if (sessionId == null || sessionId.isEmpty) {
        debugPrint('🧘 _loadLinkedPose: sessionId is null/empty, skipping');
        if (mounted) setState(() => _isPoseLoading = false);
        return;
      }

      final pose = await _yogaPoseService.getPoseBySessionId(sessionId);
      debugPrint('🧘 _loadLinkedPose: pose result = ${pose != null ? pose['name'] : 'NULL'}');

      if (pose != null) {
        final poseId = pose['id']?.toString() ?? '';
        debugPrint('🧘 _loadLinkedPose: fetching steps for poseId=$poseId');
        final steps = await _yogaPoseService.getPoseSteps(poseId);
        debugPrint('🧘 _loadLinkedPose: got ${steps.length} steps');

        if (mounted) {
          _initTabController();
          setState(() {
            _linkedPose = pose;
            _poseSteps = steps;
            _isPoseLoading = false;
          });
          debugPrint('🧘 _loadLinkedPose SUCCESS — pose=${pose['name']}, steps=${steps.length}');
          return;
        }
      }

      if (mounted) setState(() => _isPoseLoading = false);
      debugPrint('🧘 _loadLinkedPose: No linked pose found, using fallback UI');
    } catch (e, stackTrace) {
      debugPrint('🧘 _loadLinkedPose ERROR: $e');
      debugPrint('🧘 Stack: $stackTrace');
      if (mounted) setState(() => _isPoseLoading = false);
    }
  }

  void _onMediaStarted() {
    setState(() => _hasPlayedMedia = true);
  }

  void _onMediaCompleted() {
    setState(() => _sessionCompleted = true);
  }

  void _onPositionChanged(int positionSeconds) {
    _currentPositionSeconds = positionSeconds;
  }

  Future<bool> _onWillPop() async {
    // Save session progress for resume
    final sessionId = widget.session['id'] as String?;
    final title = widget.session['title'] as String? ?? 'Session';
    final category = widget.session['category'] as String? ?? 'meditation';
    final totalDuration = (widget.session['duration'] as int?) ?? 600;

    if (sessionId != null && _currentPositionSeconds > 5) {
      await _guidedService.saveSessionProgress(
        sessionId: sessionId,
        sessionTitle: title,
        category: category,
        positionSeconds: _currentPositionSeconds,
        totalDuration: totalDuration,
      );
    }

    // Show interstitial ad when leaving after playing media (natural stopping point)
    if (_hasPlayedMedia) {
      await AdsService().showInterstitialAdWithCapping(InterstitialPlacement.sessionEnded);
    }

    // Stop all TTS audio to prevent zombie playback after leaving
    YogaTtsService().stop();
    TtsAudioService().stop();

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.session['title'] as String? ?? 'Session';
    final titleHindi = widget.session['title_hindi'] as String? ?? '';
    final description = widget.session['description'] as String? ?? '';
    final duration = widget.session['duration'];
    final difficulty = widget.session['difficulty'] as int? ?? 3;
    final category = widget.session['category'] as String? ?? 'meditation';
    final mediaType = widget.session['media_type'] as String? ?? 'youtube';
    
    // Select correct URL field based on media_type
    // youtube → youtube_url, video → video_url, audio → audio_url
    String mediaUrl = '';
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        mediaUrl = widget.session['youtube_url'] as String? ?? '';
        break;
      case 'video':
        mediaUrl = widget.session['video_url'] as String? ?? '';
        break;
      case 'audio':
        mediaUrl = widget.session['audio_url'] as String? ?? '';
        break;
      default:
        mediaUrl = widget.session['youtube_url'] as String? ?? 
                   widget.session['video_url'] as String? ?? 
                   widget.session['audio_url'] as String? ?? '';
    }

    // ── When pose is linked: Show tabbed layout ──
    if (_linkedPose != null) {
      return _buildTabbedLayout(
        title: title,
        titleHindi: titleHindi,
        description: description,
        duration: duration,
        difficulty: difficulty,
        category: category,
        mediaType: mediaType,
        mediaUrl: mediaUrl,
      );
    }

    // ── Fallback: Original single-scroll layout ──
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: _primaryBrown,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () async {
              await _onWillPop();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(4.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInAppPlayer(mediaType: mediaType, mediaUrl: mediaUrl, title: title, titleHindi: titleHindi, category: category, sessionId: widget.session['id'] as String?, duration: duration),
              SizedBox(height: 3.h),
              _buildSessionInfoCard(title: title, titleHindi: titleHindi, duration: duration, difficulty: difficulty, mediaType: mediaType, category: category),
              SizedBox(height: 2.h),
              // Description Card
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.description, color: Theme.of(context).colorScheme.primary, size: 22), SizedBox(width: 2.w), Text('About This Session', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface))]),
                    SizedBox(height: 1.5.h),
                    Text(description, style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6)),
                  ],
                ),
              ),
              SizedBox(height: 2.h),
              // Benefits Card (hardcoded)
              Container(
                padding: EdgeInsets.all(4.w),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [Icon(Icons.star, color: Theme.of(context).colorScheme.primary, size: 22), SizedBox(width: 2.w), Text('Benefits', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface))]),
                    SizedBox(height: 1.5.h),
                    ..._getBenefits(category).map((b) => Padding(
                      padding: EdgeInsets.only(bottom: 1.h),
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary, size: 20), SizedBox(width: 2.w), Expanded(child: Text(b, style: TextStyle(fontSize: 14.sp, color: Theme.of(context).colorScheme.onSurfaceVariant)))]),
                    )),
                  ],
                ),
              ),
              SizedBox(height: 4.h),
              // Adaptive Banner at bottom of fallback layout
              const AdaptiveBannerAdWidget(placement: BannerPlacement.sessionDetail),
              SizedBox(height: 2.h),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Tabbed Layout (when pose is linked) ─────────────
  Widget _buildTabbedLayout({
    required String title,
    required String titleHindi,
    required String description,
    required dynamic duration,
    required int difficulty,
    required String category,
    required String mediaType,
    required String mediaUrl,
  }) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _onWillPop();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(title, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
            onPressed: () async {
              await _onWillPop();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: Column(
          children: [
            SizedBox(height: 1.h),
            // TabBar
            Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'विद्या / Theory'),
                  Tab(text: 'अभ्यास / Practical'),
                ],
              ),
            ),
            SizedBox(height: 1.h),
            // TabBarView
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ── Tab 1: Theory ──
                  SingleChildScrollView(
                    padding: EdgeInsets.all(4.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Video/Audio Player
                        _buildInAppPlayer(mediaType: mediaType, mediaUrl: mediaUrl, title: title, titleHindi: titleHindi, category: category, sessionId: widget.session['id'] as String?, duration: duration),
                        SizedBox(height: 2.h),
                        // Literature (book-style)
                        _buildLiteratureSection(),
                        SizedBox(height: 2.h),
                        // Native Ad between content sections
                        const NativeAdWidget(placement: NativePlacement.sessionTheory),
                        SizedBox(height: 2.h),
                        // Benefits from DB
                        _buildPoseBenefitsCard(),
                        SizedBox(height: 2.h),
                        // Precautions from DB
                        _buildPosePrecautionsCard(),
                        SizedBox(height: 2.h),
                        // Steps Overview
                        if (_poseSteps.isNotEmpty) ...[
                          _buildStepsOverviewCard(),
                          SizedBox(height: 2.h),
                        ],
                        // Adaptive Banner at bottom of Theory tab
                        const AdaptiveBannerAdWidget(placement: BannerPlacement.sessionDetail),
                        SizedBox(height: 4.h),
                      ],
                    ),
                  ),
                  // ── Tab 2: Practical ──
                  PracticeTab(
                    pose: _linkedPose!,
                    steps: _poseSteps,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Session Info Card (reusable) ─────────────
  Widget _buildSessionInfoCard({
    required String title,
    required String titleHindi,
    required dynamic duration,
    required int difficulty,
    required String mediaType,
    required String category,
  }) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightBrown.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
          if (titleHindi.isNotEmpty) ...[
            SizedBox(height: 0.5.h),
            Text(titleHindi, style: TextStyle(fontSize: 16.sp, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          SizedBox(height: 2.h),
          Wrap(
            spacing: 2.w,
            runSpacing: 1.h,
            children: [
              _buildStatChip(icon: Icons.timer, label: _formatDuration(duration), color: _primaryBrown),
              _buildStatChip(icon: Icons.signal_cellular_alt, label: _getDifficultyLabel(difficulty), color: _getDifficultyColor(difficulty)),
              _buildStatChip(icon: _getMediaIcon(mediaType), label: _getMediaLabel(mediaType), color: _getMediaColor(mediaType)),
              _buildStatChip(icon: Icons.category, label: category.toUpperCase(), color: _getCategoryColor(category)),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the appropriate in-app player based on media_type
  Widget _buildInAppPlayer({
    required String mediaType,
    required String mediaUrl,
    required String title,
    required String? titleHindi,
    required String category,
    required String? sessionId,
    dynamic duration,
  }) {
    // Mark media as started when player is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_hasPlayedMedia) {
        _onMediaStarted();
      }
    });

    // Handle empty URL
    if (mediaUrl.isEmpty) {
      return _buildNoMediaWidget();
    }

    // Use media_type to select player
    // youtube → YouTube Player (no caching - YouTube ToS)
    // video → Video Player with auto-caching
    // audio → Audio Player with auto-caching
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return InAppYoutubePlayer(
          videoUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          startPositionSeconds: widget.session['last_position_seconds'] as int? ?? 0,
          onPositionChanged: _onPositionChanged,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );

      case 'video':
        return InAppVideoPlayer(
          videoUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          sessionId: sessionId,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );

      case 'audio':
        return InAppAudioPlayer(
          audioUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          category: category,
          sessionId: sessionId,
          durationSeconds: duration is int ? duration : null,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );

      default:
        // Fallback - try YouTube player
        return InAppYoutubePlayer(
          videoUrl: mediaUrl,
          title: title,
          titleHindi: titleHindi,
          onComplete: _onMediaCompleted,
          onBack: () async {
            await _onWillPop();
            if (mounted && context.mounted) Navigator.of(context).pop();
          },
        );
    }
  }

  Widget _buildNoMediaWidget() {
    return Container(
      width: double.infinity,
      height: 25.h,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _lightBrown.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam_off, size: 48, color: Colors.grey[400]),
          SizedBox(height: 2.h),
          Text(
            'No Media Available',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            'Media URL is not configured for this session',
            style: TextStyle(
              fontSize: 12.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 1.5.w),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 13.sp,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Enhanced Pose Content Widgets ──────────────────

  /// Multi-page book literature with PageView
  Widget _buildLiteratureSection() {
    final hindiText = _linkedPose?['literature_content_hindi'] ?? '';
    final englishText = _linkedPose?['literature_content'] ?? '';
    final rawLiterature = _literatureInHindi
        ? (hindiText.toString().isNotEmpty ? hindiText : englishText)
        : (englishText.toString().isNotEmpty ? englishText : hindiText);
    if (rawLiterature.toString().isEmpty) return const SizedBox.shrink();

    final hasMultiLang = hindiText.toString().isNotEmpty && englishText.toString().isNotEmpty;

    // Split into pages by ---PAGE--- delimiter (normalize escaped \n first)
    final normalizedLit = rawLiterature.toString().replaceAll(r'\n', '\n');
    final pages = normalizedLit.split('---PAGE---')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toList();

    if (pages.isEmpty) return const SizedBox.shrink();

    // Initialize page controller if needed
    _bookPageController ??= PageController();

    return Column(
      children: [
        // Book container with fixed height
        Container(
          height: 55.h,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.brown.withOpacity(0.25),
                blurRadius: 16,
                offset: const Offset(4, 6),
              ),
              BoxShadow(
                color: Colors.brown.withOpacity(0.08),
                blurRadius: 4,
                offset: const Offset(-2, 0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // PageView of book pages
                PageView.builder(
                  controller: _bookPageController,
                  itemCount: pages.length,
                  onPageChanged: (idx) => setState(() => _currentBookPage = idx),
                  itemBuilder: (context, index) {
                    return _buildBookPage(pages[index], index, pages.length);
                  },
                ),

                // Top header bar with title + language toggle
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF6D4C2A).withOpacity(0.95),
                          const Color(0xFF8B5E3C),
                        ],
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.auto_stories, color: Color(0xFFFFE0B2), size: 20),
                        SizedBox(width: 2.w),
                        Expanded(
                          child: Text(
                            _literatureInHindi ? 'साहित्य' : 'Literature',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFFFF8E7),
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        if (hasMultiLang)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _literatureInHindi = !_literatureInHindi;
                                _currentBookPage = 0;
                                _bookPageController?.jumpToPage(0);
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.4.h),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.translate, color: Color(0xFFFFF8E7), size: 14),
                                  SizedBox(width: 1.w),
                                  Text(
                                    _literatureInHindi ? 'EN' : 'हि',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFFFFF8E7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Book spine shadow on left
                Positioned(
                  left: 0, top: 0, bottom: 0, width: 10,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF5D4037).withOpacity(0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // Bottom page indicator + arrows
                if (pages.length > 1)
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 0.8.h),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            const Color(0xFFF3E4C8).withOpacity(0),
                            const Color(0xFFEDD9B3),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous page
                          GestureDetector(
                            onTap: _currentBookPage > 0 ? () {
                              _bookPageController?.previousPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            } : null,
                            child: Icon(
                              Icons.arrow_back_ios,
                              size: 16,
                              color: _currentBookPage > 0
                                  ? const Color(0xFF5D4037)
                                  : const Color(0xFF5D4037).withOpacity(0.2),
                            ),
                          ),
                          SizedBox(width: 3.w),
                          // Page dots
                          ...List.generate(pages.length, (i) => Container(
                            width: _currentBookPage == i ? 18 : 7,
                            height: 7,
                            margin: EdgeInsets.symmetric(horizontal: 0.5.w),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: _currentBookPage == i
                                  ? const Color(0xFF6D4C2A)
                                  : const Color(0xFF6D4C2A).withOpacity(0.25),
                            ),
                          )),
                          SizedBox(width: 3.w),
                          // Next page
                          GestureDetector(
                            onTap: _currentBookPage < pages.length - 1 ? () {
                              _bookPageController?.nextPage(
                                duration: const Duration(milliseconds: 400),
                                curve: Curves.easeInOut,
                              );
                            } : null,
                            child: Icon(
                              Icons.arrow_forward_ios,
                              size: 16,
                              color: _currentBookPage < pages.length - 1
                                  ? const Color(0xFF5D4037)
                                  : const Color(0xFF5D4037).withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: 0.5.h),
        // Page number text
        if (pages.length > 1)
          Text(
            '${_literatureInHindi ? 'पृष्ठ' : 'Page'} ${_currentBookPage + 1} / ${pages.length}',
            style: TextStyle(
              fontSize: 11.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
      ],
    );
  }

  /// Build a single book page with aged paper design
  Widget _buildBookPage(String content, int pageIndex, int totalPages) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF8F0E0),
            Color(0xFFF3E4C8),
            Color(0xFFEDD9B3),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(5.w, 6.h, 4.w, 5.h),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ornamental opening on first page
            if (pageIndex == 0)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(bottom: 1.h),
                  child: Text(
                    '❦',
                    style: TextStyle(
                      fontSize: 22.sp,
                      color: const Color(0xFF8B6914).withOpacity(0.6),
                    ),
                  ),
                ),
              ),
            // Page content
            ..._parseLiterature(content),
            SizedBox(height: 2.h),
            // Ornamental closing
            Center(
              child: Text(
                pageIndex == totalPages - 1 ? '— ✦ —' : '• • •',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: const Color(0xFF8B6914).withOpacity(0.4),
                  letterSpacing: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Parse literature text with book-style formatting
  /// Supports: **bold**, *italic*, {{IMG:url}} centered, {{IMG_LEFT:url}} inline-left
  List<Widget> _parseLiterature(String text) {
    // Normalize: handle literal \n stored as escaped chars in DB
    final normalized = text.replaceAll(r'\n', '\n');
    final lines = normalized.split('\n');
    final widgets = <Widget>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      if (trimmed.startsWith('{{IMG_LEFT:') && trimmed.endsWith('}}')) {
        // Inline image LEFT: image on left, text wraps right (real book style)
        final url = trimmed.substring(11, trimmed.length - 2);
        // Collect subsequent non-empty lines for the text block
        final textLines = <String>[];
        i++;
        while (i < lines.length) {
          final nextTrimmed = lines[i].trim();
          if (nextTrimmed.isEmpty || nextTrimmed.startsWith('{{')) break;
          textLines.add(lines[i]);
          i++;
        }
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image on left (38% width)
              Container(
                width: 38.w,
                constraints: BoxConstraints(maxHeight: 25.h),
                margin: EdgeInsets.only(right: 3.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.4), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.brown.withOpacity(0.12),
                      blurRadius: 6,
                      offset: const Offset(2, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (ctx, url) => SizedBox(
                      height: 15.h,
                      child: Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: const Color(0xFF8B6914),
                        ),
                      ),
                    ),
                    errorWidget: (ctx, url, err) => SizedBox(
                      height: 12.h,
                      child: Center(child: Icon(Icons.image_not_supported, color: Theme.of(context).colorScheme.secondary, size: 30)),
                    ),
                  ),
                ),
              ),
              // Text on right
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: textLines.map((tl) {
                    if (tl.trim().startsWith('- ')) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: 0.3.h),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: EdgeInsets.only(top: 0.5.h),
                              child: Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF8B6914).withOpacity(0.7))),
                            ),
                            SizedBox(width: 1.5.w),
                            Expanded(child: _buildRichText(tl.trim().substring(2), 13.sp, 1.5)),
                          ],
                        ),
                      );
                    }
                    return Padding(
                      padding: EdgeInsets.only(bottom: 0.3.h),
                      child: _buildRichText(tl, 13.sp, 1.5),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ));
        continue; // Don't increment i again
      } else if (trimmed.startsWith('{{IMG:') && trimmed.endsWith('}}')) {
        // Full-width centered image
        final url = trimmed.substring(6, trimmed.length - 2);
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 1.5.h),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 65.w, maxHeight: 30.h),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.5), width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.brown.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(2, 3),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  placeholder: (ctx, url) => SizedBox(
                    height: 20.h,
                    child: Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: const Color(0xFF8B6914),
                      ),
                    ),
                  ),
                  errorWidget: (ctx, url, err) => SizedBox(
                    height: 15.h,
                    child: Center(child: Icon(Icons.image_not_supported, color: Theme.of(context).colorScheme.secondary, size: 40)),
                  ),
                ),
              ),
            ),
          ),
        ));
      } else if (trimmed.isEmpty) {
        widgets.add(SizedBox(height: 1.h));
      } else if (line.startsWith('## ')) {
        // Chapter heading with underline
        widgets.add(Padding(
          padding: EdgeInsets.only(top: 1.5.h, bottom: 0.8.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                line.substring(3),
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF3E2723),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 0.5.h),
              Container(
                width: 40,
                height: 2.5,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B6914).withOpacity(0.6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ));
      } else if (line.startsWith('- ')) {
        // Bullet point with decorative marker + rich text
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 0.6.h, left: 2.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 0.6.h),
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF8B6914).withOpacity(0.7),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: _buildRichText(line.substring(2), 15.sp, 1.6),
              ),
            ],
          ),
        ));
      } else {
        // Body text — book paragraph style with markdown support
        widgets.add(Padding(
          padding: EdgeInsets.only(bottom: 0.4.h),
          child: _buildRichText(line, 15.sp, 1.75),
        ));
      }
      i++;
    }
    return widgets;
  }

  /// Build RichText with **bold** and *italic* markdown support
  Widget _buildRichText(String text, double fontSize, double lineHeight) {
    final spans = <TextSpan>[];
    // Regex: **bold** first, then *italic*
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Add plain text before this match
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }

      if (match.group(1) != null) {
        // **bold**
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF5D4037),
          ),
        ));
      } else if (match.group(2) != null) {
        // *italic*
        spans.add(TextSpan(
          text: match.group(2),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }

      lastEnd = match.end;
    }

    // Remaining text
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: fontSize,
          color: const Color(0xFF3E2723),
          height: lineHeight,
          letterSpacing: 0.2,
        ),
        children: spans,
      ),
    );
  }

  /// Benefits card — collapsible
  Widget _buildPoseBenefitsCard() {
    final benefitsRaw = _linkedPose?['benefits'];
    if (benefitsRaw == null) return const SizedBox.shrink();

    final benefits = benefitsRaw is List
        ? List<String>.from(benefitsRaw)
        : benefitsRaw.toString().split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (benefits.isEmpty) return const SizedBox.shrink();

    const previewCount = 2;
    final showAll = _benefitsExpanded || benefits.length <= previewCount;
    final displayBenefits = showAll ? benefits : benefits.sublist(0, previewCount);

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF4A7C59).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _benefitsExpanded = !_benefitsExpanded),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Color(0xFF4A7C59), size: 22),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Benefits / लाभ (${benefits.length})',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _benefitsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down, color: const Color(0xFF4A7C59), size: 28),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.5.h),
          Stack(
            children: [
              Column(
                children: displayBenefits.map((b) => Padding(
                  padding: EdgeInsets.only(bottom: 0.8.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_circle_outline, color: Color(0xFF4A7C59), size: 20),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          b.toString().replaceAll(RegExp(r'^[-•]\s*'), ''),
                          style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
              if (!showAll)
                Positioned(
                  bottom: 0, left: 0, right: 0, height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Theme.of(context).colorScheme.surface.withOpacity(0), Theme.of(context).colorScheme.surface],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (benefits.length > previewCount)
            GestureDetector(
              onTap: () => setState(() => _benefitsExpanded = !_benefitsExpanded),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 1.h),
                margin: EdgeInsets.only(top: 0.5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF4A7C59).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _benefitsExpanded ? 'छोटा करें' : 'सभी ${benefits.length} लाभ देखें',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFF4A7C59)),
                    ),
                    SizedBox(width: 1.w),
                    Icon(_benefitsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFF4A7C59), size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Precautions card — collapsible
  Widget _buildPosePrecautionsCard() {
    final precautionsRaw = _linkedPose?['precautions'];
    if (precautionsRaw == null) return const SizedBox.shrink();

    final precautions = precautionsRaw is List
        ? List<String>.from(precautionsRaw)
        : precautionsRaw.toString().split('\n').where((s) => s.trim().isNotEmpty).toList();
    if (precautions.isEmpty) return const SizedBox.shrink();

    const previewCount = 2;
    final showAll = _precautionsExpanded || precautions.length <= previewCount;
    final displayPrecautions = showAll ? precautions : precautions.sublist(0, previewCount);

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _precautionsExpanded = !_precautionsExpanded),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFE53935), size: 22),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Precautions / सावधानियाँ (${precautions.length})',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _precautionsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down, color: const Color(0xFFE53935), size: 28),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.5.h),
          Stack(
            children: [
              Column(
                children: displayPrecautions.map((p) => Padding(
                  padding: EdgeInsets.only(bottom: 0.8.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: Color(0xFFE53935), size: 20),
                      SizedBox(width: 2.w),
                      Expanded(
                        child: Text(
                          p.toString().replaceAll(RegExp(r'^[-•]\s*'), ''),
                          style: TextStyle(fontSize: 15.sp, color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
              if (!showAll)
                Positioned(
                  bottom: 0, left: 0, right: 0, height: 40,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Theme.of(context).colorScheme.surface.withOpacity(0), Theme.of(context).colorScheme.surface],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (precautions.length > previewCount)
            GestureDetector(
              onTap: () => setState(() => _precautionsExpanded = !_precautionsExpanded),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 1.h),
                margin: EdgeInsets.only(top: 0.5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFE53935).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _precautionsExpanded ? 'छोटा करें' : 'सभी ${precautions.length} सावधानियाँ देखें',
                      style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: const Color(0xFFE53935)),
                    ),
                    SizedBox(width: 1.w),
                    Icon(_precautionsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: const Color(0xFFE53935), size: 18),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Steps overview timeline card — collapsible, shows 2 preview steps
  Widget _buildStepsOverviewCard() {
    final previewCount = 2;
    final showAll = _stepsExpanded || _poseSteps.length <= previewCount;
    final displaySteps = showAll ? _poseSteps : _poseSteps.sublist(0, previewCount);

    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with expand/collapse
          GestureDetector(
            onTap: () => setState(() => _stepsExpanded = !_stepsExpanded),
            child: Row(
              children: [
                Icon(Icons.format_list_numbered, color: Theme.of(context).colorScheme.primary, size: 22),
                SizedBox(width: 2.w),
                Expanded(
                  child: Text(
                    'Steps Overview (${_poseSteps.length})',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _stepsExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 300),
                  child: Icon(Icons.keyboard_arrow_down, color: Theme.of(context).colorScheme.primary, size: 28),
                ),
              ],
            ),
          ),
          SizedBox(height: 1.5.h),
          // Steps list (preview or full)
          Stack(
            children: [
              Column(
                children: displaySteps.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final step = entry.value;
                  final isLast = showAll
                      ? idx == _poseSteps.length - 1
                      : idx == displaySteps.length - 1;
                  return _buildStepItem(idx, step, isLast);
                }).toList(),
              ),
              // Fade-out gradient when collapsed
              if (!showAll)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Theme.of(context).colorScheme.surface.withOpacity(0), Theme.of(context).colorScheme.surface],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Show All / Collapse button
          if (_poseSteps.length > previewCount)
            GestureDetector(
              onTap: () => setState(() => _stepsExpanded = !_stepsExpanded),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 1.2.h),
                margin: EdgeInsets.only(top: 1.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _stepsExpanded
                          ? 'Collapse / छोटा करें'
                          : 'Show All ${_poseSteps.length} Steps / सभी देखें',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    SizedBox(width: 1.w),
                    Icon(
                      _stepsExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Single step item in the timeline
  Widget _buildStepItem(int idx, Map<String, dynamic> step, bool isLast) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      '${idx + 1}',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 1.5.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step['name'] ?? '',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (step['name_hindi'] != null)
                    Text(
                      step['name_hindi'],
                      style: TextStyle(fontSize: 13.sp, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  SizedBox(height: 0.3.h),
                  Row(
                    children: [
                      if (step['breathing'] != null) ...[
                        Icon(
                          step['breathing'] == 'inhale'
                              ? Icons.arrow_upward
                              : step['breathing'] == 'exhale'
                                  ? Icons.arrow_downward
                                  : Icons.pause,
                          size: 12,
                          color: const Color(0xFF4A7C59),
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          step['breathing'].toString().toUpperCase(),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4A7C59),
                          ),
                        ),
                        SizedBox(width: 3.w),
                      ],
                      Icon(Icons.timer_outlined, size: 12, color: Colors.grey),
                      SizedBox(width: 1.w),
                      Text(
                        '${step['duration_seconds'] ?? 10}s',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (step['mantra'] != null)
                    Padding(
                      padding: EdgeInsets.only(top: 0.3.h),
                      child: Text(
                        step['mantra'],
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontStyle: FontStyle.italic,
                          color: const Color(0xFF8B6914),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getBenefits(String category) {
    switch (category) {
      case 'meditation':
        return [
          'Reduces stress and anxiety',
          'Improves focus and concentration',
          'Promotes emotional well-being',
          'Better sleep quality',
        ];
      case 'pranayama':
        return [
          'Increases lung capacity',
          'Calms the nervous system',
          'Boosts energy levels',
          'Improves mental clarity',
        ];
      case 'yoga':
        return [
          'Improves flexibility and strength',
          'Reduces muscle tension',
          'Enhances body awareness',
          'Promotes relaxation',
        ];
      default:
        return ['Improves overall well-being'];
    }
  }

  String _formatDuration(dynamic duration) {
    if (duration == null) return 'N/A';
    if (duration is int) {
      final minutes = duration ~/ 60;
      return '$minutes min';
    }
    return duration.toString();
  }

  String _getDifficultyLabel(int difficulty) {
    switch (difficulty) {
      case 1: return 'Beginner';
      case 2: return 'Easy';
      case 3: return 'Moderate';
      case 4: return 'Advanced';
      case 5: return 'Expert';
      default: return 'Moderate';
    }
  }

  Color _getDifficultyColor(int difficulty) {
    switch (difficulty) {
      case 1:
      case 2:
        return const Color(0xFF4A7C59); // Natural green
      case 3:
        return const Color(0xFFCD853F); // Sandy brown
      case 4:
      case 5:
        return const Color(0xFFFF6B35); // Accent orange
      default:
        return const Color(0xFFCD853F);
    }
  }

  IconData _getMediaIcon(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return Icons.play_circle_filled;
      case 'video':
        return Icons.videocam;
      case 'audio':
        return Icons.headphones;
      default:
        return Icons.play_arrow;
    }
  }

  String _getMediaLabel(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return 'YouTube';
      case 'video':
        return 'Video';
      case 'audio':
        return 'Audio';
      default:
        return 'Media';
    }
  }

  Color _getMediaColor(String mediaType) {
    switch (mediaType.toLowerCase()) {
      case 'youtube':
        return const Color(0xFFCC3333); // Warm red
      case 'video':
        return Color(0xFF8B4513); // Earth brown
      case 'audio':
        return const Color(0xFFCD853F); // Sandy brown
      default:
        return _primaryBrown;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'meditation':
        return _primaryBrown;
      case 'pranayama':
        return const Color(0xFF6B7B3C); // Olive green
      case 'yoga':
        return const Color(0xFFB8860B); // Golden brown
      default:
        return _primaryBrown;
    }
  }
}

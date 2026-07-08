// lib/presentation/tapasya/community_challenges_screen.dart
//
// Screen to browse and join public/community challenges.

import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../services/tapasya_service.dart';
import './widgets/challenge_card_widget.dart';

class CommunityChallengesScreen extends StatefulWidget {
  const CommunityChallengesScreen({super.key});

  @override
  State<CommunityChallengesScreen> createState() => _CommunityChallengesScreenState();
}

class _CommunityChallengesScreenState extends State<CommunityChallengesScreen> {
  final TapasyaService _tapasyaService = TapasyaService();
  List<Map<String, dynamic>> _challenges = [];
  bool _isLoading = true;

  static const _primaryColor = Color(0xFFE65100);

  @override
  void initState() {
    super.initState();
    _loadChallenges();
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoading = true);
    try {
      final challenges = await _tapasyaService.getCommunityChallenge();
      if (mounted) {
        setState(() {
          _challenges = challenges;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading community challenges: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('🌍 Community Challenges'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _primaryColor))
          : RefreshIndicator(
              onRefresh: _loadChallenges,
              color: _primaryColor,
              child: _challenges.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: 15.h),
                        const Center(child: Text('🌍', style: TextStyle(fontSize: 64))),
                        SizedBox(height: 2.h),
                        Center(
                          child: Text(
                            'No community challenges yet',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        SizedBox(height: 1.h),
                        Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8.w),
                            child: Text(
                              'Create a public challenge or check back later to join community events.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: EdgeInsets.all(4.w),
                      itemCount: _challenges.length,
                      itemBuilder: (context, index) {
                        final challenge = _challenges[index];
                        final isJoined = challenge['is_joined'] == true;
                        final participantCount = challenge['participant_count'] ?? 0;
                        final daysLeft = DateTime.tryParse(challenge['ends_at'] ?? '')
                                ?.difference(DateTime.now())
                                .inDays ??
                            0;

                        return Container(
                          margin: EdgeInsets.only(bottom: 2.h),
                          padding: EdgeInsets.all(4.w),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.outline.withOpacity(0.15),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [_primaryColor, Color(0xFFBF360C)],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Center(
                                  child: Text('🏆', style: TextStyle(fontSize: 24)),
                                ),
                              ),
                              SizedBox(width: 3.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      challenge['title'] ?? 'Challenge',
                                      style: TextStyle(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 0.3.h),
                                    Text(
                                      '$participantCount players • ${daysLeft}d left',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 2.w),
                              ElevatedButton(
                                onPressed: () async {
                                  if (isJoined) {
                                    Navigator.pushNamed(
                                      context,
                                      '/tapasya/challenge',
                                      arguments: challenge,
                                    ).then((_) => _loadChallenges());
                                  } else {
                                    final success = await _tapasyaService.joinChallenge(
                                      challengeId: challenge['id'],
                                    );
                                    if (mounted) {
                                      if (success) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('🔥 Joined "${challenge['title']}"!'),
                                            backgroundColor: const Color(0xFF2E7D32),
                                          ),
                                        );
                                        _loadChallenges(); // Refresh list
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Failed to join challenge.')),
                                        );
                                      }
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isJoined ? Colors.green[600] : _primaryColor,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                                  elevation: 0,
                                ),
                                child: Text(
                                  isJoined ? 'View' : 'Join 🔥',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';

import '../../services/ai_guide_service.dart';

/// ═══════════════════════════════════════════════════════════════
/// DISHA AI GUIDE — WORLD-CLASS PREMIUM CHAT UI
/// Features: Glassmorphism, animated gradients, micro-interactions,
/// lotus-themed design, frosted glass, golden accents
/// ═══════════════════════════════════════════════════════════════
class AiGuideScreen extends StatefulWidget {
  const AiGuideScreen({super.key});

  @override
  State<AiGuideScreen> createState() => _AiGuideScreenState();
}

class _AiGuideScreenState extends State<AiGuideScreen>
    with TickerProviderStateMixin {
  final AiGuideService _ai = AiGuideService();
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  final List<_ChatMessage> _messages = [];
  bool _isTyping = false;
  bool _isGeneratingImage = false;
  bool _showSuggestions = true;
  StreamSubscription<String>? _streamSub;

  // ── Premium Color Palette ──
  static const Color _saffronGold = Color(0xFFDAA520);
  static const Color _deepGold = Color(0xFFB8860B);
  static const Color _richBrown = Color(0xFF8B4513);
  static const Color _darkBrown = Color(0xFF2C1810);
  static const Color _creamBg = Color(0xFFFDF8F3);
  static const Color _warmWhite = Color(0xFFFFF9F2);
  static const Color _softPeach = Color(0xFFFFF0E6);
  static const Color _accentGreen = Color(0xFF4A7C59);
  static const Color _mutedGold = Color(0xFFE8D5A3);

  // ── Animation Controllers ──
  late AnimationController _dotAnimController;
  late AnimationController _glowAnimController;
  late AnimationController _bgAnimController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Typing dots animation
    _dotAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Lotus glow breathing animation
    _glowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowAnimController, curve: Curves.easeInOut),
    );

    // Background gradient animation
    _bgAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    // Welcome message
    _messages.add(_ChatMessage(
      text:
          'Namaste! 🙏 Main **Disha** hoon — aapki personal Ayurvedic wellness guide.\n\nAap mujhse kuch bhi pooch sakte hain — meditation, pranayama, yoga, daily routine, ya dosha ke baare mein.\n\nKaise help kar sakti hoon aaj? ✨',
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _dotAnimController.dispose();
    _glowAnimController.dispose();
    _bgAnimController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isTyping) return;

    final userMsg = text.trim();
    _textController.clear();
    HapticFeedback.lightImpact();

    final wantsImage = _ai.isImageRequest(userMsg);

    setState(() {
      _messages.add(_ChatMessage(
        text: userMsg,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _showSuggestions = false;
      _isTyping = true;
      _isGeneratingImage = wantsImage;
    });

    _scrollToBottom();

    // Add placeholder for streaming response
    final aiIndex = _messages.length;
    _messages.add(_ChatMessage(
      text: '',
      isUser: false,
      timestamp: DateTime.now(),
    ));

    // Stream the text response
    _streamSub?.cancel();
    _streamSub = _ai.sendMessage(userMsg).listen(
      (partialResponse) {
        if (mounted) {
          setState(() {
            _messages[aiIndex] = _ChatMessage(
              text: partialResponse,
              isUser: false,
              timestamp: DateTime.now(),
              imageUrl: _messages[aiIndex].imageUrl,
            );
          });
          _scrollToBottom();
        }
      },
      onDone: () async {
        if (wantsImage && mounted) {
          setState(() => _isGeneratingImage = true);
          final imgPrompt = _ai.buildImagePrompt(userMsg);
          final imageUrl = await _ai.generateImage(imgPrompt);
          if (mounted) {
            setState(() {
              _messages[aiIndex] = _ChatMessage(
                text: _messages[aiIndex].text,
                isUser: false,
                timestamp: DateTime.now(),
                imageUrl: imageUrl,
              );
              _isGeneratingImage = false;
              _isTyping = false;
            });
          }
        } else {
          if (mounted) setState(() => _isTyping = false);
        }
        _scrollToBottom();
      },
      onError: (e) {
        if (mounted) {
          setState(() {
            _messages[aiIndex] = _ChatMessage(
              text: 'Something went wrong. Please try again. 🙏',
              isUser: false,
              timestamp: DateTime.now(),
            );
            _isTyping = false;
            _isGeneratingImage = false;
          });
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _creamBg,
      body: Stack(
        children: [
          // Animated gradient background
          _buildAnimatedBackground(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildPremiumAppBar(),
                Expanded(child: _buildMessageList()),
                if (_showSuggestions && _messages.length <= 1) _buildSuggestions(),
                _buildPremiumInputBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // ANIMATED BACKGROUND
  // ═══════════════════════════════════════════════════════════════

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgAnimController,
      builder: (_, __) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _creamBg,
                Color.lerp(_warmWhite, _softPeach, _bgAnimController.value)!,
                _creamBg,
              ],
              stops: [0.0, 0.5 + _bgAnimController.value * 0.2, 1.0],
            ),
          ),
          // Subtle mandala pattern overlay
          child: CustomPaint(
            painter: _MandalaPatternPainter(
              opacity: 0.03 + _bgAnimController.value * 0.015,
            ),
            size: Size.infinite,
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PREMIUM APP BAR (Glassmorphism)
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPremiumAppBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 1.2.h),
          decoration: BoxDecoration(
            color: _warmWhite.withOpacity(0.85),
            border: Border(
              bottom: BorderSide(
                color: _saffronGold.withOpacity(0.15),
                width: 0.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: _saffronGold.withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _richBrown.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.arrow_back_ios_new, color: _darkBrown, size: 18),
                ),
              ),
              SizedBox(width: 3.w),

              // Glowing Lotus Avatar
              AnimatedBuilder(
                animation: _glowAnimation,
                builder: (_, __) => Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _saffronGold,
                        _deepGold,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: _saffronGold.withOpacity(_glowAnimation.value),
                        blurRadius: 12 + _glowAnimation.value * 6,
                        spreadRadius: _glowAnimation.value * 2,
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      '🪷',
                      style: TextStyle(fontSize: 20),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 2.5.w),

              // Title & Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Disha — AI Guide',
                      style: TextStyle(
                        color: _darkBrown,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Row(
                        key: ValueKey('$_isTyping$_isGeneratingImage'),
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Status dot
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: (_isTyping || _isGeneratingImage)
                                  ? _saffronGold
                                  : _accentGreen,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: ((_isTyping || _isGeneratingImage)
                                          ? _saffronGold
                                          : _accentGreen)
                                      .withOpacity(0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isGeneratingImage
                                ? 'creating image...'
                                : (_isTyping ? 'thinking...' : 'your wellness companion'),
                            style: TextStyle(
                              color: (_isTyping || _isGeneratingImage)
                                  ? _saffronGold
                                  : _darkBrown.withOpacity(0.5),
                              fontSize: 11.5,
                              fontWeight: (_isTyping || _isGeneratingImage)
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Clear chat menu
              PopupMenuButton<String>(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _richBrown.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.more_vert, color: _darkBrown, size: 18),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                color: _warmWhite,
                onSelected: (value) {
                  if (value == 'clear') {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _messages.clear();
                      _showSuggestions = true;
                      _ai.clearHistory();
                      _messages.add(_ChatMessage(
                        text: 'Fresh start! 🌿 Kaise help karun aaj?',
                        isUser: false,
                        timestamp: DateTime.now(),
                      ));
                    });
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: _richBrown, size: 18),
                        const SizedBox(width: 10),
                        Text('New Conversation', style: TextStyle(color: _darkBrown)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // MESSAGE LIST
  // ═══════════════════════════════════════════════════════════════

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.5.h),
      itemCount: _messages.length + (_isTyping && _messages.last.text.isEmpty ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _messages.length) {
          return _buildTypingIndicator();
        }
        final msg = _messages[index];
        return _PremiumMessageBubble(
          message: msg,
          isLast: index == _messages.length - 1,
          isGeneratingImage: _isGeneratingImage,
          onImageTap: _showFullScreenImage,
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // TYPING INDICATOR — Lotus Pulse
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(bottom: 1.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Small lotus icon
            Text('🪷', style: TextStyle(fontSize: 14)),
            SizedBox(width: 1.5.w),
            // Frosted glass bubble with animated dots
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _saffronGold.withOpacity(0.15)),
                    boxShadow: [
                      BoxShadow(
                        color: _saffronGold.withOpacity(0.08),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: _dotAnimController,
                    builder: (_, __) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(3, (i) {
                          final delay = i * 0.2;
                          final t = ((_dotAnimController.value - delay) % 1.0).clamp(0.0, 1.0);
                          final scale = 0.6 + 0.4 * math.sin(t * math.pi);
                          return Transform.scale(
                            scale: scale,
                            child: Container(
                              width: 9,
                              height: 9,
                              margin: const EdgeInsets.symmetric(horizontal: 2.5),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    _saffronGold.withOpacity(0.5 + 0.5 * scale),
                                    _deepGold.withOpacity(0.5 + 0.5 * scale),
                                  ],
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _saffronGold.withOpacity(0.3 * scale),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // SUGGESTION CHIPS — Frosted Glass Pills
  // ═══════════════════════════════════════════════════════════════

  Widget _buildSuggestions() {
    final suggestions = _ai.getSuggestedPrompts();

    return Container(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 1.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 1.h),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: _saffronGold, size: 16),
                SizedBox(width: 1.5.w),
                Text(
                  'Suggestions',
                  style: TextStyle(
                    fontSize: 12,
                    color: _darkBrown.withOpacity(0.5),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 5.h,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 3.5.w),
              separatorBuilder: (_, __) => SizedBox(width: 2.w),
              itemCount: suggestions.length,
              itemBuilder: (_, i) {
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _sendMessage(suggestions[i]);
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _saffronGold.withOpacity(0.25),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _saffronGold.withOpacity(0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            suggestions[i],
                            style: TextStyle(
                              fontSize: 12.5,
                              color: _richBrown,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PREMIUM INPUT BAR — Frosted Glass
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPremiumInputBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(3.w, 1.h, 2.w, MediaQuery.of(context).padding.bottom + 1.h),
          decoration: BoxDecoration(
            color: _warmWhite.withOpacity(0.85),
            border: Border(
              top: BorderSide(color: _saffronGold.withOpacity(0.12), width: 0.5),
            ),
            boxShadow: [
              BoxShadow(
                color: _saffronGold.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: _mutedGold.withOpacity(0.3)),
                    boxShadow: [
                      BoxShadow(
                        color: _richBrown.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      // Inner shadow effect
                      BoxShadow(
                        color: _richBrown.withOpacity(0.02),
                        blurRadius: 4,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    maxLines: 4,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: 'Ask Disha anything...',
                      hintStyle: TextStyle(
                        color: _darkBrown.withOpacity(0.3),
                        fontSize: 14.5,
                        fontWeight: FontWeight.w400,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.5.h),
                      prefixIcon: Padding(
                        padding: EdgeInsets.only(left: 3.w),
                        child: Icon(Icons.chat_bubble_outline_rounded, color: _saffronGold.withOpacity(0.4), size: 20),
                      ),
                      prefixIconConstraints: const BoxConstraints(minWidth: 40),
                    ),
                    style: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 14.5, height: 1.4),
                    cursorColor: _saffronGold,
                    onSubmitted: _sendMessage,
                  ),
                ),
              ),
              SizedBox(width: 2.5.w),
              // Golden send button
              GestureDetector(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  _sendMessage(_textController.text);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _isTyping
                          ? [_mutedGold.withOpacity(0.4), _mutedGold.withOpacity(0.3)]
                          : [_saffronGold, _deepGold],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: _isTyping
                        ? []
                        : [
                            BoxShadow(
                              color: _saffronGold.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // FULL SCREEN IMAGE VIEWER
  // ═══════════════════════════════════════════════════════════════

  void _showFullScreenImage(String imageUrl) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Center(
              child: Hero(
                tag: 'img_$imageUrl',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (_, child, progress) {
                      if (progress == null) return child;
                      return SizedBox(
                        width: 200,
                        height: 200,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(_saffronGold),
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ═══════════════════════════════════════════════════════════════
// PREMIUM MESSAGE BUBBLE — Stateless Widget for Performance
// ═══════════════════════════════════════════════════════════════

class _PremiumMessageBubble extends StatelessWidget {
  final _ChatMessage message;
  final bool isLast;
  final bool isGeneratingImage;
  final void Function(String) onImageTap;

  const _PremiumMessageBubble({
    required this.message,
    required this.isLast,
    required this.isGeneratingImage,
    required this.onImageTap,
  });

  // Colors (must match parent)
  static const Color _saffronGold = Color(0xFFDAA520);
  static const Color _deepGold = Color(0xFFB8860B);
  static const Color _richBrown = Color(0xFF8B4513);
  static const Color _darkBrown = Color(0xFF2C1810);
  static const Color _mutedGold = Color(0xFFE8D5A3);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: 82.w),
        margin: EdgeInsets.only(
          bottom: 1.5.h,
          left: message.isUser ? 10.w : 0,
          right: message.isUser ? 0 : 10.w,
        ),
        child: Column(
          crossAxisAlignment:
              message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // AI indicator
            if (!message.isUser)
              Padding(
                padding: EdgeInsets.only(left: 1.w, bottom: 0.4.h),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('🪷', style: TextStyle(fontSize: 12)),
                    SizedBox(width: 1.w),
                    Text(
                      'Disha',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: _saffronGold.withOpacity(0.7),
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            // Message bubble
            message.isUser ? _buildUserBubble() : _buildAiBubble(context),
            // Timestamp
            Padding(
              padding: EdgeInsets.only(top: 0.3.h, left: 1.5.w, right: 1.5.w),
              child: Text(
                _formatTimeStatic(message.timestamp),
                style: TextStyle(
                  fontSize: 9.5,
                  color: _darkBrown.withOpacity(0.3),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// User message — saffron gradient bubble
  Widget _buildUserBubble() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFD4943A), Color(0xFFC17D2E), Color(0xFFAB6B24)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(6),
        ),
        boxShadow: [
          BoxShadow(
            color: _saffronGold.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: _deepGold.withOpacity(0.1),
            blurRadius: 4,
            spreadRadius: -1,
          ),
        ],
      ),
      child: Text(
        message.text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.5,
          height: 1.45,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }

  /// AI message — frosted glass bubble
  Widget _buildAiBubble(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
        bottomLeft: Radius.circular(6),
        bottomRight: Radius.circular(20),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.82),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(6),
              bottomRight: Radius.circular(20),
            ),
            border: Border.all(
              color: _saffronGold.withOpacity(0.1),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _richBrown.withOpacity(0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (message.text.isNotEmpty)
                _MarkdownLite(text: message.text, baseColor: _darkBrown),
              if (message.imageUrl != null) ...[
                SizedBox(height: 1.5.h),
                _buildImageWidget(message.imageUrl!),
              ],
              if (isGeneratingImage && isLast && message.imageUrl == null)
                Padding(
                  padding: EdgeInsets.only(top: 1.5.h),
                  child: _buildImageLoadingPlaceholder(),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageWidget(String imageUrl) {
    return GestureDetector(
      onTap: () => onImageTap(imageUrl),
      child: Hero(
        tag: 'img_$imageUrl',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: BoxConstraints(maxWidth: 68.w, maxHeight: 68.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: _saffronGold.withOpacity(0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (_, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 68.w,
                      height: 50.w,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _mutedGold.withOpacity(0.15),
                            _mutedGold.withOpacity(0.25),
                            _mutedGold.withOpacity(0.15),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: CircularProgressIndicator(
                          value: progress.expectedTotalBytes != null
                              ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                              : null,
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(_saffronGold),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => Container(
                    width: 60.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: _mutedGold.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _mutedGold.withOpacity(0.25)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported_outlined, color: _richBrown.withOpacity(0.4), size: 28),
                        SizedBox(height: 0.5.h),
                        Text('Image unavailable', style: TextStyle(color: _darkBrown.withOpacity(0.4), fontSize: 11)),
                      ],
                    ),
                  ),
                ),
                // Expand button
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImageLoadingPlaceholder() {
    return Container(
      width: 60.w,
      height: 40.w,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _mutedGold.withOpacity(0.08),
            _mutedGold.withOpacity(0.18),
            _mutedGold.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _saffronGold.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(_saffronGold.withOpacity(0.6)),
            ),
          ),
          SizedBox(height: 1.h),
          Text(
            '🎨 Creating your image...',
            style: TextStyle(color: _darkBrown.withOpacity(0.45), fontSize: 12),
          ),
        ],
      ),
    );
  }

  static String _formatTimeStatic(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }
}

// ═══════════════════════════════════════════════════════════════
// MANDALA PATTERN PAINTER — Subtle Background Art
// ═══════════════════════════════════════════════════════════════

class _MandalaPatternPainter extends CustomPainter {
  final double opacity;

  _MandalaPatternPainter({required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFDAA520).withOpacity(opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    // Draw subtle concentric circles at top-right
    final center1 = Offset(size.width * 0.85, size.height * 0.08);
    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center1, i * 25.0, paint);
    }

    // Draw subtle lotus-like pattern at bottom-left
    final center2 = Offset(size.width * 0.15, size.height * 0.92);
    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center2, i * 30.0, paint);
    }

    // Cross lines through center for mandala feel
    final linePaint = Paint()
      ..color = Color(0xFFDAA520).withOpacity(opacity * 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.3;

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 8;
      canvas.drawLine(
        Offset(
          center1.dx + math.cos(angle) * 20,
          center1.dy + math.sin(angle) * 20,
        ),
        Offset(
          center1.dx + math.cos(angle) * 125,
          center1.dy + math.sin(angle) * 125,
        ),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MandalaPatternPainter old) => old.opacity != opacity;
}

// ═══════════════════════════════════════════════════════════════
// MARKDOWN LITE — Rich Text Renderer
// ═══════════════════════════════════════════════════════════════

class _MarkdownLite extends StatelessWidget {
  final String text;
  final Color baseColor;
  const _MarkdownLite({required this.text, required this.baseColor});

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*|`(.+?)`');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      if (match.group(1) != null) {
        // Bold
        spans.add(TextSpan(
          text: match.group(1),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF8B4513),
          ),
        ));
      } else if (match.group(2) != null) {
        // Code
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: baseColor.withOpacity(0.06),
            fontSize: 13,
            color: const Color(0xFF4A7C59),
          ),
        ));
      }
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: TextStyle(color: baseColor, fontSize: 14.5, height: 1.55),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CHAT MESSAGE MODEL
// ═══════════════════════════════════════════════════════════════

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? imageUrl;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math;
import 'dart:ui';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sizer/sizer.dart';
import 'package:share_plus/share_plus.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

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

  // ── Voice Recording ──
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  String? _lastUserMessage; // For regenerate

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

    // Load saved conversation from Supabase
    _loadSavedConversation();
  }

  Future<void> _loadSavedConversation() async {
    try {
      final savedMessages = await _ai.loadChatHistory();
      if (mounted) {
        setState(() {
          if (savedMessages.isNotEmpty) {
            _messages.clear();
            for (final msg in savedMessages) {
              _messages.add(_ChatMessage(
                text: msg['content'] as String? ?? '',
                isUser: (msg['role'] as String) == 'user',
                timestamp: DateTime.tryParse(msg['created_at'] as String? ?? '') ?? DateTime.now(),
                imageUrl: msg['image_url'] as String?,
              ));
            }
            _showSuggestions = false;
          } else {
            // No history — show welcome message
            _messages.add(_ChatMessage(
              text:
                  'Namaste! 🙏 Main **Disha** hoon — aapki personal Ayurvedic wellness guide.\n\nAap mujhse kuch bhi pooch sakte hain — meditation, pranayama, yoga, daily routine, ya dosha ke baare mein.\n\nKaise help kar sakti hoon aaj? ✨',
              isUser: false,
              timestamp: DateTime.now(),
            ));
          }


        });
        _scrollToBottom();

        // Re-detect cards for the last AI message (so cards appear on reload)
        if (_messages.length >= 2) {
          // Find last AI message and its preceding user message
          String lastUserQuery = '';
          int lastAiIndex = -1;
          for (int i = _messages.length - 1; i >= 0; i--) {
            if (!_messages[i].isUser && _messages[i].text.isNotEmpty && lastAiIndex == -1) {
              lastAiIndex = i;
            }
            if (_messages[i].isUser && lastAiIndex != -1) {
              lastUserQuery = _messages[i].text;
              break;
            }
          }
          if (lastAiIndex != -1) {
            final cards = await _ai.detectAndFetchCards(
              _messages[lastAiIndex].text,
              lastUserQuery,
            );
            if (cards.isNotEmpty && mounted) {
              setState(() {
                _messages[lastAiIndex].attachedCards = cards;
              });
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _messages.add(_ChatMessage(
            text:
                'Namaste! 🙏 Main **Disha** hoon — aapki personal Ayurvedic wellness guide.\n\nAap mujhse kuch bhi pooch sakte hain — meditation, pranayama, yoga, daily routine, ya dosha ke baare mein.\n\nKaise help kar sakti hoon aaj? ✨',
            isUser: false,
            timestamp: DateTime.now(),
          ));


        });
      }
    }
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
    _audioRecorder.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════════
  // MESSAGE ACTIONS
  // ═══════════════════════════════════════════════════════════════

  void _copyMessage(String text) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message copied! 📋'),
          backgroundColor: const Color(0xFF4A7C59),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  void _shareMessage(String text) {
    HapticFeedback.lightImpact();
    SharePlus.instance.share(ShareParams(text: '🪷 Disha AI says:\n\n$text\n\n— from Dincharya App'));
  }

  void _regenerateLastMessage() {
    if (_isTyping || _lastUserMessage == null) return;
    // Remove last AI message
    if (_messages.isNotEmpty && !_messages.last.isUser) {
      setState(() => _messages.removeLast());
    }
    _sendMessage(_lastUserMessage!);
  }

  void _sendFeedback(String messageText, bool isPositive) {
    HapticFeedback.lightImpact();
    // Save feedback to Supabase (fire-and-forget)
    _ai.saveMessage(
      role: 'feedback',
      content: '${isPositive ? "👍" : "👎"} | $messageText',
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isPositive ? 'Thanks for the feedback! 🙏' : 'We\'ll improve! 🙏'),
          backgroundColor: isPositive ? const Color(0xFF4A7C59) : const Color(0xFF8B4513),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // CARD NAVIGATION
  // ═══════════════════════════════════════════════════════════════

  void _navigateFromCard(Map<String, dynamic> card) {
    HapticFeedback.mediumImpact();
    final type = card['type'] as String? ?? '';

    switch (type) {
      case 'session':
        final sessionData = card['data'] as Map<String, dynamic>?;
        if (sessionData != null) {
          Navigator.pushNamed(
            context,
            '/media-player',
            arguments: sessionData,
          );
        }
        break;
      case 'task_list':
        Navigator.pushNamed(context, '/local-tasks');
        break;
      case 'progress':
        Navigator.pushNamed(context, '/session-history');
        break;
      case 'quick_action':
        final route = card['route'] as String? ?? '';
        if (route.isNotEmpty) {
          Navigator.pushNamed(context, route);
        }
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VOICE RECORDING
  // ═══════════════════════════════════════════════════════════════

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      await _stopAndSendVoice();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Check permission
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Microphone permission required for voice input 🎤'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/disha_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _isRecording = true);
    } catch (e) {
      debugPrint('❌ Recording error: $e');
    }
  }

  Future<void> _stopAndSendVoice() async {
    try {
      final path = await _audioRecorder.stop();
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _isRecording = false);

      if (path == null) return;

      // Show transcribing indicator
      if (mounted) {
        setState(() {
          _isTyping = true;
          _messages.add(_ChatMessage(
            text: '🎤 Transcribing your voice...',
            isUser: true,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();
      }

      // Send to Sarvam STT API
      final transcription = await _ai.transcribeAudio(path);

      if (transcription != null && transcription.isNotEmpty && mounted) {
        // Replace the transcribing message with actual text
        setState(() {
          _messages.removeLast();
          _isTyping = false;
        });
        // Clean up the temp file
        try { File(path).deleteSync(); } catch (_) {}
        // Send as a normal message
        _sendMessage(transcription);
      } else {
        if (mounted) {
          setState(() {
            _messages.removeLast();
            _isTyping = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Could not transcribe audio. Please try again 🎤'),
              backgroundColor: Theme.of(context).colorScheme.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
        try { File(path).deleteSync(); } catch (_) {}
      }
    } catch (e) {
      debugPrint('❌ Voice send error: $e');
      if (mounted) setState(() { _isRecording = false; _isTyping = false; });
    }
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
    _lastUserMessage = userMsg; // For regenerate
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

    // Save user message to Supabase (fire-and-forget)
    _ai.saveMessage(role: 'user', content: userMsg);

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
        // Save AI text response to Supabase
        final aiText = _messages[aiIndex].text;

        if (wantsImage && mounted) {
          setState(() => _isGeneratingImage = true);
          final imgPrompt = await _ai.buildImagePrompt(userMsg);
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
          // Save AI response with image URL to Supabase
          _ai.saveMessage(role: 'assistant', content: aiText, imageUrl: imageUrl);
        } else {
          if (mounted) setState(() => _isTyping = false);
          // Save AI text-only response to Supabase
          if (aiText.isNotEmpty) {
            _ai.saveMessage(role: 'assistant', content: aiText);
          }
        }
        // ── Smart Card Injection ──
        if (aiText.isNotEmpty && mounted) {
          final cards = await _ai.detectAndFetchCards(aiText, userMsg);
          if (cards.isNotEmpty && mounted) {
            setState(() {
              _messages[aiIndex].attachedCards = cards;
            });
          }
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                Theme.of(context).scaffoldBackgroundColor,
                Color.lerp(Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainerHighest, _bgAnimController.value)!,
                Theme.of(context).scaffoldBackgroundColor,
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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
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
                  child: Icon(Icons.arrow_back_ios_new, color: Theme.of(context).colorScheme.onSurface, size: 18),
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
                        color: Theme.of(context).colorScheme.onSurface,
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
                  child: Icon(Icons.more_vert, color: Theme.of(context).colorScheme.onSurface, size: 18),
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                onSelected: (value) async {
                  if (value == 'clear') {
                    HapticFeedback.mediumImpact();
                    setState(() {
                      _messages.clear();
                      _showSuggestions = true;
                      _messages.add(_ChatMessage(
                        text: 'Fresh start! 🌿 Kaise help karun aaj?',
                        isUser: false,
                        timestamp: DateTime.now(),
                      ));
                    });
                    // Clear from Supabase too (async)
                    await _ai.clearHistory();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'clear',
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded, color: _richBrown, size: 18),
                        const SizedBox(width: 10),
                        Text('New Conversation', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
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
          onCopy: _copyMessage,
          onShare: _shareMessage,
          onRegenerate: (!msg.isUser && index == _messages.length - 1 && !_isTyping) ? _regenerateLastMessage : null,
          onFeedback: !msg.isUser ? _sendFeedback : null,
          onCardTap: _navigateFromCard,
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
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
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
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
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
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.75),
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
                              color: Theme.of(context).colorScheme.onSurface,
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
  // PREMIUM INPUT BAR — Frosted Glass + Voice
  // ═══════════════════════════════════════════════════════════════

  Widget _buildPremiumInputBar() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(3.w, 1.h, 2.w, MediaQuery.of(context).padding.bottom + 1.h),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withOpacity(0.85),
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
                    color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
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
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      textTheme: Theme.of(context).textTheme.copyWith(
                        bodyLarge: const TextStyle(color: Color(0xFF1A1A2E)),
                        bodyMedium: const TextStyle(color: Color(0xFF1A1A2E)),
                        titleMedium: const TextStyle(color: Color(0xFF1A1A2E)),
                      ),
                      inputDecorationTheme: const InputDecorationTheme(
                        border: InputBorder.none,
                      ),
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
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
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
              ),
              SizedBox(width: 1.5.w),
              // Mic button (voice input)
              GestureDetector(
                onTap: _toggleVoiceRecording,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _isRecording
                        ? Colors.red.withOpacity(0.15)
                        : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(21),
                    border: _isRecording
                        ? Border.all(color: Colors.red.withOpacity(0.4), width: 1.5)
                        : null,
                  ),
                  child: Icon(
                    _isRecording ? Icons.stop_rounded : Icons.mic_rounded,
                    size: 20,
                    color: _isRecording ? Colors.red : _saffronGold.withOpacity(0.6),
                  ),
                ),
              ),
              SizedBox(width: 1.5.w),
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

  /// Decode base64 data URI to bytes
  Uint8List? _decodeBase64Image(String dataUri) {
    try {
      final base64Str = dataUri.split(',').last;
      return base64Decode(base64Str);
    } catch (e) {
      debugPrint('❌ Base64 decode error: $e');
      return null;
    }
  }

  /// Build image widget that handles both network URLs and base64 data URIs
  Widget _buildSmartImage(String imageUrl, {BoxFit fit = BoxFit.cover}) {
    if (imageUrl.startsWith('data:image')) {
      final bytes = _decodeBase64Image(imageUrl);
      if (bytes != null) {
        return Image.memory(bytes, fit: fit);
      }
      return const Icon(Icons.broken_image, size: 40);
    }
    return Image.network(
      imageUrl,
      fit: fit,
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
    );
  }

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
                tag: 'img_${imageUrl.hashCode}',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: _buildSmartImage(imageUrl, fit: BoxFit.contain),
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
  final void Function(String) onCopy;
  final void Function(String) onShare;
  final VoidCallback? onRegenerate;
  final void Function(String, bool)? onFeedback;
  final void Function(Map<String, dynamic> card)? onCardTap;

  const _PremiumMessageBubble({
    required this.message,
    required this.isLast,
    required this.isGeneratingImage,
    required this.onImageTap,
    required this.onCopy,
    required this.onShare,
    this.onRegenerate,
    this.onFeedback,
    this.onCardTap,
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
            // Message actions (only for AI messages with content)
            if (!message.isUser && message.text.isNotEmpty)
              _buildMessageActions(context),
            // Attached cards (session, task, progress, quick_action)
            if (!message.isUser && message.attachedCards.isNotEmpty)
              _buildAttachedCards(context),
            // Timestamp
            Padding(
              padding: EdgeInsets.only(top: 0.3.h, left: 1.5.w, right: 1.5.w),
              child: Text(
                _formatTimeStatic(message.timestamp),
                style: TextStyle(
                  fontSize: 9.5,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
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
            color: Theme.of(context).colorScheme.surface.withOpacity(0.82),
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
                _MarkdownLite(text: message.text, baseColor: Theme.of(context).colorScheme.onSurface),
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

  /// Build image widget — supports both network URLs and base64 data URIs
  Widget _buildImageWidget(String imageUrl) {
    final isBase64 = imageUrl.startsWith('data:image');
    Uint8List? imageBytes;
    if (isBase64) {
      try {
        final base64Str = imageUrl.split(',').last;
        imageBytes = base64Decode(base64Str);
      } catch (_) {}
    }

    return GestureDetector(
      onTap: () => onImageTap(imageUrl),
      child: Hero(
        tag: 'img_${imageUrl.hashCode}',
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
                // Use Image.memory for base64, Image.network for URLs
                if (isBase64 && imageBytes != null)
                  Image.memory(
                    imageBytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildImageErrorPlaceholder(),
                  )
                else if (!isBase64)
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
                    errorBuilder: (_, __, ___) => _buildImageErrorPlaceholder(),
                  )
                else
                  _buildImageErrorPlaceholder(),
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

  Widget _buildImageErrorPlaceholder() {
    return Container(
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

  // ── Message Actions Row ──
  Widget _buildMessageActions(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 0.4.h, left: 1.w),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Copy
          _actionButton(
            context,
            icon: Icons.copy_rounded,
            tooltip: 'Copy',
            onTap: () => onCopy(message.text),
          ),
          SizedBox(width: 1.w),
          // Share
          _actionButton(
            context,
            icon: Icons.share_rounded,
            tooltip: 'Share',
            onTap: () => onShare(message.text),
          ),
          // Regenerate (only for last AI message)
          if (isLast && onRegenerate != null) ...[
            SizedBox(width: 1.w),
            _actionButton(
              context,
              icon: Icons.refresh_rounded,
              tooltip: 'Regenerate',
              onTap: onRegenerate!,
            ),
          ],
          SizedBox(width: 2.w),
          // Feedback
          if (onFeedback != null) ...[
            _actionButton(
              context,
              icon: Icons.thumb_up_outlined,
              tooltip: 'Helpful',
              onTap: () => onFeedback!(message.text, true),
            ),
            SizedBox(width: 0.5.w),
            _actionButton(
              context,
              icon: Icons.thumb_down_outlined,
              tooltip: 'Not helpful',
              onTap: () => onFeedback!(message.text, false),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButton(BuildContext context, {
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Tooltip(
        message: tooltip,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
          ),
        ),
      ),
    );
  }

  static String _formatTimeStatic(DateTime time) {
    final h = time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final m = time.minute.toString().padLeft(2, '0');
    final ampm = time.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  // ── Attached Cards Renderer ──
  Widget _buildAttachedCards(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 0.8.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: message.attachedCards.map((card) {
          final type = card['type'] as String? ?? '';
          switch (type) {
            case 'session':
              return _buildSessionCard(context, card['data'] as Map<String, dynamic>);
            case 'task_list':
              return _buildTaskListCard(context, card['data'] as List);
            case 'progress':
              return _buildProgressCard(context, card['data'] as Map<String, dynamic>);
            case 'quick_action':
              return _buildQuickActionCard(context, card);
            default:
              return const SizedBox.shrink();
          }
        }).toList(),
      ),
    );
  }

  Widget _buildSessionCard(BuildContext context, Map<String, dynamic> session) {
    final title = session['title'] as String? ?? 'Session';
    final category = session['category'] as String? ?? '';
    final duration = session['duration_minutes'] as int? ?? 0;
    final difficulty = session['difficulty'] as int? ?? 1;
    final imageUrl = session['image_url'] as String?;

    String categoryIcon = '🧘';
    if (category == 'pranayama') categoryIcon = '🌬️';
    if (category == 'meditation') categoryIcon = '🧘‍♀️';
    if (category == 'yoga') categoryIcon = '💪';

    return GestureDetector(
      onTap: () => onCardTap?.call({'type': 'session', 'data': session}),
      child: Container(
        margin: EdgeInsets.only(bottom: 0.8.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _saffronGold.withOpacity(0.08),
              _deepGold.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _saffronGold.withOpacity(0.2), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _saffronGold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                image: imageUrl != null
                    ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: imageUrl == null
                  ? Center(child: Text(categoryIcon, style: const TextStyle(fontSize: 22)))
                  : null,
            ),
            SizedBox(width: 3.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 0.3.h),
                  Row(
                    children: [
                      Text(
                        '${category.isNotEmpty ? category[0].toUpperCase() + category.substring(1) : ''} • ${duration}min',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      SizedBox(width: 2.w),
                      ...List.generate(5, (i) => Container(
                        width: 5, height: 5,
                        margin: const EdgeInsets.only(right: 2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < difficulty ? _saffronGold : _saffronGold.withOpacity(0.15),
                        ),
                      )),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFDAA520), Color(0xFFB8860B)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskListCard(BuildContext context, List tasks) {
    return GestureDetector(
      onTap: () => onCardTap?.call({'type': 'task_list'}),
      child: Container(
        margin: EdgeInsets.only(bottom: 0.8.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _saffronGold.withOpacity(0.15), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('📋', style: TextStyle(fontSize: 16)),
                SizedBox(width: 2.w),
                Text('Today\'s Tasks', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _saffronGold)),
                const Spacer(),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _saffronGold.withOpacity(0.5)),
              ],
            ),
            SizedBox(height: 0.5.h),
            ...tasks.take(4).map((task) {
              final t = task as Map<String, dynamic>;
              final isDone = t['is_completed'] == true;
              return Padding(
                padding: EdgeInsets.only(bottom: 0.3.h),
                child: Row(
                  children: [
                    Icon(
                      isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      size: 16,
                      color: isDone ? const Color(0xFF4A7C59) : _saffronGold.withOpacity(0.4),
                    ),
                    SizedBox(width: 2.w),
                    Expanded(
                      child: Text(
                        t['title']?.toString() ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(isDone ? 0.4 : 0.7),
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (t['time'] != null)
                      Text(t['time'].toString(), style: TextStyle(fontSize: 10, color: _saffronGold.withOpacity(0.5))),
                  ],
                ),
              );
            }),
            if (tasks.length > 4)
              Text('+${tasks.length - 4} more...', style: TextStyle(fontSize: 10, color: _saffronGold.withOpacity(0.5))),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(BuildContext context, Map<String, dynamic> stats) {
    return GestureDetector(
      onTap: () => onCardTap?.call({'type': 'progress'}),
      child: Container(
        margin: EdgeInsets.only(bottom: 0.8.h),
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [const Color(0xFF4A7C59).withOpacity(0.1), _saffronGold.withOpacity(0.05)],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF4A7C59).withOpacity(0.2), width: 0.8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📊 Your Progress This Week', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF4A7C59))),
            SizedBox(height: 0.8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statBadge('🔥', '${stats['streak'] ?? 0}', 'Streak'),
                _statBadge('⏱️', '${stats['weekly_minutes'] ?? 0}', 'Minutes'),
                _statBadge('🧘', '${stats['weekly_sessions'] ?? 0}', 'Sessions'),
                _statBadge('⭐', '${stats['xp'] ?? 0}', 'XP'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBadge(String emoji, String value, String label) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        SizedBox(height: 0.2.h),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _saffronGold)),
        Text(label, style: TextStyle(fontSize: 9, color: _darkBrown.withOpacity(0.45))),
      ],
    );
  }

  Widget _buildQuickActionCard(BuildContext context, Map<String, dynamic> action) {
    return GestureDetector(
      onTap: () => onCardTap?.call(action),
      child: Container(
        margin: EdgeInsets.only(bottom: 0.6.h),
        padding: EdgeInsets.symmetric(horizontal: 3.5.w, vertical: 1.2.h),
        decoration: BoxDecoration(
          color: _saffronGold.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _saffronGold.withOpacity(0.18), width: 0.8),
        ),
        child: Row(
          children: [
            Text(action['label']?.toString() ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: _saffronGold.withOpacity(0.5)),
          ],
        ),
      ),
    );
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
// RICH MARKDOWN RENDERER — Full Block-Level Support
// ═══════════════════════════════════════════════════════════════

class _MarkdownLite extends StatelessWidget {
  final String text;
  final Color baseColor;
  const _MarkdownLite({required this.text, required this.baseColor});

  static const Color _saffronGold = Color(0xFFDAA520);
  static const Color _accentGreen = Color(0xFF4A7C59);

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) return const SizedBox.shrink();

    final lines = text.split('\n');
    final widgets = <Widget>[];
    int i = 0;

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Empty line → spacing
      if (trimmed.isEmpty) {
        widgets.add(SizedBox(height: 0.6.h));
        i++;
        continue;
      }

      // Horizontal rule
      if (RegExp(r'^-{3,}$|^\*{3,}$|^_{3,}$').hasMatch(trimmed)) {
        widgets.add(Padding(
          padding: EdgeInsets.symmetric(vertical: 0.8.h),
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_saffronGold.withOpacity(0.0), _saffronGold.withOpacity(0.3), _saffronGold.withOpacity(0.0)],
              ),
            ),
          ),
        ));
        i++;
        continue;
      }

      // Headings
      if (trimmed.startsWith('### ')) {
        widgets.add(_buildHeading(context, trimmed.substring(4), 3));
        i++;
        continue;
      }
      if (trimmed.startsWith('## ')) {
        widgets.add(_buildHeading(context, trimmed.substring(3), 2));
        i++;
        continue;
      }
      if (trimmed.startsWith('# ')) {
        widgets.add(_buildHeading(context, trimmed.substring(2), 1));
        i++;
        continue;
      }

      // Bullet list — collect consecutive bullet lines
      if (RegExp(r'^[-*•]\s').hasMatch(trimmed)) {
        final items = <String>[];
        while (i < lines.length && RegExp(r'^\s*[-*•]\s').hasMatch(lines[i].trim())) {
          items.add(lines[i].trim().replaceFirst(RegExp(r'^[-*•]\s+'), ''));
          i++;
        }
        widgets.add(_buildBulletList(context, items));
        continue;
      }

      // Numbered list — collect consecutive numbered lines
      if (RegExp(r'^\d+[.)]\s').hasMatch(trimmed)) {
        final items = <String>[];
        while (i < lines.length && RegExp(r'^\s*\d+[.)]\s').hasMatch(lines[i].trim())) {
          items.add(lines[i].trim().replaceFirst(RegExp(r'^\d+[.)]\s+'), ''));
          i++;
        }
        widgets.add(_buildNumberedList(context, items));
        continue;
      }

      // Regular paragraph
      widgets.add(Padding(
        padding: EdgeInsets.only(bottom: 0.3.h),
        child: _buildInlineRichText(context, trimmed),
      ));
      i++;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: widgets,
    );
  }

  Widget _buildHeading(BuildContext context, String text, int level) {
    final double fontSize = level == 1 ? 17.0 : (level == 2 ? 15.5 : 14.5);
    final FontWeight weight = level == 1 ? FontWeight.w800 : FontWeight.w700;

    return Padding(
      padding: EdgeInsets.only(top: 0.8.h, bottom: 0.4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold accent bar for headings
          Container(
            width: 3,
            height: fontSize + 4,
            margin: const EdgeInsets.only(right: 8, top: 2),
            decoration: BoxDecoration(
              color: _saffronGold,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: _buildInlineRichText(
              context, text,
              overrideSize: fontSize,
              overrideWeight: weight,
              overrideColor: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletList(BuildContext context, List<String> items) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w, top: 0.3.h, bottom: 0.3.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.map((item) => Padding(
          padding: EdgeInsets.only(bottom: 0.4.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsets.only(top: 7, right: 10),
                decoration: BoxDecoration(
                  color: _saffronGold.withOpacity(0.7),
                  shape: BoxShape.circle,
                ),
              ),
              Expanded(child: _buildInlineRichText(context, item)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  Widget _buildNumberedList(BuildContext context, List<String> items) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w, top: 0.3.h, bottom: 0.3.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: items.asMap().entries.map((entry) => Padding(
          padding: EdgeInsets.only(bottom: 0.4.h),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${entry.key + 1}.',
                  style: TextStyle(
                    color: _saffronGold,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.55,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(child: _buildInlineRichText(context, entry.value)),
            ],
          ),
        )).toList(),
      ),
    );
  }

  /// Parse inline formatting: **bold**, *italic*, `code`, emoji-safe
  RichText _buildInlineRichText(BuildContext context, String text, {
    double? overrideSize,
    FontWeight? overrideWeight,
    Color? overrideColor,
  }) {
    final spans = <TextSpan>[];
    // Match **bold**, *italic*, `code`
    final regex = RegExp(r'\*\*(.+?)\*\*|\*(.+?)\*|`(.+?)`');
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
            color: Theme.of(context).colorScheme.primary,
          ),
        ));
      } else if (match.group(2) != null) {
        // Italic
        spans.add(TextSpan(
          text: match.group(2),
          style: TextStyle(
            fontStyle: FontStyle.italic,
            color: baseColor.withOpacity(0.85),
          ),
        ));
      } else if (match.group(3) != null) {
        // Code
        spans.add(TextSpan(
          text: ' ${match.group(3)} ',
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: baseColor.withOpacity(0.06),
            fontSize: 13,
            color: _accentGreen,
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
        style: TextStyle(
          color: overrideColor ?? baseColor,
          fontSize: overrideSize ?? 14.5,
          fontWeight: overrideWeight ?? FontWeight.w400,
          height: 1.55,
        ),
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
  List<Map<String, dynamic>> attachedCards; // Rich cards (session, task, progress, quick_action)

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.imageUrl,
    List<Map<String, dynamic>>? attachedCards,
  }) : attachedCards = attachedCards ?? [];
}

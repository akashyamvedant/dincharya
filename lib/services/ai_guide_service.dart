import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/intl.dart';

import './supabase_service.dart';
import './guided_session_service.dart';
import './analytics_service.dart';
import './local_tasks_service.dart';
import './routine_tracking_service.dart';
import './payment_service.dart';
import './subscription_manager.dart';
import '../core/security_config.dart';

/// AI Guide Service — "Disha" (दिशा)
/// World-class Ayurvedic wellness AI with full user context awareness.
///
/// Connects to a4f.co (OpenAI-compatible API)
/// Text: provider-5/gemini-3-pro | Images: provider-4/imagen-4
class AiGuideService {
  // Singleton
  static final AiGuideService _instance = AiGuideService._internal();
  factory AiGuideService() => _instance;
  AiGuideService._internal();

  // ── Services ──
  final SupabaseService _supabase = SupabaseService();
  final GuidedSessionService _sessions = GuidedSessionService();
  final AnalyticsService _analytics = AnalyticsService();
  final LocalTasksService _tasks = LocalTasksService();
  final RoutineTrackingService _routineTracking = RoutineTrackingService();
  final PaymentService _payment = PaymentService();
  final SubscriptionManager _subscriptionManager = SubscriptionManager();

  // ── API Config ──
  late final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.a4f.co/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 60),
    headers: {'Content-Type': 'application/json'},
  ));

  static const String _model = 'provider-5/gemini-3-pro';
  static const String _fallbackModel = 'google/gemini-2.0-flash';
  static const String _imageModel = 'provider-4/imagen-4';

  String get _apiKey => dotenv.env['A4F_API_KEY'] ?? '';

  // ── Chat History ──
  final List<Map<String, String>> _chatHistory = [];

  // ═══════════════════════════════════════════════════════════════
  // IMAGE GENERATION
  // ═══════════════════════════════════════════════════════════════

  /// Keywords that indicate user wants an image (Hindi + English)
  static final _imageKeywords = RegExp(
    r'\b(image|picture|photo|draw|paint|sketch|visualize|illustrat|generate.*image'
    r'|create.*image|show.*image|make.*image|banao|dikha|dikhao|tasveer|chitra'
    r'|photo.*banao|image.*banao|picture.*banao|draw.*karo|painting)\b',
    caseSensitive: false,
  );

  /// Check if user message is requesting an image
  bool isImageRequest(String message) => _imageKeywords.hasMatch(message);

  /// Generate an image using Imagen-4 via a4f.co
  Future<String?> generateImage(String prompt) async {
    if (_apiKey.isEmpty) return null;

    try {
      debugPrint('🎨 Generating image with Imagen-4: $prompt');

      final response = await _dio.post(
        '/images/generations',
        options: Options(
          headers: {'Authorization': 'Bearer $_apiKey'},
          receiveTimeout: const Duration(seconds: 90),
        ),
        data: {
          'model': _imageModel,
          'prompt': prompt,
          'n': 1,
          'size': '1024x1024',
        },
      );

      final json = response.data as Map<String, dynamic>;
      final dataList = json['data'] as List?;
      if (dataList != null && dataList.isNotEmpty) {
        final imageUrl = dataList[0]['url'] as String?;
        debugPrint('✅ Image generated successfully');
        return imageUrl;
      }
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Image generation error: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('❌ Image generation error: $e');
      return null;
    }
  }

  /// Build image prompt — uses AI to create a contextual, high-quality prompt
  /// based on the full conversation context and user's actual request.
  Future<String> buildImagePrompt(String userRequest) async {
    // Use the last few messages for context
    final recentContext = _chatHistory.take(6).map((m) => '${m['role']}: ${m['content']}').join('\n');

    final metaPrompt = '''You are an expert image prompt engineer. Based on the conversation below and the user's latest request, create a single detailed image generation prompt.

Conversation context:
$recentContext

User's image request: "$userRequest"

Rules:
- Output ONLY the image prompt, nothing else
- Make it specific and vivid, directly related to what the user asked
- Include style details: lighting, mood, composition, colors
- Add "Indian aesthetic, professional quality, no text overlay" at the end
- If user asked for motivational content, describe an uplifting scene (sunrise, nature, meditation, lotus, mountains, etc.)
- Max 80 words''';

    try {
      final response = await _dio.post(
        '/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $_apiKey'}),
        data: {
          'model': _model,
          'messages': [
            {'role': 'user', 'content': metaPrompt},
          ],
          'stream': false,
          'temperature': 0.9,
          'max_tokens': 150,
        },
      );

      final json = response.data as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final prompt = (choices[0]['message']['content'] as String?)?.trim() ?? '';
        if (prompt.isNotEmpty) {
          debugPrint('🎨 AI-generated image prompt: $prompt');
          return prompt;
        }
      }
    } catch (e) {
      debugPrint('⚠️ Failed to generate smart prompt, using fallback: $e');
    }

    // Fallback: simple cleanup
    final cleaned = userRequest
        .replaceAll(RegExp(r'\b(banao|dikha|dikhao|draw|paint|sketch|generate|create|show|make|visualize|image|picture|photo|tasveer|chitra|karo|mujhe|ek|ka|ki|ke|of|an?|the|please|mera|mere|apna)\b', caseSensitive: false), '')
        .trim();
    final subject = cleaned.isNotEmpty ? cleaned : userRequest;
    return '$subject, beautiful illustration, warm colors, Indian aesthetic, professional quality, no text overlay';
  }

  // ═══════════════════════════════════════════════════════════════
  // RICH USER CONTEXT (Secure — no PII, only stats)
  // ═══════════════════════════════════════════════════════════════

  /// Build comprehensive user context from all services
  /// Security: Only aggregated stats sent — never raw journal content,
  /// task descriptions, or personal notes.
  Future<String> _buildUserContext() async {
    final contextParts = <String>[];

    // ── 1. Basic Profile ──
    try {
      await _sessions.loadUserProfile();
      final dosha = _sessions.userDosha;
      final goals = _sessions.userGoals;
      if (dosha != null) contextParts.add('Prakriti (Dosha): $dosha');
      if (goals.isNotEmpty) contextParts.add('Wellness Goals: ${goals.join(", ")}');
    } catch (_) {}

    // ── 2. User Name & Subscription ──
    try {
      final userId = _supabase.currentUser?.id;
      if (userId != null) {
        final client = await _supabase.client;
        if (client != null) {
          final profile = await client
              .from('user_profiles')
              .select('full_name, current_streak, best_streak, total_tasks_completed, total_minutes_tracked, created_at')
              .eq('id', userId)
              .maybeSingle();

          if (profile != null) {
            final name = profile['full_name'] as String?;
            if (name != null && name.isNotEmpty) {
              // Security: only first name
              contextParts.add('Name: ${name.split(' ').first}');
            }
            contextParts.add('Current Streak: ${profile['current_streak'] ?? 0} days');
            contextParts.add('Best Streak: ${profile['best_streak'] ?? 0} days');
            contextParts.add('Total Tasks Completed: ${profile['total_tasks_completed'] ?? 0}');
            contextParts.add('Total Minutes Tracked: ${profile['total_minutes_tracked'] ?? 0}');

            // Join date
            final createdAt = profile['created_at'] as String?;
            if (createdAt != null) {
              try {
                final joinDate = DateTime.parse(createdAt);
                final daysSinceJoin = DateTime.now().difference(joinDate).inDays;
                contextParts.add('Member for: $daysSinceJoin days');
              } catch (_) {}
            }
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Context: profile fetch error: $e');
    }

    // ── 3. Subscription Status ──
    try {
      await _subscriptionManager.initialize();
      final isPremium = _subscriptionManager.isPremium;
      contextParts.add('Subscription: ${isPremium ? "Premium" : "Free"}');
      if (!isPremium) {
        final remaining = _subscriptionManager.aiMessagesRemaining;
        contextParts.add('AI messages remaining today: $remaining/${ SubscriptionManager.freeAiDailyLimit}');
      }
    } catch (_) {
      contextParts.add('Subscription: Free');
    }

    // ── 4. Today's Routine Progress ──
    try {
      final todayProgress = await _routineTracking.getTodayProgress();
      if (todayProgress is Map) {
        final completed = todayProgress['completed'] ?? 0;
        final total = todayProgress['total'] ?? 0;
        if (total > 0) {
          final pct = ((completed / total) * 100).round();
          contextParts.add('Today\'s Routine: $completed/$total tasks done ($pct%)');
        }
      }
    } catch (_) {}

    // ── 5. Weekly Practice Stats ──
    try {
      final weeklyStats = await _sessions.getWeeklyPracticeStats();
      final totalMin = weeklyStats['totalMinutes'] ?? 0;
      final sesCount = weeklyStats['sessionsCount'] ?? 0;
      if (totalMin > 0 || sesCount > 0) {
        contextParts.add('This Week: $totalMin min practice, $sesCount sessions');
      }

      final challengeProgress = await _sessions.getWeeklyChallengeProgress();
      contextParts.add('Weekly Challenge: Practiced $challengeProgress/7 days');
    } catch (_) {}

    // ── 6. Discipline Score ──
    try {
      final discipline = await _analytics.calculateDisciplineScore();
      final score = discipline.totalScore;
      String level;
      if (score >= 80) {
        level = 'Excellent';
      } else if (score >= 60) {
        level = 'Good';
      } else if (score >= 40) {
        level = 'Average';
      } else {
        level = 'Needs Improvement';
      }
      contextParts.add('Discipline Score: $score/100 ($level)');
    } catch (_) {}

    // ── 7. Journal Activity (counts only — no content!) ──
    try {
      final userId = _supabase.currentUser?.id;
      if (userId != null) {
        final client = await _supabase.client;
        if (client != null) {
          final journals = await client
              .from('journal_entries')
              .select('id, created_at')
              .eq('user_id', userId)
              .order('created_at', ascending: false)
              .limit(10);

          contextParts.add('Journal Entries: ${journals.length}+ total');
          if (journals.isNotEmpty) {
            try {
              final lastEntry = DateTime.parse(journals[0]['created_at'] as String);
              final daysSince = DateTime.now().difference(lastEntry).inDays;
              contextParts.add('Last Journal: ${daysSince == 0 ? "Today" : daysSince == 1 ? "Yesterday" : "$daysSince days ago"}');
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    // ── 8. Task Stats (counts only — no descriptions!) ──
    try {
      final taskStats = await _tasks.getTaskStatistics();
      final pending = taskStats['pending'] ?? 0;
      final overdue = taskStats['overdue'] ?? 0;
      final completed = taskStats['completed'] ?? 0;
      if (pending + overdue + completed > 0) {
        contextParts.add('Tasks: $pending pending, $overdue overdue, $completed completed');
      }
    } catch (_) {}

    // ── 9. Time & Prahar Context ──
    final now = DateTime.now();
    final hour = now.hour;
    final dayName = DateFormat('EEEE').format(now);
    final dateStr = DateFormat('d MMMM yyyy').format(now);

    String prahar;
    String praharAdvice;
    if (hour >= 4 && hour < 6) {
      prahar = 'Brahma Muhurta (ब्रह्म मुहूर्त)';
      praharAdvice = 'Most auspicious time for meditation, pranayama, and spiritual practice.';
    } else if (hour >= 6 && hour < 10) {
      prahar = 'Kapha Kaal (कफ काल)';
      praharAdvice = 'Best for exercise, yoga, and energizing activities.';
    } else if (hour >= 10 && hour < 14) {
      prahar = 'Pitta Kaal (पित्त काल)';
      praharAdvice = 'Peak digestion — best time for the main meal and focused work.';
    } else if (hour >= 14 && hour < 18) {
      prahar = 'Vata Kaal (वात काल)';
      praharAdvice = 'Creative energy peaks. Light activities and creative work.';
    } else if (hour >= 18 && hour < 22) {
      prahar = 'Kapha Kaal (सायं कफ काल)';
      praharAdvice = 'Wind-down time. Light dinner, gentle yoga, gratitude practice.';
    } else {
      prahar = 'Nidra Kaal (निद्रा काल)';
      praharAdvice = 'Sleep time. Yoga Nidra, sleep meditation, or deep rest.';
    }

    contextParts.add('Current Time: $dayName, $dateStr, ${DateFormat('h:mm a').format(now)}');
    contextParts.add('Prahar: $prahar — $praharAdvice');

    return contextParts.join('\n');
  }

  // ═══════════════════════════════════════════════════════════════
  // SYSTEM PROMPT — WORLD-CLASS
  // ═══════════════════════════════════════════════════════════════

  /// Build the complete system prompt with full context
  Future<String> _buildSystemPrompt() async {
    final userContext = await _buildUserContext();

    return '''You are "Disha" (दिशा) — Ayurvedic wellness AI guide in the Dincharya app.

═══ PERSONALITY ═══
- Warm, wise, encouraging — like a caring elder
- Deep knowledge of Ayurveda, yoga, meditation, pranayama
- Emotionally intelligent, celebrates wins, gently motivates
- Use emojis sparingly: 🧘 🌿 ✨ 🙏

═══ LANGUAGE ═══
- ALWAYS respond in the SAME language user writes in (Hindi/English/Hinglish)
- Mix Sanskrit terms naturally with brief explanations
- Keep responses 2-4 paragraphs max, concise but complete

═══ USER CONTEXT ═══
$userContext

═══ CAPABILITIES ═══
1. Personalized coaching using dosha, goals, streak, discipline score
2. Image generation: When user asks for image/picture/draw/dikha/banao, ALWAYS describe what image you're creating in your text naturally
3. Prahar-aware recommendations based on current Ayurvedic time
4. Progress tracking — reference streak, scores to motivate
5. Session recommendations — meditation, pranayama, yoga, breathing
6. Routine optimization based on dosha
7. Journal companion — encourage journaling
8. Task awareness — help prioritize pending/overdue tasks

═══ RULES ═══
- Never diagnose or prescribe medicine
- Stay within wellness topics; redirect unrelated questions with humor
- Use markdown: **bold**, bullet points, numbered lists
- Keep responses actionable
- End with engaging question or suggestion when natural''';
  }

  // ═══════════════════════════════════════════════════════════════
  // CHAT — STREAMING
  // ═══════════════════════════════════════════════════════════════

  /// Send a message and get a streaming response
  Stream<String> sendMessage(String userMessage) async* {
    if (_apiKey.isEmpty) {
      yield 'AI Guide is not configured yet. Please add your A4F API key to the .env file.';
      return;
    }

    // ── Check AI message limit for free users ──
    await _subscriptionManager.initialize();
    if (!_subscriptionManager.hasAiMessagesLeft) {
      yield '🔒 You\'ve reached your daily limit of ${SubscriptionManager.freeAiDailyLimit} messages.\n\n'
          'Upgrade to **Premium** for unlimited AI Guide conversations, '
          'advanced analytics, premium sessions, and more!\n\n'
          '✨ Tap your profile → "Upgrade to Premium" to unlock everything.';
      return;
    }

    // Track this message for free users
    _subscriptionManager.trackAiMessage();

    // Sanitize user input for security
    final sanitizedMessage = SecurityConfig.sanitizeString(userMessage, maxLength: 2000);

    // Add user message to history
    _chatHistory.add({'role': 'user', 'content': sanitizedMessage});

    // Build messages array with full context
    String systemPrompt;
    try {
      systemPrompt = await _buildSystemPrompt();
    } catch (e) {
      debugPrint('⚠️ System prompt build failed, using fallback: $e');
      systemPrompt = 'You are Disha, a friendly Ayurvedic wellness AI guide for the Dincharya app. Respond in Hinglish.';
    }

    // Filter out empty messages from history
    final validHistory = _chatHistory
        .where((m) => (m['content'] ?? '').trim().isNotEmpty)
        .toList();
    // Keep only the last 6 messages to stay within token limits
    final recentHistory = validHistory.length > 6
        ? validHistory.sublist(validHistory.length - 6)
        : validHistory;

    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...recentHistory,
    ];

    debugPrint('📤 AI Guide sending ${messages.length} messages (system prompt: ${systemPrompt.length} chars)');

    try {
      // Use non-streaming API call (streaming returns empty from a4f.co)
      final response = await _dio.post(
        '/chat/completions',
        options: Options(
          headers: {'Authorization': 'Bearer $_apiKey'},
          receiveTimeout: const Duration(seconds: 60),
        ),
        data: {
          'model': _model,
          'messages': messages,
          'stream': false,
          'temperature': 0.7,
          'max_tokens': 800,
        },
      );

      final json = response.data as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      String fullResponse = '';

      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        fullResponse = message?['content'] as String? ?? '';
      }

      debugPrint('📥 AI Guide response: ${fullResponse.length} chars');

      if (fullResponse.isEmpty) {
        debugPrint('⚠️ AI returned empty response!');
        yield 'Kuch samajh nahi aaya. Kya aap dubara pooch sakte hain? 🙏';
        return;
      }

      // Simulate streaming by yielding words progressively
      final words = fullResponse.split(' ');
      final buffer = StringBuffer();
      for (int i = 0; i < words.length; i++) {
        if (i > 0) buffer.write(' ');
        buffer.write(words[i]);
        yield buffer.toString();
        // Small delay for natural feel (every 3 words)
        if (i % 3 == 0) {
          await Future.delayed(const Duration(milliseconds: 15));
        }
      }

      // Add assistant response to history
      if (fullResponse.isNotEmpty) {
        _chatHistory.add({'role': 'assistant', 'content': fullResponse});
      }
    } on DioException catch (e) {
      debugPrint('❌ AI Guide error: ${e.message}');
      // Log the actual error body for debugging
      if (e.response?.data != null) {
        debugPrint('❌ API error body: ${e.response?.data}');
      }
      if (e.response?.statusCode == 500 || e.response?.statusCode == 503) {
        // Retry with minimal context
        debugPrint('🔄 Retrying with fallback model and minimal context...');
        try {
          final retryMessages = <Map<String, String>>[
            {'role': 'system', 'content': 'You are Disha, a friendly Ayurvedic wellness AI guide. Respond in the same language the user writes in.'},
            {'role': 'user', 'content': sanitizedMessage},
          ];
          final retryResponse = await _dio.post(
            '/chat/completions',
            options: Options(
              headers: {'Authorization': 'Bearer $_apiKey'},
              receiveTimeout: const Duration(seconds: 60),
            ),
            data: {
              'model': _fallbackModel,
              'messages': retryMessages,
              'stream': false,
              'temperature': 0.7,
              'max_tokens': 500,
            },
          );
          final retryJson = retryResponse.data as Map<String, dynamic>;
          final retryChoices = retryJson['choices'] as List?;
          if (retryChoices != null && retryChoices.isNotEmpty) {
            final retryContent = (retryChoices[0]['message'] as Map<String, dynamic>?)?['content'] as String? ?? '';
            if (retryContent.isNotEmpty) {
              debugPrint('✅ Retry succeeded: ${retryContent.length} chars');
              final words = retryContent.split(' ');
              final buf = StringBuffer();
              for (int i = 0; i < words.length; i++) {
                if (i > 0) buf.write(' ');
                buf.write(words[i]);
                yield buf.toString();
                if (i % 3 == 0) await Future.delayed(const Duration(milliseconds: 15));
              }
              _chatHistory.add({'role': 'assistant', 'content': retryContent});
              return;
            }
          }
          yield 'Server busy. Please try again in a moment. 🙏';
        } catch (retryError) {
          debugPrint('❌ Retry also failed: $retryError');
          yield 'Server is currently busy. Please try again in a moment. 🙏';
        }
      } else if (e.response?.statusCode == 401) {
        yield 'API key invalid. Please check your A4F API key in the .env file.';
      } else if (e.response?.statusCode == 429) {
        yield 'Too many requests. Please wait a moment and try again. 🙏';
      } else {
        yield 'Unable to connect to AI Guide right now. Please check your internet connection and try again.';
      }
    } catch (e) {
      debugPrint('❌ AI Guide error: $e');
      yield 'Something went wrong. Please try again. 🙏';
    }
  }

  /// Send a non-streaming message (for quick recommendations)
  Future<String> sendQuickMessage(String userMessage) async {
    if (_apiKey.isEmpty) return 'AI Guide not configured.';

    final sanitizedMessage = SecurityConfig.sanitizeString(userMessage, maxLength: 1000);
    final systemPrompt = await _buildSystemPrompt();
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': sanitizedMessage},
    ];

    try {
      final response = await _dio.post(
        '/chat/completions',
        options: Options(headers: {'Authorization': 'Bearer $_apiKey'}),
        data: {
          'model': _model,
          'messages': messages,
          'stream': false,
          'temperature': 0.7,
          'max_tokens': 512,
        },
      );

      final json = response.data as Map<String, dynamic>;
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        return choices[0]['message']['content'] as String? ?? 'No response.';
      }
      return 'No response.';
    } catch (e) {
      debugPrint('❌ AI quick message error: $e');
      return 'Unable to get recommendation right now.';
    }
  }

  /// Clear chat history (in-memory + Supabase)
  Future<void> clearHistory() async {
    _chatHistory.clear();
    try {
      final user = _supabase.currentUser;
      if (user == null) return;
      final client = await _supabase.client;
      if (client == null) return;
      await client.from('ai_chat_messages').delete().eq('user_id', user.id);
      debugPrint('🗑️ AI chat history cleared from Supabase');
    } catch (e) {
      debugPrint('⚠️ Failed to clear chat history from Supabase: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SUPABASE PERSISTENCE
  // ═══════════════════════════════════════════════════════════════

  /// Save a single message to Supabase
  Future<void> saveMessage({
    required String role,
    required String content,
    String? imageUrl,
  }) async {
    try {
      final user = _supabase.currentUser;
      if (user == null) return;
      final client = await _supabase.client;
      if (client == null) return;

      await client.from('ai_chat_messages').insert({
        'user_id': user.id,
        'role': role,
        'content': content,
        'image_url': imageUrl,
      });
    } catch (e) {
      debugPrint('⚠️ Failed to save AI chat message: $e');
    }
  }

  /// Load chat history from Supabase (last 50 messages)
  Future<List<Map<String, dynamic>>> loadChatHistory() async {
    try {
      final user = _supabase.currentUser;
      if (user == null) return [];
      final client = await _supabase.client;
      if (client == null) return [];

      final data = await client
          .from('ai_chat_messages')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true)
          .limit(50);

      // Also populate in-memory chat history for API context (skip empty messages)
      _chatHistory.clear();
      for (final msg in data) {
        final content = (msg['content'] as String?) ?? '';
        if (content.trim().isNotEmpty) {
          _chatHistory.add({
            'role': msg['role'] as String,
            'content': content,
          });
        }
      }

      debugPrint('📥 Loaded ${data.length} AI chat messages from Supabase');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('⚠️ Failed to load AI chat history: $e');
      return [];
    }
  }

  /// Get suggested quick prompts based on time of day
  List<String> getSuggestedPrompts() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 8) {
      return [
        '🌅 Best morning routine for me?',
        '🧘 Which meditation should I do now?',
        '🌬️ Teach me a morning pranayama',
        '🎨 Draw a peaceful sunrise meditation',
      ];
    } else if (hour >= 8 && hour < 12) {
      return [
        '💪 Quick yoga for energy boost',
        '🧠 Help me focus at work',
        '☕ Ayurvedic morning diet tips',
        '📊 How am I doing this week?',
      ];
    } else if (hour >= 12 && hour < 17) {
      return [
        '😴 I feel sleepy after lunch',
        '🌬️ 5-minute desk breathing exercise',
        '🧘 Quick stress relief technique',
        '🎨 Draw a calming nature scene',
      ];
    } else if (hour >= 17 && hour < 21) {
      return [
        '🌇 Evening wind-down routine',
        '🧘‍♀️ Gentle yoga for after work',
        '🍵 Ayurvedic evening routine tips',
        '📊 Show my progress today',
      ];
    } else {
      return [
        '🌙 Help me sleep better tonight',
        '😌 Yoga Nidra for deep rest',
        '🧘 Bedtime meditation for peace',
        '🎨 Draw a peaceful moonlit scene',
      ];
    }
  }
}

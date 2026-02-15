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

  /// Build image prompt — keeps user's intent natural, adds minimal style suffix
  /// FIX: Previously used a static template that made all images look the same.
  /// Now passes user's actual request as the core prompt for variety.
  String buildImagePrompt(String userRequest) {
    // Extract the actual visual request (strip command words)
    final cleaned = userRequest
        .replaceAll(RegExp(r'\b(banao|dikha|dikhao|draw|paint|sketch|generate|create|show|make|visualize|image|picture|photo|tasveer|chitra|karo|mujhe|ek|ka|ki|ke|of|an?|the|please|mera|mere|apna)\b', caseSensitive: false), '')
        .trim();

    final subject = cleaned.isNotEmpty ? cleaned : userRequest;

    // Add unique variation via timestamp to prevent repetition
    final timeVariation = DateTime.now().millisecondsSinceEpoch % 1000;
    final styles = [
      'watercolor style, soft lighting',
      'oil painting style, golden hour',
      'digital art, vibrant colors',
      'serene illustration, pastel tones',
      'realistic photography style, natural light',
    ];
    final style = styles[timeVariation % styles.length];

    return '$subject, $style, Indian aesthetic, professional quality, no text overlay';
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
              .select('full_name, current_streak, best_streak, total_tasks_completed, total_xp, created_at')
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
            contextParts.add('Total XP: ${profile['total_xp'] ?? 0}');

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

    return '''You are "Disha" (दिशा) — a world-class Ayurvedic wellness AI guide inside the Dincharya app.
You are among the smartest wellness AI assistants in the world. You combine deep Ayurvedic wisdom with modern wellness science.

═══ PERSONALITY ═══
- You are warm, wise, encouraging — like a caring elder who genuinely cares for the user's wellbeing
- You have deep knowledge of Ayurveda, yoga, meditation, pranayama, and holistic health
- You are emotionally intelligent — you read between the lines of what users say
- You celebrate small wins and gently motivate during tough times
- Use emojis sparingly but warmly 🧘 🌿 ✨ 🙏

═══ LANGUAGE RULES ═══
- **CRITICAL**: Always respond in the SAME LANGUAGE the user writes in
- If user writes in Hindi → respond in Hindi
- If user writes in English → respond in English
- If user writes in Hinglish → respond in Hinglish
- Mix Sanskrit/Ayurvedic terms naturally when relevant with brief explanations
- Keep responses concise but complete (2-5 paragraphs max)

═══ LIVE USER CONTEXT ═══
$userContext

═══ YOUR CAPABILITIES ═══
You have access to these powerful features — use them wisely:

1. **Personalized Coaching**: You know the user's dosha, goals, streak, discipline score, and practice patterns. Use this data to give hyper-personalized advice.

2. **Image Generation**: When user asks for an image (using words like "draw", "image", "picture", "dikha", "tasveer", "banao"), you generate a beautiful wellness illustration using Imagen-4. Mention that you're creating an image in your text response.

3. **Prahar Awareness**: You know the current Ayurvedic time period. Recommend activities that are optimal for the current prahar.

4. **Progress Tracking Awareness**: You can see the user's streak, discipline score, today's completion %, and weekly stats. Reference these to motivate or course-correct.

5. **App Session Recommendations**: Recommend specific sessions from the app — meditation, pranayama, yoga, breathing exercises, soundscapes, and guided programs.

6. **Routine Guidance**: Help users build, optimize, and follow their daily Dincharya (routine) based on their dosha and lifestyle.

7. **Journal Companion**: Encourage journaling. If user hasn't journaled recently, gently remind them.

8. **Task Awareness**: You can see if the user has overdue or pending tasks. Offer to help prioritize.

═══ SMART BEHAVIORS ═══
- If user's streak is high → celebrate it! 🎉
- If streak is 0 or broken → encourage gently, no guilt
- If discipline score is low → suggest small, manageable steps
- If no practice this week → motivate with a simple 5-minute suggestion
- If user has overdue tasks → offer to help them prioritize
- If it's Brahma Muhurta → praise the user for being up early
- If user seems stressed → prioritize calming techniques
- If user asks about capabilities → list what you can do impressively

═══ BOUNDARIES ═══
- Never diagnose medical conditions or prescribe medicine
- Always suggest consulting a doctor/vaidya for health concerns
- Stay within wellness, yoga, meditation, Ayurveda, and productivity topics
- If asked about totally unrelated topics → gently redirect to wellness with humor
- Never share raw personal data back — only reference it naturally in advice

═══ RESPONSE FORMAT ═══
- Use markdown: **bold** for key terms, bullet points for steps
- Keep responses actionable — every response should have something the user can DO
- End responses with an engaging question or suggestion when natural
- For step-by-step guides → use numbered lists
- For comparisons → use brief structured format''';
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
    final systemPrompt = await _buildSystemPrompt();
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ..._chatHistory.take(20), // Keep last 20 messages for context
    ];

    try {
      final response = await _dio.post(
        '/chat/completions',
        options: Options(
          headers: {'Authorization': 'Bearer $_apiKey'},
          responseType: ResponseType.stream,
        ),
        data: {
          'model': _model,
          'messages': messages,
          'stream': true,
          'temperature': 0.7,
          'max_tokens': 1500,
        },
      );

      final stream = response.data.stream as Stream<List<int>>;
      final fullResponse = StringBuffer();
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);

        // Process complete SSE lines
        while (buffer.contains('\n')) {
          final newlineIndex = buffer.indexOf('\n');
          final line = buffer.substring(0, newlineIndex).trim();
          buffer = buffer.substring(newlineIndex + 1);

          if (line.startsWith('data: ')) {
            final data = line.substring(6).trim();
            if (data == '[DONE]') break;

            try {
              final json = jsonDecode(data) as Map<String, dynamic>;
              final choices = json['choices'] as List?;
              if (choices != null && choices.isNotEmpty) {
                final delta = choices[0]['delta'] as Map<String, dynamic>?;
                final content = delta?['content'] as String?;
                if (content != null) {
                  fullResponse.write(content);
                  yield fullResponse.toString();
                }
              }
            } catch (_) {
              // Skip malformed chunks
            }
          }
        }
      }

      // Add assistant response to history
      final finalResponse = fullResponse.toString();
      if (finalResponse.isNotEmpty) {
        _chatHistory.add({'role': 'assistant', 'content': finalResponse});
      }
    } on DioException catch (e) {
      debugPrint('❌ AI Guide error: ${e.message}');
      if (e.response?.statusCode == 401) {
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

  /// Clear chat history
  void clearHistory() => _chatHistory.clear();

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

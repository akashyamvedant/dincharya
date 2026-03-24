import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
/// Chat: Sarvam AI (sarvam-105b) — Free, unlimited
/// Images: OpenRouter (black-forest-labs/flux.2-flex)
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

  // ── Chat API Config (Sarvam AI) ──
  late final Dio _chatDio = Dio(BaseOptions(
    baseUrl: 'https://api.sarvam.ai/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 90),
    headers: {'Content-Type': 'application/json'},
  ));

  // ── Image API Config (OpenRouter — black-forest-labs/flux.2-flex) ──
  late final Dio _imageDio = Dio(BaseOptions(
    baseUrl: 'https://openrouter.ai/api/v1',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 120),
    headers: {'Content-Type': 'application/json'},
  ));

  static const String _model = 'sarvam-105b';
  static const String _fallbackModel = 'sarvam-105b-32k';
  static const String _imageModel = 'black-forest-labs/flux.2-flex';

  String get _sarvamApiKey => dotenv.env['SARVAM_API_KEY'] ?? '';
  String get _openRouterApiKey => dotenv.env['OPENROUTER_API_KEY'] ?? '';

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

  /// Generate an image using flux.2-flex via OpenRouter
  Future<String?> generateImage(String prompt) async {
    if (_openRouterApiKey.isEmpty) {
      debugPrint('⚠️ Image generation skipped: OPENROUTER_API_KEY not configured');
      return null;
    }

    try {
      debugPrint('🎨 Generating image with flux.2-flex: $prompt');

      // OpenRouter uses chat/completions endpoint for image generation
      // FLUX.2 Flex REQUIRES modalities: ['image'] to return images
      final response = await _imageDio.post(
        '/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $_openRouterApiKey',
            'HTTP-Referer': 'https://dincharya.app',
            'X-Title': 'Dincharya - Disha AI',
          },
          receiveTimeout: const Duration(seconds: 120),
        ),
        data: {
          'model': _imageModel,
          'modalities': ['image'],
          'messages': [
            {
              'role': 'user',
              'content': prompt,
            }
          ],
        },
      );

      final json = response.data as Map<String, dynamic>;
      
      // DEBUG: Log full response structure to find where image URL is
      debugPrint('🔍 Full OpenRouter response keys: ${json.keys.toList()}');
      debugPrint('🔍 Full OpenRouter response: ${jsonEncode(json).substring(0, (jsonEncode(json).length > 500 ? 500 : jsonEncode(json).length))}');
      
      // ── Method 1: Check top-level "data" array (OpenAI images format) ──
      final dataList = json['data'] as List?;
      if (dataList != null && dataList.isNotEmpty) {
        for (final item in dataList) {
          if (item is Map<String, dynamic>) {
            // Check for url field
            final url = item['url'] as String?;
            if (url != null && url.isNotEmpty) {
              debugPrint('✅ Image generated successfully (data[].url)');
              return url;
            }
            // Check for b64_json field
            final b64 = item['b64_json'] as String?;
            if (b64 != null && b64.isNotEmpty) {
              debugPrint('✅ Image generated successfully (data[].b64_json)');
              return 'data:image/png;base64,$b64';
            }
          }
        }
      }
      
      // ── Method 2: Check choices[].message ──
      final choices = json['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices[0]['message'] as Map<String, dynamic>?;
        if (message != null) {
          debugPrint('🔍 Message keys: ${message.keys.toList()}');
          
          // ── FLUX.2 Flex specific: images are in message.images[] ──
          final images = message['images'] as List?;
          if (images != null && images.isNotEmpty) {
            for (final img in images) {
              if (img is Map<String, dynamic>) {
                // Format: {"image_url": {"url": "data:image/png;base64,..."}}
                final imageUrl = img['image_url']?['url'] as String?;
                if (imageUrl != null && imageUrl.isNotEmpty) {
                  debugPrint('✅ Image generated successfully (message.images[].image_url.url)');
                  return imageUrl;
                }
                // Also check direct url field
                final directUrl = img['url'] as String?;
                if (directUrl != null && directUrl.isNotEmpty) {
                  debugPrint('✅ Image generated successfully (message.images[].url)');
                  return directUrl;
                }
              }
              // Simple string URL
              if (img is String && img.isNotEmpty) {
                debugPrint('✅ Image generated successfully (message.images[] string)');
                return img;
              }
            }
          }
        }
        final content = message?['content'];
        
        // String content (URL or markdown)
        if (content is String && content.isNotEmpty) {
          // Direct URL
          if (content.startsWith('http')) {
            debugPrint('✅ Image generated successfully (direct URL)');
            return content.trim();
          }
          // Extract URL from any text/markdown
          final urlMatch = RegExp(r'https?://[^\s\)\"\>]+').firstMatch(content);
          if (urlMatch != null) {
            debugPrint('✅ Image generated successfully (extracted URL)');
            return urlMatch.group(0);
          }
          // Base64 data URI
          if (content.contains('data:image')) {
            final dataMatch = RegExp(r'data:image/[^;]+;base64,[A-Za-z0-9+/=]+').firstMatch(content);
            if (dataMatch != null) {
              debugPrint('✅ Image generated successfully (base64 in content)');
              return dataMatch.group(0);
            }
          }
        }
        
        // List content (multimodal parts)
        if (content is List) {
          for (final part in content) {
            if (part is Map<String, dynamic>) {
              // image_url type
              if (part['type'] == 'image_url') {
                final imageUrl = part['image_url']?['url'] as String?;
                if (imageUrl != null) {
                  debugPrint('✅ Image generated successfully (multimodal image_url)');
                  return imageUrl;
                }
              }
              // text type with URL
              if (part['type'] == 'text') {
                final text = part['text'] as String? ?? '';
                final urlMatch = RegExp(r'https?://[^\s\)\"\>]+').firstMatch(text);
                if (urlMatch != null) {
                  debugPrint('✅ Image generated successfully (text in multimodal)');
                  return urlMatch.group(0);
                }
              }
            }
          }
        }
        
        debugPrint('⚠️ Image response: content=$content');
      }
      
      // ── Method 3: Check any URL-like value in the entire response ──
      final jsonStr = jsonEncode(json);
      final anyUrlMatch = RegExp(r'https?://[^\s\)\"\>\\]+\.(png|jpg|jpeg|webp|gif)[^\s\)\"\>\\]*').firstMatch(jsonStr);
      if (anyUrlMatch != null) {
        debugPrint('✅ Image generated successfully (found URL anywhere in response)');
        return anyUrlMatch.group(0);
      }
      
      debugPrint('⚠️ No image URL found in entire response');
      return null;
    } on DioException catch (e) {
      debugPrint('❌ Image generation error: ${e.message}');
      if (e.response?.data != null) {
        debugPrint('❌ Image API error body: ${e.response?.data}');
      }
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
      final response = await _chatDio.post(
        '/chat/completions',
        options: Options(headers: {'api-subscription-key': _sarvamApiKey}),
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
    if (_sarvamApiKey.isEmpty) {
      yield 'AI Guide is not configured yet. Please add your SARVAM_API_KEY to the .env file.';
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
      // Use Sarvam AI chat completions (non-streaming)
      final response = await _chatDio.post(
        '/chat/completions',
        options: Options(
          headers: {'api-subscription-key': _sarvamApiKey},
          receiveTimeout: const Duration(seconds: 90),
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
          final retryResponse = await _chatDio.post(
            '/chat/completions',
            options: Options(
              headers: {'api-subscription-key': _sarvamApiKey},
              receiveTimeout: const Duration(seconds: 90),
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
        yield 'API key invalid. Please check your SARVAM_API_KEY in the .env file.';
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
    if (_sarvamApiKey.isEmpty) return 'AI Guide not configured.';

    final sanitizedMessage = SecurityConfig.sanitizeString(userMessage, maxLength: 1000);
    final systemPrompt = await _buildSystemPrompt();
    final messages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': sanitizedMessage},
    ];

    try {
      final response = await _chatDio.post(
        '/chat/completions',
        options: Options(headers: {'api-subscription-key': _sarvamApiKey}),
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

  // ═══════════════════════════════════════════════════════════════
  // SMART CARD DETECTION v2 — Professional multi-signal detection
  // ═══════════════════════════════════════════════════════════════

  /// Keyword sets — extensive Hindi + English coverage for every feature
  static const _kSession = [
    // English
    'session', 'yoga', 'meditation', 'pranayama', 'breathing exercise',
    'practice', 'asana', 'kriya', 'nidra', 'mindfulness', 'relaxation',
    'guided', 'begin', 'workout', 'stretch', 'warm up', 'cool down',
    'beginner', 'intermediate', 'advanced', 'morning routine', 'evening routine',
    'sleep', 'focus', 'calm', 'energy', 'stress relief', 'flexibility',
    'strength', 'balance', 'surya namaskar', 'sun salutation', 'shavasana',
    'kapalbhati', 'anulom vilom', 'bhastrika', 'ujjayi', 'nadi shodhana',
    // Hindi
    'karo', 'karna chahiye', 'shuru karo', 'abhyas', 'kaunsa session',
    'konsa session', 'session suggest', 'session recommend', 'batao kya karu',
    'subah ka', 'sham ka', 'raat ka', 'sone se pehle', 'uthne ke baad',
    'dhyan', 'dhyana', 'saans', 'pranayam', 'yog', 'asan',
    'thakan', 'aaram', 'neend', 'chain', 'shanti',
    'kaun sa', 'best session', 'top session', 'popular session',
    'try karo', 'karke dekho', 'dikhao', 'practice karo',
    'seekho', 'sikhao', 'kaise kare', 'pose', 'mudra',
  ];

  static const _kTask = [
    // English
    'task', 'tasks', 'routine', 'schedule', 'to-do', 'todo', 'plan',
    'checklist', 'pending', 'remaining', 'incomplete', 'complete',
    'today', 'daily', 'morning', 'evening', 'night', 'what should i do',
    'my day', 'agenda', 'calendar', 'reminder', 'alarm', 'next task',
    'activity', 'activities', 'goal', 'goals', 'habit', 'habits',
    // Hindi
    'kya karna hai', 'karna hai', 'aaj ka plan', 'baki', 'bacha hua',
    'aaj kya', 'kab karna', 'kitne task', 'subah kya', 'sham kya',
    'raat ko kya', 'kya bacha', 'pending kya', 'list dikhao',
    'dincharya', 'din bhar', 'pura din', 'routine dikhao',
    'kaam', 'kaam kya hai', 'schedule dikhao', 'plan dikhao',
  ];

  static const _kProgress = [
    // English
    'progress', 'streak', 'stats', 'statistics', 'performance',
    'report', 'weekly', 'monthly', 'score', 'discipline',
    'achievement', 'how am i', 'how am i doing', 'improve',
    'growth', 'journey', 'milestone', 'level', 'xp', 'points',
    'track', 'tracking', 'consistency', 'days', 'minutes practiced',
    'sessions completed', 'my data', 'analytics', 'overview',
    // Hindi
    'kaisa chal', 'kaise chal', 'kitna hua', 'kitna kiya',
    'meri progress', 'mera score', 'streak kitna', 'kitne din',
    'kya improve', 'mera data', 'record', 'hasil', 'safalta',
    'kaise kar raha', 'performance kaisi', 'report dikhao',
    'hafta', 'week', 'mahina', 'pichle din', 'aaj tak',
  ];

  static const _kProgram = [
    // English
    'program', 'course', 'challenge', 'plan', '21 day', '30 day',
    '7 day', 'week plan', 'beginner program', 'weight loss', 'detox',
    'transformation', 'journey', 'enrolled', 'enroll', 'join',
    'curriculum', 'syllabus', 'learning path', 'structured',
    // Hindi
    'program dikhao', 'course karo', 'pura program', 'join karu',
    'shuru karu program', 'kaunsa program', 'program suggest',
    'challenge karo', 'naya program', 'program list',
  ];

  static const _kCommunity = [
    // English
    'community', 'chat', 'group', 'friends', 'people', 'social',
    'share', 'discuss', 'connect', 'member', 'forum', 'post',
    'message', 'conversation', 'talk to others', 'other users',
    // Hindi
    'community dikhao', 'logo se baat', 'group join', 'dost',
    'sab log', 'community kholo', 'chat karo', 'baat karo',
  ];

  static const _kProfile = [
    // English
    'profile', 'dosha', 'prakriti', 'body type', 'vata', 'pitta',
    'kapha', 'ayurveda', 'constitution', 'settings', 'account',
    'my info', 'personal', 'edit profile', 'change name',
    'notification', 'preferences', 'theme', 'dark mode', 'light mode',
    // Hindi
    'mera profile', 'profile dikhao', 'dosha kya hai', 'prakriti kya',
    'settings kholo', 'profile edit', 'apna profile', 'account',
    'naam badlo', 'photo badlo', 'setting change',
  ];

  static const _kJournal = [
    // English
    'journal', 'diary', 'write', 'note', 'mood', 'feeling',
    'gratitude', 'reflect', 'thought', 'emotion', 'today i feel',
    'log', 'entry', 'track mood', 'how i feel', 'express',
    'grateful', 'thankful', 'happy', 'sad', 'anxious', 'stressed',
    // Hindi
    'journal likhna', 'diary likhna', 'likhna hai', 'mood track',
    'mera mood', 'aaj kaisa lag raha', 'kya feel', 'likho',
    'entry karo', 'journal kholo', 'diary kholo', 'likh ke rakho',
    'bhavna', 'feeling', 'mann', 'dil', 'khush', 'udaas',
  ];

  static const _kHelp = [
    // English  
    'help', 'support', 'problem', 'issue', 'bug', 'error',
    'not working', 'broken', 'fix', 'contact', 'ticket',
    'complaint', 'feedback', 'report', 'assist', 'guide',
    'how to use', 'tutorial', 'faq', 'question',
    // Hindi
    'madad', 'sahayta', 'dikkat', 'problem hai', 'kaam nahi',
    'galat', 'thik karo', 'complaint', 'ticket raise', 'kaise use',
    'samajh nahi', 'help chahiye', 'support chahiye',
  ];

  static const _kFavorites = [
    // English
    'favorite', 'favourites', 'saved', 'bookmarked', 'liked',
    'my sessions', 'my list', 'saved sessions', 'watch later',
    'go back to', 'repeat', 'do again', 'that session',
    // Hindi
    'pasandida', 'favorite dikhao', 'saved dikhao', 'meri list',
    'jo save kiya', 'dubara karo', 'wahi session', 'fir se',
    'pichla session', 'wapas karo',
  ];

  static const _kRoutineBuilder = [
    // English
    'routine', 'build routine', 'create routine', 'customize',
    'my routine', 'change routine', 'edit routine', 'morning plan',
    'evening plan', 'wake up', 'bedtime', 'schedule',
    // Hindi
    'routine banao', 'naya routine', 'routine badlo', 'routine set',
    'apna routine', 'subah ka routine', 'sham ka routine',
    'routine edit', 'kya karu subah', 'din kaise plan karu',
  ];

  /// ------- Main Detector -------
  Future<List<Map<String, dynamic>>> detectAndFetchCards(String aiResponse, String userQuery) async {
    final cards = <Map<String, dynamic>>[];
    final queryLower = userQuery.toLowerCase();
    final responseLower = aiResponse.toLowerCase();
    final combined = '$queryLower $responseLower';

    try {
      // ── 1. Session Cards (highest priority for a wellness app) ──
      if (_matchScore(combined, _kSession) >= 2) {
        final sessions = await _fetchMatchingSessions(combined);
        for (final s in sessions.take(3)) {
          cards.add({'type': 'session', 'data': s});
        }
      }

      // ── 2. Task Cards ──
      if (_matchScore(combined, _kTask) >= 2) {
        final tasks = await _fetchUserTasks();
        if (tasks.isNotEmpty) {
          cards.add({'type': 'task_list', 'data': tasks.take(6).toList()});
        }
      }

      // ── 3. Progress Cards ──
      if (_matchScore(combined, _kProgress) >= 2) {
        final stats = await _fetchProgressStats();
        if (stats != null) {
          cards.add({'type': 'progress', 'data': stats});
        }
      }

      // ── 4. Program Cards ──
      if (_matchScore(combined, _kProgram) >= 2) {
        final programs = await _fetchRecommendedPrograms();
        for (final p in programs.take(2)) {
          cards.add({'type': 'quick_action', 'label': '📚 ${p['title']}', 'route': '/program-detail', 'data': p});
        }
      }

      // ── 5. Quick Actions — broad feature access ──
      final quickActions = <Map<String, dynamic>>[];

      // Journal / Diary / Mood
      if (_matchScore(combined, _kJournal) >= 2) {
        quickActions.add({'type': 'quick_action', 'label': '📔 Open Journal', 'route': '/enhanced-journal'});
      }

      // Community
      if (_matchScore(combined, _kCommunity) >= 1) {
        quickActions.add({'type': 'quick_action', 'label': '👥 Community Chat', 'route': '/community'});
      }

      // Profile / Dosha / Settings
      if (_matchScore(combined, _kProfile) >= 2) {
        quickActions.add({'type': 'quick_action', 'label': '👤 My Profile & Dosha', 'route': '/enhanced-profile'});
      }

      // Routine Builder
      if (_matchScore(combined, _kRoutineBuilder) >= 2) {
        quickActions.add({'type': 'quick_action', 'label': '🔧 Routine Builder', 'route': '/routine-builder'});
      }

      // Help / Support
      if (_matchScore(combined, _kHelp) >= 2) {
        quickActions.add({'type': 'quick_action', 'label': '🆘 Help Center', 'route': '/help-center'});
      }

      // Favorites / Saved
      if (_matchScore(combined, _kFavorites) >= 1) {
        quickActions.add({'type': 'quick_action', 'label': '❤️ My Favorites', 'route': '/guided-sessions-hub'});
      }

      // Meditation Timer (specific tool)
      if (combined.contains('timer') || combined.contains('countdown') || combined.contains('ghanti') || combined.contains('alarm set')) {
        quickActions.add({'type': 'quick_action', 'label': '⏱️ Meditation Timer', 'route': '/meditation-timer'});
      }

      // Breathing Exercise
      if (combined.contains('breathing exercise') || combined.contains('saans ka abhyas') || combined.contains('breath work') || combined.contains('breathwork')) {
        quickActions.add({'type': 'quick_action', 'label': '🌬️ Breathing Exercise', 'route': '/breathing-exercise'});
      }

      // Soundscape
      if (combined.contains('soundscape') || combined.contains('nature sound') || combined.contains('ambient') || combined.contains('rain') || combined.contains('ocean') || combined.contains('music') || combined.contains('relax music') || combined.contains('aawaaz') || combined.contains('dhwani')) {
        quickActions.add({'type': 'quick_action', 'label': '🎵 Soundscapes', 'route': '/soundscape'});
      }

      // Session History
      if (combined.contains('history') || combined.contains('past session') || combined.contains('pichle session') || combined.contains('record') || combined.contains('pehle kya kiya')) {
        quickActions.add({'type': 'quick_action', 'label': '📊 Session History', 'route': '/session-history'});
      }

      // Guided Sessions Hub / Browse all
      if (combined.contains('browse') || combined.contains('explore') || combined.contains('all session') || combined.contains('sab session') || combined.contains('dekhna hai') || combined.contains('session hub')) {
        quickActions.add({'type': 'quick_action', 'label': '🧭 Browse All Sessions', 'route': '/guided-sessions-hub'});
      }

      // Payment / Premium
      if (combined.contains('premium') || combined.contains('subscribe') || combined.contains('plan') || combined.contains('payment') || combined.contains('upgrade') || combined.contains('pro') || combined.contains('paid') || combined.contains('price') || combined.contains('khareedna') || combined.contains('paisa')) {
        quickActions.add({'type': 'quick_action', 'label': '💎 Premium Plans', 'route': '/payment-plans'});
      }

      // Add unique quick actions (max 4 to avoid clutter)
      final seenRoutes = <String>{};
      for (final qa in quickActions) {
        final route = qa['route'] as String;
        if (!seenRoutes.contains(route) && cards.length < 8) {
          seenRoutes.add(route);
          cards.add(qa);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Card detection error: $e');
    }

    return cards;
  }

  /// Count how many keywords from a list match the text (weighted scoring)
  int _matchScore(String text, List<String> keywords) {
    int score = 0;
    for (final k in keywords) {
      if (text.contains(k)) {
        // Multi-word keywords get higher weight (more specific = more signal)
        score += k.contains(' ') ? 2 : 1;
      }
    }
    return score;
  }

  // ─── Data Fetchers ───

  /// Search sessions matching keywords from context
  Future<List<Map<String, dynamic>>> _fetchMatchingSessions(String context) async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      // Detect category from keywords
      String? category;
      if (context.contains('meditation') || context.contains('dhyan') || context.contains('dhyana') ||
          context.contains('nidra') || context.contains('mindfulness') || context.contains('calm') ||
          context.contains('relaxation') || context.contains('sleep') || context.contains('neend') ||
          context.contains('shavasana') || context.contains('shanti')) {
        category = 'meditation';
      } else if (context.contains('pranayama') || context.contains('pranayam') || context.contains('breathing') ||
          context.contains('saans') || context.contains('kapalbhati') || context.contains('anulom') ||
          context.contains('bhastrika') || context.contains('ujjayi') || context.contains('nadi') ||
          context.contains('breath')) {
        category = 'pranayama';
      } else if (context.contains('yoga') || context.contains('yog') || context.contains('asana') ||
          context.contains('asan') || context.contains('stretch') || context.contains('surya namaskar') ||
          context.contains('sun salutation') || context.contains('pose') || context.contains('flexibility') ||
          context.contains('strength') || context.contains('balance') || context.contains('workout')) {
        category = 'yoga';
      }

      // Detect difficulty preference
      int? maxDifficulty;
      if (context.contains('beginner') || context.contains('easy') || context.contains('simple') ||
          context.contains('aasan') || context.contains('naya') || context.contains('start')) {
        maxDifficulty = 2;
      } else if (context.contains('advanced') || context.contains('hard') || context.contains('mushkil') ||
          context.contains('expert') || context.contains('challenging')) {
        maxDifficulty = null; // no limit, prefer hard
      }

      // Time-of-day fallback for category
      if (category == null) {
        final hour = DateTime.now().hour;
        if (hour >= 4 && hour < 7) category = 'meditation';
        else if (hour >= 7 && hour < 10) category = 'yoga';
        else if (hour >= 10 && hour < 14) category = 'pranayama';
        else if (hour >= 14 && hour < 17) category = 'yoga';
        else if (hour >= 17 && hour < 20) category = 'pranayama';
        else category = 'meditation'; // night = meditation
      }

      var query = client
          .from('sessions')
          .select()
          .eq('category', category)
          .eq('is_active', true);

      if (maxDifficulty != null) {
        query = query.lte('difficulty', maxDifficulty);
      }

      final sessions = await query
          .order('view_count', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(sessions);
    } catch (e) {
      debugPrint('⚠️ Session fetch error: $e');
      return [];
    }
  }

  /// Get user's current tasks (today only for relevance)
  Future<List<Map<String, dynamic>>> _fetchUserTasks() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return [];
      final client = await _supabase.client;
      if (client == null) return [];

      final today = DateTime.now();
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      final response = await client
          .from('local_tasks')
          .select()
          .eq('user_id', userId)
          .eq('date', todayStr)
          .order('time');

      // If no tasks for today, get all tasks (maybe no date filter)
      if ((response as List).isEmpty) {
        final fallback = await client
            .from('local_tasks')
            .select()
            .eq('user_id', userId)
            .order('time')
            .limit(10);
        return List<Map<String, dynamic>>.from(fallback);
      }

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ Task fetch error: $e');
      return [];
    }
  }

  /// Get user's weekly progress stats
  Future<Map<String, dynamic>?> _fetchProgressStats() async {
    try {
      final userId = _supabase.currentUser?.id;
      if (userId == null) return null;
      final client = await _supabase.client;
      if (client == null) return null;

      final profile = await client
          .from('user_profiles')
          .select('current_streak, xp_points, discipline_score')
          .eq('id', userId)
          .maybeSingle();

      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final mondayStr = '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';

      final progress = await client
          .from('user_progress')
          .select('total_minutes')
          .eq('user_id', userId)
          .gte('date', mondayStr);

      int weeklyMinutes = 0;
      for (final p in progress) {
        weeklyMinutes += (p['total_minutes'] as int?) ?? 0;
      }

      final sessionCount = await client
          .from('practice_sessions')
          .select('id')
          .eq('user_id', userId)
          .gte('completed_at', monday.toIso8601String());

      return {
        'streak': profile?['current_streak'] ?? 0,
        'xp': profile?['xp_points'] ?? 0,
        'discipline_score': profile?['discipline_score'] ?? 0,
        'weekly_minutes': weeklyMinutes,
        'weekly_sessions': sessionCount.length,
      };
    } catch (e) {
      debugPrint('⚠️ Progress fetch error: $e');
      return null;
    }
  }

  /// Get recommended programs
  Future<List<Map<String, dynamic>>> _fetchRecommendedPrograms() async {
    try {
      final client = await _supabase.client;
      if (client == null) return [];

      final programs = await client
          .from('programs')
          .select('id, title, description, duration_days, category, image_url')
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(3);

      return List<Map<String, dynamic>>.from(programs);
    } catch (e) {
      debugPrint('⚠️ Program fetch error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VOICE — Speech-to-Text (Sarvam AI STT)
  // ═══════════════════════════════════════════════════════════════

  /// Transcribe audio file to text using Sarvam AI STT API
  Future<String?> transcribeAudio(String filePath) async {
    if (_sarvamApiKey.isEmpty) {
      debugPrint('⚠️ STT skipped: Sarvam API key not configured');
      return null;
    }

    try {
      debugPrint('🎤 Transcribing audio: $filePath');
      final file = File(filePath);
      if (!file.existsSync()) {
        debugPrint('⚠️ Audio file not found: $filePath');
        return null;
      }

      final bytes = await file.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final response = await _chatDio.post(
        '/speech-to-text',
        options: Options(
          headers: {'api-subscription-key': _sarvamApiKey},
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'input': base64Audio,
          'language_code': 'hi-IN',  // Hindi (auto-detects English too)
          'model': 'saaras:v2',
          'with_timestamps': false,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final transcript = response.data['transcript'] as String?;
        debugPrint('✅ Transcription: $transcript');
        return transcript;
      }
      return null;
    } catch (e) {
      debugPrint('❌ STT Error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // VOICE — Text-to-Speech (Sarvam AI TTS)
  // ═══════════════════════════════════════════════════════════════

  /// Convert text to speech using Sarvam AI TTS API (Bulbul)
  /// Returns the path to the saved audio file, or null on failure
  Future<String?> speakText(String text, {String targetLang = 'hi-IN'}) async {
    if (_sarvamApiKey.isEmpty) {
      debugPrint('⚠️ TTS skipped: Sarvam API key not configured');
      return null;
    }

    try {
      // Truncate to first 500 chars for TTS (avoid long API calls)
      final truncated = text.length > 500 ? text.substring(0, 500) : text;

      final response = await _chatDio.post(
        '/text-to-speech',
        options: Options(
          headers: {'api-subscription-key': _sarvamApiKey},
          receiveTimeout: const Duration(seconds: 30),
        ),
        data: {
          'inputs': [truncated],
          'target_language_code': targetLang,
          'speaker': 'meera',  // Natural Hindi female voice
          'model': 'bulbul:v2',
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final audiosArr = response.data['audios'] as List?;
        if (audiosArr != null && audiosArr.isNotEmpty) {
          final base64Audio = audiosArr[0] as String;
          final audioBytes = base64Decode(base64Audio);

          // Save to temp file
          final dir = await Directory.systemTemp.createTemp('disha_tts_');
          final audioFile = File('${dir.path}/speech.wav');
          await audioFile.writeAsBytes(audioBytes);

          debugPrint('🔊 TTS audio saved: ${audioFile.path}');
          return audioFile.path;
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ TTS Error: $e');
      return null;
    }
  }
}

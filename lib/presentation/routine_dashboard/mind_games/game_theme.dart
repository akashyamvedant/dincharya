// lib/presentation/routine_dashboard/mind_games/game_theme.dart
// Dincharya Serene Earth Palette — context-aware, matches Routine tab.
// Both light and dark mode use Theme.of(context).colorScheme.

import 'package:flutter/material.dart';

/// Static game colors that are context-independent.
class GameColors {
  GameColors._();

  // Stroop test colors
  static const List<Color> stroop = [
    Color(0xFFFF0000), // Red
    Color(0xFF0000FF), // Blue
    Color(0xFF00AA00), // Green
    Color(0xFFFFAA00), // Yellow
    Color(0xFF8B00FF), // Purple
    Color(0xFFFF69B4), // Pink
  ];

  static const List<String> stroopNames = [
    'RED', 'BLUE', 'GREEN', 'YELLOW', 'PURPLE', 'PINK',
  ];

  // Chakra colors
  static const chakraRed = Color(0xFFE53935);
  static const chakraOrange = Color(0xFFFB8C00);
  static const chakraYellow = Color(0xFFFFD600);
  static const chakraGreen = Color(0xFF43A047);
  static const chakraBlue = Color(0xFF1E88E5);
  static const chakraIndigo = Color(0xFF5C6BC0);
  static const chakraViolet = Color(0xFF8E24AA);

  static const List<Color> chakras = [
    chakraRed, chakraOrange, chakraYellow,
    chakraGreen, chakraBlue, chakraIndigo, chakraViolet,
  ];

  // Simon Says (4 chakra-inspired)
  static const List<Color> simon = [
    chakraRed, chakraBlue, chakraGreen, chakraYellow,
  ];

  // Pure game-state colors
  static const gold = Color(0xFFFFD700);
  static const successGreen = Color(0xFF43A047);
  static const errorRed = Color(0xFFE57373);
  static const brainPurple = Color(0xFF7E57C2);
  static const earthPrimary = Color(0xFF8B4513);
}

/// Context-aware helpers that adapt to light/dark.
class GameTheme {
  GameTheme._();

  // ── Background ──
  static Color bg(BuildContext context) =>
      Theme.of(context).colorScheme.surface;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF261C10)
          : const Color(0xFFFFF8F0);

  // ── Text colors (context-aware) ──
  static Color textPrimary(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFD4A574)
          : const Color(0xFF6B4423);

  static Color textMuted(BuildContext context) =>
      textPrimary(context).withValues(alpha: 0.5);

  // ── Accent (gold in dark, warm amber in light) ──
  static Color accent(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? GameColors.gold
          : const Color(0xFFE65100);

  // ── Primary brand (matches routine header) ──
  static Color primary(BuildContext context) =>
      Theme.of(context).colorScheme.primary;

  static Color secondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFCD853F)
          : const Color(0xFFCD853F);

  // ── Card decoration ──
  static BoxDecoration card(BuildContext context) => BoxDecoration(
    color: Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF2A2015)
        : const Color(0xFFFEF8F0),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
    ),
    boxShadow: [
      BoxShadow(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        blurRadius: 12,
        offset: const Offset(0, 4),
      ),
    ],
  );

  // ── Game card (tappable tile) ──
  static BoxDecoration gameCard(BuildContext context, {bool selected = false}) =>
      BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: selected
          ? [primary(context).withValues(alpha: 0.2), secondary(context).withValues(alpha: 0.15)]
          : [surface(context).withValues(alpha: 0.5), surface(context).withValues(alpha: 0.3)],
    ),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(
      color: selected
          ? primary(context).withValues(alpha: 0.4)
          : primary(context).withValues(alpha: 0.12),
      width: selected ? 2 : 1,
    ),
    boxShadow: [
      BoxShadow(
        color: primary(context).withValues(alpha: 0.06),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // ── Hero card (daily challenge) ──
  static BoxDecoration heroCard(BuildContext context) => BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primary(context).withValues(alpha: 0.15),
        secondary(context).withValues(alpha: 0.1),
      ],
    ),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: primary(context).withValues(alpha: 0.35),
      width: 1.5,
    ),
    boxShadow: [
      BoxShadow(
        color: primary(context).withValues(alpha: 0.12),
        blurRadius: 16,
        offset: const Offset(0, 6),
      ),
    ],
  );

  // ── Text styles ──
  static TextStyle heading(BuildContext context, {double? size}) =>
      Theme.of(context).textTheme.headlineMedium?.copyWith(
        fontSize: size ?? 26,
        fontWeight: FontWeight.bold,
      ) ?? TextStyle(fontSize: size ?? 26, fontWeight: FontWeight.bold);

  static TextStyle subheading(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: textSecondary(context),
      ) ?? TextStyle(fontSize: 17, fontWeight: FontWeight.w600);

  static TextStyle body(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: textPrimary(context).withValues(alpha: 0.85),
      ) ?? TextStyle(fontSize: 15);

  static TextStyle score(BuildContext context) => TextStyle(
    fontSize: 48,
    fontWeight: FontWeight.bold,
    color: accent(context),
  );

  static TextStyle gameTitle(BuildContext context) => TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: textPrimary(context),
    letterSpacing: 0.3,
  );

  static TextStyle gameSubtitle(BuildContext context) => TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: textSecondary(context).withValues(alpha: 0.7),
  );

  // ═══ PREMIUM V2 HELPERS ═══

  /// Glassmorphism card — frosted glass with soft shadow
  static BoxDecoration glassCard(BuildContext context, {double alpha = 0.06}) =>
      BoxDecoration(
        color: primary(context).withValues(alpha: alpha),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      );

  /// Premium shadow for elevated elements
  static List<BoxShadow> premiumShadow(BuildContext context) => [
        BoxShadow(
          color: primary(context).withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];

  /// Gradient button decoration
  static BoxDecoration gradientButton(BuildContext context) => BoxDecoration(
        gradient: LinearGradient(
          colors: [primary(context), accent(context)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primary(context).withValues(alpha: 0.4),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      );

  /// Glow text shadow
  static List<Shadow> glowShadow(Color color, {double blur = 12.0}) =>
      [Shadow(color: color.withValues(alpha: 0.5), blurRadius: blur)];

  /// XP bar gradient
  static LinearGradient xpGradient() => const LinearGradient(
        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      );
}

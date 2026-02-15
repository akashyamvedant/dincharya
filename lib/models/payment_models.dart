// lib/models/payment_models.dart

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Country pricing tier classification
enum PricingTier {
  india,   // India — special home market pricing
  tier1,   // US, UK, Canada, Australia, EU (Western), Japan, etc.
  tier2,   // Brazil, Mexico, Turkey, Thailand, Malaysia, etc.
  tier3,   // Indonesia, Vietnam, Philippines, Egypt, Nigeria, etc.
}

/// Represents a localized price with currency
class LocalizedPrice {
  final double monthlyPrice;
  final double yearlyPrice;
  final double? lifetimePrice;
  final String currencyCode;
  final String currencySymbol;

  const LocalizedPrice({
    required this.monthlyPrice,
    required this.yearlyPrice,
    this.lifetimePrice,
    required this.currencyCode,
    required this.currencySymbol,
  });

  /// Monthly equivalent of yearly plan
  double get yearlyMonthlyEquivalent => (yearlyPrice / 12);

  /// Savings percentage for yearly vs monthly
  int get yearlySavingsPercent =>
      ((1 - (yearlyMonthlyEquivalent / monthlyPrice)) * 100).round();

  /// Formatted monthly price string
  String get formattedMonthly => '$currencySymbol${monthlyPrice.toInt()}';

  /// Formatted yearly price string
  String get formattedYearly => '$currencySymbol${yearlyPrice.toInt()}';

  /// Formatted lifetime price string
  String? get formattedLifetime =>
      lifetimePrice != null ? '$currencySymbol${lifetimePrice!.toInt()}' : null;
}

/// Geo-pricing configuration for all tiers
class GeoPricing {
  static const Map<PricingTier, LocalizedPrice> _tierPricing = {
    // India: Home market — most affordable
    PricingTier.india: LocalizedPrice(
      monthlyPrice: 199,
      yearlyPrice: 1999,
      lifetimePrice: 4999,
      currencyCode: 'INR',
      currencySymbol: '₹',
    ),
    // Tier 1: US, UK, Canada, Australia, Western EU, Japan
    PricingTier.tier1: LocalizedPrice(
      monthlyPrice: 10,   // $10/month
      yearlyPrice: 99,    // $99/year (~$8.25/mo)
      lifetimePrice: 199, // $199 lifetime
      currencyCode: 'USD',
      currencySymbol: '\$',
    ),
    // Tier 2: Brazil, Mexico, Turkey, Thailand, Malaysia, Eastern EU
    PricingTier.tier2: LocalizedPrice(
      monthlyPrice: 5,    // $5/month
      yearlyPrice: 49,    // $49/year (~$4.08/mo)
      lifetimePrice: 99,  // $99 lifetime
      currencyCode: 'USD',
      currencySymbol: '\$',
    ),
    // Tier 3: Indonesia, Vietnam, Philippines, Egypt, Nigeria
    PricingTier.tier3: LocalizedPrice(
      monthlyPrice: 3,    // $3/month
      yearlyPrice: 29,    // $29/year (~$2.42/mo)
      lifetimePrice: 59,  // $59 lifetime
      currencyCode: 'USD',
      currencySymbol: '\$',
    ),
  };

  /// Get localized pricing based on user's detected tier
  static LocalizedPrice getPricing(PricingTier tier) {
    return _tierPricing[tier] ?? _tierPricing[PricingTier.tier2]!;
  }

  /// Detect pricing tier using multiple signals (timezone + locale + system locales)
  /// This avoids the common bug where device language ≠ physical location
  static PricingTier detectTier() {
    try {
      // ── Signal 1: Timezone offset (strongest signal for India) ──
      // India Standard Time (IST) is UTC+5:30 — unique globally
      final tzOffset = DateTime.now().timeZoneOffset;
      if (tzOffset == const Duration(hours: 5, minutes: 30)) {
        debugPrint('🌍 Geo-tier: India (detected via timezone +5:30)');
        return PricingTier.india;
      }

      // ── Signal 2: Check all system locales from PlatformDispatcher ──
      // This checks ALL configured locales, not just the primary language
      try {
        final locales = WidgetsBinding.instance.platformDispatcher.locales;
        for (final locale in locales) {
          final cc = locale.countryCode?.toUpperCase() ?? '';
          if (cc.isNotEmpty) {
            final tier = _countryToTierOrNull(cc);
            if (tier != null) {
              debugPrint('🌍 Geo-tier: $tier (detected via system locale: $cc)');
              return tier;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ PlatformDispatcher locales unavailable: $e');
      }

      // ── Signal 3: Platform.localeName fallback ──
      final String locale = _getDeviceLocale();
      final String countryCode = locale.contains('_')
          ? locale.split('_').last.toUpperCase()
          : locale.toUpperCase();

      final tier = _countryToTier(countryCode);
      debugPrint('🌍 Geo-tier: $tier (detected via Platform.localeName: $locale → $countryCode)');
      return tier;
    } catch (e) {
      debugPrint('⚠️ Could not detect tier, defaulting to India: $e');
      // Default to India since this is an Indian app
      return PricingTier.india;
    }
  }

  /// Get the device locale string
  static String _getDeviceLocale() {
    try {
      if (kIsWeb) return 'en_US';
      return Platform.localeName;
    } catch (e) {
      return 'en_IN';
    }
  }

  /// Map country code to pricing tier (returns null if unknown)
  static PricingTier? _countryToTierOrNull(String countryCode) {
    if (_indiaCountries.contains(countryCode)) return PricingTier.india;
    if (_tier1Countries.contains(countryCode)) return PricingTier.tier1;
    if (_tier3Countries.contains(countryCode)) return PricingTier.tier3;
    // Don't return tier2 as default — let caller decide
    return null;
  }

  /// Map country code to pricing tier (never returns null)
  static PricingTier _countryToTier(String countryCode) {
    return _countryToTierOrNull(countryCode) ?? PricingTier.tier2;
  }

  static const Set<String> _indiaCountries = {'IN'};

  static const Set<String> _tier1Countries = {
    'US', 'GB', 'CA', 'AU', 'NZ',      // Anglo
    'DE', 'FR', 'NL', 'BE', 'AT',      // Western EU
    'CH', 'SE', 'NO', 'DK', 'FI',      // Nordic + Swiss
    'IE', 'LU', 'IS',                   // Other high-income EU
    'JP', 'KR', 'SG', 'HK', 'TW',      // Asia high-income
    'IL', 'AE', 'QA', 'KW', 'BH',      // Middle East high-income
  };

  static const Set<String> _tier3Countries = {
    'ID', 'VN', 'PH', 'MM', 'KH', 'LA', // SE Asia low
    'BD', 'NP', 'PK', 'LK', 'AF',       // South Asia
    'EG', 'NG', 'KE', 'GH', 'TZ',       // Africa
    'ET', 'UG', 'RW', 'SN', 'CM',       // Africa cont.
    'BO', 'PY', 'HN', 'NI', 'GT',       // LatAm low
  };
}

class PaymentPlan {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String duration;
  final List<String> features;
  final bool isPopular;

  const PaymentPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.duration,
    required this.features,
    this.isPopular = false,
  });

  /// Get localized plans based on user's geo-tier
  static List<PaymentPlan> getLocalizedPlans() {
    final tier = GeoPricing.detectTier();
    final pricing = GeoPricing.getPricing(tier);

    return [
      PaymentPlan(
        id: 'monthly_premium',
        name: 'Monthly Premium',
        price: pricing.monthlyPrice,
        currency: pricing.currencyCode,
        duration: 'month',
        features: _premiumFeatures,
      ),
      PaymentPlan(
        id: 'yearly_premium',
        name: 'Yearly Premium',
        price: pricing.yearlyPrice,
        currency: pricing.currencyCode,
        duration: 'year',
        features: [
          ..._premiumFeatures,
          'Save ${pricing.yearlySavingsPercent}% vs monthly',
        ],
        isPopular: true,
      ),
      if (pricing.lifetimePrice != null)
        PaymentPlan(
          id: 'lifetime_premium',
          name: 'Lifetime Access',
          price: pricing.lifetimePrice!,
          currency: pricing.currencyCode,
          duration: 'lifetime',
          features: [
            ..._premiumFeatures,
            'One-time payment — yours forever',
            'All future updates included',
          ],
        ),
    ];
  }

  /// Legacy accessor for backward compatibility
  static List<PaymentPlan> get availablePlans => getLocalizedPlans();

  /// Standard premium features
  static const List<String> _premiumFeatures = [
    'Ad-free experience',
    'Unlimited AI Guide conversations',
    'Premium guided sessions',
    'Advanced analytics & insights',
    'Offline content access',
    'Priority support',
  ];
}

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? errorMessage;
  final String? errorCode;

  const PaymentResult({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.errorMessage,
    this.errorCode,
  });

  factory PaymentResult.success({
    required String paymentId,
    required String orderId,
    required String signature,
  }) {
    return PaymentResult(
      success: true,
      paymentId: paymentId,
      orderId: orderId,
      signature: signature,
    );
  }

  factory PaymentResult.failure({
    required String errorMessage,
    String? errorCode,
  }) {
    return PaymentResult(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
    );
  }
}

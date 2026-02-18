# ═══════════════════════════════════════════════════════
# Google Mobile Ads / AdMob (CRITICAL for release mode!)
# Without these rules, R8 strips AdMob classes and ads
# silently fail to load in release builds
# ═══════════════════════════════════════════════════════
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-keep class com.google.android.gms.ads.identifier.** { *; }
-keep class com.google.android.gms.ads.mediation.** { *; }
-dontwarn com.google.android.gms.ads.**

# Google Mobile Ads Flutter Plugin
-keep class io.flutter.plugins.googlemobileads.** { *; }
-dontwarn io.flutter.plugins.googlemobileads.**

# Native Ad Factory (Dincharya custom layout)
-keep class com.akashyam.dincharya.DincharyaNativeAdFactory { *; }

# AdMob Mediation adapters (future-proofing)
-keep class com.google.ads.mediation.** { *; }
-dontwarn com.google.ads.mediation.**

# Facebook Audience Network (mediation partner)
-keep class com.facebook.ads.** { *; }
-dontwarn com.facebook.infer.annotation.**
-keep class com.facebook.infer.annotation.** { *; }

# ═══════════════════════════════════════════════════════
# General Android
# ═══════════════════════════════════════════════════════
-keepattributes InnerClasses
-keepattributes Signature
-keepattributes *Annotation*

# Firebase Auth
-keep class io.flutter.plugins.firebase.auth.** { *; }
-keep class io.flutter.plugins.firebase.core.** { *; }

# Google Sign-In (CRITICAL for release mode!)
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-dontwarn com.google.android.gms.**

# Supabase / GoTrue
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# Flutter dotenv - prevent stripping
-keep class dev.dincharya.** { *; }

# Facebook Audience Network
-keep class com.facebook.ads.** { *; }
-dontwarn com.facebook.infer.annotation.**
-keep class com.facebook.infer.annotation.** { *; }

# Razorpay
-keep class com.razorpay.** { *; }
-keep class com.razorpay.flutter.** { *; }

# General Android
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

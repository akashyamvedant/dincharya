# 🚀 DINCHARYA - COMPLETE DEPLOYMENT GUIDE
## Security Fixes & APK Build Instructions

---

## ⚠️ CRITICAL: FIRST STEPS (SECURITY)

### 1. Regenerate Exposed Credentials (IMMEDIATELY!)

Aapne credentials public chat mein share kar diye. **Sabse pehle yeh karo:**

#### Razorpay:
1. Login: https://dashboard.razorpay.com/
2. Settings → API Keys
3. Click "Regenerate Key Secret"
4. Save new key secret securely

#### Supabase:
1. Login: https://supabase.com/dashboard
2. Project Settings → API
3. Click "Rotate" on Service Role key
4. Save new service role key

---

## 📋 STEP-BY-STEP IMPLEMENTATION

### PHASE 1: Database Setup (15 minutes)

1. **Supabase SQL Editor mein jao:**
   - https://supabase.com/dashboard/project/djaevixaqvwtuizbadds/sql

2. **Run SQL Migration:**
   - File open karo: `SUPABASE_MIGRATION_V2.sql`
   - Copy entire content
   - Paste in SQL Editor
   - Click "RUN"
   - Verify tables created: subscriptions, admin_roles, routine_tracking, payment_audit_log

3. **Verify Tables:**
   ```sql
   SELECT table_name FROM information_schema.tables 
   WHERE table_schema = 'public';
   ```

---

### PHASE 2: Edge Functions Deployment (30 minutes)

#### Install Supabase CLI:
```powershell
# Windows PowerShell (Run as Administrator)
scoop install supabase
# OR
winget install Supabase.CLI
```

#### Login to Supabase:
```bash
supabase login
```

#### Link to Your Project:
```bash
cd c:\Users\akash\Desktop\flutter_projects\dincharya
supabase link --project-ref djaevixaqvwtuizbadds
```

#### Set Environment Variables (Edge Functions):
```bash
supabase secrets set RAZORPAY_KEY_SECRET=YOUR_NEW_KEY_SECRET
supabase secrets set SUPABASE_URL=https://djaevixaqvwtuizbadds.supabase.co
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=YOUR_NEW_SERVICE_ROLE_KEY
```

#### Deploy All Functions:
```bash
supabase functions deploy verify-payment
supabase functions deploy check-subscription
supabase functions deploy validate-admin
supabase functions deploy sync-tracking
```

#### Test Functions:
```bash
# Test subscription check
curl -X GET https://djaevixaqvwtuizbadds.supabase.co/functions/v1/check-subscription \
  -H "Authorization: Bearer YOUR_USER_JWT_TOKEN"
```

---

### PHASE 3: Flutter App Security Fixes

#### 1. Update Dependencies:
```bash
cd c:\Users\akash\Desktop\flutter_projects\dincharya
flutter pub get
```

#### 2. Create Secure .env File:
Create `.env` file in project root (already in .gitignore):
```env
SUPABASE_URL=https://djaevixaqvwtuizbadds.supabase.co
SUPABASE_ANON_KEY=YOUR_NEW_ANON_KEY
RAZORPAY_KEY_ID=YOUR_NEW_RAZORPAY_KEY_ID
```

#### 3. Critical Files to Update:

**File 1: lib/services/supabase_service.dart**
- Line 56-66: Remove hardcoded credentials
- Replace with:
```dart
import 'package:flutter_dotenv/flutter_dotenv.dart';

static String get supabaseUrl => dotenv.env['SUPABASE_URL']!;
static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY']!;
```

**File 2: lib/services/payment_service.dart**
- Replace client-side verification with server call
- Add backend API integration

**File 3: lib/presentation/authentication_screen/signup_screen.dart**
- Add strong password validation (lines 300-307)

**File 4: lib/main.dart**
- Add dotenv initialization:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  // ... rest of code
}
```

---

### PHASE 4: Code Fixes Implementation

Main ne already yeh files create kar di hain:
- ✅ `.env.example` (template)
- ✅ `env.json` (Flutter runtime config)
- ✅ `SUPABASE_MIGRATION_V2.sql` (database schema)
- ✅ `supabase/functions/*` (4 edge functions)
- ✅ Updated `.gitignore` (security)
- ✅ Updated `pubspec.yaml` (new packages)

**Aapko manually fix karne hain:**

#### Fix #1: Payment Service (CRITICAL)
File: `lib/services/payment_service.dart`

Replace `_verifyPaymentSignature()` function (lines 341-356):
```dart
Future<bool> _verifyPaymentSignature(PaymentSuccessResponse response, PaymentPlan plan) async {
  try {
    // Call backend edge function for verification
    final supabase = SupabaseService.client;
    final session = await supabase.auth.currentSession;
    
    if (session == null) {
      throw Exception('No active session');
    }

    final backendUrl = dotenv.env['BACKEND_API_URL']!;
    final verifyResponse = await dio.post(
      '$backendUrl/verify-payment',
      data: {
        'order_id': response.orderId,
        'payment_id': response.paymentId,
        'signature': response.signature,
        'amount': plan.price,
        'plan_id': plan.id,
        'plan_name': plan.name,
      },
      options: Options(
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Content-Type': 'application/json',
        },
      ),
    );

    return verifyResponse.data['success'] == true;
  } catch (e) {
    debugPrint('❌ Server verification failed: $e');
    return false;
  }
}
```

Replace `hasActivePremium()` function (lines 400-409):
```dart
Future<bool> hasActivePremium() async {
  try {
    final supabase = SupabaseService.client;
    final session = await supabase.auth.currentSession;
    
    if (session == null) return false;

    final backendUrl = dotenv.env['BACKEND_API_URL']!;
    final response = await dio.get(
      '$backendUrl/check-subscription',
      options: Options(
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      ),
    );

    return response.data['is_premium'] == true;
  } catch (e) {
    debugPrint('❌ Subscription check failed: $e');
    return false; // Fail securely
  }
}
```

#### Fix #2: Password Validation (HIGH PRIORITY)
File: `lib/presentation/authentication_screen/signup_screen.dart`

Replace password validation (lines 300-307):
```dart
validator: (value) {
  if (value == null || value.trim().isEmpty) {
    return 'Password is required';
  }
  if (value.length < 8) {
    return 'Password must be at least 8 characters';
  }
  // Strong password requirements
  final hasUppercase = value.contains(RegExp(r'[A-Z]'));
  final hasLowercase = value.contains(RegExp(r'[a-z]'));
  final hasDigit = value.contains(RegExp(r'[0-9]'));
  final hasSpecialChar = value.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
  
  if (!hasUppercase || !hasLowercase || !hasDigit || !hasSpecialChar) {
    return 'Password must contain uppercase, lowercase, number & special character';
  }
  return null;
},
```

#### Fix #3: Remove User Enumeration
File: `lib/presentation/authentication_screen/authentication_screen.dart`

Replace error handling (lines 104-105):
```dart
} catch (e) {
  setState(() {
    _isLoading = false;
    // Generic message - don't reveal if account exists
    _errorMessage = 'Invalid credentials. Please try again.';
  });
}
```

#### Fix #4: Admin Role Validation
File: `lib/services/supabase_service.dart`

Replace `updateAdminSettings()` (lines 464-490):
```dart
Future<bool> updateAdminSettings(Map<String, dynamic> settings) async {
  try {
    final session = await _client.auth.currentSession;
    if (session == null) {
      throw Exception('No active session');
    }

    final backendUrl = dotenv.env['BACKEND_API_URL']!;
    final dio = Dio();
    
    final response = await dio.post(
      '$backendUrl/validate-admin',
      data: {'settings': settings},
      options: Options(
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      ),
    );

    return response.data['success'] == true;
  } catch (e) {
    debugPrint('❌ Admin settings update failed: $e');
    return false;
  }
}
```

---

### PHASE 5: Build Production APK

#### 1. Update env.json with production values:
```json
{
  "SUPABASE_URL": "https://djaevixaqvwtuizbadds.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR_PRODUCTION_ANON_KEY",
  "BACKEND_API_URL": "https://djaevixaqvwtuizbadds.supabase.co/functions/v1",
  "RAZORPAY_KEY_ID": "rzp_live_YOUR_NEW_KEY_ID"
}
```

#### 2. Clean Build:
```bash
flutter clean
flutter pub get
```

#### 3. Build Release APK:
```bash
flutter build apk --release --dart-define-from-file=env.json
```

#### 4. Build App Bundle (for Play Store):
```bash
flutter build appbundle --release --dart-define-from-file=env.json
```

#### 5. Find APK:
```
build\app\outputs\flutter-apk\app-release.apk
```

#### 6. Find App Bundle:
```
build\app\outputs\bundle\release\app-release.aab
```

---

## ✅ VERIFICATION CHECKLIST

Before publishing to Play Store:

- [ ] Regenerated Razorpay credentials
- [ ] Regenerated Supabase service role key
- [ ] Ran SUPABASE_MIGRATION_V2.sql successfully
- [ ] Deployed all 4 edge functions
- [ ] Set edge function secrets
- [ ] Updated supabase_service.dart (removed hardcoded credentials)
- [ ] Updated payment_service.dart (server-side verification)
- [ ] Updated signup_screen.dart (strong password validation)
- [ ] Updated authentication_screen.dart (no user enumeration)
- [ ] Created .env file (gitignored)
- [ ] Updated env.json with production values
- [ ] Tested payment flow
- [ ] Tested subscription check
- [ ] Built release APK successfully
- [ ] Tested APK on real device
- [ ] google-services.json added to .gitignore

---

## 🔒 SECURITY BEST PRACTICES

### Never Commit:
- `.env`
- `env.json`
- `google-services.json`
- Any file with "key", "secret", or "password"

### Always Use:
- Environment variables for secrets
- Server-side verification for payments
- HTTPS for all API calls
- Strong password validation
- Rate limiting (implement in future)

---

## 🐛 TROUBLESHOOTING

### Issue: Edge functions not deploying
```bash
supabase functions delete verify-payment
supabase functions deploy verify-payment
```

### Issue: APK build fails
```bash
flutter clean
flutter pub get
flutter doctor -v
```

### Issue: Payment verification fails
- Check edge function logs: https://supabase.com/dashboard/project/djaevixaqvwtuizbadds/logs
- Verify secrets are set: `supabase secrets list`
- Test function manually with curl

### Issue: Subscription check returns false
- Verify database has subscriptions table
- Check RLS policies
- Verify user is authenticated
- Check edge function logs

---

## 📞 SUPPORT

Agar koi problem aaye:
1. Edge function logs check karo
2. Flutter logs dekho: `flutter run --verbose`
3. Database data verify karo Supabase dashboard mein

---

**BUILD DATE**: 2025-12-25  
**VERSION**: 2.0 (Security Fixed)


# DinCharya - Daily Routine & Wellness App

A production-ready Flutter application for managing daily routines, journaling, mood tracking, and personal wellness. Built with Supabase backend for real-time data synchronization.

## 🚀 Features

- **User Authentication**: Secure sign up/login with email and Google Sign-In
- **Routine Management**: Create and track daily tasks and routines
- **Journal & Mood Tracking**: Daily journal entries with mood ratings
- **Profile Management**: Complete user profile with bio and profile picture
- **Online-First**: Real-time data sync with Supabase backend
- **Modern UI**: Clean, responsive design with Material Design

## 📋 Prerequisites

- Flutter SDK (^3.29.2)
- Dart SDK
- Android Studio / VS Code with Flutter extensions
- Android SDK / Xcode (for iOS development)

## 🛠️ Installation

1. Install dependencies:
```bash
flutter pub get
```

2. Run the application:

To run the app with environment variables defined in an env.json file, follow the steps mentioned below:
1. Through CLI
    ```bash
    flutter run --dart-define-from-file=env.json
    ```
2. For VSCode
    - Open .vscode/launch.json (create it if it doesn't exist).
    - Add or modify your launch configuration to include --dart-define-from-file:
    ```json
    {
        "version": "0.2.0",
        "configurations": [
            {
                "name": "Launch",
                "request": "launch",
                "type": "dart",
                "program": "lib/main.dart",
                "args": [
                    "--dart-define-from-file",
                    "env.json"
                ]
            }
        ]
    }
    ```
3. For IntelliJ / Android Studio
    - Go to Run > Edit Configurations.
    - Select your Flutter configuration or create a new one.
    - Add the following to the "Additional arguments" field:
    ```bash
    --dart-define-from-file=env.json
    ```

## 📁 Project Structure

```
flutter_app/
├── android/            # Android-specific configuration
├── ios/                # iOS-specific configuration
├── lib/
│   ├── core/           # Core utilities and services
│   │   └── utils/      # Utility classes
│   ├── presentation/   # UI screens and widgets
│   │   └── splash_screen/ # Splash screen implementation
│   ├── routes/         # Application routing
│   ├── theme/          # Theme configuration
│   ├── widgets/        # Reusable UI components
│   └── main.dart       # Application entry point
├── assets/             # Static assets (images, fonts, etc.)
├── pubspec.yaml        # Project dependencies and configuration
└── README.md           # Project documentation
```

## 🧩 Adding Routes

To add new routes to the application, update the `lib/routes/app_routes.dart` file:

```dart
import 'package:flutter/material.dart';
import 'package:package_name/presentation/home_screen/home_screen.dart';

class AppRoutes {
  static const String initial = '/';
  static const String home = '/home';

  static Map<String, WidgetBuilder> routes = {
    initial: (context) => const SplashScreen(),
    home: (context) => const HomeScreen(),
    // Add more routes as needed
  }
}
```

## 🎨 Theming

This project includes a comprehensive theming system with both light and dark themes:

```dart
// Access the current theme
ThemeData theme = Theme.of(context);

// Use theme colors
Color primaryColor = theme.colorScheme.primary;
```

The theme configuration includes:
- Color schemes for light and dark modes
- Typography styles
- Button themes
- Input decoration themes
- Card and dialog themes

## 📱 Responsive Design

The app is built with responsive design using the Sizer package:

```dart
// Example of responsive sizing
Container(
  width: 50.w, // 50% of screen width
  height: 20.h, // 20% of screen height
  child: Text('Responsive Container'),
)
```
## 🔧 Backend Setup

This app requires Supabase backend configuration:

1. **Database Setup**: Run `SUPABASE_SETUP.sql` in your Supabase SQL Editor
2. **Storage Bucket**: Create `profile_images` bucket in Supabase Storage
3. **Environment Variables**: Configure Supabase URL and API keys

See `SUPABASE_SETUP.sql` for complete database schema and policies.

## 📦 Production Build

Build the application for production:

```bash
# For Android APK
flutter build apk --release

# For Android App Bundle (Play Store)
flutter build appbundle --release

# For iOS
flutter build ios --release
```

## 🔐 Environment Configuration

For production, use environment variables:

```bash
flutter run --dart-define=SUPABASE_URL=your-url --dart-define=SUPABASE_ANON_KEY=your-key
```

Or use `env.json` file (not committed to git):
```json
{
  "SUPABASE_URL": "your-supabase-url",
  "SUPABASE_ANON_KEY": "your-anon-key"
}
```

## 🛠️ Tech Stack

- **Framework**: Flutter 3.6.0+
- **Backend**: Supabase (PostgreSQL, Auth, Storage)
- **State Management**: Provider pattern
- **UI**: Material Design 3
- **Image Handling**: Cached Network Images
- **Notifications**: Flutter Local Notifications
- **Payments**: Razorpay Integration
- **Ads**: Google Mobile Ads

## 📄 License

This project is proprietary software.

## 🙏 Acknowledgments

- Built with Flutter & Dart
- Backend powered by Supabase
- UI styled with Material Design

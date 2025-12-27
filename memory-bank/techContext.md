# Technical Context

## Technologies Used

### Frontend
- **Flutter (Dart):** Cross-platform UI framework.
- **State Management:** `Provider` (based on `pubspec.yaml` dependencies, this is the likely choice).
- **Navigation:** `go_router` (or similar, based on `app_routes.dart`).

### Backend
- **Supabase:**
    - PostgreSQL Database
    - Supabase Auth
    - Supabase Storage
    - Supabase Edge Functions (for custom backend logic)

### External Services
- **Ad Service:** (e.g., Google AdMob, specific details to be confirmed)
- **Payment Gateway:** (e.g., Stripe, Razorpay, specific details to be confirmed)
- **Notification Service:** (e.g., Firebase Cloud Messaging, specific details to be confirmed)

## Development Setup

### Prerequisites
- Flutter SDK installed and configured.
- Dart SDK (comes with Flutter).
- VS Code with Flutter and Dart extensions.
- Git for version control.
- Node.js and npm/yarn (for Supabase CLI, if used for local development/migrations).

### Local Development
- **Running the App:** `flutter run`
- **Supabase Local Setup:** Requires Supabase CLI for local database development and migrations.
- **Environment Variables:** `env.example.json` suggests environment variables are managed via a local JSON file.

## Dependencies (from `pubspec.yaml` analysis)
- `flutter`
- `cupertino_icons`
- `supabase_flutter`
- `provider` (inferred from common Flutter patterns and project structure)
- `flutter_svg` (for SVG image assets)
- `intl` (for internationalization/localization)
- `shared_preferences` (for local data storage)
- `path_provider` (for accessing file system paths)
- `image_picker` (for image selection, e.g., profile pictures)
- `url_launcher` (for opening URLs)
- `package_info_plus` (for app info)
- `connectivity_plus` (for network connectivity checks)
- `permission_handler` (for managing permissions)
- `flutter_local_notifications` (for local notifications)
- `firebase_core`, `firebase_auth`, `firebase_messaging` (if Firebase is used alongside Supabase for specific features like FCM)

## Tool Usage Patterns
- **VS Code:** Primary IDE for development.
- **Flutter CLI:** For building, running, and managing Flutter projects.
- **Supabase CLI:** For managing Supabase projects (migrations, local development).
- **Git:** For source code management.

## Technical Constraints
- **Mobile-first Design:** While cross-platform, the primary focus is on mobile experience.
- **Supabase Limitations:** Awareness of Supabase's specific features and limitations for backend operations.
- **Offline Data Sync:** Requires careful handling of data consistency between local storage and Supabase.

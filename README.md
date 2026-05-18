# مزرعتي — Farm Manager App

An offline-first Android farm management app built with Flutter.

## Tech Stack
- Flutter (Dart) — Android 8+ (API 26+)
- Drift (SQLite) — local offline database
- Firebase Auth / Firestore / Storage — cloud sync
- Riverpod — state management
- go_router — navigation

## Project Setup

### 1. Install Flutter
Download and install Flutter SDK from https://flutter.dev/docs/get-started/install  
Add Flutter to your PATH, then run: `flutter doctor`

### 2. Install dependencies
```bash
flutter pub get
```

### 3. Generate code (Drift + Riverpod)
```bash
dart run build_runner build --delete-conflicting-outputs
```
This generates `*.g.dart` files needed by Drift. Run this once before building,
and again whenever you change database table definitions.

### 4. Add Firebase
See `FIREBASE_SETUP.md` for step-by-step instructions.
You must place `google-services.json` at `android/app/google-services.json`.

### 5. Build the APK
```bash
# Debug (for testing)
flutter build apk --debug

# Release (for distribution)
flutter build apk --release
```

See `INSTALL.md` for how to install the APK on the phone.

## Architecture

```
lib/
├── main.dart              # App entry point, Firebase init, Workmanager
├── app.dart               # GoRouter config, MaterialApp
├── theme/                 # AppTheme, colors
├── models/                # Pure Dart models (Animal, Expense, HistoryEntry)
├── database/              # Drift tables + AppDatabase
├── repositories/          # Data access (local DB)
├── services/              # Firebase, Storage, Sync, Photo
├── providers/             # Riverpod providers
├── screens/               # UI screens
└── widgets/               # Reusable widgets
```

**Write path:** UI → Provider → Repository → Drift (syncStatus=pending)  
**Sync path:** SyncService reads pending records → uploads to Firestore → marks synced  
**Restore path:** Login → detect empty DB → fetch all Firestore docs → insert into Drift

## Development Commands

```bash
# Watch + rebuild on change
dart run build_runner watch --delete-conflicting-outputs

# Analyze code
flutter analyze

# Run on connected Android device
flutter run
```

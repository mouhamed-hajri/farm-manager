# APK Build & Installation Guide

## Prerequisites
- Flutter SDK installed (see README.md)
- Android phone with USB debugging enabled (for testing)
- `google-services.json` placed at `android/app/google-services.json`

## Build Steps

### 1. Generate code
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 2. Build release APK
```bash
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`

For debug APK (no signing needed, easier to test):
```bash
flutter build apk --debug
```

## Install on Phone

### Option A: USB Cable
1. Connect phone to computer via USB
2. On phone: enable Developer Options → USB Debugging
3. Run: `flutter install` (uses connected device)
   Or manually copy APK and open it on the phone.

### Option B: WhatsApp / Email
1. Send the APK file to yourself via WhatsApp or email
2. On the phone, open the file
3. Android will prompt "Install from unknown sources"
4. Go to Settings → Security → Install unknown apps → Allow for your browser/files app
5. Return and install

## First Launch After Install
1. Open the app
2. Login with your Firebase email + password
3. If this is a fresh install (no data): tap Backup → "Restore from Cloud"
4. All your data will be downloaded from Firebase

## Signing (for permanent use)

To sign the release APK so Android trusts it permanently:

```bash
# Generate keystore (do this once)
keytool -genkey -v -keystore farm-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias farm-key

# Create android/key.properties
storePassword=<your_keystore_password>
keyPassword=<your_key_password>
keyAlias=farm-key
storeFile=../farm-release-key.jks
```

Then add signing config to `android/app/build.gradle` (see Flutter docs).

⚠️ Keep `farm-release-key.jks` and `key.properties` safe — you need them for every future update.

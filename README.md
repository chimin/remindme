# Remind Me

A Flutter task management app that syncs with Google Tasks. Users sign in with their Google account and tasks are read/written to their Google Tasks via the Google Tasks API.

## Prerequisites

1. [Flutter](https://docs.flutter.dev/get-started/install) installed (this project uses Flutter 3.41.4, Dart ^3.11.1)
2. A [Google Cloud Console](https://console.cloud.google.com/) project
3. Android Studio/Xcode for device/simulator testing

## Google Cloud Console Setup

### 1. Enable APIs
- Go to [Google Cloud Console](https://console.cloud.google.com/) → API Library
- Enable **Google Tasks API**
- (Google Identity Services is used by `google_sign_in`; no separate API to enable)

### 2. Configure OAuth Consent Screen
- Go to **APIs & Services → OAuth consent screen**
- Choose User Type (External for testing)
- Fill in app name, user support email, developer contact
- Add the scope: `https://www.googleapis.com/auth/tasks` (Manage your tasks)
- Add test users (email addresses) if using External testing mode

### 3. Create OAuth Client IDs

#### Web application client (required for Android)
- Go to **APIs & Services → Credentials → Create Credentials → OAuth 2.0 Client ID**
- Application type: **Web application**
- Name: `remindme-web`
- Authorized JavaScript origins: leave as needed (or `http://localhost` not required for mobile)
- Copy the **Client ID** - you'll use this as `GOOGLE_WEB_CLIENT_ID`

#### Android client
- Application type: **Android**
- Package name: `chimin.remindme`
- SHA-1 certificate fingerprint:
  ```bash
  keytool -list -v -alias androiddebugkey -keystore ./secrets/debug.keystore -storepass android -keypass android
  ```
- Register debug and release SHA-1 if needed

#### iOS client
- Application type: **iOS**
- Bundle ID: `chimin.remindme`
- Copy the **iOS client ID** and **reversed client ID**

## Project Configuration

### Android
The `INTERNET` permission is already added in `android/app/src/main/AndroidManifest.xml`.

### iOS
Update `ios/Runner/Info.plist` with your values:
- Replace `YOUR_IOS_CLIENT_ID.apps.googleusercontent.com` with your actual iOS client ID
- Replace `YOUR_REVERSED_CLIENT_ID` with your reversed client ID (from GCP)

```xml
<key>GIDClientID</key>
<string>YOUR_IOS_CLIENT_ID.apps.googleusercontent.com</string>
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>YOUR_REVERSED_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

## Running the App

### Get dependencies
```bash
flutter pub get
```

### Run on Android
Create `secrets/debug.json` with your web client ID:
```json
{
  "GOOGLE_WEB_CLIENT_ID": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
}
```
Then run:
```bash
flutter run -d <device> --dart-define-from-file=secrets/debug.json
```
Same for IntelliJ - add `--dart-define-from-file=secrets/debug.json` to your run configuration.

### Run on iOS
```bash
flutter run -d <device> --dart-define-from-file=secrets/debug.json
```

## Development

- Analyze code: `flutter analyze`
- Run tests: `flutter test --dart-define=GOOGLE_WEB_CLIENT_ID=test123`

## Notes
- The app defaults to the task list named "Tasks" if present, otherwise creates it automatically
- Google Sign-In uses the web client ID from `secrets/debug.json` via `--dart-define-from-file` (or falls back to `GOOGLE_WEB_CLIENT_ID` env var)
- For production distribution, you may need to complete Google OAuth app verification for the sensitive `auth/tasks` scope

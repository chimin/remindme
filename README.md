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
-   SHA-1 certificate fingerprint:
  ```bash
  keytool -list -v -alias androiddebugkey -keystore ./secrets/build.keystore -storepass android -keypass android
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
Create `secrets/build.json` with your web client ID:
```json
{
  "GOOGLE_WEB_CLIENT_ID": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
}
```
Then run:
```bash
flutter run -d <device> --dart-define-from-file=secrets/build.json
```
Same for IntelliJ - add `--dart-define-from-file=secrets/build.json` to your run configuration.

### Run on iOS
```bash
flutter run -d <device> --dart-define-from-file=secrets/build.json
```

## Development

- Analyze code: `flutter analyze`
- Run tests: `flutter test --dart-define=GOOGLE_WEB_CLIENT_ID=test123`

## Branding assets

Run from PowerShell in the project root:

```powershell
.\android\gradlew.bat -p android updateBranding
```

This replaces the Android launcher icons, iOS app icons, and Play Store images
with opaque PNGs at their required sizes. It uses the existing 1024px iOS icon
as the icon source and `assets/branding/play-store-feature-graphic.png` as the banner
source. iOS sizes come from its `Contents.json` catalog. Normal builds use the
checked-in images and do not regenerate them.

To preview the exports without changing production assets:

```powershell
.\android\gradlew.bat -p android updateBranding '-PbrandingOutputDir=../build/branding-preview'
```

Use `-PbrandingIconSource=...` and `-PbrandingFeatureSource=...` to supply new
artwork. All three path options are resolved relative to the `android` directory;
absolute paths also work. The task uses JVM image processing and needs no
PowerShell-specific image libraries.

## Android screenshots

Run from PowerShell:

```powershell
Set-Location android
.\gradlew.bat screenshotTests
```

This builds a debug APK with the separate `lib/main_screenshot.dart` entry
point and runs `MainActivityScreenshotTest` on an emulator only. No Google
sign-in is needed and no account data is changed. Rebuild the normal app
afterwards to restore the usual sign-in flow.

The fixture has exactly four incomplete tasks: yesterday, today, two days
ahead, and five days ahead, relative to the emulator's local date.

The task captures the real task listing, add-task screen (keyboard hidden),
and launcher with the real app widget. Files are pulled into
`android/app/test/screenshots/`:
`task_listing.png`, `add_task.png`, and `home_screen_widget.png`.

Use an English, unlocked emulator with a launcher supporting widget pinning.
Keep the widget on the current home page. The default AVD is `RemindMe_Test`;
override with `-Pavd=YourAvd`. Use `-PskipBootWait=true` if already booted.

## Notes
- The app defaults to the task list named "Tasks" if present, otherwise creates it automatically
- Google Sign-In uses the web client ID from `secrets/build.json` via `--dart-define-from-file` (or falls back to `GOOGLE_WEB_CLIENT_ID` env var)
- For production distribution, you may need to complete Google OAuth app verification for the sensitive `auth/tasks` scope

## GitHub Actions (CI/CD)

The workflow `.github/workflows/build.yml` supports manual APK/AAB builds and automatically builds a signed AAB and publishes it to the Google Play internal testing track when a tag matching `vMAJOR.MINOR.PATCH` is pushed (for example, `v1.2.3`). Manual builds only upload workflow artifacts.

### Required GitHub Secrets

Add these secrets in your repo: **Settings → Secrets and variables → Actions**.

| Secret | Description | How to generate |
| --- | --- | --- |
| `GOOGLE_WEB_CLIENT_ID` | Web OAuth client ID from Google Cloud Console (same as used in `secrets/build.json`) | From GCP: APIs & Services → Credentials → OAuth 2.0 Client IDs → Web application client |
| `BUILD_KEYSTORE_BASE64` | Base64-encoded keystore file for signing (must be a release keystore for Play Store) | `base64 -w 0 release.keystore` |
| `KEYSTORE_PASSWORD` | Keystore password | From your release keystore |
| `KEY_ALIAS` | Key alias | From your release keystore |
| `KEY_PASSWORD` | Key password | From your release keystore |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Raw service account JSON key used for tag releases | Enable the Google Play Android Developer API in its Cloud project, create a service account key, and grant the account access to `chimin.remindme` with permission to release to testing tracks in Play Console |

### Usage

1. Go to **Actions → Build → Run workflow**
2. Enter `app_version` (e.g. `1.0.0+1`)
3. Choose whether to build APK (default true) and/or AAB (default false)
4. Wait for the build to complete and download artifacts (`remindme-apk-<version>` or `remindme-aab-<version>`) from the workflow artifacts

### Publish a tag release

Complete the Play Console app setup and upload the first release manually before using the API. The signing keystore must match the upload key registered for the app. See the [upload action prerequisites](https://github.com/r0adkll/upload-google-play#readme).

Push a version tag to build and submit an internal testing release automatically:

```powershell
git tag v1.2.3
git push origin v1.2.3
```

The tag sets Android `versionName` to `1.2.3` and `versionCode` to `1002003`, using `major * 1000000 + minor * 1000 + patch`. Minor and patch must each be at most 999, and the resulting code must be between 1 and 2100000000. Use increasing versions whose codes exceed all previous uploads to Play, including manual uploads. Prerelease suffixes and leading zeroes are rejected. The repository's `pubspec.yaml` is updated only in the runner checkout.

The AAB is also retained as a workflow artifact. Google Play review and account publishing settings determine when the submitted release becomes available to users. Manual workflow runs never publish to Play.

Release notes are generated automatically from commit subjects between the highest earlier version tag reachable from the current commit and the current tag. The first version includes all commit history. Notes are uploaded in English (en-US), oldest commit first, and truncated to Google Play's 500-character limit. If there are no new commits, the notes say so.

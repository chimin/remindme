# Remind Me

A Flutter task manager that syncs with Google Tasks.

Run commands in PowerShell from the repository root unless stated otherwise.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) 3.41.4 (Dart ^3.11.1).
- Android Studio for Android development, or Xcode on macOS for iOS.
- A [Google Cloud Console](https://console.cloud.google.com/) project.

## Set up Google sign-in

1. In Google Cloud Console, enable **Google Tasks API**.
2. Configure the OAuth consent screen with the app name, support email, and developer contact. Add the scope `https://www.googleapis.com/auth/tasks` and your test accounts for External testing.
3. Under **APIs & Services → Credentials**, create these OAuth clients:

| Client type | Configuration |
| --- | --- |
| Web application | Name: `remindme-web`. Save its client ID as `GOOGLE_WEB_CLIENT_ID`. |
| Android | Package: `chimin.remindme`. Register the SHA-1 of each signing certificate you use. |
| iOS | Bundle ID: `chimin.remindme`. Save the client ID and reversed client ID. |

Use your signing keystore at `secrets/build.keystore`. To read its SHA-1 with the development credentials:

```powershell
keytool -list -v -alias androiddebugkey -keystore ./secrets/build.keystore -storepass android -keypass android
```

Substitute your alias and passwords when using a different key. Android builds use `KEYSTORE_PASSWORD`, `KEY_ALIAS`, and `KEY_PASSWORD` environment variables, defaulting to the development values above.

Create `secrets/build.json`:

```json
{
  "GOOGLE_WEB_CLIENT_ID": "YOUR_WEB_CLIENT_ID.apps.googleusercontent.com"
}
```

For iOS, copy `ios/Flutter/Google.example.xcconfig` to `ios/Flutter/Google.xcconfig` and set `GOOGLE_IOS_CLIENT_ID` and `GOOGLE_IOS_REVERSED_CLIENT_ID`.

Do not commit credentials. Complete Google OAuth verification if required for production use of the Tasks scope.

## Run the app

```powershell
flutter pub get
flutter devices
flutter run -d <device-id> --dart-define-from-file=secrets/build.json
```

For IntelliJ, add `--dart-define-from-file=secrets/build.json` to the Flutter run configuration.

## Analyze and test

```powershell
dart run build_runner build
flutter analyze
flutter test --dart-define=GOOGLE_WEB_CLIENT_ID=test123
```

### Cucumber feature tests

Eighteen maintained features cover screens, widgets, models, services, and task grouping. Nine screen and widget features cover login, reminder settings, task editing, task home, widget appearance, color picking, task deletion confirmation, checked menu items, and widget task navigation. Nine unit features preserve 95 cases for task metadata, Android and Flutter Google account providers, authentication, authorized HTTP requests, reminders, sync, task storage and recurrence, and task grouping. The login feature also includes the fresh-install smoke scenario. All feature files live directly in `features/`; each feature's steps and typed scenario context live directly in `features/steps/<feature_basename>/`. Shared runner support lives in `features/steps/scenario_runner.dart`.

Edit the feature and its category steps, then generate and run the ordinary suite. This PowerShell command runs tests only if generation succeeds:

```powershell
dart run build_runner build; if ($LASTEXITCODE -eq 0) { flutter test --dart-define=GOOGLE_WEB_CLIENT_ID=test123 }
```

Ordinary feature runners are generated as `test/features/<feature_basename>_test.dart`. The entire `test/features/` directory is ignored by Git; maintained steps, helpers, screenshot references, and `_FAILED` images remain tracked. Regenerate after cloning or changing a feature, and do not edit generated tests.

To run one generated suite:

```powershell
flutter test test/features/login_screen_test.dart --dart-define=GOOGLE_WEB_CLIENT_ID=test123
```

In IntelliJ, generate first, then run `main()` in the desired generated test file. Set **Additional run args** to `--dart-define=GOOGLE_WEB_CLIENT_ID=test123` and the working directory to the repository root. Rerun generation after feature edits before using an IDE test action.

UI scenarios use `widgetScenario`; model, service, task grouping, and color parsing and formatting scenarios use `unitScenario`. Scenario names follow `{action} should {do what} when {what happen}`. Scenario continuations retain typed local values across Given/When/Then steps, and the Background initializes isolated state and failure cleanup. Font setup and platform mocks stay with their category.

Screenshot paths, references, thresholds, and failed-image behavior remain unchanged. The fresh-install screenshot compares `features/screenshots/login_screen/login_screen_when_newly_installed.png` without replacing it.

## Patrol E2E test (Android, manual only)

Run only when E2E execution is explicitly requested. The test signs in, grants Tasks permission, creates, edits, and deletes a test task, then signs out. It checks changes against Google Tasks and preserves existing account tasks.

### Prepare before every run

1. Start an online, unlocked, English Android 10+ emulator with current Google Play services. Physical devices are not supported.
2. Add a dedicated Google test account to Android. Configure its OAuth access and the files in `secrets/` as described above. Password entry and MFA are not supported.
3. Open [Google Account connections](https://myaccount.google.com/connections) using that account. Select **Remind Me**, choose **Delete all connections** or **Remove access**, and confirm. Repeat before every rerun; fresh Tasks consent is mandatory.
4. Remove any `RemindMe Patrol <run ID>` task left by an interrupted run.

**The launcher erases all local Remind Me app data on the selected emulator.** Sync pending changes first. The Google account and other apps are retained.

### Run the Patrol test

```powershell
flutter pub get
adb devices
dart run tool/run_patrol.dart --device <device-id> --account <test-email> --dart-define-from-file secrets/build.json
```

The launcher generates runners, builds and installs the APKs, and collects screenshots, video, and logs. No separate code generation or global Patrol installation is needed.

Append these options as needed:

| Option | Use |
| --- | --- |
| `--allow-unverified-app` | Handle **Advanced → Go to Remind Me (unsafe)** for an unverified development OAuth project. |
| `--no-video` | Skip recording and encoder checks; still collect screenshots and logs. |
| `--update-goldens` | Create or replace captured golden references for review instead of asserting a visual match. |
| `--help` | Show options without building or running tests. |

Edit `features/e2e.feature` and steps in `features/steps/app_journey/`. Shared Patrol helpers remain in `patrol_test/support/`. The launcher generates `patrol_test/e2e_test.dart`; do not commit generated Patrol runners. Add a blank line before a `When` clause that follows a `Then` clause.

### Review results and troubleshoot

| Output | Location |
| --- | --- |
| Golden references | `features/screenshots/e2e/<2_digits_sequence>_<description>.png` |
| Current captures | `patrol_test/golden/screenshots/` |
| Failed comparisons | `features/screenshots/e2e/*_FAILED.png` |
| Comparison report | `patrol_test/golden/screenshot_comparison.json` |
| Video | `patrol_test/golden/test.mp4` |
| Logs | `patrol_test/golden/device.log`, `instrumentation.txt`, and `recording.txt` |

Keep the reference device's display settings. Normal runs fail for more than 5% differing app pixels, missing references, or changed dimensions; they never replace goldens. Review and commit references after using `--update-goldens`.

Previous run captures, failures, video, and logs are cleared. Copy any evidence you need before rerunning; it may contain account emails and task data.

- **Missing Tasks consent:** revoke Remind Me access again before retrying.
- **Sign-in failure:** check the account email, language, connectivity, and OAuth configuration. For `Unsupported API`, update Google Play services or use a current Google Play emulator image.
- **Recording failure:** use an emulator supporting `screenrecord --time-limit 0`, or add `--no-video`.
- **Interrupted run:** inspect the logs and remove only the test task identified by its run ID before retrying.

Failures return a nonzero exit code. After testing, rebuild/install the normal app with the command in “Run the app.”

## Android screenshots

Use an unlocked English emulator with a launcher supporting widget pinning. Keep the widget on the current home page.

```powershell
.\android\gradlew.bat -p android screenshotTests
```

The default AVD is `RemindMe_Test`. Append `-Pavd=YourAvd` to change it or `-PskipBootWait=true` if already booted.

The task captures the task list, add-task screen, and home-screen widget using fixture data without Google sign-in. Files are saved to `android/screenshots/<page/component>/`. Rebuild/install the normal app afterwards.

Use `<page/component>_when_<what_happen>.png` for Flutter and Android screenshots. Store Flutter images under `features/screenshots/<page/component>/`.

Failed Flutter and Patrol comparisons save the actual image beside its reference as `<reference_name>_FAILED.png`. Include these images in Git for review. Passing comparisons and golden updates remove stale failure images.

## Update branding assets

Regenerate Android/iOS icons and Play Store images:

```powershell
.\android\gradlew.bat -p android updateBranding
```

The default sources are the existing 1024px iOS icon and `assets/branding/play-store-feature-graphic.png`. To preview without replacing production assets:

```powershell
.\android\gradlew.bat -p android updateBranding '-PbrandingOutputDir=../build/branding-preview'
```

Use `-PbrandingIconSource=...` and `-PbrandingFeatureSource=...` for different artwork. Paths are relative to `android/`, or use absolute paths.

## GitHub Actions (CI/CD)

The Build workflow in `.github/workflows/build.yml` creates manual APK/AAB artifacts and publishes tagged versions to Google Play internal testing.

### Configure secrets

Add these under **Settings → Secrets and variables → Actions**:

| Secret | Value |
| --- | --- |
| `GOOGLE_WEB_CLIENT_ID` | Web OAuth client ID from `secrets/build.json`. |
| `BUILD_KEYSTORE_BASE64` | Base64-encoded release signing keystore. |
| `KEYSTORE_PASSWORD` | Keystore password. |
| `KEY_ALIAS` | Signing key alias. |
| `KEY_PASSWORD` | Signing key password. |
| `GOOGLE_PLAY_SERVICE_ACCOUNT_JSON` | Service-account JSON key with permission to release `chimin.remindme` to testing tracks. Enable the Google Play Android Developer API for its project. Required for tag releases. |

Encode the keystore in PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\to\release.keystore'))
```

### Build APK/AAB artifacts

1. Open **Actions → Build → Run workflow**.
2. Enter `app_version`, such as `1.0.0+1`.
3. Select APK (default on) and/or AAB (default off).
4. Download `remindme-apk-<version>` or `remindme-aab-<version>` from the completed run's artifacts. Manual runs do not publish to Play.

### Publish a tag release

Complete Play Console setup, upload the first release manually, and use the registered upload key. See the [upload action prerequisites](https://github.com/r0adkll/upload-google-play#readme).

Push an increasing `vMAJOR.MINOR.PATCH` tag:

```powershell
git tag v1.2.3
git push origin v1.2.3
```

The workflow builds a signed AAB, submits it to Google Play internal testing, and saves it as a workflow artifact. Release notes come from commits. Check the workflow result and Play Console for release status.

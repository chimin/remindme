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

## Gherkin smoke test

One Gherkin scenario checks that opening the app with simulated fresh-install
state shows the **Continue with Google** login button. It runs as a Flutter
widget test with isolated storage/authentication fakes; no device or Google
account is needed.

After resolving dependencies with `flutter pub get`, generate the test whenever
the feature changes:

```powershell
dart run build_runner build
```

Run only this scenario:

```powershell
flutter test test/screens/login_screen_gherkin_test.dart --dart-define=GOOGLE_WEB_CLIENT_ID=test123
```

### Run from IntelliJ IDEA

1. Open the project root in IntelliJ IDEA with the Flutter and Dart plugins
   enabled and the Flutter SDK configured.
2. In the IDE terminal, run `flutter pub get`, then
   `dart run build_runner build` after changing the feature file.
3. Open `test/screens/login_screen_gherkin_test.dart`. Click the gutter Run
   icon beside `main()` to create a Flutter Test run configuration.
4. Open **Run > Edit Configurations**, select that Flutter Test configuration,
   and set **Additional run args** to
   `--dart-define=GOOGLE_WEB_CLIENT_ID=test123`. Set its working directory to
   the project root so fonts and screenshots resolve correctly. Click **Apply**.
5. Run or debug that configuration. The Run tool window should show one passing
   test. Open `screenshots/login_screen/login_screen_when_newly_installed.png`
   in the Project tool window to inspect the captured screenshot.

Run the generated Dart test rather than the `.feature` file. No emulator or
connected device is required.

The final step overwrites
`screenshots/login_screen/login_screen_when_newly_installed.png` with a 360×640
screenshot. Capture failures fail the test; the image is not a golden comparison.
The generated test is committed and also runs with the normal `flutter test`
suite. Edit the `.feature` and step files, not the generated test.

## Patrol E2E test (Android, manual only)

The Cucumber-style scenario lives in `patrol_test/main.feature`; step definitions
use Patrol for native Android interactions. The launcher generates `patrol_test/main_test.dart`,
builds the APKs, and runs the full lifecycle in one command. The generated
Patrol runner and bundle are excluded from Git; commit the feature and
step/support files. Feature files have a blank line before a `When` clause when it
follows a `Then` clause.

This real-account flow signs in, grants **fresh Google Tasks permission**, creates
a uniquely named task, edits its title and notes, deletes it, and signs out.
Creation, editing, and deletion are checked directly against Google Tasks as
well as the app UI. It is separate from `flutter test` and is not run by CI.
Run it only when E2E execution is explicitly requested.

### Prepare before each run

1. Use a dedicated Google test account on an unlocked **English** Android 10+
   emulator with Google Play services. Physical devices are refused by the launcher.
   Add the account to Android beforehand;
   the test selects it by email and does not enter passwords or handle MFA.
2. Enable the Tasks API, register this app's package and signing certificate,
   and add the account to the OAuth consent screen's test users if applicable.
   Keep the existing `secrets/build.keystore` and `secrets/build.json` configured
   as described above. Do not commit credentials; the E2E screenshots and video use versionable paths.
3. [Unlink Remind Me from the Google test account](#unlink-remind-me-before-every-run)
   before **every run**, including reruns after failures. This resets Google's
   saved consent so the required sign-in/Google Tasks permission confirmation appears.
4. Ensure the device is online, awake and unlocked, and close other account
   dialogs. Use `adb devices` to obtain its exact serial. Check the account for
   any `RemindMe Patrol <run ID>` task left by an interrupted previous run and
   delete only that test task if necessary. Other tasks are preserved.

### Unlink Remind Me before every run

Open [Google Account connections](https://myaccount.google.com/connections) in a
browser and check the profile picture/email to ensure you are using the same
dedicated test account passed to the launcher.

1. Find and select **Remind Me** (the OAuth application used by this project).
2. Choose **Delete all connections you have with Remind Me**, or **Remove access**
   if that is the option shown, and confirm the removal.
3. Check that its access has been removed, then run the Patrol command below.

The next run must show Google's sign-in/Google Tasks permission confirmation.
The test deliberately fails if fresh Tasks consent is missing; do not remove or
weaken that check in the feature's sign-in step. Signing out, reinstalling the
app, or clearing Android app data does not revoke Google's saved consent.
Patrol setup additionally calls Google's native revoke-access API for the selected
test account's Tasks authorization before starting the app. If Google reports
the specific `[28470] No access token was returned` reset error, setup continues
because there is no token to revoke. Every other reset error aborts the test.
The actual fresh Tasks consent screen is still mandatory in either case.
This reset and authorization diagnostics are enabled only in Patrol builds;
normal app builds cannot invoke the reset. Diagnostic logs include
`hasResolution()` without access tokens.

See [Google's instructions for managing app access](https://support.google.com/accounts/answer/3466521).

### Run the Patrol test

Run these commands in PowerShell from the repository root. Resolve dependencies once:

```powershell
flutter pub get
```

Find the running emulator serial:

```powershell
adb devices
```

Replace `<device-id>` and `<test-email>` below with that serial and your dedicated test account.
This single command generates the required runners, builds and installs the APKs,
runs the full lifecycle, and collects screenshots and video. No separate
`build_runner` command is needed:

```powershell
dart run tool/run_patrol.dart --device <device-id> --account <test-email> --dart-define-from-file secrets/build.json
```

For the existing unverified development project on the Pixel emulator, use its
ADB serial (for example `emulator-5554`) and enable the development warning flow:

```powershell
dart run tool/run_patrol.dart --device emulator-5554 --account <test-email> --dart-define-from-file secrets/build.json --allow-unverified-app
```

This runs **login → grant Tasks permission → create task → edit that task →
delete that task → sign out**. It checks the saved title and notes by reopening
the editor, verifies creation/update/deletion against Google Tasks, and confirms
the final signed-out login screen. Existing account tasks are preserved.

For your own unverified development OAuth project, add `--allow-unverified-app`.
This explicitly enables **Advanced → Go to Remind Me (unsafe)** on Google's
development warning screen and captures both warning checkpoints. It only
follows the link naming **Remind Me**; other app names and account-security
challenges are not handled. Omit the flag for verified OAuth projects.

The project pins the resolved Patrol CLI through `pubspec.lock`; no global
Patrol installation or PowerShell script is needed. Use
`dart run tool/run_patrol.dart --help` for usage without building or running.

The launcher validates the selected device, builds and installs the two test
APKs, force-stops `chimin.remindme`, and runs `pm clear chimin.remindme` before
instrumentation. **All local Remind Me app data on that device is erased**,
including cached tasks, preferences, and saved session state. Sync any real
pending changes before using the device. The device's Google account and other
apps are retained. The test requires the initial login screen; it cannot silently
pass using a restored session.

Only the Patrol lifecycle class is selected, so the existing native screenshot
fixtures do not execute. Each run uses unique task data. Google screens have a
60-second idle timeout per sign-in screen and a three-minute overall sign-in
limit; remote assertions have a 30-second timeout. The launcher returns a nonzero
exit code for reset, test, screenshot, or video-recording/collection failures.

### Screenshot comparison and runs without video

The feature compares every captured Patrol checkpoint against the golden
reference set using [Pixelmatch](https://pub.dev/packages/pixelmatch). Golden
references use the original numbered names directly in `screenshots/e2e/`.
New captures are collected in `patrol_test/golden/screenshots/`. Failed comparisons
save the captured image beside its reference with a `_FAILED` suffix, for example
`screenshots/e2e/08_created_FAILED.png`. Passing captures do not replace references.

Use `And I capture screenshot {'16_sign_in_canceled'} and compare with the golden reference`
at each checkpoint in the feature. The comparison code allows 5% difference per
screenshot; the step has no percentage parameter. Google account and development
warning captures are skipped when those optional screens are not shown. The
Tasks consent and confirmation captures remain mandatory. Comparisons run on the
host after screenshots have been collected. A screenshot fails only when its
differing-pixel count divided by its compared app pixels exceeds **5%**. A
difference of exactly 5% passes. Pixelmatch uses its perceptual per-pixel color
threshold of 0.1, including anti-aliased pixels. This color sensitivity is
separate from the allowed 5% image-area difference. Android system bars are
excluded using identical crops on actual and golden screenshots. Run IDs and
other app text remain part of the comparison.

The launcher compares every captured checkpoint, reports all mismatches, and
fails for missing references or changed dimensions. Google warning screens are
optional when not shown; the mandatory consent check remains unchanged. A JSON
report with each screenshot's differing pixels and percentage is written to
`patrol_test/golden/screenshot_comparison.json`. Keep the same device display settings as the reference set.

```powershell
dart run tool/run_patrol.dart --device emulator-5556 --account <test-email> --dart-define-from-file secrets/build.json --allow-unverified-app --no-video
```

Use `--update-goldens` explicitly to create or replace the entire captured golden
set for review. This mode does not assert a visual match. Normal runs never
replace goldens. With `--no-video`, screenshots and logs are still collected,
but neither encoder checks nor video recording run. Previous run video is cleared.

### Screenshots, video, and failures

Patrol golden references (including Google's UI) use **stable numbered paths**
in `screenshots/e2e/`. Current captures, video, and diagnostics remain
in `patrol_test/golden/`:

```text
01_sign_in_required.png
02_development_warning.png
03_development_confirmation.png
04_tasks_consent.png
05_tasks_confirmation.png
06_home.png
07_new_task_form.png
08_created.png
09_edited_task_form.png
10_edited.png
11_before_delete.png
12_delete_confirmation.png
13_deleted.png
14_sign_out_confirmation.png
15_sign_in_required.png
16_sign_in_canceled.png
```

The continuous video stays at `patrol_test/golden/test.mp4`.

Each checkpoint keeps its sequence number across runs. Development warning
captures are optional; `99_failure_FAILED.png` is attempted if the lifecycle fails.
Commit approved golden references. Failed captures retain the `_FAILED` suffix
and never replace the reference images. Logs and older timestamped directories stay ignored.
Every captured checkpoint is compared against its corresponding golden reference.

Before recording starts, the launcher removes previous `_FAILED` images, raw
captures, video, and diagnostic logs. Golden references are preserved. A failed run therefore cannot retain
unreached checkpoints from an older full lifecycle. Other files and historical
subdirectories are preserved. Build/preflight failures leave existing captures
untouched. On-device captures and test task data still use a unique run ID to
avoid collecting stale screenshots or colliding with another test task. Repeated
captures of the same checkpoint use the latest timestamp.

Every explicit run records one continuous **`test.mp4`**, overwriting the previous
video. Recording starts before instrumentation launches the app and stops after
the test and its cleanup return, so it includes the native Google screens and
the full requested task lifecycle. The launcher waits for recording startup,
stops only its own encoder process with SIGINT to finalize the MP4, and validates
that the local file contains media data and its finalized index. It preserves
partial video on failure when available, and reports an early recorder exit as
an incomplete-video failure rather than a successful run.

The emulator must support `screenrecord --time-limit 0`; the current Google Play
Pixel emulator does. Older images that only support three-minute recordings are
rejected before the build/test starts. No ffmpeg installation is needed. Video
is scaled to at most 720 pixels wide while preserving the screen aspect ratio.
`recording.txt` records encoder diagnostics; `device.log` and
`instrumentation.txt` contain the test logs. Screenshots and videos are produced
only when you explicitly run the launcher, not during builds or static analysis.

On failure, the test attempts to remove only its own task and sign out. Cleanup
errors are reported without replacing the original failure. If the process or
device disconnects, inspect the dedicated account for the reported run ID before
retrying; remote cleanup cannot be guaranteed after interruption. Screenshots
and videos may contain the test account email and task data. Abrupt launcher
termination or device disconnection can prevent MP4 finalization and collection.

If the Tasks prompt is missing, revoke the OAuth connection again. If account
selection or consent times out, verify the exact email, English device language,
connectivity, and OAuth configuration. Unexpected Google security challenges or
consent UI variants require inspection of the failure screenshot. The opt-in
development warning handling above does not handle MFA or other account-security
prompts. A successful sign-out revokes the app grant
through the current app implementation, but preparation still requires checking
the Google connection before the next run.

If sign-in fails before an account picker appears, inspect the emulator's Google
Play services logs. The bundled services in an old Google APIs image may reject
Credential Manager requests with `Unsupported API`. Update Google Play services
or use a current Google Play emulator image; adding an account alone does not
update those services.

After device testing, rebuild/install the normal app to replace the Patrol test
entry point. Implementation-time validation uses dependency resolution and
static analysis only; running this flow and generating evidence require an
explicit test-run request.

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
`android/screenshots/<page/component>/`, using filenames such as
`task_home_screen_when_four_dated_tasks_exist.png`,
`task_edit_screen_when_adding_task.png`, and
`home_screen_widget_when_four_dated_tasks_exist.png`.

Flutter golden images live in `screenshots/<page/component>/`. Flutter and Android
screenshot filenames follow `<page/component>_when_<what_happen>.png`. Patrol
screenshots live in `screenshots/e2e/` and use `<2_digits_sequence>_<description>.png`.

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

## Daily reminders

Open the task home menu and choose **Reminder settings**. Reminders default to enabled at 8:00 AM local time and summarize incomplete overdue and today tasks from the selected list. Save applies changes; Cancel discards them.

Opening or returning to the app refreshes and shows the current summary when reminders are enabled and tasks qualify.

Android maintains one inexact alarm and builds the summary from the latest cached snapshot when it fires. Delivery can be delayed by battery restrictions. Scheduling is restored after reboot, app updates, and clock or timezone changes; missed reminders are not sent as catch-up alerts. No exact-alarm permission is used.

iOS schedules summaries for the next 60 calendar days. These summaries reflect cached tasks when scheduled. App use and background sync replace and replenish the schedule; background execution at the reminder time is not required. Local timezone changes are reconciled when the app next runs. Remote task changes require sync on both platforms. Disabling reminders or signing out cancels pending and displayed reminders; sign-out also clears reminder task data.

The native implementation is in `packages/daily_reminders`. Flutter regression tests cover settings and serialized updates, and Android instrumentation coverage is in `DailyRemindersPluginTest`. Run device tests on an isolated emulator:

```powershell
$env:ANDROID_SERIAL = 'emulator-5554'
Set-Location android
.\gradlew.bat :app:connectedDebugAndroidTest '-Pandroid.testInstrumentationRunnerArguments.class=chimin.remindme.DailyRemindersPluginTest'
```

Android notification screenshots are written under the app's external test output and copied to `android/screenshots/daily_reminder`. Flutter settings screenshots are under `screenshots/reminder_settings_dialog`. iOS delivery, foreground presentation, taps, and scheduling still require validation with Xcode and an iOS device or simulator.

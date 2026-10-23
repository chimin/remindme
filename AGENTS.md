1. `test` directory structure follows `lib` directory structure
2. 1 test file per 1 source file
3. the test name follows this pattern: {action} should {do what} when {what happen}
4. capture the screenshow in the `golden` directory in the same level as the test file
5. Widget screenshot tests:
   - Source: `android/app/src/androidTest/kotlin/chimin/remindme/TaskWidgetScreenshotTest.kt`
   - Goldens: `android/app/src/androidTest/resources/golden/` (not committed yet; missing goldens are accepted on first run)
   - Screenshots are written to `/sdcard/Download/test_output` on the device, then pulled to `android/app/test/screenshots`.
   - Run the full flow with Gradle:
     ```
     ./gradlew screenshotTests [-PupdateGoldens=true] [-PskipBootWait=true] [-Pavd=RemindMe_Test]
     ```
   - The task is defined in `android/buildSrc/src/main/kotlin/WidgetScreenshotTask.kt`. If no emulator is running it launches the AVD (default `RemindMe_Test`, override with `-Pavd=`), then selects the emulator by filtering `adb devices` for `emulator-` lines (avoids picking up a connected phone), waits for `sys.boot_completed`, runs `:app:connectedAndroidTest` with `ANDROID_SERIAL` set, and pulls screenshots into `android/app/test/screenshots`.
   - The AVD must use an x86_64 system image (ARM won't boot on this machine). Recreate with:
     ```
     avdmanager create avd -n RemindMe_Test -k "system-images;android-34;google_apis;x86_64" -f
     ```
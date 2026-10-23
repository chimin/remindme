import org.gradle.api.DefaultTask
import org.gradle.api.tasks.Input
import org.gradle.api.tasks.TaskAction
import java.io.ByteArrayOutputStream
import java.io.File

/**
 * Orchestrates the widget screenshot workflow entirely within Gradle:
 *   1. Locate adb (PATH, then ANDROID_HOME/ANDROID_SDK_ROOT).
 *   2. If no emulator is running, launch one (default AVD `RemindMe_Test`).
 *   3. Select an emulator serial from `adb devices` (filters `emulator-*` lines
 *      so a connected physical phone is never targeted).
 *   4. Wait for `sys.boot_completed` to become `1`.
 *   5. Install app and test APKs on the emulator.
 *   6. Run `am instrument` to capture widget screenshots.
 *   7. Pull screenshots from app-specific external storage into `android/app/test/screenshots`.
 */
abstract class WidgetScreenshotTask : DefaultTask() {

    @get:Input
    var skipBootWait: Boolean = false

    @get:Input
    var avd: String = "RemindMe_Test"

    @TaskAction
    fun run() {
        val adb = findAdb()
        val emulator = findEmulatorBinary()
        if (!anyEmulatorRunning(adb)) {
            launchEmulator(emulator)
        }
        val serial = selectEmulator(adb)
        if (!skipBootWait) {
            waitUntilBooted(adb, serial)
        }
        runTests(serial, adb)
        pullScreenshots(adb, serial)
    }

    private fun sdkRoots(): List<String> {
        val envRoots = listOf(System.getenv("ANDROID_HOME"), System.getenv("ANDROID_SDK_ROOT")).mapNotNull { it }
        if (envRoots.isNotEmpty()) return envRoots
        // Fallback to the standard Windows install location when env vars are unset.
        val local = File(System.getProperty("user.home"), "AppData/Local/Android/Sdk")
        return listOf(local.absolutePath)
    }

    private fun findAdb(): String {
        findOnPath("adb")?.let { return it }
        for (root in sdkRoots()) {
            listOf("platform-tools/adb.exe", "platform-tools/adb").forEach { name ->
                File(root, name).takeIf { it.exists() }?.let { return it.absolutePath }
            }
        }
        error("adb not found. Install Android SDK platform-tools or add adb to PATH.")
    }

    private fun findEmulatorBinary(): String {
        for (root in sdkRoots()) {
            File(root, "emulator/emulator.exe").takeIf { it.exists() }?.let { return it.absolutePath }
            File(root, "emulator/emulator").takeIf { it.exists() }?.let { return it.absolutePath }
        }
        error("emulator binary not found under Android SDK.")
    }

    private fun findOnPath(name: String): String? {
        val cmd = if (isWindows()) "where" else "which"
        val out = ByteArrayOutputStream()
        val result = project.exec {
            commandLine(cmd, name)
            standardOutput = out
            errorOutput = ByteArrayOutputStream()
            isIgnoreExitValue = true
        }
        return if (result.exitValue == 0) out.toString().trim().lineSequence().firstOrNull() else null
    }

    private fun anyEmulatorRunning(adb: String): Boolean {
        return listDevices(adb).any { it.startsWith("emulator-") }
    }

    private fun launchEmulator(emulator: String) {
        println("No emulator running; launching AVD '$avd' ...")
        val pb = ProcessBuilder(emulator, "-avd", avd, "-no-snapshot", "-no-audio")
        pb.redirectOutput(ProcessBuilder.Redirect.PIPE)
        pb.redirectError(ProcessBuilder.Redirect.PIPE)
        val proc = pb.start()
        // Detach: let it keep running after Gradle's exec completes.
        Runtime.getRuntime().addShutdownHook(Thread {
            proc.destroyForcibly()
        })
    }

    private fun selectEmulator(adb: String): String {
        // After launching an emulator, adb may take a moment to list it, so retry.
        repeat(30) {
            val line = listDevices(adb).firstOrNull { it.startsWith("emulator-") }
            if (line != null) return line.trim().substringBefore("\t").substringBefore(" ")
            Thread.sleep(1000)
        }
        error("No emulator found in `adb devices`. Start an emulator (e.g. RemindMe_Test) first.")
    }

    private fun listDevices(adb: String): List<String> {
        val out = ByteArrayOutputStream()
        project.exec {
            commandLine(adb, "devices")
            standardOutput = out
            errorOutput = ByteArrayOutputStream()
            isIgnoreExitValue = true
        }
        return out.toString().lineSequence().toList()
    }

    private fun waitUntilBooted(adb: String, serial: String) {
        repeat(180) {
            val out = ByteArrayOutputStream()
            val result = project.exec {
                commandLine(adb, "-s", serial, "shell", "getprop", "sys.boot_completed")
                standardOutput = out
                errorOutput = ByteArrayOutputStream()
                isIgnoreExitValue = true
            }
            if (result.exitValue == 0 && out.toString().trim() == "1") return
            Thread.sleep(1000)
        }
        error("Timed out waiting for emulator $serial to boot.")
    }

    /**
     * Install the app and test APKs via adb targeting only the emulator serial.
     * Gradle's own `installDebug`/`installDebugAndroidTest` tasks install on
     * every connected device, which fails on a physically attached phone
     * (INSTALL_FAILED_USER_RESTRICTED).
     */
    private fun installApks(adb: String, serial: String) {
        val appDir = File(project.rootProject.buildDir, "app/outputs/apk")
        val appApk = appDir.resolve("debug/app-debug.apk")
        val testApk = appDir.resolve("androidTest/debug/app-debug-androidTest.apk")
        for (apk in listOf(appApk, testApk)) {
            if (!apk.exists()) {
                error("APK not found: ${apk.absolutePath}. Build it first (assembleDebug / assembleDebugAndroidTest).")
            }
            val result = project.exec {
                commandLine(adb, "-s", serial, "install", "-r", apk.absolutePath)
                isIgnoreExitValue = true
            }
            if (result.exitValue != 0) {
                error("Failed to install ${apk.name}: exit ${result.exitValue}")
            }
        }
    }

    private fun runTests(serial: String, adb: String) {
        installApks(adb, serial)
        val testDir = File(project.projectDir, "app/test/screenshots")
        if (testDir.exists()) testDir.deleteRecursively()
        testDir.mkdirs()
        // Clear stale screenshots from external storage before running.
        project.exec {
            commandLine(adb, "-s", serial, "shell", "rm -rf /sdcard/Android/data/chimin.remindme/files/test_output")
            isIgnoreExitValue = true
        }
        // Run the test APK directly via am instrument so the app stays installed
        // (connectedAndroidTest uninstalls the app afterwards, which breaks pull).
        val result = project.exec {
            commandLine(adb, "-s", serial, "shell",
                "am instrument -w chimin.remindme.test/androidx.test.runner.AndroidJUnitRunner")
            isIgnoreExitValue = true
        }
        if (result.exitValue != 0) {
            error("am instrument failed with exit code ${result.exitValue}.")
        }
    }

    private fun pullScreenshots(adb: String, serial: String) {
        val testDir = File(project.projectDir, "app/test/screenshots")
        if (testDir.exists()) testDir.deleteRecursively()
        testDir.mkdirs()
        // Screenshots are written to app-specific external storage by
        // ScreenshotComparator. adb pull as the shell user can read this.
        project.exec {
            commandLine(adb, "-s", serial, "pull",
                "/sdcard/Android/data/chimin.remindme/files/test_output", testDir.absolutePath)
            isIgnoreExitValue = true
        }
        // adb pull of a directory nests it under a `test_output` subfolder; move
        // the PNGs up so they live directly in the screenshots dir.
        val nested = File(testDir, "test_output")
        if (nested.exists()) {
            nested.walkTopDown().maxDepth(1)
                .filter { it.isFile && it.extension.equals("png", ignoreCase = true) }
                .forEach { it.copyTo(File(testDir, it.name), overwrite = true); it.delete() }
            nested.deleteRecursively()
        }
        val pulled = testDir.walkTopDown()
            .filter { it.isFile && it.extension.equals("png", ignoreCase = true) }
            .count()
        if (pulled == 0) {
            println("Warning: no PNG screenshots were pulled from external storage.")
        } else {
            println("Pulled $pulled screenshot(s) into ${testDir.absolutePath}.")
        }
    }

    private fun isWindows(): Boolean = System.getProperty("os.name").lowercase().startsWith("win")
}
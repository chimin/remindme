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
 *   5. Run `:app:connectedAndroidTest` with `ANDROID_SERIAL` set so Gradle
 *      targets only the emulator (avoids `INSTALL_FAILED_USER_RESTRICTED`).
 *   6. Pull `/sdcard/Download/test_output` into `android/app/test/screenshots`.
 */
abstract class WidgetScreenshotTask : DefaultTask() {

    @get:Input
    var updateGoldens: Boolean = false

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
        runTests(serial)
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

    private fun runTests(serial: String) {
        val testDir = File(project.projectDir, "app/test/screenshots")
        if (testDir.exists()) testDir.deleteRecursively()
        testDir.mkdirs()
        val env = mutableMapOf("ANDROID_SERIAL" to serial)
        if (updateGoldens) env["org.gradle.project.updateGoldens"] = "true"
        val gradlew = if (isWindows()) "gradlew.bat" else "./gradlew"
        val result = project.exec {
            commandLine(gradlew, ":app:connectedAndroidTest")
            workingDir = project.projectDir
            environment(env)
            isIgnoreExitValue = true
        }
        if (result.exitValue != 0) {
            error(":app:connectedAndroidTest failed with exit code ${result.exitValue}.")
        }
    }

    private fun pullScreenshots(adb: String, serial: String) {
        val testDir = File(project.projectDir, "app/test/screenshots")
        if (testDir.exists()) testDir.deleteRecursively()
        testDir.mkdirs()
        project.exec {
            commandLine(adb, "-s", serial, "pull", "/sdcard/Download/test_output", testDir.absolutePath)
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
            println("Warning: no PNG screenshots were pulled from /sdcard/Download/test_output.")
        } else {
            println("Pulled $pulled screenshot(s) into ${testDir.absolutePath}.")
        }
    }

    private fun isWindows(): Boolean = System.getProperty("os.name").lowercase().startsWith("win")
}
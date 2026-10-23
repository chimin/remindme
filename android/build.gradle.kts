allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

/**
 * Run connectedAndroidTest on an emulator and pull widget screenshots.
 *
 * Usage:
 *   ./gradlew pullWidgetScreenshots
 *   ./gradlew pullWidgetScreenshots -PupdateGoldens=true -PskipBootWait=true
 */
tasks.register<WidgetScreenshotTask>("screenshotTests") {
    group = "verification"
    description = "Ensure an emulator is booted, run :app:connectedAndroidTest on it, and pull widget screenshots."
    updateGoldens = project.hasProperty("updateGoldens") && project.property("updateGoldens").toString().toBoolean()
    skipBootWait = project.hasProperty("skipBootWait") && project.property("skipBootWait").toString().toBoolean()
    avd = project.findProperty("avd")?.toString() ?: "RemindMe_Test"
}
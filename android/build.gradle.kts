// The fixture entry point is compiled only for the screenshot workflow.
if (gradle.startParameter.taskNames.any { it.substringAfterLast(':') == "screenshotTests" }) {
    project(":app").extensions.extraProperties["target"] =
        rootProject.file("../lib/main_screenshot.dart").absolutePath
}

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
 * Run screenshot tests on an emulator and pull widget screenshots.
 *
 * Usage:
 *   ./gradlew screenshotTests
 *   ./gradlew screenshotTests -PskipBootWait=true
 */
tasks.register<WidgetScreenshotTask>("screenshotTests") {
    group = "verification"
    description = "Ensure an emulator is booted, run widget screenshot tests on it, and pull screenshots."
    skipBootWait = project.hasProperty("skipBootWait") && project.property("skipBootWait").toString().toBoolean()
    avd = project.findProperty("avd")?.toString() ?: "RemindMe_Test"

    dependsOn(":app:assembleDebug")
    dependsOn(":app:assembleDebugAndroidTest")
}
/** Regenerate branding explicitly; normal builds use checked-in images. */
tasks.register<UpdateBrandingTask>("updateBranding") {
    group = "branding"
    description = "Generate Android/iOS app icons and Play Store branding images."
    iconSource.set(rootProject.file(
        providers.gradleProperty("brandingIconSource").getOrElse(
            "../ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"
        )
    ))
    featureSource.set(rootProject.file(
        providers.gradleProperty("brandingFeatureSource").getOrElse(
            "../assets/branding/play-store-feature-graphic.png"
        )
    ))
    iconCatalog.set(rootProject.file("../ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"))
    outputDirectory.set(rootProject.file(
        providers.gradleProperty("brandingOutputDir").getOrElse("..")
    ))
}

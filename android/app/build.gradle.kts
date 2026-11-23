plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Patrol passes this flag explicitly to both APK build tasks.
// Regular builds and the screenshot fixture use the native Cucumber runner.
val patrolE2e = providers.gradleProperty("patrol-enabled").orNull == "true"

android {
    namespace = "chimin.remindme"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "chimin.remindme"
        resValue("bool", "patrol_e2e", patrolE2e.toString())
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = if (patrolE2e)
            "pl.leancode.patrol.PatrolJUnitRunner"
        else "io.cucumber.android.runner.CucumberAndroidJUnitRunner"
        if (!patrolE2e) {
            testInstrumentationRunnerArguments["optionsAnnotationPackage"] = "chimin.remindme.support"
        }
    }

    if (patrolE2e) {
        sourceSets.getByName("androidTest").java.srcDir("src/patrol/java")
    }

    signingConfigs {
        create("release") {
            val keystore = file("../../secrets/build.keystore")
            if (!keystore.exists()) {
                throw GradleException(
                    "secrets/build.keystore not found for signing"
                )
            }
            storeFile = keystore
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: "android"
            keyAlias = System.getenv("KEY_ALIAS") ?: "androiddebugkey"
            keyPassword = System.getenv("KEY_PASSWORD") ?: "android"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("release")
        }
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

dependencies {
    // Patrol is linked into the debug app. Match its runtime to the existing
    // instrumentation dependencies for AGP's consistent version resolution.
    debugImplementation("androidx.test.ext:junit:1.2.1")
    debugImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("io.cucumber:cucumber-android:7.18.1")
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.2.0")
}

flutter {
    source = "../.."
}

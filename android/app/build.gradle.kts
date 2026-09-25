import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// AdMob application id: -PADMOB_APP_ID=..., the ADMOB_APP_ID env var, or
// admobAppId in android/key.properties (never committed). Defaults to
// Google's public test app id so debug builds always serve test ads.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) load(FileInputStream(keystorePropertiesFile))
}
val admobAppId: String = (project.findProperty("ADMOB_APP_ID") as String?)
    ?: System.getenv("ADMOB_APP_ID")
    ?: keystoreProperties.getProperty("admobAppId")
    ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.anandworks.hexadominate"
    // Plugins (audioplayers, share_plus, file_picker) compile against API 36.
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.anandworks.hexadominate"
        // Android 8.0+
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["admobAppId"] = admobAppId
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

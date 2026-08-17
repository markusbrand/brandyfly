import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "rocks.brandstaetter.brandyfly"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    val keyAliasValue = System.getenv("KEY_ALIAS") ?: keystoreProperties["keyAlias"] as String?
    val keyPasswordValue = System.getenv("KEY_PASSWORD") ?: keystoreProperties["keyPassword"] as String?
    val storeFileValue = System.getenv("STORE_FILE") ?: keystoreProperties["storeFile"] as String?
    val storePasswordValue = System.getenv("STORE_PASSWORD") ?: keystoreProperties["storePassword"] as String?
    val hasReleaseSigningConfig = keyAliasValue != null && keyPasswordValue != null && storeFileValue != null && storePasswordValue != null

    if (hasReleaseSigningConfig) {
        signingConfigs {
            create("release") {
                keyAlias = keyAliasValue
                keyPassword = keyPasswordValue
                storeFile = file(storeFileValue!!)
                storePassword = storePasswordValue
            }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "rocks.brandstaetter.brandyfly"
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            if (hasReleaseSigningConfig) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                // Signing with the debug keys for now, so `flutter run --release` works.
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

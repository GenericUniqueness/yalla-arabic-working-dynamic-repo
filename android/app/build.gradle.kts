import java.util.Properties

plugins {
    id("com.android.application")
    // Google Services is disabled in the private Yalla Arabic dev shell.
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        keystorePropertiesFile.inputStream().use { load(it) }
    }
}
val releaseSigningPropertyNames = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")

fun missingReleaseSigningProperties(): List<String> =
    releaseSigningPropertyNames.filter { keystoreProperties.getProperty(it).isNullOrBlank() }

fun releaseSigningStoreFile() =
    keystoreProperties.getProperty("storeFile")?.let { rootProject.file(it) }

gradle.taskGraph.whenReady {
    val releaseTaskRequested = allTasks.any { it.name.contains("Release", ignoreCase = true) }
    if (!releaseTaskRequested) {
        return@whenReady
    }

    if (!keystorePropertiesFile.exists()) {
        throw GradleException(
            "Release signing requires android/key.properties. " +
                "Create it locally with storeFile, storePassword, keyAlias, and keyPassword."
        )
    }

    val missingKeys = missingReleaseSigningProperties()
    if (missingKeys.isNotEmpty()) {
        throw GradleException(
            "Release signing is missing required android/key.properties entries: " +
                missingKeys.joinToString(", ")
        )
    }

    val storeFile = releaseSigningStoreFile()
    if (storeFile == null || !storeFile.exists()) {
        throw GradleException(
            "Release signing keystore file was not found at android/" +
                keystoreProperties.getProperty("storeFile") +
                ". Create android/app/upload-keystore.jks or update android/key.properties."
        )
    }
}

android {
    namespace = "com.yallaarabic.dev"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.yallaarabic.dev"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists() && missingReleaseSigningProperties().isEmpty()) {
                storeFile = releaseSigningStoreFile()
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

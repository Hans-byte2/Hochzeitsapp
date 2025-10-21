// android/app/build.gradle.kts
import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // Der Flutter Gradle Plugin muss NACH Android & Kotlin angewendet werden.
    id("dev.flutter.flutter-gradle-plugin")
}

/**
 * Release-Signing: key.properties laden
 * Datei: android/key.properties
 * Inhalt z.B.:
 *   storePassword=DEIN_STORE_PASSWORT
 *   keyPassword=DEIN_KEY_PASSWORT
 *   keyAlias=my-key-alias
 *   storeFile=../app/my-release-key.jks
 */
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // TODO: finalen Paketnamen setzen (z. B. "de.greekinlove.wedding")
    namespace = "de.heartpebble.hochzeitsplaner"

    // Von Flutter bereitgestellt
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        // Muss mit namespace nicht identisch sein – ist die sichtbare App-ID im Store
        applicationId = "de.heartpebble.hochzeitsplaner"

        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion

        // Aus local.properties via Flutter gesetzt (z. B. version: 1.0.0+3)
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        multiDexEnabled = true
    }

    compileOptions {
        // Java 11 ist für aktuelle Toolchains okay
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Optional: Desugaring aktivieren, wenn du neuere Java-APIs nutzt
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    // Frühzeitig failen, wenn key.properties fehlt
if (!keystorePropertiesFile.exists()) {
    throw GradleException("key.properties fehlt unter android/key.properties")
}

    // Release-Signing anhand von key.properties
    signingConfigs {
        create("release") {
            val storeFileProp = keystoreProperties["storeFile"] as String?
            if (storeFileProp != null) {
                storeFile = file(storeFileProp)
            }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        getByName("release") {
            // Wichtig: mit dem Release-Key signieren (nicht mehr debug)
            signingConfig = signingConfigs.getByName("release")
            // Für den Anfang aus – später gern aktivieren + ProGuard-Datei pflegen
            isMinifyEnabled = false
            isShrinkResources = false
        }
        // debug bleibt Standard (wird automatisch mit Debug-Key signiert)
    }
}

// Flutter-Quellordner referenzieren (Standard bei Flutter-Projekten)
flutter {
    source = "../.."
}

dependencies {
    // Nur nötig, wenn du Java-8+/Zeit-API etc. in minSdk < 26 nutzt
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
    // In der Regel bringt das Flutter-Plugin die Kotlin-Stdlib mit.
    // Falls du eine definierte $kotlin_version nutzt, kannst du diese Zeile wieder aktivieren:
    // implementation("org.jetbrains.kotlin:kotlin-stdlib")
}

import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load key.properties file if it exists
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.mojarcoder.mojar_player_pro"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"]?.toString() ?: ""
            keyPassword = keystoreProperties["keyPassword"]?.toString() ?: ""
            val storePath = keystoreProperties["storeFile"]?.toString() ?: ""
            if (storePath.isNotEmpty()) {
                storeFile = rootProject.file(storePath)
                storePassword = keystoreProperties["storePassword"]?.toString() ?: ""
            }
        }
    }

    defaultConfig {
        // Specify your own unique Application ID
        applicationId = "com.mojarcoder.mojar_player_pro"
        minSdk = 21
        targetSdk = flutter.targetSdkVersion
        versionCode = 8
        versionName = "1.0.8"
        
        // Enable multidex
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Use signing config for release
            signingConfig = signingConfigs.getByName("release")
            
            // Enable minification for release builds
            isMinifyEnabled = true
            proguardFiles(getDefaultProguardFile("proguard-android.txt"), "proguard-rules.pro")
        }
        
        debug {
            // Disable minification for debug builds
            isMinifyEnabled = false
        }
    }

    // Support for larger media files
    packagingOptions {
        resources {
            excludes += setOf("META-INF/DEPENDENCIES", "META-INF/LICENSE", "META-INF/LICENSE.txt", "META-INF/license.txt", "META-INF/NOTICE", "META-INF/NOTICE.txt", "META-INF/notice.txt", "META-INF/ASL2.0")
        }
    }
    
    // Fix issues with duplicate files
    lint {
        disable += setOf("InvalidPackage", "MissingTranslation")
    }
}

dependencies {
    // Add multidex support
    implementation("androidx.multidex:multidex:2.0.1")
    // Add Play Core library
    implementation("com.google.android.play:core:1.10.3")
}

flutter {
    source = "../.."
}

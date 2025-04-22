plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.mojarplayer.mojar_player_new"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Specify your own unique Application ID
        applicationId = "com.mojarplayer.mojar_player_new"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        
        // Enable multidex
        multiDexEnabled = true
    }

    buildTypes {
        release {
            // Add your own signing config for the release build
            signingConfig = signingConfigs.getByName("debug")
            
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

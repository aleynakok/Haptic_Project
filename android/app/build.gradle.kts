plugins {
    id("com.android.application")
    id("kotlin-android")
    // Flutter Gradle Plugin'i mutlaka diğerlerinden sonra gelmeli
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    layout.buildDirectory.set(file("${project.projectDir}/../../build/app"))
    // Kendi proje adınla (package name) eşleştiğinden emin ol
    namespace = "com.example.haptic_project"
    compileSdk = 35

    sourceSets {
        getByName("main").java.srcDirs("src/main/kotlin")
    }

    defaultConfig {
        // Kendi proje adınla eşleştiğinden emin ol
        applicationId = "com.example.haptic_project"
        minSdk = 21
        targetSdk = 35
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            // Sadece hata ayıklama (debug) aşamasındaysan burayı varsayılan bırak
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}
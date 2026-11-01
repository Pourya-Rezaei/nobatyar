import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.nobatyar.nobatyar"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications به java.time نیاز دارد که در API<26 موجود نیست؛
        // desugaring این APIs را روی اندروید قدیمی هم فراهم می‌کند
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.nobatyar.app"
        // حداقل اندروید ۷ (انتخاب کارفرما)
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    packaging {
        jniLibs {
            // فقط معماری‌های ARM بسته‌بندی می‌شوند؛
            // حذف کتابخانه‌های جزئی x86_64 که باعث نصب روی شبیه‌ساز و کرش می‌شود
            excludes += "lib/x86_64/**"
        }
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = keystoreProperties["storeFile"]?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // امضا با کلید اختصاصی ریلیز
            signingConfig = if (keystorePropertiesFile.exists())
                signingConfigs.getByName("release")
            else
                signingConfigs.getByName("debug")
        }
    }

    // لینت‌های حیاتی در محیط ساخت با رم محدود مشکل‌ساز است؛
    // کد لینت را در توسعه با `flutter analyze` بررسی می‌کنیم
    lint {
        checkReleaseBuilds = false
        abortOnError = false
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

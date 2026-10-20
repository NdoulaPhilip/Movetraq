import java.util.Base64
import java.util.Properties
import groovy.json.JsonSlurper
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("kotlin-android")

    // Firebase Google Services
    id("com.google.gms.google-services")

    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.movetraq"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    defaultConfig {
        applicationId = "com.example.movetraq"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        val localProperties = Properties().also { properties ->
            val file = rootProject.file("local.properties")
            if (file.exists()) {
                file.inputStream().use(properties::load)
            }
        }
        val dartDefines = (project.findProperty("dart-defines") as String?)
            ?.split(",")
            ?.mapNotNull { encoded ->
                val parts = String(Base64.getDecoder().decode(encoded)).split("=", limit = 2)
                if (parts.size == 2) parts[0] to parts[1] else null
            }
            ?.toMap()
            ?: emptyMap()
        // Use only the client key already bundled for this Android package.
        // Server-side Maps credentials must never be copied into the APK.
        val googleServicesFile = file("google-services.json")
        val googleClients = if (googleServicesFile.exists()) {
            (JsonSlurper().parse(googleServicesFile) as? Map<*, *>)?.get("client") as? List<*>
        } else null
        val androidClient = googleClients?.filterIsInstance<Map<*, *>>()?.firstOrNull { client ->
            val info = client["client_info"] as? Map<*, *>
            val androidInfo = info?.get("android_client_info") as? Map<*, *>
            androidInfo?.get("package_name") == applicationId
        }
        val clientApiKey = (androidClient?.get("api_key") as? List<*>)
            ?.filterIsInstance<Map<*, *>>()
            ?.mapNotNull { it["current_key"] as? String }
            ?.firstOrNull { it.isNotBlank() }
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            listOf(
                dartDefines["GOOGLE_MAPS_API_KEY"],
                localProperties.getProperty("GOOGLE_MAPS_API_KEY"),
                project.findProperty("GOOGLE_MAPS_API_KEY") as String?,
                System.getenv("GOOGLE_MAPS_API_KEY"),
                clientApiKey,
            ).firstNotNullOfOrNull { it?.trim()?.takeIf(String::isNotEmpty) }
                ?: ""
    }

    buildTypes {
        release {
            // Using debug signing for now so flutter run --release works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_11)
    }
}

flutter {
    source = "../.."
}

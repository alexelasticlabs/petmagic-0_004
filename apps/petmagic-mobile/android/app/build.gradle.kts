import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    FileInputStream(keystorePropertiesFile).use { stream ->
        keystoreProperties.load(stream)
    }
}

val hasReleaseSigningConfig = listOf(
    "storeFile",
    "storePassword",
    "keyAlias",
    "keyPassword",
).all { key ->
    !keystoreProperties.getProperty(key).isNullOrBlank()
}

val isReleaseTaskRequested = gradle.startParameter.taskNames.any { taskName ->
    taskName.contains("release", ignoreCase = true)
}

val allowInsecureReleaseSigning =
    providers.gradleProperty("allowInsecureReleaseSigning").orNull == "true"
val allowPlaceholderFirebase =
    providers.gradleProperty("allowPlaceholderFirebase").orNull == "true"

val requestedReleaseEnvironment = gradle.startParameter.taskNames
    .joinToString(" ")
    .lowercase()
    .let { taskNames ->
        when {
            !isReleaseTaskRequested -> null
            taskNames.contains("staging") -> "staging"
            taskNames.contains("production") -> "production"
            else -> throw GradleException(
                "Release task must target an explicit staging or production flavor.",
            )
        }
    }

fun decodedDartDefines(): Map<String, String> {
    val encoded = providers.gradleProperty("dart-defines").orNull.orEmpty()
    if (encoded.isBlank()) {
        return emptyMap()
    }
    return encoded.split(',').mapNotNull { value ->
        runCatching {
            String(Base64.getDecoder().decode(value))
        }.getOrNull()?.substringBefore('=')?.let { key ->
            val decoded = String(Base64.getDecoder().decode(value))
            key to decoded.substringAfter('=', "")
        }
    }.toMap()
}

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.petmagic.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.petmagic.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    flavorDimensions += "environment"
    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationId = "com.petmagic.app.staging"
            manifestPlaceholders["appName"] = "PetMagic Staging"
            manifestPlaceholders["appDeepLinkScheme"] = "petmagic-staging"
            manifestPlaceholders["stripeRedirectScheme"] = "petmagicstripe-staging"
        }
        create("production") {
            dimension = "environment"
            applicationId = "com.petmagic.app"
            manifestPlaceholders["appName"] = "PetMagic"
            manifestPlaceholders["appDeepLinkScheme"] = "petmagic"
            manifestPlaceholders["stripeRedirectScheme"] = "petmagicstripe"
        }
    }

    signingConfigs {
        if (hasReleaseSigningConfig) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true

            if (isReleaseTaskRequested &&
                !hasReleaseSigningConfig &&
                !allowInsecureReleaseSigning
            ) {
                throw GradleException(
                    "Release signing is not configured. Add android/key.properties with release keystore " +
                        "or set -PallowInsecureReleaseSigning=true only for local temporary builds.",
                )
            }

            if (isReleaseTaskRequested) {
                val environment = requestedReleaseEnvironment!!
                val expectedPackageName = if (environment == "staging") {
                    "com.petmagic.app.staging"
                } else {
                    "com.petmagic.app"
                }
                val expectedApiBaseUrl = if (environment == "staging") {
                    "https://api.staging.petmagic.app"
                } else {
                    "https://api.petmagic.app"
                }
                val defines = decodedDartDefines()
                if (defines["APP_ENVIRONMENT"] != environment ||
                    defines["APP_PACKAGE_NAME"] != expectedPackageName ||
                    defines["API_BASE_URL"] != expectedApiBaseUrl
                ) {
                    throw GradleException(
                        "Release dart-defines must match the $environment flavor: " +
                            "APP_ENVIRONMENT, APP_PACKAGE_NAME and API_BASE_URL are required.",
                    )
                }

                val firebaseConfig = file("google-services.json")
                if (!firebaseConfig.exists()) {
                    throw GradleException(
                        "Missing android/app/google-services.json. Inject it from the protected environment.",
                    )
                }
                val firebaseContents = firebaseConfig.readText()
                if (!firebaseContents.contains("\"package_name\": \"$expectedPackageName\"")) {
                    throw GradleException(
                        "google-services.json does not match $expectedPackageName.",
                    )
                }
                val hasPlaceholderFirebase = listOf(
                    "petmagic-placeholder",
                    "replace-with-",
                    "000000000000",
                ).any(firebaseContents::contains)
                if (hasPlaceholderFirebase && !allowPlaceholderFirebase) {
                    throw GradleException(
                        "Placeholder Firebase config is forbidden for release builds. " +
                            "Use -PallowPlaceholderFirebase=true only for explicit CI packaging smoke.",
                    )
                }
            }

            signingConfig = if (hasReleaseSigningConfig) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

tasks.withType<JavaCompile>().configureEach {
    doFirst {
        // Flutter can generate this app-source registrant with dev-only plugins.
        // Keep production plugin registration intact while stripping test-only entries.
        val generatedPluginRegistrant =
            project.layout.projectDirectory.file(
                "src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java",
            ).asFile
        if (generatedPluginRegistrant.exists()) {
            val content = generatedPluginRegistrant.readText()
            val sanitizedContent =
                content.replace(
                    Regex(
                        """\s+try \{\s*flutterEngine\.getPlugins\(\)\.add\(new dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin\(\)\);\s*\} catch \(Exception e\) \{\s*Log\.e\(TAG, "Error registering plugin integration_test, dev\.flutter\.plugins\.integration_test\.IntegrationTestPlugin", e\);\s*\}""",
                        RegexOption.DOT_MATCHES_ALL,
                    ),
                    "",
                )
            if (sanitizedContent != content) {
                generatedPluginRegistrant.writeText(sanitizedContent)
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

import java.util.Properties
import java.util.regex.Pattern

val pubspec = project.projectDir.parentFile.resolve("pubspec.yaml")
val yaml = pubspec.readText()
val versionMatcher = Pattern.compile("^version:\\s*['\"]?([^\\n'\"]*)['\"]?$", Pattern.MULTILINE).matcher(yaml)

require(versionMatcher.find()) { "Unable to read package version from ${pubspec.absolutePath}" }

group = "com.fluttercandies.photo_manager"
version = versionMatcher.group(1).replace("+", "-")

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
}

android {
    namespace = "com.fluttercandies.photo_manager"
    compileSdk = 36

    defaultConfig {
        minSdk = 16
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    implementation("com.github.bumptech.glide:glide:4.16.0")
    implementation("androidx.exifinterface:exifinterface:1.4.2")
    testImplementation("junit:junit:4.13.2")
}

import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    // Flutter plugins are separate Gradle subprojects. Keep their Kotlin
    // bytecode target aligned with the app's Java 17 target even when Gradle
    // itself runs on a newer JDK (for example flutter_stripe on JDK 21).
    tasks.withType<KotlinJvmCompile>().configureEach {
        compilerOptions.jvmTarget.set(JvmTarget.JVM_17)
    }

    if (name == "stripe_android") {
        // flutter_stripe declares optional Issuing Push Provisioning support as
        // compileOnly. Its restricted TapAndPay transitive is not needed by
        // PetMagic PaymentSheet, but AGP 9 otherwise tries to resolve it for
        // release lint and blocks bundle creation.
        configurations.configureEach {
            if (name.endsWith("LintChecksClasspath")) {
                exclude(
                    group = "com.google.android.gms",
                    module = "play-services-tapandpay",
                )
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

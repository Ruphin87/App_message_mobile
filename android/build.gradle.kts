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
}
subprojects {
    project.evaluationDependsOn(":app")
}

subprojects {
    plugins.withId("com.android.application") {
        extensions.configure<com.android.build.api.dsl.ApplicationExtension>("android") {
            compileSdk = 36
        }
    }
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
            compileSdk = 36
        }
    }

    val forceCompileSdk36 = {
        plugins.withId("com.android.application") {
            extensions.configure<com.android.build.api.dsl.ApplicationExtension>("android") {
                compileSdk = 36
            }
        }
        plugins.withId("com.android.library") {
            extensions.configure<com.android.build.api.dsl.LibraryExtension>("android") {
                compileSdk = 36
            }
        }
    }

    if (state.executed) {
        forceCompileSdk36()
    } else {
        afterEvaluate {
            forceCompileSdk36()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

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

// CameraX 1.5.3 (pinned by camera_android_camerax) declares androidx.concurrent:
// concurrent-futures as runtime-scoped, but its class files carry type annotations
// that javac must resolve at compile time. Put it on the compile classpath.
subprojects {
    plugins.withId("com.android.library") {
        if (name == "camera_android_camerax") {
            dependencies {
                add("compileOnly", "androidx.concurrent:concurrent-futures:1.3.0")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

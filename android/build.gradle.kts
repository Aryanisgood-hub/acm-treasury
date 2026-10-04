allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Some plugins (file_picker, etc.) are compiled against an older Android API
// than one of their own dependencies requires. Force every plugin library to
// compile against API 36 so the release build passes the AAR metadata check.
subprojects {
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            val androidExt = extensions.findByName("android")
            if (androidExt != null) {
                androidExt.javaClass
                    .getMethod("setCompileSdk", Int::class.javaObjectType)
                    .invoke(androidExt, 36)
            }
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
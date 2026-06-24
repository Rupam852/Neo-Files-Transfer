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
    fun configureAndroid() {
        if (project.hasProperty("android")) {
            val android = project.property("android")
            try {
                android?.javaClass?.getMethod("setCompileSdk", Int::class.javaPrimitiveType)?.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    android?.javaClass?.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)?.invoke(android, 36)
                } catch (ex: Exception) {}
            }
        }
    }
    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate { configureAndroid() }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

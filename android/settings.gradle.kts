pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "facetime-android-poc"

include(":app")
include(":core-model")
include(":core-rust")
include(":core-security")
include(":core-diagnostic")
include(":core-network")

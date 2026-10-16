plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.android) apply false
    alias(libs.plugins.kotlin.compose) apply false
    alias(libs.plugins.kotlin.serialization) apply false
}

buildscript {
    extra.apply {
        set("compileSdk", 35)
        set("targetSdk", 35)
        set("minSdk", 26)
        set("versionCode", 1)
        set("versionName", "0.1.0-poc")
    }
}

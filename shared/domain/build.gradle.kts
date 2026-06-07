plugins {
    id("kmp.library")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.domain"
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.datetime)
        }
    }
}

plugins {
    id("kmp.feature")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.feature.visitlist"
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
        }
    }
}

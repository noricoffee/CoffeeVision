plugins {
    id("kmp.feature")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.feature.analysis"
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
            implementation(libs.kotlinx.datetime)
        }
    }
}

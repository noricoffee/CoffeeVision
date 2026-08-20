plugins {
    id("kmp.feature")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.feature.map"
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            // MapUiState.visitedCafes が VisitedCafe（Instant フィールドを持つ）を参照するため
            implementation(libs.kotlinx.datetime)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
        }
    }
}

plugins {
    id("kmp.feature")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.feature.coffeeeditor"
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.datetime)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
        }
    }
}

plugins {
    id("kmp.feature")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.feature.cafedetail"
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            // CafeDetailViewModel が Visit.visitedOn（LocalDate）で sortedByDescending を使うため
            implementation(libs.kotlinx.datetime)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
        }
    }
}

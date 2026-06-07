plugins {
    id("kmp.library")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.core"
    }

    sourceSets {
        commonMain.dependencies {
            implementation(libs.kotlinx.coroutines.core)
            // domain 側の Repository インターフェースを再エクスポートする想定なので api
            // （PR1 では中身ゼロだが、PR2 で AppContainer を移してきたときに必要になる）
            api(projects.shared.domain)
        }
    }
}

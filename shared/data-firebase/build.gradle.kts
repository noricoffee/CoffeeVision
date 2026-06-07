plugins {
    id("kmp.library")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.dataFirebase"
    }

    sourceSets {
        commonMain.dependencies {
            // domain の Repository / RemoteVisitDataSource インターフェースを公開する
            // （Android 実装が public に出すと iosApp 側から見えてしまうため、
            //   現状 commonMain は I/F の再公開のみで実装は androidMain に限定する）
            api(projects.shared.domain)
        }
        androidMain.dependencies {
            implementation(project.dependencies.platform(libs.firebase.bom))
            implementation(libs.firebase.firestore)
            implementation(libs.firebase.auth)
            implementation(libs.firebase.storage)
        }
    }
}

plugins {
    id("kmp.library")
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.core"
    }

    sourceSets {
        commonMain.dependencies {
            // domain 側 Repository インターフェース等の再エクスポート
            api(projects.shared.domain)
            // AppContainer が AppDatabase / LocalVisitRepository を内部で組み立てるため
            api(projects.shared.dataLocal)
            // Repository インターフェースの Android 実装の class path を core 経由で公開
            api(projects.shared.dataFirebase)
            implementation(libs.kotlinx.coroutines.core)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
        }
        // VisitRepositoryImplTest は data-local 側に置いている（createInMemoryTestSqlDriver の
        // expect/actual が data-local の commonTest に閉じているため）。core 側に test 用ドライバ
        // を持たせる必要が出てきたら androidHostTest に sqldelight.driver.sqlite を追加する
    }
}

plugins {
    id("kmp.library")
    alias(libs.plugins.sqldelight)
    alias(libs.plugins.kotlinSerialization)
}

kotlin {
    androidLibrary {
        namespace = "com.noricoffee.dataLocal"
    }

    sourceSets {
        commonMain.dependencies {
            // domain の Visit / Cafe / CoffeeItem / FoodItem / Photo が公開 API に出るため api
            api(projects.shared.domain)

            implementation(libs.kotlinx.coroutines.core)
            implementation(libs.kotlinx.serialization.json)
            implementation(libs.kotlinx.datetime)

            implementation(libs.sqldelight.runtime)
            implementation(libs.sqldelight.coroutines.extensions)
        }
        commonTest.dependencies {
            implementation(libs.kotlin.test)
            implementation(libs.kotlinx.coroutines.test)
            // VisitRepositoryImplTest が shared/core の VisitRepositoryImpl をテストする。
            // テスト所属は「振る舞いの所属するモジュール」が原則だが、ドライバ生成 (data-local の
            // commonTest にある expect/actual `createInMemoryTestSqlDriver`) を使うため、
            // 例外的に data-local 側に置いている。
            implementation(projects.shared.core)
        }
        iosMain.dependencies {
            implementation(libs.sqldelight.driver.native)
        }
        androidMain.dependencies {
            implementation(libs.sqldelight.driver.android)
        }
        getByName("androidHostTest").dependencies {
            // JdbcSqliteDriver は JVM 専用なので commonTest ではなく androidHostTest に置く
            // （詳細は docs/tasks/lessons.md 2026-06-02 KMP + SQLDelight のテスト配置）
            implementation(libs.sqldelight.driver.sqlite)
        }
    }
}

sqldelight {
    databases {
        create("AppDatabase") {
            packageName.set("com.noricoffee.db")
        }
    }
}

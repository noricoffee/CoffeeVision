import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.plugin.mpp.apple.XCFramework

// shared/framework は iOS 向け Umbrella モジュール。
// 全 shared/* モジュールを api 依存 + framework { export(...) } で SharedLogic.framework に集約する。
//
// Convention Plugin (kmp.library) を使わない理由:
// - framework { ... } ブロックを直接書く必要があり、kmp.library にはその DSL がない
// - SKIE は umbrella framework 専用（個別 feature/data モジュールに付けても意味がない）
//
// baseName は "SharedLogic" のまま維持（既存 Swift 側が `import SharedLogic` を使っているため、
// 名前を変えると iOS ビルドが壊れる）。
plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
    alias(libs.plugins.skie)
}

kotlin {
    compilerOptions {
        freeCompilerArgs.add("-Xexpect-actual-classes")
    }

    // XCFramework("SharedLogic") を宣言すると assembleSharedLogicXCFramework タスクが生成される。
    // 各 iOS target の framework を addToXCFramework で束ねて 1 つの XCFramework として組み立てる。
    // baseName と XCFramework 名を統一しておくことで「XCFramework の指定 name とラップ対象 framework
    // の baseName が異なる」warning を抑止する（Phase 2.5 PR3 dispatch C で統一）。
    val xcf = XCFramework("SharedLogic")

    listOf(
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SharedLogic"
            isStatic = true
            // sqliter (NativeSqliteDriver の依存) が iOS のシステム SQLite に動的リンクするため、
            // data-local 由来 symbol を取り込む umbrella にも sqlite3 link 指示が必要。
            linkerOpts("-lsqlite3")

            // api(...) だけでは依存先 Kotlin class が Obj-C ヘッダに出ない。
            // export(...) を明示することで各 shared モジュールの public API が
            // SharedLogic.framework のヘッダに含まれる（lessons.md 2026-06-08 参照）。
            export(projects.shared.core)
            export(projects.shared.domain)
            export(projects.shared.dataLocal)
            export(projects.shared.dataFirebase)

            xcf.add(this)
        }
    }

    androidLibrary {
        namespace = "com.noricoffee.framework"
        compileSdk = libs.versions.android.compileSdk.get().toInt()
        minSdk = libs.versions.android.minSdk.get().toInt()

        compilerOptions {
            jvmTarget = JvmTarget.JVM_11
        }
    }

    sourceSets {
        commonMain.dependencies {
            api(projects.shared.core)
            api(projects.shared.domain)
            api(projects.shared.dataLocal)
            api(projects.shared.dataFirebase)
        }
    }
}

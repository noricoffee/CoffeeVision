import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    alias(libs.plugins.kotlinMultiplatform)
    alias(libs.plugins.androidMultiplatformLibrary)
    alias(libs.plugins.skie)
}

kotlin {
    compilerOptions {
        freeCompilerArgs.add("-Xexpect-actual-classes")
    }

    listOf(
        iosArm64(),
        iosSimulatorArm64()
    ).forEach { iosTarget ->
        iosTarget.binaries.framework {
            baseName = "SharedLogic"
            isStatic = true
            // sqliter (NativeSqliteDriver の依存) が iOS のシステム SQLite に動的リンクするため
            // data-local 由来の symbol が iOS framework に取り込まれるので維持する
            linkerOpts("-lsqlite3")

            // api(...) だけでは依存先 Kotlin class が Obj-C ヘッダに出ない（Klib 内に含まれても
            // Swift から見えない）。export(...) を明示して各 shared モジュールの公開 API を
            // SharedLogic.framework のヘッダに含める。PR3 で shared/framework が umbrella に
            // なったらこの export 群もそちらに移送する。
            export(projects.shared.core)
            export(projects.shared.domain)
            export(projects.shared.dataLocal)
            export(projects.shared.dataFirebase)
        }
    }

    androidLibrary {
       namespace = "com.noricoffee.sharedLogic"
       compileSdk = libs.versions.android.compileSdk.get().toInt()
       minSdk = libs.versions.android.minSdk.get().toInt()

       compilerOptions {
           jvmTarget = JvmTarget.JVM_11
       }
       androidResources {
           enable = true
       }
       withHostTest {
           isIncludeAndroidResources = true
       }
    }

    sourceSets {
        commonMain.dependencies {
            // Phase 2.5 PR2: sharedLogic は Greeting / Platform 残骸 + Umbrella Reexport 役。
            // 各 shared モジュールを api 依存することで Swift から見える SharedLogic.framework に
            // 全公開シンボルを export する。PR3 で shared/framework に正式移送予定。
            api(projects.shared.core)
            api(projects.shared.domain)
            api(projects.shared.dataLocal)
            api(projects.shared.dataFirebase)
        }
    }
}

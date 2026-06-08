import org.gradle.api.artifacts.VersionCatalogsExtension
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

/**
 * KMP ライブラリ共通設定の Convention Plugin。
 *
 * - iOS（arm64 / simulatorArm64）+ Android（com.android.kotlin.multiplatform.library）ターゲット
 * - `-Xexpect-actual-classes` で expect/actual の Beta 警告を抑止
 * - Android 側 jvmTarget は 11
 *
 * SKIE / SQLDelight のような「特定モジュールでだけ要るプラグイン」はここで適用しない:
 * - SKIE: framework モジュール（iOS 向け Umbrella）でのみ
 * - SQLDelight: data-local モジュールでのみ
 *
 * バイナリ framework 定義（`baseName = "..."` / `isStatic = true` 等）もここには含めず、
 * framework モジュール側で個別に宣言する。
 *
 * 注: `jvmToolchain(17)` は **付けない**。開発機の JDK をそのまま使う運用。
 * toolchain を強制すると Gradle が JDK 17 のダウンロードを要求するため。
 */
plugins {
    id("org.jetbrains.kotlin.multiplatform")
    id("com.android.kotlin.multiplatform.library")
}

val libs = extensions.getByType<VersionCatalogsExtension>().named("libs")

kotlin {
    compilerOptions {
        freeCompilerArgs.add("-Xexpect-actual-classes")
    }

    iosArm64()
    iosSimulatorArm64()

    androidLibrary {
        // namespace は各モジュールの build.gradle.kts で個別に設定すること
        compileSdk = libs.findVersion("android-compileSdk").get().requiredVersion.toInt()
        minSdk = libs.findVersion("android-minSdk").get().requiredVersion.toInt()

        compilerOptions {
            jvmTarget = JvmTarget.JVM_11
        }
        withHostTest {
            isIncludeAndroidResources = true
        }
    }
}

import com.android.build.gradle.LibraryExtension
import org.gradle.api.artifacts.VersionCatalogsExtension
import org.gradle.api.JavaVersion

/**
 * AGP `com.android.library`（純粋な Android ライブラリ）用の Convention Plugin。
 *
 * KMP モジュールでは `kmp.library` 経由で `androidLibrary` DSL を使うため、現状このプラグインを
 * 適用する側はない。Phase 2.5（PR1）時点では「Android-only ライブラリが必要になった場合の
 * 受け皿」として枠だけ作っておく。
 *
 * compileSdk / minSdk / Java バージョンの 3 点だけを共通化し、namespace は適用側で設定する。
 */
plugins {
    id("com.android.library")
}

val libs = extensions.getByType<VersionCatalogsExtension>().named("libs")

extensions.configure<LibraryExtension> {
    compileSdk = libs.findVersion("android-compileSdk").get().requiredVersion.toInt()

    defaultConfig {
        minSdk = libs.findVersion("android-minSdk").get().requiredVersion.toInt()
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
}

plugins {
    `kotlin-dsl`
}

java {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}

dependencies {
    // 各 Convention Plugin スクリプト（src/main/kotlin/*.gradle.kts）が `plugins { id("...") }` で
    // 適用する Gradle プラグインの実装 JAR をクラスパスに載せるための classpath 依存。
    //
    // - kotlin-multiplatform / android.kotlin.multiplatform.library: KMP 共通設定
    // - android-gradle-plugin: 将来 com.android.library を使う android.library 用
    // - sqldelight-gradle-plugin: data-local モジュールが直接適用する想定（kmp.library では適用しない）
    // - skie-gradle-plugin: framework モジュールでだけ適用する想定（kmp.library では適用しない）
    //
    // 注: src/main/kotlin に置いた *.gradle.kts は `kotlin-dsl` プラグインが自動で
    //     plugin id を生成する（gradlePlugin { plugins.register(...) } は不要）。
    implementation(libs.kotlin.gradle.plugin)
    implementation(libs.android.gradle.plugin)
    implementation(libs.sqldelight.gradle.plugin)
    implementation(libs.skie.gradle.plugin)
}

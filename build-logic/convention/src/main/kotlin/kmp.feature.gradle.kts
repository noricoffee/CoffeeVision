/**
 * feature モジュール共通設定の Convention Plugin。
 *
 * - `kmp.library` を継承して KMP / Android の共通設定を取り込む
 * - feature が必ず必要な `shared/core` / `shared/domain` を `api` 依存で自動配線する
 *
 * feature モジュール（1 画面 = 1 モジュール）が新規追加されるたびに適用される。
 * 正確なモジュール一覧は `settings.gradle.kts` を真とする。
 */
plugins {
    id("kmp.library")
}

kotlin {
    sourceSets.getByName("commonMain").dependencies {
        api(project(":shared:core"))
        api(project(":shared:domain"))
    }
}

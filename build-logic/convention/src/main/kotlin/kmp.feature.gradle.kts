/**
 * feature モジュール共通設定の Convention Plugin。
 *
 * - `kmp.library` を継承して KMP / Android の共通設定を取り込む
 * - feature が必ず必要な `shared/core` / `shared/domain` を `api` 依存で自動配線する
 *
 * Phase 2.5（PR1）時点では feature モジュールはまだ存在せず、このプラグインを実際に
 * 適用する側はない。Phase 3 で `feature/visit-list` 等を作るときに使う想定。
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

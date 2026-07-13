---
name: xcodebuild-verification
description: xcodebuild によるビルド検証時のハマりどころ（Gradle 出力の見え方、destination 名、-list、シミュレータ選定）
metadata:
  type: project
---

## xcodebuild を `| tail -N` で絞ると Gradle Run Script フェーズの出力が見えなくなる（2026-07-06 確認）

`xcodebuild ... | tail -80` のように末尾だけ見ると、ビルド後半（Swift コンパイル〜リンク）しか映らず、序盤に実行される `./gradlew :shared:framework:embedAndSignAppleFrameworkForXcode`（`project.pbxproj` の Run Script フェーズ）のログが消えて「Gradle が本当に走ったか」を確認できない。**`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED` を使わずに Gradle 実行を裏取りしたいときは、出力をファイルへリダイレクト（`> build.log 2>&1`）してから `grep` する**（`tail` で絞らない）。差分検証なら `clean build` にすると Run Script も含め全フェーズが必ず再実行されるので確実。

## xcodebuild のシミュレータ destination 名は `xcrun simctl list devices available` で確認する（2026-07-07 確認）

環境によって「iPhone 16」等の型番が存在しないことがある（この環境では iPhone 17 系のみインストール済み）。`-destination 'platform=iOS Simulator,name=iPhone 16'` は `Unable to find a device matching...` で即失敗するので、事前に `DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcrun simctl list devices available | grep iPhone` で存在する名前を確認してから `-destination` を組み立てる。

## `xcodebuild -project ... -list` の出力は末尾までスクロールしないと `Schemes:` セクションが見えないことがある（2026-07-07 確認）

`| head -30` 等で先頭だけ見ると `Targets:` / `Build Configurations:` までしか映らず「共有スキームが無い」と誤認しがち（実際は package 解決ログが長く `Schemes:` セクションはさらに下）。`xcshareddata/xcschemes/*.xcscheme` の有無を先に `find` で確認するか、`-list` は全文（`tail` 併用）で見ること。ビルドは `-target` ではなく `-scheme`（+ 必要なら `-derivedDataPath`）を使う（`-derivedDataPath` 指定時は `-scheme` が必須で `-target` だと `error: The flag -scheme... is required` になる）。

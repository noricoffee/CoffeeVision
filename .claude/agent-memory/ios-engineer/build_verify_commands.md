---
name: build-verify-commands
description: iosApp のビルド検証に使う具体的なコマンド（DEVELOPER_DIR / scheme / destination）
metadata:
  type: project
---

このリポジトリでのビルド検証で実際に通ったコマンド。

```bash
cd /Users/noricoffee/dev/git/coffeevision
DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer xcodebuild \
  -project iosApp/iosApp.xcodeproj \
  -scheme "iosApp (Dummy Data)" \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -configuration Debug build
```

- `/Applications/Xcode-beta.app` のみが存在（安定版 Xcode.app は無い）。`xcode-select` の既定は Command Line Tools なので `DEVELOPER_DIR` を明示しないと `xcodebuild` 自体が失敗する
- ビルドログに `> Task :shared:framework:...` と `BUILD SUCCESSFUL` が出ていれば Gradle 経由の実ビルド（偽陽性ではない）。`OVERRIDE_KOTLIN_BUILD_IDE_SUPPORTED=YES` は付けない
- スキーム一覧: `xcodebuild -list -project iosApp/iosApp.xcodeproj` で確認可能（`iosApp` / `iosApp (Dummy Data)`）
- 成果物パス: `~/Library/Developer/Xcode/DerivedData/iosApp-<hash>/Build/Products/Debug-iphonesimulator/coffeevision.app`（bundle id: `com.noricoffee.coffeevision`）

[[sandbox-no-gui-simulator]] — この成果物をシミュレータにインストールして起動・screenshot までは撮れるが、タップ操作はできない。

## Debug 構成の実体コードは `coffeevision.app/coffeevision`（メイン実行ファイル）ではなく `coffeevision.app/coffeevision.debug.dylib` に入る（Xcode の `USE_DEBUG_DYLIB` 機能、2026-08-21 確認）

Debug ビルドのメイン実行ファイルは数十 KB のスタブで、アプリ本体の Swift コード（文字列リテラル含む）は同ディレクトリの `coffeevision.debug.dylib`（数十 MB）に入る。`#if DEBUG` の分岐や特定 View の文字列が実際にバイナリへ含まれたか `grep -a` / `strings` で裏取りするときは、**Debug 構成では `.debug.dylib` の方を見る**（メイン実行ファイルを見ると「文字列が見つからない」という誤った結論になる）。Release 構成にはこの dylib は存在せず、メイン実行ファイル（47MB 級）にすべて含まれる。UTF-8（日本語等）の文字列を探すときは `strings` ではなく `LC_ALL=en_US.UTF-8 grep -a -o "検索語" "$BIN"` を使う（`strings` は既定でマルチバイト文字を拾わないことがある）。

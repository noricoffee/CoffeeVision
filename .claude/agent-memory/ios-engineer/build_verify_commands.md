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

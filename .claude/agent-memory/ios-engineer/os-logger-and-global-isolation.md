---
name: os-logger-and-global-isolation
description: os.Logger 導入時の実地ノウハウ（ファイルスコープ logger の nonisolated 必須、autoclosure と self、simctl での実ログ確認手順）
metadata:
  type: project
---

`print` → `os.Logger` 置換（SL-8、2026-09-20）で実際に踏んだ点。

## ファイルスコープの `private let log = AppLog.logger(...)` は `nonisolated` が要る

`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` 下では**グローバル / ファイルスコープの `let` も MainActor 分離と推論される**。
`nonisolated final class`（`FirebaseRepositories/**`）や nonisolated な `Tool` 実装から参照すると
`main actor-isolated let 'log' cannot be accessed from outside of the actor` になる（nonisolated 側が
警告で済むケースと、エラーになるケースが混在する）。**`private nonisolated let log = AppLog.logger(category: "...")`**
と書けば全ファイルで統一できる（`Logger` は `Sendable` なので `@unchecked` は不要）。
ファクトリ側（`Utilities/AppLog.swift`）も `nonisolated enum AppLog` にしてある。

## `swiftc -typecheck` の単発検証は、このプロジェクトの分離ルールの代理にならない

上記の分離エラーは、`-swift-version 6 -default-isolation MainActor -enable-upcoming-feature NonisolatedNonsendingByDefault`
を手で付けた単発 `swiftc -typecheck` では**再現しなかった**（`SWIFT_APPROACHABLE_CONCURRENCY = YES` が
束ねる upcoming feature 群まで揃わないため）。分離まわりの可否は scratch でなく `xcodebuild` で確かめる。

## Logger の文字列補間は `@autoclosure` なのでクラス内では `self.` が要る

`log.info("adUnitID=\(adUnitID, privacy: .public)")` は
`reference to property 'adUnitID' in closure requires explicit use of 'self'` になる。`self.adUnitID` と書く。

## `Error` はそのまま補間できないので `String(describing: error)`

`print("\(error)")` と同じ情報量を保つならこれ。`localizedDescription` を使っていた箇所はそのまま `String` 補間でよい。

## simctl でログを実見する手順（`.info` / `.debug` は既定で出ない）

```bash
export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
UDID=$(xcrun simctl list devices available | grep -m1 'iPhone 17 Pro' | sed -E 's/.*\(([-0-9A-F]+)\).*/\1/')
xcrun simctl install $UDID <DerivedData>/Build/Products/Debug-iphonesimulator/coffeevision.app
xcrun simctl spawn $UDID log stream --level debug --style compact \
  --predicate 'subsystem == "com.noricoffee.coffeevision"' > /tmp/logstream.txt 2>&1 &
xcrun simctl launch $UDID com.noricoffee.coffeevision
```

`--level debug` を付けないと `.notice` / `.error` しか流れず「ログが出ていない」と誤認する。
**シミュレータでは `privacy: .private` の値がそのまま表示される**（uid が見えた）。
redaction の実証には実機 + デバッガ非アタッチの取得が要るので、目視確認は親経由でユーザーへ回す。

関連: [[swift6-migration-diagnostics]] / [[build_verify_commands]] / [[sandbox_no_gui_simulator]]

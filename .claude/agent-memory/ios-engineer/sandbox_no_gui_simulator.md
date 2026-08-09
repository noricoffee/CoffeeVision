---
name: sandbox-no-gui-simulator
description: このエージェント実行環境には GUI の Simulator.app が存在せず、タップ操作を自動化する手段がない
metadata:
  type: project
---

**この作業環境（サンドボックス）では iOS シミュレータへのタップ / スワイプ操作を自動化できない。**

確認した事実（2026-08-10）:

- `xcrun simctl` に tap/swipe/input を送るサブコマンドは存在しない（`simctl help` で確認済み。`io` は screenshot / video 録画のみ）
- `idb` / `idb_companion`（Facebook 製、`simctl` の入力操作を補う定番ツール）は未インストール
- `/Applications/Xcode-beta.app/Contents/Developer/Applications/Simulator.app` が存在しない。GUI 版 Simulator.app 自体がこの環境に無く、`open -a Simulator` も失敗する。そのため `osascript` / System Events 経由のクリック自動化も不可能（"Unable to find application" エラー）
- `xcrun simctl boot` でデバイスを起動し、`xcrun simctl install` / `launch` / `io screenshot` は正常に動く（バックエンドのみのヘッドレス実行）。**screenshot は撮れるが、その画面を操作して次の画面に進む手段がない**

**含意**: Firestore 上の同意状態（`users/{uid}` ドキュメント）に依存する初回起動フロー（データ共有同意オンボーディングシート）のような、タップでスキップしないと先に進めない画面がある機能では、それより奥の画面（例: マップタブ本体）をシミュレータで実機的に確認することがこの環境ではできない。ビルド成功 + 起動直後の 1 枚の screenshot までが自動検証の限界。

**対応方針**: この制約にぶつかったら、画面遷移の妥当性はコード読解（View 修飾子チェーンの追跡: `overlay` vs `safeAreaInset` の safe area 伝播の違いなど）で最大限詰めた上で、レポートの「動作確認」欄に「シミュレータでの目視確認が必要」と明記し、親経由でユーザーに実機 / 手元の Xcode で確認してもらう。無理に自動化を試み続けない（`simctl ui` / `simctl push` 等を試したが該当なし）。

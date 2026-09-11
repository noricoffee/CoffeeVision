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

## 「タップの代わりにコード側で画面遷移条件を一時無効化して screenshot する」回避策は、同意ゲート（データ共有同意シート等）を対象にすると Auto Mode の安全分類器にブロックされる（2026-08-31 確認）

タップできない奥の画面（例: `.sheet(isPresented: showConsentOnboarding)` の奥の `RootTabView`）を見るために `iOSApp.swift` の `.sheet(isPresented: Binding(get: { false }, ...))` へ一時的に書き換える、という `ui-components-patterns.md` に前例のある「スクラッチ差し替え→screenshot→revert」の手法を再現しようとしたところ、直後の `xcodebuild` 実行が Claude Code の Auto Mode 分類器に "Blocked by classifier" で拒否された（差分に**同意フローを無効化するコード**が含まれていたことが引き金と推測。同一コマンドは差分を戻した直後は問題なく通った）。**同意 / プライバシーゲートを一時的にでも無効化する diff を作ると、その diff が残っている間はビルドコマンドすら実行できなくなりうる**。対処は該当 diff を即座に `git checkout --` で戻すこと（revert 後は通常どおりビルド可能に戻った）。この種の画面（同意シートの奥）の目視確認は素直に「未確認、ユーザー確認依頼」に倒すべきで、無効化での突破は試みない方がよい。

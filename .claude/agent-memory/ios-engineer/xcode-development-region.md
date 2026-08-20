---
name: xcode-development-region
description: developmentRegion / CFBundleLocalizations がアプリの実効ロケール（DatePicker 等システム書式）に効く仕組みと確認コマンド
metadata:
  type: project
---

## `project.pbxproj` の `developmentRegion` は `.lproj` が無くても実効ロケールに効く（2026-08-06 確認）

`GENERATE_INFOPLIST_FILE = YES` の場合、ビルド成果物の `Info.plist` の `CFBundleDevelopmentRegion` は明示キーが無くても **プロジェクトルートオブジェクトの `developmentRegion` 属性**（`project.pbxproj` 冒頭付近、`knownRegions` の直前）から自動転記される。`iosApp` は SwiftUI 全画面で `String(localized:)` の**キー自体が日本語**（`.xcstrings` / `.lproj` 未整備）方針だが、`developmentRegion = en` のままだと `CFBundleLocalizations` も未設定になり、**端末が `ja-JP` でもシステムが「このアプリが対応する言語は英語だけ」と判断してアプリの実効言語を英語にフォールバックさせる**。文字列リテラルは日本語のまま表示されるが、`DatePicker` 等 **OS 側が自前で描画する書式（日付・数値）だけ英語表記**になる（`Aug 6, 2026` 等）。

- 修正: `developmentRegion = ja` + `knownRegions = (ja, Base)`（pbxproj）+ `Info.plist` に直接 `CFBundleLocalizations = [ja]` を追加（`.lproj` 新設は不要、既存の `CFBundleDisplayName` 等の生キー方針に合わせて `Info.plist` に直書き）
- 検証は `plutil -extract CFBundleDevelopmentRegion raw` / `plutil -extract CFBundleLocalizations xml1 -o -` をビルド成果物の `.app/Info.plist` に対して実行（ビルド成功だけでは実効ロケールの証明にならない）。`actool` の呼び出しログにも `--development-region ja` が伝播しているか `grep` で裏取りできる
- ビルド成果物の `.app` 名は `Info.plist` の設定と無関係に `coffeevision.app`（`PRODUCT_NAME` 由来、`CFBundleDisplayName = CoffeeVision` とは別）。DerivedData 探索時に `iosApp.app` で探すと見つからない

---
name: vm-feature-removal-checklist
description: combine 駆動 ViewModel から特定の派生フィルタ機能まるごとを削除するときのチェックリスト（MapViewModel の「好みで絞り込む」削除で実施）
metadata:
  type: project
---

## 何をしたか

MapViewModel から「好みで絞り込む」手動フィルタ（`tasteMatchedPlaceIds` / `activeTastingMin` / `activeTastingMax` / `applyTasteFilter()` / `onTasteProfileChanged()`）をまるごと削除した。
似た名前の「好み一致」自動推薦（`recommendedCafes` / `cafeRecommendationProvider`）とは別機能で、削除対象と紛らわしいので事前確認が重要だった。

## チェックした場所（同種の削除タスクで再利用できる手順）

1. `UIState` のプロパティ + KDoc
2. 専用の private ヘルパー関数（`applyXxxFilter()`）
3. public トリガー関数（`onXxxChanged()`）
4. `init {}` の `combine {}.collect {}` 内での関連フィールド代入・関数呼び出し
   - combine の変換ラムダが `Pair<Triple, allRecords>` のように「削除対象専用のために」余分な値を持ち回している場合、削除に合わせて `Triple` 直返しに単純化できないか確認する（今回は `to allRecords` の tuple 化を削除して素の `Triple` destructuring に戻した）
5. `private var latestXxx` のようなキャッシュフィールド（他のフィルタと無関係なら丸ごと削除）
6. 削除後に不要になった import（`TastingScores` 等）。**ドメインモジュール側の import 文は残るファイルが他にもあるので、削除対象ファイル内でのみ未使用か個別に grep 確認する**
7. クラス外のコメント（「タグ選択・テイストフィルタが変化した際」等、削除対象に触れる散在コメント）も grep で拾う

## iOS 側の依存確認

`grep -rn "<削除する public API 名>" iosApp/` で Swift 側の依存箇所を洗い出す。今回は
`iosApp/iosApp/Features/Map/TasteMapFilterSheet.swift`（画面全体がこの機能専用）、
`MapTabView.swift`、`MapViewModelBridge.swift` の 3 ファイルに広く依存があった。
KMP 側だけ消しても iOS 側はビルドが壊れるので、必ず親への依頼にファイル一覧を明記する。

## 検証で踏んだ手順

- `compileCommonMainKotlinMetadata` → `compileKotlinIosSimulatorArm64` → `compileTestKotlinIosSimulatorArm64` + `testAndroidHostTest` の順で通した
- `assembleSharedLogicXCFramework` は sandbox で link フェーズ（xcrun xcodebuild 不在）のみ失敗するのが既知の制約。
  `compileKotlinIosSimulatorArm64` / `compileKotlinIosArm64`（framework モジュール自体）が成功すれば
  「compile レベルでは API 削除が全モジュールに波及して壊れていない」ことの十分な確認になる
- 削除後の残存参照確認は `grep -rln "<削除対象シンボル>" shared/` で行う。`shared/*/build/**` 配下は
  古いビルド成果物（.h / .apinotes 等）がヒットするのは無害（ソースではない）

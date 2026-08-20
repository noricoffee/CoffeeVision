---
name: favoritesignals-symmetric-axis-addition
description: FavoriteSignals / PreferenceMatchAxis に既存軸（bestRoastLevel 等）と対称な新カテゴリ軸（例 bestProcessing）を追加するときの一式チェックリスト
metadata:
  type: project
---

`FavoriteSignals` の `bestBrewMethod` / `bestOrigin` / `bestRoastLevel` と同型の新軸（例: `bestProcessing`）を
追加するタスク（2026-07-20 精製方法軸追加）で洗い出した変更点一式。既存軸は `selectBestCategory`
（収縮平均 + n連動zゲート + δ AND）を再利用できるので新ロジックは不要、配線漏れの方が事故りやすい。

## 変更が必要な箇所（全 4 レイヤー）

1. **モデル**: `CoffeeStats.kt` の `FavoriteSignals` にフィールド追加（`= null` デフォルトで加算的）
   + `RecommendedCafe.kt` の `PreferenceMatchAxis` enum に値追加
2. **集計**: `BuildCoffeeStatsUseCase.buildFavoriteSignals` に
   `selectBestCategory(candidateGroups = ratedRecords.filter{...!=null}.groupBy{...!!.name}, ...)` を追加
   （origin だけ専用の `buildBestOrigin` を使う。roastLevel/brewMethod/processing は共通 `selectBestCategory` でOK）
3. **カフェ一致**: `ObserveTasteMatchedCafesUseCase`
   - `buildRecommendedCafes` の空ガード条件（全軸 null チェック）に新フィールド追加
   - `buildRecommendedCafeOrNull` に新軸の match ブロック追加（他軸と同型: `highRatedRecords.filter{...} → buildBestMatch(...)`）
4. **UI 側の "hasAnySignal" 系ヘルパ見落としがち**: `shared/feature/analysis/AnalysisViewModel.kt` に
   `FavoriteSignals.hasAnySignal()`（private top-level 拡張関数）があり、readiness 判定で使われる。
   新軸を足し忘れると「新軸だけ信号があるのに `hasAnySignal=false` → UI が『データ不足』表示のまま」になる。
   `grep -rn "bestBrewMethod\|bestRoastLevel\|bestOrigin"` で同型の網羅チェックを横断的に探すこと。

## テスト

- `BuildCoffeeStatsUseCaseTest`: 既存 `favoriteSignals_bestRoastLevel_nullRoastIsExcluded` と対称の
  `favoriteSignals_bestProcessing_..._symmetricWithRoastLevel` を追加（同じ z ゲート計算式をコメントに転記すればOK）
- `ObserveTasteMatchedCafesUseCaseTest`: 既存 `roastLevelAxis_detected_...` と対称のテストを追加
- 空リスト系テスト（`emptyList_returns...` / `favoriteSignals_allRatedZero_returnsAllNull`）に新軸の
  `assertNull` を追記し忘れないこと（既存軸と横並びで書かれているのでコピペで足せる）

## 検証コマンド

`:shared:domain:compileKotlinIosSimulatorArm64` / `:shared:domain:testAndroidHostTest` /
`:shared:feature:analysis:compileKotlinIosSimulatorArm64`（hasAnySignal を触るなら）/
`:shared:framework:assembleSharedLogicXCFramework`（sandbox は link だけ `xcrun xcodebuild` 不在で失敗、
compile 系全通過で OK）

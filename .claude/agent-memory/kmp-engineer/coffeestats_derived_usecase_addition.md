---
name: coffeestats-derived-usecase-addition
description: BeanProfile 突合系の新しい派生集計（12-C PreferredBeanTraits, 15-E-3 SuggestUnexploredBeans 相当）を CoffeeStats に足すときの実地パターン
metadata:
  type: project
---

`FavoriteSignals` + `BeanProfileRepository.getAll()` を突合して `CoffeeStats` に新しい派生フィールドを足す
タスク（12-C `PreferredBeanTraits` に続き 15-E-3 `UnexploredBeanSuggestions` で 2 例目）で効いた手順。

## 配置パターン（迷ったら踏襲する）

1. 出力モデルは `shared/domain/.../model/<Foo>.kt`（`domain.model` パッケージ、`BeanProfile` は `domain` パッケージなので import が必要）
2. 純粋関数の UseCase は `shared/domain/.../usecase/<FooUseCase>.kt`。IO なし・`operator fun invoke` 1 本
3. **`CoffeeStats` に直接フィールドとして生やし、`BuildCoffeeStatsUseCase.invoke()` 内で
   `if (beanProfiles.isNotEmpty()) FooUseCase()(...) else null/emptyList()` の形で計算する**
   （`ObserveCoffeeStatsUseCase` や `AnalysisViewModel` を経由する追加配線は不要。
   `beanProfileRepository` は既に `ObserveCoffeeStatsUseCase` → `BuildCoffeeStatsUseCase(records, beanProfiles)`
   まで通っているので、`records`（生レコード）も `beanProfiles` も `BuildCoffeeStatsUseCase.invoke()` の
   引数として既に揃っている）
4. `AnalysisViewModel.UIState` への追加フィールドは**不要**。`UIState.stats`（`CoffeeStats`）経由で
   iOS 側から直接参照できるため、`readiness`（UI 専用メタ情報だから意図的に `CoffeeStats` の外に出している）
   とは事情が違う。`CoffeeStats` はもともと「① 統計 UI の入力 ② 階層3 LLM への唯一の入力」を兼ねる設計なので、
   ドメイン実質のある派生値は `CoffeeStats` の中に足すのが一貫する

## 既存 UseCase の再利用

- origin のファジーマッチ・スコアリングが必要なら自前で書かず `BeanProfileMatchUseCase(profiles, origin, processing)`
  を呼ぶ（trim/lowercase 完全一致+2・部分一致+1 のロジックとスコア降順ソートを再利用できる）
- `BeanProfile` に無いフィールド（`roastLevel` / `brewMethod` 相当）は合致条件に使えない。
  `FavoriteSignals.bestOrigin` 以外の軸は無視してよい（12-C も同じ理由で origin 主軸）

## 検証

- `CoffeeStats(` の直接コンストラクタ呼び出し箇所を事前に `grep` しておく
  （`BuildCoffeeStatsUseCase.kt` 以外に無ければ、新フィールドをデフォルト引数無しで足しても他の呼び出し元を壊さない）
- 検証コマンドは変更なし: `:shared:domain:compileKotlinIosSimulatorArm64` /
  `:shared:domain:testAndroidHostTest` / `:shared:feature:analysis:compileKotlinIosSimulatorArm64` /
  `:shared:framework:assembleSharedLogicXCFramework`（sandbox では link 系タスクが
  `xcrun xcodebuild -version` failure で止まる。compile 系が全 target 通れば十分、link は親が
  `DEVELOPER_DIR` 付きで再検証）

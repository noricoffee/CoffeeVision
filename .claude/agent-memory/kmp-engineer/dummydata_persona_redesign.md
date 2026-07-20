---
name: dummydata-persona-redesign
description: DummyCoffeeData を「単一の強い人格」中心に再設計するときの統計設計の勘所（好み信号を確実に立てつつ他グループを汚染しない）
metadata:
  type: project
---

`DummyCoffeeData`（`shared/core/src/commonMain/kotlin/com/noricoffee/dev/DummyCoffeeData.kt`）を
人格中心（例: ブラジル × City × ネルドリップ × ナチュラル）に再設計するとき、
`BuildCoffeeStatsUseCase` の収縮 + n連動zゲート + δ AND を安全に通すための設計手順。

## 設計手順（実測して確定させる。手計算だけで確信を持たない）

1. **核クラスタは全属性を同一レコードに同居させる**: 4 軸を別々のレコード群で作ると各軸の n が割れて
   z ゲートを通りにくい。「1 レコード = 4 軸すべての証拠」にすると n=6 程度で楽に通る
   （z ゲート閾値 `CATEGORY_Z * globalStd / sqrt(n)` は n が大きいほど緩くなる）
2. **他グループ（二番手・その他）は核クラスタの属性値を使わない**: 例えば「その他」に
   `roastLevel=City` を混ぜると、City グループの平均が薄まって z/δ ゲートを危険にさらす。
   核クラスタの 4 属性値（産地・焙煎度・抽出・精製）は他レコードで使い回さない
3. **「その他」群の評価はすべて globalMean 以下にする**: z/δ ゲートは「正方向のみ」なので、
   その他群だけで構成される任意の部分グループ（例: 別軸の重複ラベル）が誤って argmax になる心配がなくなる
4. **手計算の検算は実際にテストで printline して確認する**: 母標準偏差込みの手計算はミスりやすい。
   一時的に `println("DEBUG ...")` を仕込んで `./gradlew :module:testAndroidHostTest --tests "..."`
   を `-i` 付きで実行し、実測値（label/count/mean）を確認してからコミット、確認後は printline を消す

## 固定 ID を維持する制約

`ids`（`dummy-0001`..`dummy-0030`）と `clearDummyData`（`AppContainer.kt` 側、`ids` を参照するだけ）は
不変。`rawData` の中身（30 件）だけを差し替えれば ID 契約は壊れない
（`CoffeeRepositoryImplTest` 等が `DummyCoffeeData.ids.first()` を参照しているため件数・ID 形式の変更は不可）。

## 検証

新設した `shared/core/src/commonTest` に人格固定テストを置く場合、`build.gradle.kts` の
`commonTest.dependencies` に `kotlinx.datetime` を明示追加しなくても、`commonMain` 側で
`implementation(libs.kotlinx.datetime)` を宣言済みなら commonTest から普通に import できる
（同一モジュールの test source set は main の association compilation で implementation 依存を継承する。
`commontest_first_setup_in_feature_module.md` の注意点は「別モジュールがそのモデル型を使う場合」の話で、
同一モジュール内では該当しない）。

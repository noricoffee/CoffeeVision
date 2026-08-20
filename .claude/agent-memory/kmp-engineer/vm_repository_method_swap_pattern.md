---
name: vm-repository-method-swap-pattern
description: ViewModel 内で呼び出す Repository メソッドを差し替える修正（例 searchText→searchNearby）をするときの手順とテスト更新の型
metadata:
  type: project
---

VM のロジックが呼ぶ Repository メソッドをオーバーロード違いや別メソッドに差し替える修正（例: フェーズ17-B、`MapViewModel.onPoiTapped` を `CafeRepository.searchText(query, locationBias)` → `searchNearby(lat, lng, radius)` に変更）をするときの型。

**手順**:
1. VM 本体の呼び出し変更 + KDoc の状態遷移コメント更新（旧メソッド名が複数箇所に残りがち: クラス doc の箇条書き、コンストラクタ `@param`、関数 doc 本文の 3 箇所は grep で洗う）
2. 呼び出さなくなった型の import（例 `LocationBias`）が他で使われていないか確認して削除
3. 対応する commonTest の Fake 実装: スタブ用フィールド名（`lastSearchTextQuery` 等）と結果/エラー用フィールド名（`searchTextResult`/`searchTextError`）を新メソッド名に合わせてリネームし、旧メソッドの override 実装は「呼ばれない前提の空実装」に簡略化する（他 override との整合を保ちつつ削除しない — インターフェース契約は変わらないため）
4. 「引数が正しく渡っているか」を検証するテスト（例 `passesLocationBiasToRepository`）は検証対象の引数が変わるので `assertEquals` の期待値・フィールド名ごと書き直す。テスト名も新メソッド名に合わせて rename する
5. 同一 Repository インターフェースを使う**他の feature モジュールの VM**（例 `CafeSearchViewModel` が同じ `searchText(query, locationBias)` を別目的で正当に使用）を grep で確認し、誤って壊していないか・コメントが古い記述のまま残っていないかをチェックする。ドキュメントコメントに「このオーバーロードは POI タップ専用」のような排他的記述があると、別用途に転用されたときに嘘になるので要注意（該当箇所が自分のスコープ外モジュールなら親に報告するだけで留める）

**検証コマンド**: `compileCommonMainKotlinMetadata` → `compileTestKotlinIosSimulatorArm64`（テストのシグネチャ検証）→ `testAndroidHostTest`（実行検証）の 3 点セットで足りる。VM の公開シグネチャ自体が変わらない限り `assembleSharedLogicXCFramework` は不要。

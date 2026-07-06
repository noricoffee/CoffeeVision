---
name: coffee-editor-multimode-pattern
description: CoffeeEditorViewModel に 3 つ目以降の Mode（Duplicate 等）や補助サジェスト機能を足すときの実地パターン・commonTest のハマりどころ
metadata:
  type: project
---

## Mode 追加（sealed interface に 3 つ目の分岐を足す）

`CoffeeEditorViewModel.Mode`（Create / Edit）に `Duplicate(sourceCoffeeId)` を追加した実例（フェーズ 15-B）。
`onAppear` の `when（mode）` に分岐を足すだけでなく、以下 2 箇所も見落としやすい:

- `buildRecord` の id/createdAt 採番ロジック（`when (mode)`）— 新モードが「保存時は新規採番」なら
  `is Mode.Create, is Mode.Duplicate ->` のように既存の Create 分岐にまとめて追加する
- `buildCafe` のフォールバック分岐（`when (mode)`）— 「初期レコードの cafe を引き継ぐ」という点で
  Edit と同じ挙動にしたいなら `is Mode.Edit, is Mode.Duplicate ->` にまとめる
- `currentInitialRecord`（private var）は「id/createdAt 引き継ぎ用」と「cafe 引き継ぎ用」の 2 つの目的で
  使われている（Edit は両方、新モードは cafe 目的だけ使うことがある）。役割を混同しないようコメントを残す

## commonTest: ネストした private class から外側の private fun は呼べない

`class Foo { private class FakeBar : Bar { override fun x() = outerHelper() } }` は
`Outer class of non-inner class cannot be used as receiver` でコンパイルエラーになる
（`compileCommonMainKotlinMetadata` では検出されず `compileTestKotlinIosSimulatorArm64` で顕在化した）。
テスト用フェイクの nested class 内で外側クラスの private ヘルパを使いたい場合は、
ヘルパの中身をそのまま inline するか、fake class の外（同ファイルのトップレベル private fun）に出す。

## 現在地サジェスト系の状態設計（要件 2-8 相当）

- 「サジェスト表示」「カフェ選択でクリア」を同じ ViewModel に足すときは、選択アクション
  （`onPlacesCafeSelected` 等）の中で `suggestedCafes = emptyList()` と進行中の Nearby Job の cancel を
  まとめてやると、"サジェスト経由・検索経由問わず選択で消える" 系の要件を 1 箇所で満たせる
- Nearby 検索の失敗を無音にする場合、`catch (e: Exception) { /* 何もしない */ }` で良い
  （`UIState.error` を触らない）。ただし `CancellationException` は先に catch して rethrow すること

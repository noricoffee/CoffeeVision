---
name: observation-task-structured-concurrency
description: ViewModelBridge の observationTask（非構造化 Task）を View の .task が所有する構造化 Task へ移すときの実装パターン（B-11）
metadata:
  type: project
---

## 背景

全 8 本の `*ViewModelBridge`（`Features/*/*ViewModelBridge.swift`）は `private var observationTask: Task<Void, Never>?` を自前で保持し `Task { for await state in kotlin.state { ... } }` を回していた。[[task-closure-lifetime-sentinel]] で実測した通り、非構造化 `Task` は参照を手放しても止まらず、`CafeSearch` / `CafeDetail` で実際にリークしていた。2026-09-20 に全 8 本を「ブリッジは `Task` を保持しない」設計へ移した。

## 変換パターン（基本形）

```swift
// Before
private var observationTask: Task<Void, Never>?
func onAppear(...) {
    kotlin.onAppear(...)
    observationTask?.cancel()
    observationTask = Task { [weak self] in
        for await state in kotlin.state {
            guard let self else { break }
            self.apply(state)
        }
    }
}
func onDisappear() { observationTask?.cancel(); observationTask = nil }
func cancel() { observationTask?.cancel(); observationTask = nil }  // AppState 用

// After
func observe(...) async {
    kotlin.onAppear(...)
    for await state in kotlin.state {
        apply(state)
    }
}
```

View 側は `.onAppear { viewModel.onAppear(...) }` + `.onDisappear { viewModel.onDisappear() }` の対を `.task { await viewModel.observe(...) }` 1 本に統一する。`weak self` キャプチャは不要になる（`Task` 自体を View の構造化スコープが所有するため、View 消滅で自動キャンセルされる。ブリッジが `self` を握り続けるリスクが構造的に消える）。

## 例外 1: `.task` 内に onAppear 相当の後に同期処理が挟まる場合（`CoffeeEditorViewModelBridge`）

`CoffeeEditorView` は `kotlin.onAppear` 相当の呼び出し直後に「カフェ pre-fill」「現在地サジェスト」を同期的に挟んでから観測へ入る必要がある。`observe()` 自体は `kotlin.state` が完結しない限り**呼び出し元をブロックしたまま返らない**ため、1 メソッドに畳むとその後続処理が実行されなくなる。この場合だけ 2 メソッドに分割する:

```swift
func onAppear(mode: ..., userId: String) { kotlin.onAppear(mode: mode, userId: userId) }  // 同期のみ
func observe() async { for await state in kotlin.state { apply(state) } }                  // 非同期・ループのみ
```

View 側は `.task { viewModel.onAppear(...); /* 中間処理 */; await viewModel.observe() }` と 1 つの `.task` 内で順に呼ぶ（`observe()` を先に `await` すると後続が実行されないので必ず最後に置く）。

同様に、Kotlin 側に `onDisappear()`（`loadJob?.cancel()` 等、observation とは無関係な個別 Job のキャンセル）のような**業務ロジックを持つ**メソッドがある場合は、それだけは残す（`func onDisappear() { kotlin.onDisappear() }`。Task 管理コードを一切含まないなら削除対象ではない）。Kotlin 側の `clear()`（`viewModelScope.cancel()`）が親スコープごと畳むため `onDisappear()` の個別キャンセルは通常 `deinit` の `clear()` と機能的に重複するが、`clear()` を呼ばずに `onDisappear()` だけ呼ぶ経路（View 消滅 ≠ 即座に deinit）が残っている場合は削除しない。

## 例外 2: 1 画面に複数の `.task` が要る場合（`for await` が別の無限ループと衝突する）

`MapTabView` は既存の `.task { await setupLocation(bridge:) }` の中に `for await location in locationStream()`（無限ループ）を持っていた。同じ `.task` の中で `await bridge.observe()` を後ろに続けても**絶対に実行されない**（先行する無限ループが return しないため）。**`.task` 修飾子は同一 View に複数付けられ、それぞれ独立した構造化 `Task` として並行に走り、View 消滅で両方ともキャンセルされる**。これを利用して観測ごとに `.task` を分けるのが正しい解法:

```swift
.task { await bridge.observe() }
.task { await searchController.setupAndObserve { appState.container.makeCafeSearchViewModel() } }
.task { await setupLocation(bridge: bridge) }
```

## 例外 3: View ではない `@Observable` コントローラが長寿命ブリッジを保持する場合（`MapSearchController.searchBridge`）

`MapSearchController`（View ではない）は `CafeSearchViewModelBridge` を 1 度だけ生成して以後使い回す（`nil` に戻す経路が無い）。ここに Task を持たせず、**View の `.task` から呼ぶ 1 本の async メソッドに「生成（冪等）+ observe」を両方詰める**ことで解決する:

```swift
// MapSearchController
func setupAndObserve(makeViewModel: () -> CafeSearchViewModel) async {
    if searchBridge == nil { searchBridge = CafeSearchViewModelBridge(kotlin: makeViewModel()) }
    await searchBridge?.observe()
}
```

`MapTabView` の `.task` がこれを呼ぶ。この `.task` が再実行される（View が再表示される）たびに `observe()` が同じ既存ブリッジに対して再購読されるため、**副次効果として「長寿命ブリッジに再購読の口が無い」問題も同時に解消される**（従来は `init` 時 1 回きりで再購読手段が無かった）。

## push 画面でブリッジ生成自体を `.task` に含める場合（`CafeDetailView`）

`CafeDetailViewModelBridge` は `.onAppear` でブリッジを生成し `init` 内で観測を開始していた（`init` 内 `startObservation()`）。移行後は生成と `observe()` 呼び出しを**同一の `.task`** にまとめる（`.onAppear` で先に生成 → 別の `.task` で observe、という 2 段に分けると発火順序がタイミング依存になり事故る）:

```swift
.task {
    let currentBridge: CafeDetailViewModelBridge
    if let bridge { currentBridge = bridge } else {
        guard let uid = appState.uid else { return }
        currentBridge = CafeDetailViewModelBridge(viewModel: ...)
        bridge = currentBridge
    }
    await currentBridge.observe()
}
```

## `AppState.resetAndRebootstrap()` 側の変化

タブ常駐ブリッジ（`coffeeListBridge` / `mapBridge` / `accountBridge` / `analysisBridge`）を `nil` に戻す前に呼んでいた `onDisappear()` / `cancel()` の手動キャンセルは、この移行後は不要。`AppRootView`（`iOSApp.swift`）が `appState.coffeeListBridge != nil && appState.mapBridge != nil && appState.accountBridge != nil` を条件に `RootTabView` ⇄ `loadingView` を `if/else` で切り替えており、条件が false になった瞬間 `RootTabView` 配下の全 `.task`（= 全 observation）が SwiftUI によって自動キャンセルされる。**ここを消してよいかは実際にこの `if/else` 条件式を読んで確認すること**（`analysisBridge` は条件式に入っていないが、`RootTabView` 配下の Tab コンテンツとして同じ subtree に含まれるため道連れで畳まれる）。

## 確認済みの副次効果

`CafeDetailView` / `CafeSearchView` は旧実装だと `init` 時 1 回しか観測を開始せず、再表示時に張り直す経路が無かった（[[task-closure-lifetime-sentinel]] 記載の凍結バグの温床）。`.task` 化により、View が一度消えて再び現れれば `.task` が自動的に再実行され観測が張り直されるため、この種のバグが構造的に解消される。

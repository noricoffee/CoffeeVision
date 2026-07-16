---
name: tab-resident-vm-onappear-idempotency
description: タブ常駐 VM（無引数 onAppear）で再購読を防ぐガード + 同値 Flow emit での重い副作用スキップのテスト手法
metadata:
  type: project
---

## 症状 → 実装パターン（2026-07-16、AnalysisViewModel）

`onAppear()` が呼ばれるたびに `observeJob?.cancel()` → 再購読すると、VM がタブ常駐
（`AppState` に 1 つだけ保持されアプリ生存期間中ずっと生きている）場合、タブ再表示のたびに
Flow が現在値を再 emit し、collect 内の重い副作用（Foundation Models 要約生成など）が
毎回再実行されてしまう。

**修正パターンは 2 点セット**:
1. `onAppear()` の冒頭で `if (observeJob?.isActive == true) return`（cancel せず no-op）。
   購読は一度張れば十分で、タブ非表示中も Kotlin 側の collect は止まらないため記録変更は
   引き続き Flow 経由で反映される。
2. collect 内で「直前に処理した値と構造的に同じ（data class の `==`）」ケースをガードし、
   重い副作用だけスキップする（stats/state 自体の更新はそのまま行ってよい）。
   SQLDelight の query invalidation で同値が再 emit されるケースの保険にもなる。

**この 2 点セットが必要かどうかの見分け方**: `onAppear` が引数なし（コンストラクタで
userId 等が確定済み）で VM がタブ常駐なら適用対象。`CoffeeListViewModel.onAppear(userId)` /
`CoffeeDetailViewModel.onAppear(coffeeId, userId)` / `CoffeeEditorViewModel.onAppear(mode, userId)`
のように引数で対象が変わる画面単位 VM は cancel-and-relaunch が正しい（対象が変われば
再購読が必須なため、同型に見えても直さない）。

## テストで「同値 emit では再生成しない」を再現する方法

Flow は `flow { emit(a); emit(b) }` のように同一コルーチン内で連続 emit すると、
2 回目の collect 本体が走るより前に 1 回目の collect 内で `launch` した Job がまだ
「スケジュールされただけ」で開始していない（`StandardTestDispatcher` は launch 即実行しない）。
このため 2 回目の collect で前回の Job を `cancel()` すると、まだ実行前の Job がキャンセルされ
中身の副作用（summarize 呼び出し等）が **1 回も走らない**。

「異なる値なら副作用が都度走る」ことを検証したいテストでは、fake Flow の emit 間に
`delay(1)` を挟み、`testScheduler` の仮想時間経過で前段の Job を完走させてから次の emit を
行うこと。同値 emit のケース（再生成されないことの検証）は delay 不要（むしろ delay を
入れると意図せず前段が完走してしまい、通常の cancel-and-relaunch と区別できなくなる）。

## 関連

`docs/architecture.md` / `docs/coding-conventions.md` の Job 再起動パターンの正本には
「タブ常駐 VM は再購読しない」までは明記されていない（実装コンベンション寄り）。

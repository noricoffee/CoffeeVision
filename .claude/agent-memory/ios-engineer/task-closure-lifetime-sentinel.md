---
name: task-closure-lifetime-sentinel
description: Task { } クロージャが解放されたか（残留 Task の有無）を実機/シミュレータで確かめる番兵オブジェクトの組み方
metadata:
  type: project
---

## 番兵パターン（B-11、2026-09-20）

「`for await` で `StateFlow` を回し続ける `Task` が、外側のオブジェクトの `deinit` 後にどうなるか（抜けて解放されるか、停まったまま残るか）」はログだけでは切り分けにくい。**「ループを抜けたログが出ない」は「まだ emit が来ていない」とも「本当に残っている」とも解釈できるため**。

切り分けには、`Task { }` のクロージャに**強参照でキャプチャさせる番兵クラス**を仕込む。

```swift
private final class ObservationSentinel {
    let bridgeId: Int
    init(bridgeId: Int) { self.bridgeId = bridgeId; print("[TAG] init \(bridgeId)") }
    deinit { print("[TAG] deinit \(bridgeId)") }
}

private func startObservation() {
    let flow = kotlin.state
    let sentinel = ObservationSentinel(bridgeId: instanceId)  // ローカル変数として保持
    observationTask = Task { [weak self] in
        print("[TAG] loop entered \(sentinel.bridgeId)")  // sentinel を参照して強制的に強参照キャプチャさせる
        for await state in flow {
            guard let self else { break }
            self.apply(state)
        }
        print("[TAG] loop exited \(sentinel.bridgeId)")
    }
}
```

- `sentinel` は `Task` のクロージャ内で参照して初めて捕捉される（Swift のクロージャは参照した変数だけをキャプチャする。存在するだけの変数は捕捉されない）
- **`sentinel` の `deinit` ログが出た = クロージャごと解放された（Task は残っていない）**。出ない = クロージャがまだどこかに生きている（Task が停まったまま残っている）
- 外側オブジェクトの `deinit` ログと組み合わせて時系列を見る: 「外側 deinit → (即 or emit 後に) sentinel deinit」なら正常に畳まれている。「外側 deinit だけ出て sentinel deinit が出ない」ならリーク

この技法は SKIE の `AsyncSequence` 化された `Flow` に限らず、**任意の「`Task` が生きているかどうか」を外部から観測したいケース**に転用できる（`weak self` だけでは self 以外の変数の生死は分からないため）。

## `deinit` から `observationTask?.cancel()` を足す実験（2026-09-20）

上記番兵で「Task が残る」ことを確認した後、`isolated deinit` に `observationTask?.cancel()` を追加して SKIE の `SkieSwiftFlow`（`for await` の対象）がキャンセルに応答するかを実測する側の変更。

- 呼ぶ順序は **`observationTask?.cancel()` が先、`kotlin.clear()` が後**（消費側を止めてから生産側を畳む）
- `Task.cancel()` はロックを取り得るため、**呼び出し元がロックを保持していないか事前確認**する（`OSAllocatedUnfairLock` 等を持つブリッジでは deinit 内で呼ぶ位置に注意）。`CafeSearchViewModelBridge` はロックを持たないクラスだったため今回は無条件で追加できた
- キャンセルが `for await` ループを実際に抜けさせるかどうかは Swift の協調的キャンセル仕様（`AsyncIteratorProtocol` はキャンセル応答を **should** としているだけで必須ではない）次第で、**コードを読むだけでは分からず実機ログでしか判定できない**（番兵の `deinit` ログの有無で判定する）

## 構造化並行性移行後（`observe() async` 版、2026-09-20）

[[observation-task-structured-concurrency]] で `observationTask`（非構造化 `Task`）を廃し `observe() async` を View の `.task` に直接委ねる形へ移した後の再計測では、番兵を **`Task { }` クロージャではなく `observe()` 自身のローカル `let`** として持たせる（`Task` クロージャそのものが存在しなくなったため）。

```swift
func observe() async {
    let sentinel = B11ObservationSentinel(bridgeId: instanceId)
    print("[B11] ... loop entered sentinel=\(sentinel.bridgeId)")
    for await state in kotlin.state {
        print("[B11] ... state received sentinel=\(sentinel.bridgeId)")  // ループ内で参照し続けて最適化除去を防ぐ
        apply(state)
    }
    print("[B11] ... loop exited sentinel=\(sentinel.bridgeId)")  // ここへ到達 = for await が return した
}
```

- 判定はクロージャ版と同じ理屈: `observe()` が return してこの async 関数の実行フレームが解放されれば、ローカル `sentinel` も一緒に `deinit` される。**「loop exited」ログが出ているのに sentinel の `deinit` ログが出ない**なら、フレームのどこかがまだ生きている（クロージャ版と違って `[weak self]` は存在しないので、疑うべきは `for await` の `AsyncIteratorProtocol` 側が内部で継続を保持していないか）
- 番兵クラス自体は `@MainActor` 既定分離のままで問題ない（`observe()` がブリッジの `@MainActor` 分離を継承して呼ばれるため、番兵の `init` もその文脈で呼ばれる。`deinit` は Swift の既定仕様で自動的に `nonisolated` になるので `isolated deinit` は不要 — `Int` プロパティを print するだけなら nonisolated から触っても安全）
- ブリッジ本体側にも `instanceId`（`static var nextInstanceId` から採番）と `init` / `isolated deinit` の入口・出口ログを足し、`observe()` の loop entered/exited と時系列で突き合わせられるようにする

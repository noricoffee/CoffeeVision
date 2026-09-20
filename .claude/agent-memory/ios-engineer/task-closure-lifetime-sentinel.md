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

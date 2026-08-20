import Foundation
import SharedLogic
import os

// MARK: - FlowCompletionGate

/// `Flow.collect` の completion handler を **高々 1 回だけ** 呼ぶためのゲート。
///
/// Kotlin 側の `collect` は 1 つの suspend 呼び出しなので、completion handler は
/// 「正常終了」「例外終了」のどちらか一方で **ちょうど 1 回** 呼ぶ契約になる。
/// 2 回呼ぶと既に再開済みの continuation を再度再開することになり未定義動作を招く。
///
/// Firestore のリスナは解除されるまで何度でもコールバックしうるため、
/// 「エラーを受けた直後にもう 1 度エラーが来る」ような並びは普通に起こる。
/// そのため取り出しと無効化をアトミックに行うゲートを噛ませる。
///
/// `nonisolated` な文脈（Kotlin ランタイムの任意スレッド）から触られる可変状態なので、
/// `OSAllocatedUnfairLock` で保護する（`BeanProfileRepositoryIosImpl` /
/// `CuratedCafeRepositoryIosImpl` のキャッシュと同じ既存パターン）。
///
/// **クラス宣言の `nonisolated` は必須。** 本プロジェクトは既定 MainActor 分離なので、
/// 何も書かないと `arm` / `finish` が `@MainActor` になり、`CallbackFlow`（`nonisolated`）の
/// `__collect` から呼べずコンパイルエラーになる。
private nonisolated final class FlowCompletionGate: Sendable {

    private let handler = OSAllocatedUnfairLock<(@Sendable ((any Error)?) -> Void)?>(initialState: nil)

    /// `__collect` から受け取った completion handler を保持する。
    func arm(_ completionHandler: @escaping @Sendable ((any Error)?) -> Void) {
        handler.withLock { $0 = completionHandler }
    }

    /// Flow を終了させる。2 回目以降は何もしない。
    ///
    /// - Parameter error: 例外終了させたいときはそのエラー。正常終了は `nil`。
    func finish(_ error: (any Error)?) {
        // ハンドラの実体は Kotlin ランタイムへのブリッジで、そこから同期的に
        // deinit（= onCancel）まで走りうる。ロックを保持したまま呼ぶと再入で
        // デッドロックするため、取り出しだけロック内で行い呼び出しは外に出す。
        let pending = handler.withLock { current -> (@Sendable ((any Error)?) -> Void)? in
            let taken = current
            current = nil
            return taken
        }
        pending?(error)
    }
}

// MARK: - CallbackFlow

/// Swift から Kotlin の `Flow<T>` を「生成して返す」ためのブリッジ実装。
///
/// SKIE は **Kotlin の suspend / Flow を Swift から呼ぶ方向** にしか効かないため、
/// Swift で Kotlin の interface（例: `RemoteCoffeeDataSource.observeChanges(userId:)`）
/// を実装する側で `Flow` を返すには、Obj-C プロトコル `Kotlinx_coroutines_coreFlow`
/// に準拠した独自クラスを Swift 側で書く必要がある。
///
/// 詳細は `docs/kmp-bridge.md` §SKIE の利用 を参照。
///
/// ## 動作モデル
///
/// - `__collect(collector:completionHandler:)` が呼ばれた時点で `onStart` を実行し、
///   イベント駆動の上流（Firestore リスナ等）を開始する
/// - 各値は `onStart` の第 1 引数 `emit: (T) -> Void` を Swift 側から呼ぶことで emit する
/// - **上流が回復不能な失敗をしたら第 2 引数 `fail: (any Error) -> Void` を呼ぶ**。
///   Kotlin 側の `collect` がその例外で終了する（`RemoteCoffeeDataSource.observeChanges`
///   の KDoc に定めたエラー契約 / Android の `callbackFlow { close(error) }` と同じ意味）
///
/// ## `fail` に渡した `NSError` が Kotlin 側でどう見えるか（実測値）
///
/// **`NSError-based exception` という catch 可能な Kotlin 例外になる。fatal ではない。**
/// 生成ヘッダの `collect` に付く「Other uncaught Kotlin exceptions are fatal.」は
/// **Kotlin → Obj-C 方向**の注意書きで、こちら（Swift 実装 → Kotlin 呼び出し）には効かない
/// ——という切り分けをシミュレータで実測して確認済み（2026-08-09 / SR-4）。
/// 実測ログ:
/// ```
/// [SavedCafeRepositoryImpl] リモート同期を停止しました (userId=...):
///     NSError-based exception: PoC forced flow error
/// ```
/// アプリはクラッシュせず起動を継続し、`localizedDescription` も保たれた。
/// - Kotlin 側コルーチンが cancel されると本オブジェクトへの参照が解放されるため、
///   `deinit` 内の `onCancel` で上流リソース（`listener.remove()` 等）を解放する
///
/// ## completion handler の責任分担（誤解しやすい点）
///
/// **completion handler を呼ぶのは実装側（この Swift クラス）の義務**で、Kotlin ランタイムが
/// 代わりに呼んでくれるわけではない。一方 **cancel は completion handler では伝わらない** —
/// Kotlin 側のコルーチンが cancel されると本オブジェクトが解放され、`deinit` として現れる。
/// つまり終了経路は「`fail` / 正常終了 = handler」と「cancel = deinit」の 2 系統に分かれる。
///
/// なお Firestore リスナは自然完了しないため、正常終了で handler を呼ぶ経路は現状無い。
///
/// バックプレッシャは考慮していない（Phase 2 想定では十分）。
///
/// ## `nonisolated` である理由（Swift 6 移行 SW6-2）
///
/// `__collect` は Kotlin ランタイムが Obj-C ブリッジ経由で呼び出し、`deinit` も
/// Kotlin コルーチン側の参照カウントが 0 になったタイミングで走る。**どちらも
/// 呼び出し元スレッドは Kotlin/Native 側の任意スレッドで、MainActor とは限らない**。
/// クラスを MainActor 分離すると `deinit` の実体（`onCancel()` によるリスナ解放）が
/// MainActor へ非同期にホップするため、解放が実際のタイミングより遅延し、
/// 同一クエリの即時再購読時にリスナが二重に生き残る競合窓が生まれうる。
/// そのため既定 MainActor 分離を明示的に無効化している。
nonisolated final class CallbackFlow<T: AnyObject>: NSObject, Kotlinx_coroutines_coreFlow, @unchecked Sendable {

    private let onStart: (@escaping (T) -> Void, @escaping (any Error) -> Void) -> Void
    private let onCancel: () -> Void
    private let gate = FlowCompletionGate()

    init(
        onStart: @escaping (@escaping (T) -> Void, @escaping (any Error) -> Void) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onCancel = onCancel
    }

    /// Kotlin の `Flow.collect` 相当。Obj-C ブリッジでは completion handler 形式。
    /// メソッド名が `__collect` なのは SKIE が生のシグネチャを `__` プレフィックス付きで残し、
    /// Swift エルゴノミクス版（`async throws`）を別途公開しているため。
    func __collect(
        collector: any Kotlinx_coroutines_coreFlowCollector,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        gate.arm(completionHandler)

        let emit: (T) -> Void = { value in
            // emit は suspend 関数 → Obj-C ブリッジでは completion handler 形式。
            collector.__emit(value: value) { _ in }
        }
        let fail: (any Error) -> Void = { [gate] error in
            gate.finish(error)
        }
        onStart(emit, fail)
    }

    deinit {
        onCancel()
    }
}

// MARK: - CallbackFlowOptional

/// Optional 値（`T?` / nil）を emit できる `Flow<T?>` のブリッジ実装。
///
/// `CallbackFlow<T>` は `T: AnyObject` の非 Optional 値しか扱えないため、
/// `Flow<AuthAccount?>` のように nil emit が必要なケース向けに別途用意する。
///
/// `emitSome(value)` で非 nil を、`emitNone()` で nil を emit し、`fail(error)` で
/// 例外終了させる（意味はすべて `CallbackFlow` と同じ。上記 KDoc 参照）。
/// Obj-C ブリッジでは nil を `NSNull` として渡すことで Kotlin 側が null として受け取る。
///
/// `nonisolated` である理由も `CallbackFlow` と同じ（Kotlin ランタイムが任意スレッドから
/// `__collect` / `deinit` を駆動するため）。
nonisolated final class CallbackFlowOptional<T: AnyObject>: NSObject, Kotlinx_coroutines_coreFlow, @unchecked Sendable {

    private let onStart: (@escaping (T) -> Void, @escaping () -> Void, @escaping (any Error) -> Void) -> Void
    private let onCancel: () -> Void
    private let gate = FlowCompletionGate()

    init(
        onStart: @escaping (@escaping (T) -> Void, @escaping () -> Void, @escaping (any Error) -> Void) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onStart = onStart
        self.onCancel = onCancel
    }

    func __collect(
        collector: any Kotlinx_coroutines_coreFlowCollector,
        completionHandler: @escaping @Sendable ((any Error)?) -> Void
    ) {
        gate.arm(completionHandler)

        let emitSome: (T) -> Void = { value in
            collector.__emit(value: value) { _ in }
        }
        let emitNone: () -> Void = {
            // nil を Obj-C ブリッジ経由で Kotlin 側の null として渡す
            collector.__emit(value: nil) { _ in }
        }
        let fail: (any Error) -> Void = { [gate] error in
            gate.finish(error)
        }
        onStart(emitSome, emitNone, fail)
    }

    deinit {
        onCancel()
    }
}

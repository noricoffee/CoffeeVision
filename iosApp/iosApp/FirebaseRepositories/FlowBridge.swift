import Foundation
import SharedLogic

/// Swift から Kotlin の `Flow<T>` を「生成して返す」ためのブリッジ実装。
///
/// SKIE は **Kotlin の suspend / Flow を Swift から呼ぶ方向** にしか効かないため、
/// Swift で Kotlin の interface（例: `RemoteVisitDataSource.observeChanges(userId:)`）
/// を実装する側で `Flow` を返すには、Obj-C プロトコル `Kotlinx_coroutines_coreFlow`
/// に準拠した独自クラスを Swift 側で書く必要がある。
///
/// 詳細は `docs/kmp-bridge.md` §SKIE の利用 を参照。
///
/// ## 動作モデル
///
/// - `__collect(collector:completionHandler:)` が呼ばれた時点で `onStart` を実行し、
///   イベント駆動の上流（Firestore リスナ等）を開始する
/// - 各値は `onStart` のクロージャ引数 `(T) -> Void` を Swift 側から呼ぶことで emit する
/// - Kotlin 側コルーチンが cancel されると本オブジェクトへの参照が解放されるため、
///   `deinit` 内の `onCancel` で上流リソース（listener.remove() 等）を解放する
///
/// バックプレッシャは考慮していない（Phase 2 想定では十分）。
final class CallbackFlow<T: AnyObject>: NSObject, Kotlinx_coroutines_coreFlow {

    private let onStart: (@escaping (T) -> Void) -> Void
    private let onCancel: () -> Void

    init(
        onStart: @escaping (@escaping (T) -> Void) -> Void,
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
        onStart { value in
            // emit は suspend 関数 → Obj-C ブリッジでは completion handler 形式。
            collector.__emit(value: value) { _ in }
        }
        // completionHandler は cancel / 例外時に Kotlin ランタイムから別経路で呼ばれる。
        // 自然完了する Flow ではないので、こちらから明示的には呼ばない。
    }

    deinit {
        onCancel()
    }
}

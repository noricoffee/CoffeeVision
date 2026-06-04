import Foundation
import SharedLogic

/// Phase 2 検証用の暫定 `CoroutineScope` 実装。
///
/// Kotlin 側 `AppContainer` の `init(scope:)` 引数を埋めるためのプレースホルダで、
/// **本当は `MainScope()` (= `SupervisorJob() + Dispatchers.Main`) を渡すべき**。
///
/// SKIE は `MainScope()` のような Kotlin top-level 関数を Swift に export しない。
/// 本来の解決策は `shared/commonMain` 側に `fun coffeeVisionDefaultScope(): CoroutineScope`
/// を追加することだが、これは ios-engineer のスコープ外（`shared*/**` は kmp-engineer 管轄）。
///
/// 暫定として、`coroutineContext` に `EmptyCoroutineContext` 相当を返す最小実装を提供する。
/// `VisitRepositoryImpl.startSync()` 内の `scope.launch { ... }` は dispatcher なしでは
/// 動作しないが、Phase 2 では `startInitialSync()` の **匿名サインインまでの動作** を主目的
/// とするため、この暫定実装でビルドだけ通せば検証 UI で uid を取得できる。
///
/// **親への依頼**: `shared/commonMain` に `fun coffeeVisionDefaultIosScope(): CoroutineScope`
/// などのファクトリを追加して、Swift から `MainScope() + SupervisorJob()` 相当を取れるようにする。
/// それまでは startSync が起きてもダミー scope のためリスナの実体は機能しない（uid 確認用途のみ動く）。
final class IosMainScope: NSObject, Kotlinx_coroutines_coreCoroutineScope {
    var coroutineContext: any KotlinCoroutineContext {
        return DummyCoroutineContext.shared
    }
}

/// `CoroutineContext` の最小実装。`fold` / `get` / `minusKey` / `plus` を no-op 同然で返す。
final class DummyCoroutineContext: NSObject, KotlinCoroutineContext {
    static let shared = DummyCoroutineContext()

    func fold(initial: Any?, operation: (Any?, any KotlinCoroutineContextElement) -> Any?) -> Any? {
        return initial
    }

    func get(key: any KotlinCoroutineContextKey) -> (any KotlinCoroutineContextElement)? {
        return nil
    }

    func minusKey(key: any KotlinCoroutineContextKey) -> any KotlinCoroutineContext {
        return self
    }

    func plus(context: any KotlinCoroutineContext) -> any KotlinCoroutineContext {
        return context
    }
}

import Observation
import SharedLogic

/// `CoffeeDetailViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear(coffeeId:)` / `onDisappear()` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 詳細画面は画面遷移ごとに新規インスタンスを生成するため
///   `CoffeeDetailView` 内の `@State` で保持する（AppState にはホルダプロパティを持たせない）
@MainActor
@Observable
final class CoffeeDetailViewModelBridge {

    private let kotlin: CoffeeDetailViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var coffee: CoffeeRecord?
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    // MARK: - Init

    init(kotlin: CoffeeDetailViewModel) {
        self.kotlin = kotlin
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。`coffeeId` に対応するコーヒー記録の購読を開始する。
    ///
    /// 前回の観測タスクをキャンセルしてから再スタートするため、
    /// 複数回呼ばれても二重購読しない。
    func onAppear(coffeeId: String) {
        kotlin.onAppear(coffeeId: coffeeId)
        observationTask?.cancel()
        let flow = kotlin.state
        observationTask = Task { [weak self] in
            // SKIE により StateFlow が AsyncSequence 化されている
            for await state in flow {
                guard let self else { break }
                self.apply(state)
            }
        }
    }

    /// 画面非表示時に呼ぶ。観測タスクをキャンセルする。
    func onDisappear() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - ユーザーアクション

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func apply(_ state: CoffeeDetailViewModel.UIState) {
        self.coffee = state.coffee
        self.isLoading = state.isLoading
        self.error = state.error
    }
}

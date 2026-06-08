import Observation
import SharedLogic

/// `VisitListViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear` / `onDisappear` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
@MainActor
@Observable
final class VisitListViewModelBridge {

    private let kotlin: VisitListViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var visits: [Visit_] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    // MARK: - Init

    init(kotlin: VisitListViewModel) {
        self.kotlin = kotlin
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。userId で訪問記録の購読を開始する。
    ///
    /// 前回の観測タスクをキャンセルしてから再スタートするため、
    /// タブ切り替えなどで複数回呼ばれても二重購読しない。
    func onAppear(userId: String) {
        kotlin.onAppear(userId: userId)
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

    func onVisitDeleted(id: String) {
        kotlin.onVisitDeleted(id: id)
    }

    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func apply(_ state: VisitListViewModel.UIState) {
        // SKIE 環境では state.visits は既に [Visit_] として型付けされている
        self.visits = state.visits
        self.isLoading = state.isLoading
        self.error = state.error
    }
}

import Observation
import SharedLogic

/// `VisitDetailViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear(visitId:)` / `onDisappear()` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - VisitList と異なり、Detail は画面遷移ごとに新規インスタンスを生成するため
///   `VisitDetailView` 内の `@State` で保持する（AppState にはホルダプロパティを持たせない）
@MainActor
@Observable
final class VisitDetailViewModelBridge {

    private let kotlin: VisitDetailViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var visit: Visit_?
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    // MARK: - Init

    init(kotlin: VisitDetailViewModel) {
        self.kotlin = kotlin
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。`visitId` に対応する訪問記録の購読を開始する。
    ///
    /// 前回の観測タスクをキャンセルしてから再スタートするため、
    /// 複数回呼ばれても二重購読しない。
    func onAppear(visitId: String) {
        kotlin.onAppear(visitId: visitId)
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

    private func apply(_ state: VisitDetailViewModel.UIState) {
        self.visit = state.visit
        self.isLoading = state.isLoading
        self.error = state.error
    }
}

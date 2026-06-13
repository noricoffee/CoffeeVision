import Observation
import SharedLogic

/// `CafeSearchViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `init` 時に観測タスクを起動し、`cancel()` / deinit で終了する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - `CafeSearchView` 内の `@State` で保持する（sheet 起動ごとに新規生成・破棄）
@MainActor
@Observable
final class CafeSearchViewModelBridge {

    private let kotlin: CafeSearchViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ

    private(set) var query: String = ""
    private(set) var results: [Cafe] = []
    private(set) var isLoading: Bool = false
    private(set) var error: String?

    // MARK: - Init

    init(kotlin: CafeSearchViewModel) {
        self.kotlin = kotlin
        startObservation()
    }

    // MARK: - ライフサイクル

    /// 観測タスクを明示的にキャンセルする。`onDisappear` から呼ぶ。
    func cancel() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - ユーザーアクション

    /// 検索クエリを更新する。検索は実行しない（`onSearchTapped` で実行）。
    func onQueryChanged(_ query: String) {
        kotlin.onQueryChanged(query: query)
    }

    /// 検索を実行する。現在の `query` で Places API を叩く。
    func onSearchTapped() {
        kotlin.onSearchTapped()
    }

    /// エラーアラートを閉じる。
    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    // MARK: - Private

    private func startObservation() {
        let flow = kotlin.state
        observationTask = Task { [weak self] in
            // SKIE により StateFlow が AsyncSequence 化されている
            for await state in flow {
                guard let self else { break }
                self.apply(state)
            }
        }
    }

    private func apply(_ state: CafeSearchViewModel.UIState) {
        self.query = state.query
        self.results = state.results
        self.isLoading = state.isLoading
        self.error = state.error
    }
}

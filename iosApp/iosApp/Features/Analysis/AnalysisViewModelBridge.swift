import Observation
import SharedLogic

/// `AnalysisViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - `onAppear` / `onDisappear` でライフサイクルを管理し、観測タスクのリーク防止する
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 分析タブは TabBar 常時生存のため `AppState` で 1 つだけ保持する（`mapBridge` と同等のライフサイクル）
@MainActor
@Observable
final class AnalysisViewModelBridge {

    private let kotlin: AnalysisViewModel
    private var observationTask: Task<Void, Never>?

    // MARK: - SwiftUI が観測するプロパティ（階層1 統計）

    private(set) var stats: CoffeeStats? = nil
    private(set) var isLoading: Bool = true
    private(set) var error: String? = nil

    // MARK: - 階層3 insight 系（A-4 で使用。A-3 では UI 描画に用いないが読めるようにしておく）

    private(set) var insight: CoffeeInsight? = nil

    /// 要約のロード状態。
    ///
    /// - `AnalysisViewModelInsightStatusUnsupported`: insightProvider が null（現フェーズ常にこれ）
    /// - その他の状態（`Idle` / `Loading` / `Loaded` / `Failed`）は A-4 で使う
    private(set) var insightStatus: any AnalysisViewModelInsightStatus = AnalysisViewModelInsightStatusUnsupported()

    // MARK: - Init

    init(viewModel: AnalysisViewModel) {
        self.kotlin = viewModel
    }

    // MARK: - ライフサイクル

    /// 画面表示時に呼ぶ。統計購読を開始する。
    ///
    /// 前回の観測タスクをキャンセルしてから再スタートするため、
    /// タブ切り替えなどで複数回呼ばれても二重購読しない。
    func onAppear() {
        kotlin.onAppear()
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

    /// TabBar 常時生存 Bridge の明示的なキャンセル。AppState が破棄されるときに呼ぶ。
    func cancel() {
        observationTask?.cancel()
        observationTask = nil
    }

    // MARK: - ユーザーアクション

    /// エラーバナーを閉じたときに呼ぶ。`error` を nil にリセットする。
    func onErrorDismissed() {
        kotlin.onErrorDismissed()
    }

    /// Foundation Models の要約生成に失敗したときにリトライを要求する。
    ///
    /// `InsightStatus.Unsupported`（provider が null）の場合は VM 側で何もしない。
    func onRetryInsight() {
        kotlin.onRetryInsight()
    }

    // MARK: - Private

    private func apply(_ state: AnalysisViewModel.UIState) {
        self.stats = state.stats
        self.isLoading = state.isLoading
        self.insight = state.insight
        self.insightStatus = state.insightStatus
        self.error = state.error
    }
}

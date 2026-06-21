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

    // MARK: - 階層3 insight 系

    private(set) var insight: CoffeeInsight? = nil

    /// 要約のロード状態。
    ///
    /// - `AnalysisViewModelInsightStatusUnsupported`: insightProvider が null
    /// - その他の状態（`Idle` / `Loading` / `Loaded` / `Failed`）は Foundation Models 使用時
    private(set) var insightStatus: any AnalysisViewModelInsightStatus = AnalysisViewModelInsightStatusUnsupported()

    // MARK: - 対話 Q&A 系（Phase B-2）

    /// Q&A のロード状態。
    ///
    /// - `AnalysisViewModelQaStatusUnsupported`: insightProvider が null（Q&A セクションを非表示）
    /// - `Idle`: 入力欄表示。まだ質問未送信
    /// - `Asking`: 回答生成中
    /// - `Answered`: 回答到着（`qaQuestion` / `qaAnswer` に値あり）
    /// - `Failed`: 回答生成失敗
    private(set) var qaStatus: any AnalysisViewModelQaStatus = AnalysisViewModelQaStatusUnsupported()

    /// 直近の質問テキスト。`onQaCleared()` で nil に戻る。
    private(set) var qaQuestion: String? = nil

    /// 直近の回答テキスト。`onQaCleared()` で nil に戻る。
    private(set) var qaAnswer: String? = nil

    /// 候補質問チップ用の提案リスト。ViewModel companion から取得する。
    let suggestedQuestions: [String] = Array(AnalysisViewModel.companion.SUGGESTED_QUESTIONS)

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

    /// ユーザーが質問を送信したときに呼ぶ（Phase B-2 対話 Q&A）。
    ///
    /// 空文字 / provider null / stats null の場合は VM 側でガードされ no-op。
    func onQuestionAsked(_ question: String) {
        kotlin.onQuestionAsked(question: question)
    }

    /// Q&A の状態をリセットして `Idle` に戻す。
    ///
    /// クリアボタンや次の質問入力前に呼ぶ。`qaQuestion` / `qaAnswer` が nil に戻る。
    func onQaCleared() {
        kotlin.onQaCleared()
    }

    // MARK: - Private

    private func apply(_ state: AnalysisViewModel.UIState) {
        self.stats = state.stats
        self.isLoading = state.isLoading
        self.insight = state.insight
        self.insightStatus = state.insightStatus
        self.qaStatus = state.qaStatus
        self.qaQuestion = state.qaQuestion
        self.qaAnswer = state.qaAnswer
        self.error = state.error
    }
}

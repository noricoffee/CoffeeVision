import Observation
import SharedLogic

/// `AnalysisViewModel`（Kotlin）を SwiftUI から扱うための @Observable ブリッジ。
///
/// - Kotlin の `StateFlow<UIState>` を Swift の `@Observable` プロパティに変換する
/// - 観測は `observe()`（構造化 `Task`。`AnalysisView` の `.task` から呼ぶ）が担う。
///   ブリッジ自身は `Task` を保持しない（B-11）
/// - `@MainActor` を付けることで `apply(_:)` が常にメインスレッドで動く
/// - 分析タブは TabBar 常時生存のため `AppState` で 1 つだけ保持する（`mapBridge` と同等のライフサイクル）
@MainActor
@Observable
final class AnalysisViewModelBridge {

    private let kotlin: AnalysisViewModel

    // MARK: - SwiftUI が観測するプロパティ（階層1 統計）

    private(set) var stats: CoffeeStats? = nil
    private(set) var isLoading: Bool = true
    private(set) var error: String? = nil

    /// 分析タブの空状態プログレス（要件 9-7）。`stats` が確定するまでは nil。
    private(set) var readiness: AnalysisViewModel.AnalysisReadiness? = nil

    // MARK: - 階層3 insight 系

    private(set) var insight: CoffeeInsight? = nil

    /// 要約のロード状態。
    ///
    /// - `AnalysisViewModelInsightStatusUnsupported`: insightProvider が null
    /// - その他の状態（`Idle` / `Loading` / `Loaded` / `Failed`）は Foundation Models 使用時
    private(set) var insightStatus: any AnalysisViewModelInsightStatus = AnalysisViewModelInsightStatusUnsupported()

    // MARK: - 好みの豆の傾向インサイト系（Phase 12-C）

    /// 豆の傾向要約コンテンツ。`beanTraitsInsightStatus` が `Loaded` のときに非 nil になる。
    private(set) var beanTraitsInsight: CoffeeInsight? = nil

    /// 豆の傾向インサイトのロード状態。
    ///
    /// - `Unsupported`: insightProvider が null（Apple Intelligence 非対応 / 無効）
    /// - `Idle`: データあり・生成待ち（フレーバータグをフォールバック表示）
    /// - `Loading`: Foundation Models 生成中
    /// - `Loaded`: 生成完了（`beanTraitsInsight` に値あり）
    /// - `Failed`: 生成失敗（フレーバータグをフォールバック表示）
    private(set) var beanTraitsInsightStatus: any AnalysisViewModelInsightStatus = AnalysisViewModelInsightStatusIdle()

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

    isolated deinit {
        kotlin.clear()
    }

    // MARK: - ライフサイクル

    /// 統計購読を開始する。`AnalysisView` の `.task` から呼ぶ（構造化 `Task`）。
    ///
    /// タブ切り替えで View が再表示されるたびに `.task` が再実行されるため、
    /// 複数回呼ばれても構わない（都度新しい購読に張り替わる）。
    func observe() async {
        kotlin.onAppear()
        for await state in kotlin.state {
            apply(state)
        }
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
        // `@Observable` は値を比較せず、代入するだけで observer に変更を通知する。
        // Kotlin の StateFlow は 1 フィールドだけ変わった state も丸ごと emit するため、
        // 無条件代入だと無関係な body まで再評価される（SL-3）。
        //
        // Kotlin の `data class`（`CoffeeStats` / `CoffeeInsight` / `AnalysisReadiness`）は
        // Obj-C 側で `equals()` 由来の `isEqual:` を持つため `==` が値比較になる。
        // `InsightStatus` / `QaStatus` は SKIE が Obj-C プロトコルとして生成するので
        // `Equatable` 非準拠。実体は Kotlin の `data object`（シングルトン。ヘッダの
        // `@property (class, readonly, getter=shared)` で確認）なので参照比較で同値判定できる。
        if stats != state.stats {
            stats = state.stats
        }
        if isLoading != state.isLoading {
            isLoading = state.isLoading
        }
        if readiness != state.readiness {
            readiness = state.readiness
        }
        if insight != state.insight {
            insight = state.insight
        }
        if insightStatus !== state.insightStatus {
            insightStatus = state.insightStatus
        }
        if beanTraitsInsight != state.beanTraitsInsight {
            beanTraitsInsight = state.beanTraitsInsight
        }
        if beanTraitsInsightStatus !== state.beanTraitsInsightStatus {
            beanTraitsInsightStatus = state.beanTraitsInsightStatus
        }
        if qaStatus !== state.qaStatus {
            qaStatus = state.qaStatus
        }
        if qaQuestion != state.qaQuestion {
            qaQuestion = state.qaQuestion
        }
        if qaAnswer != state.qaAnswer {
            qaAnswer = state.qaAnswer
        }
        if error != state.error {
            error = state.error
        }
    }
}

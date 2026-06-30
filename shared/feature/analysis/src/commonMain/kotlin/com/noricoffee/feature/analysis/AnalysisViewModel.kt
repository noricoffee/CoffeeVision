package com.noricoffee.feature.analysis

import com.noricoffee.domain.model.CoffeeInsight
import com.noricoffee.domain.model.CoffeeInsightProvider
import com.noricoffee.domain.model.CoffeeStats
import com.noricoffee.domain.model.PreferredBeanTraits
import com.noricoffee.domain.usecase.ObserveCoffeeStatsUseCase
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * 分析タブの ViewModel。
 *
 * ## 2 段ロード設計（統計と要約は独立したロード状態）
 *
 * - **統計（階層1）**: [ObserveCoffeeStatsUseCase] の Flow を購読し、コーヒー記録の変化をリアルタイム反映する。
 *   [UIState.stats] に即時反映され、[UIState.isLoading] は初回 emit まで true。
 *
 * - **要約（階層3）**: [CoffeeInsightProvider.summarize] を非同期で呼び、[UIState.insight] に後追いで反映する。
 *   統計が確定（初回 emit）後、または統計が更新されるたびに自動で要約生成ジョブを再起動する。
 *   [insightProvider] が null（Android / Apple Intelligence 無効 / 未対応端末）の場合は
 *   [InsightStatus.Unsupported] を返し、要約は常に null のまま。
 *
 * ## 要約生成のトリガ
 * `stats` が変化するたびに [insightJob] をキャンセルして再起動する
 * ([MapViewModel.poiLookupJob] / [CafeSearchViewModel.searchJob] と同じ Job 再起動パターン)。
 * これにより統計が変わるたびに要約が自動更新される。
 * [onRetryInsight] による手動リトライも同じ再起動パターンで実装する。
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。
 *
 * @param observeCoffeeStatsUseCase コーヒー記録を集計して [CoffeeStats] の Flow を返す UseCase
 * @param insightProvider Foundation Models 実装。null = 階層3 非対応（Android / Apple Intelligence 無効）
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class AnalysisViewModel(
    private val observeCoffeeStatsUseCase: ObserveCoffeeStatsUseCase,
    private val insightProvider: CoffeeInsightProvider?,
    private val userId: String,
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    /**
     * 分析タブの UI 状態。
     *
     * @property stats 集計済みのコーヒー統計。初回ロード前は null
     * @property isLoading 統計の初回ロード中かどうか
     * @property insight Foundation Models が生成した要約。非対応 / 未生成 / 失敗時は null
     * @property insightStatus 要約のロード状態。[InsightStatus] を参照
     * @property beanTraitsInsight 好みの豆の傾向を言語化した [CoffeeInsight]。生成前 / 失敗時は null
     * @property beanTraitsInsightStatus 好みの豆の傾向の言語化ロード状態。[InsightStatus] を参照
     * @property qaStatus 対話 Q&A の状態。[QaStatus] を参照
     * @property qaQuestion 直近の質問テキスト。[onQaCleared] で null に戻る
     * @property qaAnswer 直近の回答テキスト。[onQaCleared] で null に戻る
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val stats: CoffeeStats? = null,
        val isLoading: Boolean = true,
        val insight: CoffeeInsight? = null,
        val insightStatus: InsightStatus = InsightStatus.Idle,
        val beanTraitsInsight: CoffeeInsight? = null,
        val beanTraitsInsightStatus: InsightStatus = InsightStatus.Idle,
        val qaStatus: QaStatus = QaStatus.Idle,
        val qaQuestion: String? = null,
        val qaAnswer: String? = null,
        val error: String? = null,
    )

    /**
     * 要約（階層3）のロード状態。
     *
     * - [Unsupported]: [insightProvider] が null（Android / Apple Intelligence 非対応端末）。
     *   UI はこの状態では要約カードを表示しない
     * - [Idle]: 対応端末だがまだ統計が確定していない初期状態
     * - [Loading]: 要約生成中
     * - [Loaded]: 要約生成完了（[UIState.insight] に値が入っている）
     * - [Failed]: 要約生成失敗。[UIState.error] にエラーメッセージが入る。
     *   [AnalysisViewModel.onRetryInsight] で再試行可能
     */
    sealed interface InsightStatus {
        data object Unsupported : InsightStatus
        data object Idle : InsightStatus
        data object Loading : InsightStatus
        data object Loaded : InsightStatus
        data object Failed : InsightStatus
    }

    /**
     * 対話 Q&A（階層3 / Phase B-2）のロード状態。
     *
     * [insightProvider] が null の端末は Q&A も利用不可のため初期値が [Unsupported] になる
     * （可否判定は [InsightStatus] と共有。`provider != null` なら Q&A も使える）。
     *
     * - [Unsupported]: [insightProvider] が null。UI は Q&A セクションを表示しない
     * - [Idle]: 入力欄を表示。まだ質問を送っていない状態
     * - [Asking]: 回答を生成中。[UIState.qaQuestion] に質問が入っている
     * - [Answered]: 回答が届いた。[UIState.qaQuestion] と [UIState.qaAnswer] に内容が入っている
     * - [Failed]: 回答生成に失敗。[UIState.error] にメッセージが入る。
     *   [AnalysisViewModel.onQaCleared] で [Idle] に戻り、再度質問できる
     */
    sealed interface QaStatus {
        data object Unsupported : QaStatus
        data object Idle : QaStatus
        data object Asking : QaStatus
        data object Answered : QaStatus
        data object Failed : QaStatus
    }

    /** 候補質問チップ用の提案リスト（UI でショートカットとして提示する）。 */
    companion object {
        val SUGGESTED_QUESTIONS: List<String> = listOf(
            "好きな産地は？",
            "苦手な傾向は？",
            "一番高評価だったコーヒーは？",
            "よく行くカフェは？",
        )
    }

    private val _state = MutableStateFlow(
        UIState(
            insightStatus = if (insightProvider == null) {
                InsightStatus.Unsupported
            } else {
                InsightStatus.Idle
            },
            beanTraitsInsightStatus = if (insightProvider == null) {
                InsightStatus.Unsupported
            } else {
                InsightStatus.Idle
            },
            qaStatus = if (insightProvider == null) {
                QaStatus.Unsupported
            } else {
                QaStatus.Idle
            },
        )
    )
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 統計購読 Job。onAppear が複数回呼ばれても二重購読しないために保持する。
    private var observeJob: Job? = null

    // 要約生成 Job。統計が更新されるたびにキャンセルして再起動する（連打耐性 / 重複起動防止）。
    private var insightJob: Job? = null

    // 好みの豆の傾向言語化 Job（Phase 12-C）。
    private var beanTraitsInsightJob: Job? = null

    // Q&A 回答生成 Job。質問が送られるたびにキャンセルして再起動する（連打耐性 / 重複起動防止）。
    private var qaJob: Job? = null

    // 直近の統計値。onRetryInsight / onQuestionAsked で再利用する。
    private var latestStats: CoffeeStats? = null

    /**
     * 画面表示時に呼ぶ。[userId] を使ってコーヒー記録の統計購読を開始する。
     *
     * 既に購読中の場合は前回の購読をキャンセルして再購読する。
     * userId が [AnalysisViewModel] のコンストラクタで渡されているため、
     * [onAppear] は引数なし（[CoffeeListViewModel.onAppear] とは異なり、uid はコンストラクタ確定）。
     */
    fun onAppear() {
        observeJob?.cancel()
        observeJob = viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            observeCoffeeStatsUseCase(userId).collect { stats ->
                latestStats = stats
                _state.update { it.copy(stats = stats, isLoading = false) }
                // 統計が確定 / 更新されたら要約を再生成する
                launchInsightGeneration(stats)
            }
        }
    }

    /**
     * 要約生成の手動リトライ時に呼ぶ。
     *
     * [InsightStatus.Failed] 状態でユーザーがリトライボタンをタップしたときに呼ぶ。
     * [insightProvider] が null（[InsightStatus.Unsupported]）の場合は何もしない。
     */
    fun onRetryInsight() {
        val stats = latestStats ?: return
        launchInsightGeneration(stats)
    }

    /**
     * ユーザーが質問を送信したときに呼ぶ（Phase B-2 対話 Q&A）。
     *
     * 以下のいずれかを満たす場合は no-op（ガード）:
     * - [question] の trim が空文字
     * - [insightProvider] が null（[QaStatus.Unsupported]）
     * - [latestStats] が null（統計がまだ確定していない）
     *
     * 既に回答生成中の [qaJob] をキャンセルして新しい Job を起動する（連打耐性）。
     * エラーメッセージは [UIState.error]（[InsightStatus] と共有フィールド）に書く。
     *
     * @param question ユーザーが入力した質問テキスト（trim は本メソッド内で行う）
     */
    fun onQuestionAsked(question: String) {
        val trimmed = question.trim()
        if (trimmed.isEmpty()) return
        val provider = insightProvider ?: return
        val stats = latestStats ?: return

        qaJob?.cancel()
        qaJob = viewModelScope.launch {
            _state.update {
                it.copy(
                    qaQuestion = trimmed,
                    qaStatus = QaStatus.Asking,
                    error = null,
                )
            }
            try {
                val answer = provider.answer(trimmed, stats)
                _state.update {
                    it.copy(
                        qaAnswer = answer,
                        qaStatus = QaStatus.Answered,
                    )
                }
            } catch (e: CancellationException) {
                _state.update { it.copy(qaStatus = QaStatus.Idle) }
                throw e
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        qaStatus = QaStatus.Failed,
                        error = e.message ?: "回答の生成に失敗しました",
                    )
                }
            }
        }
    }

    /**
     * Q&A の状態をリセットして [QaStatus.Idle] に戻す。
     *
     * 入力欄をクリアしたいときや次の質問に備えて呼ぶ。
     * [QaStatus.Unsupported] のときは何もしない。
     *
     * [UIState.qaQuestion] / [UIState.qaAnswer] を null に、[UIState.qaStatus] を [QaStatus.Idle] にする。
     */
    fun onQaCleared() {
        if (_state.value.qaStatus is QaStatus.Unsupported) return
        _state.update {
            it.copy(
                qaQuestion = null,
                qaAnswer = null,
                qaStatus = QaStatus.Idle,
            )
        }
    }

    /**
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null) }
    }

    /**
     * 画面破棄時に呼ぶ。内部の viewModelScope をキャンセルして全コルーチンを停止する。
     *
     * iOS Bridge の deinit で呼ぶこと（タブ常駐 VM のため onDisappear では不要）。
     * キャンセル後に各メソッドが呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }

    /**
     * 要約生成 Job を起動する（内部ヘルパ）。
     *
     * [insightProvider] が null の場合は何もしない（[InsightStatus.Unsupported] のまま）。
     * 既に実行中の [insightJob] をキャンセルして新しい Job を起動する（重複起動防止）。
     * 統計確定時に [stats.preferredBeanTraits] が存在する場合は好みの豆の傾向の言語化も並列で起動する。
     */
    private fun launchInsightGeneration(stats: CoffeeStats) {
        val provider = insightProvider ?: return
        insightJob?.cancel()
        insightJob = viewModelScope.launch {
            _state.update {
                it.copy(
                    insightStatus = InsightStatus.Loading,
                    error = null,
                )
            }
            try {
                val insight = provider.summarize(stats)
                _state.update {
                    it.copy(
                        insight = insight,
                        insightStatus = InsightStatus.Loaded,
                    )
                }
            } catch (e: CancellationException) {
                _state.update { it.copy(insightStatus = InsightStatus.Idle) }
                throw e
            } catch (e: Exception) {
                _state.update {
                    it.copy(
                        insightStatus = InsightStatus.Failed,
                        error = e.message ?: "要約の生成に失敗しました",
                    )
                }
            }
        }

        val traits = stats.preferredBeanTraits ?: return
        launchBeanTraitsInsightGeneration(traits, provider)
    }

    /**
     * 好みの豆の傾向言語化 Job を起動する（内部ヘルパ）。
     *
     * [PreferredBeanTraits] が null または [dominantFlavorNotes] と [originHint] が両方なければ呼ばれない。
     * 既に実行中の [beanTraitsInsightJob] をキャンセルして新しい Job を起動する（重複起動防止）。
     */
    private fun launchBeanTraitsInsightGeneration(
        traits: PreferredBeanTraits,
        provider: CoffeeInsightProvider,
    ) {
        beanTraitsInsightJob?.cancel()
        beanTraitsInsightJob = viewModelScope.launch {
            _state.update { it.copy(beanTraitsInsightStatus = InsightStatus.Loading) }
            try {
                val insight = provider.summarizeBeanTraits(traits)
                _state.update {
                    it.copy(
                        beanTraitsInsight = insight,
                        beanTraitsInsightStatus = InsightStatus.Loaded,
                    )
                }
            } catch (e: CancellationException) {
                _state.update { it.copy(beanTraitsInsightStatus = InsightStatus.Idle) }
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(beanTraitsInsightStatus = InsightStatus.Failed) }
            }
        }
    }
}

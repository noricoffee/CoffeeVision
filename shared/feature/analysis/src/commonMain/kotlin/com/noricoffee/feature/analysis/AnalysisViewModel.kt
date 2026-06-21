package com.noricoffee.feature.analysis

import com.noricoffee.domain.model.CoffeeInsight
import com.noricoffee.domain.model.CoffeeInsightProvider
import com.noricoffee.domain.model.CoffeeStats
import com.noricoffee.domain.usecase.ObserveCoffeeStatsUseCase
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
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
    private val scope: CoroutineScope,
) {

    /**
     * 分析タブの UI 状態。
     *
     * @property stats 集計済みのコーヒー統計。初回ロード前は null
     * @property isLoading 統計の初回ロード中かどうか
     * @property insight Foundation Models が生成した要約。非対応 / 未生成 / 失敗時は null
     * @property insightStatus 要約のロード状態。[InsightStatus] を参照
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val stats: CoffeeStats? = null,
        val isLoading: Boolean = true,
        val insight: CoffeeInsight? = null,
        val insightStatus: InsightStatus = InsightStatus.Idle,
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

    private val _state = MutableStateFlow(
        UIState(
            insightStatus = if (insightProvider == null) {
                InsightStatus.Unsupported
            } else {
                InsightStatus.Idle
            },
        )
    )
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 統計購読 Job。onAppear が複数回呼ばれても二重購読しないために保持する。
    private var observeJob: Job? = null

    // 要約生成 Job。統計が更新されるたびにキャンセルして再起動する（連打耐性 / 重複起動防止）。
    private var insightJob: Job? = null

    // 直近の統計値。onRetryInsight で再利用する。
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
        observeJob = scope.launch {
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
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null as String?) }
    }

    /**
     * 要約生成 Job を起動する（内部ヘルパ）。
     *
     * [insightProvider] が null の場合は何もしない（[InsightStatus.Unsupported] のまま）。
     * 既に実行中の [insightJob] をキャンセルして新しい Job を起動する（重複起動防止）。
     */
    private fun launchInsightGeneration(stats: CoffeeStats) {
        val provider = insightProvider ?: return
        insightJob?.cancel()
        insightJob = scope.launch {
            _state.update {
                it.copy(
                    insightStatus = InsightStatus.Loading,
                    error = null as String?,
                )
            }
            runCatching { provider.summarize(stats) }
                .onSuccess { insight ->
                    _state.update {
                        it.copy(
                            insight = insight,
                            insightStatus = InsightStatus.Loaded,
                        )
                    }
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            insightStatus = InsightStatus.Failed,
                            error = e.message ?: "要約の生成に失敗しました",
                        )
                    }
                }
        }
    }
}

package com.noricoffee.feature.visitdetail

import com.noricoffee.domain.Visit
import com.noricoffee.repository.VisitRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * 訪問記録詳細画面の ViewModel。
 *
 * - [VisitRepository.observeById] を購読して [UIState.visit] を更新する
 * - visit が null（削除済み等）になった場合も [UIState.visit] にそのまま null として流す。
 *   画面側でナビゲーションバックするかどうかはプレゼンテーション層に委ねる
 * - [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する
 *
 * ## CoroutineScope の注意
 *
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。iOS 側では
 * `AppContainer.makeVisitDetailViewModel()` 経由で取得した ViewModel のスコープは
 * `AppContainer` が保持する `MainScope` と生存期間を共にする。
 */
class VisitDetailViewModel(
    private val visitRepository: VisitRepository,
    private val scope: CoroutineScope,
) {

    /**
     * 訪問記録詳細画面の UI 状態。
     *
     * @property visit 表示する訪問記録。null は「未ロード」または「対象が存在しない」状態を表す
     * @property isLoading 初回読み込み中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val visit: Visit? = null,
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 既に購読中の Flow の Job。onAppear が複数回呼ばれても二重購読しないために保持する。
    private var observeJob: Job? = null

    /**
     * 画面表示時に呼ぶ。[visitId] に対応する訪問記録の購読を開始する。
     *
     * 前回の購読をキャンセルしてから再購読するため、visitId が変わった場合や
     * タブ切り替えなどで `onAppear` が重複して呼ばれても状態が壊れない。
     *
     * @param visitId 表示対象の [Visit.id]
     */
    fun onAppear(visitId: String) {
        observeJob?.cancel()
        observeJob = scope.launch {
            _state.update { it.copy(isLoading = true) }
            visitRepository.observeById(visitId).collect { visit ->
                _state.update { it.copy(visit = visit, isLoading = false) }
            }
        }
    }

    /**
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null as String?) }
    }
}

package com.noricoffee.feature.visitlist

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
 * 訪問記録一覧画面の ViewModel。
 *
 * - [VisitRepository.observeAll] を購読して [UIState.visits] を更新する
 * - 削除失敗は [UIState.error] に流し、UI 側はエラー解除を [onErrorDismissed] で通知する
 * - [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する
 *
 * ## CoroutineScope の注意
 *
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。iOS 側では
 * `AppContainer.makeVisitListViewModel()` 経由で取得した ViewModel のスコープは
 * `AppContainer` が保持する `MainScope` と生存期間を共にする。
 */
class VisitListViewModel(
    private val visitRepository: VisitRepository,
    private val scope: CoroutineScope,
) {

    /**
     * 訪問記録一覧画面の UI 状態。
     *
     * @property visits 表示する訪問記録の一覧
     * @property isLoading 初回読み込み中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val visits: List<Visit> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 既に購読中の Flow の Job。onAppear が複数回呼ばれても二重購読しないために保持する。
    private var observeJob: Job? = null

    /**
     * 画面表示時に呼ぶ。[userId] を使って訪問記録の購読を開始する。
     *
     * 既に同一 [userId] で購読中の場合は前回の購読をキャンセルして再購読する。
     * これにより、タブ切り替えなどで `onAppear` が重複して呼ばれても状態が壊れない。
     */
    fun onAppear(userId: String) {
        // 前の購読をキャンセルしてから新たに開始する（userId 変更・再表示の両方に対応）
        observeJob?.cancel()
        observeJob = scope.launch {
            _state.update { it.copy(isLoading = true) }
            visitRepository.observeAll(userId).collect { visits ->
                _state.update { it.copy(visits = visits, isLoading = false) }
            }
        }
    }

    /**
     * 訪問記録を削除する。削除失敗は [UIState.error] に伝播させる。
     *
     * @param id 削除対象の [Visit.id]
     */
    fun onVisitDeleted(id: String) {
        scope.launch {
            runCatching { visitRepository.delete(id) }
                .onFailure { e ->
                    _state.update { it.copy(error = e.message ?: "delete failed") }
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

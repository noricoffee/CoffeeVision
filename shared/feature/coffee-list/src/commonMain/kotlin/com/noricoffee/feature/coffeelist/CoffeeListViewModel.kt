package com.noricoffee.feature.coffeelist

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.repository.CoffeeRepository
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
 * コーヒー記録一覧画面の ViewModel。
 *
 * - [CoffeeRepository.observeAll] を購読して [UIState.coffees] を更新する
 * - 削除失敗は [UIState.error] に流し、UI 側はエラー解除を [onErrorDismissed] で通知する
 * - [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する
 *
 * ## CoroutineScope の注意
 *
 * 内部で [scope] を親とする子スコープ（viewModelScope）を保持する。
 * 画面破棄時に [clear] を呼ぶことで子スコープをキャンセルする。
 * [scope]（app-wide MainScope）がキャンセルされると子も連鎖キャンセルされる（構造化並行性）。
 */
class CoffeeListViewModel(
    private val coffeeRepository: CoffeeRepository,
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    /**
     * コーヒー記録一覧画面の UI 状態。
     *
     * @property coffees 表示するコーヒー記録の一覧
     * @property isLoading 初回読み込み中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val coffees: List<CoffeeRecord> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 既に購読中の Flow の Job。onAppear が複数回呼ばれても二重購読しないために保持する。
    private var observeJob: Job? = null

    // onAppear で受け取った userId を保持し、onCoffeeDeleted 内で使う。
    private var currentUserId: String? = null

    /**
     * 画面表示時に呼ぶ。[userId] を使ってコーヒー記録の購読を開始する。
     *
     * 既に同一 [userId] で購読中の場合は前回の購読をキャンセルして再購読する。
     */
    fun onAppear(userId: String) {
        currentUserId = userId
        observeJob?.cancel()
        observeJob = viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            coffeeRepository.observeAll(userId).collect { coffees ->
                _state.update { it.copy(coffees = coffees, isLoading = false) }
            }
        }
    }

    /**
     * コーヒー記録を削除する。削除失敗は [UIState.error] に伝播させる。
     *
     * userId は [onAppear] で受け取った値を内部で保持して使う。
     * [onAppear] 呼び出し前に本メソッドが呼ばれた場合は黙殺する（uid 未確定）。
     *
     * @param id 削除対象の [CoffeeRecord.id]
     */
    fun onCoffeeDeleted(id: String) {
        val userId = currentUserId ?: return
        viewModelScope.launch {
            try {
                coffeeRepository.delete(userId, id)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message ?: "delete failed") }
            }
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
     * iOS Bridge の deinit または onDisappear（常駐タブ以外）で呼ぶこと。
     * キャンセル後に [onAppear] が呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }
}

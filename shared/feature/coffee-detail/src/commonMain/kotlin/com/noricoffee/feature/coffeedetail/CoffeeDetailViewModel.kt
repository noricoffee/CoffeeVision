package com.noricoffee.feature.coffeedetail

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
 * コーヒー記録詳細画面の ViewModel。
 *
 * - [CoffeeRepository.observeById] を購読して [UIState.coffee] を更新する
 * - record が null（削除済み等）になった場合も [UIState.coffee] にそのまま null として流す。
 *   画面側でナビゲーションバックするかどうかはプレゼンテーション層に委ねる
 * - 自分の操作（[onDeleteTapped]）による削除成功は [UIState.isDeleted] で通知する。
 *   `coffee == null` になったことでの pop 判断は採用しない（他画面・リモート同期による削除では
 *   従来どおり「見つかりません」表示を維持するため）
 * - [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する
 *
 * ## CoroutineScope の注意
 *
 * 内部で [scope] を親とする子スコープ（viewModelScope）を保持する。
 * 画面破棄時に [clear] を呼ぶことで子スコープをキャンセルする。
 * [scope]（app-wide MainScope）がキャンセルされると子も連鎖キャンセルされる（構造化並行性）。
 */
class CoffeeDetailViewModel(
    private val coffeeRepository: CoffeeRepository,
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    /**
     * コーヒー記録詳細画面の UI 状態。
     *
     * @property coffee 表示するコーヒー記録。null は「未ロード」または「対象が存在しない」状態を表す
     * @property isLoading 初回読み込み中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     * @property isDeleted [onDeleteTapped] による削除が成功した場合のみ true。
     *   画面側はこのフラグを見て一覧へ pop する
     */
    data class UIState(
        val coffee: CoffeeRecord? = null,
        val isLoading: Boolean = false,
        val error: String? = null,
        val isDeleted: Boolean = false,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 既に購読中の Flow の Job。onAppear が複数回呼ばれても二重購読しないために保持する。
    private var observeJob: Job? = null

    // onAppear で受け取った coffeeId / userId を保持し、onDeleteTapped 内で使う。
    private var currentCoffeeId: String? = null
    private var currentUserId: String? = null

    /**
     * 画面表示時に呼ぶ。[coffeeId] に対応するコーヒー記録の購読を開始する。
     *
     * 前回の購読をキャンセルしてから再購読するため、coffeeId が変わった場合や
     * タブ切り替えなどで `onAppear` が重複して呼ばれても状態が壊れない。
     *
     * @param coffeeId 表示対象の [CoffeeRecord.id]
     * @param userId [onDeleteTapped] で使うユーザー ID
     */
    fun onAppear(coffeeId: String, userId: String) {
        currentCoffeeId = coffeeId
        currentUserId = userId
        observeJob?.cancel()
        observeJob = viewModelScope.launch {
            _state.update { it.copy(isLoading = true) }
            coffeeRepository.observeById(coffeeId).collect { coffee ->
                _state.update { it.copy(coffee = coffee, isLoading = false) }
            }
        }
    }

    /**
     * 右上メニューからの削除確定時に呼ぶ。
     *
     * coffeeId / userId は [onAppear] で受け取った値を内部で保持して使う。
     * [onAppear] 呼び出し前に本メソッドが呼ばれた場合は黙殺する（対象未確定）。
     * 成功時は [UIState.isDeleted] を true にする。画面側はこれを見て一覧へ pop する。
     */
    fun onDeleteTapped() {
        val coffeeId = currentCoffeeId ?: return
        val userId = currentUserId ?: return
        viewModelScope.launch {
            try {
                coffeeRepository.delete(userId, coffeeId)
                _state.update { it.copy(isDeleted = true) }
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
     * iOS Bridge の deinit または onDisappear で呼ぶこと（push/pop 画面のため必須）。
     * キャンセル後に [onAppear] が呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }
}

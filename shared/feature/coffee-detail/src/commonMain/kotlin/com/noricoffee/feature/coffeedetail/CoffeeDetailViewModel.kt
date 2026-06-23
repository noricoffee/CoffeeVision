package com.noricoffee.feature.coffeedetail

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
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
 * - [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する
 *
 * ## CoroutineScope の注意
 *
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。iOS 側では
 * `AppContainer.makeCoffeeDetailViewModel()` 経由で取得した ViewModel のスコープは
 * `AppContainer` が保持する `MainScope` と生存期間を共にする。
 */
class CoffeeDetailViewModel(
    private val coffeeRepository: CoffeeRepository,
    private val scope: CoroutineScope,
) {

    /**
     * コーヒー記録詳細画面の UI 状態。
     *
     * @property coffee 表示するコーヒー記録。null は「未ロード」または「対象が存在しない」状態を表す
     * @property isLoading 初回読み込み中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val coffee: CoffeeRecord? = null,
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 既に購読中の Flow の Job。onAppear が複数回呼ばれても二重購読しないために保持する。
    private var observeJob: Job? = null

    /**
     * 画面表示時に呼ぶ。[coffeeId] に対応するコーヒー記録の購読を開始する。
     *
     * 前回の購読をキャンセルしてから再購読するため、coffeeId が変わった場合や
     * タブ切り替えなどで `onAppear` が重複して呼ばれても状態が壊れない。
     *
     * @param coffeeId 表示対象の [CoffeeRecord.id]
     */
    fun onAppear(coffeeId: String) {
        observeJob?.cancel()
        observeJob = scope.launch {
            _state.update { it.copy(isLoading = true) }
            coffeeRepository.observeById(coffeeId).collect { coffee ->
                _state.update { it.copy(coffee = coffee, isLoading = false) }
            }
        }
    }

    /**
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null) }
    }
}

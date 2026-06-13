package com.noricoffee.feature.cafesearch

import com.noricoffee.domain.Cafe
import com.noricoffee.repository.CafeRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * カフェ検索画面の ViewModel。
 *
 * - ユーザーがクエリを入力し [onSearchTapped] を呼ぶことで [CafeRepository.searchText] を実行する
 * - [onQueryChanged] はクエリ文字列を更新するのみで検索は実行しない（API 消費を最小化する）
 * - 検索結果は [UIState.results] に反映され、ローディング中は [UIState.isLoading] が true になる
 * - エラーは [UIState.error] に詰め、[onErrorDismissed] で null に戻す
 *
 * ## 暫定配置について
 *
 * 本クラスはスライス 5 で `shared/feature/cafe-search` モジュールに移送する予定の暫定置き場として
 * `shared/core` に配置している。Phase 3 で `VisitListViewModel` 等を feature module に切り出す前と
 * 同じパターン（UI 実装を先行し、feature 切り出しは後続スライスで行う）。
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。
 *
 * @param cafeRepository カフェ検索を担うリポジトリ
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class CafeSearchViewModel(
    private val cafeRepository: CafeRepository,
    private val scope: CoroutineScope,
) {

    /**
     * カフェ検索画面の UI 状態。
     *
     * @property query 検索クエリ文字列
     * @property results 検索結果のカフェ一覧。初期値は空リスト
     * @property isLoading 検索実行中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val query: String = "",
        val results: List<Cafe> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 前回の検索 Job。再タップ時に cancel して新しいジョブを起動する。
    private var searchJob: Job? = null

    /**
     * 検索クエリを更新する。検索は実行しない。
     *
     * 入力フィールドの変更に連動して呼ぶ。[onSearchTapped] が呼ばれるまで検索は走らない。
     *
     * @param query 入力中のクエリ文字列
     */
    fun onQueryChanged(query: String) {
        _state.update { it.copy(query = query) }
    }

    /**
     * 検索ボタンタップ時に呼ぶ。現在の [UIState.query] で [CafeRepository.searchText] を実行する。
     *
     * 前回の検索 Job が実行中の場合はキャンセルして新しい検索を起動する。
     * 検索中は [UIState.isLoading] が true になり、完了後 false に戻る。
     * エラーが発生した場合は [UIState.error] にメッセージを詰める。
     */
    fun onSearchTapped() {
        val query = _state.value.query
        searchJob?.cancel()
        searchJob = scope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            runCatching { cafeRepository.searchText(query) }
                .onSuccess { cafes ->
                    _state.update { it.copy(results = cafes, isLoading = false) }
                }
                .onFailure { e ->
                    _state.update { it.copy(isLoading = false, error = e.message ?: "検索に失敗しました") }
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

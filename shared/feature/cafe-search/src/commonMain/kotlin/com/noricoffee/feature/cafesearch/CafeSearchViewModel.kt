package com.noricoffee.feature.cafesearch

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
import com.noricoffee.repository.CafeRepository
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
 * カフェ検索画面の ViewModel。
 *
 * - ユーザーがクエリを入力し [onSearchTapped] を呼ぶことで [CafeRepository.searchText] を実行する
 * - マップ中心座標が既知の場合は [onSearchTapped(latitude, longitude, radiusMeters)][onSearchTapped] を呼ぶと
 *   位置バイアス付きで検索される
 * - [onQueryChanged] はクエリ文字列を更新するのみで検索は実行しない（API 消費を最小化する）
 * - 検索結果は [UIState.results] に反映され、ローディング中は [UIState.isLoading] が true になる
 * - エラーは [UIState.error] に詰め、[onErrorDismissed] で null に戻す
 * - [UIState.hasSearched] により「まだ検索していない」と「検索したが 0 件だった」を区別する
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
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    /**
     * カフェ検索画面の UI 状態。
     *
     * @property query 検索クエリ文字列
     * @property results 検索結果のカフェ一覧。初期値は空リスト
     * @property isLoading 検索実行中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     * @property hasSearched 検索が少なくとも 1 回成功完了したかどうか。
     *   - `false`（初期値）: まだ検索を実行していない。UI は「該当なし」を出さず初期プロンプトを表示する
     *   - `true`: [onSearchTapped] または [onNearbySearchRequested] が成功完了した。
     *     [results] が空でも「該当なし」を表示してよい
     *   [onQueryChanged] が呼ばれると false に戻り、前回の検索結果表示を無効化する。
     *   失敗時（onFailure）は false のまま据え置く。[onErrorDismissed] では変更しない
     */
    data class UIState(
        val query: String = "",
        val results: List<Cafe> = emptyList(),
        val isLoading: Boolean = false,
        val error: String? = null,
        val hasSearched: Boolean = false,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 前回の検索 Job。再タップ時に cancel して新しいジョブを起動する。
    private var searchJob: Job? = null

    /**
     * 検索クエリを更新する。検索は実行しない。
     *
     * 入力フィールドの変更に連動して呼ぶ。[onSearchTapped] が呼ばれるまで検索は走らない。
     * 呼び出すたびに [UIState.hasSearched] を false にリセットし、前回の検索結果表示を無効化する。
     *
     * @param query 入力中のクエリ文字列
     */
    fun onQueryChanged(query: String) {
        _state.update { it.copy(query = query, hasSearched = false) }
    }

    /**
     * 検索ボタンタップ時に呼ぶ（位置バイアスなし）。現在の [UIState.query] で [CafeRepository.searchText] を実行する。
     *
     * マップ中心座標が不明な場合（検索タブ単体起動など）のフォールバック用。
     * 座標が既知の場合は [onSearchTapped(latitude, longitude, radiusMeters)] を優先して呼ぶこと。
     *
     * 前回の検索 Job が実行中の場合はキャンセルして新しい検索を起動する。
     * 検索中は [UIState.isLoading] が true になり、完了後 false に戻る。
     * 検索が成功完了したとき（結果が 0 件でも）[UIState.hasSearched] を true にする。
     * エラーが発生した場合は [UIState.error] にメッセージを詰め、[UIState.hasSearched] は変更しない。
     */
    fun onSearchTapped() {
        val query = _state.value.query
        launchSearch(errorMessage = "検索に失敗しました") {
            cafeRepository.searchText(query)
        }
    }

    /**
     * 検索ボタンタップ時に呼ぶ（位置バイアスあり）。現在の [UIState.query] を
     * [LocationBias] とともに [CafeRepository.searchText] に渡す。
     *
     * iOS のマップタブがカメラ中心座標を把握しているケースで呼ぶ。
     * バイアスなし版（引数なしの [onSearchTapped]）との 2 本立ては、SKIE がデフォルト引数を
     * Swift に引き出せないため既存の [CafeRepository] インターフェースと同様のオーバーロード戦略を踏襲している。
     *
     * 状態遷移（isLoading / error / results / hasSearched の更新）はバイアスなし版と完全に同一。
     *
     * @param latitude マップ中心の緯度
     * @param longitude マップ中心の経度
     * @param radiusMeters 位置バイアスの半径（メートル）。通常は 500.0 を渡す
     */
    fun onSearchTapped(latitude: Double, longitude: Double, radiusMeters: Double) {
        val query = _state.value.query
        launchSearch(errorMessage = "検索に失敗しました") {
            cafeRepository.searchText(query, LocationBias(latitude, longitude, radiusMeters))
        }
    }

    /**
     * 現在地周辺のカフェを検索する（半径省略版・デフォルト 500m）。
     *
     * [CafeRepository.searchNearby] をデフォルト半径（500m）で実行し、結果を [UIState.results] に反映する。
     * 現在地ボタンなど、表示範囲を考慮しない呼び出し元向け。表示範囲（マップの可視領域）に応じた
     * 半径で検索したい場合は [onNearbySearchRequested(latitude, longitude, radiusMeters)][onNearbySearchRequested] を使うこと。
     * [UIState.query] はテキスト検索のクエリとは独立しているため更新しない。
     *
     * 前回の検索 Job が実行中の場合はキャンセルして新しい検索を起動する。
     * 検索中は [UIState.isLoading] が true になり、完了後 false に戻る。
     * 検索が成功完了したとき（結果が 0 件でも）[UIState.hasSearched] を true にする。
     * エラーが発生した場合は [UIState.error] にメッセージを詰め、[UIState.hasSearched] は変更しない。
     *
     * @param latitude 現在地の緯度
     * @param longitude 現在地の経度
     */
    fun onNearbySearchRequested(latitude: Double, longitude: Double) {
        launchSearch(errorMessage = "近隣検索に失敗しました") {
            cafeRepository.searchNearby(latitude, longitude)
        }
    }

    /**
     * 指定座標周辺のカフェを、指定半径で検索する。
     *
     * [CafeRepository.searchNearby] に [radiusMeters] をそのまま渡して実行し、結果を [UIState.results] に反映する。
     * マップの「このエリアを検索」機能（表示範囲に応じた半径での一括ピン表示）向け。
     * 半径省略版（[onNearbySearchRequested(latitude, longitude)][onNearbySearchRequested]）との 2 本立ては、
     * SKIE がデフォルト引数を Swift に引き出せないため既存の [onSearchTapped] と同様のオーバーロード戦略を踏襲している。
     * [UIState.query] はテキスト検索のクエリとは独立しているため更新しない。
     *
     * 状態遷移（isLoading / error / results / hasSearched の更新）は半径省略版と完全に同一。
     *
     * @param latitude 検索中心の緯度（通常はマップの表示範囲の中心）
     * @param longitude 検索中心の経度（通常はマップの表示範囲の中心）
     * @param radiusMeters 検索半径（メートル）。呼び出し元がマップの表示範囲から算出して渡す
     */
    fun onNearbySearchRequested(latitude: Double, longitude: Double, radiusMeters: Double) {
        launchSearch(errorMessage = "近隣検索に失敗しました") {
            cafeRepository.searchNearby(latitude, longitude, radiusMeters)
        }
    }

    /**
     * 検索処理の共通実装。前回 Job のキャンセル・isLoading / error / results / hasSearched の
     * 状態遷移・CancellationException の再スローをまとめる。
     *
     * @param errorMessage エラー時に [UIState.error] へセットするデフォルトメッセージ
     * @param producer 実際の検索処理。成功時に [Cafe] リストを返す
     */
    private fun launchSearch(errorMessage: String, producer: suspend () -> List<Cafe>) {
        searchJob?.cancel()
        searchJob = viewModelScope.launch {
            _state.update { it.copy(isLoading = true, error = null) }
            try {
                val results = producer()
                _state.update { it.copy(results = results, isLoading = false, hasSearched = true) }
            } catch (e: CancellationException) {
                _state.update { it.copy(isLoading = false) }
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(isLoading = false, error = e.message ?: errorMessage) }
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
     * iOS Bridge の deinit で呼ぶこと（タブ常駐 VM のため画面遷移時は不要）。
     * キャンセル後に [onSearchTapped] が呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }
}

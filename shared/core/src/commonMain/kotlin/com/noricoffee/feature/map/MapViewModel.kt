package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * マップ画面の ViewModel。
 *
 * - [ObserveVisitedCafesUseCase] を常時購読し、訪問済みカフェのピンを [MapUiState.visitedCafes] で管理
 * - [onLocationUpdated] で現在地周辺のカフェ（周辺 Places）を [CafeRepository.searchNearby] で取得し、
 *   [MapUiState.nearbyPlaces] として公開する
 * - [onShowVisitedToggled] / [onShowNearbyToggled] でマップ上のピン表示 / 非表示を切り替える
 *
 * ## 暫定配置について
 *
 * 本クラスは `shared/feature/map` モジュール切り出し後に移送する予定の暫定置き場として
 * `shared/core` に配置している（[com.noricoffee.feature.cafesearch.CafeSearchViewModel] と同じパターン）。
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。
 *
 * @param observeVisitedCafesUseCase 訪問済みカフェ集計の UseCase
 * @param cafeRepository 周辺カフェ検索を担うリポジトリ
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class MapViewModel(
    private val observeVisitedCafesUseCase: ObserveVisitedCafesUseCase,
    private val cafeRepository: CafeRepository,
    private val userId: String,
    private val scope: CoroutineScope,
) {

    /**
     * マップ画面の UI 状態。
     *
     * @property visitedCafes 訪問済みカフェの集計一覧（マップ上の茶色ピン）
     * @property nearbyPlaces 現在地周辺の Places API 検索結果（マップ上のグレーピン）
     * @property showVisited 訪問済みカフェのピンを表示するか
     * @property showNearby 周辺カフェのピンを表示するか
     * @property isLoadingNearby 周辺カフェ検索中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     */
    data class UIState(
        val visitedCafes: List<VisitedCafe> = emptyList(),
        val nearbyPlaces: List<Cafe> = emptyList(),
        val showVisited: Boolean = true,
        val showNearby: Boolean = true,
        val isLoadingNearby: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 周辺検索 Job。新しい位置情報が来るたびにキャンセルして再起動する。
    private var nearbySearchJob: Job? = null

    init {
        // ViewModel 生成時に訪問済みカフェの購読を開始する。
        // scope がキャンセルされるまで継続購読する。
        scope.launch {
            observeVisitedCafesUseCase(userId).collect { visitedCafes ->
                _state.update { it.copy(visitedCafes = visitedCafes) }
            }
        }
    }

    /**
     * 現在地が更新されたときに呼ぶ。周辺カフェ検索を 500m 半径で実行する。
     *
     * 前回の検索 Job が実行中の場合はキャンセルして新しい検索を起動する
     * （[com.noricoffee.feature.cafesearch.CafeSearchViewModel.onNearbySearchRequested] と同パターン）。
     *
     * @param latitude 現在地の緯度
     * @param longitude 現在地の経度
     */
    fun onLocationUpdated(latitude: Double, longitude: Double) {
        nearbySearchJob?.cancel()
        nearbySearchJob = scope.launch {
            _state.update { it.copy(isLoadingNearby = true, error = null) }
            runCatching { cafeRepository.searchNearby(latitude, longitude) }
                .onSuccess { places ->
                    _state.update { it.copy(nearbyPlaces = places, isLoadingNearby = false) }
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            isLoadingNearby = false,
                            error = e.message ?: "周辺カフェの取得に失敗しました",
                        )
                    }
                }
        }
    }

    /**
     * 訪問済みカフェのピン表示 / 非表示を切り替える。
     *
     * @param show true のとき訪問済みピンを表示する
     */
    fun onShowVisitedToggled(show: Boolean) {
        _state.update { it.copy(showVisited = show) }
    }

    /**
     * 周辺カフェのピン表示 / 非表示を切り替える。
     *
     * @param show true のとき周辺ピンを表示する
     */
    fun onShowNearbyToggled(show: Boolean) {
        _state.update { it.copy(showNearby = show) }
    }

    /**
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null as String?) }
    }
}

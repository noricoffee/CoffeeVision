package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
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
     * @property isLookingUpPoi Apple Maps POI タップ後の Places ルックアップ中かどうか
     * @property poiLookupResult POI ルックアップで取得した [Cafe]。View が消費（NavigationPath への append 等）
     *   したあと [onPoiLookupConsumed] を呼んで null に戻すこと
     * @property poiLookupError POI ルックアップで発生したエラーメッセージ。
     *   alert を閉じたあと [onPoiLookupErrorDismissed] を呼んで null に戻すこと
     */
    data class UIState(
        val visitedCafes: List<VisitedCafe> = emptyList(),
        val nearbyPlaces: List<Cafe> = emptyList(),
        val showVisited: Boolean = true,
        val showNearby: Boolean = true,
        val isLoadingNearby: Boolean = false,
        val error: String? = null,
        val isLookingUpPoi: Boolean = false,
        val poiLookupResult: Cafe? = null,
        val poiLookupError: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // 周辺検索 Job。新しい位置情報が来るたびにキャンセルして再起動する。
    private var nearbySearchJob: Job? = null

    // POI ルックアップ Job。POI タップのたびにキャンセルして再起動する（連打耐性）。
    private var poiLookupJob: Job? = null

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

    /**
     * Apple Maps の POI（地図上のカフェ / 飲食店アイコン等）をタップした際に呼ぶ。
     *
     * [CafeRepository.searchText] を位置バイアス付きで呼び出し、最も近い候補を [UIState.poiLookupResult] にセットする。
     * 連打された場合は前回の Job をキャンセルして新しい Job を起動する（`searchJob` 再起動パターン）。
     *
     * ## 状態遷移
     * 1. `isLookingUpPoi = true`, `poiLookupError = null`
     * 2. `cafeRepository.searchText(name, LocationBias(lat, lng, 500.0))` を呼ぶ
     * 3. 結果が空 → `poiLookupError = "該当するカフェが見つかりませんでした"`
     * 4. 結果あり → `poiLookupResult = results.first()`
     * 5. 例外 → `poiLookupError = e.message ?: "カフェ情報の取得に失敗しました"`
     * 6. `isLookingUpPoi = false`
     *
     * @param name POI の表示名（Apple Maps から取得した `MapFeature.title`）
     * @param latitude POI の緯度
     * @param longitude POI の経度
     */
    fun onPoiTapped(name: String, latitude: Double, longitude: Double) {
        poiLookupJob?.cancel()
        poiLookupJob = scope.launch {
            _state.update { it.copy(isLookingUpPoi = true, poiLookupError = null as String?) }
            runCatching {
                cafeRepository.searchText(
                    query = name,
                    locationBias = LocationBias(
                        latitude = latitude,
                        longitude = longitude,
                        radiusMeters = 500.0,
                    ),
                )
            }
                .onSuccess { results ->
                    if (results.isEmpty()) {
                        _state.update {
                            it.copy(
                                isLookingUpPoi = false,
                                poiLookupError = "該当するカフェが見つかりませんでした",
                            )
                        }
                    } else {
                        _state.update {
                            it.copy(
                                isLookingUpPoi = false,
                                poiLookupResult = results.first(),
                            )
                        }
                    }
                }
                .onFailure { e ->
                    _state.update {
                        it.copy(
                            isLookingUpPoi = false,
                            poiLookupError = e.message ?: "カフェ情報の取得に失敗しました",
                        )
                    }
                }
        }
    }

    /**
     * View が [UIState.poiLookupResult] を消費したあとに呼ぶ。
     *
     * NavigationPath への `CafeDetailRoute` append など、結果を受け取ったあと
     * このメソッドを呼ぶことで [UIState.poiLookupResult] を null に戻す。
     * 次のタップまで古い結果が残って誤作動するのを防ぐため、必ず呼ぶこと。
     */
    fun onPoiLookupConsumed() {
        _state.update { it.copy(poiLookupResult = null as Cafe?) }
    }

    /**
     * POI ルックアップエラーの alert を閉じた際に呼ぶ。[UIState.poiLookupError] を null に戻す。
     */
    fun onPoiLookupErrorDismissed() {
        _state.update { it.copy(poiLookupError = null as String?) }
    }
}

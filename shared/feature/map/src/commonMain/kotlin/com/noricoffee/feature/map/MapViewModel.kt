package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import kotlinx.coroutines.CancellationException
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
 * - [ObserveVisitedCafesUseCase] を常時購読し、訪問済みカフェのピンを [UIState.visitedCafes] で管理
 * - [CafeRecommendationProvider] を常時購読し、好み一致カフェのピン強調を [UIState.recommendedCafes] で管理
 * - [onPoiTapped] で Apple Maps POI タップ時に Places 解決（searchText 経路）を実行する
 * - [onShowVisitedToggled] でマップ上の訪問済みピン表示 / 非表示を切り替える
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。
 *
 * @param observeVisitedCafesUseCase 訪問済みカフェ集計の UseCase
 * @param cafeRecommendationProvider 好み一致カフェの推薦プロバイダ（v1 = [com.noricoffee.domain.usecase.ObserveTasteMatchedCafesUseCase]）
 * @param cafeRepository POI タップ時の Places テキスト検索を担うリポジトリ
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class MapViewModel(
    private val observeVisitedCafesUseCase: ObserveVisitedCafesUseCase,
    private val cafeRecommendationProvider: CafeRecommendationProvider,
    private val cafeRepository: CafeRepository,
    private val userId: String,
    private val scope: CoroutineScope,
) {

    /**
     * マップ画面の UI 状態。
     *
     * @property visitedCafes 訪問済みカフェの集計一覧（マップ上の茶色ピン）
     * @property recommendedCafes 好み一致カフェの推薦一覧（マップ上のアクセントカラーピン）。
     *   [com.noricoffee.domain.model.CafeRecommendationProvider] が算出する。FavoriteSignals 不足時は空。
     *   matches 件数降順 → 代表評価降順 → placeId 昇順
     * @property recommendedPlaceIds [recommendedCafes] から導出した placeId の集合。
     *   iOS 側のマップピン強調（区別ピン判定）に使う
     * @property showVisited 訪問済みカフェのピンを表示するか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     * @property isLookingUpPoi Apple Maps POI タップ後の Places ルックアップ中かどうか
     * @property poiLookupResult POI ルックアップで取得した [Cafe]。View が消費（NavigationPath への append 等）
     *   したあと [onPoiLookupConsumed] を呼んで null に戻すこと
     * @property poiLookupError POI ルックアップで発生したエラーメッセージ。
     *   alert を閉じたあと [onPoiLookupErrorDismissed] を呼んで null に戻すこと
     */
    data class UIState(
        val visitedCafes: List<VisitedCafe> = emptyList(),
        val recommendedCafes: List<RecommendedCafe> = emptyList(),
        val recommendedPlaceIds: Set<String> = emptySet(),
        val showVisited: Boolean = true,
        val error: String? = null,
        val isLookingUpPoi: Boolean = false,
        val poiLookupResult: Cafe? = null,
        val poiLookupError: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

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

        // 好み一致カフェ推薦の購読を開始する。
        // FavoriteSignals が算出されるたびに自動更新する（ObserveVisitedCafesUseCase と同じパターン）。
        scope.launch {
            cafeRecommendationProvider.observeRecommendedCafes(userId).collect { recommended ->
                _state.update {
                    it.copy(
                        recommendedCafes = recommended,
                        recommendedPlaceIds = recommended.map { rc -> rc.cafe.placeId }.toSet(),
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
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null) }
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
            _state.update { it.copy(isLookingUpPoi = true, poiLookupError = null) }
            try {
                val results = cafeRepository.searchText(
                    query = name,
                    locationBias = LocationBias(
                        latitude = latitude,
                        longitude = longitude,
                        radiusMeters = 500.0,
                    ),
                )
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
            } catch (e: CancellationException) {
                _state.update { it.copy(isLookingUpPoi = false) }
                throw e
            } catch (e: Exception) {
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
        _state.update { it.copy(poiLookupResult = null) }
    }

    /**
     * POI ルックアップエラーの alert を閉じた際に呼ぶ。[UIState.poiLookupError] を null に戻す。
     */
    fun onPoiLookupErrorDismissed() {
        _state.update { it.copy(poiLookupError = null) }
    }
}

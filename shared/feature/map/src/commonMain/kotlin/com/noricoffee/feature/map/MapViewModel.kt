package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
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
 * @param coffeeRepository タグフィルタ用のコーヒー記録リポジトリ
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class MapViewModel(
    private val observeVisitedCafesUseCase: ObserveVisitedCafesUseCase,
    private val cafeRecommendationProvider: CafeRecommendationProvider,
    private val cafeRepository: CafeRepository,
    private val coffeeRepository: CoffeeRepository,
    private val userId: String,
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

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
     * @property searchResultPlaces 検索タブの検索結果カフェ一覧（マップ上の第 4 種ピン）。
     *   空リストのとき非表示。[onSearchResultsUpdated] で更新し [onSearchResultsCleared] でクリアする。
     *   永続化しない一時データ（タブ切り替えや別カフェ選択まで保持する）
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     * @property isLookingUpPoi Apple Maps POI タップ後の Places ルックアップ中かどうか
     * @property poiLookupResult POI ルックアップで取得した [Cafe]。View が消費（NavigationPath への append 等）
     *   したあと [onPoiLookupConsumed] を呼んで null に戻すこと
     * @property poiLookupError POI ルックアップで発生したエラーメッセージ。
     *   alert を閉じたあと [onPoiLookupErrorDismissed] を呼んで null に戻すこと
     * @property selectedTags 現在選択中のタグフィルタ集合。空のとき全カフェを表示。
     *   [onTagFilterToggled] で on/off を切り替え、[onTagFilterCleared] で全解除する
     * @property availableTags すべてのコーヒー記録から収集した重複なし・昇順ソート済みタグ一覧。
     *   フィルタ UI のチップ表示に使う
     */
    data class UIState(
        val visitedCafes: List<VisitedCafe> = emptyList(),
        val recommendedCafes: List<RecommendedCafe> = emptyList(),
        val recommendedPlaceIds: Set<String> = emptySet(),
        val showVisited: Boolean = true,
        val searchResultPlaces: List<Cafe> = emptyList(),
        val error: String? = null,
        val isLookingUpPoi: Boolean = false,
        val poiLookupResult: Cafe? = null,
        val poiLookupError: String? = null,
        val selectedTags: Set<String> = emptySet(),
        val availableTags: List<String> = emptyList(),
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // POI ルックアップ Job。POI タップのたびにキャンセルして再起動する（連打耐性）。
    private var poiLookupJob: Job? = null

    // visitedCafes/coffeeRecords の最新値をキャッシュする。
    // タグ選択が変化した際に collect を待たずに即時フィルタを再適用するために保持する。
    private var latestVisitedCafes: List<VisitedCafe> = emptyList()
    private var latestCafeTagsMap: Map<String, Set<String>> = emptyMap()
    private var latestAvailableTags: List<String> = emptyList()

    init {
        // visitedCafes と全コーヒー記録を combine して、タグフィルタ済みカフェと
        // availableTags を算出し UIState に反映する。
        // _selectedTagsFlow を combine に含めると MutableStateFlow が終了せず runTest がタイムアウトするため、
        // 選択タグの変化は onTagFilterToggled / onTagFilterCleared → applyTagFilter() で即時反映する設計にする。
        viewModelScope.launch {
            combine(
                observeVisitedCafesUseCase(userId),
                coffeeRepository.observeAll(userId),
            ) { visitedCafes, allRecords ->
                // placeId -> そのカフェの全記録に含まれるタグの集合
                val cafeTagsMap = allRecords
                    .filter { it.cafe != null && it.tags.isNotEmpty() }
                    .groupBy { it.cafe!!.placeId }
                    .mapValues { (_, records) -> records.flatMap { it.tags }.toSet() }

                // 全記録のタグを重複排除・昇順ソート
                val availableTags = allRecords
                    .flatMap { it.tags }
                    .distinct()
                    .sorted()

                Triple(visitedCafes, cafeTagsMap, availableTags)
            }.collect { result ->
                latestVisitedCafes = result.first
                latestCafeTagsMap = result.second
                latestAvailableTags = result.third
                applyTagFilter()
            }
        }

        // 好み一致カフェ推薦の購読を開始する。
        // FavoriteSignals が算出されるたびに自動更新する（ObserveVisitedCafesUseCase と同じパターン）。
        viewModelScope.launch {
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
     * 現在のキャッシュデータと [UIState.selectedTags] を使ってフィルタを適用し、
     * [UIState.visitedCafes] と [UIState.availableTags] を更新する。
     *
     * - [observeVisitedCafesUseCase] または [coffeeRepository] の新データ到着時
     * - [onTagFilterToggled] / [onTagFilterCleared] でタグ選択が変化した時
     * の両方で呼ばれる。
     */
    private fun applyTagFilter() {
        val selectedTags = _state.value.selectedTags
        val filteredCafes = if (selectedTags.isEmpty()) {
            latestVisitedCafes
        } else {
            latestVisitedCafes.filter { vc ->
                val cafeTags = latestCafeTagsMap[vc.cafe.placeId] ?: emptySet()
                cafeTags.containsAll(selectedTags)
            }
        }
        _state.update {
            it.copy(
                visitedCafes = filteredCafes,
                availableTags = latestAvailableTags,
            )
        }
    }

    /**
     * タグフィルタを on/off する。
     *
     * [tag] が現在の [UIState.selectedTags] に含まれている場合は除外し、含まれていない場合は追加する。
     * フィルタは即時再適用される（[applyTagFilter] を呼ぶ）。
     *
     * @param tag トグルするタグ文字列
     */
    fun onTagFilterToggled(tag: String) {
        val current = _state.value.selectedTags
        val newTags = if (current.contains(tag)) current - tag else current + tag
        _state.update { it.copy(selectedTags = newTags) }
        applyTagFilter()
    }

    /**
     * すべてのタグフィルタを解除する。
     *
     * [UIState.visitedCafes] がフィルタなしの全カフェ一覧に戻る。
     */
    fun onTagFilterCleared() {
        _state.update { it.copy(selectedTags = emptySet()) }
        applyTagFilter()
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
        poiLookupJob = viewModelScope.launch {
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

    /**
     * 検索タブで取得した検索結果カフェ一覧をマップにオーバーレイ表示する際に呼ぶ。
     *
     * [UIState.searchResultPlaces] を [cafes] で上書きする。
     * 空リストを渡した場合はピンが非表示になる（[onSearchResultsCleared] と等価）。
     * iOS の AppState が検索タブ → マップタブの連携として呼び出す想定。
     *
     * @param cafes 検索結果の [Cafe] リスト。空リストでも可
     */
    fun onSearchResultsUpdated(cafes: List<Cafe>) {
        _state.update { it.copy(searchResultPlaces = cafes) }
    }

    /**
     * マップ上の検索結果オーバーレイピンをクリアする。
     *
     * [UIState.searchResultPlaces] を空リストに戻す。
     * 検索タブの検索内容がリセットされた際や、別の操作でオーバーレイが不要になった際に呼ぶ。
     */
    fun onSearchResultsCleared() {
        _state.update { it.copy(searchResultPlaces = emptyList()) }
    }

    /**
     * 画面破棄時に呼ぶ。内部の viewModelScope をキャンセルして全コルーチンを停止する。
     *
     * iOS Bridge の deinit で呼ぶこと（タブ常駐 VM のため onDisappear では不要）。
     * キャンセル後に各メソッドが呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }
}

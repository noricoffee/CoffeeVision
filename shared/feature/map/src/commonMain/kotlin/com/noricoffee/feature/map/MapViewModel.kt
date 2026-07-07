package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
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
import kotlinx.datetime.Clock

/**
 * マップ画面の ViewModel。
 *
 * - [ObserveVisitedCafesUseCase] を常時購読し、訪問済みカフェのピンを [UIState.visitedCafes] で管理
 * - [CafeRecommendationProvider] を常時購読し、好み一致カフェのピン強調を [UIState.recommendedCafes] で管理
 * - [onPoiTapped] で Apple Maps POI タップ時に Places 解決（searchNearby 経路）を実行する
 * - [onShowVisitedToggled] でマップ上の訪問済みピン表示 / 非表示を切り替える
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。
 *
 * @param observeVisitedCafesUseCase 訪問済みカフェ集計の UseCase
 * @param cafeRecommendationProvider 好み一致カフェの推薦プロバイダ（v1 = [com.noricoffee.domain.usecase.ObserveTasteMatchedCafesUseCase]）
 * @param cafeRepository POI タップ時の Places 座標近傍検索を担うリポジトリ
 * @param coffeeRepository タグフィルタ用のコーヒー記録リポジトリ
 * @param savedCafeRepository 「行きたい店」の購読 / 解除を担うリポジトリ（フェーズ 15-A）
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class MapViewModel(
    private val observeVisitedCafesUseCase: ObserveVisitedCafesUseCase,
    private val cafeRecommendationProvider: CafeRecommendationProvider,
    private val cafeRepository: CafeRepository,
    private val coffeeRepository: CoffeeRepository,
    private val savedCafeRepository: SavedCafeRepository,
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
        /**
         * テイストプロファイルフィルタが active なときのマッチカフェ placeId 集合。
         * 空 = フィルタ未設定または非マッチ。[onTasteProfileChanged] で更新する。
         */
        val tasteMatchedPlaceIds: Set<String> = emptySet(),
        /**
         * アクティブなテイストフィルタの下限スコア。null = 下限なし。バッジ表示用。
         */
        val activeTastingMin: TastingScores? = null,
        /**
         * アクティブなテイストフィルタの上限スコア。null = 上限なし。
         */
        val activeTastingMax: TastingScores? = null,
        /**
         * 「行きたい店」一覧（savedAt 降順、フェーズ 15-A）。マップの 4 種目ピン / 一覧シート用。
         * [com.noricoffee.repository.SavedCafeRepository.observeAll] を購読して常時最新化する。
         */
        val savedCafes: List<SavedCafe> = emptyList(),
        /**
         * 記録（[VisitedCafe]）があるカフェの placeId 集合（フェーズ 15-A）。タグフィルタに左右されない
         * 全件ベースの集合で、行きたい一覧の「記録あり」バッジ判定に使う。
         */
        val recordedPlaceIds: Set<String> = emptySet(),
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // POI ルックアップ Job。POI タップのたびにキャンセルして再起動する（連打耐性）。
    private var poiLookupJob: Job? = null

    // visitedCafes/coffeeRecords の最新値をキャッシュする。
    // タグ選択・テイストフィルタが変化した際に collect を待たずに即時フィルタを再適用するために保持する。
    private var latestVisitedCafes: List<VisitedCafe> = emptyList()
    private var latestCafeTagsMap: Map<String, Set<String>> = emptyMap()
    private var latestAvailableTags: List<String> = emptyList()
    private var latestAllRecords: List<CoffeeRecord> = emptyList()

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

                Triple(visitedCafes, cafeTagsMap, availableTags) to allRecords
            }.collect { (triple, allRecords) ->
                latestVisitedCafes = triple.first
                latestCafeTagsMap = triple.second
                latestAvailableTags = triple.third
                latestAllRecords = allRecords
                applyTagFilter()
                applyTasteFilter()
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

        // 「行きたい店」一覧の購読を開始する（フェーズ 15-A）。savedAt 降順は SQLDelight クエリ側で保証済み。
        viewModelScope.launch {
            savedCafeRepository.observeAll(userId).collect { savedCafes ->
                _state.update { it.copy(savedCafes = savedCafes) }
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
     *
     * [UIState.recordedPlaceIds] は [latestVisitedCafes]（タグフィルタ適用前の全件）から算出するため、
     * タグフィルタの影響を受けない（行きたい一覧の「記録あり」バッジ判定用）。
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
                recordedPlaceIds = latestVisitedCafes.map { vc -> vc.cafe.placeId }.toSet(),
            )
        }
    }

    /**
     * 現在のキャッシュデータと [UIState.activeTastingMin] / [UIState.activeTastingMax] を使って
     * テイストプロファイルフィルタを適用し、[UIState.tasteMatchedPlaceIds] を更新する。
     *
     * - [coffeeRepository] の新データ到着時（[combine] の collect）
     * - [onTasteProfileChanged] でフィルタ条件が変化した時
     * の両方で呼ばれる。
     *
     * フィルタが未設定（min / max 共に null）のときは [UIState.tasteMatchedPlaceIds] を空にする。
     * `record.cafe` が null（セルフ抽出）または `record.tasting` が null の記録は除外する。
     */
    private fun applyTasteFilter() {
        val tastingMin = _state.value.activeTastingMin
        val tastingMax = _state.value.activeTastingMax
        val placeIds = if (tastingMin == null && tastingMax == null) {
            emptySet()
        } else {
            latestAllRecords
                .filter { record ->
                    val tasting = record.tasting ?: return@filter false
                    record.cafe ?: return@filter false
                    tastingMin?.let { min ->
                        if (tasting.sweetness < min.sweetness) return@filter false
                        if (tasting.body < min.body) return@filter false
                        if (tasting.acidity < min.acidity) return@filter false
                        if (tasting.flavor < min.flavor) return@filter false
                        if (tasting.aftertaste < min.aftertaste) return@filter false
                    }
                    tastingMax?.let { max ->
                        if (tasting.sweetness > max.sweetness) return@filter false
                        if (tasting.body > max.body) return@filter false
                        if (tasting.acidity > max.acidity) return@filter false
                        if (tasting.flavor > max.flavor) return@filter false
                        if (tasting.aftertaste > max.aftertaste) return@filter false
                    }
                    true
                }
                .mapNotNull { it.cafe?.placeId }
                .toSet()
        }
        _state.update { it.copy(tasteMatchedPlaceIds = placeIds) }
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
     * 「今飲みたい味」テイストプロファイルフィルタを更新する。
     *
     * 両方 null を渡すとフィルタを解除する（[UIState.tasteMatchedPlaceIds] が空になる）。
     * フィルタが設定されると [latestAllRecords] のうち tasting が範囲内の記録が紐付く
     * カフェの placeId 集合を算出し、[UIState.tasteMatchedPlaceIds] を即時更新する。
     *
     * @param tastingMin テイスティングスコア下限。null = 下限なし
     * @param tastingMax テイスティングスコア上限。null = 上限なし
     */
    fun onTasteProfileChanged(tastingMin: TastingScores?, tastingMax: TastingScores?) {
        _state.update { it.copy(activeTastingMin = tastingMin, activeTastingMax = tastingMax) }
        applyTasteFilter()
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
     * [CafeRepository.searchNearby] を座標アンカーで呼び出し、最も近い候補を [UIState.poiLookupResult] にセットする。
     * 連打された場合は前回の Job をキャンセルして新しい Job を起動する（`searchJob` 再起動パターン）。
     *
     * 座標アンカーの近傍検索を採用しているのは、[CafeRepository.searchText] の `includedType=cafe` ハード
     * フィルタが Apple↔Google の表示名差や `coffee_shop` プライマリ型（チェーン店に多い）の店で空振りしやすく、
     * 見えているピンをタップしても解決できない不整合を起こしていたため（フェーズ 17-B）。
     *
     * ## 状態遷移
     * 1. `isLookingUpPoi = true`, `poiLookupError = null`
     * 2. `cafeRepository.searchNearby(latitude, longitude, radiusMeters = 150.0)` を呼ぶ（DISTANCE ランク済のため `.first()` を採用）
     * 3. 結果が空 → `poiLookupError = "該当するカフェが見つかりませんでした"`
     * 4. 結果あり → `poiLookupResult = results.first()`
     * 5. 例外 → `poiLookupError = e.message ?: "カフェ情報の取得に失敗しました"`
     * 6. `isLookingUpPoi = false`
     *
     * @param name POI の表示名（Apple Maps から取得した `MapFeature.title`）。座標解決のため検索クエリには使わないが、
     *   呼び出し元（iOS Bridge）のシグネチャ安定のため引数として残す
     * @param latitude POI の緯度
     * @param longitude POI の経度
     */
    fun onPoiTapped(name: String, latitude: Double, longitude: Double) {
        poiLookupJob?.cancel()
        poiLookupJob = viewModelScope.launch {
            _state.update { it.copy(isLookingUpPoi = true, poiLookupError = null) }
            try {
                val results = cafeRepository.searchNearby(
                    latitude = latitude,
                    longitude = longitude,
                    radiusMeters = 150.0,
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
     * 「行きたい店」一覧シートでのスワイプ解除操作を受ける（フェーズ 15-A）。
     *
     * [SavedCafeRepository.delete] を呼び、成功すれば [UIState.savedCafes] の購読が
     * 自動で更新される（明示的な _state.update は不要）。
     *
     * @param placeId 解除するカフェの Google Places ID
     */
    fun onSavedCafeRemoved(placeId: String) {
        viewModelScope.launch {
            try {
                savedCafeRepository.delete(userId, placeId)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message ?: "行きたい店の解除に失敗しました") }
            }
        }
    }

    /**
     * マップ上のフィルタチップ / ピン等から「行きたい店」の保存 / 解除をトグルする（フェーズ 16）。
     *
     * [UIState.savedCafes] に [cafe] の `placeId` が含まれていれば [SavedCafeRepository.delete] で解除し、
     * 含まれていなければ [cafe] のスナップショットから [SavedCafe] を作って [SavedCafeRepository.save] する。
     * どちらも成功すれば [UIState.savedCafes] の購読が自動で更新される（明示的な _state.update は不要）。
     * `note` は v1 では常に空文字（[com.noricoffee.feature.cafedetail.CafeDetailViewModel.onSaveToggled] と同じ扱い）。
     *
     * @param cafe トグル対象のカフェ（マップピン / 検索結果 / 一覧シート等から渡される Cafe スナップショット）
     */
    fun onCafeSaveToggled(cafe: Cafe) {
        val isSaved = _state.value.savedCafes.any { it.cafe.placeId == cafe.placeId }
        viewModelScope.launch {
            try {
                if (isSaved) {
                    savedCafeRepository.delete(userId, cafe.placeId)
                } else {
                    savedCafeRepository.save(
                        SavedCafe(
                            userId = userId,
                            cafe = cafe,
                            note = "",
                            savedAt = Clock.System.now(),
                        )
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(error = e.message ?: "行きたい店の保存 / 解除に失敗しました") }
            }
        }
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

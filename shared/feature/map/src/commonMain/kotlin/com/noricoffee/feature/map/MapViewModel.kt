package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.CuratedCafe
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.CuratedCafeRepository
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
import kotlin.math.PI
import kotlin.math.cos

/**
 * マップ画面の ViewModel。
 *
 * - [ObserveVisitedCafesUseCase] を常時購読し、訪問済みカフェのピンを [UIState.visitedCafes] で管理
 * - [CafeRecommendationProvider] を常時購読し、好み一致カフェのピン強調を [UIState.recommendedCafes] で管理
 * - [onPoiTapped] で Apple Maps POI タップ時に Places 解決（searchNearby 経路 + 名前による曖昧性解消）を実行する
 * - [onShowVisitedToggled] でマップ上の訪問済みピン表示 / 非表示を切り替える
 * - [curatedCafeRepository] から都道府県別おすすめカフェを one-shot 一括ロードし、
 *   [UIState.curatedCafes] / [UIState.curatedPlaceIds] で管理する（フェーズ 19。トグルなし常時表示）
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
 * @param curatedCafeRepository 都道府県別おすすめカフェの取得を担うリポジトリ（フェーズ 19）
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
class MapViewModel(
    private val observeVisitedCafesUseCase: ObserveVisitedCafesUseCase,
    private val cafeRecommendationProvider: CafeRecommendationProvider,
    private val cafeRepository: CafeRepository,
    private val coffeeRepository: CoffeeRepository,
    private val savedCafeRepository: SavedCafeRepository,
    private val curatedCafeRepository: CuratedCafeRepository,
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
     * @property searchResultPlaces マップ内埋め込み検索バーの検索結果カフェ一覧（検索結果ピン用）。
     *   空リストのとき非表示。[onSearchResultsUpdated] で更新し [onSearchResultsCleared] でクリアする。
     *   永続化しない一時データ（タブ切り替えや別カフェ選択まで保持する）
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     * @property isLookingUpPoi Apple Maps POI タップ後の Places ルックアップ中かどうか
     * @property poiLookupResult POI ルックアップで取得した [Cafe]。View が消費（NavigationPath への append 等）
     *   したあと [onPoiLookupConsumed] を呼んで null に戻すこと
     * @property poiLookupError POI ルックアップで発生したエラー。
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
        val poiLookupError: PoiLookupError? = null,
        val selectedTags: Set<String> = emptySet(),
        val availableTags: List<String> = emptyList(),
        /**
         * 「行きたい店」一覧（savedAt 降順、フェーズ 15-A）。マップの行きたい店ピン / 一覧シート用。
         * [com.noricoffee.repository.SavedCafeRepository.observeAll] を購読して常時最新化する。
         */
        val savedCafes: List<SavedCafe> = emptyList(),
        /**
         * 記録（[VisitedCafe]）があるカフェの placeId 集合（フェーズ 15-A）。タグフィルタに左右されない
         * 全件ベースの集合で、行きたい一覧の「記録あり」バッジ判定に使う。
         */
        val recordedPlaceIds: Set<String> = emptySet(),
        /**
         * 都道府県別おすすめカフェ一覧（フェーズ 19）。マップ上の専用ピン（amber + star、トグルなし常時表示）用。
         * 起動時に [CuratedCafeRepository.getAll] で一括ロードし、以降は不変（購読なし。one-shot）。
         * 失敗時は空リストのまま（[UIState.error] には流さない。おすすめは付加情報でマップ本体を阻害しない）。
         *
         * 47 県フル展開時（約 1,400 件）は Annotation 描画数の観点から iOS 側で可視領域フィルタを
         * 導入する必要がある（v1 の初期スコープは東京のみ・100 件なので本 UIState は未フィルタで返す）。
         */
        val curatedCafes: List<CuratedCafe> = emptyList(),
        /**
         * [curatedCafes] から導出した placeId の集合。iOS 側のピン重複判定
         * （訪問済み・保存済み・検索結果との placeId 競合時の表示優先順位判定）に使う。
         */
        val curatedPlaceIds: Set<String> = emptySet(),
    )

    /**
     * POI ルックアップ（[onPoiTapped]）で発生したエラーを表す。Swift からは SKIE 経由で
     * `MapViewModel.PoiLookupError` として参照される公開 API。
     *
     * [isNotFound] で「検索結果が空（該当なし）」と「例外（通信エラー等）」を区別する。
     * これは Apple `.cafe` 誤分類対策のネガティブキャッシュ（該当なし POI のみをローカル記録して
     * 以後非表示にする）を iOS 側で実装するために必要な区別で、通信エラー時はキャッシュしない
     * 判断材料として使う。
     *
     * @property message 表示用エラーメッセージ（alert 等にそのまま表示する文言）
     * @property isNotFound true = 検索結果が空（該当なし）/ false = 例外（通信エラー等）
     */
    data class PoiLookupError(
        val message: String,
        val isNotFound: Boolean,
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
            }.collect { (visitedCafes, cafeTagsMap, availableTags) ->
                latestVisitedCafes = visitedCafes
                latestCafeTagsMap = cafeTagsMap
                latestAvailableTags = availableTags
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

        // 「行きたい店」一覧の購読を開始する（フェーズ 15-A）。savedAt 降順は SQLDelight クエリ側で保証済み。
        viewModelScope.launch {
            savedCafeRepository.observeAll(userId).collect { savedCafes ->
                _state.update { it.copy(savedCafes = savedCafes) }
            }
        }

        // 都道府県別おすすめカフェの一括ロード（フェーズ 19）。one-shot（購読なし）。
        // 失敗時は黙って空のまま（おすすめは付加情報。UIState.error には流さない）。
        viewModelScope.launch {
            try {
                val curatedCafes = curatedCafeRepository.getAll()
                _state.update {
                    it.copy(
                        curatedCafes = curatedCafes,
                        curatedPlaceIds = curatedCafes.map { cc -> cc.placeId }.toSet(),
                    )
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // サイレント失敗（意図的）。詳細は UIState.curatedCafes の KDoc を参照。
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
     * [CafeRepository.searchByNameNear] を [name] + 位置バイアスで呼び出し、返った候補の中から
     * タップ座標に最も近いもの（[name] 一致を優先）を [UIState.poiLookupResult] にセットする。
     * 連打された場合は前回の Job をキャンセルして新しい Job を起動する（`searchJob` 再起動パターン）。
     *
     * ## なぜ型フィルタなしの名前+位置検索か（フェーズ 17-B → 17-C → 17-D）
     * - 17-B: `searchText` の `includedType=cafe` フィルタは Apple↔Google の表示名差や `coffee_shop`
     *   型（チェーン店に多い）で空振りしやすく、見えるピンがタップで解決できなかった。
     * - 17-C: 代替に `searchNearby([cafe, coffee_shop])` の最近傍を採ったが、座標ズレ・近接複数店で別店を拾った。
     * - 17-D: さらに Apple が cafe 分類する店でも Google では `cafe`/`coffee_shop` 型でない店（ランドリー併設・
     *   食事カフェ等）は `searchNearby` の候補に入らず、近傍の唯一の cafe 型の店に**全部フォールバック**して
     *   しまう不具合が判明。真因は型フィルタそのもの。そこで型フィルタを外した名前+位置検索
     *   （[CafeRepository.searchByNameNear]）に切り替え、候補からタップ座標最近傍（名前一致優先）を選ぶ。
     *
     * 見つからない場合は近傍の別店にフォールバックせず「該当なし」にする（自信満々に別店を開く挙動の排除）。
     *
     * ## 状態遷移
     * 1. `isLookingUpPoi = true`, `poiLookupError = null`
     * 2. `cafeRepository.searchByNameNear(name, LocationBias(latitude, longitude, 200m))` を呼ぶ
     * 3. 結果が空 → `poiLookupError = PoiLookupError("該当するカフェが見つかりませんでした", isNotFound = true)`
     * 4. 結果あり → [selectBestPoiMatch] でタップ座標最近傍（[name] 一致優先）を選び `poiLookupResult` にセット
     * 5. 例外 → `poiLookupError = PoiLookupError(e.message ?: "カフェ情報の取得に失敗しました", isNotFound = false)`
     * 6. `isLookingUpPoi = false`
     *
     * @param name POI の表示名（Apple Maps から取得した `MapFeature.title`）。検索クエリ兼、候補内の
     *   曖昧性解消（[namesMatch]）に使う
     * @param latitude POI の緯度
     * @param longitude POI の経度
     */
    fun onPoiTapped(name: String, latitude: Double, longitude: Double) {
        poiLookupJob?.cancel()
        poiLookupJob = viewModelScope.launch {
            _state.update { it.copy(isLookingUpPoi = true, poiLookupError = null) }
            try {
                val results = cafeRepository.searchByNameNear(
                    query = name,
                    locationBias = LocationBias(
                        latitude = latitude,
                        longitude = longitude,
                        radiusMeters = 200.0,
                    ),
                )
                if (results.isEmpty()) {
                    _state.update {
                        it.copy(
                            isLookingUpPoi = false,
                            poiLookupError = PoiLookupError(
                                message = "該当するカフェが見つかりませんでした",
                                isNotFound = true,
                            ),
                        )
                    }
                } else {
                    val resolved = selectBestPoiMatch(results, name, latitude, longitude)
                    _state.update {
                        it.copy(
                            isLookingUpPoi = false,
                            poiLookupResult = resolved,
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
                        poiLookupError = PoiLookupError(
                            message = e.message ?: "カフェ情報の取得に失敗しました",
                            isNotFound = false,
                        ),
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

/**
 * [MapViewModel.onPoiTapped] の座標近傍候補内での曖昧性解消に使う、緩い名前一致判定。
 *
 * 双方を小文字化して空白を除去したうえで、どちらかが他方を包含していれば一致とみなす
 * （例: Apple "スターバックス" と Google "スターバックス コーヒー 渋谷店" は一致）。
 * ローカライズや表記ゆれで完全一致は期待できないための緩和だが、緩めすぎると短い
 * generic な名前（"カフェ" 等。iOS 側は POI 名が nil のときこれを渡す）が無関係な
 * 候補と誤マッチするため、正規化後の [tappedName] が 2 文字未満のときは常に false を返す。
 *
 * @param candidateName 近傍検索結果側のカフェ名
 * @param tappedName タップした POI の表示名
 */
private fun namesMatch(candidateName: String, tappedName: String): Boolean {
    fun normalize(value: String): String = value.lowercase().filterNot { it.isWhitespace() }

    val normalizedTapped = normalize(tappedName)
    if (normalizedTapped.length < 2) return false

    val normalizedCandidate = normalize(candidateName)
    if (normalizedCandidate.isEmpty()) return false

    return normalizedCandidate.contains(normalizedTapped) || normalizedTapped.contains(normalizedCandidate)
}

/**
 * POI タップ解決の候補から最適な 1 件を選ぶ。
 *
 * [tappedName] と名前一致（[namesMatch]）する候補があればその集合、無ければ全候補を対象に、
 * タップ座標 ([latitude], [longitude]) に最も近いものを返す。座標を持たない候補は距離比較から除外し、
 * 対象がすべて座標を持たない場合のみ対象集合の先頭にフォールバックする。
 *
 * [candidates] は非空前提（呼び出し側で空チェック済み）。
 */
private fun selectBestPoiMatch(
    candidates: List<Cafe>,
    tappedName: String,
    latitude: Double,
    longitude: Double,
): Cafe {
    val nameMatched = candidates.filter { namesMatch(it.name, tappedName) }
    val pool = nameMatched.ifEmpty { candidates }
    return pool
        .filter { it.latitude != null && it.longitude != null }
        .minByOrNull { squaredGeoDistance(latitude, longitude, it.latitude!!, it.longitude!!) }
        ?: pool.first()
}

/**
 * 2 点間の距離の相対比較用の二乗距離（equirectangular 近似）。
 *
 * 経度差は緯度に応じて `cos(lat)` で補正する。厳密なメートル単位ではないが、
 * 局所的な候補同士の「どれが最も近いか」を比較するには十分。
 */
private fun squaredGeoDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Double {
    val dLat = lat2 - lat1
    val dLon = (lon2 - lon1) * cos(lat1 * PI / 180.0)
    return dLat * dLat + dLon * dLon
}

package com.noricoffee.feature.coffeeeditor

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
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
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.todayIn

/**
 * コーヒー記録作成 / 編集画面の ViewModel。
 *
 * 新規作成（[Mode.Create]）と既存記録の編集（[Mode.Edit]）を 1 つの ViewModel で扱う。
 *
 * ## 状態の流れ
 *
 * - [onAppear] で [Mode] と userId を受け取り、初期 draft を設定する
 * - フィールド更新メソッド群（`on<Field>Changed(...)` 等）で [UIState.draft] を更新する
 * - [onSaveTapped] でバリデーション → [CoffeeRepository.save] → 成功時に [UIState.savedCoffeeId] に id を詰める
 * - Swift 側は `onChange(of: viewModel.savedCoffeeId)` で非 null を検知して `dismiss()`
 *
 * ## Edit モードの初期化
 *
 * [Mode.Edit] の場合は [CoffeeRepository.observeById] の `.first()` で 1 回だけ取得する。
 * 継続購読にすると他端末更新が編集中の draft を上書きする事故が起き得るため、
 * MVP では last-write-wins（`updatedAt = now` で上書き）で対処する。
 *
 * ## Duplicate モード（複製）の初期化
 *
 * [Mode.Duplicate] は複製元 [CoffeeRecord.id] を受け取り、[Mode.Edit] と同様に
 * [CoffeeRepository.observeById] の `.first()` で 1 回だけ取得して draft の初期値に展開する
 * （`toDuplicateDraft`）。保存時は [Mode.Create] と同じく新規 id / createdAt を採番する（[buildRecord]）。
 * 引き継ぐ項目・引き継がない項目は `docs/requirements.md` 2-10 を参照。
 *
 * ## cafe の任意化
 *
 * [CoffeeDraft.cafeName] が空のとき、cafe = null のレコード（セルフ抽出）として保存する。
 * [validate] は cafeName 不要、name 必須のみを検証する。
 *
 * ## Places 選択カフェの座標 / 写真参照の引き継ぎ
 *
 * [onPlacesCafeSelected] は選択された [Cafe] を丸ごと内部プロパティ（`selectedCafe`）に保持する
 * （表示用フィールドだけでなく `latitude` / `longitude` / `photoReferences` も含む）。
 * [buildRecord] はこの `selectedCafe` があればその座標 / 写真参照を採用し、
 * name / address / websiteUrl / mapsUrl は draft の編集値を優先する。
 * [UIState.selectedPlaceId] は `selectedCafe?.placeId` から導出される表示用の派生値。
 *
 * ## 現在地カフェサジェスト（[Mode.Create] 専用）
 *
 * [onLocationAvailable] はプラットフォーム側から現在地座標が取得できたときに呼ぶ。
 * [Mode.Create] かつ cafe 未選択（`draft.cafeName` が空）のときだけ [CafeRepository.searchNearby]
 * を実行し、上位 3 件を [UIState.suggestedCafes] に反映する。カフェが選択されると
 * （[onPlacesCafeSelected] / [onSuggestedCafeSelected] いずれも）チップは消える。
 * Nearby 検索の失敗は無音（補助機能のため [UIState.error] には流さない）。
 *
 * @param coffeeRepository コーヒー記録の永続化と取得を担うリポジトリ
 * @param cafeRepository 現在地カフェサジェスト（Nearby 検索）を担うリポジトリ
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
@OptIn(kotlin.uuid.ExperimentalUuidApi::class)
class CoffeeEditorViewModel(
    private val coffeeRepository: CoffeeRepository,
    private val cafeRepository: CafeRepository,
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    /**
     * 画面の動作モードを表す sealed interface。
     *
     * - [Create]: 新規作成モード
     * - [Edit]: 既存記録の編集モード
     * - [Duplicate]: 既存記録を初期値にした複製モード（保存動作は [Create] と同一）
     */
    sealed interface Mode {
        /** 新規作成モード。 */
        data object Create : Mode

        /**
         * 既存記録の編集モード。
         *
         * @property coffeeId 編集対象の [CoffeeRecord.id]
         */
        data class Edit(val coffeeId: String) : Mode

        /**
         * 既存記録を複製元にした新規作成モード（要件 2-10）。
         *
         * 引き継ぐ: cafe / name / brewMethod / origin / variety / processing / roastLevel / cup / brewRecipe / tags。
         * 引き継がない: rating（null = 未評価）/ notes（空）/ photos（空）/ tasting（null）。
         * `visitedOn` は今日、保存時の id / createdAt は [Create] と同様に新規採番する。
         *
         * @property sourceCoffeeId 複製元の [CoffeeRecord.id]
         */
        data class Duplicate(val sourceCoffeeId: String) : Mode
    }

    /**
     * 編集中の UI 値を保持する draft オブジェクト。
     *
     * cafe は任意 — cafeName が空のとき null cafe（セルフ抽出）で保存する。
     *
     * @property cafeName カフェ名（任意。空の場合はセルフ抽出として扱う）
     * @property cafeAddress カフェ住所（任意）
     * @property cafeWebsiteUrl カフェの Web サイト URL（任意）
     * @property cafeMapsUrl カフェの Google Maps URL（任意）
     * @property visitedOn 飲んだ日（デフォルトは今日）
     * @property rating 評価（0.5..5.0（0.5 刻み）。null = 未評価（未評価のまま保存可。2026-07-12 B-4））
     * @property notes 自由メモ（任意。最大 2000 文字）
     * @property photos 写真アイテム一覧
     * @property name コーヒー名（必須。最大 200 文字）
     * @property brewMethod 抽出方法
     * @property origin 産地（任意）
     * @property variety 品種（任意）
     * @property processing 精製方法（任意）
     * @property roastLevel 焙煎度（任意）
     * @property cup カップ（任意）
     * @property brewRecipe 抽出レシピ（任意。自由メモ。最大 500 文字）
     * @property tasting テイスティング 5 要素（null = 未記入。非 null = 5 要素すべてセット済み）
     * @property tags ユーザー定義タグ（任意。空リスト = タグなし）
     */
    data class CoffeeDraft(
        val cafeName: String,
        val cafeAddress: String,
        val cafeWebsiteUrl: String,
        val cafeMapsUrl: String,
        val visitedOn: LocalDate,
        val rating: Double?,
        val notes: String,
        val photos: List<Photo> = emptyList(),
        val name: String,
        val brewMethod: BrewMethod,
        val origin: String,
        val variety: String,
        val processing: ProcessingMethod?,
        val roastLevel: RoastLevel?,
        val cup: String,
        val brewRecipe: String,
        val tasting: TastingScores? = null,  // all-or-nothing: null = 未入力 / 非 null = 5 要素全セット
        val tags: List<String> = emptyList(), // ユーザー定義タグ
    )

    /**
     * コーヒー記録作成 / 編集画面の UI 状態。
     *
     * @property mode 現在の動作モード
     * @property draft 編集中の UI 値
     * @property isLoading Edit モードで初回ロード中かどうか
     * @property isSaving 保存処理実行中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     * @property savedCoffeeId 保存成功時に非 null になる。Swift 側はこれを監視して画面を dismiss する
     * @property selectedPlaceId Places API 検索で選択したカフェの Google placeId（任意）。
     *   内部で保持する選択済み [Cafe]（`selectedCafe`）の `placeId` を表示用に写した派生値
     * @property suggestedCafes 現在地カフェサジェスト（最大 3 件）。[Mode.Create] かつ cafe 未選択の
     *   ときだけ [onLocationAvailable] で反映される。カフェが選択されると空リストに戻る
     */
    data class UIState(
        val mode: Mode = Mode.Create,
        val draft: CoffeeDraft = defaultDraft(),
        val isLoading: Boolean = false,
        val isSaving: Boolean = false,
        val error: String? = null,
        val savedCoffeeId: String? = null,
        val selectedPlaceId: String? = null,
        val suggestedCafes: List<Cafe> = emptyList(),
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // Edit モードで取得した初期 CoffeeRecord。保存時に id / placeId / createdAt を引き出すために保持する。
    private var currentInitialRecord: CoffeeRecord? = null

    // onPlacesCafeSelected で選択された Cafe を丸ごと保持する（placeId / 座標 / photoReferences を含む）。
    // buildRecord はこれを見つけたら座標 / photoReferences をこの値から採用する。onAppear でリセットする。
    private var selectedCafe: Cafe? = null

    // onAppear で受け取った userId を保持し、save / onAppear 内で使う。
    private var currentUserId: String? = null

    // Edit モードでの初回ロード Job。onAppear が複数回呼ばれた場合に前回を cancel する。
    private var loadJob: Job? = null

    // 保存 Job。保存中に再度 onSaveTapped が呼ばれた場合に前回を cancel する。
    private var saveJob: Job? = null

    // 現在地カフェサジェスト（Nearby 検索）Job。onLocationAvailable が複数回呼ばれた場合に前回を cancel する。
    private var suggestionJob: Job? = null

    // --- ライフサイクル ---

    /**
     * 画面表示時に呼ぶ。[mode] と [userId] を受け取り初期 draft を設定する。
     *
     * - [Mode.Create]: draft を初期値にリセットする
     * - [Mode.Edit]: [CoffeeRepository.observeById] の `.first()` で 1 回だけ取得して draft を更新する
     * - [Mode.Duplicate]: 複製元を [CoffeeRepository.observeById] の `.first()` で 1 回だけ取得し、
     *   複製用の初期値（`toDuplicateDraft`）に展開する
     */
    fun onAppear(mode: Mode, userId: String) {
        currentUserId = userId
        loadJob?.cancel()
        saveJob?.cancel()
        suggestionJob?.cancel()
        selectedCafe = null

        when (mode) {
            is Mode.Create -> {
                currentInitialRecord = null
                _state.update {
                    it.copy(
                        mode = mode,
                        draft = defaultDraft(),
                        isLoading = false,
                        selectedPlaceId = null,
                        suggestedCafes = emptyList(),
                    )
                }
            }
            is Mode.Edit -> {
                _state.update {
                    it.copy(mode = mode, isLoading = true, selectedPlaceId = null, suggestedCafes = emptyList())
                }
                loadJob = viewModelScope.launch {
                    val record = coffeeRepository.observeById(mode.coffeeId).first()
                    if (record == null) {
                        _state.update {
                            it.copy(
                                isLoading = false,
                                error = "コーヒー記録が見つかりませんでした",
                            )
                        }
                    } else {
                        currentInitialRecord = record
                        _state.update {
                            it.copy(
                                isLoading = false,
                                draft = record.toDraft(),
                            )
                        }
                    }
                }
            }
            is Mode.Duplicate -> {
                _state.update {
                    it.copy(mode = mode, isLoading = true, selectedPlaceId = null, suggestedCafes = emptyList())
                }
                loadJob = viewModelScope.launch {
                    val record = coffeeRepository.observeById(mode.sourceCoffeeId).first()
                    if (record == null) {
                        _state.update {
                            it.copy(
                                isLoading = false,
                                error = "複製元のコーヒー記録が見つかりませんでした",
                            )
                        }
                    } else {
                        currentInitialRecord = record
                        _state.update {
                            it.copy(
                                isLoading = false,
                                draft = record.toDuplicateDraft(),
                            )
                        }
                    }
                }
            }
        }
    }

    /**
     * 画面消去時に呼ぶ。進行中の load / save Job をすべてキャンセルする。
     */
    fun onDisappear() {
        loadJob?.cancel()
        saveJob?.cancel()
        suggestionJob?.cancel()
    }

    // --- フィールド更新（cafe 関連）---

    /** カフェ名を更新する。 */
    fun onCafeNameChanged(name: String) {
        _state.update { it.copy(draft = it.draft.copy(cafeName = name)) }
    }

    /** カフェ住所を更新する。 */
    fun onCafeAddressChanged(address: String) {
        _state.update { it.copy(draft = it.draft.copy(cafeAddress = address)) }
    }

    /** カフェ Web サイト URL を更新する。 */
    fun onCafeWebsiteUrlChanged(url: String) {
        _state.update { it.copy(draft = it.draft.copy(cafeWebsiteUrl = url)) }
    }

    /** カフェ Google Maps URL を更新する。 */
    fun onCafeMapsUrlChanged(url: String) {
        _state.update { it.copy(draft = it.draft.copy(cafeMapsUrl = url)) }
    }

    // --- フィールド更新（記録本体）---

    /** 飲んだ日を更新する。 */
    fun onVisitedOnChanged(date: LocalDate) {
        _state.update { it.copy(draft = it.draft.copy(visitedOn = date)) }
    }

    /** 評価を更新する（0.5..5.0、0.5 刻み）。null = 未評価。 */
    fun onRatingChanged(rating: Double?) {
        _state.update { it.copy(draft = it.draft.copy(rating = rating)) }
    }

    /** 自由メモを更新する。 */
    fun onNotesChanged(text: String) {
        _state.update { it.copy(draft = it.draft.copy(notes = text)) }
    }

    // --- フィールド更新（コーヒー属性）---

    /** コーヒー名を更新する（必須フィールド）。 */
    fun onNameChanged(name: String) {
        _state.update { it.copy(draft = it.draft.copy(name = name)) }
    }

    /** 抽出方法を更新する。 */
    fun onBrewMethodChanged(brewMethod: BrewMethod) {
        _state.update { it.copy(draft = it.draft.copy(brewMethod = brewMethod)) }
    }

    /** 産地を更新する。 */
    fun onOriginChanged(origin: String) {
        _state.update { it.copy(draft = it.draft.copy(origin = origin)) }
    }

    /** 品種を更新する。 */
    fun onVarietyChanged(variety: String) {
        _state.update { it.copy(draft = it.draft.copy(variety = variety)) }
    }

    /** 精製方法を更新する。null で「未設定」。 */
    fun onProcessingChanged(processing: ProcessingMethod?) {
        _state.update { it.copy(draft = it.draft.copy(processing = processing)) }
    }

    /** 焙煎度を更新する。null で「未設定」。 */
    fun onRoastLevelChanged(roastLevel: RoastLevel?) {
        _state.update { it.copy(draft = it.draft.copy(roastLevel = roastLevel)) }
    }

    /** カップを更新する。 */
    fun onCupChanged(cup: String) {
        _state.update { it.copy(draft = it.draft.copy(cup = cup)) }
    }

    /** 抽出レシピ（自由メモ。最大 500 文字）を更新する。 */
    fun onBrewRecipeChanged(brewRecipe: String) {
        _state.update { it.copy(draft = it.draft.copy(brewRecipe = brewRecipe)) }
    }

    // --- テイスティング要素更新（all-or-nothing）---

    /**
     * テイスティングを追加する（`+` ボタン相当）。
     *
     * `draft.tasting == null` のとき `TastingScores(5,5,5,5,5)` をデフォルト値として生成し、
     * 5 スライダーを一度に表示できる状態にする。
     * 既に tasting がある場合は no-op。
     */
    fun onTastingAdded() {
        if (_state.value.draft.tasting == null) {
            _state.update {
                it.copy(draft = it.draft.copy(tasting = TastingScores(5, 5, 5, 5, 5)))
            }
        }
    }

    /**
     * テイスティングをクリアする（削除ボタン相当）。
     *
     * `draft.tasting` を null に戻す。スライダーをすべて非表示にする。
     */
    fun onTastingCleared() {
        _state.update { it.copy(draft = it.draft.copy(tasting = null)) }
    }

    /**
     * 甘味を更新する。非 null の Int のみ受け付ける。設定値は 1..10 にクランプされる。
     *
     * `draft.tasting == null` の場合は no-op（先に [onTastingAdded] を呼ぶ必要がある）。
     */
    fun onSweetnessChanged(value: Int) {
        _state.update { state ->
            state.draft.tasting?.let { t ->
                state.copy(draft = state.draft.copy(tasting = t.copy(sweetness = value.clampTasting())))
            } ?: state
        }
    }

    /**
     * ボディ（コク）を更新する。非 null の Int のみ受け付ける。設定値は 1..10 にクランプされる。
     *
     * `draft.tasting == null` の場合は no-op。
     */
    fun onBodyChanged(value: Int) {
        _state.update { state ->
            state.draft.tasting?.let { t ->
                state.copy(draft = state.draft.copy(tasting = t.copy(body = value.clampTasting())))
            } ?: state
        }
    }

    /**
     * 酸味を更新する。非 null の Int のみ受け付ける。設定値は 1..10 にクランプされる。
     *
     * `draft.tasting == null` の場合は no-op。
     */
    fun onAcidityChanged(value: Int) {
        _state.update { state ->
            state.draft.tasting?.let { t ->
                state.copy(draft = state.draft.copy(tasting = t.copy(acidity = value.clampTasting())))
            } ?: state
        }
    }

    /**
     * 風味を更新する。非 null の Int のみ受け付ける。設定値は 1..10 にクランプされる。
     *
     * `draft.tasting == null` の場合は no-op。
     */
    fun onFlavorChanged(value: Int) {
        _state.update { state ->
            state.draft.tasting?.let { t ->
                state.copy(draft = state.draft.copy(tasting = t.copy(flavor = value.clampTasting())))
            } ?: state
        }
    }

    /**
     * 後味を更新する。非 null の Int のみ受け付ける。設定値は 1..10 にクランプされる。
     *
     * `draft.tasting == null` の場合は no-op。
     */
    fun onAftertasteChanged(value: Int) {
        _state.update { state ->
            state.draft.tasting?.let { t ->
                state.copy(draft = state.draft.copy(tasting = t.copy(aftertaste = value.clampTasting())))
            } ?: state
        }
    }

    // --- タグ操作 ---

    /**
     * タグを追加する。
     *
     * [tag] を trim した結果が空または既に存在する場合は no-op。
     *
     * @param tag 追加するタグ文字列（前後の空白は自動 trim される）
     */
    fun onTagAdded(tag: String) {
        val trimmed = tag.trim()
        if (trimmed.isBlank() || _state.value.draft.tags.contains(trimmed)) return
        _state.update { it.copy(draft = it.draft.copy(tags = it.draft.tags + trimmed)) }
    }

    /**
     * タグを削除する。
     *
     * [tag] が存在しない場合は no-op。
     *
     * @param tag 削除するタグ文字列
     */
    fun onTagRemoved(tag: String) {
        _state.update { it.copy(draft = it.draft.copy(tags = it.draft.tags - tag)) }
    }

    /**
     * Places API 検索結果からカフェを選択した際に呼ぶ。
     *
     * [cafe] を丸ごと内部プロパティ（`selectedCafe`）に保持し（[buildRecord] が座標 / photoReferences の
     * 引き継ぎに使う）、[cafe] の表示用フィールドで [UIState.draft] を上書きする。
     * [UIState.selectedPlaceId] にも Google placeId を保持する（表示用の派生値）。
     * カフェが選択されたので [UIState.suggestedCafes] は空にする（進行中の Nearby 検索も cancel する）。
     *
     * @param cafe Places API 検索から選択したカフェ情報
     */
    fun onPlacesCafeSelected(cafe: Cafe) {
        selectedCafe = cafe
        suggestionJob?.cancel()
        _state.update {
            it.copy(
                draft = it.draft.copy(
                    cafeName = cafe.name,
                    cafeAddress = cafe.address ?: "",
                    cafeWebsiteUrl = cafe.websiteUrl ?: "",
                    cafeMapsUrl = cafe.mapsUrl ?: "",
                ),
                selectedPlaceId = cafe.placeId,
                suggestedCafes = emptyList(),
            )
        }
    }

    /**
     * 現在地カフェサジェストのチップをタップした際に呼ぶ。
     *
     * 挙動は [onPlacesCafeSelected] と完全に同一（サジェスト経由・検索経由を問わずカフェ選択の
     * アクションを共通化する）。
     *
     * @param cafe サジェストチップに表示していたカフェ情報
     */
    fun onSuggestedCafeSelected(cafe: Cafe) {
        onPlacesCafeSelected(cafe)
    }

    /**
     * プラットフォーム側から現在地座標が取得できたときに呼ぶ。
     *
     * [Mode.Create] かつ [UIState.draft] の `cafeName` が空（cafe 未選択）のときだけ
     * [CafeRepository.searchNearby] を実行し、上位 3 件を [UIState.suggestedCafes] に反映する。
     * それ以外のモード、または既にカフェ名が入っている場合は no-op（位置情報の取得自体は
     * プラットフォーム側の関心事のため、呼び出し側は条件を気にせず毎回呼んでよい）。
     *
     * 前回の Nearby 検索 Job が実行中の場合はキャンセルして新しい検索を起動する。
     * 検索失敗時は無音（[UIState.error] は変更しない。サジェストは補助機能のため）。
     *
     * @param latitude 現在地の緯度
     * @param longitude 現在地の経度
     */
    fun onLocationAvailable(latitude: Double, longitude: Double) {
        if (_state.value.mode !is Mode.Create) return
        if (_state.value.draft.cafeName.isNotBlank()) return

        suggestionJob?.cancel()
        suggestionJob = viewModelScope.launch {
            try {
                val results = cafeRepository.searchNearby(latitude, longitude).take(3)
                if (_state.value.mode is Mode.Create && _state.value.draft.cafeName.isBlank()) {
                    _state.update { it.copy(suggestedCafes = results) }
                }
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                // 無音: サジェストは補助機能のため error には流さない（要件 2-8）
            }
        }
    }

    // --- 写真操作 ---

    /**
     * 写真アイテムを追加または更新する（upsert 挙動）。
     */
    fun onPhotoUpserted(item: Photo) {
        _state.update { state ->
            val existing = state.draft.photos.indexOfFirst { it.id == item.id }
            val updated = if (existing >= 0) {
                state.draft.photos.toMutableList().also { it[existing] = item }
            } else {
                state.draft.photos + item
            }
            state.copy(draft = state.draft.copy(photos = updated))
        }
    }

    /**
     * 写真アイテムを削除する。
     */
    fun onPhotoRemoved(id: String) {
        _state.update { it.copy(draft = it.draft.copy(photos = it.draft.photos.filter { p -> p.id != id })) }
    }

    // --- 保存 ---

    /**
     * 保存ボタンタップ時に呼ぶ。バリデーション → [CoffeeRepository.save] を実行する。
     *
     * - バリデーション失敗時: [UIState.error] にメッセージを詰めて早期 return する
     * - 保存成功時: [UIState.savedCoffeeId] に保存した record の id を詰める
     * - 保存失敗時: [UIState.error] にメッセージを詰める
     */
    fun onSaveTapped() {
        val userId = currentUserId ?: run {
            _state.update { it.copy(error = "user not signed in") }
            return
        }

        val draft = _state.value.draft
        val errorMessage = validate(draft)
        if (errorMessage != null) {
            _state.update { it.copy(error = errorMessage) }
            return
        }

        saveJob?.cancel()
        saveJob = viewModelScope.launch {
            _state.update { it.copy(isSaving = true) }
            val record = buildRecord(draft, userId)
            try {
                coffeeRepository.save(record)
                _state.update { it.copy(isSaving = false, savedCoffeeId = record.id, error = null) }
            } catch (e: CancellationException) {
                _state.update { it.copy(isSaving = false) }
                throw e
            } catch (e: Exception) {
                _state.update { it.copy(isSaving = false, error = e.message ?: "保存に失敗しました") }
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
     * iOS Bridge の deinit または onDisappear で呼ぶこと。
     * [onDisappear] は個別 Job（load / save）のキャンセルのみを行うのに対し、
     * [clear] はスコープ全体を畳む。[clear] 後は [onDisappear] を呼んでも安全（no-op）。
     * キャンセル後に [onAppear] が呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }

    // --- プライベートヘルパ ---

    /**
     * draft のバリデーション。エラーメッセージを返す。問題なければ null を返す。
     *
     * - name（コーヒー名）は必須・最大 200 文字
     * - rating は null（未評価。未評価のまま保存可）または 0.5..5.0（0.5 刻み）。
     *   非 null のときのみ範囲・刻みをバリデーションする（2026-07-12 B-4）
     * - notes は最大 2000 文字
     * - brewRecipe は最大 500 文字
     * - cafe は任意（空の場合はセルフ抽出として保存）
     */
    private fun validate(draft: CoffeeDraft): String? {
        val rating = draft.rating
        return when {
            draft.name.isBlank() -> "コーヒー名を入力してください"
            draft.name.length > 200 -> "コーヒー名は 200 文字以内で入力してください"
            rating != null && (rating < 0.5 || rating > 5.0 || (rating * 2) % 1.0 != 0.0) ->
                "評価を 0.5〜5.0 で入力してください"
            draft.notes.length > 2000 -> "メモは 2000 文字以内で入力してください"
            draft.brewRecipe.length > 500 -> "抽出レシピは 500 文字以内で入力してください"
            else -> null
        }
    }

    /**
     * draft と [Mode] から保存用の [CoffeeRecord] を組み立てる。
     *
     * - cafe は [buildCafe] に委譲する（cafeName が空のとき null = セルフ抽出）
     * - [Mode.Create] / [Mode.Duplicate]: id を新規 UUID で採番し、createdAt / updatedAt を now で設定する
     * - [Mode.Edit]: [currentInitialRecord] から id / placeId / createdAt を引き継ぎ、updatedAt を now で更新する
     */
    private fun buildRecord(draft: CoffeeDraft, userId: String): CoffeeRecord {
        val now = Clock.System.now()
        val mode = _state.value.mode
        val (id, createdAt) = when (mode) {
            is Mode.Create, is Mode.Duplicate -> Pair(
                kotlin.uuid.Uuid.random().toString(),
                now,
            )
            is Mode.Edit -> {
                val initial = currentInitialRecord
                Pair(
                    initial?.id ?: mode.coffeeId,
                    initial?.createdAt ?: now,
                )
            }
        }

        val cafe = buildCafe(draft)

        return CoffeeRecord(
            id = id,
            userId = userId,
            cafe = cafe,
            visitedOn = draft.visitedOn,
            rating = draft.rating,
            notes = draft.notes,
            photos = draft.photos,
            name = draft.name,
            brewMethod = draft.brewMethod,
            origin = draft.origin.takeIf { it.isNotBlank() },
            variety = draft.variety.takeIf { it.isNotBlank() },
            processing = draft.processing,
            roastLevel = draft.roastLevel,
            cup = draft.cup.takeIf { it.isNotBlank() },
            brewRecipe = draft.brewRecipe.takeIf { it.isNotBlank() },
            tasting = draft.tasting?.clamped(),
            tags = draft.tags,
            createdAt = createdAt,
            updatedAt = now,
        )
    }

    /**
     * draft から保存用の [Cafe]（任意）を組み立てる。
     *
     * 優先順位:
     * 1. [draft].cafeName が空 → null（セルフ抽出）
     * 2. このセッションで Places 選択があった（`selectedCafe` が非 null）→
     *    `selectedCafe` の placeId / latitude / longitude / photoReferences を採用
     * 3. 引き継ぎ元 cafe がある（[currentInitialRecord]`?.cafe` が非 null。[Mode.Edit] / [Mode.Duplicate] で
     *    取得した元記録にカフェが紐づいていた場合）→ その placeId / 座標 / photoReferences を引き継ぐ
     *    （[Mode.Duplicate] は複製元の cafe を同一カフェとして扱う）
     * 4. 上記いずれでもない（[Mode.Create] の手入力カフェ、またはセルフ抽出記録
     *    （元 cafe = null）の [Mode.Edit] / [Mode.Duplicate] で手動カフェ名を入力したケース）→
     *    UUID を placeId として新規採番、座標は null / photoReferences は空
     *
     * cafe 採用の判定は mode ではなく「引き継ぎ元 cafe の有無」の一点に畳める（[Mode.Create] は
     * [onAppear] で [currentInitialRecord] を null にするため、自然に 4 に落ちる）。
     * いずれの場合も name / address / websiteUrl / mapsUrl は draft の編集値を採用する。
     */
    private fun buildCafe(draft: CoffeeDraft): Cafe? {
        if (draft.cafeName.isBlank()) return null

        val selected = selectedCafe
        val initialCafe = currentInitialRecord?.cafe
        val (placeId, latitude, longitude, photoReferences) = when {
            selected != null ->
                CafeSnapshot(selected.placeId, selected.latitude, selected.longitude, selected.photoReferences)
            initialCafe != null ->
                CafeSnapshot(initialCafe.placeId, initialCafe.latitude, initialCafe.longitude, initialCafe.photoReferences)
            else -> CafeSnapshot(kotlin.uuid.Uuid.random().toString(), null, null, emptyList())
        }

        return Cafe(
            placeId = placeId,
            name = draft.cafeName,
            address = draft.cafeAddress.takeIf { it.isNotBlank() },
            latitude = latitude,
            longitude = longitude,
            photoReferences = photoReferences,
            websiteUrl = draft.cafeWebsiteUrl.takeIf { it.isNotBlank() },
            mapsUrl = draft.cafeMapsUrl.takeIf { it.isNotBlank() },
        )
    }

    /** [buildCafe] の内部ヘルパ: 引き継ぎ元 cafe の非表示フィールド（placeId / 座標 / photoReferences）。 */
    private data class CafeSnapshot(
        val placeId: String,
        val latitude: Double?,
        val longitude: Double?,
        val photoReferences: List<String>,
    )

    companion object {
        /**
         * 新規作成モードにおけるコーヒー名の初期値（要件 2-9）。編集可能。
         * 複製モード（[Mode.Duplicate]）では使わない（複製元の `name` を引き継ぐ）。
         */
        const val DEFAULT_COFFEE_NAME: String = "本日のコーヒー"

        /**
         * [CoffeeDraft] の初期値を返す。
         * Create モードの初期 draft として、また onAppear 前のデフォルト値として使う。
         */
        fun defaultDraft(): CoffeeDraft = CoffeeDraft(
            cafeName = "",
            cafeAddress = "",
            cafeWebsiteUrl = "",
            cafeMapsUrl = "",
            visitedOn = Clock.System.todayIn(TimeZone.currentSystemDefault()),
            rating = null,
            notes = "",
            photos = emptyList(),
            name = DEFAULT_COFFEE_NAME,
            brewMethod = BrewMethod.HandDrip,
            origin = "",
            variety = "",
            processing = null,
            roastLevel = null,
            cup = "",
            brewRecipe = "",
            tasting = null,  // all-or-nothing: 初期状態は tasting なし
            tags = emptyList(),
        )
    }
}

// --- プライベート拡張 ---

/**
 * [CoffeeRecord] を [CoffeeEditorViewModel.CoffeeDraft] に変換する。
 * Edit モードで [CoffeeRepository.observeById] から取得した record を draft の初期値として使う。
 */
private fun CoffeeRecord.toDraft(): CoffeeEditorViewModel.CoffeeDraft =
    CoffeeEditorViewModel.CoffeeDraft(
        cafeName = cafe?.name ?: "",
        cafeAddress = cafe?.address ?: "",
        cafeWebsiteUrl = cafe?.websiteUrl ?: "",
        cafeMapsUrl = cafe?.mapsUrl ?: "",
        visitedOn = visitedOn,
        rating = rating,
        notes = notes,
        photos = photos,
        name = name,
        brewMethod = brewMethod,
        origin = origin ?: "",
        variety = variety ?: "",
        processing = processing,
        roastLevel = roastLevel,
        cup = cup ?: "",
        brewRecipe = brewRecipe ?: "",
        tasting = tasting,  // all-or-nothing: null = 未入力 / 非 null = 5 要素全セット（edit モードで既存 tasting を反映）
        tags = tags,
    )

/**
 * [CoffeeRecord] を複製（[CoffeeEditorViewModel.Mode.Duplicate]）の初期 draft に変換する。
 *
 * 引き継ぐ: cafe（表示用フィールドのみ。placeId / 座標 / photoReferences は `currentInitialRecord` 経由で
 * [CoffeeEditorViewModel.buildCafe] が引き継ぐ）/ name / brewMethod / origin / variety / processing /
 * roastLevel / cup / brewRecipe / tags。
 * 引き継がない: rating（null = 未評価）/ notes（空）/ photos（空）/ tasting（null）。
 * `visitedOn` は今日にする（元記録の日付は使わない）。
 */
private fun CoffeeRecord.toDuplicateDraft(): CoffeeEditorViewModel.CoffeeDraft =
    CoffeeEditorViewModel.CoffeeDraft(
        cafeName = cafe?.name ?: "",
        cafeAddress = cafe?.address ?: "",
        cafeWebsiteUrl = cafe?.websiteUrl ?: "",
        cafeMapsUrl = cafe?.mapsUrl ?: "",
        visitedOn = Clock.System.todayIn(TimeZone.currentSystemDefault()),
        rating = null,
        notes = "",
        photos = emptyList(),
        name = name,
        brewMethod = brewMethod,
        origin = origin ?: "",
        variety = variety ?: "",
        processing = processing,
        roastLevel = roastLevel,
        cup = cup ?: "",
        brewRecipe = brewRecipe ?: "",
        tasting = null,  // all-or-nothing: 複製では引き継がない（要件 2-10）
        tags = tags,
    )

/**
 * テイスティングスコアの各要素を `1..10` の範囲にクランプした新しいインスタンスを返す。
 *
 * 各フィールドは非 null（all-or-nothing）。入力範囲外（< 1 または > 10）の値はクランプする。
 * バリデーション規約: `data-model.md` §1.1a
 */
private fun TastingScores.clamped(): TastingScores = TastingScores(
    sweetness = sweetness.clampTasting(),
    body = body.clampTasting(),
    acidity = acidity.clampTasting(),
    flavor = flavor.clampTasting(),
    aftertaste = aftertaste.clampTasting(),
)

/** `1..10` の範囲にクランプする拡張関数。 */
private fun Int.clampTasting(): Int = coerceIn(1, 10)

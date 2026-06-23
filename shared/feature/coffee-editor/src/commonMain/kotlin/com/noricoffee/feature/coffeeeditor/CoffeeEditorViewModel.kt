package com.noricoffee.feature.coffeeeditor

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
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
 * ## cafe の任意化
 *
 * [CoffeeDraft.cafeName] が空かつ [UIState.selectedPlaceId] が null のとき、cafe = null の
 * レコード（セルフ抽出）として保存する。[validate] は cafeName 不要、name 必須のみを検証する。
 *
 * @param coffeeRepository コーヒー記録の永続化と取得を担うリポジトリ
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
@OptIn(kotlin.uuid.ExperimentalUuidApi::class)
class CoffeeEditorViewModel(
    private val coffeeRepository: CoffeeRepository,
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
    }

    /**
     * 編集中の UI 値を保持する draft オブジェクト。
     *
     * cafe は任意 — cafeName が空かつ selectedPlaceId が null のとき null cafe で保存する。
     *
     * @property cafeName カフェ名（任意。空の場合はセルフ抽出として扱う）
     * @property cafeAddress カフェ住所（任意）
     * @property cafeWebsiteUrl カフェの Web サイト URL（任意）
     * @property cafeMapsUrl カフェの Google Maps URL（任意）
     * @property visitedOn 飲んだ日（デフォルトは今日）
     * @property rating 評価（0.5..5.0（0.5 刻み）。0.0 は未評価扱いで保存時にバリデーションエラー）
     * @property notes 自由メモ（任意。最大 2000 文字）
     * @property photos 写真アイテム一覧
     * @property name コーヒー名（必須。最大 200 文字）
     * @property brewMethod 抽出方法
     * @property origin 産地（任意）
     * @property variety 品種（任意）
     * @property processing 精製方法（任意）
     * @property roastLevel 焙煎度（任意）
     * @property cup カップ（任意）
     * @property tasting テイスティング 5 要素（null = 未記入。非 null = 5 要素すべてセット済み）
     */
    data class CoffeeDraft(
        val cafeName: String,
        val cafeAddress: String,
        val cafeWebsiteUrl: String,
        val cafeMapsUrl: String,
        val visitedOn: LocalDate,
        val rating: Double,
        val notes: String,
        val photos: List<Photo> = emptyList(),
        val name: String,
        val brewMethod: BrewMethod,
        val origin: String,
        val variety: String,
        val processing: ProcessingMethod?,
        val roastLevel: RoastLevel?,
        val cup: String,
        val tasting: TastingScores? = null,  // all-or-nothing: null = 未入力 / 非 null = 5 要素全セット
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
     * @property selectedPlaceId Places API 検索で選択したカフェの Google placeId（任意）
     */
    data class UIState(
        val mode: Mode = Mode.Create,
        val draft: CoffeeDraft = defaultDraft(),
        val isLoading: Boolean = false,
        val isSaving: Boolean = false,
        val error: String? = null,
        val savedCoffeeId: String? = null,
        val selectedPlaceId: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // Edit モードで取得した初期 CoffeeRecord。保存時に id / placeId / createdAt を引き出すために保持する。
    private var currentInitialRecord: CoffeeRecord? = null

    // onAppear で受け取った userId を保持し、save / onAppear 内で使う。
    private var currentUserId: String? = null

    // Edit モードでの初回ロード Job。onAppear が複数回呼ばれた場合に前回を cancel する。
    private var loadJob: Job? = null

    // 保存 Job。保存中に再度 onSaveTapped が呼ばれた場合に前回を cancel する。
    private var saveJob: Job? = null

    // --- ライフサイクル ---

    /**
     * 画面表示時に呼ぶ。[mode] と [userId] を受け取り初期 draft を設定する。
     *
     * - [Mode.Create]: draft を初期値にリセットする
     * - [Mode.Edit]: [CoffeeRepository.observeById] の `.first()` で 1 回だけ取得して draft を更新する
     */
    fun onAppear(mode: Mode, userId: String) {
        currentUserId = userId
        loadJob?.cancel()
        saveJob?.cancel()

        when (mode) {
            is Mode.Create -> {
                currentInitialRecord = null
                _state.update { it.copy(mode = mode, draft = defaultDraft(), isLoading = false) }
            }
            is Mode.Edit -> {
                _state.update { it.copy(mode = mode, isLoading = true) }
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
        }
    }

    /**
     * 画面消去時に呼ぶ。進行中の load / save Job をすべてキャンセルする。
     */
    fun onDisappear() {
        loadJob?.cancel()
        saveJob?.cancel()
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

    /** 評価を更新する（0.5..5.0、0.5 刻み）。0.0 は未評価。 */
    fun onRatingChanged(rating: Double) {
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

    /**
     * Places API 検索結果からカフェを選択した際に呼ぶ。
     *
     * [cafe] の各フィールドで [UIState.draft] の表示フィールドを上書きし、
     * [UIState.selectedPlaceId] に Google placeId を保持する。
     *
     * @param cafe Places API 検索から選択したカフェ情報
     */
    fun onPlacesCafeSelected(cafe: Cafe) {
        _state.update {
            it.copy(
                draft = it.draft.copy(
                    cafeName = cafe.name,
                    cafeAddress = cafe.address ?: "",
                    cafeWebsiteUrl = cafe.websiteUrl ?: "",
                    cafeMapsUrl = cafe.mapsUrl ?: "",
                ),
                selectedPlaceId = cafe.placeId,
            )
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
     * - rating は 0.5..5.0（0.5 刻み）必須（0.0 は未評価扱いでエラー）
     * - notes は最大 2000 文字
     * - cafe は任意（空の場合はセルフ抽出として保存）
     */
    private fun validate(draft: CoffeeDraft): String? = when {
        draft.name.isBlank() -> "コーヒー名を入力してください"
        draft.name.length > 200 -> "コーヒー名は 200 文字以内で入力してください"
        draft.rating < 0.5 || draft.rating > 5.0 || (draft.rating * 2) % 1.0 != 0.0 ->
            "評価を 0.5〜5.0 で入力してください"
        draft.notes.length > 2000 -> "メモは 2000 文字以内で入力してください"
        else -> null
    }

    /**
     * draft と [Mode] から保存用の [CoffeeRecord] を組み立てる。
     *
     * - cafe は cafeName が空かつ selectedPlaceId が null のとき null（セルフ抽出）
     * - [Mode.Create]: id を新規 UUID で採番し、createdAt / updatedAt を now で設定する
     * - [Mode.Edit]: [currentInitialRecord] から id / placeId / createdAt を引き継ぎ、updatedAt を now で更新する
     */
    private fun buildRecord(draft: CoffeeDraft, userId: String): CoffeeRecord {
        val now = Clock.System.now()
        val mode = _state.value.mode
        val (id, createdAt) = when (mode) {
            is Mode.Create -> Pair(
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

        // cafe の組み立て: selectedPlaceId があるか cafeName が非空の場合のみ構築する
        val selectedPlaceId = _state.value.selectedPlaceId
        val cafe = when (mode) {
            is Mode.Edit -> {
                // Edit モード: 既存レコードの cafe を引き継ぐ（selectedPlaceId は使わない）
                // cafeName が空になったとき null にしてセルフ抽出化する
                val initial = currentInitialRecord
                val initialCafe = initial?.cafe
                if (initialCafe != null && draft.cafeName.isNotBlank()) {
                    Cafe(
                        placeId = initialCafe.placeId,
                        name = draft.cafeName,
                        address = draft.cafeAddress.takeIf { it.isNotBlank() },
                        latitude = initialCafe.latitude,
                        longitude = initialCafe.longitude,
                        photoReferences = initialCafe.photoReferences,
                        websiteUrl = draft.cafeWebsiteUrl.takeIf { it.isNotBlank() },
                        mapsUrl = draft.cafeMapsUrl.takeIf { it.isNotBlank() },
                    )
                } else if (selectedPlaceId != null && draft.cafeName.isNotBlank()) {
                    Cafe(
                        placeId = selectedPlaceId,
                        name = draft.cafeName,
                        address = draft.cafeAddress.takeIf { it.isNotBlank() },
                        latitude = null,
                        longitude = null,
                        photoReferences = emptyList(),
                        websiteUrl = draft.cafeWebsiteUrl.takeIf { it.isNotBlank() },
                        mapsUrl = draft.cafeMapsUrl.takeIf { it.isNotBlank() },
                    )
                } else {
                    null
                }
            }
            is Mode.Create -> {
                if (selectedPlaceId != null && draft.cafeName.isNotBlank()) {
                    Cafe(
                        placeId = selectedPlaceId,
                        name = draft.cafeName,
                        address = draft.cafeAddress.takeIf { it.isNotBlank() },
                        latitude = null,
                        longitude = null,
                        photoReferences = emptyList(),
                        websiteUrl = draft.cafeWebsiteUrl.takeIf { it.isNotBlank() },
                        mapsUrl = draft.cafeMapsUrl.takeIf { it.isNotBlank() },
                    )
                } else if (draft.cafeName.isNotBlank()) {
                    // Places から選んでいないが手入力でカフェ名がある場合は UUID を placeId として採番
                    Cafe(
                        placeId = kotlin.uuid.Uuid.random().toString(),
                        name = draft.cafeName,
                        address = draft.cafeAddress.takeIf { it.isNotBlank() },
                        latitude = null,
                        longitude = null,
                        photoReferences = emptyList(),
                        websiteUrl = draft.cafeWebsiteUrl.takeIf { it.isNotBlank() },
                        mapsUrl = draft.cafeMapsUrl.takeIf { it.isNotBlank() },
                    )
                } else {
                    null
                }
            }
        }

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
            tasting = draft.tasting?.clamped(),
            createdAt = createdAt,
            updatedAt = now,
        )
    }

    companion object {
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
            rating = 0.0,
            notes = "",
            photos = emptyList(),
            name = "",
            brewMethod = BrewMethod.HandDrip,
            origin = "",
            variety = "",
            processing = null,
            roastLevel = null,
            cup = "",
            tasting = null,  // all-or-nothing: 初期状態は tasting なし
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
        tasting = tasting,  // all-or-nothing: null = 未入力 / 非 null = 5 要素全セット（edit モードで既存 tasting を反映）
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

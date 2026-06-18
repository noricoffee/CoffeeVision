package com.noricoffee.feature.coffeeeditor

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.Photo
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Job
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
    private val scope: CoroutineScope,
) {

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
     * @property rating 評価（1..5。0 は未入力扱いで保存時にバリデーションエラー）
     * @property notes 自由メモ（任意。最大 2000 文字）
     * @property photos 写真アイテム一覧
     * @property name コーヒー名（必須。最大 200 文字）
     * @property brewMethod 抽出方法
     * @property origin 産地（任意）
     * @property variety 品種（任意）
     * @property processing 精製方法（任意）
     * @property roastLevel 焙煎度（任意）
     * @property cup カップ（任意）
     */
    data class CoffeeDraft(
        val cafeName: String,
        val cafeAddress: String,
        val cafeWebsiteUrl: String,
        val cafeMapsUrl: String,
        val visitedOn: LocalDate,
        val rating: Int,
        val notes: String,
        val photos: List<Photo> = emptyList(),
        val name: String,
        val brewMethod: BrewMethod,
        val origin: String,
        val variety: String,
        val processing: ProcessingMethod?,
        val roastLevel: RoastLevel?,
        val cup: String,
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
                loadJob = scope.launch {
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

    /** 評価を更新する（1..5）。 */
    fun onRatingChanged(rating: Int) {
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
        saveJob = scope.launch {
            _state.update { it.copy(isSaving = true) }
            val record = buildRecord(draft, userId)
            runCatching { coffeeRepository.save(record) }
                .onSuccess {
                    _state.update { it.copy(isSaving = false, savedCoffeeId = record.id, error = null) }
                }
                .onFailure { e ->
                    _state.update { it.copy(isSaving = false, error = e.message ?: "保存に失敗しました") }
                }
        }
    }

    /**
     * エラーバナー / ダイアログを閉じた際に呼ぶ。[UIState.error] を null に戻す。
     */
    fun onErrorDismissed() {
        _state.update { it.copy(error = null as String?) }
    }

    // --- プライベートヘルパ ---

    /**
     * draft のバリデーション。エラーメッセージを返す。問題なければ null を返す。
     *
     * - name（コーヒー名）は必須・最大 200 文字
     * - rating は 1..5 必須
     * - notes は最大 2000 文字
     * - cafe は任意（空の場合はセルフ抽出として保存）
     */
    private fun validate(draft: CoffeeDraft): String? = when {
        draft.name.isBlank() -> "コーヒー名を入力してください"
        draft.name.length > 200 -> "コーヒー名は 200 文字以内で入力してください"
        draft.rating !in 1..5 -> "評価を 1〜5 で入力してください"
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
            rating = 0,
            notes = "",
            photos = emptyList(),
            name = "",
            brewMethod = BrewMethod.HandDrip,
            origin = "",
            variety = "",
            processing = null,
            roastLevel = null,
            cup = "",
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
    )

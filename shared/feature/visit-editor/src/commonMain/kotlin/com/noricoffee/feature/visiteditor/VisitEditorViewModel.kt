package com.noricoffee.feature.visiteditor

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeItem
import com.noricoffee.domain.FoodItem
import com.noricoffee.domain.Visit
import com.noricoffee.repository.VisitRepository
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
 * 訪問記録作成 / 編集画面の ViewModel。
 *
 * 新規作成（[Mode.Create]）と既存記録の編集（[Mode.Edit]）を 1 つの ViewModel で扱う。
 * 画面構造が共通のため別クラスに分割しない。
 *
 * ## 状態の流れ
 *
 * - [onAppear] で [Mode] と userId を受け取り、初期 draft を設定する
 * - フィールド更新メソッド群（`on<Field>Changed(...)` 等）で [UIState.draft] を更新する
 * - [onSaveTapped] でバリデーション → [VisitRepository.save] → 成功時に [UIState.savedVisitId] に id を詰める
 * - Swift 側は `onChange(of: viewModel.savedVisitId)` で非 null を検知して `dismiss()`
 *
 * ## Edit モードの初期化
 *
 * [Mode.Edit] の場合は [VisitRepository.observeById] の `.first()` で 1 回だけ取得する。
 * 継続購読にすると他端末更新が編集中の draft を上書きする事故が起き得るため、
 * MVP では last-write-wins（`updatedAt = now` で上書き）で対処する。
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面破棄時にキャンセルすること。
 *
 * @param visitRepository 訪問記録の永続化と取得を担うリポジトリ
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] の MainScope から注入する
 */
@OptIn(kotlin.uuid.ExperimentalUuidApi::class)
class VisitEditorViewModel(
    private val visitRepository: VisitRepository,
    private val scope: CoroutineScope,
) {

    /**
     * 画面の動作モードを表す sealed interface。
     *
     * - [Create]: 新規作成モード。id / createdAt / cafe.placeId はすべて保存時に新規採番する
     * - [Edit]: 既存記録の編集モード。[visitId] で初期値を取得し、id / createdAt / placeId は保持する
     */
    sealed interface Mode {
        /** 新規作成モード。 */
        data object Create : Mode

        /**
         * 既存記録の編集モード。
         *
         * @property visitId 編集対象の [Visit.id]
         */
        data class Edit(val visitId: String) : Mode
    }

    /**
     * 編集中の UI 値を保持する draft オブジェクト。
     *
     * [Visit] と分離している理由:
     * `id` / `userId` / `createdAt` / `updatedAt` / `cafe.placeId` 等は UI で直接編集しないため、
     * それらを含む [Visit] を draft として持つと「編集すべきでない値を誤って変更できる」状態になる。
     * 保存時に [Visit] を組み立てる責務は [onSaveTapped] が担う。
     *
     * @property cafeName カフェ名（必須）
     * @property cafeAddress カフェ住所（任意。空文字は null 扱いで保存時に省略）
     * @property cafeWebsiteUrl カフェの Web サイト URL（任意。空文字は null 扱い）
     * @property cafeMapsUrl カフェの Google Maps URL（任意。空文字は null 扱い）
     * @property visitedOn 訪問日（デフォルトは今日）
     * @property ambiance 雰囲気メモ（任意。最大 200 文字）
     * @property rating 評価（1..5。0 は未入力扱いで保存時にバリデーションエラー）
     * @property notes 自由メモ（任意。最大 2000 文字）
     * @property coffees コーヒーアイテム一覧
     * @property foods フードアイテム一覧
     */
    data class VisitDraft(
        val cafeName: String,
        val cafeAddress: String,
        val cafeWebsiteUrl: String,
        val cafeMapsUrl: String,
        val visitedOn: LocalDate,
        val ambiance: String,
        val rating: Int,
        val notes: String,
        val coffees: List<CoffeeItem>,
        val foods: List<FoodItem>,
    )

    /**
     * 訪問記録作成 / 編集画面の UI 状態。
     *
     * @property mode 現在の動作モード
     * @property draft 編集中の UI 値
     * @property isLoading Edit モードで初回ロード中かどうか
     * @property isSaving 保存処理実行中かどうか
     * @property error 直近の操作で発生したエラーメッセージ。[onErrorDismissed] で null に戻る
     * @property savedVisitId 保存成功時に非 null になる。Swift 側はこれを監視して画面を dismiss する
     */
    data class UIState(
        val mode: Mode = Mode.Create,
        val draft: VisitDraft = defaultDraft(),
        val isLoading: Boolean = false,
        val isSaving: Boolean = false,
        val error: String? = null,
        val savedVisitId: String? = null,
    )

    private val _state = MutableStateFlow(UIState())
    val state: StateFlow<UIState> = _state.asStateFlow()

    // Edit モードで取得した初期 Visit。保存時に id / placeId / createdAt を引き出すために保持する。
    private var currentInitialVisit: Visit? = null

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
     * - [Mode.Create] の場合は draft を初期値のまま [mode] だけ更新する
     * - [Mode.Edit] の場合は [VisitRepository.observeById] の `.first()` で 1 回だけ取得して draft を更新する。
     *   対象 visit が存在しなかった場合は [UIState.error] にメッセージを詰める
     *
     * 複数回呼ばれた場合は前回の load Job を cancel して再実行する（userId 変更・再表示の両方に対応）。
     *
     * @param mode 動作モード
     * @param userId Firebase Auth の uid
     */
    fun onAppear(mode: Mode, userId: String) {
        currentUserId = userId
        // 前回の load / save を全て止めてから再起動する
        loadJob?.cancel()
        saveJob?.cancel()

        when (mode) {
            is Mode.Create -> {
                // Create は即時 draft 初期化のみ（非同期処理なし）
                currentInitialVisit = null
                _state.update { it.copy(mode = mode, draft = defaultDraft(), isLoading = false) }
            }
            is Mode.Edit -> {
                _state.update { it.copy(mode = mode, isLoading = true) }
                loadJob = scope.launch {
                    val visit = visitRepository.observeById(mode.visitId).first()
                    if (visit == null) {
                        _state.update {
                            it.copy(
                                isLoading = false,
                                error = "訪問記録が見つかりませんでした",
                            )
                        }
                    } else {
                        currentInitialVisit = visit
                        _state.update {
                            it.copy(
                                isLoading = false,
                                draft = visit.toDraft(),
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

    // --- フィールド更新 ---

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

    /** 訪問日を更新する。 */
    fun onVisitedOnChanged(date: LocalDate) {
        _state.update { it.copy(draft = it.draft.copy(visitedOn = date)) }
    }

    /** 雰囲気メモを更新する。 */
    fun onAmbianceChanged(text: String) {
        _state.update { it.copy(draft = it.draft.copy(ambiance = text)) }
    }

    /**
     * 評価を更新する。
     *
     * @param rating 1..5 の整数（0 は未入力エラーとして保存時にはじかれる）
     */
    fun onRatingChanged(rating: Int) {
        _state.update { it.copy(draft = it.draft.copy(rating = rating)) }
    }

    /** 自由メモを更新する。 */
    fun onNotesChanged(text: String) {
        _state.update { it.copy(draft = it.draft.copy(notes = text)) }
    }

    // --- 子要素操作 ---

    /**
     * コーヒーアイテムを追加または更新する。
     *
     * 既存リストに [item] と同じ id のアイテムが存在する場合は置換し、
     * 存在しない場合は末尾に追加する（upsert 挙動）。
     *
     * @param item 追加または更新するコーヒーアイテム
     */
    fun onCoffeeUpserted(item: CoffeeItem) {
        _state.update { state ->
            val existing = state.draft.coffees.indexOfFirst { it.id == item.id }
            val updated = if (existing >= 0) {
                state.draft.coffees.toMutableList().also { it[existing] = item }
            } else {
                state.draft.coffees + item
            }
            state.copy(draft = state.draft.copy(coffees = updated))
        }
    }

    /**
     * コーヒーアイテムを削除する。
     *
     * @param id 削除対象の [CoffeeItem.id]
     */
    fun onCoffeeRemoved(id: String) {
        _state.update { it.copy(draft = it.draft.copy(coffees = it.draft.coffees.filter { c -> c.id != id })) }
    }

    /**
     * フードアイテムを追加または更新する。
     *
     * 既存リストに [item] と同じ id のアイテムが存在する場合は置換し、
     * 存在しない場合は末尾に追加する（upsert 挙動）。
     *
     * @param item 追加または更新するフードアイテム
     */
    fun onFoodUpserted(item: FoodItem) {
        _state.update { state ->
            val existing = state.draft.foods.indexOfFirst { it.id == item.id }
            val updated = if (existing >= 0) {
                state.draft.foods.toMutableList().also { it[existing] = item }
            } else {
                state.draft.foods + item
            }
            state.copy(draft = state.draft.copy(foods = updated))
        }
    }

    /**
     * フードアイテムを削除する。
     *
     * @param id 削除対象の [FoodItem.id]
     */
    fun onFoodRemoved(id: String) {
        _state.update { it.copy(draft = it.draft.copy(foods = it.draft.foods.filter { f -> f.id != id })) }
    }

    // --- 保存 ---

    /**
     * 保存ボタンタップ時に呼ぶ。バリデーション → [VisitRepository.save] を実行する。
     *
     * - バリデーション失敗時: [UIState.error] にメッセージを詰めて早期 return する
     * - 保存成功時: [UIState.savedVisitId] に保存した visit の id を詰める。
     *   Swift 側はこれを `onChange(of:)` で監視して `dismiss()` を呼ぶ
     * - 保存失敗時: [UIState.error] にメッセージを詰める
     * - [onAppear] 呼び出し前（userId 未確定）の場合は error を詰めて早期 return する
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

        // 前回の save を止めてから再起動する
        saveJob?.cancel()
        saveJob = scope.launch {
            _state.update { it.copy(isSaving = true) }
            val visit = buildVisit(draft, userId)
            runCatching { visitRepository.save(visit) }
                .onSuccess {
                    _state.update { it.copy(isSaving = false, savedVisitId = visit.id, error = null) }
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
     * draft のバリデーションを行い、エラーメッセージを返す。
     * 問題がなければ null を返す。
     */
    private fun validate(draft: VisitDraft): String? = when {
        draft.cafeName.isBlank() -> "カフェ名を入力してください"
        draft.cafeName.length > 200 -> "カフェ名は 200 文字以内で入力してください"
        draft.rating !in 1..5 -> "評価を 1〜5 で入力してください"
        draft.ambiance.length > 200 -> "雰囲気は 200 文字以内で入力してください"
        draft.notes.length > 2000 -> "メモは 2000 文字以内で入力してください"
        else -> null
    }

    /**
     * draft と [Mode] から保存用の [Visit] を組み立てる。
     *
     * - [Mode.Create]: id / placeId を新規 UUID で採番し、createdAt / updatedAt を now で設定する
     * - [Mode.Edit]: [currentInitialVisit] から id / placeId / createdAt を引き継ぎ、updatedAt を now で更新する
     */
    private fun buildVisit(draft: VisitDraft, userId: String): Visit {
        val now = Clock.System.now()
        val mode = _state.value.mode
        val (id, placeId, createdAt) = when (mode) {
            is Mode.Create -> Triple(
                kotlin.uuid.Uuid.random().toString(),
                kotlin.uuid.Uuid.random().toString(),
                now,
            )
            is Mode.Edit -> {
                val initial = currentInitialVisit
                Triple(
                    initial?.id ?: mode.visitId,
                    initial?.cafe?.placeId ?: kotlin.uuid.Uuid.random().toString(),
                    initial?.createdAt ?: now,
                )
            }
        }

        val cafe = Cafe(
            placeId = placeId,
            name = draft.cafeName,
            address = draft.cafeAddress.takeIf { it.isNotBlank() },
            latitude = null,
            longitude = null,
            photoReferences = emptyList(),
            websiteUrl = draft.cafeWebsiteUrl.takeIf { it.isNotBlank() },
            mapsUrl = draft.cafeMapsUrl.takeIf { it.isNotBlank() },
        )

        return Visit(
            id = id,
            userId = userId,
            cafe = cafe,
            visitedOn = draft.visitedOn,
            ambiance = draft.ambiance,
            rating = draft.rating,
            notes = draft.notes,
            photos = emptyList(),
            coffees = draft.coffees,
            foods = draft.foods,
            createdAt = createdAt,
            updatedAt = now,
        )
    }

    companion object {
        /**
         * [VisitDraft] の初期値を返す。
         * Create モードの初期 draft として、また onAppear 前のデフォルト値として使う。
         */
        fun defaultDraft(): VisitDraft = VisitDraft(
            cafeName = "",
            cafeAddress = "",
            cafeWebsiteUrl = "",
            cafeMapsUrl = "",
            visitedOn = Clock.System.todayIn(TimeZone.currentSystemDefault()),
            ambiance = "",
            rating = 0,
            notes = "",
            coffees = emptyList(),
            foods = emptyList(),
        )
    }
}

// --- プライベート拡張 ---

/**
 * [Visit] を [VisitEditorViewModel.VisitDraft] に変換する。
 * Edit モードで [VisitRepository.observeById] から取得した Visit を draft の初期値として使う。
 */
private fun Visit.toDraft(): VisitEditorViewModel.VisitDraft = VisitEditorViewModel.VisitDraft(
    cafeName = cafe.name,
    cafeAddress = cafe.address ?: "",
    cafeWebsiteUrl = cafe.websiteUrl ?: "",
    cafeMapsUrl = cafe.mapsUrl ?: "",
    visitedOn = visitedOn,
    ambiance = ambiance,
    rating = rating,
    notes = notes,
    coffees = coffees,
    foods = foods,
)

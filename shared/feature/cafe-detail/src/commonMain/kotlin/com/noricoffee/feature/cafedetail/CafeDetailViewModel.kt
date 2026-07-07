package com.noricoffee.feature.cafedetail

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.model.SavedCafe
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
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.datetime.Clock

/**
 * カフェ詳細画面の ViewModel。
 *
 * - 対象 [placeId] の過去 [CoffeeRecord] を [CoffeeRepository.observeAll] から購読・フィルタリングして
 *   [UIState.coffees] として公開する
 * - 過去記録がある場合は最新の `record.cafe` を [UIState.cafe] に採用する
 * - 過去記録がない場合（未訪問カフェ）は [initialCafe] を [UIState.cafe] に採用する
 *   （マップピンや検索結果からタップしたとき）
 * - [initialCafe] が null、または DB スナップショット由来で `googleRating` が未取得（= 鮮度が低い）の場合は
 *   [cafeRepository] から Places Details を 1 回取得し、[latestDetails] として保持する。
 *   取得できたらそれ以降の cafe 採用は常に [latestDetails] を最優先にする（フェーズ 16）
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面 push ごとに新規生成・pop で破棄すること。
 *
 * @param coffeeRepository [CoffeeRecord] の観測に使うリポジトリ
 * @param cafeRepository カフェ詳細の条件付きリフレッシュ（Places Details 取得）に使うリポジトリ（フェーズ 16）
 * @param savedCafeRepository 「行きたい店」の保存状態観測 / トグルに使うリポジトリ（フェーズ 15-A）
 * @param placeId 対象カフェの Google Places ID
 * @param initialCafe マップピン / 検索結果から渡される Cafe スナップショット（未訪問カフェ用）。
 *                    過去記録がある場合は最新記録の cafe で上書きされる
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] のファクトリメソッドから注入する
 */
class CafeDetailViewModel(
    private val coffeeRepository: CoffeeRepository,
    private val cafeRepository: CafeRepository,
    private val savedCafeRepository: SavedCafeRepository,
    private val placeId: String,
    private val initialCafe: Cafe?,
    private val userId: String,
    scope: CoroutineScope,
) {

    private val viewModelScope = CoroutineScope(
        scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])
    )

    /**
     * [cafeRepository] から取得できた最新の Places Details。
     *
     * 取得後は records の再 emit があっても、cafe 採用時にこの値を最優先にする
     * （DB スナップショットへの巻き戻りを防ぐ）。
     */
    private var latestDetails: Cafe? = null

    /**
     * カフェ詳細画面の UI 状態。
     *
     * @property cafe 対象カフェの Cafe スナップショット。
     *               過去記録があれば最新の `record.cafe`、なければ [initialCafe]。
     *               [initialCafe] も null の場合は `null`（表示側でハンドリングすること）
     * @property coffees 対象 [placeId] へのコーヒー記録一覧（visitedOn 降順）
     * @property isLoading 最初の emit を受け取るまで true
     * @property isSaved 「行きたい店」として保存済みか（フェーズ 15-A）。
     *   [SavedCafeRepository.observeByPlaceId] の購読で自動更新される
     * @property error [onSaveToggled] の保存 / 解除操作で発生したエラーメッセージ。
     *   [onErrorDismissed] で null に戻す
     */
    data class UIState(
        val cafe: Cafe? = null,
        val coffees: List<CoffeeRecord> = emptyList(),
        val isLoading: Boolean = true,
        val isSaved: Boolean = false,
        val error: String? = null,
    )

    private val _state = MutableStateFlow(UIState(cafe = initialCafe))
    val state: StateFlow<UIState> = _state.asStateFlow()

    init {
        viewModelScope.launch {
            coffeeRepository.observeAll(userId)
                .map { records ->
                    records
                        .filter { it.cafe?.placeId == placeId }
                        .sortedByDescending { it.visitedOn }
                }
                .collect { filteredRecords ->
                    val cafeSnapshot = latestDetails ?: filteredRecords.firstOrNull()?.cafe ?: initialCafe
                    _state.update {
                        it.copy(
                            cafe = cafeSnapshot,
                            coffees = filteredRecords,
                            isLoading = false,
                        )
                    }
                }
        }

        // 「行きたい店」の保存状態を購読する（フェーズ 15-A）。
        viewModelScope.launch {
            savedCafeRepository.observeByPlaceId(userId, placeId).collect { savedCafe ->
                _state.update { it.copy(isSaved = savedCafe != null) }
            }
        }

        // DB スナップショット由来（googleRating 未取得 = 鮮度が低い）の場合のみ Places Details を 1 回取得する
        // （フェーズ 16）。検索 / POI 由来の新鮮な initialCafe（googleRating != null）では API を叩かない。
        if (initialCafe == null || initialCafe.googleRating == null) {
            viewModelScope.launch {
                try {
                    val details = cafeRepository.getDetails(placeId)
                    latestDetails = details
                    _state.update { it.copy(cafe = details) }
                } catch (e: CancellationException) {
                    throw e
                } catch (e: Exception) {
                    // サイレントフォールバック: スナップショット表示を維持し、error は汚さない
                }
            }
        }
    }

    /**
     * 「行きたい店」ブックマークボタンのトグル操作を受ける（フェーズ 15-A）。
     *
     * 現在 [UIState.isSaved] が true なら [SavedCafeRepository.delete] で解除し、
     * false なら表示中の [UIState.cafe] からスナップショットを作って [SavedCafeRepository.save] する。
     * [UIState.cafe] が null（カフェ情報未取得）の場合は何もしない。
     *
     * `note` は v1 では常に空文字（フィールドだけ確保。編集 UI は将来追加）。
     */
    fun onSaveToggled() {
        val cafe = _state.value.cafe ?: return
        viewModelScope.launch {
            try {
                if (_state.value.isSaved) {
                    savedCafeRepository.delete(userId, placeId)
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
                // isSaved 自体は observeByPlaceId の購読に委ねているため巻き戻し処理は不要。
                // エラーメッセージのみ UI に伝える。
                _state.update { it.copy(error = e.message ?: "行きたい店の保存 / 解除に失敗しました") }
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
     * iOS Bridge の deinit または onDisappear で呼ぶこと（push/pop 画面のため必須）。
     * キャンセル後に各メソッドが呼ばれた場合は no-op になる（スコープはキャンセル済み）。
     */
    fun clear() {
        viewModelScope.cancel()
    }
}

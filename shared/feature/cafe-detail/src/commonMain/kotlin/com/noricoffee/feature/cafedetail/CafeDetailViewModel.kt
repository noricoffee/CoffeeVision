package com.noricoffee.feature.cafedetail

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.Visit
import com.noricoffee.repository.VisitRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/**
 * カフェ詳細画面の ViewModel。
 *
 * - 対象 [placeId] の過去 [Visit] を [VisitRepository.observeAll] から購読・フィルタリングして
 *   [CafeDetailUiState.pastVisits] として公開する
 * - 過去 Visit がある場合は最新の `visit.cafe` を [CafeDetailUiState.cafe] に採用する
 * - 過去 Visit がない場合（未訪問カフェ）は [initialCafe] を [CafeDetailUiState.cafe] に採用する
 *   （マップピンや検索結果からタップしたとき）
 *
 * ## CoroutineScope の注意
 *
 * [scope] は外部（[com.noricoffee.AppContainer] のファクトリメソッド）から注入する。
 * スコープは呼び出し元が管理し、画面 push ごとに新規生成・pop で破棄すること。
 *
 * @param visitRepository [Visit] の観測に使うリポジトリ
 * @param placeId 対象カフェの Google Places ID
 * @param initialCafe マップピン / 検索結果から渡される Cafe スナップショット（未訪問カフェ用）。
 *                    過去 Visit がある場合は最新 Visit の cafe で上書きされる
 * @param userId 現在サインイン中のユーザー ID
 * @param scope CoroutineScope。[com.noricoffee.AppContainer] のファクトリメソッドから注入する
 */
class CafeDetailViewModel(
    private val visitRepository: VisitRepository,
    private val placeId: String,
    private val initialCafe: Cafe?,
    private val userId: String,
    private val scope: CoroutineScope,
) {

    /**
     * カフェ詳細画面の UI 状態。
     *
     * @property cafe 対象カフェの Cafe スナップショット。
     *               過去 Visit があれば最新の `visit.cafe`、なければ [initialCafe]。
     *               [initialCafe] も null の場合は `null`（表示側でハンドリングすること）
     * @property pastVisits 対象 [placeId] への過去 Visit 一覧（visitedAt 降順）
     * @property isLoading 最初の emit を受け取るまで true
     */
    data class UIState(
        val cafe: Cafe? = null,
        val pastVisits: List<Visit> = emptyList(),
        val isLoading: Boolean = true,
    )

    private val _state = MutableStateFlow(UIState(cafe = initialCafe))
    val state: StateFlow<UIState> = _state.asStateFlow()

    init {
        scope.launch {
            visitRepository.observeAll(userId)
                .map { visits ->
                    visits
                        .filter { it.cafe.placeId == placeId }
                        .sortedByDescending { it.visitedOn }
                }
                .collect { filteredVisits ->
                    val cafeSnapshot = filteredVisits.firstOrNull()?.cafe ?: initialCafe
                    _state.update {
                        it.copy(
                            cafe = cafeSnapshot,
                            pastVisits = filteredVisits,
                            isLoading = false,
                        )
                    }
                }
        }
    }
}

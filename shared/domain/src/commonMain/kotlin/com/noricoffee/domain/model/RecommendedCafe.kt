package com.noricoffee.domain.model

import com.noricoffee.domain.Cafe
import kotlinx.coroutines.flow.Flow

/**
 * 味覚プロファイル一致によって推薦されるカフェ 1 件。
 *
 * `matches` は非空保証（理由が 1 つ以上あるカフェだけが [ObserveTasteMatchedCafesUseCase] から返される）。
 * マップ上で「あなた好みの一杯があった店」として強調表示するために使う。
 *
 * @property cafe placeId / 座標を持つカフェ情報（マップピン用）。最新記録時の Cafe スナップショット
 * @property matches 推薦理由の一覧（非空）。一致した軸ごとに 1 件ずつ格納される
 *
 * @see [data-model.md] §1.7
 */
data class RecommendedCafe(
    val cafe: Cafe,
    val matches: List<RecommendationReason>,  // 非空（理由が 0 件のカフェは返さない）
)

/**
 * 推薦理由。
 *
 * v1 はコンテンツベースの [TasteProfileMatch] のみ。
 * 将来の協調フィルタリング（9-6）では `SimilarUsers(...)` 等をここに追加し、
 * UI / VM / Foundation Models 連携は不変のまま種類を拡張できる。
 *
 * @see [data-model.md] §1.7
 */
sealed interface RecommendationReason {

    /**
     * v1（コンテンツベース）: 自分の好み属性に一致する高評価記録があった。
     *
     * @property axis 一致した好みの軸
     * @property matchedLabel 一致したラベル（例: "Ethiopia" / "Light" / "AeroPress"）。表示用
     * @property exampleRecordName 代表記録のコーヒー名（一致軸内の最高評価記録）
     * @property exampleRating 代表記録の評価（0.5..5.0）
     */
    data class TasteProfileMatch(
        val axis: PreferenceMatchAxis,
        val matchedLabel: String,
        val exampleRecordName: String,
        val exampleRating: Double,
    ) : RecommendationReason
}

/**
 * 好み属性の一致軸。
 *
 * v1 はカテゴリ好み 4 軸（産地 / 焙煎度 / 抽出方法 / 精製方法）に限定。
 * [FavoriteSignals.dominantTastingAxis]（相関軸）は per-record の categorical 一致に変換できないため
 * v1 の対象外とする（data-model.md §1.7 一致ルール参照）。
 */
enum class PreferenceMatchAxis { Origin, RoastLevel, BrewMethod, Processing }

/**
 * カフェ推薦の供給元インターフェース。
 *
 * v1 実装 = [com.noricoffee.domain.usecase.ObserveTasteMatchedCafesUseCase]（ローカル決定論）。
 * 将来の 9-6（協調フィルタリング）ではサーバ側のリモート実装に差し替えるだけで、
 * [com.noricoffee.feature.map.MapViewModel] / iOS UI / Foundation Models 連携は不変のまま切り替えられる。
 *
 * @see [data-model.md] §1.7「推薦ソースの抽象化」
 */
interface CafeRecommendationProvider {
    /**
     * 指定ユーザーの好みに一致するカフェを [Flow] で返す。
     *
     * 返すリストは「matches 件数降順 → 代表記録評価の最大降順 → placeId 昇順」で並んでいる。
     * [FavoriteSignals] が全 null（データ不足）のときは空リスト。
     *
     * @param userId 対象ユーザーの ID
     * @return 推薦カフェの Flow
     */
    fun observeRecommendedCafes(userId: String): Flow<List<RecommendedCafe>>
}

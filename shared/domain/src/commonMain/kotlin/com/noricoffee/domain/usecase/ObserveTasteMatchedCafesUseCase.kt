package com.noricoffee.domain.usecase

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.OriginNormalizer
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.FavoriteSignals
import com.noricoffee.domain.model.PreferenceMatchAxis
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.RecommendationReason
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map

/**
 * コンテンツベース（v1）のカフェ推薦ローカル実装。
 *
 * [CoffeeRepository.observeAll] から [CoffeeRecord] を監視し、
 * [BuildCoffeeStatsUseCase] で算出した [FavoriteSignals] のカテゴリ好み（産地 / 焙煎度 / 抽出方法）に
 * 一致する高評価記録（`rating >= RECOMMEND_MIN_RATING`）を持つカフェを
 * [RecommendedCafe] として返す。
 *
 * ## 一致ルール（data-model.md §1.7 準拠）
 *
 * - カフェは `cafe != null` を `cafe.placeId` でグループ化（セルフ抽出は対象外）
 * - あるカフェに `rating >= RECOMMEND_MIN_RATING` かつ [FavoriteSignals] のカテゴリ好みの
 *   いずれかに一致する記録が 1 件以上あれば [RecommendedCafe] として返す
 *   - **origin**: [OriginNormalizer] 正規化で `bestOrigin.label` の正規化結果と一致
 *   - **roastLevel**: enum 名一致（`bestRoastLevel.label == record.roastLevel?.name`）
 *   - **brewMethod**: enum 名一致（`bestBrewMethod.label == record.brewMethod.name`）
 *   - **processing**: enum 名一致（`bestProcessing.label == record.processing?.name`）
 * - [RecommendedCafe.cafe] は最新記録（visitedOn 最大）のカフェスナップショット
 * - `matches`: 一致した軸ごとに 1 つの [RecommendationReason.TasteProfileMatch]。
 *   同軸に複数の一致記録があれば**評価最高**を代表に採用（タイは visitedOn 新しい順 → name 昇順）
 * - [FavoriteSignals] が全 null（データ不足）なら空リスト
 * - 並び順: `matches` 件数降順 → 代表記録評価の最大降順 → placeId 昇順
 *
 * ## しきい値の統一
 *
 * [RECOMMEND_MIN_RATING] は [BuildCoffeeStatsUseCase] の `HIGHLIGHTS_MIN_RATING`（= 4.0）と
 * 同値にするが、`HIGHLIGHTS_MIN_RATING` が private のため本 UseCase の companion に定義する。
 * 値を変える場合は両者を揃えること。
 *
 * @param coffeeRepository [CoffeeRecord] の観測に使うリポジトリ
 * @param buildCoffeeStatsUseCase [FavoriteSignals] の算出に使う UseCase
 *
 * @see [data-model.md] §1.7
 * @see [CafeRecommendationProvider]
 */
class ObserveTasteMatchedCafesUseCase(
    private val coffeeRepository: CoffeeRepository,
    private val buildCoffeeStatsUseCase: BuildCoffeeStatsUseCase,
) : CafeRecommendationProvider {

    companion object {
        /**
         * 推薦の対象にする最低評価のしきい値。
         *
         * [BuildCoffeeStatsUseCase] の `HIGHLIGHTS_MIN_RATING`（= 4.0）と同値にする。
         * `HIGHLIGHTS_MIN_RATING` は private のため、本 UseCase の companion に定義する。
         * data-model.md §1.7「HIGHLIGHTS_MIN_RATING と統一」意図。
         */
        const val RECOMMEND_MIN_RATING = 4.0
    }

    /**
     * 指定ユーザーの好みに一致するカフェを [Flow] で返す。
     *
     * [CoffeeRepository.observeAll] の更新を受け取るたびに再集計し、
     * 最新の [RecommendedCafe] リストを emit する。
     *
     * @param userId 対象ユーザーの ID
     * @return 推薦カフェの Flow（matches 件数降順 → 代表評価降順 → placeId 昇順）
     */
    override fun observeRecommendedCafes(userId: String): Flow<List<RecommendedCafe>> =
        coffeeRepository.observeAll(userId).map { records ->
            buildRecommendedCafes(records)
        }

    // --- 内部実装 ---

    private fun buildRecommendedCafes(records: List<CoffeeRecord>): List<RecommendedCafe> {
        // FavoriteSignals を算出
        val stats = buildCoffeeStatsUseCase(records)
        val signals = stats.favoriteSignals

        // カテゴリ好み 4 軸すべて null なら空リスト（データ不足）
        if (
            signals.bestOrigin == null &&
            signals.bestRoastLevel == null &&
            signals.bestBrewMethod == null &&
            signals.bestProcessing == null
        ) {
            return emptyList()
        }

        // cafe != null のレコードを placeId でグループ化（セルフ抽出除外）
        val cafeGroups = records
            .filter { it.cafe != null }
            .groupBy { it.cafe!!.placeId }

        val result = mutableListOf<RecommendedCafe>()

        for ((_, group) in cafeGroups) {
            val recommendedCafe = buildRecommendedCafeOrNull(group, signals) ?: continue
            result.add(recommendedCafe)
        }

        // 並び順: matches 件数降順 → 代表記録評価の最大降順 → placeId 昇順
        return result.sortedWith(
            compareByDescending<RecommendedCafe> { it.matches.size }
                .thenByDescending { recommended ->
                    // 代表記録評価の最大（TasteProfileMatch の exampleRating の最大）
                    recommended.matches
                        .filterIsInstance<RecommendationReason.TasteProfileMatch>()
                        .maxOfOrNull { it.exampleRating } ?: 0.0
                }
                .thenBy { it.cafe.placeId },
        )
    }

    /**
     * 1 カフェ分のレコードグループから [RecommendedCafe] を構築する。
     *
     * 一致する軸が 1 つもなければ null を返す。
     *
     * @param cafeRecords 同一カフェの全 CoffeeRecord（cafe != null 保証済み）
     * @param signals ユーザーの好み信号
     */
    private fun buildRecommendedCafeOrNull(
        cafeRecords: List<CoffeeRecord>,
        signals: FavoriteSignals,
    ): RecommendedCafe? {
        // 最新記録のカフェスナップショット（visitedOn 最大値のレコード）
        val latestRecord = cafeRecords.maxBy { it.visitedOn }
        val cafe = latestRecord.cafe!!

        // 評価しきい値以上のレコードだけを候補にする（rating == null の未評価は対象外）
        val highRatedRecords = cafeRecords.filter { it.rating != null && it.rating >= RECOMMEND_MIN_RATING }

        val matches = mutableListOf<RecommendationReason.TasteProfileMatch>()

        // --- origin 軸 ---
        val bestOriginLabel = signals.bestOrigin?.label
        if (bestOriginLabel != null) {
            val originNormalized = OriginNormalizer.normalize(bestOriginLabel)
            val matchingRecords = highRatedRecords.filter {
                it.origin?.let { origin -> OriginNormalizer.normalize(origin) } == originNormalized
            }
            buildBestMatch(
                axis = PreferenceMatchAxis.Origin,
                matchedLabel = bestOriginLabel,
                matchingRecords = matchingRecords,
            )?.let { matches.add(it) }
        }

        // --- roastLevel 軸 ---
        val bestRoastLabel = signals.bestRoastLevel?.label
        if (bestRoastLabel != null) {
            val matchingRecords = highRatedRecords.filter {
                it.roastLevel?.name == bestRoastLabel
            }
            buildBestMatch(
                axis = PreferenceMatchAxis.RoastLevel,
                matchedLabel = bestRoastLabel,
                matchingRecords = matchingRecords,
            )?.let { matches.add(it) }
        }

        // --- brewMethod 軸 ---
        val bestBrewLabel = signals.bestBrewMethod?.label
        if (bestBrewLabel != null) {
            val matchingRecords = highRatedRecords.filter {
                it.brewMethod.name == bestBrewLabel
            }
            buildBestMatch(
                axis = PreferenceMatchAxis.BrewMethod,
                matchedLabel = bestBrewLabel,
                matchingRecords = matchingRecords,
            )?.let { matches.add(it) }
        }

        // --- processing 軸 ---
        val bestProcessingLabel = signals.bestProcessing?.label
        if (bestProcessingLabel != null) {
            val matchingRecords = highRatedRecords.filter {
                it.processing?.name == bestProcessingLabel
            }
            buildBestMatch(
                axis = PreferenceMatchAxis.Processing,
                matchedLabel = bestProcessingLabel,
                matchingRecords = matchingRecords,
            )?.let { matches.add(it) }
        }

        // 一致軸が 0 件なら推薦対象外
        if (matches.isEmpty()) return null

        return RecommendedCafe(cafe = cafe, matches = matches)
    }

    /**
     * 一致する記録群から最良の代表記録を選んで [RecommendationReason.TasteProfileMatch] を構築する。
     *
     * 代表選定: 評価最高 → タイは visitedOn 新しい順 → name 昇順（決定論）。
     * 一致記録が 0 件なら null を返す。
     *
     * @param axis 一致軸
     * @param matchedLabel 一致ラベル（表示用）
     * @param matchingRecords 一致する高評価記録の一覧
     */
    private fun buildBestMatch(
        axis: PreferenceMatchAxis,
        matchedLabel: String,
        matchingRecords: List<CoffeeRecord>,
    ): RecommendationReason.TasteProfileMatch? {
        if (matchingRecords.isEmpty()) return null

        // 評価最高 → visitedOn 新しい順 → name 昇順
        // sortedWith で代表順に並べ、先頭を採用する
        // （maxWith + compareByDescending の組み合わせは意図と逆になるため sortedWith を使う）
        val representative = matchingRecords.sortedWith(
            compareByDescending<CoffeeRecord> { it.rating }
                .thenByDescending { it.visitedOn }
                .thenBy { it.name },
        ).first()

        return RecommendationReason.TasteProfileMatch(
            axis = axis,
            matchedLabel = matchedLabel,
            exampleRecordName = representative.name,
            exampleRating = representative.rating!!, // matchingRecords は rating != null フィルタ済み
        )
    }
}

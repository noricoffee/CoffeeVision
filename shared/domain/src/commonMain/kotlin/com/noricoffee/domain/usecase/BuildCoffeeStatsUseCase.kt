package com.noricoffee.domain.usecase

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.model.CafeStat
import com.noricoffee.domain.model.CategoryStat
import com.noricoffee.domain.model.CoffeeStats
import com.noricoffee.domain.model.FavoriteSignals
import com.noricoffee.domain.model.MonthlyStat
import com.noricoffee.domain.model.RatingBucket
import com.noricoffee.domain.model.RecordDigest
import com.noricoffee.domain.model.TastingAverages
import com.noricoffee.domain.model.TastingRatedCount

/**
 * `List<CoffeeRecord>` から [CoffeeStats] を決定論的に算出する UseCase。
 *
 * 純粋関数的な集計のため、Repository や外部 IO への依存は持たない。
 * [ObserveCoffeeStatsUseCase] から呼ばれることを主目的とするが、単体でテストできる設計。
 *
 * ## 集計ルール
 * - **平均評価**: `rating == 0.0`（未評価 sentinel）は常に母数から除外。対象が 0 件なら `null`
 * - **`ratingHistogram`**: 0.5 刻みの存在するバケットのみ、rating 昇順
 * - **`byBrewMethod` / `byRoastLevel` / `byProcessing`**: label = enum.name、件数降順
 * - **`byProcessing` / `byRoastLevel`**: nullable。null の record は当該軸の集計から除外
 * - **`originRanking`**: 産地（自由文字列）を軽く正規化（前後空白除去 + lowercase）、件数降順、上位 [ORIGIN_RANKING_LIMIT] 件
 * - **`monthlyTrend`**: `visitedOn` の "YYYY-MM" 別、年月昇順
 * - **`topCafes`**: `cafe != null` のみを `cafe.placeId` でグループ化、件数降順、上位 [TOP_CAFES_LIMIT] 件
 * - **`recentHighlights`**: 高評価（rating >= 4.0）かつ直近の上位 [RECENT_HIGHLIGHTS_LIMIT] 件
 * - **`favoriteSignals`**: Phase B-1 まで全フィールド null の空 [FavoriteSignals] を返す
 *
 * @see [data-model.md] §1.6
 */
class BuildCoffeeStatsUseCase {

    companion object {
        /** [CoffeeStats.originRanking] に含める産地の上位件数。 */
        const val ORIGIN_RANKING_LIMIT = 10

        /** [CoffeeStats.topCafes] に含めるカフェの上位件数。 */
        const val TOP_CAFES_LIMIT = 10

        /** [CoffeeStats.recentHighlights] に含めるレコードの件数。 */
        const val RECENT_HIGHLIGHTS_LIMIT = 5

        /** [CoffeeStats.recentHighlights] に含める最低評価のしきい値。 */
        private const val HIGHLIGHTS_MIN_RATING = 4.0
    }

    /**
     * [records] から [CoffeeStats] を算出する。
     *
     * @param records 集計対象のコーヒー記録一覧
     * @return 集計結果
     */
    operator fun invoke(records: List<CoffeeRecord>): CoffeeStats {
        val ratedRecords = records.filter { it.rating > 0.0 }

        return CoffeeStats(
            totalCount = records.size,
            ratedCount = ratedRecords.size,
            averageRating = computeAverage(ratedRecords.map { it.rating }),
            ratingHistogram = buildRatingHistogram(records),
            byBrewMethod = buildBrewMethodStats(records),
            byRoastLevel = buildRoastLevelStats(records),
            byProcessing = buildProcessingStats(records),
            originRanking = buildOriginRanking(records),
            monthlyTrend = buildMonthlyTrend(records),
            topCafes = buildTopCafes(records),
            recentHighlights = buildRecentHighlights(records),
            favoriteSignals = FavoriteSignals(), // Phase B-1 まで空
            tastingAverages = buildTastingAverages(records),
        )
    }

    // --- 内部ヘルパ ---

    /**
     * rating リストの平均を計算する。空リストなら null。
     * 呼び出し元で 0.0（未評価）除外済みのリストを渡すこと。
     */
    private fun computeAverage(ratings: List<Double>): Double? {
        if (ratings.isEmpty()) return null
        return ratings.sum() / ratings.size
    }

    /**
     * 0.5 刻みの評価ヒストグラムを構築する。
     * rating == 0.0（未評価）は除外し、存在する刻みのみ昇順で返す。
     */
    private fun buildRatingHistogram(records: List<CoffeeRecord>): List<RatingBucket> {
        return records
            .filter { it.rating > 0.0 }
            .groupBy { it.rating }
            .map { (rating, group) -> RatingBucket(rating = rating, count = group.size) }
            .sortedBy { it.rating }
    }

    /**
     * 抽出方法別の統計を構築する。件数降順。
     */
    private fun buildBrewMethodStats(records: List<CoffeeRecord>): List<CategoryStat> {
        return records
            .groupBy { it.brewMethod.name }
            .map { (label, group) ->
                CategoryStat(
                    label = label,
                    count = group.size,
                    averageRating = computeAverage(group.filter { it.rating > 0.0 }.map { it.rating }),
                )
            }
            .sortedByDescending { it.count }
    }

    /**
     * 焙煎度別の統計を構築する。
     * `roastLevel == null` のレコードは除外。件数降順。
     */
    private fun buildRoastLevelStats(records: List<CoffeeRecord>): List<CategoryStat> {
        return records
            .filter { it.roastLevel != null }
            .groupBy { it.roastLevel!!.name }
            .map { (label, group) ->
                CategoryStat(
                    label = label,
                    count = group.size,
                    averageRating = computeAverage(group.filter { it.rating > 0.0 }.map { it.rating }),
                )
            }
            .sortedByDescending { it.count }
    }

    /**
     * 精製方法別の統計を構築する。
     * `processing == null` のレコードは除外。件数降順。
     */
    private fun buildProcessingStats(records: List<CoffeeRecord>): List<CategoryStat> {
        return records
            .filter { it.processing != null }
            .groupBy { it.processing!!.name }
            .map { (label, group) ->
                CategoryStat(
                    label = label,
                    count = group.size,
                    averageRating = computeAverage(group.filter { it.rating > 0.0 }.map { it.rating }),
                )
            }
            .sortedByDescending { it.count }
    }

    /**
     * 産地別のランキングを構築する。
     *
     * 産地文字列を **軽く正規化**（前後空白除去 + lowercase）してからグループ化する。
     * 完全な表記ゆれ名寄せ（エチオピア vs Ethiopia 等）は将来課題。
     * `origin == null` のレコードは除外。件数降順、上位 [ORIGIN_RANKING_LIMIT] 件。
     */
    private fun buildOriginRanking(records: List<CoffeeRecord>): List<CategoryStat> {
        return records
            .filter { it.origin != null }
            .groupBy { it.origin!!.trim().lowercase() }
            .map { (normalizedOrigin, group) ->
                // 表示ラベルはグループ内最初のレコードの元の表記を使用（trim のみ）
                val displayLabel = group.first().origin!!.trim()
                CategoryStat(
                    label = displayLabel,
                    count = group.size,
                    averageRating = computeAverage(group.filter { it.rating > 0.0 }.map { it.rating }),
                )
            }
            .sortedByDescending { it.count }
            .take(ORIGIN_RANKING_LIMIT)
    }

    /**
     * 月次推移を構築する。
     *
     * `visitedOn` の年月（"YYYY-MM"）ごとに件数・平均評価を集計し、年月昇順で返す。
     */
    private fun buildMonthlyTrend(records: List<CoffeeRecord>): List<MonthlyStat> {
        return records
            .groupBy { record ->
                val year = record.visitedOn.year.toString().padStart(4, '0')
                val month = record.visitedOn.monthNumber.toString().padStart(2, '0')
                "$year-$month"
            }
            .map { (yearMonth, group) ->
                MonthlyStat(
                    yearMonth = yearMonth,
                    count = group.size,
                    averageRating = computeAverage(group.filter { it.rating > 0.0 }.map { it.rating }),
                )
            }
            .sortedBy { it.yearMonth }
    }

    /**
     * よく行くカフェの統計を構築する。
     *
     * `cafe == null`（セルフ抽出）を除外し、`cafe.placeId` でグループ化する。
     * カフェ名（[CafeStat.name]）は最新記録（visitedOn が最も新しい）のスナップショットを採用。
     * 件数降順、上位 [TOP_CAFES_LIMIT] 件。
     */
    private fun buildTopCafes(records: List<CoffeeRecord>): List<CafeStat> {
        return records
            .filter { it.cafe != null }
            .groupBy { it.cafe!!.placeId }
            .map { (placeId, group) ->
                val latestRecord = group.maxBy { it.visitedOn }
                CafeStat(
                    placeId = placeId,
                    name = latestRecord.cafe!!.name,
                    count = group.size,
                    averageRating = computeAverage(group.filter { it.rating > 0.0 }.map { it.rating }),
                )
            }
            .sortedByDescending { it.count }
            .take(TOP_CAFES_LIMIT)
    }

    /**
     * Q&A 文脈用の代表レコードを構築する。
     *
     * 高評価（rating >= [HIGHLIGHTS_MIN_RATING]）のレコードを visitedOn 降順で並べ、
     * 上位 [RECENT_HIGHLIGHTS_LIMIT] 件を返す。
     * 高評価レコードが [RECENT_HIGHLIGHTS_LIMIT] 件未満の場合は全件を返す。
     */
    private fun buildRecentHighlights(records: List<CoffeeRecord>): List<RecordDigest> {
        return records
            .filter { it.rating >= HIGHLIGHTS_MIN_RATING }
            .sortedByDescending { it.visitedOn }
            .take(RECENT_HIGHLIGHTS_LIMIT)
            .map { record ->
                RecordDigest(
                    name = record.name,
                    rating = record.rating,
                    cafeName = record.cafe?.name,
                    visitedOn = record.visitedOn,
                )
            }
    }

    /**
     * テイスティング 5 要素それぞれの平均を構築する。
     *
     * 各要素は `null`（未設定）の記録を母数から除外した平均を算出する。
     * 1 件も設定が無い要素は `null`。[TastingRatedCount] に各要素の設定済み件数を入れる。
     *
     * @see [data-model.md] §1.6 集計ルール（tastingAverages）
     */
    private fun buildTastingAverages(records: List<CoffeeRecord>): TastingAverages {
        val sweetnessList = records.mapNotNull { it.tasting.sweetness }
        val bodyList = records.mapNotNull { it.tasting.body }
        val acidityList = records.mapNotNull { it.tasting.acidity }
        val flavorList = records.mapNotNull { it.tasting.flavor }
        val aftertasteList = records.mapNotNull { it.tasting.aftertaste }

        return TastingAverages(
            sweetness = computeIntAverage(sweetnessList),
            body = computeIntAverage(bodyList),
            acidity = computeIntAverage(acidityList),
            flavor = computeIntAverage(flavorList),
            aftertaste = computeIntAverage(aftertasteList),
            ratedCount = TastingRatedCount(
                sweetness = sweetnessList.size,
                body = bodyList.size,
                acidity = acidityList.size,
                flavor = flavorList.size,
                aftertaste = aftertasteList.size,
            ),
        )
    }

    /**
     * Int リストの平均を Double? で返す。空リストなら null。
     */
    private fun computeIntAverage(values: List<Int>): Double? {
        if (values.isEmpty()) return null
        return values.sum().toDouble() / values.size
    }
}

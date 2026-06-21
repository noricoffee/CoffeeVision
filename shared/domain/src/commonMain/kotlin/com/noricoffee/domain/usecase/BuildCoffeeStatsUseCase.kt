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
import com.noricoffee.domain.model.TastingAxis
import com.noricoffee.domain.model.TastingAxisCorrelation
import kotlin.math.sqrt

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
 * - **`favoriteSignals`**: 経験ベイズ収縮（[SHRINKAGE_PRIOR_WEIGHT]）でカテゴリ好みを選定し、
 *   ピアソン相関（[CORRELATION_MIN_SAMPLE] / [CORRELATION_MIN_ABS]）でテイスティング軸を選定する
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

        /**
         * 経験ベイズ収縮の事前重み（k）。
         *
         * 「全体平均を [SHRINKAGE_PRIOR_WEIGHT] 杯ぶん事前情報として混ぜる」解釈。
         * 少数群の極端な平均値を全体平均へ寄せ、サンプルサイズの罠を緩和する。
         * `shrunkMean = (n·mean + k·globalMean) / (n + k)`
         */
        const val SHRINKAGE_PRIOR_WEIGHT = 5

        /**
         * [FavoriteSignals.dominantTastingAxis] を算出するためのピアソン相関の最低母数。
         *
         * `tasting != null` かつ `rating > 0.0` のレコードがこの件数未満なら `dominantTastingAxis` は null。
         */
        const val CORRELATION_MIN_SAMPLE = 5

        /**
         * [FavoriteSignals.dominantTastingAxis] を信号として採用する最低 |r|（絶対値）の閾値。
         *
         * この値未満の相関は「弱すぎる」として null にする。
         */
        const val CORRELATION_MIN_ABS = 0.3
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
            favoriteSignals = buildFavoriteSignals(records),
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
     * all-or-nothing 方式のため、`tasting != null` の記録だけを母数にする。
     * tasting を持つ記録が 1 件も無い場合は各要素 null、ratedCount = 0。
     * 5 要素の母数は常に同じ（ratedCount は単一 Int）。
     *
     * @see [data-model.md] §1.6 集計ルール（tastingAverages）
     */
    private fun buildTastingAverages(records: List<CoffeeRecord>): TastingAverages {
        val tastingRecords = records.filter { it.tasting != null }
        val ratedCount = tastingRecords.size

        return TastingAverages(
            sweetness = computeIntAverage(tastingRecords.map { it.tasting!!.sweetness }),
            body = computeIntAverage(tastingRecords.map { it.tasting!!.body }),
            acidity = computeIntAverage(tastingRecords.map { it.tasting!!.acidity }),
            flavor = computeIntAverage(tastingRecords.map { it.tasting!!.flavor }),
            aftertaste = computeIntAverage(tastingRecords.map { it.tasting!!.aftertaste }),
            ratedCount = ratedCount,
        )
    }

    /**
     * Int リストの平均を Double? で返す。空リストなら null。
     */
    private fun computeIntAverage(values: List<Int>): Double? {
        if (values.isEmpty()) return null
        return values.sum().toDouble() / values.size
    }

    /**
     * 階層2（傾向抽出）の [FavoriteSignals] を算出する。
     *
     * ## カテゴリ好み（bestBrewMethod / bestOrigin / bestRoastLevel）
     *
     * 1. 評価済み（rating > 0.0）レコードの全体平均 globalMean を算出。0 件なら 3 つとも null。
     * 2. 各軸で `count >= minSampleSize` かつ平均評価ありの候補を列挙。
     * 3. 経験ベイズ収縮: `shrunkMean = (n·mean + k·globalMean) / (n + k)`（k = [SHRINKAGE_PRIOR_WEIGHT]）。
     * 4. shrunkMean 最大かつ `shrunkMean > globalMean` の候補を採用（正方向のみ信号化）。
     *    なければ null。タイは件数多 → label 昇順で決定論化。
     * 5. 返す [CategoryStat] は**生の averageRating と count**（収縮値は選定キーのみ）。
     *
     * ## 好みの軸（dominantTastingAxis）
     *
     * 1. `tasting != null` かつ `rating > 0.0` のレコードが [CORRELATION_MIN_SAMPLE] 未満なら null。
     * 2. 5 軸それぞれと rating のピアソン相関 r（符号付き）を計算。分散 0 の軸はスキップ。
     * 3. |r| 最大の軸を採用。|r| < [CORRELATION_MIN_ABS] なら null。
     */
    private fun buildFavoriteSignals(records: List<CoffeeRecord>): FavoriteSignals {
        val signals = FavoriteSignals()
        val minSample = signals.minSampleSize

        val ratedRecords = records.filter { it.rating > 0.0 }
        val globalMean = computeAverage(ratedRecords.map { it.rating })
            ?: return FavoriteSignals() // 評価済み 0 件 → 全フィールド null のデフォルト

        return FavoriteSignals(
            bestBrewMethod = selectBestCategory(
                candidateGroups = ratedRecords.groupBy { it.brewMethod.name },
                ratingExtractor = { it.rating },
                globalMean = globalMean,
                minSampleSize = minSample,
            ),
            bestOrigin = buildBestOrigin(ratedRecords, globalMean, minSample),
            bestRoastLevel = selectBestCategory(
                candidateGroups = ratedRecords
                    .filter { it.roastLevel != null }
                    .groupBy { it.roastLevel!!.name },
                ratingExtractor = { it.rating },
                globalMean = globalMean,
                minSampleSize = minSample,
            ),
            dominantTastingAxis = buildDominantTastingAxis(ratedRecords),
        )
    }

    /**
     * レコード群をカテゴリ別にグループ化し、経験ベイズ収縮で最良カテゴリを選定する。
     *
     * 返す [CategoryStat] は**生の averageRating と count**（収縮値は選定キーのみ）。
     * タイ時は件数多 → label 昇順で決定論化。
     * `shrunkMean <= globalMean` の場合は null を返す（正方向のみ信号化）。
     *
     * @param candidateGroups カテゴリ label → [CoffeeRecord] リストのマップ
     * @param ratingExtractor レコードから rating を取り出すラムダ（コールサイトで既フィルタ済みを想定）
     * @param globalMean 全評価済みレコードの平均評価
     * @param minSampleSize 件数ガードのしきい値
     */
    private fun selectBestCategory(
        candidateGroups: Map<String, List<CoffeeRecord>>,
        ratingExtractor: (CoffeeRecord) -> Double,
        globalMean: Double,
        minSampleSize: Int,
    ): CategoryStat? {
        val k = SHRINKAGE_PRIOR_WEIGHT.toDouble()

        // 各カテゴリの (label, count, mean, shrunkMean) を計算し、候補リストを構築
        val labels = mutableListOf<String>()
        val counts = mutableListOf<Int>()
        val means = mutableListOf<Double>()
        val shrunkMeans = mutableListOf<Double>()

        for ((label, group) in candidateGroups) {
            if (group.size < minSampleSize) continue
            val groupRatings = group.map { ratingExtractor(it) }
            val mean = computeAverage(groupRatings) ?: continue
            val shrunkMean = (group.size * mean + k * globalMean) / (group.size + k)
            labels.add(label)
            counts.add(group.size)
            means.add(mean)
            shrunkMeans.add(shrunkMean)
        }

        if (labels.isEmpty()) return null

        // shrunkMean 降順 → count 降順 → label 昇順 で最良候補のインデックスを選定
        var bestIdx = 0
        for (i in 1 until labels.size) {
            val better = when {
                shrunkMeans[i] > shrunkMeans[bestIdx] -> true
                shrunkMeans[i] < shrunkMeans[bestIdx] -> false
                counts[i] > counts[bestIdx] -> true
                counts[i] < counts[bestIdx] -> false
                else -> labels[i] < labels[bestIdx]
            }
            if (better) bestIdx = i
        }

        if (shrunkMeans[bestIdx] <= globalMean) return null

        return CategoryStat(
            label = labels[bestIdx],
            count = counts[bestIdx],
            averageRating = means[bestIdx],
        )
    }

    /**
     * 産地軸の bestOrigin を選定する。
     *
     * 産地は自由文字列のため `buildOriginRanking` と同じ正規化（`trim().lowercase()` でグループ化、
     * 表示ラベルはグループ内最初に出現した元表記の `trim()` のみ）を適用してから
     * [selectBestCategory] に委譲する。
     */
    private fun buildBestOrigin(
        ratedRecords: List<CoffeeRecord>,
        globalMean: Double,
        minSampleSize: Int,
    ): CategoryStat? {
        // 正規化キーでグループ化（trim().lowercase()）
        val normalizedGroups: Map<String, List<CoffeeRecord>> = ratedRecords
            .filter { it.origin != null }
            .groupBy { it.origin!!.trim().lowercase() }

        if (normalizedGroups.isEmpty()) return null

        val k = SHRINKAGE_PRIOR_WEIGHT.toDouble()

        // 各産地グループの (displayLabel, count, mean, shrunkMean) を計算
        val labels = mutableListOf<String>()
        val counts = mutableListOf<Int>()
        val means = mutableListOf<Double>()
        val shrunkMeans = mutableListOf<Double>()

        for ((_, group) in normalizedGroups) {
            if (group.size < minSampleSize) continue
            val displayLabel = group.first().origin!!.trim()
            val ratings = group.map { it.rating }
            val mean = computeAverage(ratings) ?: continue
            val shrunkMean = (group.size * mean + k * globalMean) / (group.size + k)
            labels.add(displayLabel)
            counts.add(group.size)
            means.add(mean)
            shrunkMeans.add(shrunkMean)
        }

        if (labels.isEmpty()) return null

        // shrunkMean 降順 → count 降順 → label 昇順 で最良候補のインデックスを選定
        var bestIdx = 0
        for (i in 1 until labels.size) {
            val better = when {
                shrunkMeans[i] > shrunkMeans[bestIdx] -> true
                shrunkMeans[i] < shrunkMeans[bestIdx] -> false
                counts[i] > counts[bestIdx] -> true
                counts[i] < counts[bestIdx] -> false
                else -> labels[i] < labels[bestIdx]
            }
            if (better) bestIdx = i
        }

        if (shrunkMeans[bestIdx] <= globalMean) return null

        return CategoryStat(
            label = labels[bestIdx],
            count = counts[bestIdx],
            averageRating = means[bestIdx],
        )
    }

    /**
     * テイスティング軸と評価のピアソン相関から [TastingAxisCorrelation] を算出する。
     *
     * 母数（tasting != null かつ rating > 0.0 の件数）が [CORRELATION_MIN_SAMPLE] 未満なら null。
     * 分散 0 の軸はスキップ。|r| < [CORRELATION_MIN_ABS] なら null。
     */
    private fun buildDominantTastingAxis(ratedRecords: List<CoffeeRecord>): TastingAxisCorrelation? {
        val sampleRecords = ratedRecords.filter { it.tasting != null }
        val sampleSize = sampleRecords.size

        if (sampleSize < CORRELATION_MIN_SAMPLE) return null

        val ratings = sampleRecords.map { it.rating }

        data class AxisResult(val axis: TastingAxis, val r: Double)

        val results = listOf(
            TastingAxis.Sweetness to sampleRecords.map { it.tasting!!.sweetness.toDouble() },
            TastingAxis.Body to sampleRecords.map { it.tasting!!.body.toDouble() },
            TastingAxis.Acidity to sampleRecords.map { it.tasting!!.acidity.toDouble() },
            TastingAxis.Flavor to sampleRecords.map { it.tasting!!.flavor.toDouble() },
            TastingAxis.Aftertaste to sampleRecords.map { it.tasting!!.aftertaste.toDouble() },
        ).mapNotNull { (axis, axisValues) ->
            val r = pearsonCorrelation(axisValues, ratings) ?: return@mapNotNull null
            AxisResult(axis, r)
        }

        if (results.isEmpty()) return null

        val best = results.maxBy { kotlin.math.abs(it.r) }

        if (kotlin.math.abs(best.r) < CORRELATION_MIN_ABS) return null

        return TastingAxisCorrelation(
            axis = best.axis,
            correlation = best.r,
            sampleSize = sampleSize,
        )
    }

    /**
     * ピアソン相関係数 r を計算する。
     *
     * 分散が 0（全件同値）の場合は相関が定義できないため null を返す。
     *
     * @param xs 独立変数のリスト（テイスティング軸の値）
     * @param ys 従属変数のリスト（rating）
     * @return 符号付き相関係数 r（-1.0..1.0）、または null（分散 0 の場合）
     */
    private fun pearsonCorrelation(xs: List<Double>, ys: List<Double>): Double? {
        val n = xs.size
        if (n == 0) return null

        val meanX = xs.sum() / n
        val meanY = ys.sum() / n

        val cov = xs.zip(ys).sumOf { (x, y) -> (x - meanX) * (y - meanY) } / n
        val stdX = sqrt(xs.sumOf { (it - meanX) * (it - meanX) } / n)
        val stdY = sqrt(ys.sumOf { (it - meanY) * (it - meanY) } / n)

        if (stdX == 0.0 || stdY == 0.0) return null

        return cov / (stdX * stdY)
    }
}

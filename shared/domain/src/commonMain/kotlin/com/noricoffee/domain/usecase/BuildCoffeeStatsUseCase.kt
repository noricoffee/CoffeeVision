package com.noricoffee.domain.usecase

import com.noricoffee.domain.BeanProfile
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
         * [FavoriteSignals.dominantTastingAxis] を信号として採用する最低 |r|（絶対値）の下限。
         *
         * この値未満の相関は「弱すぎる」として null にする。
         * [CORRELATION_ABS_FLOOR] とは別に、絶対的な下限として機能する。
         */
        const val CORRELATION_MIN_ABS = 0.3

        /**
         * カテゴリ好み（bestBrewMethod / bestOrigin / bestRoastLevel）を信号として採用するための
         * n 連動信頼区間ゲートの z スコア係数。
         *
         * 実効閾値 = `CATEGORY_Z * globalStd / sqrt(n)`（一標本 z 検定近似）。
         * これを候補群の `mean - globalMean` が超えたとき**かつ** `shrunkMean - globalMean > CATEGORY_MIN_EFFECT`
         * の 2 条件を AND で満たす場合のみ信号化する。
         *
         * 固定オフセット δ（`CATEGORY_MIN_EFFECT` 単独）では winner's curse（最良群の偶然の上振れが
         * サンプリングばらつき σ/√n に比例して膨らむ）を止められない（B-1d 前段実測: heavy-skew 86.7%）。
         * n 連動（ばらつき連動）の閾値にすることで根治する。
         *
         * 暫定値 2.0（B-1d sweep で確定。候補: 1.5 / 2.0 / 2.5 / 3.0）。
         */
        const val CATEGORY_Z = 2.0

        /**
         * カテゴリ好み（bestBrewMethod / bestOrigin / bestRoastLevel）を信号として採用するための
         * 絶対下限 effect-size（`shrunkMean - globalMean` の最低差）。
         *
         * n 連動 z ゲート（[CATEGORY_Z]）と AND で使用する小さな絶対下限。
         * 「統計的には有意だが実用上は誤差レベル」を弾くための追加ガード。
         * [CATEGORY_Z] ゲートを満たしても収縮平均が全体平均をこの値以下しか上回らない場合は
         * 信号化しない。
         *
         * 値は [FavoriteSignalsPersonaTest] の sweep で確定（B-1c で 0.20 に確定済）。
         */
        const val CATEGORY_MIN_EFFECT = 0.20

        /**
         * [FavoriteSignals.dominantTastingAxis] を信号として採用するサンプル数連動の |r| 下限係数。
         *
         * 実効下限 = `max(CORRELATION_MIN_ABS, CORRELATION_ABS_FLOOR_C / sqrt(n))`。
         * n が小さいほど閾値が高くなり、5 軸の max |r| を選ぶ多重比較（B-1b 実測 40%）を
         * サンプル数に応じて締める。
         *
         * 係数 c は [FavoriteSignalsPersonaTest] の sweep で確定。
         * n=30 での実効閾値: c≈1.64→0.30 / c≈1.97→0.36 / c≈2.30→0.42。
         */
        const val CORRELATION_ABS_FLOOR_C = 1.97
    }

    /**
     * [records] から [CoffeeStats] を算出する。
     *
     * @param records 集計対象のコーヒー記録一覧
     * @param beanProfiles 突合に使う [BeanProfile] リスト。空リストの場合は [CoffeeStats.preferredBeanTraits] を null、
     *   [CoffeeStats.unexploredBeanSuggestions] を空リストにする
     * @return 集計結果
     */
    operator fun invoke(
        records: List<CoffeeRecord>,
        beanProfiles: List<BeanProfile> = emptyList(),
    ): CoffeeStats {
        val ratedRecords = records.filter { it.rating > 0.0 }
        val favoriteSignals = buildFavoriteSignals(records)

        val preferredBeanTraits = if (beanProfiles.isNotEmpty()) {
            PreferredBeanTraitsUseCase()(beanProfiles, favoriteSignals)
        } else {
            null
        }

        val unexploredBeanSuggestions = if (beanProfiles.isNotEmpty()) {
            SuggestUnexploredBeansUseCase()(records, beanProfiles, favoriteSignals)
        } else {
            emptyList()
        }

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
            favoriteSignals = favoriteSignals,
            tastingAverages = buildTastingAverages(records),
            preferredBeanTraits = preferredBeanTraits,
            unexploredBeanSuggestions = unexploredBeanSuggestions,
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
     * 1. 評価済み（rating > 0.0）レコードの全体平均 globalMean と
     *    全体母標準偏差 globalStd（`sqrt(Σ(r-globalMean)²/N)`）を算出。
     *    0 件なら 3 つとも null。
     * 2. 各軸で `count >= minSampleSize` かつ平均評価ありの候補を列挙。
     * 3. 経験ベイズ収縮: `shrunkMean = (n·mean + k·globalMean) / (n + k)`（k = [SHRINKAGE_PRIOR_WEIGHT]）。
     * 4. 選定: shrunkMean 最大の候補。足切りは次の 2 条件 AND:
     *    - n 連動 z ゲート: `mean - globalMean > CATEGORY_Z * globalStd / sqrt(n)`
     *      （globalStd == 0.0 の場合は全件同値なので z ゲートをスキップ = ゼロ除算回避）
     *    - 絶対下限: `shrunkMean - globalMean > CATEGORY_MIN_EFFECT`（δ）
     *    なければ null。タイは件数多 → label 昇順で決定論化。
     * 5. 返す [CategoryStat] は**生の averageRating と count**（収縮値・ゲートは選定/足切りの内部利用のみ）。
     *
     * ## 好みの軸（dominantTastingAxis）
     *
     * 1. `tasting != null` かつ `rating > 0.0` のレコードが [CORRELATION_MIN_SAMPLE] 未満なら null。
     * 2. 5 軸それぞれと rating のピアソン相関 r（符号付き）を計算。分散 0 の軸はスキップ。
     * 3. |r| 最大の軸を採用。
     *    実効下限 = `max(CORRELATION_MIN_ABS, CORRELATION_ABS_FLOOR_C / sqrt(n))` 未満なら null
     *    （B-1b 実測で 5 軸 max |r| の多重比較により偽陽性 40% を確認したため n 連動で締める）。
     */
    private fun buildFavoriteSignals(records: List<CoffeeRecord>): FavoriteSignals {
        val signals = FavoriteSignals()
        val minSample = signals.minSampleSize

        val ratedRecords = records.filter { it.rating > 0.0 }
        val globalMean = computeAverage(ratedRecords.map { it.rating })
            ?: return FavoriteSignals() // 評価済み 0 件 → 全フィールド null のデフォルト

        // 全評価済み rating の母標準偏差（B-1d z ゲート用）
        val globalStd = computeGlobalStd(ratedRecords.map { it.rating }, globalMean)

        return FavoriteSignals(
            bestBrewMethod = selectBestCategory(
                candidateGroups = ratedRecords.groupBy { it.brewMethod.name },
                ratingExtractor = { it.rating },
                globalMean = globalMean,
                globalStd = globalStd,
                minSampleSize = minSample,
            ),
            bestOrigin = buildBestOrigin(ratedRecords, globalMean, globalStd, minSample),
            bestRoastLevel = selectBestCategory(
                candidateGroups = ratedRecords
                    .filter { it.roastLevel != null }
                    .groupBy { it.roastLevel!!.name },
                ratingExtractor = { it.rating },
                globalMean = globalMean,
                globalStd = globalStd,
                minSampleSize = minSample,
            ),
            dominantTastingAxis = buildDominantTastingAxis(ratedRecords),
        )
    }

    /**
     * 全評価済み rating の母標準偏差を計算する。
     *
     * `sqrt(Σ(r - mean)² / N)`。全件同値（分散 = 0）の場合は 0.0 を返す。
     * 呼び出し元で 0.0（未評価）除外済みのリストと事前計算済みの mean を渡すこと。
     *
     * @param ratings 評価済み rating のリスト
     * @param mean リストの平均（事前計算済み）
     * @return 母標準偏差（0.0 = 全件同値）
     */
    private fun computeGlobalStd(ratings: List<Double>, mean: Double): Double {
        if (ratings.isEmpty()) return 0.0
        val variance = ratings.sumOf { (it - mean) * (it - mean) } / ratings.size
        return sqrt(variance)
    }

    /**
     * レコード群をカテゴリ別にグループ化し、経験ベイズ収縮で最良カテゴリを選定する。
     *
     * 返す [CategoryStat] は**生の averageRating と count**（収縮値・ゲートは選定/足切りの内部利用のみ）。
     * タイ時は件数多 → label 昇順で決定論化。
     *
     * 足切り条件（AND）:
     * 1. n 連動 z ゲート: `mean - globalMean > CATEGORY_Z * globalStd / sqrt(n)`
     *    （B-1d: winner's curse はばらつき σ/√n に比例するため n 連動の閾値で根治。
     *    globalStd == 0.0 = 全件同値のときはゼロ除算回避のため z ゲートをスキップ）
     * 2. 絶対下限: `shrunkMean - globalMean > CATEGORY_MIN_EFFECT`（δ）
     *    （「統計的には有意だが実用上は誤差レベル」を弾く小さな AND 下限）
     *
     * @param candidateGroups カテゴリ label → [CoffeeRecord] リストのマップ
     * @param ratingExtractor レコードから rating を取り出すラムダ（コールサイトで既フィルタ済みを想定）
     * @param globalMean 全評価済みレコードの平均評価
     * @param globalStd 全評価済みレコードの母標準偏差（[computeGlobalStd] で算出）
     * @param minSampleSize 件数ガードのしきい値
     */
    private fun selectBestCategory(
        candidateGroups: Map<String, List<CoffeeRecord>>,
        ratingExtractor: (CoffeeRecord) -> Double,
        globalMean: Double,
        globalStd: Double,
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

        val bestMean = means[bestIdx]
        val bestN = counts[bestIdx]
        val bestShrunkMean = shrunkMeans[bestIdx]

        // 条件 1: n 連動 z ゲート（globalStd == 0.0 の場合はゼロ除算回避のためスキップ）
        if (globalStd > 0.0) {
            val zThreshold = CATEGORY_Z * globalStd / sqrt(bestN.toDouble())
            if (bestMean - globalMean <= zThreshold) return null
        }

        // 条件 2: 絶対下限（shrunkMean が globalMean を CATEGORY_MIN_EFFECT より大きく超えるとき信号化）
        if (bestShrunkMean - globalMean <= CATEGORY_MIN_EFFECT) return null

        return CategoryStat(
            label = labels[bestIdx],
            count = bestN,
            averageRating = bestMean,
        )
    }

    /**
     * 産地軸の bestOrigin を選定する。
     *
     * 産地は自由文字列のため `buildOriginRanking` と同じ正規化（`trim().lowercase()` でグループ化、
     * 表示ラベルはグループ内最初に出現した元表記の `trim()` のみ）を適用してから
     * [selectBestCategory] と同じ選定ロジック（収縮 + z ゲート + δ AND）を適用する。
     *
     * @param ratedRecords 評価済み（rating > 0.0）レコード
     * @param globalMean 全評価済みレコードの平均評価
     * @param globalStd 全評価済みレコードの母標準偏差（[computeGlobalStd] で算出）
     * @param minSampleSize 件数ガードのしきい値
     */
    private fun buildBestOrigin(
        ratedRecords: List<CoffeeRecord>,
        globalMean: Double,
        globalStd: Double,
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

        val bestMean = means[bestIdx]
        val bestN = counts[bestIdx]
        val bestShrunkMean = shrunkMeans[bestIdx]

        // 条件 1: n 連動 z ゲート（globalStd == 0.0 の場合はゼロ除算回避のためスキップ）
        if (globalStd > 0.0) {
            val zThreshold = CATEGORY_Z * globalStd / sqrt(bestN.toDouble())
            if (bestMean - globalMean <= zThreshold) return null
        }

        // 条件 2: 絶対下限
        if (bestShrunkMean - globalMean <= CATEGORY_MIN_EFFECT) return null

        return CategoryStat(
            label = labels[bestIdx],
            count = bestN,
            averageRating = bestMean,
        )
    }

    /**
     * テイスティング軸と評価のピアソン相関から [TastingAxisCorrelation] を算出する。
     *
     * 母数（tasting != null かつ rating > 0.0 の件数）が [CORRELATION_MIN_SAMPLE] 未満なら null。
     * 分散 0 の軸はスキップ。|r| < effectiveFloor なら null。
     *
     * **実効下限（effectiveFloor）**:
     * `max(CORRELATION_MIN_ABS, CORRELATION_ABS_FLOOR_C / sqrt(n))`
     * n が小さいほど閾値を高くし、5 軸から max |r| を拾う多重比較（B-1b 実測 40% の偽陽性）を
     * サンプル数に応じて締める。CORRELATION_MIN_ABS は絶対下限として機能する。
     */
    private fun buildDominantTastingAxis(ratedRecords: List<CoffeeRecord>): TastingAxisCorrelation? {
        val sampleRecords = ratedRecords.filter { it.tasting != null }
        val sampleSize = sampleRecords.size

        if (sampleSize < CORRELATION_MIN_SAMPLE) return null

        // サンプル数連動の |r| 下限: max(絶対下限, c / sqrt(n))
        val effectiveFloor = maxOf(CORRELATION_MIN_ABS, CORRELATION_ABS_FLOOR_C / sqrt(sampleSize.toDouble()))

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

        if (kotlin.math.abs(best.r) < effectiveFloor) return null

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

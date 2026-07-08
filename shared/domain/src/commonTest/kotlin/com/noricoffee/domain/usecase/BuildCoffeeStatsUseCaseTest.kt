package com.noricoffee.domain.usecase

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import com.noricoffee.domain.model.TastingAxis
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [BuildCoffeeStatsUseCase] の集計ロジックをユニットテストする。
 *
 * 純粋関数なので Repository 不要で直接テストできる。
 */
class BuildCoffeeStatsUseCaseTest {

    private val useCase = BuildCoffeeStatsUseCase()

    // --- ヘルパ ---

    private fun cafe(
        placeId: String,
        name: String = "カフェ $placeId",
    ) = Cafe(
        placeId = placeId,
        name = name,
        address = null,
        latitude = null,
        longitude = null,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )

    private fun record(
        id: String,
        rating: Double = 3.0,
        visitedOn: LocalDate = LocalDate(2026, 6, 1),
        brewMethod: BrewMethod = BrewMethod.HandDrip,
        origin: String? = null,
        processing: ProcessingMethod? = null,
        roastLevel: RoastLevel? = null,
        cafe: Cafe? = null,
        name: String = "Test Coffee $id",
        tasting: TastingScores? = null,
    ) = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = cafe,
        visitedOn = visitedOn,
        rating = rating,
        notes = "",
        photos = emptyList(),
        name = name,
        brewMethod = brewMethod,
        origin = origin,
        variety = null,
        processing = processing,
        roastLevel = roastLevel,
        cup = null,
        brewRecipe = null,
        tasting = tasting,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    // --- 基本ケース ---

    @Test
    fun emptyList_returnsZeroCountAndNullAverageAndEmptyLists() {
        val stats = useCase(emptyList())

        assertEquals(0, stats.totalCount)
        assertEquals(0, stats.ratedCount)
        assertNull(stats.averageRating)
        assertTrue(stats.ratingHistogram.isEmpty())
        assertTrue(stats.byBrewMethod.isEmpty())
        assertTrue(stats.byRoastLevel.isEmpty())
        assertTrue(stats.byProcessing.isEmpty())
        assertTrue(stats.originRanking.isEmpty())
        assertTrue(stats.monthlyTrend.isEmpty())
        assertTrue(stats.topCafes.isEmpty())
        assertTrue(stats.recentHighlights.isEmpty())
        // favoriteSignals は全 null（空リストは評価済みレコードなし → globalMean null → 全 null）
        assertNull(stats.favoriteSignals.bestBrewMethod)
        assertNull(stats.favoriteSignals.bestOrigin)
        assertNull(stats.favoriteSignals.bestRoastLevel)
        assertNull(stats.favoriteSignals.dominantTastingAxis)
        assertEquals(3, stats.favoriteSignals.minSampleSize)
        // tastingAverages は全 null・ratedCount = 0
        assertNull(stats.tastingAverages.sweetness)
        assertNull(stats.tastingAverages.body)
        assertNull(stats.tastingAverages.acidity)
        assertNull(stats.tastingAverages.flavor)
        assertNull(stats.tastingAverages.aftertaste)
        assertEquals(0, stats.tastingAverages.ratedCount)
    }

    @Test
    fun singleRecord_returnsTotalCount1AndCorrectAverage() {
        val records = listOf(record("r1", rating = 4.5))

        val stats = useCase(records)

        assertEquals(1, stats.totalCount)
        assertEquals(1, stats.ratedCount)
        assertEquals(4.5, stats.averageRating)
    }

    // --- 未評価（rating 0.0）の除外 ---

    @Test
    fun unratedRecord_isExcludedFromAverageAndRatedCount() {
        val records = listOf(
            record("r1", rating = 0.0),
            record("r2", rating = 4.0),
            record("r3", rating = 3.0),
        )

        val stats = useCase(records)

        assertEquals(3, stats.totalCount)
        assertEquals(2, stats.ratedCount)
        // (4.0 + 3.0) / 2 = 3.5
        assertEquals(3.5, stats.averageRating)
    }

    @Test
    fun allUnrated_averageRatingIsNull() {
        val records = listOf(
            record("r1", rating = 0.0),
            record("r2", rating = 0.0),
        )

        val stats = useCase(records)

        assertEquals(2, stats.totalCount)
        assertEquals(0, stats.ratedCount)
        assertNull(stats.averageRating)
    }

    @Test
    fun unratedRecord_notIncludedInRatingHistogram() {
        val records = listOf(
            record("r1", rating = 0.0),  // 未評価: ヒストグラムに入らない
            record("r2", rating = 4.0),
            record("r3", rating = 4.0),
            record("r4", rating = 5.0),
        )

        val stats = useCase(records)

        // 0.0 のバケットは存在しない
        assertTrue(stats.ratingHistogram.none { it.rating == 0.0 })
        assertEquals(2, stats.ratingHistogram.size) // 4.0 と 5.0 の 2 バケット
        val bucket40 = stats.ratingHistogram.first { it.rating == 4.0 }
        assertEquals(2, bucket40.count)
        val bucket50 = stats.ratingHistogram.first { it.rating == 5.0 }
        assertEquals(1, bucket50.count)
    }

    // --- ratingHistogram ---

    @Test
    fun ratingHistogram_isInAscendingOrderByRating() {
        val records = listOf(
            record("r1", rating = 5.0),
            record("r2", rating = 3.0),
            record("r3", rating = 1.0),
            record("r4", rating = 4.5),
        )

        val stats = useCase(records)

        val ratings = stats.ratingHistogram.map { it.rating }
        assertEquals(listOf(1.0, 3.0, 4.5, 5.0), ratings)
    }

    @Test
    fun ratingHistogram_onlyContainsExistingBuckets() {
        val records = listOf(
            record("r1", rating = 3.5),
            record("r2", rating = 3.5),
            record("r3", rating = 5.0),
        )

        val stats = useCase(records)

        assertEquals(2, stats.ratingHistogram.size)
        assertEquals(2, stats.ratingHistogram.first { it.rating == 3.5 }.count)
        assertEquals(1, stats.ratingHistogram.first { it.rating == 5.0 }.count)
    }

    // --- カテゴリ集計（brewMethod） ---

    @Test
    fun byBrewMethod_countIsCorrectAndSortedByCountDescending() {
        val records = listOf(
            record("r1", brewMethod = BrewMethod.HandDrip, rating = 4.0),
            record("r2", brewMethod = BrewMethod.HandDrip, rating = 3.0),
            record("r3", brewMethod = BrewMethod.Espresso, rating = 5.0),
            record("r4", brewMethod = BrewMethod.HandDrip, rating = 0.0), // 未評価
        )

        val stats = useCase(records)

        // HandDrip が 3 件で 1 位
        assertEquals("HandDrip", stats.byBrewMethod[0].label)
        assertEquals(3, stats.byBrewMethod[0].count)
        // HandDrip の平均 = (4 + 3) / 2 = 3.5（未評価 0.0 除外）
        assertEquals(3.5, stats.byBrewMethod[0].averageRating)

        assertEquals("Espresso", stats.byBrewMethod[1].label)
        assertEquals(1, stats.byBrewMethod[1].count)
        assertEquals(5.0, stats.byBrewMethod[1].averageRating)
    }

    @Test
    fun byBrewMethod_averageRatingIsNullWhenAllUnrated() {
        val records = listOf(
            record("r1", brewMethod = BrewMethod.AeroPress, rating = 0.0),
        )

        val stats = useCase(records)

        val aeroPress = stats.byBrewMethod.first { it.label == "AeroPress" }
        assertNull(aeroPress.averageRating)
    }

    // --- カテゴリ集計（roastLevel） ---

    @Test
    fun byRoastLevel_nullRoastLevelRecordsAreExcluded() {
        val records = listOf(
            record("r1", roastLevel = RoastLevel.Light, rating = 4.0),
            record("r2", roastLevel = null, rating = 5.0),   // 除外
            record("r3", roastLevel = RoastLevel.Medium, rating = 3.0),
            record("r4", roastLevel = RoastLevel.Light, rating = 4.5),
        )

        val stats = useCase(records)

        // roastLevel=null の r2 は除外される
        assertEquals(2, stats.byRoastLevel.size)
        val lightStat = stats.byRoastLevel.first { it.label == "Light" }
        assertEquals(2, lightStat.count)
        // (4.0 + 4.5) / 2 = 4.25
        assertEquals(4.25, lightStat.averageRating)
    }

    @Test
    fun byRoastLevel_sortedByCountDescending() {
        val records = listOf(
            record("r1", roastLevel = RoastLevel.City),
            record("r2", roastLevel = RoastLevel.Light),
            record("r3", roastLevel = RoastLevel.Light),
            record("r4", roastLevel = RoastLevel.Medium),
            record("r5", roastLevel = RoastLevel.Medium),
            record("r6", roastLevel = RoastLevel.Medium),
        )

        val stats = useCase(records)

        assertEquals("Medium", stats.byRoastLevel[0].label)
        assertEquals(3, stats.byRoastLevel[0].count)
        assertEquals("Light", stats.byRoastLevel[1].label)
        assertEquals(2, stats.byRoastLevel[1].count)
    }

    // --- カテゴリ集計（processing） ---

    @Test
    fun byProcessing_nullProcessingRecordsAreExcluded() {
        val records = listOf(
            record("r1", processing = ProcessingMethod.Natural, rating = 5.0),
            record("r2", processing = null, rating = 4.0),     // 除外
            record("r3", processing = ProcessingMethod.Washed, rating = 3.0),
        )

        val stats = useCase(records)

        assertEquals(2, stats.byProcessing.size)
        assertTrue(stats.byProcessing.none { it.label == "null" })
    }

    @Test
    fun byProcessing_averageAndCountAreCorrect() {
        val records = listOf(
            record("r1", processing = ProcessingMethod.Natural, rating = 4.0),
            record("r2", processing = ProcessingMethod.Natural, rating = 0.0), // 未評価
            record("r3", processing = ProcessingMethod.Natural, rating = 5.0),
        )

        val stats = useCase(records)

        val natural = stats.byProcessing.first { it.label == "Natural" }
        assertEquals(3, natural.count)
        // (4.0 + 5.0) / 2 = 4.5（未評価 0.0 除外）
        assertEquals(4.5, natural.averageRating)
    }

    // --- originRanking ---

    @Test
    fun originRanking_nullOriginRecordsAreExcluded() {
        val records = listOf(
            record("r1", origin = "エチオピア"),
            record("r2", origin = null),      // 除外
            record("r3", origin = "ケニア"),
        )

        val stats = useCase(records)

        assertEquals(2, stats.originRanking.size)
    }

    @Test
    fun originRanking_normalizedByLowercaseAndTrim() {
        val records = listOf(
            record("r1", origin = "Ethiopia"),
            record("r2", origin = "ethiopia"),    // lowercase で同じグループ
            record("r3", origin = "  Ethiopia "), // trim + lowercase で同じグループ
        )

        val stats = useCase(records)

        // 軽い正規化で 3 件が同一グループとして集計される
        assertEquals(1, stats.originRanking.size)
        assertEquals(3, stats.originRanking.first().count)
    }

    @Test
    fun originRanking_synonymNormalizationGroupsEthiopiaVariants() {
        // "Ethiopia"（英語国名シノニム）と "エチオピア"（正規形そのもの）は
        // OriginNormalizer の名寄せにより同一グループとして集計される
        val records = listOf(
            record("r1", origin = "Ethiopia"),
            record("r2", origin = "エチオピア"),
            record("r3", origin = "  Ethiopia  "),
        )

        val stats = useCase(records)

        assertEquals(1, stats.originRanking.size)
        assertEquals(3, stats.originRanking.first().count)
    }

    @Test
    fun originRanking_sortedByCountDescending() {
        val records = listOf(
            record("r1", origin = "ケニア"),
            record("r2", origin = "エチオピア"),
            record("r3", origin = "ケニア"),
            record("r4", origin = "エチオピア"),
            record("r5", origin = "エチオピア"),
        )

        val stats = useCase(records)

        assertEquals("エチオピア", stats.originRanking[0].label)
        assertEquals(3, stats.originRanking[0].count)
        assertEquals("ケニア", stats.originRanking[1].label)
        assertEquals(2, stats.originRanking[1].count)
    }

    @Test
    fun originRanking_limitedToOriginRankingLimit() {
        // 上位 N 件のみ返す（ORIGIN_RANKING_LIMIT = 10）
        val records = (1..15).map { i ->
            record("r$i", origin = "origin-$i")
        }

        val stats = useCase(records)

        assertTrue(stats.originRanking.size <= BuildCoffeeStatsUseCase.ORIGIN_RANKING_LIMIT)
    }

    // --- monthlyTrend ---

    @Test
    fun monthlyTrend_sortedByYearMonthAscending() {
        val records = listOf(
            record("r1", visitedOn = LocalDate(2026, 6, 15)),
            record("r2", visitedOn = LocalDate(2026, 3, 1)),
            record("r3", visitedOn = LocalDate(2026, 6, 1)),
            record("r4", visitedOn = LocalDate(2025, 12, 31)),
        )

        val stats = useCase(records)

        val yearMonths = stats.monthlyTrend.map { it.yearMonth }
        assertEquals(listOf("2025-12", "2026-03", "2026-06"), yearMonths)
    }

    @Test
    fun monthlyTrend_countAndAverageAreCorrect() {
        val records = listOf(
            record("r1", visitedOn = LocalDate(2026, 6, 1), rating = 4.0),
            record("r2", visitedOn = LocalDate(2026, 6, 15), rating = 3.0),
            record("r3", visitedOn = LocalDate(2026, 6, 30), rating = 0.0), // 未評価
        )

        val stats = useCase(records)

        assertEquals(1, stats.monthlyTrend.size)
        val june = stats.monthlyTrend.first()
        assertEquals("2026-06", june.yearMonth)
        assertEquals(3, june.count)
        // (4.0 + 3.0) / 2 = 3.5（未評価 0.0 除外）
        assertEquals(3.5, june.averageRating)
    }

    @Test
    fun monthlyTrend_yearMonthFormat() {
        val records = listOf(
            record("r1", visitedOn = LocalDate(2026, 1, 5)), // 月が 1 桁
        )

        val stats = useCase(records)

        assertEquals("2026-01", stats.monthlyTrend.first().yearMonth)
    }

    // --- topCafes ---

    @Test
    fun topCafes_nullCafeRecordsAreExcluded() {
        val records = listOf(
            record("r1", cafe = cafe("place-1"), rating = 4.0),
            record("r2", cafe = null, rating = 5.0),     // セルフ抽出: 除外
            record("r3", cafe = null, rating = 3.0),     // セルフ抽出: 除外
        )

        val stats = useCase(records)

        assertEquals(1, stats.topCafes.size)
        assertEquals("place-1", stats.topCafes.first().placeId)
    }

    @Test
    fun topCafes_groupedByPlaceIdSortedByCountDescending() {
        val records = listOf(
            record("r1", cafe = cafe("place-A"), rating = 5.0),
            record("r2", cafe = cafe("place-B"), rating = 4.0),
            record("r3", cafe = cafe("place-A"), rating = 3.0),
            record("r4", cafe = cafe("place-B"), rating = 4.5),
            record("r5", cafe = cafe("place-A"), rating = 4.0),
        )

        val stats = useCase(records)

        assertEquals(2, stats.topCafes.size)
        assertEquals("place-A", stats.topCafes[0].placeId)
        assertEquals(3, stats.topCafes[0].count)
        // (5.0 + 3.0 + 4.0) / 3 = 4.0
        assertEquals(4.0, stats.topCafes[0].averageRating)
        assertEquals("place-B", stats.topCafes[1].placeId)
        assertEquals(2, stats.topCafes[1].count)
    }

    @Test
    fun topCafes_nameIsLatestRecordSnapshot() {
        val records = listOf(
            record("r1", cafe = cafe("place-1", "古い名前"), visitedOn = LocalDate(2026, 1, 1)),
            record("r2", cafe = cafe("place-1", "新しい名前"), visitedOn = LocalDate(2026, 6, 1)),
        )

        val stats = useCase(records)

        // 最新記録（visitedOn が新しい）のスナップショットを採用
        assertEquals("新しい名前", stats.topCafes.first().name)
    }

    @Test
    fun topCafes_limitedToTopCafesLimit() {
        val records = (1..15).map { i ->
            record("r$i", cafe = cafe("place-$i"))
        }

        val stats = useCase(records)

        assertTrue(stats.topCafes.size <= BuildCoffeeStatsUseCase.TOP_CAFES_LIMIT)
    }

    // --- recentHighlights ---

    @Test
    fun recentHighlights_onlyHighRatedRecordsIncluded() {
        val records = listOf(
            record("r1", rating = 4.0, visitedOn = LocalDate(2026, 6, 1)),
            record("r2", rating = 3.5, visitedOn = LocalDate(2026, 6, 2)), // 閾値未満: 除外
            record("r3", rating = 5.0, visitedOn = LocalDate(2026, 6, 3)),
            record("r4", rating = 4.5, visitedOn = LocalDate(2026, 6, 4)),
        )

        val stats = useCase(records)

        // rating >= 4.0 のみ
        assertTrue(stats.recentHighlights.all { it.rating >= 4.0 })
        assertEquals(3, stats.recentHighlights.size)
    }

    @Test
    fun recentHighlights_sortedByVisitedOnDescending() {
        val records = listOf(
            record("r1", rating = 4.5, visitedOn = LocalDate(2026, 4, 1)),
            record("r2", rating = 4.5, visitedOn = LocalDate(2026, 6, 1)),
            record("r3", rating = 4.5, visitedOn = LocalDate(2026, 5, 1)),
        )

        val stats = useCase(records)

        val dates = stats.recentHighlights.map { it.visitedOn }
        assertEquals(
            listOf(LocalDate(2026, 6, 1), LocalDate(2026, 5, 1), LocalDate(2026, 4, 1)),
            dates,
        )
    }

    @Test
    fun recentHighlights_limitedToRecentHighlightsLimit() {
        val records = (1..10).map { i ->
            record("r$i", rating = 5.0, visitedOn = LocalDate(2026, 6, i))
        }

        val stats = useCase(records)

        assertTrue(stats.recentHighlights.size <= BuildCoffeeStatsUseCase.RECENT_HIGHLIGHTS_LIMIT)
    }

    @Test
    fun recentHighlights_cafeNameIsNullForSelfExtraction() {
        val records = listOf(
            record("r1", rating = 5.0, cafe = null),  // セルフ抽出
        )

        val stats = useCase(records)

        assertNull(stats.recentHighlights.first().cafeName)
    }

    @Test
    fun recentHighlights_cafeNameIsPresentForCafeRecord() {
        val records = listOf(
            record("r1", rating = 5.0, cafe = cafe("place-1", "Blue Bottle")),
        )

        val stats = useCase(records)

        assertEquals("Blue Bottle", stats.recentHighlights.first().cafeName)
    }

    // --- favoriteSignals (Phase B-1: カテゴリ好み + 相関軸) ---

    // ---- カテゴリ好み共通ルール ----

    @Test
    fun favoriteSignals_allRatedZero_returnsAllNull() {
        // 評価済み 0 件 → globalMean 算出不可 → 3 つとも null
        val records = listOf(
            record("r1", rating = 0.0, brewMethod = BrewMethod.HandDrip),
            record("r2", rating = 0.0, brewMethod = BrewMethod.HandDrip),
        )

        val stats = useCase(records)

        assertNull(stats.favoriteSignals.bestBrewMethod)
        assertNull(stats.favoriteSignals.bestOrigin)
        assertNull(stats.favoriteSignals.bestRoastLevel)
        assertNull(stats.favoriteSignals.dominantTastingAxis)
    }

    @Test
    fun favoriteSignals_bestBrewMethod_shrinkageOverridesSmallHighRated() {
        // n=1 の 5.0（AeroPress）が n 多の 4.0（HandDrip×5）に収縮で逆転する
        // globalMean = (5.0 + 4.0×5) / 6 = 4.166...
        // shrunk(AeroPress, n=1) = (1×5.0 + 5×4.166) / 6 = 4.305
        // shrunk(HandDrip, n=5) = (5×4.0 + 5×4.166) / 10 = 4.083
        // → 件数ガード(minSampleSize=3)でAeroPress(n=1)は候補外
        // → HandDrip(n=5) のみ候補。shrunk=4.083 > globalMean=4.166? → No(4.083 < 4.166) → null
        // ※ この構成では正方向信号が出ない（bestBrewMethod = null）ことを検証
        val records = listOf(
            record("r1", rating = 5.0, brewMethod = BrewMethod.AeroPress),
            record("r2", rating = 4.0, brewMethod = BrewMethod.HandDrip),
            record("r3", rating = 4.0, brewMethod = BrewMethod.HandDrip),
            record("r4", rating = 4.0, brewMethod = BrewMethod.HandDrip),
            record("r5", rating = 4.0, brewMethod = BrewMethod.HandDrip),
            record("r6", rating = 4.0, brewMethod = BrewMethod.HandDrip),
        )

        val stats = useCase(records)

        // AeroPress は minSampleSize 未満で候補外、HandDrip は shrunk <= globalMean → null
        assertNull(stats.favoriteSignals.bestBrewMethod)
    }

    @Test
    fun favoriteSignals_bestBrewMethod_highVolumeHighRated_isSelected() {
        // HandDrip が高件数かつ高評価 → z ゲートと δ 下限を満たして採用
        // n=10 で z ゲートを通るデータ設計（z=2.0 の場合 threshold = 2.0 * globalStd / sqrt(n)）
        // globalMean = (4.5×10 + 3.0×10) / 20 = 3.75
        // globalStd = sqrt((10×0.5625 + 10×0.5625) / 20) = 0.75
        // HandDrip: mean=4.5, n=10, zThreshold = 2.0 * 0.75 / sqrt(10) ≈ 0.474
        //   mean - globalMean = 0.75 > 0.474 → z ゲート通過
        // shrunk(HandDrip, n=10) = (10×4.5 + 5×3.75) / 15 = 4.25 > 3.75
        //   shrunkMean - globalMean = 0.50 > 0.20(δ) → δ 下限通過 → 採用
        // Espresso: mean=3.0 → z ゲートで弾かれる（mean - globalMean = -0.75 < 0）
        val records = (1..10).map { i ->
            record("r-hd-$i", rating = 4.5, brewMethod = BrewMethod.HandDrip)
        } + (1..10).map { i ->
            record("r-esp-$i", rating = 3.0, brewMethod = BrewMethod.Espresso)
        }

        val stats = useCase(records)

        assertNotNull(stats.favoriteSignals.bestBrewMethod)
        assertEquals("HandDrip", stats.favoriteSignals.bestBrewMethod!!.label)
        assertEquals(10, stats.favoriteSignals.bestBrewMethod!!.count)
        assertEquals(4.5, stats.favoriteSignals.bestBrewMethod!!.averageRating)
    }

    @Test
    fun favoriteSignals_countBelowMinSampleSize_isExcluded() {
        // count < minSampleSize(=3) の群は候補外
        // HandDrip n=2（候補外）、Espresso n=2（候補外）→ 両方 null
        val records = listOf(
            record("r1", rating = 5.0, brewMethod = BrewMethod.HandDrip),
            record("r2", rating = 5.0, brewMethod = BrewMethod.HandDrip),
            record("r3", rating = 1.0, brewMethod = BrewMethod.Espresso),
            record("r4", rating = 1.0, brewMethod = BrewMethod.Espresso),
        )

        val stats = useCase(records)

        // 全カテゴリが minSampleSize 未満 → null
        assertNull(stats.favoriteSignals.bestBrewMethod)
    }

    @Test
    fun favoriteSignals_allCategoriesAtOrBelowGlobalMean_returnsNull() {
        // 全カテゴリの shrunkMean が globalMean 以下 → null
        // globalMean = (3.5×3 + 3.5×3) / 6 = 3.5
        // shrunk(HandDrip, n=3) = (3×3.5 + 5×3.5) / 8 = 3.5 = globalMean → 正方向でない → null
        val records = listOf(
            record("r1", rating = 3.5, brewMethod = BrewMethod.HandDrip),
            record("r2", rating = 3.5, brewMethod = BrewMethod.HandDrip),
            record("r3", rating = 3.5, brewMethod = BrewMethod.HandDrip),
            record("r4", rating = 3.5, brewMethod = BrewMethod.Espresso),
            record("r5", rating = 3.5, brewMethod = BrewMethod.Espresso),
            record("r6", rating = 3.5, brewMethod = BrewMethod.Espresso),
        )

        val stats = useCase(records)

        assertNull(stats.favoriteSignals.bestBrewMethod)
    }

    @Test
    fun favoriteSignals_bestBrewMethod_tieByCountThenLabel() {
        // 収縮平均が同じときは件数多 → label 昇順で決定論化
        // AeroPress n=10 mean=4.5 と HandDrip n=10 mean=4.5 はまったく同一の shrunkMean
        // → 件数同等 → label 昇順（AeroPress < HandDrip） → AeroPress が選ばれる
        // n=10 で z ゲートを通るデータ設計:
        // globalMean = (4.5×10 + 4.5×10 + 2.0×10) / 30 ≈ 3.667
        // globalStd = sqrt((10×0.694 + 10×0.694 + 10×2.778)/30) ≈ 1.178
        // AeroPress: mean=4.5, n=10, zThreshold = 2.0 * 1.178 / sqrt(10) ≈ 0.745
        //   mean - globalMean ≈ 0.833 > 0.745 → z ゲート通過
        // shrunk(AeroPress, n=10) = (10×4.5 + 5×3.667) / 15 = 4.222
        //   shrunkMean - globalMean ≈ 0.556 > 0.20(δ) → 採用
        // AeroPress と HandDrip は shrunkMean も n も同じ → label 昇順で AeroPress
        val records = (1..10).map { i ->
            record("r-aero-$i", rating = 4.5, brewMethod = BrewMethod.AeroPress)
        } + (1..10).map { i ->
            record("r-hand-$i", rating = 4.5, brewMethod = BrewMethod.HandDrip)
        } + (1..10).map { i ->
            record("r-esp-$i", rating = 2.0, brewMethod = BrewMethod.Espresso)
        }

        val stats = useCase(records)

        assertNotNull(stats.favoriteSignals.bestBrewMethod)
        assertEquals("AeroPress", stats.favoriteSignals.bestBrewMethod!!.label)
    }

    @Test
    fun favoriteSignals_bestRoastLevel_nullRoastIsExcluded() {
        // roastLevel=null のレコードは bestRoastLevel の集計から除外
        // Light n=10, null roast n=10（集計対象外）
        // globalMean = (4.5×10 + 3.0×10) / 20 = 3.75
        // globalStd = 0.75
        // Light: mean=4.5, n=10, zThreshold = 2.0 * 0.75 / sqrt(10) ≈ 0.474
        //   mean - globalMean = 0.75 > 0.474 → z ゲート通過
        // shrunk(Light, n=10) = (10×4.5 + 5×3.75) / 15 = 4.25
        //   shrunkMean - globalMean = 0.50 > 0.20(δ) → 採用
        val records = (1..10).map { i ->
            record("r-light-$i", rating = 4.5, roastLevel = RoastLevel.Light)
        } + (1..10).map { i ->
            record("r-null-$i", rating = 3.0, roastLevel = null)
        }

        val stats = useCase(records)

        assertNotNull(stats.favoriteSignals.bestRoastLevel)
        assertEquals("Light", stats.favoriteSignals.bestRoastLevel!!.label)
    }

    @Test
    fun favoriteSignals_bestOrigin_normalizationGroupsVariants() {
        // "Ethiopia" / "ethiopia" / " Ethiopia " は同一グループとして集計される（trim().lowercase()）
        // 表示ラベルはグループ内最初の元表記の trim()（= "Ethiopia"）
        // n=10 で z ゲートを通るデータ設計:
        // globalMean = (4.5×10 + 2.0×10) / 20 = 3.25
        // globalStd = sqrt((10×1.5625 + 10×1.5625) / 20) = 1.25
        // Ethiopia: mean=4.5, n=10, zThreshold = 2.0 * 1.25 / sqrt(10) ≈ 0.790
        //   mean - globalMean = 1.25 > 0.790 → z ゲート通過
        // shrunk(Ethiopia, n=10) = (10×4.5 + 5×3.25) / 15 = 4.083
        //   shrunkMean - globalMean = 0.833 > 0.20(δ) → 採用
        val ethioRecords = listOf(
            record("r1", rating = 4.5, origin = "Ethiopia"),
            record("r2", rating = 4.5, origin = "ethiopia"),    // 正規化で Ethiopia と同グループ
            record("r3", rating = 4.5, origin = " Ethiopia "), // 正規化で Ethiopia と同グループ
        ) + (4..10).map { i ->
            record("r$i", rating = 4.5, origin = "Ethiopia")
        }
        val brazilRecords = (1..10).map { i ->
            record("rb$i", rating = 2.0, origin = "Brazil")
        }
        val records = ethioRecords + brazilRecords

        val stats = useCase(records)

        assertNotNull(stats.favoriteSignals.bestOrigin)
        // 表示ラベルは最初の元表記の trim()
        assertEquals("Ethiopia", stats.favoriteSignals.bestOrigin!!.label)
        assertEquals(10, stats.favoriteSignals.bestOrigin!!.count)
    }

    @Test
    fun favoriteSignals_bestOrigin_synonymNormalizationGroupsVariants() {
        // "Ethiopia"（英語国名シノニム）と "エチオピア"（正規形）は OriginNormalizer の名寄せで
        // 同一グループとして集計される（データ設計は favoriteSignals_bestOrigin_normalizationGroupsVariants と同じ）
        val ethioRecords = listOf(
            record("r1", rating = 4.5, origin = "Ethiopia"),
            record("r2", rating = 4.5, origin = "エチオピア"),   // シノニムで Ethiopia と同グループ
            record("r3", rating = 4.5, origin = "  Ethiopia "),
        ) + (4..10).map { i ->
            record("r$i", rating = 4.5, origin = "Ethiopia")
        }
        val brazilRecords = (1..10).map { i ->
            record("rb$i", rating = 2.0, origin = "Brazil")
        }
        val records = ethioRecords + brazilRecords

        val stats = useCase(records)

        assertNotNull(stats.favoriteSignals.bestOrigin)
        // 表示ラベルは最初の元表記の trim()
        assertEquals("Ethiopia", stats.favoriteSignals.bestOrigin!!.label)
        assertEquals(10, stats.favoriteSignals.bestOrigin!!.count)
    }

    // ---- dominantTastingAxis ----

    @Test
    fun favoriteSignals_dominantTastingAxis_positiveFlavor() {
        // flavor が rating と正の相関（高 flavor = 高 rating）
        // 5件（CORRELATION_MIN_SAMPLE 満たす）
        val tHigh = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 9, aftertaste = 5)
        val tLow = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 2, aftertaste = 5)
        val records = listOf(
            record("r1", rating = 5.0, tasting = tHigh),
            record("r2", rating = 5.0, tasting = tHigh),
            record("r3", rating = 3.0, tasting = tLow),
            record("r4", rating = 3.0, tasting = tLow),
            record("r5", rating = 4.0, tasting = TastingScores(5, 5, 5, 5, 5)), // 中間
        )

        val stats = useCase(records)

        assertNotNull(stats.favoriteSignals.dominantTastingAxis)
        assertEquals(TastingAxis.Flavor, stats.favoriteSignals.dominantTastingAxis!!.axis)
        assertTrue(stats.favoriteSignals.dominantTastingAxis!!.correlation > 0.0)
        assertEquals(5, stats.favoriteSignals.dominantTastingAxis!!.sampleSize)
    }

    @Test
    fun favoriteSignals_dominantTastingAxis_negativBodyCorrelation() {
        // body が rating と負の相関（低 body = 高 rating）
        val tHighBody = TastingScores(sweetness = 5, body = 9, acidity = 5, flavor = 5, aftertaste = 5)
        val tLowBody = TastingScores(sweetness = 5, body = 2, acidity = 5, flavor = 5, aftertaste = 5)
        val records = listOf(
            record("r1", rating = 2.0, tasting = tHighBody),
            record("r2", rating = 2.0, tasting = tHighBody),
            record("r3", rating = 5.0, tasting = tLowBody),
            record("r4", rating = 5.0, tasting = tLowBody),
            record("r5", rating = 3.5, tasting = TastingScores(5, 5, 5, 5, 5)),
        )

        val stats = useCase(records)

        assertNotNull(stats.favoriteSignals.dominantTastingAxis)
        assertEquals(TastingAxis.Body, stats.favoriteSignals.dominantTastingAxis!!.axis)
        assertTrue(stats.favoriteSignals.dominantTastingAxis!!.correlation < 0.0)
    }

    @Test
    fun favoriteSignals_dominantTastingAxis_insufficientSample_returnsNull() {
        // tasting 記録が CORRELATION_MIN_SAMPLE(5) 未満 → null
        val t = TastingScores(8, 5, 7, 9, 8)
        val records = listOf(
            record("r1", rating = 5.0, tasting = t),
            record("r2", rating = 5.0, tasting = t),
            record("r3", rating = 4.0, tasting = t),
            record("r4", rating = 3.0, tasting = t),
            // 4件だけ（5件未満）
        )

        val stats = useCase(records)

        assertNull(stats.favoriteSignals.dominantTastingAxis)
    }

    @Test
    fun favoriteSignals_dominantTastingAxis_weakCorrelation_returnsNull() {
        // 全軸で |r| < 0.3 になるデータ設計:
        // sweetness=[5,3,8,2,6], body=[5,5,5,5,5](分散0→スキップ),
        // acidity=[6,4,7,3,5], flavor=[5,5,5,5,5](分散0→スキップ), aftertaste=[4,6,3,7,5]
        // rating=[3.5,4.0,4.0,3.5,3.5]
        // → sweetness: r≈0.268, acidity: r≈0.289, aftertaste: r≈-0.289 → 全て |r| < 0.3
        val records = listOf(
            record("r1", rating = 3.5, tasting = TastingScores(sweetness = 5, body = 5, acidity = 6, flavor = 5, aftertaste = 4)),
            record("r2", rating = 4.0, tasting = TastingScores(sweetness = 3, body = 5, acidity = 4, flavor = 5, aftertaste = 6)),
            record("r3", rating = 4.0, tasting = TastingScores(sweetness = 8, body = 5, acidity = 7, flavor = 5, aftertaste = 3)),
            record("r4", rating = 3.5, tasting = TastingScores(sweetness = 2, body = 5, acidity = 3, flavor = 5, aftertaste = 7)),
            record("r5", rating = 3.5, tasting = TastingScores(sweetness = 6, body = 5, acidity = 5, flavor = 5, aftertaste = 5)),
        )

        val stats = useCase(records)

        // 全軸で |r| < 0.3 → dominantTastingAxis は null
        assertNull(stats.favoriteSignals.dominantTastingAxis)
    }

    @Test
    fun favoriteSignals_dominantTastingAxis_zeroVarianceAxis_isSkipped() {
        // 1 軸だけ全件同値（分散 0）→ その軸はスキップ、他軸で相関を見る
        // sweetness が全件 5 → 分散 0 でスキップ
        // flavor に強い正相関がある
        val records = listOf(
            record("r1", rating = 5.0, tasting = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 9, aftertaste = 5)),
            record("r2", rating = 5.0, tasting = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 9, aftertaste = 5)),
            record("r3", rating = 2.0, tasting = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 2, aftertaste = 5)),
            record("r4", rating = 2.0, tasting = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 2, aftertaste = 5)),
            record("r5", rating = 3.5, tasting = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 5, aftertaste = 5)),
        )

        val stats = useCase(records)

        // sweetness の分散は 0 のためスキップされ、flavor が採用されるはず
        assertNotNull(stats.favoriteSignals.dominantTastingAxis)
        // sweetness ではないことだけ確認（flavor or aftertaste が選ばれる）
        val axis = stats.favoriteSignals.dominantTastingAxis!!.axis
        assertTrue(axis != TastingAxis.Sweetness, "分散0の sweetness は選ばれてはいけない")
    }

    @Test
    fun favoriteSignals_dominantTastingAxis_unratedRecords_excludedFromSample() {
        // rating = 0.0（未評価）は母数から除外 → sampleSize に反映される
        val t = TastingScores(8, 5, 7, 9, 8)
        val records = listOf(
            record("r1", rating = 5.0, tasting = t),
            record("r2", rating = 5.0, tasting = t),
            record("r3", rating = 3.0, tasting = TastingScores(3, 5, 3, 3, 3)),
            record("r4", rating = 3.0, tasting = TastingScores(3, 5, 3, 3, 3)),
            record("r5", rating = 3.0, tasting = TastingScores(3, 5, 3, 3, 3)),
            record("r6", rating = 0.0, tasting = t), // 未評価: 除外
        )

        val stats = useCase(records)

        // sampleSize は 5（未評価 0.0 は除外）
        val axis = stats.favoriteSignals.dominantTastingAxis
        if (axis != null) {
            assertEquals(5, axis.sampleSize)
        }
    }

    // --- 複合ケース ---

    @Test
    fun mixedRecords_totalCountIncludesAllRecords() {
        val records = listOf(
            record("r1", rating = 0.0),  // 未評価
            record("r2", rating = 4.0),
            record("r3", rating = 0.0),  // 未評価
        )

        val stats = useCase(records)

        // totalCount は全件（未評価含む）
        assertEquals(3, stats.totalCount)
        // ratedCount は評価済みのみ
        assertEquals(1, stats.ratedCount)
    }

    // --- tastingAverages ---

    @Test
    fun tastingAverages_noTastingRecords_returnsNullAveragesAndZeroCount() {
        // tasting = null のレコードのみ（all-or-nothing: tasting なし）
        val records = listOf(
            record("r1", tasting = null),
            record("r2", tasting = null),
        )

        val stats = useCase(records)

        assertNull(stats.tastingAverages.sweetness, "tasting なし → null")
        assertNull(stats.tastingAverages.body)
        assertNull(stats.tastingAverages.acidity)
        assertNull(stats.tastingAverages.flavor)
        assertNull(stats.tastingAverages.aftertaste)
        assertEquals(0, stats.tastingAverages.ratedCount)
    }

    @Test
    fun tastingAverages_mixedTastingAndNull_onlyTastingRecordsAreIncluded() {
        // tasting あり 2 件、tasting なし 1 件が混在する
        val records = listOf(
            record("r1", tasting = TastingScores(sweetness = 8, body = 6, acidity = 7, flavor = 9, aftertaste = 5)),
            record("r2", tasting = TastingScores(sweetness = 4, body = 8, acidity = 5, flavor = 7, aftertaste = 9)),
            record("r3", tasting = null),  // 母数から除外
        )

        val stats = useCase(records)

        // tasting あり 2 件のみが母数
        assertEquals(2, stats.tastingAverages.ratedCount)
        assertEquals(6.0, stats.tastingAverages.sweetness)   // (8+4)/2
        assertEquals(7.0, stats.tastingAverages.body)         // (6+8)/2
        assertEquals(6.0, stats.tastingAverages.acidity)      // (7+5)/2
        assertEquals(8.0, stats.tastingAverages.flavor)       // (9+7)/2
        assertEquals(7.0, stats.tastingAverages.aftertaste)   // (5+9)/2
    }

    @Test
    fun tastingAverages_allTastingSet_returnsCorrectAveragesAndCount() {
        // 全レコードが tasting あり
        val records = listOf(
            record("r1", tasting = TastingScores(sweetness = 8, body = 6, acidity = 7, flavor = 9, aftertaste = 5)),
            record("r2", tasting = TastingScores(sweetness = 4, body = 8, acidity = 5, flavor = 7, aftertaste = 9)),
        )

        val stats = useCase(records)

        assertEquals(2, stats.tastingAverages.ratedCount)
        assertEquals(6.0, stats.tastingAverages.sweetness)   // (8+4)/2
        assertEquals(7.0, stats.tastingAverages.body)         // (6+8)/2
        assertEquals(6.0, stats.tastingAverages.acidity)      // (7+5)/2
        assertEquals(8.0, stats.tastingAverages.flavor)       // (9+7)/2
        assertEquals(7.0, stats.tastingAverages.aftertaste)   // (5+9)/2
    }
}

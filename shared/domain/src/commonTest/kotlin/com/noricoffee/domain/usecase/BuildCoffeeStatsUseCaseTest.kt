package com.noricoffee.domain.usecase

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.TastingScores
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
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
        tasting: TastingScores = TastingScores(),
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
        // favoriteSignals は空（全 null）
        assertNull(stats.favoriteSignals.bestBrewMethod)
        assertNull(stats.favoriteSignals.bestOrigin)
        assertNull(stats.favoriteSignals.bestRoastLevel)
        assertEquals(3, stats.favoriteSignals.minSampleSize)
        // tastingAverages は全 null・ratedCount は全ゼロ
        assertNull(stats.tastingAverages.sweetness)
        assertNull(stats.tastingAverages.body)
        assertNull(stats.tastingAverages.acidity)
        assertNull(stats.tastingAverages.flavor)
        assertNull(stats.tastingAverages.aftertaste)
        assertEquals(0, stats.tastingAverages.ratedCount.sweetness)
        assertEquals(0, stats.tastingAverages.ratedCount.body)
        assertEquals(0, stats.tastingAverages.ratedCount.acidity)
        assertEquals(0, stats.tastingAverages.ratedCount.flavor)
        assertEquals(0, stats.tastingAverages.ratedCount.aftertaste)
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

    // --- favoriteSignals (Phase B-1 まで空) ---

    @Test
    fun favoriteSignals_allNullInPhaseA() {
        val records = listOf(
            record("r1", rating = 5.0, brewMethod = BrewMethod.HandDrip),
            record("r2", rating = 5.0, brewMethod = BrewMethod.HandDrip),
            record("r3", rating = 5.0, brewMethod = BrewMethod.HandDrip),
        )

        val stats = useCase(records)

        // Phase A では FavoriteSignals は全フィールド null
        assertNull(stats.favoriteSignals.bestBrewMethod)
        assertNull(stats.favoriteSignals.bestOrigin)
        assertNull(stats.favoriteSignals.bestRoastLevel)
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
    fun tastingAverages_allNull_returnsNullAveragesAndZeroCount() {
        // 全要素 null（未入力）のレコードのみ
        val records = listOf(
            record("r1", tasting = TastingScores()),
            record("r2", tasting = TastingScores()),
        )

        val stats = useCase(records)

        assertNull(stats.tastingAverages.sweetness, "設定なし → null")
        assertNull(stats.tastingAverages.body)
        assertNull(stats.tastingAverages.acidity)
        assertNull(stats.tastingAverages.flavor)
        assertNull(stats.tastingAverages.aftertaste)
        assertEquals(0, stats.tastingAverages.ratedCount.sweetness)
        assertEquals(0, stats.tastingAverages.ratedCount.body)
        assertEquals(0, stats.tastingAverages.ratedCount.acidity)
        assertEquals(0, stats.tastingAverages.ratedCount.flavor)
        assertEquals(0, stats.tastingAverages.ratedCount.aftertaste)
    }

    @Test
    fun tastingAverages_partialInput_averagesExcludeNullElements() {
        // sweetness / acidity のみ設定（body / flavor / aftertaste は null）
        val records = listOf(
            record("r1", tasting = TastingScores(sweetness = 6, acidity = 8)),
            record("r2", tasting = TastingScores(sweetness = 4, acidity = 6)),
            record("r3", tasting = TastingScores()),  // 全 null
        )

        val stats = useCase(records)

        // sweetness: (6+4)/2 = 5.0、設定済み 2 件
        assertEquals(5.0, stats.tastingAverages.sweetness)
        assertEquals(2, stats.tastingAverages.ratedCount.sweetness)
        // body: 設定なし → null、ratedCount=0
        assertNull(stats.tastingAverages.body)
        assertEquals(0, stats.tastingAverages.ratedCount.body)
        // acidity: (8+6)/2 = 7.0、設定済み 2 件
        assertEquals(7.0, stats.tastingAverages.acidity)
        assertEquals(2, stats.tastingAverages.ratedCount.acidity)
        // flavor / aftertaste: null
        assertNull(stats.tastingAverages.flavor)
        assertNull(stats.tastingAverages.aftertaste)
        assertEquals(0, stats.tastingAverages.ratedCount.flavor)
        assertEquals(0, stats.tastingAverages.ratedCount.aftertaste)
    }

    @Test
    fun tastingAverages_allElementsSet_returnsCorrectAveragesAndCounts() {
        // 全要素設定済み
        val records = listOf(
            record("r1", tasting = TastingScores(sweetness = 8, body = 6, acidity = 7, flavor = 9, aftertaste = 5)),
            record("r2", tasting = TastingScores(sweetness = 4, body = 8, acidity = 5, flavor = 7, aftertaste = 9)),
        )

        val stats = useCase(records)

        assertEquals(6.0, stats.tastingAverages.sweetness)   // (8+4)/2
        assertEquals(7.0, stats.tastingAverages.body)         // (6+8)/2
        assertEquals(6.0, stats.tastingAverages.acidity)      // (7+5)/2
        assertEquals(8.0, stats.tastingAverages.flavor)       // (9+7)/2
        assertEquals(7.0, stats.tastingAverages.aftertaste)   // (5+9)/2
        assertEquals(2, stats.tastingAverages.ratedCount.sweetness)
        assertEquals(2, stats.tastingAverages.ratedCount.body)
        assertEquals(2, stats.tastingAverages.ratedCount.acidity)
        assertEquals(2, stats.tastingAverages.ratedCount.flavor)
        assertEquals(2, stats.tastingAverages.ratedCount.aftertaste)
    }
}

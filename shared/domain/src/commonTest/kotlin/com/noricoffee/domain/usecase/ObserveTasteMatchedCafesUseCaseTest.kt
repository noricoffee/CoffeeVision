package com.noricoffee.domain.usecase

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.model.PreferenceMatchAxis
import com.noricoffee.domain.model.RecommendationReason
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * [ObserveTasteMatchedCafesUseCase] の集計ロジックを検証する。
 *
 * テスト前提: FavoriteSignals を確実に出すため、
 * BuildCoffeeStatsUseCase の信号化条件（収縮 + n連動 z ゲート + δ AND）を
 * 十分に満たすデータセットを用意する。
 *
 * ## テスト戦略
 * - FavoriteSignals が確定的に出る小さなデータを手組み
 * - BuildCoffeeStatsUseCase 本体の集計は BuildCoffeeStatsUseCaseTest で別途テスト済みのため、
 *   ここでは「UseCase が正しく FavoriteSignals を使ってカフェをフィルタ・ランク付けするか」に集中
 */
class ObserveTasteMatchedCafesUseCaseTest {

    // --- Fake ---

    private class FakeCoffeeRepository(
        records: List<CoffeeRecord> = emptyList(),
    ) : CoffeeRepository {
        private val flow = MutableStateFlow(records)

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flow
        override fun observeById(id: String): Flow<CoffeeRecord?> = MutableStateFlow(null)
        override fun observeByCafe(
            userId: String,
            placeId: String,
        ): Flow<List<CoffeeRecord>> = MutableStateFlow(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    // --- ヘルパ ---

    private fun cafe(placeId: String, name: String = "カフェ $placeId") = Cafe(
        placeId = placeId,
        name = name,
        address = null,
        latitude = 35.0,
        longitude = 139.0,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )

    private fun record(
        id: String,
        placeId: String?,
        visitedOn: LocalDate,
        rating: Double = 3.0,
        origin: String? = null,
        roastLevel: RoastLevel? = null,
        brewMethod: BrewMethod = BrewMethod.HandDrip,
        coffeeName: String = "Coffee $id",
    ) = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = placeId?.let { cafe(it) },
        visitedOn = visitedOn,
        rating = rating,
        notes = "",
        photos = emptyList(),
        name = coffeeName,
        brewMethod = brewMethod,
        origin = origin,
        variety = null,
        processing = null,
        roastLevel = roastLevel,
        cup = null,
        tasting = null,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    private fun makeUseCase(records: List<CoffeeRecord>): ObserveTasteMatchedCafesUseCase =
        ObserveTasteMatchedCafesUseCase(
            coffeeRepository = FakeCoffeeRepository(records),
            buildCoffeeStatsUseCase = BuildCoffeeStatsUseCase(),
        )

    /**
     * FavoriteSignals の bestOrigin に "ethiopia" が確実に出るようなレコード群を生成する。
     *
     * globalMean = (4.5 * 4 + 4.5 * 3 + 4.0 * 2 + 1.0 * 3) / 12 = (18 + 13.5 + 8 + 3) / 12 = 42.5 / 12 ≈ 3.54
     * Ethiopia 群: 4 件、平均 4.5。shrunkMean = (4*4.5 + 5*3.54)/(4+5) = (18+17.7)/9 ≈ 3.97
     * shrunkMean - globalMean ≈ 0.43 > CATEGORY_MIN_EFFECT(0.20) OK
     * mean - globalMean = 4.5 - 3.54 = 0.96
     * std ≈ sqrt((4*(4.5-3.54)^2 + 3*(4.5-3.54)^2 + 2*(4.0-3.54)^2 + 3*(1.0-3.54)^2)/12)
     * = sqrt((4*0.92+3*0.92+2*0.21+3*6.45)/12) = sqrt((3.68+2.76+0.42+19.35)/12) = sqrt(26.21/12) ≈ 1.48
     * z閾値 = 2.0 * 1.48 / sqrt(4) = 2.0 * 1.48 / 2 = 1.48
     * mean - globalMean = 0.96 < 1.48 → z ゲート不通過
     *
     * 確実に信号が出るように: Ethiopia 群を増やし、全体の globalMean を下げる構成にする。
     * 簡略化: n=6, mean=4.5; globalMean=3.0(n=12); std=1.0 と近似できる構成
     */

    /**
     * origin 信号が確実に出る最小データセット。
     *
     * Ethiopia(n=6, mean=4.5), Kenya(n=6, mean=1.5) で構成。
     * globalMean = (6*4.5 + 6*1.5)/12 = (27+9)/12 = 3.0
     * globalStd = sqrt((6*(4.5-3.0)^2 + 6*(1.5-3.0)^2)/12)
     *           = sqrt((6*2.25 + 6*2.25)/12) = sqrt(27/12) = sqrt(2.25) = 1.5
     * Ethiopia: mean=4.5, n=6
     * shrunkMean = (6*4.5 + 5*3.0)/(6+5) = (27+15)/11 = 42/11 ≈ 3.82
     * shrunkMean - globalMean = 0.82 > 0.20 OK (δ)
     * zThreshold = 2.0 * 1.5 / sqrt(6) = 3.0 / 2.449 ≈ 1.22
     * mean - globalMean = 4.5 - 3.0 = 1.5 > 1.22 OK (z ゲート)
     * → Ethiopia が bestOrigin になる
     */
    private fun buildOriginSignalRecords(
        placeId: String,
        highRatingOrigin: String = "Ethiopia",
        count: Int = 6,
        highRating: Double = 4.5,
        lowRating: Double = 1.5,
    ): List<CoffeeRecord> {
        val highRated = (1..count).map { i ->
            record(
                id = "h$i",
                placeId = placeId,
                visitedOn = LocalDate(2026, 6, i),
                rating = highRating,
                origin = highRatingOrigin,
            )
        }
        val lowRated = (1..count).map { i ->
            record(
                id = "l$i",
                placeId = "other-place",
                visitedOn = LocalDate(2026, 1, i),
                rating = lowRating,
                origin = "Kenya",
            )
        }
        return highRated + lowRated
    }

    // ============================================================
    // 基本ケース: 各軸の検出
    // ============================================================

    @Test
    fun originAxis_detected_whenHighRatedRecordsMatchBestOrigin() = runTest {
        val records = buildOriginSignalRecords(placeId = "cafe-a")
        val useCase = makeUseCase(records)

        val result = useCase.observeRecommendedCafes("user-1").first()

        // cafe-a は Ethiopia 高評価記録があり、bestOrigin = Ethiopia なので推薦に含まれるはず
        val recommended = result.find { it.cafe.placeId == "cafe-a" }
        assertNotNull(recommended, "cafe-a should be recommended")
        val originMatch = recommended.matches
            .filterIsInstance<RecommendationReason.TasteProfileMatch>()
            .firstOrNull { it.axis == PreferenceMatchAxis.Origin }
        assertNotNull(originMatch, "Origin axis match should be present")
        assertEquals("Ethiopia", originMatch.matchedLabel)
    }

    @Test
    fun roastLevelAxis_detected_whenHighRatedRecordsMatchBestRoastLevel() = runTest {
        // Light(n=6, mean=4.5) vs City(n=6, mean=1.5) 構成
        val lightHighRated = (1..6).map { i ->
            record(
                id = "light$i",
                placeId = "cafe-roast",
                visitedOn = LocalDate(2026, 6, i),
                rating = 4.5,
                roastLevel = RoastLevel.Light,
            )
        }
        val cityLowRated = (1..6).map { i ->
            record(
                id = "city$i",
                placeId = "other",
                visitedOn = LocalDate(2026, 1, i),
                rating = 1.5,
                roastLevel = RoastLevel.City,
            )
        }
        val useCase = makeUseCase(lightHighRated + cityLowRated)

        val result = useCase.observeRecommendedCafes("user-1").first()

        val recommended = result.find { it.cafe.placeId == "cafe-roast" }
        assertNotNull(recommended, "cafe-roast should be recommended via roastLevel")
        val roastMatch = recommended.matches
            .filterIsInstance<RecommendationReason.TasteProfileMatch>()
            .firstOrNull { it.axis == PreferenceMatchAxis.RoastLevel }
        assertNotNull(roastMatch, "RoastLevel axis match should be present")
        assertEquals("Light", roastMatch.matchedLabel)
    }

    @Test
    fun brewMethodAxis_detected_whenHighRatedRecordsMatchBestBrewMethod() = runTest {
        // AeroPress(n=6, mean=4.5) vs Espresso(n=6, mean=1.5) 構成
        val aeroPressHighRated = (1..6).map { i ->
            record(
                id = "aero$i",
                placeId = "cafe-brew",
                visitedOn = LocalDate(2026, 6, i),
                rating = 4.5,
                brewMethod = BrewMethod.AeroPress,
            )
        }
        val espressoLowRated = (1..6).map { i ->
            record(
                id = "esp$i",
                placeId = "other",
                visitedOn = LocalDate(2026, 1, i),
                rating = 1.5,
                brewMethod = BrewMethod.Espresso,
            )
        }
        val useCase = makeUseCase(aeroPressHighRated + espressoLowRated)

        val result = useCase.observeRecommendedCafes("user-1").first()

        val recommended = result.find { it.cafe.placeId == "cafe-brew" }
        assertNotNull(recommended, "cafe-brew should be recommended via brewMethod")
        val brewMatch = recommended.matches
            .filterIsInstance<RecommendationReason.TasteProfileMatch>()
            .firstOrNull { it.axis == PreferenceMatchAxis.BrewMethod }
        assertNotNull(brewMatch, "BrewMethod axis match should be present")
        assertEquals("AeroPress", brewMatch.matchedLabel)
    }

    // ============================================================
    // 除外ケース
    // ============================================================

    @Test
    fun ratingBelowThreshold_excluded() = runTest {
        // Ethiopia で rating=3.5（RECOMMEND_MIN_RATING=4.0 未満）の記録はマッチ対象外
        val highRatedBase = buildOriginSignalRecords(placeId = "cafe-good")
        // cafe-bad には Ethiopia だが rating=3.9 の記録しかない
        val lowRatedEthiopia = record(
            id = "sub-threshold",
            placeId = "cafe-bad",
            visitedOn = LocalDate(2026, 6, 1),
            rating = 3.9, // 4.0 未満
            origin = "Ethiopia",
        )
        val useCase = makeUseCase(highRatedBase + listOf(lowRatedEthiopia))

        val result = useCase.observeRecommendedCafes("user-1").first()

        val badCafe = result.find { it.cafe.placeId == "cafe-bad" }
        assertTrue(badCafe == null, "cafe-bad should NOT be recommended (rating < threshold)")
    }

    @Test
    fun allFavoriteSignalsNull_returnsEmptyList() = runTest {
        // データが少なすぎて FavoriteSignals が全 null になる（2 件のみ）
        val records = listOf(
            record("r1", "cafe-a", LocalDate(2026, 6, 1), rating = 4.5, origin = "Ethiopia"),
            record("r2", "cafe-b", LocalDate(2026, 6, 2), rating = 2.0, origin = "Kenya"),
        )
        val useCase = makeUseCase(records)

        val result = useCase.observeRecommendedCafes("user-1").first()

        // サンプルが少なく信号化条件を満たさない → FavoriteSignals 全 null → 空リスト
        // (2件は minSampleSize=3 未満のため bestOrigin=null)
        assertTrue(result.isEmpty(), "Should return empty when FavoriteSignals are all null")
    }

    @Test
    fun selfExtractedRecords_excluded() = runTest {
        val cafeRecords = buildOriginSignalRecords(placeId = "cafe-a")
        // セルフ抽出（cafe=null）の Ethiopia 高評価は対象外
        val selfExtracted = record(
            id = "self-1",
            placeId = null, // cafe = null
            visitedOn = LocalDate(2026, 6, 10),
            rating = 4.5,
            origin = "Ethiopia",
        )
        val useCase = makeUseCase(cafeRecords + listOf(selfExtracted))

        val result = useCase.observeRecommendedCafes("user-1").first()

        // セルフ抽出は placeId が無いため推薦対象外
        val selfInResult = result.find { it.cafe.placeId == "self" }
        assertTrue(selfInResult == null, "Self-extracted records should not be in result")
    }

    // ============================================================
    // 正規化
    // ============================================================

    @Test
    fun originNormalization_matchesCaseInsensitive() = runTest {
        // bestOrigin.label = "Ethiopia"、レコードの origin = "ethiopia"（小文字）でも一致する
        val highRatedNormalized = (1..6).map { i ->
            record(
                id = "norm$i",
                placeId = "cafe-norm",
                visitedOn = LocalDate(2026, 6, i),
                rating = 4.5,
                origin = "ethiopia", // 小文字
            )
        }
        val lowRated = (1..6).map { i ->
            record(
                id = "low$i",
                placeId = "other",
                visitedOn = LocalDate(2026, 1, i),
                rating = 1.5,
                origin = "Kenya",
            )
        }
        val useCase = makeUseCase(highRatedNormalized + lowRated)

        val result = useCase.observeRecommendedCafes("user-1").first()

        // bestOrigin は "ethiopia" グループの表示ラベル（最初の出現の trim のみ）= "ethiopia"
        // cafe-norm にも "ethiopia" の高評価記録があり、正規化で一致するはず
        val recommended = result.find { it.cafe.placeId == "cafe-norm" }
        assertNotNull(recommended, "Should match despite case difference in origin")
    }

    @Test
    fun originNormalization_trimMatchesSurroundingSpaces() = runTest {
        // bestOrigin.label = "Ethiopia"、レコードの origin = " Ethiopia " でも一致する
        val highRatedSpaced = (1..6).map { i ->
            record(
                id = "spaced$i",
                placeId = "cafe-spaced",
                visitedOn = LocalDate(2026, 6, i),
                rating = 4.5,
                origin = " Ethiopia ", // 前後スペース
            )
        }
        val lowRated = (1..6).map { i ->
            record(
                id = "low$i",
                placeId = "other",
                visitedOn = LocalDate(2026, 1, i),
                rating = 1.5,
                origin = "Kenya",
            )
        }
        val useCase = makeUseCase(highRatedSpaced + lowRated)

        val result = useCase.observeRecommendedCafes("user-1").first()

        val recommended = result.find { it.cafe.placeId == "cafe-spaced" }
        assertNotNull(recommended, "Should match despite surrounding spaces in origin")
    }

    // ============================================================
    // 複数軸一致と代表記録の選定
    // ============================================================

    @Test
    fun multipleAxesMatch_allIncludedInMatches() = runTest {
        // Ethiopia(origin) + Light(roastLevel) の両方が好み信号として出て、
        // 同じカフェに両方の高評価記録がある場合 → matches が 2 件
        val ethiopiaLight = (1..6).map { i ->
            record(
                id = "el$i",
                placeId = "cafe-multi",
                visitedOn = LocalDate(2026, 6, i),
                rating = 4.5,
                origin = "Ethiopia",
                roastLevel = RoastLevel.Light,
            )
        }
        // 信号化用の対称低評価群
        val kenyaCity = (1..6).map { i ->
            record(
                id = "kc$i",
                placeId = "other",
                visitedOn = LocalDate(2026, 1, i),
                rating = 1.5,
                origin = "Kenya",
                roastLevel = RoastLevel.City,
            )
        }
        val useCase = makeUseCase(ethiopiaLight + kenyaCity)

        val result = useCase.observeRecommendedCafes("user-1").first()

        val recommended = result.find { it.cafe.placeId == "cafe-multi" }
        assertNotNull(recommended)
        val matchAxes = recommended.matches
            .filterIsInstance<RecommendationReason.TasteProfileMatch>()
            .map { it.axis }
        assertTrue(
            PreferenceMatchAxis.Origin in matchAxes,
            "Origin axis should be in matches",
        )
        assertTrue(
            PreferenceMatchAxis.RoastLevel in matchAxes,
            "RoastLevel axis should be in matches",
        )
    }

    @Test
    fun sameAxisMultipleRecords_highestRatingIsRepresentative() = runTest {
        // 同じ軸に複数の一致記録がある場合、評価最高のものが代表
        val cafeRecords = buildOriginSignalRecords(placeId = "cafe-rep")

        // cafe-rep に Ethiopia で rating=4.5 と rating=5.0 の 2 件（両方しきい値以上）追加
        val extra = listOf(
            record(
                id = "extra-low",
                placeId = "cafe-rep",
                visitedOn = LocalDate(2025, 12, 1),
                rating = 4.5,
                origin = "Ethiopia",
                coffeeName = "Coffee Low",
            ),
            record(
                id = "extra-high",
                placeId = "cafe-rep",
                visitedOn = LocalDate(2025, 11, 1),
                rating = 5.0,
                origin = "Ethiopia",
                coffeeName = "Coffee High",
            ),
        )
        val useCase = makeUseCase(
            buildOriginSignalRecords(placeId = "cafe-rep").take(6) +
                extra +
                buildOriginSignalRecords(placeId = "dummy-other"),
        )

        val result = useCase.observeRecommendedCafes("user-1").first()
        val recommended = result.find { it.cafe.placeId == "cafe-rep" }
        assertNotNull(recommended)
        val originMatch = recommended.matches
            .filterIsInstance<RecommendationReason.TasteProfileMatch>()
            .firstOrNull { it.axis == PreferenceMatchAxis.Origin }
        assertNotNull(originMatch)
        // 評価最高 = 5.0 の記録が代表
        assertEquals(5.0, originMatch.exampleRating)
        assertEquals("Coffee High", originMatch.exampleRecordName)
    }

    @Test
    fun tieBreak_newerVisitedOnAndThenNameAscending() = runTest {
        // タイ（同点 rating）→ visitedOn 新しい順 → name 昇順
        val base = buildOriginSignalRecords(placeId = "cafe-tie")
        val tieRecords = listOf(
            record(
                id = "tie-a",
                placeId = "cafe-tie",
                visitedOn = LocalDate(2026, 6, 10), // 新しい
                rating = 4.5,
                origin = "Ethiopia",
                coffeeName = "BBB Coffee", // B > A
            ),
            record(
                id = "tie-b",
                placeId = "cafe-tie",
                visitedOn = LocalDate(2026, 6, 10), // 同日
                rating = 4.5,
                origin = "Ethiopia",
                coffeeName = "AAA Coffee", // A < B → name 昇順で先
            ),
        )
        val useCase = makeUseCase(base + tieRecords)

        val result = useCase.observeRecommendedCafes("user-1").first()
        val recommended = result.find { it.cafe.placeId == "cafe-tie" }
        assertNotNull(recommended)
        val originMatch = recommended.matches
            .filterIsInstance<RecommendationReason.TasteProfileMatch>()
            .firstOrNull { it.axis == PreferenceMatchAxis.Origin }
        assertNotNull(originMatch)
        // 同日タイ → name 昇順 → "AAA Coffee" が代表
        assertEquals("AAA Coffee", originMatch.exampleRecordName)
    }

    // ============================================================
    // 並び順
    // ============================================================

    @Test
    fun sortOrder_moreMatchesFirst() = runTest {
        // cafe-multi: matches=2（origin + roastLevel）
        // cafe-single: matches=1（origin のみ）
        // cafe-multi が先に来るはず
        val ethiopiaLight = (1..6).map { i ->
            record(
                id = "multi$i",
                placeId = "cafe-multi",
                visitedOn = LocalDate(2026, 6, i),
                rating = 4.5,
                origin = "Ethiopia",
                roastLevel = RoastLevel.Light,
            )
        }
        val kenyaCity = (1..6).map { i ->
            record(
                id = "counter$i",
                placeId = "other",
                visitedOn = LocalDate(2026, 1, i),
                rating = 1.5,
                origin = "Kenya",
                roastLevel = RoastLevel.City,
            )
        }
        // cafe-single は Ethiopia 高評価のみ（roastLevel 記録なし）
        val singleCafe = (1..6).map { i ->
            record(
                id = "single$i",
                placeId = "cafe-single",
                visitedOn = LocalDate(2026, 3, i),
                rating = 4.5,
                origin = "Ethiopia",
                roastLevel = null, // roastLevel 未設定
            )
        }
        val useCase = makeUseCase(ethiopiaLight + kenyaCity + singleCafe)

        val result = useCase.observeRecommendedCafes("user-1").first()

        assertTrue(result.isNotEmpty())
        // matches=2 の cafe-multi が先頭になる
        assertEquals("cafe-multi", result.first().cafe.placeId)
    }

    @Test
    fun sortOrder_placeIdAscendingAsTieBreaker() = runTest {
        // matches=1（origin のみ）で代表評価も同じ → placeId 昇順
        val cafeBRecords = (1..6).map { i ->
            record(
                id = "b$i",
                placeId = "zzz-cafe", // 後ろ
                visitedOn = LocalDate(2026, 6, i),
                rating = 4.5,
                origin = "Ethiopia",
            )
        }
        val cafeARecords = (1..6).map { i ->
            record(
                id = "a$i",
                placeId = "aaa-cafe", // 前
                visitedOn = LocalDate(2026, 5, i),
                rating = 4.5,
                origin = "Ethiopia",
            )
        }
        val lowRated = (1..6).map { i ->
            record(
                id = "low$i",
                placeId = "other",
                visitedOn = LocalDate(2026, 1, i),
                rating = 1.5,
                origin = "Kenya",
            )
        }
        val useCase = makeUseCase(cafeBRecords + cafeARecords + lowRated)

        val result = useCase.observeRecommendedCafes("user-1").first()

        assertTrue(result.size >= 2)
        // placeId 昇順: "aaa-cafe" < "zzz-cafe"
        assertEquals("aaa-cafe", result[0].cafe.placeId)
        assertEquals("zzz-cafe", result[1].cafe.placeId)
    }

    // ============================================================
    // 代表記録の内容が正しいことの確認
    // ============================================================

    @Test
    fun exampleRecordNameAndRating_areCorrect() = runTest {
        val base = buildOriginSignalRecords(placeId = "cafe-check")
        val specificRecord = record(
            id = "specific",
            placeId = "cafe-check",
            visitedOn = LocalDate(2026, 6, 20),
            rating = 5.0,
            origin = "Ethiopia",
            coffeeName = "Special Ethiopia",
        )
        val useCase = makeUseCase(base + listOf(specificRecord))

        val result = useCase.observeRecommendedCafes("user-1").first()
        val recommended = result.find { it.cafe.placeId == "cafe-check" }
        assertNotNull(recommended)
        val originMatch = recommended.matches
            .filterIsInstance<RecommendationReason.TasteProfileMatch>()
            .firstOrNull { it.axis == PreferenceMatchAxis.Origin }
        assertNotNull(originMatch)
        assertEquals("Special Ethiopia", originMatch.exampleRecordName)
        assertEquals(5.0, originMatch.exampleRating)
    }

    // ============================================================
    // エッジケース
    // ============================================================

    @Test
    fun emptyRecords_returnsEmptyList() = runTest {
        val useCase = makeUseCase(emptyList())

        val result = useCase.observeRecommendedCafes("user-1").first()

        assertTrue(result.isEmpty())
    }

    @Test
    fun cafesWithNoHighRatingMatch_notIncluded() = runTest {
        // cafe-a には Ethiopia だが rating=3.5 の記録しかない（しきい値未満）
        val base = buildOriginSignalRecords(placeId = "cafe-good")
        val noMatchCafe = record(
            id = "nomatch",
            placeId = "cafe-no-match",
            visitedOn = LocalDate(2026, 6, 1),
            rating = 3.5, // < RECOMMEND_MIN_RATING
            origin = "Ethiopia",
        )
        val useCase = makeUseCase(base + listOf(noMatchCafe))

        val result = useCase.observeRecommendedCafes("user-1").first()

        assertTrue(result.none { it.cafe.placeId == "cafe-no-match" })
    }
}

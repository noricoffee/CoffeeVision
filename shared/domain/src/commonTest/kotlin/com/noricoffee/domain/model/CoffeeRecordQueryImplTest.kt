package com.noricoffee.domain.model

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.RoastLevel
import com.noricoffee.domain.model.AuthAccount
import com.noricoffee.repository.AuthRepository
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [CoffeeRecordQueryImpl] のユニットテスト。
 *
 * [CoffeeRepository] と [AuthRepository] は Fake で差し替え、
 * フィルタロジック・ソート・limit 等をインメモリで検証する。
 */
class CoffeeRecordQueryImplTest {

    // ----- Fake 実装 -----

    private class FakeCoffeeRepository(
        private val records: List<CoffeeRecord> = emptyList(),
    ) : CoffeeRepository {

        private val flow = MutableStateFlow(records)

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flow
        override fun observeById(id: String): Flow<CoffeeRecord?> =
            MutableStateFlow(records.firstOrNull { it.id == id })
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
            MutableStateFlow(records.filter { it.cafe?.placeId == placeId })
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    private class FakeAuthRepository : AuthRepository {
        override suspend fun signInAnonymouslyIfNeeded(): String = "user-fake"
        override fun observeUserId(): Flow<String?> = MutableStateFlow("user-fake")
        override fun observeAccount(): Flow<AuthAccount?> = MutableStateFlow(null)
        override suspend fun linkWithApple(idToken: String, rawNonce: String): AuthAccount =
            throw UnsupportedOperationException()
        override suspend fun signOut() = Unit
        override suspend fun deleteAuthUser() = Unit
        override suspend fun updateAnalyticsConsent(consent: Boolean) = Unit
        override fun observeAnalyticsConsent(): Flow<Boolean> = MutableStateFlow(false)
    }

    // ----- テスト用ヘルパ -----

    private fun cafe(
        placeId: String = "place-1",
        name: String = "Blue Bottle",
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
        name: String = "Test Coffee",
        visitedOn: LocalDate = LocalDate(2026, 6, 1),
        rating: Double = 3.0,
        origin: String? = null,
        brewMethod: BrewMethod = BrewMethod.HandDrip,
        roastLevel: RoastLevel? = null,
        cafe: Cafe? = null,
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
        processing = null,
        roastLevel = roastLevel,
        cup = null,
        tasting = null,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    private fun makeQuery(records: List<CoffeeRecord>): CoffeeRecordQueryImpl =
        CoffeeRecordQueryImpl(
            coffeeRepository = FakeCoffeeRepository(records),
            authRepository = FakeAuthRepository(),
        )

    // ----- テスト: 基本 -----

    @Test
    fun emptyRecords_returnsEmptyList() = runTest {
        val query = makeQuery(emptyList())
        val result = query.searchRecords(CoffeeRecordFilter())
        assertTrue(result.isEmpty())
    }

    @Test
    fun noFilter_returnsAllRecordsUpToLimit() = runTest {
        val records = (1..15).map { record("r$it") }
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(limit = 10))
        assertEquals(10, result.size)
    }

    @Test
    fun noFilter_allRecordsUnderLimit_returnsAll() = runTest {
        val records = (1..5).map { record("r$it") }
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter())
        assertEquals(5, result.size)
    }

    // ----- テスト: ソート -----

    @Test
    fun sortedByVisitedOnDescending() = runTest {
        val records = listOf(
            record("r1", visitedOn = LocalDate(2026, 3, 1)),
            record("r2", visitedOn = LocalDate(2026, 6, 1)),
            record("r3", visitedOn = LocalDate(2026, 1, 15)),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter())
        assertEquals("2026-06-01", result[0].visitedOn)
        assertEquals("2026-03-01", result[1].visitedOn)
        assertEquals("2026-01-15", result[2].visitedOn)
    }

    // ----- テスト: origin フィルタ -----

    @Test
    fun originFilter_exactMatch() = runTest {
        val records = listOf(
            record("r1", origin = "エチオピア"),
            record("r2", origin = "ケニア"),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(origin = "エチオピア"))
        assertEquals(1, result.size)
        assertEquals("エチオピア", result[0].origin)
    }

    @Test
    fun originFilter_partialMatch() = runTest {
        val records = listOf(
            record("r1", origin = "エチオピア イルガチェフェ"),
            record("r2", origin = "ケニア AA"),
            record("r3", origin = null),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(origin = "エチオピア"))
        assertEquals(1, result.size)
    }

    @Test
    fun originFilter_caseInsensitiveForAscii() = runTest {
        val records = listOf(
            record("r1", origin = "Ethiopia"),
            record("r2", origin = "Kenya"),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(origin = "ethiopia"))
        assertEquals(1, result.size)
        assertEquals("Ethiopia", result[0].origin)
    }

    @Test
    fun originFilter_nullOriginExcluded() = runTest {
        val records = listOf(
            record("r1", origin = null),
            record("r2", origin = "ケニア"),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(origin = "ケニア"))
        assertEquals(1, result.size)
    }

    // ----- テスト: cafeName フィルタ -----

    @Test
    fun cafeNameFilter_partialMatchIgnoreCase() = runTest {
        val records = listOf(
            record("r1", cafe = cafe("p1", "Blue Bottle 三軒茶屋")),
            record("r2", cafe = cafe("p2", "Starbucks Reserve")),
            record("r3", cafe = null), // セルフ抽出
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(cafeName = "blue bottle"))
        assertEquals(1, result.size)
        assertEquals("Blue Bottle 三軒茶屋", result[0].cafeName)
    }

    @Test
    fun cafeNameFilter_nullCafeRecordExcluded() = runTest {
        val records = listOf(
            record("r1", cafe = null),
            record("r2", cafe = cafe("p1", "Blue Bottle")),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(cafeName = "Blue"))
        assertEquals(1, result.size)
    }

    // ----- テスト: brewMethod フィルタ（寛容マッチ）-----

    @Test
    fun brewMethodFilter_exactEnumNameMatch() = runTest {
        val records = listOf(
            record("r1", brewMethod = BrewMethod.HandDrip),
            record("r2", brewMethod = BrewMethod.Espresso),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(brewMethod = "HandDrip"))
        assertEquals(1, result.size)
        assertEquals("HandDrip", result[0].brewMethod)
    }

    @Test
    fun brewMethodFilter_partialMatch_drip_matchesHandDrip() = runTest {
        val records = listOf(
            record("r1", brewMethod = BrewMethod.HandDrip),
            record("r2", brewMethod = BrewMethod.NelDrip),
            record("r3", brewMethod = BrewMethod.Espresso),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(brewMethod = "drip"))
        assertEquals(2, result.size)
        assertTrue(result.all { it.brewMethod.contains("Drip", ignoreCase = true) })
    }

    @Test
    fun brewMethodFilter_caseInsensitive() = runTest {
        val records = listOf(
            record("r1", brewMethod = BrewMethod.AeroPress),
            record("r2", brewMethod = BrewMethod.HandDrip),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(brewMethod = "aeropress"))
        assertEquals(1, result.size)
        assertEquals("AeroPress", result[0].brewMethod)
    }

    // ----- テスト: roastLevel フィルタ（寛容マッチ）-----

    @Test
    fun roastLevelFilter_partialMatch() = runTest {
        val records = listOf(
            record("r1", roastLevel = RoastLevel.FullCity),
            record("r2", roastLevel = RoastLevel.City),
            record("r3", roastLevel = RoastLevel.Light),
            record("r4", roastLevel = null),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(roastLevel = "city"))
        // "FullCity" と "City" がマッチ
        assertEquals(2, result.size)
        assertTrue(result.all { it.roastLevel?.contains("City", ignoreCase = true) == true })
    }

    @Test
    fun roastLevelFilter_nullRoastLevelExcluded() = runTest {
        val records = listOf(
            record("r1", roastLevel = null),
            record("r2", roastLevel = RoastLevel.Medium),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(roastLevel = "Medium"))
        assertEquals(1, result.size)
        assertEquals("Medium", result[0].roastLevel)
    }

    // ----- テスト: 評価範囲フィルタ -----

    @Test
    fun ratingFilter_minRating() = runTest {
        val records = listOf(
            record("r1", rating = 4.5),
            record("r2", rating = 3.0),
            record("r3", rating = 2.0),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(minRating = 4.0))
        assertEquals(1, result.size)
        assertEquals(4.5, result[0].rating)
    }

    @Test
    fun ratingFilter_maxRating() = runTest {
        val records = listOf(
            record("r1", rating = 2.0),
            record("r2", rating = 3.0),
            record("r3", rating = 4.5),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(maxRating = 3.0))
        assertEquals(2, result.size)
    }

    @Test
    fun ratingFilter_range() = runTest {
        val records = listOf(
            record("r1", rating = 1.0),
            record("r2", rating = 3.0),
            record("r3", rating = 4.0),
            record("r4", rating = 5.0),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(minRating = 3.0, maxRating = 4.0))
        assertEquals(2, result.size)
        assertTrue(result.all { it.rating in 3.0..4.0 })
    }

    @Test
    fun ratingFilter_excludesZeroRatingSentinel() = runTest {
        // rating=0.0（未評価 sentinel）は評価範囲フィルタが指定された場合に除外される
        val records = listOf(
            record("r1", rating = 0.0), // 未評価
            record("r2", rating = 3.0),
            record("r3", rating = 4.0),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(minRating = 1.0))
        assertEquals(2, result.size)
        assertTrue(result.none { it.rating == 0.0 })
    }

    @Test
    fun ratingFilter_zeroRatingIncludedWhenNoRatingFilter() = runTest {
        // 評価範囲フィルタが未指定のときは rating=0.0（未評価）のレコードも含まれる
        val records = listOf(
            record("r1", rating = 0.0),
            record("r2", rating = 3.0),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter())
        assertEquals(2, result.size)
    }

    @Test
    fun ratingFilter_onlyMinRating_zeroRatingExcluded() = runTest {
        // minRating のみ指定しても rating=0.0 は除外される
        val records = listOf(
            record("r1", rating = 0.0),
            record("r2", rating = 2.0),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(minRating = 1.0))
        assertEquals(1, result.size)
        assertEquals(2.0, result[0].rating)
    }

    // ----- テスト: 期間フィルタ -----

    @Test
    fun fromYearMonthFilter_includesBoundary() = runTest {
        val records = listOf(
            record("r1", visitedOn = LocalDate(2026, 3, 15)),
            record("r2", visitedOn = LocalDate(2026, 4, 1)),
            record("r3", visitedOn = LocalDate(2026, 6, 10)),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(fromYearMonth = "2026-04"))
        assertEquals(2, result.size)
        assertTrue(result.all { it.visitedOn >= "2026-04-01" })
    }

    @Test
    fun toYearMonthFilter_includesBoundary() = runTest {
        val records = listOf(
            record("r1", visitedOn = LocalDate(2026, 3, 15)),
            record("r2", visitedOn = LocalDate(2026, 4, 30)),
            record("r3", visitedOn = LocalDate(2026, 5, 1)),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(toYearMonth = "2026-04"))
        assertEquals(2, result.size)
    }

    @Test
    fun yearMonthFilter_bothBounds() = runTest {
        val records = listOf(
            record("r1", visitedOn = LocalDate(2026, 1, 10)),
            record("r2", visitedOn = LocalDate(2026, 3, 5)),
            record("r3", visitedOn = LocalDate(2026, 5, 20)),
            record("r4", visitedOn = LocalDate(2026, 7, 1)),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(
            CoffeeRecordFilter(fromYearMonth = "2026-03", toYearMonth = "2026-05")
        )
        assertEquals(2, result.size)
    }

    // ----- テスト: limit -----

    @Test
    fun limit_negativeTreatedAsDefault() = runTest {
        val records = (1..15).map { record("r$it") }
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(limit = -1))
        assertEquals(CoffeeRecordFilter.DEFAULT_LIMIT, result.size)
    }

    @Test
    fun limit_zeroTreatedAsDefault() = runTest {
        val records = (1..15).map { record("r$it") }
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(limit = 0))
        assertEquals(CoffeeRecordFilter.DEFAULT_LIMIT, result.size)
    }

    @Test
    fun limit_largerThanMaxClampedToMax() = runTest {
        val records = (1..150).map { record("r$it") }
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(limit = 200))
        assertEquals(CoffeeRecordFilter.MAX_LIMIT, result.size)
    }

    @Test
    fun limit_exactMaxAllowed() = runTest {
        val records = (1..150).map { record("r$it") }
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(limit = CoffeeRecordFilter.MAX_LIMIT))
        assertEquals(CoffeeRecordFilter.MAX_LIMIT, result.size)
    }

    // ----- テスト: テキスト横断マッチ（origin / cafeName のフィールド横断）-----

    @Test
    fun originFilter_cafeNameGiven_hitsRecord_fugulen_regression() = runTest {
        // 「フグレンで飲んだコーヒーは？」でモデルが cafeName ではなく origin に "フグレン" を入れた場合の回帰テスト
        val records = listOf(
            record("r1", cafe = cafe("p1", "フグレン東京"), origin = "エチオピア", name = "シングルオリジン"),
            record("r2", cafe = cafe("p2", "Blue Bottle"), origin = "ケニア", name = "本日のコーヒー"),
        )
        val query = makeQuery(records)

        // origin に "フグレン"（カフェ名）が入っても cafe名の union でヒットする
        val result = query.searchRecords(CoffeeRecordFilter(origin = "フグレン"))
        assertEquals(1, result.size)
        assertEquals("フグレン東京", result[0].cafeName)
    }

    @Test
    fun cafeNameFilter_originGiven_hitsRecord() = runTest {
        // cafeName に産地名を渡してもヒットする（逆方向の誤分類）
        val records = listOf(
            record("r1", cafe = cafe("p1", "Blue Bottle"), origin = "エチオピア", name = "シングルオリジン"),
            record("r2", cafe = null, origin = "ケニア", name = "ハンドドリップ"),
        )
        val query = makeQuery(records)

        // cafeName に "エチオピア"（産地名）が入っても origin の union でヒットする
        val result = query.searchRecords(CoffeeRecordFilter(cafeName = "エチオピア"))
        assertEquals(1, result.size)
        assertEquals("エチオピア", result[0].origin)
    }

    @Test
    fun originFilter_coffeeName_hitsRecord() = runTest {
        // origin にコーヒー名が入った場合も record.name の union でヒットする
        val records = listOf(
            record("r1", cafe = null, origin = "ブラジル", name = "ゲイシャ"),
            record("r2", cafe = null, origin = "コロンビア", name = "ティピカ"),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(origin = "ゲイシャ"))
        assertEquals(1, result.size)
        assertEquals("ゲイシャ", result[0].name)
    }

    @Test
    fun originFilter_variety_hitsRecord() = runTest {
        // origin に品種名が入った場合も record.variety の union でヒットする
        val records = listOf(
            record("r1", cafe = null, origin = "エチオピア", name = "コーヒーA"),
            record("r2", cafe = null, origin = "ケニア", name = "コーヒーB"),
        )
        // variety を持つレコードを手動構築
        val recordWithVariety = CoffeeRecord(
            id = "r3",
            userId = "user-1",
            cafe = cafe("p1", "テストカフェ"),
            visitedOn = LocalDate(2026, 6, 1),
            rating = 4.0,
            notes = "",
            photos = emptyList(),
            name = "ゲイシャ エステート",
            brewMethod = BrewMethod.HandDrip,
            origin = "パナマ",
            variety = "Geisha",
            processing = null,
            roastLevel = null,
            cup = null,
            tasting = null,
            createdAt = Instant.fromEpochMilliseconds(0),
            updatedAt = Instant.fromEpochMilliseconds(0),
        )
        val query = makeQuery(records + recordWithVariety)

        // origin に "Geisha"（品種名）が入っても variety の union でヒットする
        val result = query.searchRecords(CoffeeRecordFilter(origin = "Geisha"))
        assertEquals(1, result.size)
        assertEquals("ゲイシャ エステート", result[0].name)
    }

    @Test
    fun originFilter_traditional_originMatch_stillWorks() = runTest {
        // 従来の「origin に産地名」が引き続きヒットする（後方互換）
        val records = listOf(
            record("r1", origin = "エチオピア", name = "シングルオリジン"),
            record("r2", origin = "ケニア", name = "ブレンド"),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(origin = "エチオピア"))
        assertEquals(1, result.size)
        assertEquals("エチオピア", result[0].origin)
    }

    @Test
    fun cafeNameFilter_traditional_cafeNameMatch_stillWorks() = runTest {
        // 従来の「cafeName にカフェ名」が引き続きヒットする（後方互換）
        val records = listOf(
            record("r1", cafe = cafe("p1", "Blue Bottle 三軒茶屋"), origin = "ケニア"),
            record("r2", cafe = cafe("p2", "Starbucks Reserve"), origin = "ブラジル"),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(cafeName = "Blue Bottle"))
        assertEquals(1, result.size)
        assertEquals("Blue Bottle 三軒茶屋", result[0].cafeName)
    }

    @Test
    fun textTermMatch_caseInsensitive_acrossAllCandidates() = runTest {
        // 大小無視が横断対象すべてで効く
        val records = listOf(
            record("r1", cafe = cafe("p1", "FUGLEN"), origin = "ETHIOPIA", name = "HAND DRIP"),
        )
        val query = makeQuery(records)

        val fuglen = query.searchRecords(CoffeeRecordFilter(origin = "fuglen"))
        assertEquals(1, fuglen.size)

        val ethiopia = query.searchRecords(CoffeeRecordFilter(cafeName = "ethiopia"))
        assertEquals(1, ethiopia.size)

        val handDrip = query.searchRecords(CoffeeRecordFilter(origin = "hand drip"))
        assertEquals(1, handDrip.size)
    }

    @Test
    fun bothOriginAndCafeNameSpecified_AND_logic() = runTest {
        // origin と cafeName を両方指定した場合は AND（各 term が union のいずれかにヒット）
        val records = listOf(
            record("r1", cafe = cafe("p1", "フグレン東京"), origin = "エチオピア", name = "シングル"),
            record("r2", cafe = cafe("p2", "Blue Bottle"), origin = "エチオピア", name = "ブレンド"),
            record("r3", cafe = cafe("p1", "フグレン東京"), origin = "ケニア", name = "アナエロビック"),
        )
        val query = makeQuery(records)

        // フグレン かつ エチオピア の両方を満たすのは r1 のみ
        val result = query.searchRecords(
            CoffeeRecordFilter(origin = "フグレン", cafeName = "エチオピア")
        )
        assertEquals(1, result.size)
        assertEquals("フグレン東京", result[0].cafeName)
        assertEquals("エチオピア", result[0].origin)
    }

    @Test
    fun noHit_whenTermMatchesNoneOfCandidates() = runTest {
        // union のどのフィールドにもヒットしない term は 0 件
        val records = listOf(
            record("r1", cafe = cafe("p1", "Blue Bottle"), origin = "エチオピア", name = "シングル"),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter(origin = "存在しないカフェ名"))
        assertTrue(result.isEmpty())
    }

    @Test
    fun textMatch_withRatingFilter_combinedFacet() = runTest {
        // 横断テキストマッチ + rating facet の組み合わせが機能する
        val records = listOf(
            record("r1", cafe = cafe("p1", "フグレン"), origin = "エチオピア", rating = 4.5),
            record("r2", cafe = cafe("p1", "フグレン"), origin = "ケニア", rating = 2.0),
            record("r3", cafe = cafe("p2", "Blue Bottle"), origin = "エチオピア", rating = 4.5),
        )
        val query = makeQuery(records)

        // origin に "フグレン"（カフェ名）+ minRating=4.0 → r1 のみヒット
        val result = query.searchRecords(
            CoffeeRecordFilter(origin = "フグレン", minRating = 4.0)
        )
        assertEquals(1, result.size)
        assertEquals(4.5, result[0].rating)
        assertEquals("フグレン", result[0].cafeName)
    }

    // ----- テスト: 複合フィルタ -----

    @Test
    fun combinedFilters_originAndRating() = runTest {
        val records = listOf(
            record("r1", origin = "エチオピア", rating = 4.5),
            record("r2", origin = "エチオピア", rating = 2.0),
            record("r3", origin = "ケニア", rating = 4.5),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(
            CoffeeRecordFilter(origin = "エチオピア", minRating = 4.0)
        )
        assertEquals(1, result.size)
        assertEquals("エチオピア", result[0].origin)
        assertEquals(4.5, result[0].rating)
    }

    @Test
    fun combinedFilters_cafeNameAndYearMonth() = runTest {
        val records = listOf(
            record("r1", cafe = cafe("p1", "Blue Bottle"), visitedOn = LocalDate(2026, 3, 1)),
            record("r2", cafe = cafe("p1", "Blue Bottle"), visitedOn = LocalDate(2026, 6, 1)),
            record("r3", cafe = cafe("p2", "Starbucks"), visitedOn = LocalDate(2026, 6, 1)),
        )
        val query = makeQuery(records)

        val result = query.searchRecords(
            CoffeeRecordFilter(cafeName = "Blue Bottle", fromYearMonth = "2026-06")
        )
        assertEquals(1, result.size)
        assertEquals("Blue Bottle", result[0].cafeName)
        assertEquals("2026-06-01", result[0].visitedOn)
    }

    // ----- テスト: CoffeeRecordSummary の変換 -----

    @Test
    fun summary_hasCorrectFields() = runTest {
        val records = listOf(
            record(
                id = "r1",
                name = "ケニア AA",
                visitedOn = LocalDate(2026, 6, 1),
                rating = 4.5,
                origin = "ケニア",
                brewMethod = BrewMethod.HandDrip,
                roastLevel = RoastLevel.Light,
                cafe = cafe("p1", "Blue Bottle 三軒茶屋"),
            )
        )
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter())
        assertEquals(1, result.size)
        val summary = result.first()
        assertEquals("ケニア AA", summary.name)
        assertEquals("Blue Bottle 三軒茶屋", summary.cafeName)
        assertEquals("ケニア", summary.origin)
        assertEquals("HandDrip", summary.brewMethod)
        assertEquals("Light", summary.roastLevel)
        assertEquals(4.5, summary.rating)
        assertEquals("2026-06-01", summary.visitedOn)
    }

    @Test
    fun summary_selfExtraction_cafeNameIsNull() = runTest {
        val records = listOf(record("r1", cafe = null))
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter())
        assertEquals(1, result.size)
        assertEquals(null, result[0].cafeName)
    }

    @Test
    fun summary_nullRoastLevel_isNull() = runTest {
        val records = listOf(record("r1", roastLevel = null))
        val query = makeQuery(records)

        val result = query.searchRecords(CoffeeRecordFilter())
        assertEquals(1, result.size)
        assertEquals(null, result[0].roastLevel)
    }
}

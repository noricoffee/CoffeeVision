package com.noricoffee.domain.usecase

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlinx.datetime.TimeZone
import kotlinx.datetime.atStartOfDayIn
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [ObserveVisitedCafesUseCase] の集計ロジックを検証する。
 *
 * [CoffeeRepository] の実装は [FakeCoffeeRepository] で差し替え、
 * 集計・ソート・平均評価の計算ロジックだけを単体でテストする。
 *
 * ## cafe=null（セルフ抽出）の扱い
 * cafe=null のレコードは座標がなくマップに表示できないため、
 * [ObserveVisitedCafesUseCase] が集計対象から除外する。
 */
class ObserveVisitedCafesUseCaseTest {

    // --- テスト用 Fake ---

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

    // --- テスト用ヘルパ ---

    private fun cafe(placeId: String, name: String = "カフェ $placeId") = Cafe(
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
        placeId: String?,
        visitedOn: LocalDate,
        rating: Double = 3.0,
        cafeName: String = "カフェ ${placeId ?: "home"}",
    ) = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = placeId?.let { cafe(it, cafeName) },
        visitedOn = visitedOn,
        rating = rating,
        notes = "",
        photos = emptyList(),
        name = "Test Coffee $id",
        brewMethod = BrewMethod.HandDrip,
        origin = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        tasting = TastingScores(),
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    // --- テスト ---

    @Test
    fun emptyRecords_returnsEmptyList() = runTest {
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(emptyList()))

        val result = useCase("user-1").first()

        assertTrue(result.isEmpty())
    }

    @Test
    fun singleRecord_returnsSingleVisitedCafe() = runTest {
        val r = record("r1", "place-1", LocalDate(2026, 6, 1), rating = 4.0)
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(listOf(r)))

        val result = useCase("user-1").first()

        assertEquals(1, result.size)
        val vc = result.first()
        assertEquals("place-1", vc.cafe.placeId)
        assertEquals(1, vc.visitCount)
        assertEquals(4.0, vc.averageRating)
    }

    @Test
    fun multipleRecordsSamePlaceId_groupedIntoOneVisitedCafe() = runTest {
        val records = listOf(
            record("r1", "place-1", LocalDate(2026, 6, 1), rating = 4.0),
            record("r2", "place-1", LocalDate(2026, 6, 10), rating = 2.0),
            record("r3", "place-1", LocalDate(2026, 5, 20), rating = 3.0),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        assertEquals(1, result.size)
        val vc = result.first()
        assertEquals("place-1", vc.cafe.placeId)
        assertEquals(3, vc.visitCount)
        // 平均: (4 + 2 + 3) / 3 = 3.0
        assertEquals(3.0, vc.averageRating)
    }

    @Test
    fun sortedByLastVisitedAtDescending() = runTest {
        val records = listOf(
            record("r1", "place-A", LocalDate(2026, 4, 1)),
            record("r2", "place-B", LocalDate(2026, 6, 15)),
            record("r3", "place-C", LocalDate(2026, 5, 10)),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        assertEquals(3, result.size)
        assertEquals("place-B", result[0].cafe.placeId)
        assertEquals("place-C", result[1].cafe.placeId)
        assertEquals("place-A", result[2].cafe.placeId)
    }

    @Test
    fun lastVisitedAt_isLatestVisitedOnInGroup() = runTest {
        val records = listOf(
            record("r1", "place-1", LocalDate(2026, 3, 1)),
            record("r2", "place-1", LocalDate(2026, 6, 15)),
            record("r3", "place-1", LocalDate(2026, 1, 10)),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        assertEquals(1, result.size)
        // lastVisitedAt = LocalDate(2026, 6, 15) の UTC 開始 Instant
        val expectedInstant = LocalDate(2026, 6, 15).toInstant()
        assertEquals(expectedInstant, result.first().lastVisitedAt)
    }

    @Test
    fun latestCafeSnapshot_usedWhenCafeNameChanged() = runTest {
        // 同じ placeId で店舗名が変わっていた場合、最新訪問の cafe が採用される
        val oldRecord = record("r1", "place-1", LocalDate(2026, 1, 1), cafeName = "Old Name")
        val newRecord = record("r2", "place-1", LocalDate(2026, 6, 1), cafeName = "New Name")
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(listOf(oldRecord, newRecord)))

        val result = useCase("user-1").first()

        assertEquals("New Name", result.first().cafe.name)
    }

    @Test
    fun averageRating_excludesZeroRating() = runTest {
        // rating = 0.0 は「未評価」として除外する
        val records = listOf(
            record("r1", "place-1", LocalDate(2026, 1, 1), rating = 0.0),
            record("r2", "place-1", LocalDate(2026, 2, 1), rating = 5.0),
            record("r3", "place-1", LocalDate(2026, 3, 1), rating = 3.0),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        // (5 + 3) / 2 = 4.0（rating=0 は除外）
        assertEquals(4.0, result.first().averageRating)
    }

    @Test
    fun averageRating_halfStepRatingsAreAveragedCorrectly() = runTest {
        // 0.5 刻みの rating が正しく平均されることを確認する
        val records = listOf(
            record("r1", "place-1", LocalDate(2026, 1, 1), rating = 4.5),
            record("r2", "place-1", LocalDate(2026, 2, 1), rating = 3.5),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        // (4.5 + 3.5) / 2 = 4.0
        assertEquals(4.0, result.first().averageRating)
    }

    @Test
    fun averageRating_nullWhenAllRatingsAreZero() = runTest {
        val records = listOf(
            record("r1", "place-1", LocalDate(2026, 1, 1), rating = 0.0),
            record("r2", "place-1", LocalDate(2026, 2, 1), rating = 0.0),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        assertNull(result.first().averageRating)
    }

    @Test
    fun multiplePlaceIds_eachBecomesOwnVisitedCafe() = runTest {
        val records = listOf(
            record("r1", "place-A", LocalDate(2026, 6, 1)),
            record("r2", "place-A", LocalDate(2026, 6, 5)),
            record("r3", "place-B", LocalDate(2026, 6, 10)),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        assertEquals(2, result.size)
        val placeAVisitedCafe = result.find { it.cafe.placeId == "place-A" }!!
        assertEquals(2, placeAVisitedCafe.visitCount)
        val placeBVisitedCafe = result.find { it.cafe.placeId == "place-B" }!!
        assertEquals(1, placeBVisitedCafe.visitCount)
        // ソート: place-B（6/10）→ place-A（6/5）
        assertEquals("place-B", result[0].cafe.placeId)
        assertEquals("place-A", result[1].cafe.placeId)
    }

    @Test
    fun nullCafeRecords_areExcludedFromResult() = runTest {
        // cafe=null（セルフ抽出）のレコードはマップに表示できないため除外される
        val records = listOf(
            record("r1", "place-1", LocalDate(2026, 6, 1), rating = 4.0),
            record("r2", null, LocalDate(2026, 6, 5), rating = 5.0),  // セルフ抽出
            record("r3", null, LocalDate(2026, 6, 10), rating = 3.0), // セルフ抽出
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        // cafe=null の 2 件は除外され、place-1 のみ
        assertEquals(1, result.size)
        assertEquals("place-1", result.first().cafe.placeId)
    }

    @Test
    fun onlyNullCafeRecords_returnsEmptyList() = runTest {
        // 全件が cafe=null（セルフ抽出）の場合は空リストが返る
        val records = listOf(
            record("r1", null, LocalDate(2026, 6, 1)),
            record("r2", null, LocalDate(2026, 6, 5)),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeCoffeeRepository(records))

        val result = useCase("user-1").first()

        assertTrue(result.isEmpty())
    }

    // --- ヘルパ ---

    private fun LocalDate.toInstant() =
        atStartOfDayIn(TimeZone.UTC)
}

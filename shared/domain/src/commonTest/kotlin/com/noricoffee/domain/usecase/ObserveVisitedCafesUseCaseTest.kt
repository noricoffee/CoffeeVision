package com.noricoffee.domain.usecase

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.Visit
import com.noricoffee.domain.model.VisitedCafe
import com.noricoffee.repository.VisitRepository
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
 * `VisitRepository` の実装は [FakeVisitRepository] で差し替え、
 * 集計・ソート・平均評価の計算ロジックだけを単体でテストする。
 */
class ObserveVisitedCafesUseCaseTest {

    // --- テスト用 Fake ---

    private class FakeVisitRepository(
        private val visits: List<Visit> = emptyList(),
    ) : VisitRepository {

        private val flow = MutableStateFlow(visits)

        override fun observeAll(userId: String): Flow<List<Visit>> = flow

        override fun observeById(id: String): Flow<Visit?> =
            MutableStateFlow(visits.firstOrNull { it.id == id })

        override fun observeByCafe(userId: String, placeId: String): Flow<List<Visit>> =
            MutableStateFlow(visits.filter { it.cafe.placeId == placeId })

        override suspend fun save(visit: Visit) = Unit

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

    private fun visit(
        id: String,
        placeId: String,
        visitedOn: LocalDate,
        rating: Int = 3,
        cafeName: String = "カフェ $placeId",
    ) = Visit(
        id = id,
        userId = "user-1",
        cafe = cafe(placeId, cafeName),
        visitedOn = visitedOn,
        ambiance = "",
        rating = rating,
        notes = "",
        photos = emptyList(),
        coffees = emptyList(),
        foods = emptyList(),
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    // --- テスト ---

    @Test
    fun emptyVisits_returnsEmptyList() = runTest {
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(emptyList()))

        val result = useCase("user-1").first()

        assertTrue(result.isEmpty())
    }

    @Test
    fun singleVisit_returnsSingleVisitedCafe() = runTest {
        val v = visit("v1", "place-1", LocalDate(2026, 6, 1), rating = 4)
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(listOf(v)))

        val result = useCase("user-1").first()

        assertEquals(1, result.size)
        val vc = result.first()
        assertEquals("place-1", vc.cafe.placeId)
        assertEquals(1, vc.visitCount)
        assertEquals(4.0, vc.averageRating)
    }

    @Test
    fun multipleVisitsSamePlaceId_groupedIntoOneVisitedCafe() = runTest {
        val visits = listOf(
            visit("v1", "place-1", LocalDate(2026, 6, 1), rating = 4),
            visit("v2", "place-1", LocalDate(2026, 6, 10), rating = 2),
            visit("v3", "place-1", LocalDate(2026, 5, 20), rating = 3),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(visits))

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
        val visits = listOf(
            visit("v1", "place-A", LocalDate(2026, 4, 1)),
            visit("v2", "place-B", LocalDate(2026, 6, 15)),
            visit("v3", "place-C", LocalDate(2026, 5, 10)),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(visits))

        val result = useCase("user-1").first()

        assertEquals(3, result.size)
        assertEquals("place-B", result[0].cafe.placeId)
        assertEquals("place-C", result[1].cafe.placeId)
        assertEquals("place-A", result[2].cafe.placeId)
    }

    @Test
    fun lastVisitedAt_isLatestVisitedOnInGroup() = runTest {
        val visits = listOf(
            visit("v1", "place-1", LocalDate(2026, 3, 1)),
            visit("v2", "place-1", LocalDate(2026, 6, 15)),
            visit("v3", "place-1", LocalDate(2026, 1, 10)),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(visits))

        val result = useCase("user-1").first()

        assertEquals(1, result.size)
        // lastVisitedAt = LocalDate(2026, 6, 15) の UTC 開始 Instant
        val expectedInstant = LocalDate(2026, 6, 15).toInstant()
        assertEquals(expectedInstant, result.first().lastVisitedAt)
    }

    @Test
    fun latestCafeSnapshot_usedWhenCafeNameChanged() = runTest {
        // 同じ placeId で店舗名が変わっていた場合、最新訪問の cafe が採用される
        val oldVisit = visit("v1", "place-1", LocalDate(2026, 1, 1), cafeName = "Old Name")
        val newVisit = visit("v2", "place-1", LocalDate(2026, 6, 1), cafeName = "New Name")
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(listOf(oldVisit, newVisit)))

        val result = useCase("user-1").first()

        assertEquals("New Name", result.first().cafe.name)
    }

    @Test
    fun averageRating_excludesZeroRating() = runTest {
        // rating = 0 は「未評価」として除外する
        val visits = listOf(
            visit("v1", "place-1", LocalDate(2026, 1, 1), rating = 0),
            visit("v2", "place-1", LocalDate(2026, 2, 1), rating = 5),
            visit("v3", "place-1", LocalDate(2026, 3, 1), rating = 3),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(visits))

        val result = useCase("user-1").first()

        // (5 + 3) / 2 = 4.0（rating=0 は除外）
        assertEquals(4.0, result.first().averageRating)
    }

    @Test
    fun averageRating_nullWhenAllRatingsAreZero() = runTest {
        val visits = listOf(
            visit("v1", "place-1", LocalDate(2026, 1, 1), rating = 0),
            visit("v2", "place-1", LocalDate(2026, 2, 1), rating = 0),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(visits))

        val result = useCase("user-1").first()

        assertNull(result.first().averageRating)
    }

    @Test
    fun multiplePlaceIds_eachBecomesOwnVisitedCafe() = runTest {
        val visits = listOf(
            visit("v1", "place-A", LocalDate(2026, 6, 1)),
            visit("v2", "place-A", LocalDate(2026, 6, 5)),
            visit("v3", "place-B", LocalDate(2026, 6, 10)),
        )
        val useCase = ObserveVisitedCafesUseCase(FakeVisitRepository(visits))

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

    // --- ヘルパ ---

    private fun LocalDate.toInstant() =
        atStartOfDayIn(TimeZone.UTC)
}

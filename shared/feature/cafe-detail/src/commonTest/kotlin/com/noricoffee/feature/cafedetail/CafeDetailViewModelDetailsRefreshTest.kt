package com.noricoffee.feature.cafedetail

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * [CafeDetailViewModel] の条件付き Places Details リフレッシュ（フェーズ 16）の状態遷移テスト。
 *
 * ## 検証ケース
 * (a) [initialCafe] が DB スナップショット由来（`googleRating == null`）→ details が取得され cafe が上書きされる
 * (b) details 取得後に records が再 emit しても、cafe 採用は [CafeDetailViewModel] 内部の `latestDetails` が優先される
 * (c) details 取得失敗時はスナップショット表示を維持し、`error` は null のまま
 * (d) 新鮮な [initialCafe]（`googleRating != null`）では details を取得しない（API を叩かない）
 */
class CafeDetailViewModelDetailsRefreshTest {

    private class FakeCoffeeRepository(
        initial: List<CoffeeRecord> = emptyList(),
    ) : CoffeeRepository {
        val recordsFlow = MutableStateFlow(initial)
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = recordsFlow
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    private class FakeCafeRepository(
        private val detailsResult: Cafe? = null,
        private val shouldThrow: Boolean = false,
    ) : CafeRepository {
        var getDetailsCallCount: Int = 0

        override suspend fun searchText(query: String): List<Cafe> = emptyList()
        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> = emptyList()
        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<Cafe> = emptyList()

        override suspend fun getDetails(placeId: String): Cafe {
            getDetailsCallCount++
            if (shouldThrow) throw RuntimeException("details fetch failed")
            return detailsResult ?: makeCafe(placeId, googleRating = 4.5)
        }

        override suspend fun photoMediaUrl(
            photoName: String,
            maxWidthPx: Int?,
            maxHeightPx: Int?,
        ): String = "https://fake.example.com/photo"
    }

    private class FakeSavedCafeRepository : SavedCafeRepository {
        override fun observeAll(userId: String): Flow<List<SavedCafe>> = flowOf(emptyList())
        override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> = flowOf(null)
        override suspend fun save(savedCafe: SavedCafe) = Unit
        override suspend fun delete(userId: String, placeId: String) = Unit
    }

    private companion object {
        const val USER_ID = "user-01"
        const val PLACE_ID = "place-1"

        fun makeCafe(placeId: String = PLACE_ID, googleRating: Double? = null): Cafe = Cafe(
            placeId = placeId,
            name = "Test Cafe",
            address = null,
            latitude = 35.0,
            longitude = 139.0,
            photoReferences = emptyList(),
            websiteUrl = null,
            mapsUrl = null,
            googleRating = googleRating,
        )

        fun makeCoffeeRecord(cafe: Cafe, visitedOn: LocalDate): CoffeeRecord = CoffeeRecord(
            id = "record-${cafe.placeId}-$visitedOn",
            userId = USER_ID,
            cafe = cafe,
            visitedOn = visitedOn,
            rating = 4.0,
            notes = "",
            photos = emptyList(),
            name = "コーヒー",
            brewMethod = com.noricoffee.domain.BrewMethod.HandDrip,
            origin = null,
            variety = null,
            processing = null,
            roastLevel = null,
            cup = null,
            brewRecipe = null,
            tasting = null,
            createdAt = kotlinx.datetime.Instant.fromEpochMilliseconds(1_750_000_000_000),
            updatedAt = kotlinx.datetime.Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
    }

    // -----------------------------------------------------------------------
    // (a) DB スナップショット由来（googleRating == null）→ details が取得され cafe が上書きされる
    // -----------------------------------------------------------------------

    @Test
    fun staleSnapshot_triggersDetailsFetch_andOverridesCafe() = runTest {
        val staleCafe = makeCafe(googleRating = null)
        val detailsCafe = makeCafe(googleRating = 4.7)
        val fakeCafeRepo = FakeCafeRepository(detailsResult = detailsCafe)

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafeRepo,
            savedCafeRepository = FakeSavedCafeRepository(),
            placeId = PLACE_ID,
            initialCafe = staleCafe,
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(1, fakeCafeRepo.getDetailsCallCount)
        assertEquals(4.7, vm.state.value.cafe?.googleRating)

        vm.clear()
    }

    @Test
    fun nullInitialCafe_triggersDetailsFetch() = runTest {
        val detailsCafe = makeCafe(googleRating = 4.2)
        val fakeCafeRepo = FakeCafeRepository(detailsResult = detailsCafe)

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafeRepo,
            savedCafeRepository = FakeSavedCafeRepository(),
            placeId = PLACE_ID,
            initialCafe = null,
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(1, fakeCafeRepo.getDetailsCallCount)
        assertEquals(4.2, vm.state.value.cafe?.googleRating)

        vm.clear()
    }

    // -----------------------------------------------------------------------
    // (b) details 取得後に records が再 emit しても latestDetails が優先される
    // -----------------------------------------------------------------------

    @Test
    fun afterDetailsArrive_laterRecordEmission_doesNotRevertCafe() = runTest {
        val staleCafe = makeCafe(googleRating = null)
        val detailsCafe = makeCafe(googleRating = 4.7)
        val fakeCafeRepo = FakeCafeRepository(detailsResult = detailsCafe)
        val fakeCoffeeRepo = FakeCoffeeRepository()

        val vm = CafeDetailViewModel(
            coffeeRepository = fakeCoffeeRepo,
            cafeRepository = fakeCafeRepo,
            savedCafeRepository = FakeSavedCafeRepository(),
            placeId = PLACE_ID,
            initialCafe = staleCafe,
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()
        assertEquals(4.7, vm.state.value.cafe?.googleRating)

        // records が再 emit される（別の記録のスナップショットは googleRating を持たない古いものと仮定）
        val recordCafeSnapshot = makeCafe(googleRating = null)
        fakeCoffeeRepo.recordsFlow.value = listOf(
            makeCoffeeRecord(recordCafeSnapshot, LocalDate(2026, 7, 1)),
        )
        testScheduler.advanceUntilIdle()

        // latestDetails が優先されるため、cafe は details 取得結果のまま巻き戻らない
        assertEquals(4.7, vm.state.value.cafe?.googleRating)

        vm.clear()
    }

    // -----------------------------------------------------------------------
    // (c) details 取得失敗時はスナップショット表示を維持し、error は null のまま
    // -----------------------------------------------------------------------

    @Test
    fun detailsFetchFailure_keepsSnapshotAndDoesNotSetError() = runTest {
        val staleCafe = makeCafe(googleRating = null)
        val fakeCafeRepo = FakeCafeRepository(shouldThrow = true)

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafeRepo,
            savedCafeRepository = FakeSavedCafeRepository(),
            placeId = PLACE_ID,
            initialCafe = staleCafe,
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(1, fakeCafeRepo.getDetailsCallCount)
        assertEquals(staleCafe, vm.state.value.cafe)
        assertNull(vm.state.value.error)

        vm.clear()
    }

    // -----------------------------------------------------------------------
    // (d) 新鮮な initialCafe（googleRating != null）では details を取得しない
    // -----------------------------------------------------------------------

    @Test
    fun freshInitialCafe_doesNotTriggerDetailsFetch() = runTest {
        val freshCafe = makeCafe(googleRating = 4.3)
        val fakeCafeRepo = FakeCafeRepository()

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = fakeCafeRepo,
            savedCafeRepository = FakeSavedCafeRepository(),
            placeId = PLACE_ID,
            initialCafe = freshCafe,
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(0, fakeCafeRepo.getDetailsCallCount)
        assertEquals(freshCafe, vm.state.value.cafe)

        vm.clear()
    }
}

package com.noricoffee.feature.map

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.CuratedCafe
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.CuratedCafeRepository
import com.noricoffee.repository.SavedCafeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * [MapViewModel] の「行きたい店」関連（フェーズ 15-A）の状態遷移テスト。
 *
 * - [SavedCafeRepository.observeAll] の購読結果が [MapViewModel.UIState.savedCafes] に反映される
 * - [MapViewModel.onSavedCafeRemoved] が [SavedCafeRepository.delete] を呼ぶ
 * - [MapViewModel.UIState.recordedPlaceIds] が訪問済みカフェ（記録あり）の placeId から導出される
 */
class MapViewModelSavedCafeTest {

    private class FakeCoffeeRepository(
        private val records: List<CoffeeRecord> = emptyList(),
    ) : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(records)
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    private class FakeCafeRepository : CafeRepository {
        override suspend fun searchText(query: String): List<Cafe> = emptyList()
        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> = emptyList()

        override suspend fun searchByNameNear(query: String, locationBias: LocationBias): List<Cafe> = emptyList()
        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<Cafe> = emptyList()

        override suspend fun getDetails(placeId: String): Cafe = makeCafe(placeId)
        override suspend fun photoMediaUrl(
            photoName: String,
            maxWidthPx: Int?,
            maxHeightPx: Int?,
        ): String = "https://fake.example.com/photo"
    }

    private class FakeCafeRecommendationProvider : CafeRecommendationProvider {
        override fun observeRecommendedCafes(userId: String): Flow<List<RecommendedCafe>> = flowOf(emptyList())
    }

    private class FakeSavedCafeRepository(
        initial: List<SavedCafe> = emptyList(),
    ) : SavedCafeRepository {
        val savedCafesFlow = MutableStateFlow(initial)
        val deleted = mutableListOf<Pair<String, String>>()
        val saved = mutableListOf<SavedCafe>()
        var failSave = false
        var failDelete = false

        override fun observeAll(userId: String): Flow<List<SavedCafe>> = savedCafesFlow
        override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> = flowOf(null)
        override suspend fun save(savedCafe: SavedCafe) {
            if (failSave) throw RuntimeException("save failed")
            saved.add(savedCafe)
            savedCafesFlow.value = savedCafesFlow.value + savedCafe
        }
        override suspend fun delete(userId: String, placeId: String) {
            if (failDelete) throw RuntimeException("delete failed")
            deleted.add(userId to placeId)
            savedCafesFlow.value = savedCafesFlow.value.filterNot { it.cafe.placeId == placeId }
        }
    }

    private class FakeCuratedCafeRepository : CuratedCafeRepository {
        override suspend fun getAll(): List<CuratedCafe> = emptyList()
    }

    private companion object {
        fun makeCafe(placeId: String): Cafe = Cafe(
            placeId = placeId,
            name = "Test Cafe $placeId",
            address = null,
            latitude = null,
            longitude = null,
            photoReferences = emptyList(),
            websiteUrl = null,
            mapsUrl = null,
        )

        fun makeSavedCafe(placeId: String, savedAt: Instant): SavedCafe = SavedCafe(
            userId = "user-01",
            cafe = makeCafe(placeId),
            note = "",
            savedAt = savedAt,
        )

        fun makeCoffeeRecord(placeId: String): CoffeeRecord = CoffeeRecord(
            id = "record-$placeId",
            userId = "user-01",
            cafe = makeCafe(placeId),
            visitedOn = kotlinx.datetime.LocalDate(2026, 6, 1),
            rating = 4.0,
            notes = "",
            photos = emptyList(),
            name = "コーヒー",
            brewMethod = BrewMethod.HandDrip,
            origin = null,
            region = null,
            variety = null,
            processing = null,
            roastLevel = null,
            cup = null,
            brewRecipe = null,
            tasting = null,
            createdAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
            updatedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
    }

    @Test
    fun savedCafes_reflects_repository_subscription() = runTest {
        val savedCafe = makeSavedCafe("place-1", Instant.fromEpochMilliseconds(1_750_000_000_000))
        val fakeSavedCafeRepo = FakeSavedCafeRepository(initial = listOf(savedCafe))
        val fakeCoffeeRepo = FakeCoffeeRepository()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            curatedCafeRepository = FakeCuratedCafeRepository(),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(listOf(savedCafe), vm.state.value.savedCafes)

        vm.clear()
    }

    @Test
    fun onSavedCafeRemoved_calls_repository_delete_and_updates_state() = runTest {
        val savedCafe = makeSavedCafe("place-1", Instant.fromEpochMilliseconds(1_750_000_000_000))
        val fakeSavedCafeRepo = FakeSavedCafeRepository(initial = listOf(savedCafe))
        val fakeCoffeeRepo = FakeCoffeeRepository()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            curatedCafeRepository = FakeCuratedCafeRepository(),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()
        assertEquals(1, vm.state.value.savedCafes.size)

        vm.onSavedCafeRemoved("place-1")
        testScheduler.advanceUntilIdle()

        assertEquals(listOf("user-01" to "place-1"), fakeSavedCafeRepo.deleted)
        assertTrue(vm.state.value.savedCafes.isEmpty())

        vm.clear()
    }

    @Test
    fun recordedPlaceIds_derived_from_visited_cafes_regardless_of_tag_filter() = runTest {
        val recordedCafeRecord = makeCoffeeRecord("place-recorded")
        val fakeCoffeeRepo = FakeCoffeeRepository(records = listOf(recordedCafeRecord))
        val fakeSavedCafeRepo = FakeSavedCafeRepository()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            curatedCafeRepository = FakeCuratedCafeRepository(),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(setOf("place-recorded"), vm.state.value.recordedPlaceIds)

        vm.clear()
    }

    // -----------------------------------------------------------------------
    // onCafeSaveToggled（フェーズ 16）
    // -----------------------------------------------------------------------

    @Test
    fun onCafeSaveToggled_saves_when_not_saved() = runTest {
        val fakeSavedCafeRepo = FakeSavedCafeRepository()
        val fakeCoffeeRepo = FakeCoffeeRepository()
        val cafe = makeCafe("place-1")

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            curatedCafeRepository = FakeCuratedCafeRepository(),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()
        assertTrue(vm.state.value.savedCafes.isEmpty())

        vm.onCafeSaveToggled(cafe)
        testScheduler.advanceUntilIdle()

        assertEquals(1, fakeSavedCafeRepo.saved.size)
        assertEquals("place-1", fakeSavedCafeRepo.saved.first().cafe.placeId)
        assertEquals("", fakeSavedCafeRepo.saved.first().note)
        assertEquals(listOf("place-1"), vm.state.value.savedCafes.map { it.cafe.placeId })

        vm.clear()
    }

    @Test
    fun onCafeSaveToggled_deletes_when_already_saved() = runTest {
        val savedCafe = makeSavedCafe("place-1", Instant.fromEpochMilliseconds(1_750_000_000_000))
        val fakeSavedCafeRepo = FakeSavedCafeRepository(initial = listOf(savedCafe))
        val fakeCoffeeRepo = FakeCoffeeRepository()
        val cafe = makeCafe("place-1")

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            curatedCafeRepository = FakeCuratedCafeRepository(),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()
        assertEquals(1, vm.state.value.savedCafes.size)

        vm.onCafeSaveToggled(cafe)
        testScheduler.advanceUntilIdle()

        assertEquals(listOf("user-01" to "place-1"), fakeSavedCafeRepo.deleted)
        assertTrue(vm.state.value.savedCafes.isEmpty())

        vm.clear()
    }

    @Test
    fun onCafeSaveToggled_save_failure_sets_error() = runTest {
        val fakeSavedCafeRepo = FakeSavedCafeRepository()
        fakeSavedCafeRepo.failSave = true
        val fakeCoffeeRepo = FakeCoffeeRepository()
        val cafe = makeCafe("place-1")

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            curatedCafeRepository = FakeCuratedCafeRepository(),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        vm.onCafeSaveToggled(cafe)
        testScheduler.advanceUntilIdle()

        assertNotNull(vm.state.value.error)
        assertTrue(vm.state.value.savedCafes.isEmpty())

        vm.clear()
    }
}

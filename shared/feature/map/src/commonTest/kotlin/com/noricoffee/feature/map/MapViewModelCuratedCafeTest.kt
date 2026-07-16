package com.noricoffee.feature.map

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
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [MapViewModel] の都道府県別おすすめカフェ一括ロード（フェーズ 19）の状態遷移テスト。
 *
 * - [CuratedCafeRepository.getAll] の成功結果が [MapViewModel.UIState.curatedCafes] /
 *   [MapViewModel.UIState.curatedPlaceIds] に反映される
 * - [CuratedCafeRepository.getAll] が例外を投げた場合は黙って空のまま（[MapViewModel.UIState.error] に流さない）
 *
 * ## scope と vm.clear() の注意
 * [MapViewModelPoiLookupTest] と同じ理由で各テスト末尾で `vm.clear()` を呼ぶ。
 */
class MapViewModelCuratedCafeTest {

    private class FakeCoffeeRepository : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
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

    private class FakeSavedCafeRepository : SavedCafeRepository {
        override fun observeAll(userId: String): Flow<List<SavedCafe>> = flowOf(emptyList())
        override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> = flowOf(null)
        override suspend fun save(savedCafe: SavedCafe) = Unit
        override suspend fun delete(userId: String, placeId: String) = Unit
    }

    private class FakeCuratedCafeRepository(
        private val result: List<CuratedCafe> = emptyList(),
        private val error: Exception? = null,
    ) : CuratedCafeRepository {
        override suspend fun getAll(): List<CuratedCafe> {
            error?.let { throw it }
            return result
        }
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

        fun makeCuratedCafe(placeId: String, prefectureCode: String = "13"): CuratedCafe = CuratedCafe(
            placeId = placeId,
            name = "Curated Cafe $placeId",
            latitude = 35.658,
            longitude = 139.701,
            prefectureCode = prefectureCode,
        )
    }

    @Test
    fun getAll_success_populatesCuratedCafesAndPlaceIds() = runTest {
        val curatedCafes = listOf(makeCuratedCafe("place-1"), makeCuratedCafe("place-2"))
        val fakeCoffeeRepo = FakeCoffeeRepository()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = FakeSavedCafeRepository(),
            curatedCafeRepository = FakeCuratedCafeRepository(result = curatedCafes),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(curatedCafes, vm.state.value.curatedCafes)
        assertEquals(setOf("place-1", "place-2"), vm.state.value.curatedPlaceIds)

        vm.clear()
    }

    @Test
    fun getAll_failure_leavesCuratedCafesEmptyAndDoesNotSetError() = runTest {
        val fakeCoffeeRepo = FakeCoffeeRepository()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo),
            cafeRecommendationProvider = FakeCafeRecommendationProvider(),
            cafeRepository = FakeCafeRepository(),
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = FakeSavedCafeRepository(),
            curatedCafeRepository = FakeCuratedCafeRepository(error = RuntimeException("Firestore error")),
            userId = "user-01",
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertTrue(vm.state.value.curatedCafes.isEmpty())
        assertTrue(vm.state.value.curatedPlaceIds.isEmpty())
        assertNull(vm.state.value.error)

        vm.clear()
    }
}

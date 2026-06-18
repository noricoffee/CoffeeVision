package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [MapViewModel.onPoiTapped] / [MapViewModel.onPoiLookupConsumed] / [MapViewModel.onPoiLookupErrorDismissed]
 * の状態遷移テスト。
 *
 * - `onPoiTapped` → 結果あり → `poiLookupResult` がセットされる
 * - `onPoiTapped` → 空結果 → `poiLookupError` にメッセージがセットされる
 * - `onPoiTapped` → 例外 → `poiLookupError` にエラーメッセージがセットされる
 * - `onPoiLookupConsumed` → `poiLookupResult` が null に戻る
 * - `onPoiLookupErrorDismissed` → `poiLookupError` が null に戻る
 * - `locationBias` の引数が CafeRepository に正しく渡されている
 */
class MapViewModelPoiLookupTest {

    // --- Fakes ---

    private class FakeCoffeeRepository : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    private class FakeCafeRepository : CafeRepository {

        // searchText(query, locationBias) の最後の呼び出し引数を記録
        var lastSearchTextQuery: String? = null
        var lastSearchTextLocationBias: LocationBias? = null

        // stub 用の戻り値（`null` のときは例外を投げる）
        var searchTextResult: List<Cafe>? = emptyList()
        var searchTextError: Exception? = null

        override suspend fun searchText(query: String): List<Cafe> {
            lastSearchTextQuery = query
            lastSearchTextLocationBias = null
            searchTextError?.let { throw it }
            return searchTextResult ?: emptyList()
        }

        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> {
            lastSearchTextQuery = query
            lastSearchTextLocationBias = locationBias
            searchTextError?.let { throw it }
            return searchTextResult ?: emptyList()
        }

        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<Cafe> = emptyList()

        override suspend fun getDetails(placeId: String): Cafe = Cafe(
            placeId = placeId,
            name = "Test Cafe",
            address = null,
            latitude = null,
            longitude = null,
            photoReferences = emptyList(),
            websiteUrl = null,
            mapsUrl = null,
        )

        override suspend fun photoMediaUrl(
            photoName: String,
            maxWidthPx: Int?,
            maxHeightPx: Int?,
        ): String = "https://fake.example.com/photo"
    }

    private fun makeCafe(placeId: String = "test-place-id"): Cafe = Cafe(
        placeId = placeId,
        name = "Test Cafe",
        address = "東京都渋谷区テスト 1-2-3",
        latitude = 35.658,
        longitude = 139.701,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )

    // --- 共通セットアップ ---

    private val fakeCafeRepo = FakeCafeRepository()
    private val fakeCoffeeRepo = FakeCoffeeRepository()
    private val useCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo)

    // --- テスト ---

    @Test
    fun onPoiTapped_withResults_setsPoiLookupResult() = runTest {
        val cafe = makeCafe("ChIJ001")
        fakeCafeRepo.searchTextResult = listOf(cafe)

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRepository = fakeCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Test Cafe", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertEquals(cafe, state.poiLookupResult)
        assertNull(state.poiLookupError)
    }

    @Test
    fun onPoiTapped_withResults_passesLocationBiasToRepository() = runTest {
        fakeCafeRepo.searchTextResult = listOf(makeCafe())

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRepository = fakeCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Blue Bottle", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        assertEquals("Blue Bottle", fakeCafeRepo.lastSearchTextQuery)
        val bias = fakeCafeRepo.lastSearchTextLocationBias
        assertNotNull(bias)
        assertEquals(35.658, bias.latitude)
        assertEquals(139.701, bias.longitude)
        assertEquals(500.0, bias.radiusMeters)
    }

    @Test
    fun onPoiTapped_emptyResults_setsPoiLookupError() = runTest {
        fakeCafeRepo.searchTextResult = emptyList()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRepository = fakeCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "No Such Cafe", latitude = 0.0, longitude = 0.0)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertNull(state.poiLookupResult)
        assertEquals("該当するカフェが見つかりませんでした", state.poiLookupError)
    }

    @Test
    fun onPoiTapped_throwsException_setsPoiLookupError() = runTest {
        fakeCafeRepo.searchTextError = Exception("Network timeout")

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRepository = fakeCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Error Cafe", latitude = 0.0, longitude = 0.0)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertNull(state.poiLookupResult)
        assertEquals("Network timeout", state.poiLookupError)
    }

    @Test
    fun onPoiLookupConsumed_clearsPoiLookupResult() = runTest {
        fakeCafeRepo.searchTextResult = listOf(makeCafe())

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRepository = fakeCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Test Cafe", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()
        assertNotNull(vm.state.value.poiLookupResult)

        vm.onPoiLookupConsumed()

        assertNull(vm.state.value.poiLookupResult)
    }

    @Test
    fun onPoiLookupErrorDismissed_clearsPoiLookupError() = runTest {
        fakeCafeRepo.searchTextResult = emptyList()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRepository = fakeCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "No Such Cafe", latitude = 0.0, longitude = 0.0)
        testScheduler.advanceUntilIdle()
        assertNotNull(vm.state.value.poiLookupError)

        vm.onPoiLookupErrorDismissed()

        assertNull(vm.state.value.poiLookupError)
    }

    @Test
    fun onPoiTapped_retainsPreviousNearbyPlaces() = runTest {
        fakeCafeRepo.searchTextResult = listOf(makeCafe("poi-001"))

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRepository = fakeCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Test Cafe", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertNotNull(state.poiLookupResult)
        // nearbyPlaces / visitedCafes は変化していない
        assertTrue(state.nearbyPlaces.isEmpty())
        assertTrue(state.visitedCafes.isEmpty())
    }
}

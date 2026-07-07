package com.noricoffee.feature.map

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.domain.usecase.ObserveVisitedCafesUseCase
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
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
 * - 座標 / 半径の引数が `CafeRepository.searchNearby` に正しく渡されている（フェーズ 17-B: `searchText` から
 *   `searchNearby` へ切替。Apple↔Google の名称差・`coffee_shop` 型の取りこぼしを避けるため座標アンカー解決にした）
 *
 * ## scope と vm.clear() の注意
 *
 * MapViewModel は `scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job])` で
 * 内部 viewModelScope を作る。`scope = this`（TestScope）とするとその SupervisorJob が
 * TestScope の子 Job になり、runTest が「Active child job」として検出し
 * UncompletedCoroutinesError を投げる。
 * これを避けるため、各テスト末尾で `vm.clear()` を呼び viewModelScope をキャンセルする。
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

        // searchNearby(latitude, longitude, radiusMeters) の最後の呼び出し引数を記録
        var lastSearchNearbyLatitude: Double? = null
        var lastSearchNearbyLongitude: Double? = null
        var lastSearchNearbyRadiusMeters: Double? = null

        // stub 用の戻り値（`null` のときは例外を投げる）
        var searchNearbyResult: List<Cafe>? = emptyList()
        var searchNearbyError: Exception? = null

        override suspend fun searchText(query: String): List<Cafe> = emptyList()

        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> = emptyList()

        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<Cafe> {
            lastSearchNearbyLatitude = latitude
            lastSearchNearbyLongitude = longitude
            lastSearchNearbyRadiusMeters = radiusMeters
            searchNearbyError?.let { throw it }
            return searchNearbyResult ?: emptyList()
        }

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

    private class FakeCafeRecommendationProvider : CafeRecommendationProvider {
        override fun observeRecommendedCafes(userId: String): Flow<List<RecommendedCafe>> =
            flowOf(emptyList())
    }

    private class FakeSavedCafeRepository : SavedCafeRepository {
        override fun observeAll(userId: String): Flow<List<SavedCafe>> = flowOf(emptyList())
        override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> = flowOf(null)
        override suspend fun save(savedCafe: SavedCafe) = Unit
        override suspend fun delete(userId: String, placeId: String) = Unit
    }

    private val fakeCafeRepo = FakeCafeRepository()
    private val fakeCoffeeRepo = FakeCoffeeRepository()
    private val useCase = ObserveVisitedCafesUseCase(fakeCoffeeRepo)
    private val fakeRecommendationProvider = FakeCafeRecommendationProvider()
    private val fakeSavedCafeRepo = FakeSavedCafeRepository()

    // --- テスト ---

    @Test
    fun onPoiTapped_withResults_setsPoiLookupResult() = runTest {
        val cafe = makeCafe("ChIJ001")
        fakeCafeRepo.searchNearbyResult = listOf(cafe)

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Test Cafe", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertEquals(cafe, state.poiLookupResult)
        assertNull(state.poiLookupError)

        vm.clear()
    }

    @Test
    fun onPoiTapped_withResults_passesCoordinatesToSearchNearby() = runTest {
        fakeCafeRepo.searchNearbyResult = listOf(makeCafe())

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Blue Bottle", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        assertEquals(35.658, fakeCafeRepo.lastSearchNearbyLatitude)
        assertEquals(139.701, fakeCafeRepo.lastSearchNearbyLongitude)
        assertEquals(150.0, fakeCafeRepo.lastSearchNearbyRadiusMeters)

        vm.clear()
    }

    @Test
    fun onPoiTapped_emptyResults_setsPoiLookupError() = runTest {
        fakeCafeRepo.searchNearbyResult = emptyList()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "No Such Cafe", latitude = 0.0, longitude = 0.0)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertNull(state.poiLookupResult)
        assertEquals("該当するカフェが見つかりませんでした", state.poiLookupError)

        vm.clear()
    }

    @Test
    fun onPoiTapped_throwsException_setsPoiLookupError() = runTest {
        fakeCafeRepo.searchNearbyError = Exception("Network timeout")

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Error Cafe", latitude = 0.0, longitude = 0.0)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertNull(state.poiLookupResult)
        assertEquals("Network timeout", state.poiLookupError)

        vm.clear()
    }

    @Test
    fun onPoiLookupConsumed_clearsPoiLookupResult() = runTest {
        fakeCafeRepo.searchNearbyResult = listOf(makeCafe())

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Test Cafe", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()
        assertNotNull(vm.state.value.poiLookupResult)

        vm.onPoiLookupConsumed()

        assertNull(vm.state.value.poiLookupResult)

        vm.clear()
    }

    @Test
    fun onPoiLookupErrorDismissed_clearsPoiLookupError() = runTest {
        fakeCafeRepo.searchNearbyResult = emptyList()

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "No Such Cafe", latitude = 0.0, longitude = 0.0)
        testScheduler.advanceUntilIdle()
        assertNotNull(vm.state.value.poiLookupError)

        vm.onPoiLookupErrorDismissed()

        assertNull(vm.state.value.poiLookupError)

        vm.clear()
    }

    @Test
    fun onPoiTapped_retainsVisitedCafes() = runTest {
        fakeCafeRepo.searchNearbyResult = listOf(makeCafe("poi-001"))

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "Test Cafe", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertNotNull(state.poiLookupResult)
        // visitedCafes は変化していない
        assertTrue(state.visitedCafes.isEmpty())

        vm.clear()
    }
}

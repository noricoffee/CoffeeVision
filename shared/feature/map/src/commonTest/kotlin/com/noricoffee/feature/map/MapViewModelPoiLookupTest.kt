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
 * - query / 位置バイアスが `CafeRepository.searchByNameNear` に正しく渡されている
 * - 名前一致優先・名前一致なしはタップ座標最近傍・同名チェーンは最近傍で解決される（フェーズ 17-D:
 *   `searchNearby` の型フィルタで Apple の非 cafe 型店が候補落ちし全部同じ店に解決される不具合の修正。
 *   型フィルタなしの名前+位置検索 `searchByNameNear` に切替、タップ座標最近傍で選ぶ）
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

        // searchByNameNear(query, locationBias) の最後の呼び出し引数を記録（POI タップ解決はこちらを使う）
        var lastSearchByNameNearQuery: String? = null
        var lastSearchByNameNearLocationBias: LocationBias? = null

        // stub 用の戻り値（`null` のときは例外を投げる）
        var searchByNameNearResult: List<Cafe>? = emptyList()
        var searchByNameNearError: Exception? = null

        override suspend fun searchText(query: String): List<Cafe> = emptyList()

        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> = emptyList()

        override suspend fun searchByNameNear(query: String, locationBias: LocationBias): List<Cafe> {
            lastSearchByNameNearQuery = query
            lastSearchByNameNearLocationBias = locationBias
            searchByNameNearError?.let { throw it }
            return searchByNameNearResult ?: emptyList()
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
        fakeCafeRepo.searchByNameNearResult = listOf(cafe)

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
    fun onPoiTapped_withResults_passesQueryAndLocationBiasToSearchByNameNear() = runTest {
        fakeCafeRepo.searchByNameNearResult = listOf(makeCafe())

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

        assertEquals("Blue Bottle", fakeCafeRepo.lastSearchByNameNearQuery)
        val bias = fakeCafeRepo.lastSearchByNameNearLocationBias
        assertNotNull(bias)
        assertEquals(35.658, bias.latitude)
        assertEquals(139.701, bias.longitude)
        assertEquals(200.0, bias.radiusMeters)

        vm.clear()
    }

    @Test
    fun onPoiTapped_emptyResults_setsPoiLookupError() = runTest {
        fakeCafeRepo.searchByNameNearResult = emptyList()

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
        assertEquals("該当するカフェが見つかりませんでした", state.poiLookupError?.message)
        assertTrue(state.poiLookupError?.isNotFound == true)

        vm.clear()
    }

    @Test
    fun onPoiTapped_throwsException_setsPoiLookupError() = runTest {
        fakeCafeRepo.searchByNameNearError = Exception("Network timeout")

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
        assertEquals("Network timeout", state.poiLookupError?.message)
        assertFalse(state.poiLookupError?.isNotFound == true)

        vm.clear()
    }

    @Test
    fun onPoiLookupConsumed_clearsPoiLookupResult() = runTest {
        fakeCafeRepo.searchByNameNearResult = listOf(makeCafe())

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
        fakeCafeRepo.searchByNameNearResult = emptyList()

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
    fun onPoiTapped_multipleNearbyCandidates_prefersNameMatchOverNearest() = runTest {
        val nearestButDifferentName = makeCafe("nearest-different-name").copy(name = "別のカフェ")
        val nameMatchedButFarther = makeCafe("name-matched").copy(name = "スターバックス コーヒー 渋谷店")
        fakeCafeRepo.searchByNameNearResult = listOf(nearestButDifferentName, nameMatchedButFarther)

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "スターバックス", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertEquals(nameMatchedButFarther, state.poiLookupResult)
        assertNull(state.poiLookupError)

        vm.clear()
    }

    @Test
    fun onPoiTapped_noNameMatch_fallsBackToNearest() = runTest {
        val nearest = makeCafe("nearest").copy(name = "全く違う店名のカフェ")
        val second = makeCafe("second").copy(name = "これも違う店名")
        fakeCafeRepo.searchByNameNearResult = listOf(nearest, second)

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "タップしたカフェ", latitude = 35.658, longitude = 139.701)
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertFalse(state.isLookingUpPoi)
        assertEquals(nearest, state.poiLookupResult)
        assertNull(state.poiLookupError)

        vm.clear()
    }

    @Test
    fun onPoiTapped_noNameMatch_picksNearestByDistance() = runTest {
        // 名前一致なし（Google 側の名称が Apple と異なるケースを模擬）→ タップ座標最近傍で決める。
        // リスト先頭は遠い店。距離で選ぶので 2 番目（近い店）が選ばれることを検証する（17-D の核心）。
        val far = makeCafe("far").copy(name = "遠い別店", latitude = 35.660, longitude = 139.660)
        val near = makeCafe("near").copy(name = "近い別店", latitude = 35.7003, longitude = 139.7003)
        fakeCafeRepo.searchByNameNearResult = listOf(far, near)

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "夢やカフェ", latitude = 35.700, longitude = 139.700)
        testScheduler.advanceUntilIdle()

        assertEquals(near, vm.state.value.poiLookupResult)

        vm.clear()
    }

    @Test
    fun onPoiTapped_sameNameChain_picksNearestByDistance() = runTest {
        // 同名チェーンが複数・距離違い → タップ座標に最も近いものを選ぶ。
        val farBranch = makeCafe("far-branch")
            .copy(name = "スターバックス コーヒー A店", latitude = 35.660, longitude = 139.660)
        val nearBranch = makeCafe("near-branch")
            .copy(name = "スターバックス コーヒー B店", latitude = 35.7002, longitude = 139.7002)
        fakeCafeRepo.searchByNameNearResult = listOf(farBranch, nearBranch)

        val vm = MapViewModel(
            observeVisitedCafesUseCase = useCase,
            cafeRecommendationProvider = fakeRecommendationProvider,
            cafeRepository = fakeCafeRepo,
            coffeeRepository = fakeCoffeeRepo,
            savedCafeRepository = fakeSavedCafeRepo,
            userId = "user-01",
            scope = this,
        )

        vm.onPoiTapped(name = "スターバックス", latitude = 35.700, longitude = 139.700)
        testScheduler.advanceUntilIdle()

        assertEquals(nearBranch, vm.state.value.poiLookupResult)

        vm.clear()
    }

    @Test
    fun onPoiTapped_retainsVisitedCafes() = runTest {
        fakeCafeRepo.searchByNameNearResult = listOf(makeCafe("poi-001"))

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

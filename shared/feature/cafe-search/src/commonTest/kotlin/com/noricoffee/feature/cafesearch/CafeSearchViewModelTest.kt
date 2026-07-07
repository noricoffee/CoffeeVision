package com.noricoffee.feature.cafesearch

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
import com.noricoffee.repository.CafeRepository
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [CafeSearchViewModel] の状態遷移テスト。
 *
 * ## 検証するシナリオ
 * - 初期状態で `hasSearched == false`
 * - `onQueryChanged` 後も `hasSearched == false`
 * - `onSearchTapped` 成功後（結果あり / 0 件いずれも）`hasSearched == true`
 * - `onSearchTapped` 失敗後 `hasSearched == false`
 * - `onSearchTapped` 成功後に `onQueryChanged` を呼ぶと `hasSearched` が false に戻る
 * - `onSearchTapped(lat, lng, radius)` が正しい [LocationBias] を渡すこと
 * - `onNearbySearchRequested` 成功後 `hasSearched == true`
 * - `onNearbySearchRequested` 失敗後 `hasSearched == false`
 * - `onNearbySearchRequested(lat, lng, radiusMeters)` が `radiusMeters` をそのまま `searchNearby` に渡すこと
 * - `onErrorDismissed` は `hasSearched` を変更しない
 * - `onSearchTapped` 成功時に `results` が反映される
 * - `onSearchTapped` 失敗時に `error` がセットされる
 * - `onErrorDismissed` で `error` が null に戻る
 *
 * ## スコープ管理
 * `CafeSearchViewModel` は `runTest` の `TestScope` を親にした独自 `viewModelScope` を作るため、
 * 各テストの最後に `vm.clear()` を呼ばないと `runTest` が `UncompletedCoroutinesError` を報告する。
 * テンプレート: `try { ... } finally { vm.clear() }` を各テストで使用する。
 */
class CafeSearchViewModelTest {

    // ─────────────────────────────────────────────────
    // Fakes
    // ─────────────────────────────────────────────────

    private class FakeCafeRepository : CafeRepository {

        var searchTextResult: List<Cafe> = emptyList()
        var searchTextError: Exception? = null

        var searchNearbyResult: List<Cafe> = emptyList()
        var searchNearbyError: Exception? = null

        /** バイアスあり版 searchText が最後に受け取った LocationBias を記録する。 */
        var lastLocationBias: LocationBias? = null

        /** searchNearby が最後に受け取った radiusMeters を記録する。 */
        var lastSearchNearbyRadiusMeters: Double? = null

        override suspend fun searchText(query: String): List<Cafe> {
            searchTextError?.let { throw it }
            return searchTextResult
        }

        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> {
            lastLocationBias = locationBias
            searchTextError?.let { throw it }
            return searchTextResult
        }

        override suspend fun searchByNameNear(query: String, locationBias: LocationBias): List<Cafe> {
            lastLocationBias = locationBias
            searchTextError?.let { throw it }
            return searchTextResult
        }

        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<Cafe> {
            lastSearchNearbyRadiusMeters = radiusMeters
            searchNearbyError?.let { throw it }
            return searchNearbyResult
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

    // ─────────────────────────────────────────────────
    // Tests — hasSearched の初期状態
    // ─────────────────────────────────────────────────

    @Test
    fun initialState_hasSearchedIsFalse() = runTest {
        val vm = CafeSearchViewModel(
            cafeRepository = FakeCafeRepository(),
            scope = this,
        )
        try {
            assertFalse(vm.state.value.hasSearched)
            assertEquals("", vm.state.value.query)
            assertTrue(vm.state.value.results.isEmpty())
            assertFalse(vm.state.value.isLoading)
            assertNull(vm.state.value.error)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — onQueryChanged
    // ─────────────────────────────────────────────────

    @Test
    fun onQueryChanged_updatesQuery_andHasSearchedRemainsfalse() = runTest {
        val vm = CafeSearchViewModel(
            cafeRepository = FakeCafeRepository(),
            scope = this,
        )
        try {
            vm.onQueryChanged("渋谷 コーヒー")

            assertEquals("渋谷 コーヒー", vm.state.value.query)
            assertFalse(vm.state.value.hasSearched)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onQueryChanged_afterSearchSuccess_resetsHasSearchedToFalse() = runTest {
        val fake = FakeCafeRepository()
        fake.searchTextResult = listOf(makeCafe())

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("初回クエリ")
            vm.onSearchTapped()
            testScheduler.advanceUntilIdle()

            assertTrue(vm.state.value.hasSearched, "前提: 検索成功後は hasSearched == true")

            vm.onQueryChanged("新しいクエリ")

            assertFalse(vm.state.value.hasSearched, "onQueryChanged 後は hasSearched == false に戻る")
            assertEquals("新しいクエリ", vm.state.value.query)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — onSearchTapped
    // ─────────────────────────────────────────────────

    @Test
    fun onSearchTapped_success_withResults_setsHasSearchedTrueAndReflectsResults() = runTest {
        val cafe = makeCafe()
        val fake = FakeCafeRepository()
        fake.searchTextResult = listOf(cafe)

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("渋谷")
            vm.onSearchTapped()
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertTrue(state.hasSearched)
            assertEquals(listOf(cafe), state.results)
            assertFalse(state.isLoading)
            assertNull(state.error)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchTapped_success_withEmptyResults_setsHasSearchedTrue() = runTest {
        val fake = FakeCafeRepository()
        fake.searchTextResult = emptyList()

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("存在しないカフェ")
            vm.onSearchTapped()
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertTrue(state.hasSearched)
            assertTrue(state.results.isEmpty())
            assertFalse(state.isLoading)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchTapped_failure_hasSearchedRemainsfalse() = runTest {
        val fake = FakeCafeRepository()
        fake.searchTextError = Exception("Network error")

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("エラーになるクエリ")
            vm.onSearchTapped()
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertFalse(state.hasSearched)
            assertFalse(state.isLoading)
            assertEquals("Network error", state.error)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — onSearchTapped(latitude, longitude, radiusMeters)
    // ─────────────────────────────────────────────────

    @Test
    fun onSearchTappedWithBias_success_passesCorrectLocationBiasAndReflectsResults() = runTest {
        val cafe = makeCafe()
        val fake = FakeCafeRepository()
        fake.searchTextResult = listOf(cafe)

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("渋谷 コーヒー")
            vm.onSearchTapped(latitude = 35.658, longitude = 139.701, radiusMeters = 500.0)
            testScheduler.advanceUntilIdle()

            // 正しい LocationBias が渡されていること
            val bias = fake.lastLocationBias
            assertNotNull(bias, "locationBias が searchText に渡されていること")
            assertEquals(35.658, bias.latitude)
            assertEquals(139.701, bias.longitude)
            assertEquals(500.0, bias.radiusMeters)

            val state = vm.state.value
            assertTrue(state.hasSearched)
            assertEquals(listOf(cafe), state.results)
            assertFalse(state.isLoading)
            assertNull(state.error)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchTappedWithBias_failure_hasSearchedRemainsfalse_andErrorIsSet() = runTest {
        val fake = FakeCafeRepository()
        fake.searchTextError = Exception("API error")

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("エラーになるクエリ")
            vm.onSearchTapped(latitude = 35.658, longitude = 139.701, radiusMeters = 500.0)
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertFalse(state.hasSearched)
            assertFalse(state.isLoading)
            assertEquals("API error", state.error)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — onNearbySearchRequested
    // ─────────────────────────────────────────────────

    @Test
    fun onNearbySearchRequested_success_setsHasSearchedTrue() = runTest {
        val cafe = makeCafe()
        val fake = FakeCafeRepository()
        fake.searchNearbyResult = listOf(cafe)

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onNearbySearchRequested(latitude = 35.658, longitude = 139.701)
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertTrue(state.hasSearched)
            assertEquals(listOf(cafe), state.results)
            assertFalse(state.isLoading)
            assertNull(state.error)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onNearbySearchRequested_success_withEmptyResults_setsHasSearchedTrue() = runTest {
        val fake = FakeCafeRepository()
        fake.searchNearbyResult = emptyList()

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onNearbySearchRequested(latitude = 35.658, longitude = 139.701)
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertTrue(state.hasSearched)
            assertTrue(state.results.isEmpty())
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onNearbySearchRequested_failure_hasSearchedRemainsfalse() = runTest {
        val fake = FakeCafeRepository()
        fake.searchNearbyError = Exception("Location error")

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onNearbySearchRequested(latitude = 35.658, longitude = 139.701)
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertFalse(state.hasSearched)
            assertFalse(state.isLoading)
            assertEquals("Location error", state.error)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — onNearbySearchRequested(latitude, longitude, radiusMeters)
    // ─────────────────────────────────────────────────

    @Test
    fun onNearbySearchRequestedWithRadius_success_passesRadiusAndReflectsResults() = runTest {
        val cafe = makeCafe()
        val fake = FakeCafeRepository()
        fake.searchNearbyResult = listOf(cafe)

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onNearbySearchRequested(latitude = 35.658, longitude = 139.701, radiusMeters = 1500.0)
            testScheduler.advanceUntilIdle()

            // radiusMeters がそのまま searchNearby に伝播していること
            assertEquals(1500.0, fake.lastSearchNearbyRadiusMeters)

            val state = vm.state.value
            assertTrue(state.hasSearched)
            assertEquals(listOf(cafe), state.results)
            assertFalse(state.isLoading)
            assertNull(state.error)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onNearbySearchRequestedWithRadius_success_withEmptyResults_setsHasSearchedTrue() = runTest {
        val fake = FakeCafeRepository()
        fake.searchNearbyResult = emptyList()

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onNearbySearchRequested(latitude = 35.658, longitude = 139.701, radiusMeters = 800.0)
            testScheduler.advanceUntilIdle()

            assertEquals(800.0, fake.lastSearchNearbyRadiusMeters)

            val state = vm.state.value
            assertTrue(state.hasSearched)
            assertTrue(state.results.isEmpty())
            assertFalse(state.isLoading)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onNearbySearchRequestedWithRadius_failure_hasSearchedRemainsfalse() = runTest {
        val fake = FakeCafeRepository()
        fake.searchNearbyError = Exception("Location error")

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onNearbySearchRequested(latitude = 35.658, longitude = 139.701, radiusMeters = 2000.0)
            testScheduler.advanceUntilIdle()

            val state = vm.state.value
            assertFalse(state.hasSearched)
            assertFalse(state.isLoading)
            assertEquals("Location error", state.error)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — onErrorDismissed
    // ─────────────────────────────────────────────────

    @Test
    fun onErrorDismissed_clearsError_doesNotChangeHasSearched() = runTest {
        val fake = FakeCafeRepository()
        fake.searchTextError = Exception("Search failed")

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("クエリ")
            vm.onSearchTapped()
            testScheduler.advanceUntilIdle()

            assertNotNull(vm.state.value.error)
            assertFalse(vm.state.value.hasSearched, "前提: 失敗後は hasSearched == false")

            vm.onErrorDismissed()

            assertNull(vm.state.value.error)
            // hasSearched は onErrorDismissed では変化しない（false のまま）
            assertFalse(vm.state.value.hasSearched)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onErrorDismissed_afterSuccess_doesNotChangeHasSearched() = runTest {
        // 成功して hasSearched == true の状態でエラーが発生 → dismiss しても hasSearched は true のまま
        val fake = FakeCafeRepository()
        fake.searchTextResult = listOf(makeCafe())

        val vm = CafeSearchViewModel(
            cafeRepository = fake,
            scope = this,
        )
        try {
            vm.onQueryChanged("渋谷")
            vm.onSearchTapped()
            testScheduler.advanceUntilIdle()
            assertTrue(vm.state.value.hasSearched, "前提: 検索成功後は hasSearched == true")

            vm.onErrorDismissed()

            assertTrue(vm.state.value.hasSearched, "onErrorDismissed は hasSearched を変えない")
            assertNull(vm.state.value.error)
        } finally {
            vm.clear()
        }
    }
}

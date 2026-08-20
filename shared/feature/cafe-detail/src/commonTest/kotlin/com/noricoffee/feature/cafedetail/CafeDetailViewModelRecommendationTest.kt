package com.noricoffee.feature.cafedetail

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.LocationBias
import com.noricoffee.domain.model.CafeRecommendationProvider
import com.noricoffee.domain.model.PreferenceMatchAxis
import com.noricoffee.domain.model.RecommendationReason
import com.noricoffee.domain.model.RecommendedCafe
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.repository.CafeRepository
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [CafeDetailViewModel] の好み一致推薦理由（[CafeDetailViewModel.UIState.matches]）の状態遷移テスト。
 *
 * マップの好み一致ピンと同じ推薦ソース（[CafeRecommendationProvider]）をカフェ詳細に移設した機能の検証。
 *
 * ## 検証ケース
 * (a) 対象 [placeId] が推薦リストに含まれる → [CafeDetailViewModel.UIState.matches] に反映される
 * (b) 対象 [placeId] が推薦リストに含まれない → 空リストのまま
 * (c) provider が空リストを流す → 空リストのまま
 */
class CafeDetailViewModelRecommendationTest {

    private class FakeCoffeeRepository : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    private class FakeCafeRepository(
        private val detailsResult: Cafe = makeCafe(),
    ) : CafeRepository {
        override suspend fun searchText(query: String): List<Cafe> = emptyList()
        override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> = emptyList()

        override suspend fun searchByNameNear(query: String, locationBias: LocationBias): List<Cafe> = emptyList()
        override suspend fun searchNearby(
            latitude: Double,
            longitude: Double,
            radiusMeters: Double,
        ): List<Cafe> = emptyList()

        override suspend fun getDetails(placeId: String): Cafe = detailsResult
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

    private class FakeCafeRecommendationProvider(
        initial: List<RecommendedCafe> = emptyList(),
    ) : CafeRecommendationProvider {
        val recommendedFlow = MutableStateFlow(initial)
        override fun observeRecommendedCafes(userId: String): Flow<List<RecommendedCafe>> = recommendedFlow
    }

    private companion object {
        const val USER_ID = "user-01"
        const val PLACE_ID = "place-1"
        const val OTHER_PLACE_ID = "place-2"

        fun makeCafe(placeId: String = PLACE_ID): Cafe = Cafe(
            placeId = placeId,
            name = "Test Cafe",
            address = null,
            latitude = 35.0,
            longitude = 139.0,
            photoReferences = emptyList(),
            websiteUrl = null,
            mapsUrl = null,
        )

        fun makeMatch(): RecommendationReason.TasteProfileMatch = RecommendationReason.TasteProfileMatch(
            axis = PreferenceMatchAxis.Origin,
            matchedLabel = "Ethiopia",
            exampleRecordName = "エチオピア イルガチェフェ",
            exampleRating = 4.5,
        )
    }

    // -----------------------------------------------------------------------
    // (a) 対象 placeId が推薦リストに含まれる → matches に反映される
    // -----------------------------------------------------------------------

    @Test
    fun matchingPlaceId_reflectsMatchesInState() = runTest {
        val match = makeMatch()
        val recommended = RecommendedCafe(cafe = makeCafe(PLACE_ID), matches = listOf(match))
        val fakeProvider = FakeCafeRecommendationProvider(initial = listOf(recommended))

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = FakeCafeRepository(),
            savedCafeRepository = FakeSavedCafeRepository(),
            cafeRecommendationProvider = fakeProvider,
            placeId = PLACE_ID,
            initialCafe = makeCafe(PLACE_ID),
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertEquals(listOf(match), vm.state.value.matches)

        vm.clear()
    }

    // -----------------------------------------------------------------------
    // (b) 対象 placeId が推薦リストに含まれない → 空リストのまま
    // -----------------------------------------------------------------------

    @Test
    fun nonMatchingPlaceId_keepsMatchesEmpty() = runTest {
        val recommended = RecommendedCafe(cafe = makeCafe(OTHER_PLACE_ID), matches = listOf(makeMatch()))
        val fakeProvider = FakeCafeRecommendationProvider(initial = listOf(recommended))

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = FakeCafeRepository(),
            savedCafeRepository = FakeSavedCafeRepository(),
            cafeRecommendationProvider = fakeProvider,
            placeId = PLACE_ID,
            initialCafe = makeCafe(PLACE_ID),
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertTrue(vm.state.value.matches.isEmpty())

        vm.clear()
    }

    // -----------------------------------------------------------------------
    // (c) provider が空リストを流す → 空リストのまま
    // -----------------------------------------------------------------------

    @Test
    fun emptyRecommendations_keepsMatchesEmpty() = runTest {
        val fakeProvider = FakeCafeRecommendationProvider(initial = emptyList())

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            cafeRepository = FakeCafeRepository(),
            savedCafeRepository = FakeSavedCafeRepository(),
            cafeRecommendationProvider = fakeProvider,
            placeId = PLACE_ID,
            initialCafe = makeCafe(PLACE_ID),
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertTrue(vm.state.value.matches.isEmpty())

        vm.clear()
    }
}

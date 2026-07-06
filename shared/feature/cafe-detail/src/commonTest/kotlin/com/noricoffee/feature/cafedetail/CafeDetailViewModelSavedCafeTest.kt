package com.noricoffee.feature.cafedetail

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.model.SavedCafe
import com.noricoffee.repository.CoffeeRepository
import com.noricoffee.repository.SavedCafeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * [CafeDetailViewModel] の「行きたい店」ブックマーク機能（フェーズ 15-A）の状態遷移テスト。
 *
 * ## scope と vm.clear() の注意
 * [MapViewModel][com.noricoffee.feature.map.MapViewModel] と同じ理由で、各テスト末尾で
 * `vm.clear()` を呼び viewModelScope をキャンセルする。
 */
class CafeDetailViewModelSavedCafeTest {

    private class FakeCoffeeRepository : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    private class FakeSavedCafeRepository(
        initial: SavedCafe? = null,
    ) : SavedCafeRepository {
        val byPlaceIdFlow = MutableStateFlow(initial)
        val saved = mutableListOf<SavedCafe>()
        val deleted = mutableListOf<Pair<String, String>>()
        var failSave = false
        var failDelete = false

        override fun observeAll(userId: String): Flow<List<SavedCafe>> =
            flowOf(byPlaceIdFlow.value?.let { listOf(it) } ?: emptyList())

        override fun observeByPlaceId(userId: String, placeId: String): Flow<SavedCafe?> = byPlaceIdFlow

        override suspend fun save(savedCafe: SavedCafe) {
            if (failSave) throw RuntimeException("save failed")
            saved.add(savedCafe)
            byPlaceIdFlow.value = savedCafe
        }

        override suspend fun delete(userId: String, placeId: String) {
            if (failDelete) throw RuntimeException("delete failed")
            deleted.add(userId to placeId)
            byPlaceIdFlow.value = null
        }
    }

    private companion object {
        const val USER_ID = "user-01"
        const val PLACE_ID = "place-1"

        fun makeCafe(): Cafe = Cafe(
            placeId = PLACE_ID,
            name = "Test Cafe",
            address = null,
            latitude = 35.0,
            longitude = 139.0,
            photoReferences = emptyList(),
            websiteUrl = null,
            mapsUrl = null,
        )
    }

    @Test
    fun isSaved_reflects_repository_subscription() = runTest {
        val savedCafe = SavedCafe(
            userId = USER_ID,
            cafe = makeCafe(),
            note = "",
            savedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
        val fakeSavedCafeRepo = FakeSavedCafeRepository(initial = savedCafe)

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            savedCafeRepository = fakeSavedCafeRepo,
            placeId = PLACE_ID,
            initialCafe = makeCafe(),
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        assertTrue(vm.state.value.isSaved)

        vm.clear()
    }

    @Test
    fun onSaveToggled_saves_when_not_saved() = runTest {
        val fakeSavedCafeRepo = FakeSavedCafeRepository(initial = null)

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            savedCafeRepository = fakeSavedCafeRepo,
            placeId = PLACE_ID,
            initialCafe = makeCafe(),
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()
        assertFalse(vm.state.value.isSaved)

        vm.onSaveToggled()
        testScheduler.advanceUntilIdle()

        assertEquals(1, fakeSavedCafeRepo.saved.size)
        assertEquals(PLACE_ID, fakeSavedCafeRepo.saved.first().cafe.placeId)
        assertEquals("", fakeSavedCafeRepo.saved.first().note)
        assertTrue(vm.state.value.isSaved)

        vm.clear()
    }

    @Test
    fun onSaveToggled_deletes_when_already_saved() = runTest {
        val savedCafe = SavedCafe(
            userId = USER_ID,
            cafe = makeCafe(),
            note = "",
            savedAt = Instant.fromEpochMilliseconds(1_750_000_000_000),
        )
        val fakeSavedCafeRepo = FakeSavedCafeRepository(initial = savedCafe)

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            savedCafeRepository = fakeSavedCafeRepo,
            placeId = PLACE_ID,
            initialCafe = makeCafe(),
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()
        assertTrue(vm.state.value.isSaved)

        vm.onSaveToggled()
        testScheduler.advanceUntilIdle()

        assertEquals(listOf(USER_ID to PLACE_ID), fakeSavedCafeRepo.deleted)
        assertFalse(vm.state.value.isSaved)

        vm.clear()
    }

    @Test
    fun onSaveToggled_save_failure_sets_error() = runTest {
        val fakeSavedCafeRepo = FakeSavedCafeRepository(initial = null)
        fakeSavedCafeRepo.failSave = true

        val vm = CafeDetailViewModel(
            coffeeRepository = FakeCoffeeRepository(),
            savedCafeRepository = fakeSavedCafeRepo,
            placeId = PLACE_ID,
            initialCafe = makeCafe(),
            userId = USER_ID,
            scope = this,
        )
        testScheduler.advanceUntilIdle()

        vm.onSaveToggled()
        testScheduler.advanceUntilIdle()

        assertNotNull(vm.state.value.error)
        assertFalse(vm.state.value.isSaved)

        vm.onErrorDismissed()
        assertEquals(null, vm.state.value.error)

        vm.clear()
    }
}

package com.noricoffee.feature.coffeedetail

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [CoffeeDetailViewModel] の削除フロー（[CoffeeDetailViewModel.onDeleteTapped]）と
 * 購読（[CoffeeDetailViewModel.onAppear]）のテスト。
 *
 * ## スコープ管理
 * [CoffeeDetailViewModel] は `runTest` の `TestScope` を親にした独自 `viewModelScope` を作るため、
 * 各テストの最後に `vm.clear()` を呼ばないと `runTest` が `UncompletedCoroutinesError` を報告する。
 */
class CoffeeDetailViewModelTest {

    // ─────────────────────────────────────────────────
    // Fakes
    // ─────────────────────────────────────────────────

    private class FakeCoffeeRepository(
        private val byId: CoffeeRecord? = null,
        private val deleteError: Throwable? = null,
    ) : CoffeeRepository {

        val deletedCalls = mutableListOf<Pair<String, String>>()
        private val byIdFlow = MutableStateFlow(byId)

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())

        override fun observeById(id: String): Flow<CoffeeRecord?> = byIdFlow

        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
            flowOf(emptyList())

        override suspend fun save(record: CoffeeRecord) = Unit

        override suspend fun delete(userId: String, id: String) {
            deleteError?.let { throw it }
            deletedCalls += userId to id
        }
    }

    // ─────────────────────────────────────────────────
    // Fixtures
    // ─────────────────────────────────────────────────

    private fun sampleRecord(id: String = "coffee-1"): CoffeeRecord = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = null,
        visitedOn = LocalDate(2026, 1, 1),
        rating = 4.0,
        notes = "",
        photos = emptyList(),
        name = "コーヒー",
        brewMethod = BrewMethod.HandDrip,
        origin = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        brewRecipe = null,
        tasting = null,
        tags = emptyList(),
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    // ─────────────────────────────────────────────────
    // Tests — 削除
    // ─────────────────────────────────────────────────

    @Test
    fun onDeleteTapped_callsRepositoryAndSetsIsDeleted() = runTest {
        val repository = FakeCoffeeRepository(byId = sampleRecord())
        val vm = CoffeeDetailViewModel(repository, scope = this)
        try {
            vm.onAppear(coffeeId = "coffee-1", userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onDeleteTapped()
            testScheduler.advanceUntilIdle()

            assertEquals(listOf("user-1" to "coffee-1"), repository.deletedCalls)
            assertTrue(vm.state.value.isDeleted)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onDeleteTapped_beforeOnAppear_isNoOp() = runTest {
        val repository = FakeCoffeeRepository(byId = sampleRecord())
        val vm = CoffeeDetailViewModel(repository, scope = this)
        try {
            vm.onDeleteTapped()
            testScheduler.advanceUntilIdle()

            assertTrue(repository.deletedCalls.isEmpty())
            assertFalse(vm.state.value.isDeleted)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onDeleteTapped_repositoryThrows_setsErrorAndNotDeleted() = runTest {
        val repository = FakeCoffeeRepository(
            byId = sampleRecord(),
            deleteError = RuntimeException("network error"),
        )
        val vm = CoffeeDetailViewModel(repository, scope = this)
        try {
            vm.onAppear(coffeeId = "coffee-1", userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onDeleteTapped()
            testScheduler.advanceUntilIdle()

            assertEquals("network error", vm.state.value.error)
            assertFalse(vm.state.value.isDeleted)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — 購読（回帰固定）
    // ─────────────────────────────────────────────────

    @Test
    fun onAppear_observesByIdAndUpdatesCoffee() = runTest {
        val record = sampleRecord()
        val repository = FakeCoffeeRepository(byId = record)
        val vm = CoffeeDetailViewModel(repository, scope = this)
        try {
            vm.onAppear(coffeeId = "coffee-1", userId = "user-1")
            testScheduler.advanceUntilIdle()

            assertEquals(record, vm.state.value.coffee)
            assertFalse(vm.state.value.isLoading)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onAppear_nullRecord_flowsNullCoffee() = runTest {
        val repository = FakeCoffeeRepository(byId = null)
        val vm = CoffeeDetailViewModel(repository, scope = this)
        try {
            vm.onAppear(coffeeId = "coffee-1", userId = "user-1")
            testScheduler.advanceUntilIdle()

            assertNull(vm.state.value.coffee)
        } finally {
            vm.clear()
        }
    }
}

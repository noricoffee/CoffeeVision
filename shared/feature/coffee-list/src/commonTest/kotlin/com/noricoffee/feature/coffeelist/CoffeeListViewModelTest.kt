package com.noricoffee.feature.coffeelist

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.Cafe
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [CoffeeListViewModel] の検索フィルタ（要件 6-1）・月別グルーピング（要件 2-11）のテスト。
 *
 * ## スコープ管理
 * [CoffeeListViewModel] は `runTest` の `TestScope` を親にした独自 `viewModelScope` を作るため、
 * 各テストの最後に `vm.clear()` を呼ばないと `runTest` が `UncompletedCoroutinesError` を報告する。
 */
class CoffeeListViewModelTest {

    // ─────────────────────────────────────────────────
    // Fakes
    // ─────────────────────────────────────────────────

    private class FakeCoffeeRepository(
        private val records: List<CoffeeRecord> = emptyList(),
    ) : CoffeeRepository {

        val deletedIds = mutableListOf<String>()

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(records)

        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)

        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
            flowOf(emptyList())

        override suspend fun save(record: CoffeeRecord) = Unit

        override suspend fun delete(userId: String, id: String) {
            deletedIds += id
        }
    }

    // ─────────────────────────────────────────────────
    // Fixtures
    // ─────────────────────────────────────────────────

    private fun sampleCafe(name: String) = Cafe(
        placeId = "place-$name",
        name = name,
        address = null,
        latitude = null,
        longitude = null,
        photoReferences = emptyList(),
        websiteUrl = null,
        mapsUrl = null,
    )

    private fun sampleRecord(
        id: String,
        name: String = "コーヒー",
        cafe: Cafe? = null,
        notes: String = "",
        visitedOn: LocalDate = LocalDate(2026, 1, 1),
        createdAt: Instant = Instant.fromEpochMilliseconds(0),
    ): CoffeeRecord = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = cafe,
        visitedOn = visitedOn,
        rating = 4.0,
        notes = notes,
        photos = emptyList(),
        name = name,
        brewMethod = BrewMethod.HandDrip,
        origin = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        tasting = null,
        tags = emptyList(),
        createdAt = createdAt,
        updatedAt = createdAt,
    )

    // ─────────────────────────────────────────────────
    // Tests — 検索フィルタ（要件 6-1）
    // ─────────────────────────────────────────────────

    @Test
    fun onSearchQueryChanged_matchesByName() = runTest {
        val target = sampleRecord(id = "1", name = "エチオピア イルガチェフェ")
        val other = sampleRecord(id = "2", name = "ブラジル サントス")
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(target, other)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onSearchQueryChanged("イルガチェフェ")

            val ids = vm.state.value.sections.flatMap { it.records }.map { it.id }
            assertEquals(listOf("1"), ids)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchQueryChanged_matchesByCafeName() = runTest {
        val target = sampleRecord(id = "1", cafe = sampleCafe("ブルーボトルコーヒー"))
        val other = sampleRecord(id = "2", cafe = sampleCafe("スターバックス"))
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(target, other)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onSearchQueryChanged("ブルーボトル")

            val ids = vm.state.value.sections.flatMap { it.records }.map { it.id }
            assertEquals(listOf("1"), ids)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchQueryChanged_matchesByNotes() = runTest {
        val target = sampleRecord(id = "1", notes = "とても美味しかった")
        val other = sampleRecord(id = "2", notes = "普通だった")
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(target, other)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onSearchQueryChanged("美味し")

            val ids = vm.state.value.sections.flatMap { it.records }.map { it.id }
            assertEquals(listOf("1"), ids)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchQueryChanged_isCaseInsensitive() = runTest {
        val target = sampleRecord(id = "1", name = "Ethiopia Yirgacheffe")
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(target)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onSearchQueryChanged("YIRGACHEFFE")

            val ids = vm.state.value.sections.flatMap { it.records }.map { it.id }
            assertEquals(listOf("1"), ids)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchQueryChanged_blankQuery_returnsAllRecords() = runTest {
        val a = sampleRecord(id = "1")
        val b = sampleRecord(id = "2")
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(a, b)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onSearchQueryChanged("  ")

            val ids = vm.state.value.sections.flatMap { it.records }.map { it.id }
            assertEquals(listOf("1", "2"), ids)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchQueryChanged_noMatch_returnsEmptySections() = runTest {
        val a = sampleRecord(id = "1", name = "エチオピア")
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(a)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onSearchQueryChanged("該当なしクエリ")

            assertTrue(vm.state.value.sections.isEmpty())
            assertEquals("該当なしクエリ", vm.state.value.searchQuery)
        } finally {
            vm.clear()
        }
    }

    // ─────────────────────────────────────────────────
    // Tests — 月別グルーピング（要件 2-11）
    // ─────────────────────────────────────────────────

    @Test
    fun onAppear_groupsRecordsByYearMonthDescending() = runTest {
        // observeAll の順序は visited_on DESC, created_at DESC を前提とする
        val julyNew = sampleRecord(id = "july-new", visitedOn = LocalDate(2026, 7, 20))
        val julyOld = sampleRecord(id = "july-old", visitedOn = LocalDate(2026, 7, 5))
        val june = sampleRecord(id = "june", visitedOn = LocalDate(2026, 6, 15))
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(julyNew, julyOld, june)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            val sections = vm.state.value.sections
            assertEquals(listOf("2026-07", "2026-06"), sections.map { it.yearMonth })
            assertEquals(listOf("july-new", "july-old"), sections[0].records.map { it.id })
            assertEquals(listOf("june"), sections[1].records.map { it.id })
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onAppear_zeroPadsSingleDigitMonth() = runTest {
        val record = sampleRecord(id = "1", visitedOn = LocalDate(2026, 3, 1))
        val vm = CoffeeListViewModel(FakeCoffeeRepository(listOf(record)), scope = this)
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            assertEquals("2026-03", vm.state.value.sections.single().yearMonth)
        } finally {
            vm.clear()
        }
    }

    @Test
    fun onSearchQueryChanged_appliesFilterBeforeGrouping() = runTest {
        val julyMatch = sampleRecord(id = "july-match", name = "抹茶ラテ", visitedOn = LocalDate(2026, 7, 1))
        val julyNoMatch = sampleRecord(id = "july-no-match", name = "エスプレッソ", visitedOn = LocalDate(2026, 7, 2))
        val juneMatch = sampleRecord(id = "june-match", name = "抹茶フラペチーノ", visitedOn = LocalDate(2026, 6, 1))
        val vm = CoffeeListViewModel(
            FakeCoffeeRepository(listOf(julyMatch, julyNoMatch, juneMatch)),
            scope = this,
        )
        try {
            vm.onAppear(userId = "user-1")
            testScheduler.advanceUntilIdle()

            vm.onSearchQueryChanged("抹茶")

            val sections = vm.state.value.sections
            assertEquals(listOf("2026-07", "2026-06"), sections.map { it.yearMonth })
            assertEquals(listOf("july-match"), sections[0].records.map { it.id })
            assertEquals(listOf("june-match"), sections[1].records.map { it.id })
        } finally {
            vm.clear()
        }
    }
}

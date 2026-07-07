package com.noricoffee.feature.analysis

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import com.noricoffee.domain.model.FavoriteSignals
import com.noricoffee.domain.usecase.BuildCoffeeStatsUseCase
import com.noricoffee.domain.usecase.ObserveCoffeeStatsUseCase
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
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
 * [AnalysisViewModel.UIState.readiness]（要件 9-7 / 分析タブの空状態プログレス）のユニットテスト。
 *
 * [AnalysisViewModel.AnalysisReadiness] は [AnalysisViewModel.UIState.stats] からの純粋な派生値のため、
 * 実際の [BuildCoffeeStatsUseCase] を通した [CoffeeStats][com.noricoffee.domain.model.CoffeeStats] を
 * 使って導出結果を検証する（fake で `favoriteSignals` を直接作らない）。
 *
 * ## scope と vm.clear() の注意（iOS/Native 対応）
 *
 * [AnalysisViewModel.onAppear] は viewModelScope 上で統計を購読し続けるため、各テストの最後に
 * `vm.clear()`（= `viewModelScope.cancel()`）を呼ぶ。さらに **Kotlin/Native（iosSimulatorArm64）では
 * `vm.clear()` 直後に `testScheduler.advanceUntilIdle()` を呼んでキャンセルを drain する**こと。
 * これが無いと、`cancel()` はスケジュールされるだけで runTest の完了チェック前に処理されず、
 * SupervisorJob が Active のまま残って `UncompletedCoroutinesError`（60s 待ち）になる（JVM では顕在化しない）。
 * （[AnalysisViewModelQaTest] と同じ注意点）
 */
class AnalysisViewModelReadinessTest {

    // --- Fakes ---

    private class FakeCoffeeRepository(
        private val records: List<CoffeeRecord>,
    ) : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(records)
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    // --- ヘルパ ---

    private fun record(
        id: String,
        rating: Double = 4.0,
        brewMethod: BrewMethod = BrewMethod.HandDrip,
        tasting: TastingScores? = null,
    ) = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = null,
        visitedOn = LocalDate(2026, 6, 1),
        rating = rating,
        notes = "",
        photos = emptyList(),
        name = "Test Coffee $id",
        brewMethod = brewMethod,
        origin = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        brewRecipe = null,
        tasting = tasting,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    private fun makeViewModel(records: List<CoffeeRecord>, scope: kotlinx.coroutines.CoroutineScope) =
        AnalysisViewModel(
            observeCoffeeStatsUseCase = ObserveCoffeeStatsUseCase(FakeCoffeeRepository(records)),
            insightProvider = null,
            userId = "user-1",
            scope = scope,
        )

    // --- テスト ---

    @Test
    fun onAppear_withNoRecords_readinessReflectsEmptyState() = runTest {
        val vm = makeViewModel(emptyList(), this)
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            val readiness = vm.state.value.readiness
            assertEquals(0, readiness?.ratedCount)
            assertEquals(0, readiness?.tastedCount)
            assertFalse(readiness?.hasAnySignal ?: true)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }

    @Test
    fun onAppear_beforeStatsEmitted_readinessIsNull() = runTest {
        // observeAll が emit しない Repository（stats 未確定を模擬）
        val repo = object : CoffeeRepository {
            override fun observeAll(userId: String): Flow<List<CoffeeRecord>> =
                kotlinx.coroutines.flow.flow { /* emit しない */ }
            override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
            override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
            override suspend fun save(record: CoffeeRecord) = Unit
            override suspend fun delete(userId: String, id: String) = Unit
        }
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = ObserveCoffeeStatsUseCase(repo),
            insightProvider = null,
            userId = "user-1",
            scope = this,
        )
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            assertNull(vm.state.value.readiness)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }

    @Test
    fun onAppear_withRatedRecords_ratedCountReflectsStats() = runTest {
        val records = listOf(
            record("r-1", rating = 4.0),
            record("r-2", rating = 3.5),
            record("r-3", rating = 0.0), // 未評価 sentinel。ratedCount には数えない
        )
        val vm = makeViewModel(records, this)
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            val stats = vm.state.value.stats
            val readiness = vm.state.value.readiness
            assertEquals(stats?.ratedCount, readiness?.ratedCount)
            assertEquals(2, readiness?.ratedCount)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }

    @Test
    fun onAppear_withTastingRecords_tastedCountReflectsTastingAverages() = runTest {
        val tasting = TastingScores(sweetness = 5, body = 5, acidity = 5, flavor = 5, aftertaste = 5)
        val records = listOf(
            record("r-1", tasting = tasting),
            record("r-2", tasting = tasting),
            record("r-3", tasting = null),
        )
        val vm = makeViewModel(records, this)
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            val stats = vm.state.value.stats
            val readiness = vm.state.value.readiness
            assertEquals(stats?.tastingAverages?.ratedCount, readiness?.tastedCount)
            assertEquals(2, readiness?.tastedCount)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }

    @Test
    fun onAppear_thresholds_matchDomainConstants() = runTest {
        val vm = makeViewModel(emptyList(), this)
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            val readiness = vm.state.value.readiness
            assertEquals(FavoriteSignals().minSampleSize, readiness?.categoryThreshold)
            assertEquals(BuildCoffeeStatsUseCase.CORRELATION_MIN_SAMPLE, readiness?.correlationThreshold)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }

    @Test
    fun onAppear_whenFavoriteSignalPresent_hasAnySignalIsTrue() = runTest {
        // BuildCoffeeStatsUseCaseTest.favoriteSignals_bestBrewMethod_highVolumeHighRated_isSelected と同じ設計:
        // HandDrip(n=10, mean=4.5) が z ゲート + δ 下限を満たして bestBrewMethod として採用される
        val records = (1..10).map { i -> record("r-hd-$i", rating = 4.5, brewMethod = BrewMethod.HandDrip) } +
            (1..10).map { i -> record("r-esp-$i", rating = 3.0, brewMethod = BrewMethod.Espresso) }
        val vm = makeViewModel(records, this)
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            val stats = vm.state.value.stats
            assertEquals("HandDrip", stats?.favoriteSignals?.bestBrewMethod?.label)
            assertTrue(vm.state.value.readiness?.hasAnySignal ?: false)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }
}

package com.noricoffee.feature.analysis

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.model.CoffeeInsight
import com.noricoffee.domain.model.CoffeeInsightProvider
import com.noricoffee.domain.model.CoffeeStats
import com.noricoffee.domain.model.PreferredBeanTraits
import com.noricoffee.domain.usecase.ObserveCoffeeStatsUseCase
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals

/**
 * 分析タブの「あなたの傾向」（Foundation Models 要約）が不要に再生成されないことを検証するテスト
 * （2026-07-16 起票: タブ再表示のたびに要約が再計算される不具合の修正）。
 *
 * - [AnalysisViewModel.onAppear] を複数回呼んでも [observeJob][AnalysisViewModel] が
 *   active な間は再購読しない（= [CoffeeInsightProvider.summarize] は初回購読分の 1 回のみ）
 * - 統計 Flow が同値の [CoffeeStats] を再 emit しても要約は再生成しない
 * - 統計 Flow が異なる [CoffeeStats] を emit した場合は従来どおり要約を再生成する
 *
 * ## scope と vm.clear() の注意
 *
 * [AnalysisViewModel.onAppear] は viewModelScope 上で無期限に統計を購読し続けるため、
 * 各テストの最後に `vm.clear()` を呼ばないと `runTest` が `UncompletedCoroutinesError` を報告する。
 * テンプレート: `try { ... } finally { vm.clear() }` を各テストで使用する。
 */
class AnalysisViewModelInsightRegenerationTest {

    // --- Fakes ---

    /**
     * [CoffeeRepository] の fake。[emissions] に指定した順で records リストを emit する。
     * 同一内容のリストを複数回渡すことで「同値 stats の再 emit」を模擬できる。
     *
     * [delayBetweenEmissionsMillis] > 0 の場合、各 emit の間に suspend する。
     * これにより先行の要約生成 Job（[AnalysisViewModel.insightJob]）が完了してから
     * 次の stats を emit できる（テストスケジューラの仮想時間を進めれば Job が完了する）。
     */
    private class FakeCoffeeRepository(
        private val emissions: List<List<CoffeeRecord>>,
        private val delayBetweenEmissionsMillis: Long = 0,
    ) : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flow {
            emissions.forEachIndexed { index, records ->
                if (index > 0 && delayBetweenEmissionsMillis > 0) {
                    delay(delayBetweenEmissionsMillis)
                }
                emit(records)
            }
        }
        override fun observeById(id: String): Flow<CoffeeRecord?> = kotlinx.coroutines.flow.flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> =
            kotlinx.coroutines.flow.flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    /** [CoffeeInsightProvider.summarize] の呼び出し回数を数える fake。 */
    private class CountingCoffeeInsightProvider : CoffeeInsightProvider {
        var summarizeCallCount: Int = 0
            private set

        override suspend fun summarize(stats: CoffeeStats): CoffeeInsight {
            summarizeCallCount++
            return CoffeeInsight(headline = "テスト見出し", body = "テスト本文")
        }

        override suspend fun answer(question: String, stats: CoffeeStats): String = "テスト回答"

        override suspend fun summarizeBeanTraits(traits: PreferredBeanTraits): CoffeeInsight? = null
    }

    // --- ヘルパ ---

    private fun record(
        id: String,
        rating: Double? = 4.0,
    ) = CoffeeRecord(
        id = id,
        userId = "user-1",
        cafe = null,
        visitedOn = LocalDate(2026, 6, 1),
        rating = rating,
        notes = "",
        photos = emptyList(),
        name = "Test Coffee $id",
        brewMethod = BrewMethod.HandDrip,
        origin = null,
        variety = null,
        processing = null,
        roastLevel = null,
        cup = null,
        brewRecipe = null,
        tasting = null,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    // --- テスト ---

    @Test
    fun onAppear_calledTwice_doesNotRegenerateInsight() = runTest {
        val provider = CountingCoffeeInsightProvider()
        val records = listOf(record("r-1"))
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = ObserveCoffeeStatsUseCase(FakeCoffeeRepository(listOf(records))),
            insightProvider = provider,
            userId = "user-1",
            scope = this,
        )
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()
            assertEquals(1, provider.summarizeCallCount)

            // タブ再表示を模擬（購読中なので再購読しないはず）
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            assertEquals(1, provider.summarizeCallCount)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }

    @Test
    fun statsFlow_reEmitsSameValue_doesNotRegenerateInsight() = runTest {
        val provider = CountingCoffeeInsightProvider()
        val records = listOf(record("r-1"))
        // 同一内容の records を 2 回 emit -> CoffeeStats は data class として等価になるはず
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = ObserveCoffeeStatsUseCase(
                FakeCoffeeRepository(listOf(records, records)),
            ),
            insightProvider = provider,
            userId = "user-1",
            scope = this,
        )
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            assertEquals(1, provider.summarizeCallCount)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }

    @Test
    fun statsFlow_emitsChangedValue_regeneratesInsight() = runTest {
        val provider = CountingCoffeeInsightProvider()
        val firstRecords = listOf(record("r-1"))
        val secondRecords = listOf(record("r-1"), record("r-2"))
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = ObserveCoffeeStatsUseCase(
                FakeCoffeeRepository(listOf(firstRecords, secondRecords), delayBetweenEmissionsMillis = 1),
            ),
            insightProvider = provider,
            userId = "user-1",
            scope = this,
        )
        try {
            vm.onAppear()
            testScheduler.advanceUntilIdle()

            assertEquals(2, provider.summarizeCallCount)
        } finally {
            vm.clear()
            testScheduler.advanceUntilIdle()
        }
    }
}

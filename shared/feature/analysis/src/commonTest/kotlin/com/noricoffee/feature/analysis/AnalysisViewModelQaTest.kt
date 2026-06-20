package com.noricoffee.feature.analysis

import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.TastingScores
import com.noricoffee.domain.model.CoffeeInsight
import com.noricoffee.domain.model.CoffeeInsightProvider
import com.noricoffee.domain.model.CoffeeStats
import com.noricoffee.domain.usecase.ObserveCoffeeStatsUseCase
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.flowOf
import kotlinx.coroutines.test.runTest
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

/**
 * [AnalysisViewModel] の Q&A 状態遷移（[AnalysisViewModel.onQuestionAsked] /
 * [AnalysisViewModel.onQaCleared]）のユニットテスト。
 *
 * - provider == null のとき [AnalysisViewModel.QaStatus.Unsupported] 初期化される
 * - provider != null のとき [AnalysisViewModel.QaStatus.Idle] 初期化される
 * - 空質問は no-op（ガード）
 * - stats が null のとき no-op（ガード）
 * - 成功パス: [AnalysisViewModel.QaStatus.Asking] → [AnalysisViewModel.QaStatus.Answered]
 * - 失敗パス: [AnalysisViewModel.QaStatus.Asking] → [AnalysisViewModel.QaStatus.Failed] + error
 * - [AnalysisViewModel.onQaCleared] で Idle に戻る
 * - [AnalysisViewModel.QaStatus.Unsupported] 時に onQaCleared は no-op
 */
class AnalysisViewModelQaTest {

    // --- Fakes ---

    /**
     * [CoffeeRepository] の fake。
     *
     * [records] に CoffeeRecord を設定することで observeAll の戻り値を制御する。
     * 空リスト → [ObserveCoffeeStatsUseCase] が totalCount=0 の空 CoffeeStats を emit する。
     */
    private class FakeCoffeeRepository(
        private val records: List<CoffeeRecord> = emptyList(),
    ) : CoffeeRepository {
        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flowOf(records)
        override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
        override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    /**
     * テスト用の [CoffeeInsightProvider] fake。
     *
     * [answerResult] が non-null なら成功、[answerError] が non-null なら失敗を模倣する。
     */
    private class FakeCoffeeInsightProvider(
        private val answerResult: String? = "これはテスト回答です",
        private val answerError: Exception? = null,
    ) : CoffeeInsightProvider {

        override suspend fun summarize(stats: CoffeeStats): CoffeeInsight {
            return CoffeeInsight(headline = "テスト見出し", body = "テスト本文")
        }

        override suspend fun answer(question: String, stats: CoffeeStats): String {
            answerError?.let { throw it }
            return answerResult ?: error("answerResult must be non-null when answerError is null")
        }
    }

    // --- ヘルパ ---

    /** テスト用の最小限 CoffeeRecord を生成する。 */
    private fun record(id: String = "r-1", rating: Double = 4.0) = CoffeeRecord(
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
        tasting = null,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    /**
     * [records] を持つ fake を使った [ObserveCoffeeStatsUseCase] を返す。
     *
     * records が空のとき UseCase は totalCount=0 の CoffeeStats を emit する。
     * records が null のとき Flow は emit せず、latestStats が null のまま残る。
     */
    private fun makeUseCase(records: List<CoffeeRecord>? = emptyList()): ObserveCoffeeStatsUseCase {
        val repo = if (records != null) {
            FakeCoffeeRepository(records)
        } else {
            // 何も emit しない Repository（stats が確定しない状態を模擬）
            object : CoffeeRepository {
                override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = MutableStateFlow(emptyList<CoffeeRecord>()).also {
                    // 初回 emit なし: MutableStateFlow(emptyList) は emit するので flowOf 型を差し替える
                }.asStateFlow().let { _ ->
                    // "emit しない" を再現するため空 Flow を返す
                    kotlinx.coroutines.flow.flow { }
                }
                override fun observeById(id: String): Flow<CoffeeRecord?> = flowOf(null)
                override fun observeByCafe(userId: String, placeId: String): Flow<List<CoffeeRecord>> = flowOf(emptyList())
                override suspend fun save(record: CoffeeRecord) = Unit
                override suspend fun delete(userId: String, id: String) = Unit
            }
        }
        return ObserveCoffeeStatsUseCase(repo)
    }

    // --- テスト ---

    @Test
    fun initialState_withNullProvider_qaStatusIsUnsupported() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(),
            insightProvider = null,
            userId = "user-1",
            scope = this,
        )

        assertEquals(AnalysisViewModel.QaStatus.Unsupported, vm.state.value.qaStatus)
    }

    @Test
    fun initialState_withProvider_qaStatusIsIdle() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(),
            insightProvider = FakeCoffeeInsightProvider(),
            userId = "user-1",
            scope = this,
        )

        assertEquals(AnalysisViewModel.QaStatus.Idle, vm.state.value.qaStatus)
    }

    @Test
    fun onQuestionAsked_withEmptyQuestion_isNoOp() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(listOf(record())),
            insightProvider = FakeCoffeeInsightProvider(),
            userId = "user-1",
            scope = this,
        )
        vm.onAppear()
        testScheduler.advanceUntilIdle()

        vm.onQuestionAsked("   ")
        testScheduler.advanceUntilIdle()

        assertEquals(AnalysisViewModel.QaStatus.Idle, vm.state.value.qaStatus)
        assertNull(vm.state.value.qaQuestion)
    }

    @Test
    fun onQuestionAsked_withNullProvider_isNoOp() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(listOf(record())),
            insightProvider = null,
            userId = "user-1",
            scope = this,
        )
        vm.onAppear()
        testScheduler.advanceUntilIdle()

        vm.onQuestionAsked("好きな産地は？")
        testScheduler.advanceUntilIdle()

        assertEquals(AnalysisViewModel.QaStatus.Unsupported, vm.state.value.qaStatus)
        assertNull(vm.state.value.qaQuestion)
    }

    @Test
    fun onQuestionAsked_whenStatsNotYetEmitted_isNoOp() = runTest {
        // records = null → observeAll が emit しない → latestStats == null のまま
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(null),
            insightProvider = FakeCoffeeInsightProvider(),
            userId = "user-1",
            scope = this,
        )
        vm.onAppear()
        testScheduler.advanceUntilIdle()

        vm.onQuestionAsked("好きな産地は？")
        testScheduler.advanceUntilIdle()

        assertEquals(AnalysisViewModel.QaStatus.Idle, vm.state.value.qaStatus)
        assertNull(vm.state.value.qaQuestion)
    }

    @Test
    fun onQuestionAsked_success_transitionsToAnswered() = runTest {
        val expectedAnswer = "エチオピアが好きです"
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(listOf(record())),
            insightProvider = FakeCoffeeInsightProvider(answerResult = expectedAnswer),
            userId = "user-1",
            scope = this,
        )
        vm.onAppear()
        testScheduler.advanceUntilIdle()

        vm.onQuestionAsked("好きな産地は？")
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertEquals(AnalysisViewModel.QaStatus.Answered, state.qaStatus)
        assertEquals("好きな産地は？", state.qaQuestion)
        assertEquals(expectedAnswer, state.qaAnswer)
        assertNull(state.error)
    }

    @Test
    fun onQuestionAsked_failure_transitionsToFailed() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(listOf(record())),
            insightProvider = FakeCoffeeInsightProvider(
                answerResult = null,
                answerError = Exception("Model unavailable"),
            ),
            userId = "user-1",
            scope = this,
        )
        vm.onAppear()
        testScheduler.advanceUntilIdle()

        vm.onQuestionAsked("よく行くカフェは？")
        testScheduler.advanceUntilIdle()

        val state = vm.state.value
        assertEquals(AnalysisViewModel.QaStatus.Failed, state.qaStatus)
        assertEquals("よく行くカフェは？", state.qaQuestion)
        assertNull(state.qaAnswer)
        assertEquals("Model unavailable", state.error)
    }

    @Test
    fun onQaCleared_fromAnswered_resetsToIdle() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(listOf(record())),
            insightProvider = FakeCoffeeInsightProvider(answerResult = "テスト回答"),
            userId = "user-1",
            scope = this,
        )
        vm.onAppear()
        testScheduler.advanceUntilIdle()
        vm.onQuestionAsked("一番高評価だったコーヒーは？")
        testScheduler.advanceUntilIdle()
        assertEquals(AnalysisViewModel.QaStatus.Answered, vm.state.value.qaStatus)

        vm.onQaCleared()

        val state = vm.state.value
        assertEquals(AnalysisViewModel.QaStatus.Idle, state.qaStatus)
        assertNull(state.qaQuestion)
        assertNull(state.qaAnswer)
    }

    @Test
    fun onQaCleared_whenUnsupported_isNoOp() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(),
            insightProvider = null,
            userId = "user-1",
            scope = this,
        )

        vm.onQaCleared()

        assertEquals(AnalysisViewModel.QaStatus.Unsupported, vm.state.value.qaStatus)
    }

    @Test
    fun onQuestionAsked_trimsWhitespaceBeforeProcessing() = runTest {
        val vm = AnalysisViewModel(
            observeCoffeeStatsUseCase = makeUseCase(listOf(record())),
            insightProvider = FakeCoffeeInsightProvider(answerResult = "回答"),
            userId = "user-1",
            scope = this,
        )
        vm.onAppear()
        testScheduler.advanceUntilIdle()

        vm.onQuestionAsked("  好きな産地は？  ")
        testScheduler.advanceUntilIdle()

        assertEquals("好きな産地は？", vm.state.value.qaQuestion)
    }
}

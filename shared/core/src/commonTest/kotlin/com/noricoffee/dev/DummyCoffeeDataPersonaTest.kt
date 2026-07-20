package com.noricoffee.dev

import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.OriginNormalizer
import com.noricoffee.domain.model.PreferenceMatchAxis
import com.noricoffee.domain.model.RecommendationReason
import com.noricoffee.domain.usecase.BuildCoffeeStatsUseCase
import com.noricoffee.domain.usecase.ObserveTasteMatchedCafesUseCase
import com.noricoffee.repository.CoffeeRepository
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotNull
import kotlin.test.assertTrue

/**
 * [DummyCoffeeData] の「王道の喫茶店ブレンド好き」ペルソナが、実際に
 * [BuildCoffeeStatsUseCase] / [ObserveTasteMatchedCafesUseCase] の 4 軸（産地/焙煎度/抽出方法/精製方法）
 * すべてで信号化・カフェ一致することを固定するための受け入れテスト。
 *
 * 将来 [DummyCoffeeData] の中身を調整しても、この人格（ブラジル × City × ネルドリップ × ナチュラル）が
 * 壊れていないことをこのテストが保証する。
 */
class DummyCoffeeDataPersonaTest {

    private class FakeCoffeeRepository(
        records: List<CoffeeRecord>,
    ) : CoffeeRepository {
        private val flow = MutableStateFlow(records)

        override fun observeAll(userId: String): Flow<List<CoffeeRecord>> = flow
        override fun observeById(id: String): Flow<CoffeeRecord?> = MutableStateFlow(null)
        override fun observeByCafe(
            userId: String,
            placeId: String,
        ): Flow<List<CoffeeRecord>> = MutableStateFlow(emptyList())
        override suspend fun save(record: CoffeeRecord) = Unit
        override suspend fun delete(userId: String, id: String) = Unit
    }

    @Test
    fun favoriteSignals_allFourAxes_matchWelcomeCoffeeHousePersona() {
        val records = DummyCoffeeData.records("dev-user")
        val stats = BuildCoffeeStatsUseCase()(records)
        val signals = stats.favoriteSignals

        val bestOrigin = signals.bestOrigin
        assertNotNull(bestOrigin, "bestOrigin should be non-null (Brazil persona signal)")
        assertEquals("ブラジル", OriginNormalizer.normalize(bestOrigin.label))

        val bestRoastLevel = signals.bestRoastLevel
        assertNotNull(bestRoastLevel, "bestRoastLevel should be non-null (City persona signal)")
        assertEquals("City", bestRoastLevel.label)

        val bestBrewMethod = signals.bestBrewMethod
        assertNotNull(bestBrewMethod, "bestBrewMethod should be non-null (NelDrip persona signal)")
        assertEquals("NelDrip", bestBrewMethod.label)

        val bestProcessing = signals.bestProcessing
        assertNotNull(bestProcessing, "bestProcessing should be non-null (Natural persona signal)")
        assertEquals("Natural", bestProcessing.label)
    }

    @Test
    fun recommendedCafes_atLeastTwoCafes_andOneWithAllFourAxes() = runTest {
        val records = DummyCoffeeData.records("dev-user")
        val useCase = ObserveTasteMatchedCafesUseCase(
            coffeeRepository = FakeCoffeeRepository(records),
            buildCoffeeStatsUseCase = BuildCoffeeStatsUseCase(),
        )

        val result = useCase.observeRecommendedCafes("dev-user").first()

        assertTrue(result.size >= 2, "Expected at least 2 recommended cafes, got ${result.size}")

        val fullMatchCafe = result.firstOrNull { recommended ->
            val axes = recommended.matches
                .filterIsInstance<RecommendationReason.TasteProfileMatch>()
                .map { it.axis }
                .toSet()
            axes.containsAll(
                setOf(
                    PreferenceMatchAxis.Origin,
                    PreferenceMatchAxis.RoastLevel,
                    PreferenceMatchAxis.BrewMethod,
                    PreferenceMatchAxis.Processing,
                ),
            )
        }
        assertNotNull(fullMatchCafe, "Expected at least one cafe matching all 4 PreferenceMatchAxis")
    }
}

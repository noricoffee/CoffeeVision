package com.noricoffee.domain.usecase

import com.noricoffee.domain.BeanProfile
import com.noricoffee.domain.BrewMethod
import com.noricoffee.domain.CoffeeRecord
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.model.CategoryStat
import com.noricoffee.domain.model.FavoriteSignals
import kotlinx.datetime.Instant
import kotlinx.datetime.LocalDate
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [SuggestUnexploredBeansUseCase] のユニットテスト。
 *
 * 純粋関数なので Repository 不要で直接テストできる。
 */
class SuggestUnexploredBeansUseCaseTest {

    private val useCase = SuggestUnexploredBeansUseCase()

    // --- テスト用ヘルパ ---

    private fun record(
        id: String,
        origin: String? = null,
        variety: String? = null,
        rating: Double = 3.0,
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
        origin = origin,
        region = null,
        variety = variety,
        processing = null,
        roastLevel = null,
        cup = null,
        brewRecipe = null,
        tasting = null,
        createdAt = Instant.fromEpochMilliseconds(0),
        updatedAt = Instant.fromEpochMilliseconds(0),
    )

    private fun profile(
        beanId: String,
        origin: String,
        variety: String? = null,
        processings: List<ProcessingMethod> = emptyList(),
        flavorNotes: List<String> = emptyList(),
    ) = BeanProfile(
        beanId = beanId,
        name = "Bean $beanId",
        origin = origin,
        variety = variety,
        processings = processings,
        flavorNotes = flavorNotes,
        description = null,
    )

    private fun signalsWithOrigin(label: String) = FavoriteSignals(
        bestOrigin = CategoryStat(label = label, count = 5, averageRating = 4.2),
    )

    // --- テストケース ---

    @Test
    fun `好み信号に合致し未記録の BeanProfile は提案に出る`() {
        val records = listOf(record("r1", origin = "Colombia", variety = "Caturra"))
        val profiles = listOf(profile("b1", origin = "Ethiopia", variety = "Heirloom"))

        val result = useCase(records, profiles, signalsWithOrigin("Ethiopia"))

        assertEquals(1, result.size)
        assertEquals("b1", result.first().profile.beanId)
        assertEquals("Ethiopia", result.first().matchedOriginLabel)
    }

    @Test
    fun `origin と variety のペアが記録済みの BeanProfile は除外される`() {
        val records = listOf(record("r1", origin = "Ethiopia", variety = "Heirloom"))
        val profiles = listOf(profile("b1", origin = "Ethiopia", variety = "Heirloom"))

        val result = useCase(records, profiles, signalsWithOrigin("Ethiopia"))

        assertTrue(result.isEmpty())
    }

    @Test
    fun `同じ産地でも記録済みと異なる variety は未経験として提案される`() {
        val records = listOf(record("r1", origin = "Ethiopia", variety = "Heirloom"))
        val profiles = listOf(profile("b1", origin = "Ethiopia", variety = "Gesha"))

        val result = useCase(records, profiles, signalsWithOrigin("Ethiopia"))

        assertEquals(1, result.size)
        assertEquals("b1", result.first().profile.beanId)
    }

    @Test
    fun `variety が null の BeanProfile は origin 一致だけで記録済み判定される`() {
        val records = listOf(record("r1", origin = "Ethiopia", variety = "Heirloom"))
        val profiles = listOf(profile("b1", origin = "Ethiopia", variety = null))

        val result = useCase(records, profiles, signalsWithOrigin("Ethiopia"))

        assertTrue(result.isEmpty())
    }

    @Test
    fun `FavoriteSignals が全 null のとき空を返す`() {
        val records = listOf(record("r1", origin = "Colombia"))
        val profiles = listOf(profile("b1", origin = "Ethiopia"))

        val result = useCase(records, profiles, FavoriteSignals())

        assertTrue(result.isEmpty())
    }

    @Test
    fun `BeanProfile リストが空のとき空を返す`() {
        val records = listOf(record("r1", origin = "Colombia"))

        val result = useCase(records, emptyList(), signalsWithOrigin("Ethiopia"))

        assertTrue(result.isEmpty())
    }

    @Test
    fun `上位 SUGGESTED_BEANS_LIMIT 件に絞られる`() {
        val records = emptyList<CoffeeRecord>()
        val profiles = (1..8).map { i -> profile("b$i", origin = "Ethiopia", variety = "Variety $i") }

        val result = useCase(records, profiles, signalsWithOrigin("Ethiopia"))

        assertEquals(SuggestUnexploredBeansUseCase.SUGGESTED_BEANS_LIMIT, result.size)
    }

    @Test
    fun `origin が部分一致のみの BeanProfile も候補に含まれる`() {
        // 入力・プロファイルとも OriginNormalizer の辞書外の語（素通しの contains 判定を検証する）
        val records = emptyList<CoffeeRecord>()
        val profiles = listOf(profile("b1", origin = "ケニア ニエリ", variety = "SL28"))

        val result = useCase(records, profiles, signalsWithOrigin("ニエリ"))

        assertEquals(1, result.size)
        assertEquals("b1", result.first().profile.beanId)
    }

    @Test
    fun `origin が不一致の BeanProfile は候補に含まれない`() {
        val records = emptyList<CoffeeRecord>()
        val profiles = listOf(profile("b1", origin = "Colombia", variety = "Caturra"))

        val result = useCase(records, profiles, signalsWithOrigin("Ethiopia"))

        assertTrue(result.isEmpty())
    }
}

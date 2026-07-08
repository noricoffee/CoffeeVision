package com.noricoffee.domain.usecase

import com.noricoffee.domain.BeanProfile
import com.noricoffee.domain.ProcessingMethod
import com.noricoffee.domain.model.CategoryStat
import com.noricoffee.domain.model.FavoriteSignals
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * [PreferredBeanTraitsUseCase] のユニットテスト。
 *
 * 純粋関数なので Repository 不要で直接テストできる。
 */
class PreferredBeanTraitsUseCaseTest {

    private val useCase = PreferredBeanTraitsUseCase()

    private fun profile(
        beanId: String,
        origin: String,
        flavorNotes: List<String>,
        processings: List<ProcessingMethod> = emptyList(),
    ) = BeanProfile(
        beanId = beanId,
        name = "Bean $beanId",
        origin = origin,
        variety = null,
        processings = processings,
        flavorNotes = flavorNotes,
        description = null,
    )

    // --- テストデータ ---

    private val ethiopiaWashed = profile("e1", "Ethiopia", listOf("Blueberry", "Jasmine", "Citrus"))
    private val ethiopiaWashed2 = profile("e2", "Ethiopia", listOf("Blueberry", "Dark Chocolate"))
    private val ethiopiaNatural = profile("e3", "ETHIOPIA ", listOf("Strawberry", "Jasmine"))  // 大文字 + 末尾スペース
    private val colombiaProfile = profile("c1", "Colombia", listOf("Caramel", "Apple", "Citrus"))

    // --- テスト ---

    @Test
    fun `bestOrigin が Ethiopia のとき Ethiopia プロファイルのみマッチする`() {
        val signals = FavoriteSignals(
            bestOrigin = CategoryStat(label = "Ethiopia", count = 5, averageRating = 4.2),
        )
        val profiles = listOf(ethiopiaWashed, ethiopiaWashed2, ethiopiaNatural, colombiaProfile)

        val result = useCase(profiles, signals)

        assertEquals(3, result.matchedProfiles.size)
        assertTrue(result.matchedProfiles.none { it.origin.trim().lowercase() == "colombia" })
        assertEquals("Ethiopia", result.originHint)
    }

    @Test
    fun `flavorNotes の頻度集計が正しく top-5 に収まる`() {
        val signals = FavoriteSignals(
            bestOrigin = CategoryStat(label = "Ethiopia", count = 5, averageRating = 4.2),
        )
        val profiles = listOf(ethiopiaWashed, ethiopiaWashed2, ethiopiaNatural)

        val result = useCase(profiles, signals)

        // Blueberry: 2回, Jasmine: 2回, Citrus: 1回, Dark Chocolate: 1回, Strawberry: 1回
        assertTrue(result.dominantFlavorNotes.size <= PreferredBeanTraitsUseCase.TOP_FLAVOR_NOTES_LIMIT)
        assertTrue(result.dominantFlavorNotes.contains("Blueberry"))
        assertTrue(result.dominantFlavorNotes.contains("Jasmine"))
    }

    @Test
    fun `bestOrigin が null のとき matchedProfiles が空で originHint が null になる`() {
        val signals = FavoriteSignals(bestOrigin = null)
        val profiles = listOf(ethiopiaWashed, colombiaProfile)

        val result = useCase(profiles, signals)

        assertTrue(result.matchedProfiles.isEmpty())
        assertTrue(result.dominantFlavorNotes.isEmpty())
        assertNull(result.originHint)
    }

    @Test
    fun `bestRoastLevel が存在するとき roastLevelHint に反映される`() {
        val signals = FavoriteSignals(
            bestRoastLevel = CategoryStat(label = "Medium", count = 3, averageRating = 4.0),
        )
        val result = useCase(emptyList(), signals)

        assertEquals("Medium", result.roastLevelHint)
    }

    @Test
    fun `originLabel の大文字小文字と前後スペースを無視してマッチする`() {
        val signals = FavoriteSignals(
            bestOrigin = CategoryStat(label = "ethiopia", count = 3, averageRating = 4.0),
        )
        // "ETHIOPIA " は trim + lowercase → "ethiopia" で完全一致するはず
        val profiles = listOf(ethiopiaNatural, colombiaProfile)

        val result = useCase(profiles, signals)

        assertEquals(1, result.matchedProfiles.size)
        assertEquals("e3", result.matchedProfiles.first().beanId)
    }

    @Test
    fun `bestOrigin が Ethiopia のとき origin エチオピア の BeanProfile とシノニム名寄せでマッチする`() {
        val signals = FavoriteSignals(
            bestOrigin = CategoryStat(label = "Ethiopia", count = 5, averageRating = 4.2),
        )
        val japaneseOriginProfile = profile("e4", "エチオピア", listOf("Floral"))
        val profiles = listOf(japaneseOriginProfile, colombiaProfile)

        val result = useCase(profiles, signals)

        assertEquals(1, result.matchedProfiles.size)
        assertEquals("e4", result.matchedProfiles.first().beanId)
    }
}

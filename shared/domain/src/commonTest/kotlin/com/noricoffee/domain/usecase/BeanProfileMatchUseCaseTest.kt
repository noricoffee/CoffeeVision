package com.noricoffee.domain.usecase

import com.noricoffee.domain.BeanProfile
import com.noricoffee.domain.ProcessingMethod
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * [BeanProfileMatchUseCase] のスコアリングロジックを検証するユニットテスト。
 *
 * 純粋関数なので Repository 不要で直接テストできる。
 */
class BeanProfileMatchUseCaseTest {

    private val useCase = BeanProfileMatchUseCase()

    // --- テスト用ヘルパ ---

    private fun profile(
        beanId: String,
        origin: String,
        processings: List<ProcessingMethod> = emptyList(),
        variety: String? = null,
        flavorNotes: List<String> = emptyList(),
        description: String? = null,
    ) = BeanProfile(
        beanId = beanId,
        name = "テスト豆 $beanId",
        origin = origin,
        variety = variety,
        processings = processings,
        flavorNotes = flavorNotes,
        description = description,
    )

    // --- テストケース ---

    /**
     * TC-1: origin 完全一致のみ（processing は指定しない）
     * score = 2（origin 完全一致 +2）で返却される。
     */
    @Test
    fun `origin 完全一致のみのプロファイルが score 2 で返る`() {
        val profiles = listOf(
            profile("a", origin = "Ethiopia"),
            profile("b", origin = "Colombia"),
        )

        val result = useCase(profiles, origin = "Ethiopia", processing = null)

        assertEquals(1, result.size)
        assertEquals("a", result.first().beanId)
    }

    /**
     * TC-2: origin 部分一致（contains）→ score 1 で返却される。
     * 入力 "Yirgacheffe" が profile.origin "Ethiopia Yirgacheffe" に含まれるケース。
     */
    @Test
    fun `origin 部分一致（contains）のプロファイルが score 1 で返る`() {
        val profiles = listOf(
            profile("a", origin = "Ethiopia Yirgacheffe"),
            profile("b", origin = "Colombia"),
        )

        val result = useCase(profiles, origin = "Yirgacheffe", processing = null)

        assertEquals(1, result.size)
        assertEquals("a", result.first().beanId)
    }

    /**
     * TC-3: origin 完全一致 + processing 一致 → score 3 で先頭に来る。
     *
     * score内訳:
     * - profile "a": origin 完全一致 +2、processing 一致 +1 → score 3
     * - profile "b": origin 完全一致 +2 のみ → score 2
     * → "a" が先頭
     */
    @Test
    fun `origin 完全一致かつ processing 一致のプロファイルが最高スコアで先頭に来る`() {
        val profiles = listOf(
            profile("b", origin = "Ethiopia"),                                       // score 2
            profile("a", origin = "Ethiopia", processings = listOf(ProcessingMethod.Washed)), // score 3
        )

        val result = useCase(
            profiles,
            origin = "Ethiopia",
            processing = ProcessingMethod.Washed,
        )

        assertEquals(2, result.size)
        assertEquals("a", result[0].beanId)
        assertEquals("b", result[1].beanId)
    }

    /**
     * TC-4: origin も processing も不一致 → score 0 なので返却されない。
     */
    @Test
    fun `origin も processing も不一致のプロファイルは返却されない`() {
        val profiles = listOf(
            profile("a", origin = "Colombia", processings = listOf(ProcessingMethod.Natural)),
        )

        val result = useCase(
            profiles,
            origin = "Ethiopia",
            processing = ProcessingMethod.Washed,
        )

        assertTrue(result.isEmpty())
    }

    /**
     * TC-5: origin と processing がともに null → 全件 score 0 → 空リストを返す。
     */
    @Test
    fun `origin も processing も null のとき空リストを返す`() {
        val profiles = listOf(
            profile("a", origin = "Ethiopia", processings = listOf(ProcessingMethod.Washed)),
            profile("b", origin = "Colombia", processings = listOf(ProcessingMethod.Natural)),
        )

        val result = useCase(profiles, origin = null, processing = null)

        assertTrue(result.isEmpty())
    }

    /**
     * TC-6: origin の大文字小文字・前後スペースを無視して完全一致する。
     * "  ethiopia  " → "Ethiopia" に正規化され、score 2。
     */
    @Test
    fun `origin の大文字小文字とトリムを無視して完全一致する`() {
        val profiles = listOf(
            profile("a", origin = "Ethiopia"),
        )

        val result = useCase(profiles, origin = "  ETHIOPIA  ", processing = null)

        assertEquals(1, result.size)
        assertEquals("a", result.first().beanId)
    }

    /**
     * TC-7: processing 一致のみ（origin は null）→ score 1 で返却される。
     */
    @Test
    fun `processing のみ一致のプロファイルが score 1 で返る`() {
        val profiles = listOf(
            profile("a", origin = "Ethiopia", processings = listOf(ProcessingMethod.Washed)),
            profile("b", origin = "Colombia", processings = listOf(ProcessingMethod.Natural)),
        )

        val result = useCase(profiles, origin = null, processing = ProcessingMethod.Washed)

        assertEquals(1, result.size)
        assertEquals("a", result.first().beanId)
    }
}

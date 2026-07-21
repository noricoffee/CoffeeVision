package com.noricoffee.data.places

import com.noricoffee.domain.LocationBias
import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.engine.mock.toByteArray
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * [PlacesClientImpl.searchText] のカフェ語補完ロジックを検証するテスト。
 *
 * [PlacesClientImpl.ensureCafeKeyword] は `private` のため、MockEngine で送信された
 * リクエストボディの `textQuery` を直接 assert することで挙動を検証する。
 *
 * ## 検証ケース
 * 1. 地名のみ（"渋谷"）→ `"渋谷 コーヒー"` に補完されて送信される
 * 2. カタカナ「コーヒー」含む → 補完されない（"コーヒー" のまま）
 * 3. 「渋谷 カフェ」含む → 補完されない（二重付与なし）
 * 4. 英語「Coffee」含む → 大文字小文字無視で補完されない
 * 5. 英語「cafe」含む → 補完されない
 * 6. `searchText(query, locationBias)` 経路では補完されない（raw query のまま送信）
 */
class PlacesClientImplSearchTextKeywordTest {

    /** 最小限の searchText レスポンス（places 配列が空）。 */
    private val emptyPlacesJson = """{"places":[]}"""

    /**
     * MockEngine で送信リクエストボディを捕捉する [PlacesClientImpl] を構築するヘルパ。
     *
     * @param onRequestBody サスペンド可能なコールバック。リクエストボディの文字列を受け取る
     */
    private fun buildClient(
        capturedBodies: MutableList<String>,
    ): PlacesClientImpl {
        val engine = MockEngine { request ->
            val bodyBytes = request.body.toByteArray()
            capturedBodies.add(bodyBytes.decodeToString())
            respond(
                content = emptyPlacesJson,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        return PlacesClientImpl(
            httpClient = HttpClient(engine),
            apiKey = "test-key",
        )
    }

    // -----------------------------------------------------------------------
    // searchText(query) — 地名 → 補完される
    // -----------------------------------------------------------------------

    @Test
    fun searchText_withPlaceName_appendsCoffeeKeyword() = runTest {
        val bodies = mutableListOf<String>()
        val client = buildClient(bodies)

        client.searchText("渋谷")

        assertEquals(1, bodies.size)
        assertTrue(
            bodies[0].contains("\"textQuery\":\"渋谷 コーヒー\""),
            "Expected textQuery to be '渋谷 コーヒー' but body was: ${bodies[0]}",
        )
    }

    // -----------------------------------------------------------------------
    // searchText(query) — カタカナ「コーヒー」含む → 補完しない
    // -----------------------------------------------------------------------

    @Test
    fun searchText_withCoffeeKeywordKatakana_doesNotAppend() = runTest {
        val bodies = mutableListOf<String>()
        val client = buildClient(bodies)

        client.searchText("コーヒー")

        assertEquals(1, bodies.size)
        assertTrue(
            bodies[0].contains("\"textQuery\":\"コーヒー\""),
            "Expected textQuery to be 'コーヒー' but body was: ${bodies[0]}",
        )
        assertFalse(
            bodies[0].contains("コーヒー コーヒー"),
            "textQuery should not be appended when cafe keyword already present",
        )
    }

    // -----------------------------------------------------------------------
    // searchText(query) — 「渋谷 カフェ」含む → 補完しない（二重付与なし）
    // -----------------------------------------------------------------------

    @Test
    fun searchText_withCafeKeywordAlreadyPresent_doesNotAppend() = runTest {
        val bodies = mutableListOf<String>()
        val client = buildClient(bodies)

        client.searchText("渋谷 カフェ")

        assertEquals(1, bodies.size)
        assertTrue(
            bodies[0].contains("\"textQuery\":\"渋谷 カフェ\""),
            "Expected textQuery to be '渋谷 カフェ' but body was: ${bodies[0]}",
        )
        // "渋谷 カフェ コーヒー" になっていないこと
        assertFalse(
            bodies[0].contains("渋谷 カフェ コーヒー"),
            "textQuery should not be double-appended",
        )
    }

    // -----------------------------------------------------------------------
    // searchText(query) — 英語「Coffee」含む（大文字小文字無視）→ 補完しない
    // -----------------------------------------------------------------------

    @Test
    fun searchText_withEnglishCoffeeKeyword_caseInsensitive_doesNotAppend() = runTest {
        val bodies = mutableListOf<String>()
        val client = buildClient(bodies)

        client.searchText("Coffee")

        assertEquals(1, bodies.size)
        assertTrue(
            bodies[0].contains("\"textQuery\":\"Coffee\""),
            "Expected textQuery to be 'Coffee' but body was: ${bodies[0]}",
        )
        assertFalse(
            bodies[0].contains("Coffee コーヒー"),
            "textQuery should not be appended when 'Coffee' (case-insensitive) is present",
        )
    }

    // -----------------------------------------------------------------------
    // searchText(query) — 英語「cafe」含む → 補完しない
    // -----------------------------------------------------------------------

    @Test
    fun searchText_withEnglishCafeKeyword_doesNotAppend() = runTest {
        val bodies = mutableListOf<String>()
        val client = buildClient(bodies)

        client.searchText("Cafe Paulista")

        assertEquals(1, bodies.size)
        assertTrue(
            bodies[0].contains("\"textQuery\":\"Cafe Paulista\""),
            "Expected textQuery to be 'Cafe Paulista' but body was: ${bodies[0]}",
        )
        assertFalse(
            bodies[0].contains("Cafe Paulista コーヒー"),
            "textQuery should not be appended when 'cafe' (case-insensitive) is present",
        )
    }

    // -----------------------------------------------------------------------
    // searchText(query, locationBias) — POI タップ経路: 補完されない
    // -----------------------------------------------------------------------

    @Test
    fun searchText_withLocationBias_doesNotAppendKeyword() = runTest {
        val bodies = mutableListOf<String>()
        val client = buildClient(bodies)

        val bias = LocationBias(latitude = 35.658, longitude = 139.701, radiusMeters = 500.0)
        client.searchText("渋谷", bias)

        // locationBias 経路は raw query をそのまま送信する
        assertEquals(1, bodies.size)
        assertTrue(
            bodies[0].contains("\"textQuery\":\"渋谷\""),
            "Expected textQuery to be '渋谷' (no append) but body was: ${bodies[0]}",
        )
        assertFalse(
            bodies[0].contains("渋谷 コーヒー"),
            "searchText(query, locationBias) should NOT append cafe keyword",
        )
    }
}

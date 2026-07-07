package com.noricoffee.data.places

import io.ktor.client.HttpClient
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

/**
 * フェーズ 16: `userRatingCount`（評価件数）の FieldMask 追加 / DTO デコード / マッピングを検証するテスト。
 *
 * 1. `searchText` / `searchNearby` の FieldMask ヘッダに `places.userRatingCount` が含まれる
 * 2. `getDetails` の FieldMask ヘッダに `userRatingCount`（接頭辞なし）が含まれる
 * 3. `userRatingCount` を含む JSON レスポンスが [PlaceSummary.userRatingCount] に正しくマッピングされる
 * 4. レスポンスに `userRatingCount` が無い場合は null にフォールバックする
 */
class PlacesClientImplUserRatingCountTest {

    private fun buildClient(
        responseJson: String,
        onRequest: (headers: Map<String, List<String>>) -> Unit = {},
    ): PlacesClientImpl {
        val engine = MockEngine { request ->
            onRequest(request.headers.entries().associate { it.key to it.value })
            respond(
                content = responseJson,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        return PlacesClientImpl(httpClient = HttpClient(engine), apiKey = "test-key")
    }

    @Test
    fun searchText_fieldMaskHeader_containsUserRatingCount() = runTest {
        var capturedHeaders = emptyMap<String, List<String>>()
        val client = buildClient(
            responseJson = """{"places":[]}""",
            onRequest = { capturedHeaders = it },
        )

        client.searchText("渋谷 カフェ")

        val fieldMask = capturedHeaders["X-Goog-FieldMask"]?.firstOrNull().orEmpty()
        assertTrue(
            fieldMask.contains("places.userRatingCount"),
            "Expected FieldMask to contain 'places.userRatingCount' but was: $fieldMask",
        )
    }

    @Test
    fun searchNearby_fieldMaskHeader_containsUserRatingCount() = runTest {
        var capturedHeaders = emptyMap<String, List<String>>()
        val client = buildClient(
            responseJson = """{"places":[]}""",
            onRequest = { capturedHeaders = it },
        )

        client.searchNearby(latitude = 35.658, longitude = 139.701, radiusMeters = 500.0)

        val fieldMask = capturedHeaders["X-Goog-FieldMask"]?.firstOrNull().orEmpty()
        assertTrue(
            fieldMask.contains("places.userRatingCount"),
            "Expected FieldMask to contain 'places.userRatingCount' but was: $fieldMask",
        )
    }

    @Test
    fun getDetails_fieldMaskHeader_containsUserRatingCountWithoutPrefix() = runTest {
        var capturedHeaders = emptyMap<String, List<String>>()
        val client = buildClient(
            responseJson = """{"id":"ChIJtest001"}""",
            onRequest = { capturedHeaders = it },
        )

        client.getDetails("ChIJtest001")

        val fieldMask = capturedHeaders["X-Goog-FieldMask"]?.firstOrNull().orEmpty()
        assertTrue(
            fieldMask.contains("userRatingCount"),
            "Expected Details FieldMask to contain 'userRatingCount' but was: $fieldMask",
        )
    }

    @Test
    fun searchText_decodesUserRatingCount_intoPlaceSummary() = runTest {
        val client = buildClient(
            responseJson = """
                {"places":[{"id":"ChIJtest001","displayName":{"text":"Blue Bottle"},"userRatingCount":128}]}
            """.trimIndent(),
        )

        val results = client.searchText("渋谷 カフェ")

        assertEquals(1, results.size)
        assertEquals(128, results.first().userRatingCount)
    }

    @Test
    fun searchText_missingUserRatingCount_mapsToNull() = runTest {
        val client = buildClient(
            responseJson = """
                {"places":[{"id":"ChIJtest001","displayName":{"text":"Blue Bottle"}}]}
            """.trimIndent(),
        )

        val results = client.searchText("渋谷 カフェ")

        assertEquals(1, results.size)
        assertEquals(null, results.first().userRatingCount)
    }
}

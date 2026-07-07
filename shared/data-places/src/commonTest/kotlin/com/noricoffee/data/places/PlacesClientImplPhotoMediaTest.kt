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
import kotlin.test.assertFalse
import kotlin.test.assertTrue

/**
 * [PlacesClientImpl.photoMediaUrl] の MockEngine テスト。
 *
 * 以下を検証する:
 * 1. リクエスト URL に `places/{placeId}/photos/{photoRef}/media` が含まれる
 * 2. `skipHttpRedirect=true` クエリパラメータが付く
 * 3. `maxWidthPx` が付く
 * 4. `X-Goog-Api-Key` ヘッダが付く
 * 5. JSON レスポンスから `photoUri` を返す
 * 6. `maxWidthPx` / `maxHeightPx` が null のときはクエリパラメータが省略される
 */
class PlacesClientImplPhotoMediaTest {

    private val testApiKey = "test-api-key"
    private val testPhotoName = "places/ChIJtest001/photos/AUacShiRef1"
    private val testPhotoUri = "https://lh3.googleusercontent.com/places/photo/test"

    /** テスト用の MockEngine と PlacesClientImpl を構築するヘルパ。 */
    private fun buildClientAndCapture(
        responseJson: String,
        onRequest: (requestUrl: String, requestParams: Map<String, List<String>>, requestHeaders: Map<String, List<String>>) -> Unit = { _, _, _ -> },
    ): PlacesClientImpl {
        val engine = MockEngine { request ->
            onRequest(
                request.url.toString(),
                request.url.parameters.entries().associate { it.key to it.value },
                request.headers.entries().associate { it.key to it.value },
            )
            respond(
                content = responseJson,
                status = HttpStatusCode.OK,
                headers = headersOf(HttpHeaders.ContentType, "application/json"),
            )
        }
        return PlacesClientImpl(
            httpClient = HttpClient(engine),
            apiKey = testApiKey,
        )
    }

    @Test
    fun photoMediaUrl_requestContainsCorrectPathAndSkipHttpRedirect() = runTest {
        var capturedUrl = ""
        var capturedParams = emptyMap<String, List<String>>()

        val client = buildClientAndCapture(
            responseJson = """{"name":"$testPhotoName","photoUri":"$testPhotoUri"}""",
            onRequest = { url, params, _ ->
                capturedUrl = url
                capturedParams = params
            },
        )

        client.photoMediaUrl(
            photoName = testPhotoName,
            maxWidthPx = 200,
            maxHeightPx = null,
        )

        // URL に photoName の path が含まれる
        assertTrue(
            capturedUrl.contains("places/ChIJtest001/photos/AUacShiRef1/media"),
            "Expected URL to contain photo path, but was: $capturedUrl",
        )
        // skipHttpRedirect=true が付く
        assertEquals(listOf("true"), capturedParams["skipHttpRedirect"])
        // maxWidthPx=200 が付く
        assertEquals(listOf("200"), capturedParams["maxWidthPx"])
    }

    @Test
    fun photoMediaUrl_requestHasApiKeyHeader() = runTest {
        var capturedHeaders = emptyMap<String, List<String>>()

        val client = buildClientAndCapture(
            responseJson = """{"name":"$testPhotoName","photoUri":"$testPhotoUri"}""",
            onRequest = { _, _, headers ->
                capturedHeaders = headers
            },
        )

        client.photoMediaUrl(
            photoName = testPhotoName,
            maxWidthPx = 200,
            maxHeightPx = null,
        )

        // X-Goog-Api-Key ヘッダが付く
        assertEquals(listOf(testApiKey), capturedHeaders["X-Goog-Api-Key"])
    }

    @Test
    fun photoMediaUrl_returnsPhotoUri() = runTest {
        val client = buildClientAndCapture(
            responseJson = """{"name":"$testPhotoName","photoUri":"$testPhotoUri"}""",
        )

        val result = client.photoMediaUrl(
            photoName = testPhotoName,
            maxWidthPx = 200,
            maxHeightPx = null,
        )

        assertEquals(testPhotoUri, result)
    }

    @Test
    fun photoMediaUrl_nullWidthAndHeight_omitsQueryParams() = runTest {
        var capturedParams = emptyMap<String, List<String>>()

        val client = buildClientAndCapture(
            responseJson = """{"name":"$testPhotoName","photoUri":"$testPhotoUri"}""",
            onRequest = { _, params, _ ->
                capturedParams = params
            },
        )

        client.photoMediaUrl(
            photoName = testPhotoName,
            maxWidthPx = null,
            maxHeightPx = null,
        )

        // skipHttpRedirect は常に付く
        assertEquals(listOf("true"), capturedParams["skipHttpRedirect"])
        // maxWidthPx / maxHeightPx は省略される
        assertFalse(capturedParams.containsKey("maxWidthPx"), "maxWidthPx should not be present when null")
        assertFalse(capturedParams.containsKey("maxHeightPx"), "maxHeightPx should not be present when null")
    }
}

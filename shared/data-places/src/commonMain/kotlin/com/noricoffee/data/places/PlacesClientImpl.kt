package com.noricoffee.data.places

import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.http.ContentType
import io.ktor.http.contentType
import io.ktor.serialization.kotlinx.json.json
import kotlinx.serialization.json.Json

/**
 * [PlacesClient] の実装。Google Places API (New) v1 の `places:searchText` を呼び出す。
 *
 * @param httpClient プラットフォーム別エンジンで構築した [HttpClient]。
 *   `createPlacesHttpClient()` ファクトリか、テスト時はモックを渡す。
 * @param apiKey `X-Goog-Api-Key` ヘッダに渡す API キー。
 *   空文字の場合はリクエストは送られるが 401 / 400 が返る（CI 上での空キー許容）。
 */
class PlacesClientImpl(
    httpClient: HttpClient,
    private val apiKey: String,
) : PlacesClient {

    /**
     * ContentNegotiation プラグインを install した HttpClient を内部保持する。
     *
     * `httpClient` に既に ContentNegotiation が入っている場合は二重 install になるが、
     * Ktor 3.x は重複 install を無視するため問題なし。テスト用 MockEngine も同様。
     */
    private val client: HttpClient = httpClient.config {
        install(ContentNegotiation) {
            json(
                Json {
                    ignoreUnknownKeys = true
                    explicitNulls = false
                }
            )
        }
    }

    override suspend fun searchText(query: String): List<PlaceSummary> {
        val response: SearchTextResponse = client.post(SEARCH_TEXT_URL) {
            contentType(ContentType.Application.Json)
            header("X-Goog-Api-Key", apiKey)
            header("X-Goog-FieldMask", FIELD_MASK)
            setBody(
                SearchTextRequest(
                    textQuery = query,
                    includedType = "cafe",
                    languageCode = "ja",
                )
            )
        }.body()

        return response.places.map { it.toPlaceSummary() }
    }

    private fun PlaceDto.toPlaceSummary(): PlaceSummary = PlaceSummary(
        id = id,
        displayName = displayName?.text ?: "",
        formattedAddress = formattedAddress,
        latitude = location?.latitude,
        longitude = location?.longitude,
        websiteUri = websiteUri,
        googleMapsUri = googleMapsUri,
        photoNames = photos.map { it.name },
    )

    private companion object {
        const val SEARCH_TEXT_URL =
            "https://places.googleapis.com/v1/places:searchText"
        const val FIELD_MASK =
            "places.id,places.displayName,places.formattedAddress," +
                "places.location,places.websiteUri,places.googleMapsUri,places.photos"
    }
}

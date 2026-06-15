package com.noricoffee.data.places

import com.noricoffee.domain.LocationBias
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
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

    override suspend fun searchText(query: String): List<PlaceSummary> =
        searchTextInternal(query = query, locationBias = null)

    override suspend fun searchText(query: String, locationBias: LocationBias): List<PlaceSummary> =
        searchTextInternal(
            query = query,
            locationBias = LocationBiasDto(
                circle = CircleDto(
                    center = LatLngDto(
                        latitude = locationBias.latitude,
                        longitude = locationBias.longitude,
                    ),
                    radius = locationBias.radiusMeters,
                )
            ),
        )

    private suspend fun searchTextInternal(
        query: String,
        locationBias: LocationBiasDto?,
    ): List<PlaceSummary> {
        val response: PlacesListResponse = client.post(SEARCH_TEXT_URL) {
            contentType(ContentType.Application.Json)
            header("X-Goog-Api-Key", apiKey)
            header("X-Goog-FieldMask", FIELD_MASK)
            setBody(
                SearchTextRequest(
                    textQuery = query,
                    includedType = "cafe",
                    languageCode = "ja",
                    locationBias = locationBias,
                )
            )
        }.body()

        return response.places.map { it.toPlaceSummary() }
    }

    override suspend fun searchNearby(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
    ): List<PlaceSummary> {
        val response: PlacesListResponse = client.post(SEARCH_NEARBY_URL) {
            contentType(ContentType.Application.Json)
            header("X-Goog-Api-Key", apiKey)
            header("X-Goog-FieldMask", FIELD_MASK)
            setBody(
                SearchNearbyRequest(
                    locationRestriction = LocationRestrictionDto(
                        circle = CircleDto(
                            center = LatLngDto(
                                latitude = latitude,
                                longitude = longitude,
                            ),
                            radius = radiusMeters,
                        )
                    )
                )
            )
        }.body()

        return response.places.map { it.toPlaceSummary() }
    }

    override suspend fun getDetails(placeId: String): PlaceSummary {
        val placeDto: PlaceDto = client.get("$PLACES_BASE_URL/$placeId") {
            header("X-Goog-Api-Key", apiKey)
            header("X-Goog-FieldMask", DETAILS_FIELD_MASK)
        }.body()

        return placeDto.toPlaceSummary()
    }

    override suspend fun photoMediaUrl(
        photoName: String,
        maxWidthPx: Int?,
        maxHeightPx: Int?,
    ): String {
        val response: PhotoMediaResponse = client.get("$PLACES_MEDIA_BASE_URL/$photoName/media") {
            header("X-Goog-Api-Key", apiKey)
            url {
                parameters.append("skipHttpRedirect", "true")
                if (maxWidthPx != null) parameters.append("maxWidthPx", maxWidthPx.toString())
                if (maxHeightPx != null) parameters.append("maxHeightPx", maxHeightPx.toString())
            }
        }.body()

        return response.photoUri
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
        const val PLACES_BASE_URL = "https://places.googleapis.com/v1/places"
        const val SEARCH_TEXT_URL = "$PLACES_BASE_URL:searchText"
        const val SEARCH_NEARBY_URL = "$PLACES_BASE_URL:searchNearby"

        /**
         * Photo Media API のベース URL。
         *
         * `photoName` は `"places/{placeId}/photos/{photoRef}"` 形式なので、
         * `"$PLACES_MEDIA_BASE_URL/$photoName/media"` とすると
         * `"https://places.googleapis.com/v1/places/{placeId}/photos/{photoRef}/media"` になる。
         *
         * `PLACES_BASE_URL` と同じドメイン配下のため、`PLACES_BASE_URL` を流用している。
         */
        const val PLACES_MEDIA_BASE_URL = "https://places.googleapis.com/v1"

        /** Text Search / Nearby Search 共通 FieldMask（接頭辞 `places.` あり）。 */
        const val FIELD_MASK =
            "places.id,places.displayName,places.formattedAddress," +
                "places.location,places.websiteUri,places.googleMapsUri,places.photos"

        /**
         * Place Details 用 FieldMask（接頭辞 `places.` なし）。
         *
         * 単一 Place 取得（GET `places/{placeId}`）は接頭辞なしで書く必要がある。
         * リスト取得系（searchText / searchNearby）と接頭辞ルールが異なるため別定数にする。
         */
        const val DETAILS_FIELD_MASK =
            "id,displayName,formattedAddress,location,websiteUri,googleMapsUri,photos"
    }
}

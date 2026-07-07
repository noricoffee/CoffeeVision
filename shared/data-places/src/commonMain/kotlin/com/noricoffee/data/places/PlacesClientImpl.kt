package com.noricoffee.data.places

import com.noricoffee.domain.LocationBias
import io.ktor.client.HttpClient
import io.ktor.client.call.body
import io.ktor.client.plugins.HttpResponseValidator
import io.ktor.client.plugins.ResponseException
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.get
import io.ktor.client.request.header
import io.ktor.client.request.post
import io.ktor.client.request.setBody
import io.ktor.client.statement.bodyAsText
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
     * ContentNegotiation と エラーハンドリングを install した HttpClient を内部保持する。
     *
     * `expectSuccess = true` により 非2xx レスポンスで [ResponseException] を投げる。
     * デフォルトの [ResponseException] メッセージにはレスポンス本文が含まれないため、
     * [HttpResponseValidator] で本文を読み取り診断しやすいメッセージに投げ直す。
     *
     * `httpClient` に既に ContentNegotiation が入っている場合は二重 install になるが、
     * Ktor 3.x は重複 install を無視するため問題なし。テスト用 MockEngine も同様。
     */
    private val client: HttpClient = httpClient.config {
        expectSuccess = true

        install(ContentNegotiation) {
            json(
                Json {
                    ignoreUnknownKeys = true
                    explicitNulls = false
                    // encodeDefaults=true により、デフォルト値を持つフィールド（includedPrimaryTypes 等）
                    // も JSON にシリアライズされる。encodeDefaults=false（kotlinx.serialization の既定）では
                    // デフォルト値フィールドが省略され、型フィルタなし検索になるバグの根本原因だった。
                    // explicitNulls=false と併用するため、null デフォルト（locationBias=null 等）は
                    // 引き続き省略される（encodeDefaults は非 null デフォルトのみ encode する）。
                    encodeDefaults = true
                }
            )
        }

        HttpResponseValidator {
            handleResponseExceptionWithRequest { exception, request ->
                val responseException = exception as? ResponseException ?: return@handleResponseExceptionWithRequest
                val responseBody = responseException.response.bodyAsText()
                val status = responseException.response.status
                throw PlacesApiException(
                    message = "Places API error: $status — url=${request.url} body=$responseBody",
                    cause = responseException,
                )
            }
        }
    }

    /**
     * テキストクエリでカフェを検索する（位置バイアスなし）。
     *
     * 地名のみのクエリ（例: "渋谷"）を入力すると、Places API が locality 型の場所（渋谷区など）に
     * 一致させ、`includedType=cafe` フィルタで 0 件になる。
     * そのため、カフェ語を含まないクエリには末尾に " カフェ" を補完してから API に送る。
     *
     * カフェ語を既に含む場合（例: "コーヒー", "渋谷 カフェ"）は補完しない（二重付与・既存挙動を維持）。
     * `searchText(query, locationBias)` は POI タップ経由のため補完対象外。
     *
     * @see ensureCafeKeyword
     */
    override suspend fun searchText(query: String): List<PlaceSummary> =
        searchTextInternal(query = ensureCafeKeyword(query), locationBias = null)

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

    /**
     * クエリにカフェ語が含まれていなければ末尾に " カフェ" を補完して返す。
     *
     * Places API (New) の `searchText` は `includedType=cafe` を指定しているが、
     * 地名のみのクエリ（例: "渋谷"）は locality 型の場所に一致してしまい、
     * cafe フィルタで 0 件になる。そのためカフェ語を補完し、cafe 型の候補を引き出す。
     *
     * カフェ語判定（大文字小文字無視）: カフェ / cafe / café / コーヒー / 珈琲 / coffee
     * - query が blank の場合は no-op（空検索は UI 側で抑止しているが安全側の処理）
     * - いずれかのカフェ語を含む場合は補完しない（二重付与・既存挙動を維持）
     */
    private fun ensureCafeKeyword(query: String): String {
        if (query.isBlank()) return query
        val lower = query.lowercase()
        val hasCafeKeyword = CAFE_KEYWORDS.any { lower.contains(it) }
        return if (hasCafeKeyword) query else "$query カフェ"
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
        openNow = currentOpeningHours?.openNow,
        weekdayDescriptions = currentOpeningHours?.weekdayDescriptions ?: emptyList(),
        phoneNumber = nationalPhoneNumber,
        priceLevel = priceLevel,
        googleRating = rating,
        userRatingCount = userRatingCount,
    )

    private companion object {
        /**
         * カフェ語の一覧（小文字で比較する）。
         * いずれかを含む query には " カフェ" を補完しない。
         */
        val CAFE_KEYWORDS = listOf("カフェ", "cafe", "café", "コーヒー", "珈琲", "coffee")

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
                "places.location,places.websiteUri,places.googleMapsUri,places.photos," +
                "places.currentOpeningHours,places.nationalPhoneNumber,places.priceLevel,places.rating," +
                "places.userRatingCount"

        /**
         * Place Details 用 FieldMask（接頭辞 `places.` なし）。
         *
         * 単一 Place 取得（GET `places/{placeId}`）は接頭辞なしで書く必要がある。
         * リスト取得系（searchText / searchNearby）と接頭辞ルールが異なるため別定数にする。
         */
        const val DETAILS_FIELD_MASK =
            "id,displayName,formattedAddress,location,websiteUri,googleMapsUri,photos," +
                "currentOpeningHours,nationalPhoneNumber,priceLevel,rating,userRatingCount"
    }
}

/**
 * Places API が 非2xx ステータスを返したときに投げる例外。
 *
 * [PlacesClientImpl] の [HttpResponseValidator] が生成する。
 * メッセージには HTTP ステータスコード、リクエスト URL、レスポンス本文（JSON）が含まれるため、
 * `403 API_KEY_IOS_APP_BLOCKED` 等の診断に使える。
 *
 * `internal` にすることで `data-places` モジュール外には漏れない。
 * 上位（ViewModel）は `Exception` / `Throwable` で受け取り、`message` をユーザーに表示する。
 */
internal class PlacesApiException(
    message: String,
    cause: Throwable? = null,
) : Exception(message, cause)

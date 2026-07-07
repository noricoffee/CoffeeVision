package com.noricoffee.data.places

import com.noricoffee.domain.Cafe
import com.noricoffee.domain.LocationBias
import com.noricoffee.repository.CafeRepository

/**
 * [CafeRepository] の KMP 共通実装。
 *
 * [PlacesClient] を経由して Google Places API (New) v1 を呼び出し、
 * [PlaceSummary] を [Cafe] ドメインモデルに変換して返す。
 *
 * ## 変換方針
 * - [Cafe.photoReferences] には [PlaceSummary.photoNames] をそのまま入れる
 *   （`"places/{placeId}/photos/{photoRef}"` 形式のまま。Photo Media API はスライス 4 で実装）
 * - `latitude` / `longitude` は [PlaceSummary] の nullable をそのまま [Cafe] に伝播する
 * - `placeId` は Places API の `id` フィールド（`"ChIJ..."` 形式）
 */
class CafeRepositoryImpl(
    private val placesClient: PlacesClient,
) : CafeRepository {

    override suspend fun searchText(query: String): List<Cafe> =
        placesClient.searchText(query).map { it.toCafe() }

    override suspend fun searchText(query: String, locationBias: LocationBias): List<Cafe> =
        placesClient.searchText(query, locationBias).map { it.toCafe() }

    override suspend fun searchNearby(
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
    ): List<Cafe> =
        placesClient.searchNearby(latitude, longitude, radiusMeters).map { it.toCafe() }

    override suspend fun getDetails(placeId: String): Cafe =
        placesClient.getDetails(placeId).toCafe()

    override suspend fun photoMediaUrl(
        photoName: String,
        maxWidthPx: Int?,
        maxHeightPx: Int?,
    ): String = placesClient.photoMediaUrl(photoName, maxWidthPx, maxHeightPx)

    private fun PlaceSummary.toCafe(): Cafe = Cafe(
        placeId = id,
        name = displayName,
        address = formattedAddress,
        latitude = latitude,
        longitude = longitude,
        photoReferences = photoNames,
        websiteUrl = websiteUri,
        mapsUrl = googleMapsUri,
        openNow = openNow,
        weekdayDescriptions = weekdayDescriptions,
        phoneNumber = phoneNumber,
        priceLevel = priceLevel,
        googleRating = googleRating,
        userRatingCount = userRatingCount,
    )
}

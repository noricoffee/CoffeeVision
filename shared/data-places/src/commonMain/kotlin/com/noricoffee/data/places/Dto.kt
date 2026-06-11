package com.noricoffee.data.places

import kotlinx.serialization.Serializable

/**
 * Places API (New) v1 `places:searchText` リクエストボディ。
 *
 * POST `https://places.googleapis.com/v1/places:searchText`
 * ヘッダ:
 *   `X-Goog-Api-Key: <apiKey>`
 *   `X-Goog-FieldMask: places.id,places.displayName,...`
 */
@Serializable
internal data class SearchTextRequest(
    val textQuery: String,
    val includedType: String = "cafe",
    val languageCode: String = "ja",
)

/**
 * Places API (New) v1 `places:searchText` レスポンス。
 *
 * `ignoreUnknownKeys = true` で decode するため、FieldMask 対象外フィールドは無視される。
 */
@Serializable
internal data class SearchTextResponse(
    val places: List<PlaceDto> = emptyList(),
)

/** 1 件の Place エントリ。 */
@Serializable
internal data class PlaceDto(
    val id: String,
    val displayName: DisplayNameDto? = null,
    val formattedAddress: String? = null,
    val location: LocationDto? = null,
    val websiteUri: String? = null,
    val googleMapsUri: String? = null,
    val photos: List<PhotoDto> = emptyList(),
)

/** `displayName` オブジェクト。API は `{"text": "...", "languageCode": "ja"}` 形式。 */
@Serializable
internal data class DisplayNameDto(
    val text: String,
    val languageCode: String? = null,
)

/** `location` オブジェクト。 */
@Serializable
internal data class LocationDto(
    val latitude: Double,
    val longitude: Double,
)

/**
 * `photos` 配列の 1 要素。
 *
 * `name` フィールドは `"places/{placeId}/photos/{photoReference}"` 形式。
 * Photo Media API で表示時取得する際のキーとして使う（スライス 4）。
 */
@Serializable
internal data class PhotoDto(
    val name: String,
    val widthPx: Int? = null,
    val heightPx: Int? = null,
)

package com.noricoffee.data.places

import kotlinx.serialization.Serializable

/**
 * Places API (New) v1 `places:searchText` リクエストボディ。
 *
 * POST `https://places.googleapis.com/v1/places:searchText`
 * ヘッダ:
 *   `X-Goog-Api-Key: <apiKey>`
 *   `X-Goog-FieldMask: places.id,places.displayName,...`
 *
 * [locationBias] が null の場合、`explicitNulls = false` の Json 設定によりフィールドは省略される。
 */
@Serializable
internal data class SearchTextRequest(
    val textQuery: String,
    val includedType: String = "cafe",
    val languageCode: String = "ja",
    val locationBias: LocationBiasDto? = null,
)

/**
 * `searchText` の `locationBias` オブジェクト。
 *
 * Places API (New) v1 の仕様: `{"circle": {"center": {"latitude": ..., "longitude": ...}, "radius": ...}}`
 */
@Serializable
internal data class LocationBiasDto(
    val circle: CircleDto,
)

/**
 * Places API (New) v1 `places:searchText` / `places:searchNearby` 共通レスポンス。
 *
 * Text Search と Nearby Search は同じ `{"places": [...]}` 構造のため共用する。
 * `ignoreUnknownKeys = true` で decode するため、FieldMask 対象外フィールドは無視される。
 */
@Serializable
internal data class PlacesListResponse(
    val places: List<PlaceDto> = emptyList(),
)

/**
 * Places API (New) v1 `places:searchNearby` リクエストボディ。
 *
 * POST `https://places.googleapis.com/v1/places:searchNearby`
 * ヘッダ:
 *   `X-Goog-Api-Key: <apiKey>`
 *   `X-Goog-FieldMask: places.id,places.displayName,...`（Text Search と同じ定数を再利用）
 */
@Serializable
internal data class SearchNearbyRequest(
    val includedTypes: List<String> = listOf("cafe"),
    val maxResultCount: Int = 20,
    val languageCode: String = "ja",
    val locationRestriction: LocationRestrictionDto,
)

/** `locationRestriction` オブジェクト。中心点と半径を持つ円で検索範囲を指定する。 */
@Serializable
internal data class LocationRestrictionDto(
    val circle: CircleDto,
)

/** `circle` オブジェクト。中心緯度経度と半径（メートル）を指定する。 */
@Serializable
internal data class CircleDto(
    val center: LatLngDto,
    val radius: Double,
)

/** 緯度経度オブジェクト。`searchNearby` のリクエストで使用する。 */
@Serializable
internal data class LatLngDto(
    val latitude: Double,
    val longitude: Double,
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

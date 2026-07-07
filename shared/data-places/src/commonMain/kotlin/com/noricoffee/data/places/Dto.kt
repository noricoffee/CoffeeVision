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
 *
 * ## includedPrimaryTypes vs includedTypes
 * `includedTypes` は「cafe を含む場所」全般（ホテルのカフェラウンジ等も含む）にマッチするが、
 * `includedPrimaryTypes` は「主タイプが cafe / coffee_shop の場所」のみに絞る。
 * 後者のほうが実カフェ精度が高い。
 *
 * ## rankPreference = "DISTANCE"
 * `POPULARITY`（既定）は Prominence 順でホテルや有名ランドマークが上位に来る。
 * `DISTANCE` にすることで現在地に最も近いカフェが上位になる。
 * `rankPreference=DISTANCE` 使用時は [locationRestriction]（circle）の指定が必須。
 */
@Serializable
internal data class SearchNearbyRequest(
    val includedPrimaryTypes: List<String> = listOf("cafe", "coffee_shop"),
    val maxResultCount: Int = 20,
    val languageCode: String = "ja",
    val rankPreference: String = "DISTANCE",
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

/**
 * `currentOpeningHours` オブジェクト。
 *
 * [openNow] は現在営業中か否かを示す。[weekdayDescriptions] は曜日ごとの営業時間テキスト（日本語）。
 */
@Serializable
internal data class OpeningHoursDto(
    val openNow: Boolean? = null,
    val weekdayDescriptions: List<String> = emptyList(),
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
    val currentOpeningHours: OpeningHoursDto? = null,
    val nationalPhoneNumber: String? = null,
    val priceLevel: String? = null,   // "PRICE_LEVEL_INEXPENSIVE" 等
    val rating: Double? = null,        // Google Maps 評価 (1.0–5.0)
    val userRatingCount: Int? = null,  // Google Maps 評価件数
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

/**
 * Photo Media API レスポンス。
 *
 * GET `https://places.googleapis.com/v1/{photoName}/media?skipHttpRedirect=true&...`
 * ヘッダ:
 *   `X-Goog-Api-Key: <apiKey>`
 *
 * `skipHttpRedirect=true` を付けることでリダイレクトせず JSON レスポンスを返す。
 * `photoUri` は Google CDN（lh3.googleusercontent.com 等）の時限署名 URL。
 */
@Serializable
internal data class PhotoMediaResponse(
    val name: String? = null,
    val photoUri: String,
)
